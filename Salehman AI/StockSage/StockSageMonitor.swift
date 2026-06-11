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
                await self?.runCycle()
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
        var strong: [StockSageSignal] = []
        for symbol in StockSageStore.shared.fetchAllSymbols() {
            guard let signal = StockSageSignalEngine.generateSignal(for: symbol) else { continue }
            guard signal.recommendation == .strongBuy || signal.recommendation == .strongSell else { continue }
            strong.append(signal)
            if notify {
                await sendAlert(signal: signal, market: symbol.market)
            }
        }
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
