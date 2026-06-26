import Foundation
import UserNotifications

// MARK: - StockSageMonitor
//
// Reworked from the package's `AutonomousMarketAgent`. Kept the genuinely real
// parts — the cancellable monitoring loop and real `UNUserNotificationCenter`
// strong-signal alerts. Changes from the package:
//   * Namespaced (no collision with Chat A's agent backbone).
//   * Throttle decision uses the app's real `MemoryManager` instead of the
//     package's `testingHooks.shouldThrottleForThermal` shim.
//   * **Dropped the fabricated swarm-spawn / device-migration calls** — the
//     package "spawned" agents into a dictionary and printed fake migration
//     success. Shipping nothing that lies.
//   * Reads symbols from `StockSageStore` (in-memory; sample data until Chat A's
//     live feed replaces it).
@MainActor
final class StockSageMonitor {
    static let shared = StockSageMonitor()
    private init() {}

    private var task: Task<Void, Never>?
    private(set) var isRunning = false
    /// When this UserDefaults flag is set AND the user has a non-empty watchlist, the loop
    /// scans ONLY the watchlist (fetching just those quotes) instead of pulling the whole
    /// ~250-name core every cycle. Shared with the Markets toggle's @AppStorage key.
    static let watchlistOnlyKey = "marketsWatchlistOnly"
    /// The last strong recommendation fired per symbol, so we don't re-spam the
    /// SAME alert every cycle (only a NEW or CHANGED strong signal notifies).
    private var lastAlerted: [String: StockSageRecommendation] = [:]

    enum MonitorError: LocalizedError {
        case alreadyRunning
        var errorDescription: String? {
            switch self {
            case .alreadyRunning: return "StockSage monitor is already running."
            }
        }
    }

    /// Start the monitoring loop. Re-evaluates every `interval` seconds (doubled
    /// automatically when `MemoryManager` reports the machine is under
    /// memory/thermal pressure). Throws if already running.
    func start(interval: TimeInterval = 45) throws {
        guard !isRunning else { throw MonitorError.alreadyRunning }
        isRunning = true
        requestNotificationPermission()

        task = Task { [weak self] in
            while !Task.isCancelled {
                // Watchlist-only mode (opt-in, re-read each cycle so toggling takes effect):
                // fetch + scan ONLY the user's watchlist instead of refreshing the whole core.
                let watch = StockSageStore.shared.userSymbols
                let scoped = UserDefaults.standard.bool(forKey: StockSageMonitor.watchlistOnlyKey) && !watch.isEmpty
                if scoped {
                    await self?.runWatchlistCycle(watch)
                } else {
                    // Evaluate on LIVE quotes: pull a fresh worldwide snapshot before
                    // each cycle (no-ops cleanly when offline / web access is off).
                    await StockSageStore.shared.refresh()
                    await self?.runCycle()
                }
                // Throttle under pressure: concurrencyLimit() folds in both
                // memory pressure and thermal state. <=1 means "the machine is
                // stressed" → back off to 2× the interval.
                let stressed = await MemoryManager.shared.concurrencyLimit() <= 1
                let delay = stressed ? interval * 2 : interval
                try? await Task.sleep(for: .seconds(Int(delay)))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    deinit { task?.cancel() }

    /// One evaluation pass: derive a signal per tracked symbol and fire a
    /// notification for strong buy/sell. Returns the strong signals it found
    /// (also used by the unit tests / tool, which don't want notifications).
    @discardableResult
    func runCycle(notify: Bool = true) async -> [StockSageSignal] {
        // NEVER fire a notification on seeded SAMPLE data OR on STALE disk-cache prices.
        // seedSampleData() plants two strong movers (2222.SR, NVDA), so a failed first-launch
        // refresh would push a "Strong Buy" built on hardcoded demo prices; loadedFromCache means
        // the board is last-session prices the in-app UI already labels "NOT live" — pushing a
        // notification off either is an honesty-floor violation (a stale push the owner acts on
        // without seeing the on-screen caveat). Still RETURN the signals so the tests/tool exercise
        // the logic without notifications, and don't poison `lastAlerted` with stale state.
        let store = StockSageStore.shared
        let liveNotify = notify && !store.isSampleData && !store.loadedFromCache
        var strong: [StockSageSignal] = []
        var nowStrong: [String: StockSageRecommendation] = [:]
        for symbol in StockSageStore.shared.fetchAllSymbols() {
            guard let signal = StockSageSignalEngine.generateSignal(for: symbol) else { continue }
            guard signal.recommendation == .strongBuy || signal.recommendation == .strongSell else { continue }
            strong.append(signal)
            nowStrong[signal.symbol] = signal.recommendation
            // Fire only when this symbol's strong signal is NEW or has FLIPPED
            // (Strong Buy ⇄ Strong Sell) — not the same alert on every poll.
            if liveNotify, lastAlerted[signal.symbol] != signal.recommendation {
                await sendAlert(signal: signal, market: symbol.market)
            }
        }
        // MERGE rather than replace: update the symbols that are strong now, but KEEP the
        // last-alerted state of symbols that left "strong". Replacing with only the
        // currently-strong set would forget a symbol that went strong→hold, so a
        // strong→hold→strong round-trip would re-fire the identical alert the user already
        // saw. A genuine flip (Strong Buy⇄Strong Sell) still alerts — the rec differs.
        if liveNotify { for (sym, rec) in nowStrong { lastAlerted[sym] = rec } }
        return strong
    }

    /// Watchlist-only evaluation: fetch LIVE quotes for just the watchlist tickers and alert
    /// on strong buy/sell — self-contained (doesn't touch the board `symbols` or its
    /// sample/cache flags), so it stays honest (it fires only on quotes it just fetched) and
    /// cheap (no 250-name pull). Same NEW-or-flipped dedup as runCycle via `lastAlerted`.
    @discardableResult
    func runWatchlistCycle(_ watch: [String], notify: Bool = true) async -> [StockSageSignal] {
        let quotes = await StockSageQuoteService.fetchQuotes(for: watch)
        var strong: [StockSageSignal] = []
        var nowStrong: [String: StockSageRecommendation] = [:]
        for ticker in watch {
            guard let q = quotes[ticker.uppercased()], q.price > 0, q.previousClose > 0 else { continue }
            let sym = StockSageSymbol(symbol: ticker, market: "★ My watchlist", quotes: [
                StockSageQuote(price: q.previousClose, previousPrice: q.previousClose,
                               time: Date(timeIntervalSinceNow: -86_400)),
                StockSageQuote(price: q.price, previousPrice: q.previousClose),
            ])
            guard let signal = StockSageSignalEngine.generateSignal(for: sym) else { continue }
            guard signal.recommendation == .strongBuy || signal.recommendation == .strongSell else { continue }
            strong.append(signal)
            nowStrong[signal.symbol] = signal.recommendation
            if notify, lastAlerted[signal.symbol] != signal.recommendation {
                await sendAlert(signal: signal, market: sym.market)
            }
        }
        if notify { for (s, r) in nowStrong { lastAlerted[s] = r } }
        return strong
    }

    private func sendAlert(signal: StockSageSignal, market: String) async {
        let content = UNMutableNotificationContent()
        content.title = "\(signal.recommendation.rawValue): \(signal.symbol) (\(market))"
        content.body = signal.reason
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
