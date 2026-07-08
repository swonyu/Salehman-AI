import Foundation
import Combine

/// One ranked trade idea: a symbol joined with the advisor's verdict on its real
/// candle history. What the "Ideas" board renders.
struct StockSageIdea: Sendable, Equatable, Identifiable {
    let symbol: String
    let market: String
    let price: Double
    let advice: TradeAdvice
    /// Downsampled recent closes for the inline sparkline (newest last).
    let spark: [Double]
    /// Typical TRUE one-day move (avg |Δ| of the raw daily closes), if known. The `spark` is
    /// down-sampled (~2 calendar days/point), so deriving a daily move from it doubles velocity;
    /// this carries the un-downsampled value for the velocity/hold estimate. nil ⇒ fall back to spark.
    let dailyMove: Double?
    /// Annualized realized volatility from the RAW daily closes (not the down-sampled spark, which
    /// would overstate it). Lets the allocator vol-target like the advisor does. nil ⇒ no shrink.
    let realizedVol: Double?
    var id: String { symbol }

    /// Per-symbol vol regime computed from the raw close history. nil when history is too short
    /// (<273 bars). The `sizingMultiplier` is applied by StockSageCapitalAllocator after Kelly sizing.
    let volRegime: VolRegime?

    /// When this idea's advice was computed against a live quote — nil for ideas built without
    /// one (tests, older persisted state). Stop/target are fixed numbers against THAT quote;
    /// viewing the idea later, the market has moved and R:R has silently drifted. nil ⇒ no
    /// "computed at" note is shown (HONESTY_FLOOR: only claim a timestamp we actually have).
    let generatedAt: Date?

    /// 0–1 read on whether SHORT-HORIZON momentum is genuinely hot right now, as computed by
    /// `StockSageExpectedValue.momentumQuality(for:closes:)` from the RAW daily close history.
    /// nil ⇒ history was too short for ANY of the three internal signals (the spark is down-sampled
    /// and cannot substitute here). NEVER defaults to a number — nil means unknown, not neutral.
    let momentumQuality: Double?

    /// Whether the LATEST close sits at the running high/low of the RAW (un-downsampled) recent
    /// window — the "At N-day high/low" chip's honesty fix (L1, 2026-07-07): the chip used to
    /// call `SparkSeries.extreme(spark)` on the DOWNSAMPLED spark array (≤32 of up to 63 points),
    /// so a true high/low on a day the downsample skipped could be missed, silently making the
    /// claim false vs the actual last-63-day window. Computed here from the RAW closes so the
    /// displayed chip is genuinely honest about the full window it claims. nil means
    /// not computed (default init); buildIdeas always sets a value — `.neither` when the
    /// window has fewer than 2 closes.
    let recentExtreme: SparkSeries.Extreme?
    /// The actual window length `recentExtreme` was computed over — `min(closes.count, 63)`.
    /// Carried alongside `recentExtreme` so the chip can label "At N-day high/low" with the
    /// TRUE N (days, not downsampled bars) rather than assuming a fixed 63.
    let recentExtremeSpan: Int?

    nonisolated init(symbol: String, market: String, price: Double, advice: TradeAdvice,
                     spark: [Double], dailyMove: Double? = nil, realizedVol: Double? = nil,
                     volRegime: VolRegime? = nil, generatedAt: Date? = nil,
                     momentumQuality: Double? = nil, recentExtreme: SparkSeries.Extreme? = nil,
                     recentExtremeSpan: Int? = nil) {
        self.symbol = symbol; self.market = market; self.price = price
        self.advice = advice; self.spark = spark; self.dailyMove = dailyMove
        self.realizedVol = realizedVol; self.volRegime = volRegime; self.generatedAt = generatedAt
        self.momentumQuality = momentumQuality; self.recentExtreme = recentExtreme
        self.recentExtremeSpan = recentExtremeSpan
    }
}

// MARK: - StockSageStore
//
// In-memory store for tracked symbols. Reworked from the package's SwiftData
// `MarketStore` (renamed to avoid colliding with Chat A's `MarketStore` in
// `Views/MarketsStub.swift`, and de-SwiftData'd to drop the force-try container
// init).
//
// **Data source:** the StockSage v32 package shipped NO live price feed, so this
// store starts from a small, clearly-labeled SAMPLE set purely so the signal /
// briefing / monitor layers are demonstrable end-to-end. When Chat A's Phase-2
// Yahoo Finance feed lands, replace `seedSampleData()` with real fetches — every
// downstream layer is data-source-agnostic and just consumes `StockSageSymbol`s.
@MainActor
final class StockSageStore: ObservableObject {
    static let shared = StockSageStore()

    @Published private(set) var symbols: [StockSageSymbol] = []
    /// Distinguishes the built-in demo data from a real feed, so the UI/tool can
    /// say "sample data" honestly rather than implying live quotes.
    @Published private(set) var isSampleData = true
    /// True when the board is seeded from the DISK CACHE (real last-good prices) rather
    /// than sample data or a live fetch — cleared on the next successful refresh.
    @Published private(set) var loadedFromCache = false
    /// When the cached snapshot was saved (for an honest "last good as of …" label).
    @Published private(set) var cacheSavedAt: Date?

    /// When the last successful live refresh completed (nil = still on the sample
    /// seed). Drives the "updated HH:mm" status in the Markets header.
    @Published private(set) var lastUpdated: Date?
    /// The newest quote MARKET timestamp from the last refresh (not our fetch time) — so the banner
    /// can tell genuinely-live prices from a days-old weekend/holiday close. nil when unknown.
    /// NOTE: this is the max across ALL symbols, so always-on crypto keeps it ≈ now — use
    /// `closeableQuoteAsOf` for the "is the (mostly equity) board live?" question.
    @Published private(set) var quoteAsOf: Date?

    /// Freshest market time among CLOSEABLE (non-24/7) assets — equities/indices/FX. The "live" banner
    /// keys off THIS, not the global `quoteAsOf`, so a 24/7 crypto quote can't make a days-old weekend
    /// equity board read "live". nil when no closeable asset carries a market time (e.g. an all-crypto
    /// board) → the caller treats that as not-stale, since crypto genuinely is live.
    static func closeableQuoteAsOf(_ symbols: [StockSageSymbol]) -> Date? {
        symbols.filter { StockSageAllocation.assetClass($0.symbol) != "Crypto" }
            .compactMap { $0.latest?.marketTime }.max()
    }
    var closeableQuoteAsOf: Date? { Self.closeableQuoteAsOf(symbols) }
    /// True while a live fetch is in flight — spins the refresh control.
    @Published private(set) var isRefreshing = false
    /// Human-readable reason the last refresh produced no live data (offline,
    /// web access off, feed unreachable). nil when the feed is healthy.
    @Published private(set) var feedError: String?

    // Advice/ideas — the advisor run across the universe on real candle history.
    @Published private(set) var ideas: [StockSageIdea] = []
    @Published private(set) var isLoadingIdeas = false
    /// Live fetch progress during refreshIdeas: (current, total) symbol count. nil when idle.
    /// UNIT: `current` counts symbols ATTEMPTED so far (cache-served + fetch-attempted,
    /// hit or miss) — NOT symbols successfully priced. Monotonically non-decreasing within a
    /// scan by construction (see `performRefreshIdeas`'s `attemptedSoFar`/`priorAttempted`);
    /// do not feed a priced-only count into this without re-checking that invariant.
    @Published private(set) var ideasProgress: (current: Int, total: Int)?
    /// In-flight ideas-refresh task, retained so the UI can cancel it (backlog #12).
    private var ideasRefreshTask: Task<Void, Never>?
    @Published private(set) var ideasUpdated: Date?
    @Published private(set) var ideasError: String?
    /// What changed vs the last FULL scan (symbol → .new/.actionChanged) — WRITTEN ONLY by
    /// performRefreshIdeas; a partial retry or the QA seed must never touch this (see
    /// PLAN_2026-07-07_scan_deltas.md). Absent baseline ⇒ empty (first-run honesty rule).
    @Published private(set) var scanDeltas: [String: ScanDelta] = [:]
    /// Symbols the last analysis couldn't fetch history for (feed miss / rate-limit) —
    /// surfaced so the board never silently ranks on a partial universe.
    @Published private(set) var ideasMissing: [String] = []
    /// THROTTLE FALLBACK SCAFFOLD (Stage 1, PLAN_2026-07-08_equity2000.md): true when a
    /// chunk beyond the first returned < 30% coverage (429-storm signature) and the scan
    /// stopped launching further chunks. Completed chunks' results stay on the board;
    /// `ideasMissing` names the rest. At today's n=210 (single-ish chunk) this is dormant —
    /// exercised via `StockSageScanChunking.shouldThrottle` in tests, not reachable live yet.
    @Published private(set) var scanThrottled = false

    /// Signal alerts — events (flips, stop/target crossings) detected between
    /// successive Ideas refreshes. Opt-in (off by default); a capped event log.
    @Published var alertsEnabled = false
    @Published private(set) var alerts: [IdeaAlert] = []
    private static let maxAlerts = 50

    func clearAlerts() { alerts = [] }

    // User-added watchlist tickers (beyond the curated universe), persisted.
    @Published private(set) var userSymbols: [String] = []
    @Published private(set) var isAddingSymbol = false
    @Published private(set) var addSymbolError: String?
    private static let userSymbolsKey = "stocksage_user_symbols"
    private static let userMarketLabel = "★ My watchlist"

    // User-set price alerts (target levels), persisted as JSON.
    @Published private(set) var priceAlerts: [PriceAlert] = []
    private static let priceAlertsKey = "stocksage_price_alerts"

    private init() {
        userSymbols = (UserDefaults.standard.array(forKey: Self.userSymbolsKey) as? [String]) ?? []
        priceAlerts = Self.loadPriceAlerts()
        seedSampleData()
        loadCachedQuotes()   // prefer real last-good prices over the sample seed when we have them
    }

    // MARK: Price alerts (user-set target levels)

    private static func loadPriceAlerts() -> [PriceAlert] {
        guard let data = UserDefaults.standard.data(forKey: priceAlertsKey),
              let decoded = try? JSONDecoder().decode([PriceAlert].self, from: data) else { return [] }
        return decoded
    }

    private func savePriceAlerts() {
        if let data = try? JSONEncoder().encode(priceAlerts) {
            UserDefaults.standard.set(data, forKey: Self.priceAlertsKey)
        }
    }

    func addPriceAlert(symbol: String, target: Double, direction: PriceAlert.Direction) {
        let up = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !up.isEmpty, target > 0 else { return }
        // Dedupe: don't stack an identical armed alert (a card's bell can be tapped twice).
        guard !priceAlerts.contains(where: {
            $0.isArmed && $0.symbol == up && $0.target == target && $0.direction == direction
        }) else { return }
        priceAlerts.append(PriceAlert(symbol: up, target: target, direction: direction))
        savePriceAlerts()
    }

    func removePriceAlert(_ id: UUID) {
        priceAlerts.removeAll { $0.id == id }
        savePriceAlerts()
    }

    /// Re-arm a triggered alert so it can fire again.
    func resetPriceAlert(_ id: UUID) {
        guard let i = priceAlerts.firstIndex(where: { $0.id == id }) else { return }
        priceAlerts[i].triggeredAt = nil
        savePriceAlerts()
    }

    /// Mark alerts triggered (one-shot). Called by the Monitor after it fires them.
    func markPriceAlertsTriggered(_ ids: [UUID], at when: Date = Date()) {
        guard !ids.isEmpty else { return }
        let set = Set(ids)
        for i in priceAlerts.indices where set.contains(priceAlerts[i].id) {
            priceAlerts[i].triggeredAt = when
        }
        savePriceAlerts()
    }

    /// Pure reconcile step for the new-listing badge set (L3-03, 2026-07-07 audit). Given the
    /// CURRENT set and a batch of freshly-priced quotes, returns the set with each quote's symbol
    /// inserted when the feed says `isNewListing == true` and removed when it says `false` —
    /// symmetric, so a stale flag also clears once the feed stops reporting the symbol as new.
    /// Never infers the flag: the only source of truth is `LiveQuote.isNewListing` itself.
    /// `nonisolated static` and side-effect-free so it's unit-testable without the
    /// `@MainActor` singleton (`mergeLiveQuotes`/`addSymbol` are its only callers).
    nonisolated static func reconcileNewListings(
        current: Set<String>, pricedQuotes: [String: StockSageQuoteService.LiveQuote]
    ) -> Set<String> {
        var result = current
        for (sym, q) in pricedQuotes {
            if q.isNewListing {
                result.insert(sym)
            } else {
                result.remove(sym)
            }
        }
        return result
    }

    /// Merge freshly-fetched live quotes into the matching board rows (used by the
    /// watchlist-only monitor so those names show live prices even though the full
    /// auto-refresh is paused). Deliberately does NOT flip isSampleData/loadedFromCache or
    /// `lastUpdated` — it only updates the rows it has, so the board never over-claims that
    /// the WHOLE snapshot is live.
    func mergeLiveQuotes(_ quotes: [String: StockSageQuoteService.LiveQuote]) {
        guard !quotes.isEmpty else { return }
        symbols = symbols.map { s in
            guard let q = quotes[s.symbol.uppercased()], q.price > 0 else { return s }
            return StockSageSymbol(symbol: s.symbol, market: s.market, quotes: [
                StockSageQuote(price: q.previousClose, previousPrice: q.previousClose,
                               time: Date(timeIntervalSinceNow: -86_400)),
                StockSageQuote(price: q.price, previousPrice: q.previousClose, marketTime: q.marketTime),
            ])
        }
        // Thread the new-listing flag through the watchlist-only path too: refresh() was previously
        // the ONLY writer of `newListings`, so with auto-refresh paused a genuinely new listing
        // merged here could never get its badge.
        let priced = quotes.filter { $0.value.price > 0 }
        newListings = Self.reconcileNewListings(current: newListings, pricedQuotes: priced)
        // Advance freshness if these merged quotes are newer (watchlist-only path also keeps it honest).
        if let newest = quotes.values.compactMap(\.marketTime).max() {
            quoteAsOf = [quoteAsOf, newest].compactMap { $0 }.max()
        }
    }

    /// Seed the board from the disk cache (last successful quotes) so launch shows real
    /// last-good numbers instantly + works offline, instead of fabricated sample data.
    private func loadCachedQuotes() {
        guard let cache = StockSageQuoteCache.load(), !cache.entries.isEmpty else { return }
        let labels = Dictionary(trackedDefs().map { ($0.symbol.uppercased(), $0.market) },
                                uniquingKeysWith: { a, _ in a })
        symbols = cache.symbols(marketFor: { labels[$0.uppercased()] ?? Self.userMarketLabel })
        isSampleData = false
        loadedFromCache = true
        cacheSavedAt = cache.savedAt
        // Restore the brand-new-listing flag from the reloaded cache entries — without this a
        // cached placeholder-flat row (real previousClose unknown) silently reads as a genuine
        // 0%-move "hold" after relaunch, before any live refresh has re-derived it.
        newListings = Set(cache.entries.filter(\.isNewListing).map { $0.symbol.uppercased() })
    }

    /// Every tracked instrument definition: the curated universe + the user's
    /// added tickers (deduped). Drives both the live feed and the ideas analysis,
    /// so user picks survive refreshes and get analyzed too.
    private func trackedDefs() -> [StockSageSymbol] {
        var defs = StockSageUniverse.worldwide
        let known = Set(defs.map { $0.symbol.uppercased() })
        for s in userSymbols where !known.contains(s.uppercased()) {
            defs.append(StockSageSymbol(symbol: s, market: Self.userMarketLabel))
        }
        return defs
    }

    /// Pure validation/normalization for a user-typed ticker. Returns the
    /// normalized symbol (or nil) and a rejection reason (or nil). Testable.
    static func validateNewSymbol(_ raw: String, alreadyTracked: Set<String>) -> (symbol: String?, error: String?) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty else { return (nil, "Enter a ticker.") }
        guard s.count <= 20, !s.contains(" ") else { return (nil, "That doesn't look like a ticker.") }
        guard !alreadyTracked.contains(s) else { return (nil, "\(s) is already tracked.") }
        return (s, nil)
    }

    /// Validate a typed ticker against a LIVE quote; if it prices, add it to the
    /// persisted watchlist and show it immediately. Honest rejection otherwise.
    func addSymbol(_ raw: String) async {
        guard !isAddingSymbol else { return }
        let tracked = Set(userSymbols.map { $0.uppercased() })
            .union(StockSageUniverse.worldwide.map { $0.symbol.uppercased() })
        let validation = Self.validateNewSymbol(raw, alreadyTracked: tracked)
        guard let symbol = validation.symbol else { addSymbolError = validation.error; return }
        if let reason = ToolPolicy.webToolsDisabledReason() { addSymbolError = reason; return }

        isAddingSymbol = true
        addSymbolError = nil
        let quotes = await StockSageQuoteService.fetchQuotes(for: [symbol])
        isAddingSymbol = false
        guard let q = quotes[symbol] else {
            addSymbolError = "Couldn't find a tradeable price for “\(symbol)”. Check the ticker (e.g. AAPL, 2222.SR, BTC-USD)."
            return
        }
        userSymbols.append(symbol)
        UserDefaults.standard.set(userSymbols, forKey: Self.userSymbolsKey)
        // Show it on the board now, without disturbing the sample/live flag.
        let added = StockSageSymbol(symbol: symbol, market: Self.userMarketLabel, quotes: [
            StockSageQuote(price: q.previousClose, previousPrice: q.previousClose, time: Date(timeIntervalSinceNow: -86_400)),
            StockSageQuote(price: q.price, previousPrice: q.previousClose),
        ])
        symbols = symbols.filter { $0.symbol.uppercased() != symbol } + [added]
        // Thread the new-listing flag through here too (L3-03, 2026-07-07 audit) — same reconcile
        // rule mergeLiveQuotes uses, never set without the feed itself saying isNewListing==true.
        newListings = Self.reconcileNewListings(current: newListings, pricedQuotes: [symbol: q])
    }

    /// Remove a user-added ticker (no-op for curated-universe symbols).
    func removeSymbol(_ symbol: String) {
        let up = symbol.uppercased()
        guard userSymbols.contains(where: { $0.uppercased() == up }) else { return }
        userSymbols.removeAll { $0.uppercased() == up }
        UserDefaults.standard.set(userSymbols, forKey: Self.userSymbolsKey)
        symbols = symbols.filter { $0.symbol.uppercased() != up }
    }

    /// Analyze the worldwide universe on real 1-year candle history and rank the
    /// results into actionable ideas (strongest buys first). Heavy (one history
    /// fetch per symbol), so it's user-triggered, never automatic. Non-destructive
    /// on failure. No-op-with-reason when external access is off.
    func refreshIdeas() async {
        guard !isLoadingIdeas else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            ideasError = reason
            return
        }
        isLoadingIdeas = true
        defer { isLoadingIdeas = false }   // clears on EVERY path: success, feed-failure early-return, AND cancel
        let task = Task { await self.performRefreshIdeas() }
        ideasRefreshTask = task
        // The 120s watchdog is now PER-CHUNK (armed inside performRefreshIdeas around each
        // chunk's fetch+build) rather than one clock for the whole scan — a stall kills the
        // current chunk, not chunks already committed. This outer task has no watchdog of its
        // own; it simply awaits the (self-bounding) chunked work.
        await task.value                   // keep refreshIdeas awaitable so callers see populated `ideas`
        ideasRefreshTask = nil
    }

    /// The heavy ideas scan, run as a cancellable child task. MainActor-isolated (inherited),
    /// so no actor hops are added. Cancellation (from `cancelIdeasRefresh` or a chunk watchdog)
    /// stops it applying stale results.
    ///
    /// CHUNKED PROGRESSIVE SCAN (PLAN_2026-07-08_equity2000.md Stage 1): `trackedDefs()` is
    /// split into `StockSageScanChunking.chunks` (~250 wide; chunk 0 is always the array's
    /// natural head, so the curated Saudi-first core scans and appears on the board first).
    /// Each chunk is fetched, built, and MERGED into `ideas` independently — replace-by-symbol,
    /// re-sorted, board published — so the board grows live instead of waiting for the whole
    /// universe. At today's n=210 universe this is a SINGLE chunk, so the merge loop runs once
    /// and the observable behavior is byte-identical to the pre-chunking single-shot scan.
    /// SCAN-END-ONCE semantics (delta baseline with the DEG-01 missing-but-tracked carry-forward,
    /// missingAfterScan, history-cache save, paper trades, earnings kick, and alert detection)
    /// all run exactly once, after the FINAL chunk, over the accumulated full-scan result —
    /// never per chunk. (`newListings` is untouched here, matching the pre-chunking scan —
    /// this store's ideas path has never written it; only the separate quote-refresh path does.)
    private func performRefreshIdeas() async {
        ideasError = nil
        scanThrottled = false
        let universe = trackedDefs()
        let total = universe.count
        ideasProgress = (current: 0, total: total)
        defer { ideasProgress = nil }   // clear on EVERY exit (success + the cancel/feed-failure early-returns), not just success

        // PERF FIX (review round 1): `.load()` decodes the whole multi-MB on-disk JSON cache
        // synchronously — hoisted into a detached task so that decode runs off the MainActor
        // instead of blocking it once per scan. `nonisolated static func`, so no actor hop is
        // needed to call it from a detached context. Same one-load-per-scan cadence as before.
        let cache = await Task.detached { StockSageHistoryCache.load() }.value
        // Reconstructed ONCE here (was rebuilt from `cache?.priceHistories()` inside the chunk
        // loop on every iteration — an O(chunks) re-decode of the same dictionary for a value
        // that never changes across chunks within one scan).
        let cachePriceHistories = cache?.priceHistories() ?? [:]
        let cal = convictionCalibration                           // read on the main actor before ANY await
        let journalTrades = StockSageJournalStore.shared.trades   // read on the main actor before ANY await
        // Benchmark fetched ONCE up front, shared by every chunk's buildIdeas call.
        let benchmark = await StockSageQuoteService.fetchHistory("^GSPC", range: "1y")
        guard !Task.isCancelled else { return }

        // ALERTS FIX (review round 1): snapshot the board BEFORE the chunk loop starts
        // publishing. The loop below does `ideas = ranked` after EVERY chunk merges (so the
        // board grows live) — if alert-detect compared against `ideas` read AFTER the loop, it
        // would be comparing the final board to itself (detect(new, new) never fires; alerts
        // went dead). `preScanBoard` is the one-and-only "previous" for this scan, taken before
        // any chunk publish. The first-ever-scan skip guard below keys on `!preScanBoard.isEmpty`
        // (not `!ideas.isEmpty`, which by scan-end has already been overwritten) — same "don't
        // alert on the very first population" semantics as the legacy single-shot scan.
        let preScanBoard = ideas

        let chunks = StockSageScanChunking.chunks(universe)
        var accumulatedHistories: [String: StockSagePriceHistory] = [:]
        var ranked: [StockSageIdea] = []
        var firstChunkTotallyFailed = false
        // Running "attempted" total across completed chunks — same unit `ideasProgress.current`
        // is displayed in (see priorAttempted's doc comment below); NOT the priced count.
        var attemptedSoFar = 0

        for (chunkIndex, chunkDefs) in chunks.enumerated() {
            guard !Task.isCancelled else { break }

            // CACHE-AWARE SKIP (plan step 3): serve today's-already-fresh symbols from disk,
            // fetch only the rest. `cache == nil` (no cache yet) ⇒ everyone fetches, same as before.
            let symbols = chunkDefs.map(\.symbol)
            let (fromCache, toFetch) = StockSageScanChunking.partitionByCacheFreshness(symbols: symbols, cache: cache)
            var cachedHistories: [String: StockSagePriceHistory] = [:]
            for sym in fromCache {
                if let h = cachePriceHistories[sym.uppercased()] { cachedHistories[sym.uppercased()] = h }
            }

            // PER-CHUNK 120s watchdog: races this chunk's fetch+build against a timer. A timeout
            // cancels the chunk's own child task (not the whole scan) — completed chunks before
            // it stay committed; this chunk's (and every later chunk's) symbols land in
            // ideasMissing via the scan-end-once missingAfterScan derivation.
            //
            // PROGRESS UNIT (review round 1 fix): `ideasProgress.current` counts symbols
            // ATTEMPTED so far, not symbols successfully priced — `fetchHistories`'s onProgress
            // fires per attempted batch regardless of hits/misses (`completed += chunk.count`),
            // so mixing it with a priced-only count (as the post-merge update below used to do
            // via `accumulatedHistories.count`) could step the counter BACKWARD the moment a
            // chunk had any fetch misses. `priorAttempted` is this chunk's starting point in the
            // same attempted-units space: every earlier chunk's full `symbols.count` (whether
            // served from cache or fetched, all of it was "accounted for") plus this chunk's own
            // cache hits (already known, not going through the fetch progress callback).
            let priorAttempted = attemptedSoFar + cachedHistories.count
            let chunkWork = Task { () -> (histories: [String: StockSagePriceHistory], built: [StockSageIdea]) in
                let fetched = await StockSageQuoteService.fetchHistories(for: toFetch, onProgress: { [weak self] n in
                    self?.ideasProgress = (current: priorAttempted + n, total: total)
                })
                let merged = cachedHistories.merging(fetched) { _, new in new }
                guard !merged.isEmpty else { return (merged, []) }
                let built = await Self.buildIdeas(defs: chunkDefs, histories: merged, benchmark: benchmark,
                                                  calibration: cal, journalTrades: journalTrades)
                return (merged, built)
            }
            let chunkWatchdog = Task {
                try? await Task.sleep(for: .seconds(120))
                if !Task.isCancelled { chunkWork.cancel() }
            }
            // CANCEL FIX (review round 1): `chunkWork` is an UNSTRUCTURED Task — Swift does not
            // preemptively tear it down when the parent scan task is cancelled, it only flips
            // the flag `chunkWork` would see if it checked `Task.isCancelled` itself (it doesn't;
            // fetchHistories/buildIdeas run to completion regardless). Forward the parent's
            // cancellation into the chunk explicitly so a mid-chunk `cancelIdeasRefresh()` stops
            // the fetch/build promptly instead of silently finishing a chunk nobody wants.
            if Task.isCancelled { chunkWork.cancel() }
            let (chunkHistories, built) = await chunkWork.value
            chunkWatchdog.cancel()
            let chunkTimedOut = chunkWork.isCancelled

            // Re-check AFTER the await, BEFORE any merge/publish: cancellation can also land
            // WHILE we were awaiting chunkWork (not just before it started). Matches the legacy
            // single-shot scan's shape — one `guard !Task.isCancelled` right after the awaited
            // fetch+build, before `ideas`/`ideasMissing`/anything else is touched — so a
            // cancelled scan NEVER commits a half-built chunk and never runs the scan-end
            // reconcile tail (stillTracked filter, alert detect, snapshot save) on a partial
            // result. `ideasProgress` still clears via the outer `defer`; `isLoadingIdeas` clears
            // via `refreshIdeas`'s defer. The board is left exactly as the LAST fully-committed
            // chunk (or the pre-scan snapshot, if cancelled before chunk 0 finished) — the same
            // "last consistent state" contract the pre-chunking scan gave a mid-fetch cancel.
            guard !Task.isCancelled else { return }

            let attempted = symbols.count
            let priced = chunkHistories.count

            if chunkIndex == 0 {
                // Legacy total-failure path — the FIRST chunk's coverage-guard/empty-feed bail
                // is the pre-chunking behavior verbatim: a fully-failed first chunk aborts the
                // whole scan (nothing to show, nothing to merge).
                guard !chunkHistories.isEmpty else {
                    firstChunkTotallyFailed = true
                    break
                }
            } else if StockSageScanChunking.shouldThrottle(chunkIndex: chunkIndex, priced: priced, attempted: attempted) {
                // THROTTLE FALLBACK SCAFFOLD (plan step 5): a later chunk cratered (<30%
                // coverage, the 429-storm signature) — stop launching further chunks. This
                // chunk's own partial results still merge below (partial success is honest
                // success); only chunks AFTER this one never launch.
                scanThrottled = true
            }

            accumulatedHistories.merge(chunkHistories) { _, new in new }
            attemptedSoFar += attempted   // whole chunk now accounted for, hit or miss
            ideasProgress = (current: attemptedSoFar, total: total)   // same attempted-unit space as priorAttempted above

            if !built.isEmpty {
                // MERGE (retryFailedIdeas' precedent, shared via StockSageScanChunking.mergeChunk):
                // replace-by-symbol, then re-sort. The post-await stillTracked reconcile runs once,
                // at scan end, over the final `ranked`.
                ranked = StockSageScanChunking.mergeChunk(current: ranked, newlyBuilt: built, rankScore: Self.rankScore)
                ideas = ranked   // publish — board grows live as each chunk merges in
            }

            if chunkTimedOut || (chunkIndex > 0 && scanThrottled) { break }
        }

        if firstChunkTotallyFailed {
            ideasError = "Couldn't reach the market feed for analysis — try again."
            return
        }
        guard !Task.isCancelled else { return }
        // A watchdog timeout or throttle trip needs no branch here — either way, everything
        // below runs over whatever chunks DID complete: "stop launching more chunks" is not
        // "discard what we have" (partial success is honest success, same as any individual
        // symbol's fetch failure).

        // Persist ALL histories fetched across every chunk this scan for OFFLINE net-cost
        // validation / backtests (StockSageHistoryCache). Best-effort and DETACHED so the JSON
        // encode runs off the main actor and never blocks the commit below; ZERO new network —
        // it saves bytes already downloaded and otherwise discarded after buildIdeas.
        let historyUniverse = Set(universe.map { $0.symbol.uppercased() })
        let historiesToSave = accumulatedHistories
        Task.detached { StockSageHistoryCache.from(histories: historiesToSave, universe: historyUniverse, savedAt: Date()).save() }

        // SCAN-END-ONCE (plan step 2): everything below runs exactly once, over the FULL
        // accumulated result — same order/guards as the pre-chunking single-shot scan.
        //
        // Re-reconcile vs the CURRENT tracked set (mirror refresh() at the liveFiltered step): a
        // removeSymbol() that landed DURING any chunk's await must win, else a pre-await
        // snapshot resurrects a dropped ticker into ranked ideas AND the capital allocator.
        let stillTracked = Set(trackedDefs().map { $0.symbol.uppercased() })
        let finalRanked = ranked.filter { stillTracked.contains($0.symbol.uppercased()) }
            .sorted { Self.rankScore($0.advice) > Self.rankScore($1.advice) }
        // Detect alert events vs the PRE-SCAN snapshot (taken before the loop's mid-scan
        // publishes) — once, vs the full board. Using `ideas` here would compare the
        // just-published finalRanked to itself (see preScanBoard's doc comment above).
        if alertsEnabled, !preScanBoard.isEmpty {
            let fired = StockSageAlerts.detect(previous: preScanBoard, current: finalRanked)
            if !fired.isEmpty { alerts = Array((fired + alerts).prefix(Self.maxAlerts)) }
        }
        // Partial success is honest success: keep the names that priced, and NAME the ones that
        // didn't so the EV ranking isn't silently computed on a subset.
        let analyzed = Set(finalRanked.map { $0.symbol.uppercased() })
        // Indices are DELIBERATELY skipped by buildIdeas (not buyable) — don't report them as fetch
        // failures, or ~17 healthy index tickers show a permanent "couldn't be fetched" with a retry
        // button that can never clear.
        let missing = Self.missingAfterScan(universe: universe.map(\.symbol),
                                            analyzed: analyzed, stillTracked: stillTracked)
        ideasMissing = missing
        // Scan deltas ("New" / "was <Action>" chips): compute vs the PRE-refresh persisted
        // baseline, THEN persist the new scan's map as the next baseline. Only this full-scan
        // commit writes the snapshot — retryFailedIdeas (partial) and seedQAIdeas (QA fixture)
        // deliberately never call save() (PLAN_2026-07-07_scan_deltas.md).
        let snapshotStore = StockSageScanSnapshotStore.shared
        scanDeltas = StockSageScanDelta.deltas(current: finalRanked, previous: snapshotStore.entries)
        // DEG-01: symbols missing-but-still-tracked (feed miss/429 THIS scan) carry their PRIOR
        // baseline entry forward instead of dropping out — see nextBaseline's doc comment.
        let nextBaseline = StockSageScanDelta.nextBaseline(ranked: finalRanked, missingButTracked: missing,
                                                            previous: snapshotStore.entries)
        snapshotStore.save(entries: nextBaseline)
        ideas = finalRanked
        // FORWARD PAPER TRADING: auto-open a fake-money position for each long-actionable idea and mark
        // existing open paper trades to the fresh histories (net-of-cost). Separate store, never conflated
        // with the real journal; does NOT feed win-rate calibration (F01/F02). Best-effort, synchronous.
        updatePaperTrades(ideas: finalRanked, histories: accumulatedHistories)
        // Populate earnings for the top names (non-blocking) so the imminent-earnings demotion +
        // warnings fire on the boards, not only on detail-expand. Cached-once → cheap after first load.
        Task { await refreshEarningsForTopIdeas() }
        ideasUpdated = Date()
    }

    /// Cancel an in-flight ideas scan (backlog #12). The outer refreshIdeas defer clears the spinner.
    func cancelIdeasRefresh() { ideasRefreshTask?.cancel() }

    /// Advance the forward PAPER-trading harness (fake money, honest net-of-cost). Runs after each ideas
    /// refresh on the MainActor with the just-fetched `histories` + `ideas`: closes any open paper trade a
    /// new bar resolved (stop/target/time-stop), then opens a paper trade for each long-actionable idea
    /// without an open position. All state lives in `StockSagePaperTradeStore` (SEPARATE from the real
    /// journal). Disabled ⇒ byte-identical to no paper trading. Pure orchestration lives in
    /// `StockSagePaperTrader.step`; this is only the thin persistence boundary. F01/F02 fence: paper
    /// outcomes never feed `convictionCalibration`.
    private func updatePaperTrades(ideas: [StockSageIdea], histories: [String: StockSagePriceHistory]) {
        let store = StockSagePaperTradeStore.shared
        guard store.enabled else { return }
        let (closes, opens) = StockSagePaperTrader.step(
            current: store.trades, ideas: ideas, histories: histories, openDate: Date(),
            costsFor: { StockSageNetEdge.defaultCosts(forSymbol: $0) })
        // MEM-01a: one mutation + ONE UserDefaults save instead of a per-call re-encode of the
        // whole (growing) array for every close and every open this cycle.
        store.apply(closes: closes, opens: opens)
    }

    /// Re-fetch ONLY the symbols the last scan couldn't price and merge them in, re-ranking.
    /// Cheap relative to a full refresh; user-triggered from the "Retry failed" affordance.
    func retryFailedIdeas() async {
        guard !isLoadingIdeas, !ideasMissing.isEmpty else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() { ideasError = reason; return }
        isLoadingIdeas = true
        defer { isLoadingIdeas = false }
        ideasError = nil
        let cal = convictionCalibration                           // read on the main actor before the await hop
        let journalTrades = StockSageJournalStore.shared.trades   // read on the main actor before the await hop
        let retrySet = Set(ideasMissing.map { $0.uppercased() })
        // CONCURRENCY #3: ONE universe snapshot BEFORE the await — the missing-list below must
        // be computed against the same set that was scanned, not a fresh post-await read that
        // can contain a just-added (priced, on-board) ticker and falsely banner it as a failure.
        let universe = trackedDefs()
        let defs = universe.filter { retrySet.contains($0.symbol.uppercased()) }
        async let benchmarkTask = StockSageQuoteService.fetchHistory("^GSPC", range: "1y")
        let histories = await StockSageQuoteService.fetchHistories(for: defs.map(\.symbol))
        let benchmark = await benchmarkTask
        guard !histories.isEmpty else {
            ideasError = "Still couldn't reach those symbols — try again later."
            return
        }
        let built = await Self.buildIdeas(defs: defs, histories: histories, benchmark: benchmark,
                                          calibration: cal, journalTrades: journalTrades)
        // MERGE (review round 1, finding 5): now routed through the SAME
        // StockSageScanChunking.mergeChunk the chunked scan uses, so "shared so the chunked
        // scan and the retry path can never drift apart" (mergeChunk's own doc comment) is
        // actually true instead of aspirational. Byte-identical to the prior inline
        // replace-by-symbol-then-resort — mergeChunk's `built.isEmpty` early return is a no-op
        // here because the `stillTracked` filter + re-sort below still runs unconditionally
        // afterward, exactly like the pre-this-change code always did (this call site does its
        // OWN stillTracked filtering; mergeChunk stays a pure symbol-replace-and-resort step
        // with no tracked-set awareness, same contract the chunked scan relies on).
        let replaced = StockSageScanChunking.mergeChunk(current: ideas, newlyBuilt: built, rankScore: Self.rankScore)
        // Re-reconcile vs the current tracked set (mirror refreshIdeas): a removeSymbol() during the
        // retry await must not resurrect the dropped ticker via the pre-await `defs`/`built`.
        let stillTracked = Set(trackedDefs().map { $0.symbol.uppercased() })
        let merged = replaced.filter { stillTracked.contains($0.symbol.uppercased()) }
            .sorted { Self.rankScore($0.advice) > Self.rankScore($1.advice) }
        ideas = merged
        let analyzed = Set(merged.map { $0.symbol.uppercased() })
        ideasMissing = Self.missingAfterScan(universe: universe.map(\.symbol),
                                             analyzed: analyzed, stillTracked: stillTracked)
        // DEG-02: deliberately NOT advancing ideasUpdated here — this path re-analyzes only the
        // FAILED subset, and ideasUpdated drives the whole board's staleness chrome (ideasIsStale
        // chip/dim + its a11y clause). Bumping it on a partial merge would reset that chrome for
        // every card, including ones untouched by this retry. The retried cards' own
        // idea.generatedAt still carries their individual freshness.
    }

    /// CONCURRENCY #3: the "couldn't be fetched" list, derived from ONE pre-await `universe`
    /// snapshot — shared by refreshIdeas AND retryFailedIdeas so the two paths cannot disagree.
    /// A ticker ADDED during the await is absent from `universe` → never falsely bannered as a
    /// fetch failure (the next full refresh scans it); a ticker REMOVED during the await is
    /// dropped via `stillTracked`; indices are never "missing" (not buyable, no idea to build).
    /// Pure + testable (StockSageIdeasMissingTests).
    nonisolated static func missingAfterScan(universe: [String], analyzed: Set<String>,
                                             stillTracked: Set<String>) -> [String] {
        universe.filter {
            stillTracked.contains($0.uppercased()) &&
            !analyzed.contains($0.uppercased()) &&
            StockSageAllocation.assetClass($0) != "Index"
        }
    }

    /// Build ranked ideas off the main actor (the advisor runs every indicator over each
    /// symbol's full year). Pure over its inputs; everything it touches is Sendable.
    nonisolated static func buildIdeas(defs: [StockSageSymbol],
                                       histories: [String: StockSagePriceHistory],
                                       benchmark: StockSagePriceHistory? = nil,
                                       calibration: StockSageConvictionCalibration? = nil,
                                       journalTrades: [TradeRecord] = []) async -> [StockSageIdea] {
        await Task.detached(priority: .userInitiated) {
            var out: [StockSageIdea] = []
            // Sector rotation (HARDENING_BACKLOG #31, reframed flag-only): rank ONCE per
            // buildIdeas call (not per-symbol) and reuse across the loop — same cost profile as
            // `calibration`/`benchmark`. journalTrades defaults to [] so `analyze` returns [] and
            // every per-symbol lookup below is a no-op — omitting it is byte-identical to today.
            let sectorRotation = StockSageSectorRotation.analyze(allTrades: journalTrades)
            for sym in defs {
                guard let history = histories[sym.symbol.uppercased()], let price = history.latestClose else { continue }
                // An index LEVEL (^GSPC/^VIX) is not a buyable instrument — never surface it as a
                // buy/stop/target/size idea (it would also pollute the EV/velocity/allocator math).
                guard StockSageAllocation.assetClass(sym.symbol) != "Index" else { continue }
                // Relative-strength-vs-S&P only means something for EQUITIES — pass the benchmark only
                // there so FX/crypto don't get a meaningless "Leading/Lagging the S&P" term (and an
                // index never benchmarks against itself, now moot since indices are excluded above).
                let bench = StockSageAllocation.assetClass(sym.symbol) == "Equity" ? benchmark : nil
                var advice = StockSageAdvisor.advise(history: history, benchmark: bench)
                // Re-size on the CALIBRATED win-prob (advise() used the conservative linear prior — it
                // is pure and can't see the runtime calibration). nil calibration ⇒ recompute returns the
                // SAME prior weight, so the value is unchanged. Only suggestedWeight differs; the
                // directional score, action, conviction, stop and target are advise()'s deterministic output.
                if let calibration {
                    // Realized vol from the FULL raw closes (matches the advisor) for vol-targeting.
                    let realizedVolForSizing = StockSageIndicators.annualizedVolatility(history.closes)
                    let calibratedWeight = StockSageAdvisor.suggestedWeight(
                        action: advice.action, conviction: advice.conviction, price: price,
                        stop: advice.stopPrice, target: advice.targetPrice,
                        realizedVol: realizedVolForSizing, calibration: calibration)
                    advice = TradeAdvice(action: advice.action, conviction: advice.conviction,
                                         regime: advice.regime, rationale: advice.rationale,
                                         stopPrice: advice.stopPrice, targetPrice: advice.targetPrice,
                                         suggestedWeight: calibratedWeight, caveat: advice.caveat,
                                         stopMultiplier: advice.stopMultiplier, stopReason: advice.stopReason,
                                         timeframeAligned: advice.timeframeAligned, confluenceNote: advice.confluenceNote)
                }
                // Honesty-only risk reads (EDGE_RESEARCH #4/#5): flag-only notes appended to the
                // rationale shown in the detail-sheet "Why" ForEach. NOT a sizing/score input —
                // advise() is untouched. Computed once per idea here, never in the bar-by-bar backtester.
                var extraNotes: [String] = []
                if let shape = StockSageReturnShape.returnShape(closes: history.closes), shape.isLeftTailed {
                    extraNotes.append("⚠ Left-tailed history — worst days exceed what its volatility implies; your stop may gap. " + shape.note)
                }
                if let stab = StockSageVolStability.volStability(closes: history.closes) {
                    if case .erratic = stab.band {
                        extraNotes.append("⚠ Whippy volatility — stop width / size are less reliable here; trade smaller. " + stab.note)
                    }
                }
                // Vol regime brake (EDGE_RESEARCH #1): flag in "Why" + applies sizingMultiplier in allocator.
                let volRegime = StockSageVolRegime.regime(closes: history.closes)
                if let vr = volRegime, vr.sizingMultiplier < 0.95 {
                    extraNotes.append("⚠ " + vr.note)
                }
                // Sector-rotation confirmation (HARDENING_BACKLOG #31, reframed flag-only — see
                // StockSageSectorRotation.swift header). Surfaced note ONLY: `advice.conviction`,
                // `.suggestedWeight`, `.stopPrice`, `.targetPrice` are untouched below, exactly
                // like the ReturnShape/VolStability blocks above.
                if let rotation = sectorRotation.first(where: { $0.sector == StockSageSector.sector(sym.symbol) }),
                   rotation.isRotatingIn {
                    extraNotes.append("⚠ " + rotation.note)
                }
                // Execution-timing advisory (week-horizon velocity research #2): flag-only, never
                // touches score/conviction/sizing — see StockSageExecutionTiming's header for the
                // evidence and the .bullTrend/.bearTrend-only gate.
                if let timingNote = StockSageExecutionTiming.sessionNote(action: advice.action, regime: advice.regime) {
                    extraNotes.append("⏱ " + timingNote)
                }
                if !extraNotes.isEmpty {
                    advice = TradeAdvice(action: advice.action, conviction: advice.conviction,
                                         regime: advice.regime, rationale: advice.rationale + extraNotes,
                                         stopPrice: advice.stopPrice, targetPrice: advice.targetPrice,
                                         suggestedWeight: advice.suggestedWeight, caveat: advice.caveat,
                                         stopMultiplier: advice.stopMultiplier, stopReason: advice.stopReason,
                                         timeframeAligned: advice.timeframeAligned, confluenceNote: advice.confluenceNote)
                }
                let recent = Array(history.closes.suffix(63))
                let spark = SparkSeries.downsample(recent)
                // True daily move from the UN-downsampled closes (spark points are ~2 days apart).
                let dailyMove = StockSageExpectedValue.typicalDailyMove(recent)
                // Realized vol from the FULL raw closes (matches the advisor) for allocator vol-targeting.
                let realizedVol = StockSageIndicators.annualizedVolatility(history.closes)
                // Momentum quality from the FULL raw closes — requires at least 21 bars for the
                // loosest internal signal (Kaufman efficiencyRatio, period 20 → needs count > 20).
                // When closes are too short for ALL signals, momentumQuality() returns the neutral
                // sentinel 1.0 (no data ⇒ no penalty), which is NOT a real quality score — store
                // nil instead so callers know "unknown" vs a measured value.
                let momentumQuality: Double? = history.closes.count > 20
                    ? StockSageExpectedValue.momentumQuality(for: StockSageIdea(symbol: sym.symbol,
                        market: sym.market, price: price, advice: advice, spark: spark),
                        closes: history.closes)
                    : nil
                // At-the-extreme honesty fix (L1, 2026-07-07): compute over the RAW `recent`
                // window (same array `dailyMove` uses), NOT the downsampled `spark` — a true
                // high/low that downsample skips must not be missed. span = recent.count
                // (min(history.closes.count, 63)) is the ACTUAL window checked, so the chip can
                // say "At N-day high/low" with a real N instead of assuming a fixed 63.
                let recentExtreme = SparkSeries.extreme(recent)
                let recentExtremeSpan = recent.count
                out.append(StockSageIdea(symbol: sym.symbol, market: sym.market,
                                         price: price, advice: advice, spark: spark,
                                         dailyMove: dailyMove, realizedVol: realizedVol,
                                         volRegime: volRegime, generatedAt: Date(),
                                         momentumQuality: momentumQuality,
                                         recentExtreme: recentExtreme, recentExtremeSpan: recentExtremeSpan))
            }
            return out
        }.value
    }

    // Risk-parity — inverse-vol target weights across the owner's holdings.
    @Published private(set) var riskParity: [RiskParityTarget] = []
    /// Holdings excluded from the risk-parity calculation — no fetchable price history, or
    /// non-positive volatility — too sparse to size.
    @Published private(set) var riskParityDropped: [String] = []
    @Published private(set) var isComputingParity = false
    @Published private(set) var parityError: String?

    /// Fetch each holding's history, derive its annualized volatility, and compute
    /// inverse-vol (risk-parity) target weights + rebalance deltas. User-triggered;
    /// non-destructive on failure.
    func refreshRiskParity() async {
        guard !isComputingParity else { return }
        let positions = StockSagePortfolio.shared.positions
        guard !positions.isEmpty else {
            riskParity = []
            parityError = "Add holdings to your portfolio first."
            return
        }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            parityError = reason
            return
        }
        isComputingParity = true
        parityError = nil
        let histories = await StockSageQuoteService.fetchHistories(for: positions.map(\.symbol))
        isComputingParity = false

        let (holdings, dropped) = Self.splitRiskParityHoldings(positions: positions, histories: histories)
        guard !holdings.isEmpty else {
            parityError = "Couldn't get enough history to risk-size the portfolio."
            return
        }
        riskParityDropped = dropped
        riskParity = StockSageRiskParity.targets(holdings)
    }

    /// Pure split of positions into risk-sizeable holdings vs the ones excluded (no fetchable
    /// history, non-positive volatility, or no price) — the exclusion is recorded AT THE POINT
    /// each position fails, not re-derived afterward by filtering the already-filtered
    /// `holdings` array (that predicate could never be true, since everything appended there
    /// already satisfies volatility > 0 by construction). Pure + testable without a network fetch.
    nonisolated static func splitRiskParityHoldings(positions: [PortfolioPosition],
                                                     histories: [String: StockSagePriceHistory])
        -> (holdings: [RiskParityHolding], dropped: [String]) {
        var holdings: [RiskParityHolding] = []
        var dropped: [String] = []
        for p in positions {
            guard let history = histories[p.symbol.uppercased()],
                  let vol = StockSageIndicators.annualizedVolatility(history.closes), vol > 0,
                  let price = history.latestClose else {
                dropped.append(p.symbol)
                continue
            }
            holdings.append(RiskParityHolding(symbol: p.symbol, currentValue: price * p.shares, volatility: vol))
        }
        return (holdings, dropped)
    }

    // Market regime — the risk-on/off meta-gauge.
    @Published private(set) var regime: MarketRegime?
    @Published private(set) var regimeGaugedAt: Date?
    @Published private(set) var isLoadingRegime = false
    @Published private(set) var regimeError: String?

    /// Gauge the market regime: the S&P 500 vs its 200DMA + index momentum, the
    /// VIX level, and breadth (fraction of a large-cap sample above their own
    /// 200DMA). User-triggered; non-destructive on failure.
    func refreshRegime() async {
        guard !isLoadingRegime else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            regimeError = reason
            return
        }
        isLoadingRegime = true
        defer { isLoadingRegime = false }
        regimeError = nil

        let sample = StockSageRegime.breadthSample
        async let indexHistory = StockSageQuoteService.fetchHistory("^GSPC", range: "1y")
        async let vixQuotes = StockSageQuoteService.fetchQuotes(for: ["^VIX"])
        async let breadthHistories = StockSageQuoteService.fetchHistories(for: sample)

        let idx = await indexHistory
        let vix = (await vixQuotes)["^VIX"]?.price
        let hists = await breadthHistories

        guard let idx else {
            regimeError = "Couldn't load the market index — try again."
            return
        }
        // Breadth: fraction of the sample above its own 200DMA (names without a
        // computable 200DMA are excluded from the denominator — see the helper).
        let priced = sample.compactMap { hists[$0.uppercased()] }
        let breadth = StockSageRegime.breadth(priced)

        regime = StockSageRegime.assess(indexCloses: idx.closes, vix: vix, breadthAbove200: breadth)
        regimeGaugedAt = Date()
    }

    /// True when the regime is older than ~6 trading hours (or never gauged) — a
    /// signal that any regime-derived sizing should be treated cautiously.
    var regimeIsStale: Bool {
        guard let at = regimeGaugedAt else { return true }
        return Date().timeIntervalSince(at) > 6 * 3600
    }

    var ideasIsStale: Bool {
        guard let at = ideasUpdated else { return false }
        return Date().timeIntervalSince(at) > 4 * 3600
    }

    // Multi-timeframe — daily+weekly trend agreement, cached per symbol.
    @Published private(set) var multiTimeframe: [String: MultiTimeframeTrend] = [:]

    /// Fetch a daily (1y) AND a weekly (2y, interval=1wk) history for one symbol and
    /// cache whether the two timeframes' trends agree. Computed once per symbol.
    func refreshMultiTimeframe(symbol: String) async {
        let up = symbol.uppercased()
        guard multiTimeframe[up] == nil, ToolPolicy.isExternalAllowed else { return }
        async let dailyHistory = StockSageQuoteService.fetchHistory(symbol, range: "1y", interval: "1d")
        async let weeklyHistory = StockSageQuoteService.fetchHistory(symbol, range: "2y", interval: "1wk")
        guard let d = await dailyHistory, let w = await weeklyHistory else { return }
        multiTimeframe[up] = StockSageMultiTimeframe.assess(dailyCloses: d.closes, weeklyCloses: w.closes)
    }

    // Strategy backtest — the advisor's rules aggregated across a sample universe.
    @Published private(set) var strategyBacktest: StrategyBacktest?
    @Published private(set) var isLoadingStrategy = false
    @Published private(set) var strategyError: String?
    /// Conviction→win-probability calibration learned from the strategy BACKTEST's trades. nil until
    /// a backtest has run with enough trades.
    @Published private(set) var backtestConvictionCalibration: StockSageConvictionCalibration?

    /// F12 (2026-07-02): memoization for the journal calibration fit + OOS check. The fit
    /// (chronological split + IRLS + PAV + OOS selector) used to re-run on EVERY read of
    /// `convictionCalibration` — 33 read sites per MarketsView body render, on the MainActor.
    /// Keyed by VALUE equality of the journal's trades array, so ANY journal mutation
    /// (add/close/remove — current AND future mutators alike, no per-func invalidation hooks to
    /// forget) invalidates on the very next read: a just-closed trade still affects the very next
    /// render. Behavior identical, work amortized. `fitCount` exists purely so tests can pin the
    /// memoization contract (compute-once on repeat reads, recompute-on-change).
    struct JournalCalibrationCache {
        private var key: [TradeRecord]?
        private var cachedFit: StockSageConvictionCalibration?
        private var cachedOOS: StockSageConvictionCalibration.OOSCalibrationCheck?
        private(set) var fitCount = 0

        nonisolated mutating func value(for trades: [TradeRecord])
            -> (fit: StockSageConvictionCalibration?, oos: StockSageConvictionCalibration.OOSCalibrationCheck?) {
            if key != trades {
                cachedFit = StockSageConvictionCalibration.fit(fromJournal: trades)
                cachedOOS = StockSageConvictionCalibration.validateOutOfSample(trades)
                key = trades
                fitCount += 1
            }
            return (cachedFit, cachedOOS)
        }
    }
    private var calibrationFitCache = JournalCalibrationCache()

    /// EFFECTIVE conviction calibration the whole app sizes/ranks on: the owner's OWN realized edge
    /// (their journal) when it has enough closed conviction-trades, ELSE the sample-backtest fit, ELSE
    /// nil (callers fall back to the conservative linear prior). The journal beats a generic backtest —
    /// it captures the owner's real fills, slippage, and discipline. Check `.method` for provenance
    /// (isotonicWilson/beta/platt/identity) — conservatism depends on the fit path, NOT on non-nil.
    /// Cached per journal state (F12); any journal change is picked up on the very next read.
    var convictionCalibration: StockSageConvictionCalibration? {
        calibrationFitCache.value(for: StockSageJournalStore.shared.trades).fit ?? backtestConvictionCalibration
    }

    /// OUT-OF-SAMPLE honesty check of the conviction→win-prob map on the owner's journal: fit on their
    /// earlier trades, score on later held-out ones (purged/embargoed split) vs a no-skill base-rate
    /// predictor. nil until the journal has enough closed trades to split + fit — so it shows only once
    /// there's a real OOS verdict to give (small-sample-noisy by nature). Cached with the fit (F12).
    var calibrationOOS: StockSageConvictionCalibration.OOSCalibrationCheck? {
        calibrationFitCache.value(for: StockSageJournalStore.shared.trades).oos
    }

    /// Fetch ~5y for a bounded equity sample, walk-forward each off-main, and
    /// aggregate honest strategy-wide stats. User-triggered (heavy).
    func refreshStrategyBacktest() async {
        guard !isLoadingStrategy else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            strategyError = reason
            return
        }
        isLoadingStrategy = true
        defer { isLoadingStrategy = false }
        strategyError = nil

        let symbols = StockSageStrategyBacktest.sampleSymbols
        // Fetch the ^GSPC benchmark at the SAME 5y range as the symbol histories — a 1y slice
        // would leave the first ~4y of every symbol with no benchmark → RS silently disabled for
        // most of the backtest, defeating the fidelity fix. Use 5y so the date-aligned pointer has
        // full coverage over the entire symbol window.
        async let benchmarkTask = StockSageQuoteService.fetchHistory("^GSPC", range: "5y")
        let histories = await StockSageQuoteService.fetchHistories(for: symbols, range: "5y")
        let benchmark = await benchmarkTask
        guard !histories.isEmpty else {
            strategyError = "Couldn't load histories to backtest the strategy — try again."
            return
        }
        let (results, trades, tradeDates): ([BacktestResult], [BacktestTrade], [Date]) = await Task.detached {
            var rs: [BacktestResult] = []
            var ts: [BacktestTrade] = []
            var ds: [Date] = []
            for sym in symbols {
                guard let h = histories[sym.uppercased()] else { continue }
                // Faithful: charge asset-class costs AND feed the ^GSPC benchmark so the backtest
                // measures the SAME relative-strength term the live ideas path uses. The date-aligned
                // pointer inside runDetailed handles holiday calendar mismatches between symbol and
                // benchmark (symbol bar-counts differ from ^GSPC's — a naive index slice is wrong).
                let d = StockSageBacktester.runDetailed(h, costs: StockSageNetEdge.defaultCosts(forSymbol: sym),
                                                        benchmark: benchmark)
                rs.append(d.result)
                ts.append(contentsOf: d.trades)
                // Thread entry dates aligned 1:1 with trades for the pooled chronological DD.
                // entryIndex = i+1 (the fill bar), always in-bounds: i < n-1 so entryIndex ≤ n-1.
                ds.append(contentsOf: d.trades.map { h.dates[$0.entryIndex] })
            }
            return (rs, ts, ds)
        }.value
        strategyBacktest = StockSageStrategyBacktest.aggregate(results, trades: trades, tradeEntryDates: tradeDates)
        // Learn conviction→win-prob from the realized BACKTEST trades (nil if too thin). The computed
        // `convictionCalibration` prefers the owner's journal fit over this when their journal is rich enough.
        // `trades` is appended symbol-by-symbol above, so it is NOT globally time-ordered on its own —
        // pass the 1:1-aligned `tradeDates` so the OOS candidate-selector's train/test split is a
        // genuine chronological holdout (matching fit(fromJournal:)'s own sort-by-close-date fix).
        backtestConvictionCalibration = StockSageConvictionCalibration.fit(fromBacktest: trades, dates: tradeDates)
    }

    // Portfolio risk analytics — the full backward-looking risk/return suite.
    @Published private(set) var analytics: PortfolioAnalytics?
    @Published private(set) var correlation: CorrelationMatrix?
    @Published private(set) var isLoadingAnalytics = false
    @Published private(set) var analyticsError: String?

    /// Fetch each holding's history and compute the portfolio risk/return suite
    /// (Sharpe/Sortino/Calmar, max drawdown, VaR, correlation → diversification).
    /// User-triggered; heavy compute runs off-main; non-destructive on failure.
    func refreshPortfolioAnalytics() async {
        guard !isLoadingAnalytics else { return }
        let positions = StockSagePortfolio.shared.positions
        guard !positions.isEmpty else {
            analytics = nil
            analyticsError = "Add holdings to your portfolio first."
            return
        }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            analyticsError = reason
            return
        }
        isLoadingAnalytics = true
        defer { isLoadingAnalytics = false }
        analyticsError = nil

        async let gspcHistory = StockSageQuoteService.fetchHistory("^GSPC", range: "1y")
        let histories = await StockSageQuoteService.fetchHistories(for: positions.map(\.symbol))

        // Build DATED returns per holding so co-movement stats can align by calendar
        // day, not array position — holdings span exchanges with different holidays.
        var symbols: [String] = []
        var weights: [Double] = []
        var datedHoldingReturns: [[(date: Date, ret: Double)]] = []
        for p in positions {
            guard let h = histories[p.symbol.uppercased()], let price = h.latestClose else { continue }
            let dr = StockSagePortfolioAnalytics.datedReturns(dates: h.dates, closes: h.closes)
            guard !dr.isEmpty else { continue }
            symbols.append(p.symbol)
            weights.append(price * p.shares)
            datedHoldingReturns.append(dr)
        }
        guard !symbols.isEmpty else {
            analyticsError = "Couldn't load enough history to analyze the portfolio."
            return
        }

        let marketDated = (await gspcHistory).map {
            StockSagePortfolioAnalytics.datedReturns(dates: $0.dates, closes: $0.closes)
        } ?? []

        // Align every holding (and the market when present) to their common days.
        let toAlign = marketDated.isEmpty ? datedHoldingReturns : datedHoldingReturns + [marketDated]
        let aligned = StockSagePortfolioAnalytics.alignByDate(toAlign)
        let holdingVecs = marketDated.isEmpty ? aligned : Array(aligned.dropLast())
        let marketVec = marketDated.isEmpty ? [] : (aligned.last ?? [])

        // Analytics suite over date-aligned data: rebuild pseudo-closes (cumulative
        // product of 1+ret) so compute()'s closes path runs on the aligned returns.
        let alignedHoldings: [(weight: Double, closes: [Double])] = zip(weights, holdingVecs).map { w, rets in
            var closes: [Double] = [100]
            for r in rets { closes.append(closes[closes.count - 1] * (1 + r)) }
            return (weight: w, closes: closes)
        }
        let computed = await Task.detached { StockSagePortfolioAnalytics.compute(holdings: alignedHoldings) }.value
        analytics = computed
        if computed == nil {
            analyticsError = "Not enough overlapping history across your holdings yet."
        }

        // Heatmap from the date-aligned holding return vectors.
        if symbols.count >= 2, (holdingVecs.first?.count ?? 0) >= 5 {
            correlation = CorrelationMatrix(symbols: symbols,
                                            matrix: StockSagePortfolioAnalytics.correlationMatrix(holdingVecs))
        } else {
            correlation = nil
        }

        // Beta: value-weighted portfolio vs the SAME-DAY market vector.
        let port = StockSagePortfolioAnalytics.portfolioReturns(holdings: alignedHoldings)
        portfolioBeta = (port.isEmpty || marketVec.isEmpty)
            ? nil : StockSagePortfolioAnalytics.beta(portfolio: port, market: marketVec)
    }

    /// Portfolio beta vs the S&P 500 (computed alongside the analytics).
    @Published private(set) var portfolioBeta: Double?

    // Correlation pre-check — how a candidate would affect portfolio concentration.
    @Published private(set) var precheck: [String: CorrelationPrecheck] = [:]
    /// The holdings fingerprint each cached verdict was computed under, so the
    /// cache RECOMPUTES when the book changes (add/remove a holding) instead of
    /// serving a stale concentration verdict.
    private var precheckFingerprint: [String: String] = [:]
    /// F14 (2026-07-02): date-tagged daily returns for every symbol refreshPrecheck fetched
    /// (candidate + holdings) — the detail-sheet cluster check correlates on THESE, calendar-
    /// aligned via `StockSagePortfolioAnalytics.alignByDate`, instead of pairing ~2-day
    /// down-sampled sparks positionally (which biases cross-calendar pairs — Tadawul/US,
    /// crypto/equity — toward 0 and could show a false-green "adds diversification" while the
    /// sibling precheck row, built on real daily closes, disagreed in the same sheet). Reuses
    /// the precheck's OWN fetch — no extra network call. An absent symbol ⇒ unknown: the
    /// cluster check renders nothing rather than a fabricated coefficient.
    @Published private(set) var precheckDatedReturns: [String: [(date: Date, ret: Double)]] = [:]

    /// Compute (and cache) how adding `symbol` would correlate with the current
    /// holdings. Cached per (symbol + holdings fingerprint); no-op when access is off.
    func refreshPrecheck(symbol: String) async {
        let up = symbol.uppercased()
        let positions = StockSagePortfolio.shared.positions
        let fingerprint = positions.map { $0.symbol.uppercased() }.sorted().joined(separator: ",")
        // Fresh only if the verdict was computed under the CURRENT book.
        guard precheckFingerprint[up] != fingerprint else { return }
        if ToolPolicy.webToolsDisabledReason() != nil { return }
        guard !positions.isEmpty else {
            precheck[up] = CorrelationPrecheck(verdict: .noHoldings, avgCorrelation: 0,
                                               comparedCount: 0, mostCorrelatedSymbol: nil, mostCorrelation: 0)
            precheckFingerprint[up] = fingerprint
            return
        }
        var symbols = Set(positions.map { $0.symbol.uppercased() })
        symbols.insert(up)
        let hists = await StockSageQuoteService.fetchHistories(for: Array(symbols))
        // F14: stash every fetched symbol's DATE-TAGGED returns for the cluster check — even when
        // the candidate itself failed to fetch, a holding's series can serve a later candidate.
        for (sym, h) in hists {
            precheckDatedReturns[sym] = StockSagePortfolioAnalytics.datedReturns(dates: h.dates, closes: h.closes)
        }
        guard let cand = hists[up] else { return }
        let candReturns = StockSagePortfolioAnalytics.dailyReturns(cand.closes)
        let holdReturns: [(symbol: String, returns: [Double])] = positions.compactMap { p in
            let psym = p.symbol.uppercased()
            guard psym != up, let h = hists[psym] else { return nil }
            return (p.symbol, StockSagePortfolioAnalytics.dailyReturns(h.closes))
        }
        precheck[up] = await Task.detached {
            StockSageCorrelationPrecheck.assess(candidate: candReturns, holdings: holdReturns)
        }.value
        precheckFingerprint[up] = fingerprint
    }

    // Fast-lane cross-correlation (FASTMONEY_BACKLOG #7) — how much the crypto and equity fast-lane
    // boards are ACTUALLY moving together right now. Mirrors refreshPrecheck's exact pattern:
    // fingerprint-cached (recomputes only when the fast-lane's symbol SET changes), ToolPolicy-gated,
    // pure StockSageExpectedValue.laneCorrelation over fetched histories (no new fetch code — reuses
    // StockSageQuoteService.fetchHistories, the SAME call refreshPrecheck uses).
    @Published private(set) var laneCorrelationValue: Double?
    private var laneCorrelationFingerprint: String?

    /// Fetch history for the CURRENT crypto+equity fast-lane symbols and compute their average
    /// cross-group correlation. No-op if access is off or either side is empty (nothing to
    /// correlate — clears the stale value so a picker toggle to a one-sided view can't show a
    /// number from the OLD symbol set).
    func refreshLaneCorrelation(holds: VelocityHoldDays = .defaults) async {
        let split = StockSageExpectedValue.fastLaneByClass(ideas, holds: holds, calibration: convictionCalibration)
        guard !split.crypto.isEmpty, !split.equity.isEmpty else {
            laneCorrelationValue = nil; laneCorrelationFingerprint = nil; return
        }
        let symbols = (split.crypto + split.equity).map(\.symbol)
        let fingerprint = symbols.sorted().joined(separator: ",")
        guard laneCorrelationFingerprint != fingerprint else { return }
        guard ToolPolicy.webToolsDisabledReason() == nil else { return }
        let histories = await StockSageQuoteService.fetchHistories(for: symbols)
        guard !Task.isCancelled else { return }
        let result = StockSageExpectedValue.laneCorrelation(
            crypto: split.crypto, equity: split.equity, histories: histories.mapValues(\.closes))
        // F11: stamp the fingerprint ONLY on a non-nil result; clear it on failure/cancellation.
        // If the fetch failed (result==nil), clearing the fingerprint ensures the next call is NOT
        // blocked by the guard above — allowing a retry after a network miss. A cancelled stale
        // task cannot reach here (guard above), so it can't clobber a fresh task's published value.
        // Mirrors the cache-on-success pattern of refreshTrailingStop/refreshLiquidity.
        laneCorrelationValue = result
        laneCorrelationFingerprint = (result != nil) ? fingerprint : nil
    }

    // Symbols whose latest quote had no real previousClose (a brand-new listing) — Yahoo's
    // fallback (previousClose := price) reads as a genuine flat 0%-move "hold" without this,
    // when it's actually "unevaluated." Refreshed each `refresh()` cycle alongside `quotes`.
    @Published private(set) var newListings: Set<String> = []

    // Earnings proximity — overnight-gap event risk for an equity. Only the RAW earnings DATE
    // is cached per symbol (it doesn't shift within a session); the derived daysUntil/severity
    // is recomputed FRESH on every read (see `earnings` below) so a long-running session's
    // imminent-earnings ranking demotion never goes stale relative to whenever the date happened
    // to be fetched.
    @Published private(set) var earningsDates: [String: Date] = [:]

    /// Pure derivation: raw earnings dates → proximity, evaluated at `now`. A free function (not
    /// baked into a cached dict) so it's directly testable with an injected `now` — the SAME
    /// cached raw date must yield a DIFFERENT severity as real time passes, unlike the frozen
    /// fetch-time value the pre-fix code cached.
    nonisolated static func deriveEarningsProximity(_ dates: [String: Date], now: Date = Date()) -> [String: EarningsProximity] {
        // F32: evict entries whose date is more than 1 day in the past. The session cache never
        // auto-expires, so after a report date passes mid-session max(0,days) floors at 0 and the
        // .imminent badge + −2000 rank demotion would persist for hours.
        // NOTE — one-instant deliberate difference vs the fetch-time guard in refreshEarnings:
        //   fetch guard:   date.timeIntervalSinceNow > -86_400   (strict, evicts at exactly -86400s)
        //   derive guard:  date.timeIntervalSince(now) >= -86_400 (non-strict, keeps at exactly -86400s)
        // The derive guard is deliberately conservative: it keeps the warning for one instant longer
        // than the fetch guard would. Do NOT change either boundary.
        dates.compactMapValues { date in
            guard date.timeIntervalSince(now) >= -86_400 else { return nil }
            return StockSageEarnings.proximity(now: now, earnings: date)
        }
    }

    /// Earnings proximity — overnight-gap event risk for an equity. Recomputed fresh from
    /// `earningsDates` on every access; never cached as a stale derived value.
    var earnings: [String: EarningsProximity] { Self.deriveEarningsProximity(earningsDates) }

    func refreshEarnings(symbol: String) async {
        let up = symbol.uppercased()
        guard earningsDates[up] == nil else { return }
        guard let date = await StockSageEarnings.fetchNextEarnings(for: symbol),
              date.timeIntervalSinceNow > -86_400 else { return }   // ignore a stale past date
        earningsDates[up] = date
    }

    /// Feed earnings for the TOP-ranked ideas (bounded) so the imminent-earnings DEMOTION + warnings
    /// fire on the BOARDS / best-bet / allocation — not only after a detail expand. Each symbol is
    /// cached once (refreshEarnings no-ops when present), so this only fetches the new top names.
    func refreshEarningsForTopIdeas(limit: Int = 15) async {
        // Run up to 4 earnings fetches in parallel (each has an 8s timeout); sequential
        // was correct for correctness but serialised 15 fetches = up to 15×8s worst-case.
        let top = Array(ideas.prefix(limit))
        let chunks = stride(from: 0, to: top.count, by: 4).map { Array(top[$0 ..< min($0 + 4, top.count)]) }
        for chunk in chunks {
            await withTaskGroup(of: Void.self) { group in
                for idea in chunk { group.addTask { await self.refreshEarnings(symbol: idea.symbol) } }
                for await _ in group { }
            }
        }
    }

    // Monthly seasonality — calendar-month return tendency over a long history.
    @Published private(set) var seasonality: [String: MonthlySeasonality] = [:]

    func refreshSeasonality(symbol: String) async {
        let up = symbol.uppercased()
        guard seasonality[up] == nil else { return }
        if ToolPolicy.webToolsDisabledReason() != nil { return }
        guard let h = await StockSageQuoteService.fetchHistory(symbol, range: "10y", interval: "1mo") else { return }
        seasonality[up] = await Task.detached {
            StockSageSeasonality.compute(dates: h.dates, closes: h.closes)
        }.value
    }

    // Liquidity — avg daily $ volume + tier, cached per symbol (equities/crypto only).
    @Published private(set) var liquidity: [String: LiquidityProfile] = [:]

    func refreshLiquidity(symbol: String) async {
        let up = symbol.uppercased()
        guard liquidity[up] == nil else { return }
        // USD-priced only: a foreign listing's local-currency volume mislabeled "$"
        // (and London's pence quotes) would give a wrong tier/number. FX/index too.
        guard StockSageLiquidity.isUSDPriced(symbol) else { return }
        if ToolPolicy.webToolsDisabledReason() != nil { return }
        guard let h = await StockSageQuoteService.fetchHistory(symbol, range: "3mo") else { return }
        if let p = StockSageLiquidity.profile(closes: h.closes, volumes: h.volumes) {
            liquidity[up] = p
        }
    }

    // ATR trailing-stop suggestion, cached per symbol.
    @Published private(set) var trailingStop: [String: TrailingStop] = [:]

    func refreshTrailingStop(symbol: String) async {
        let up = symbol.uppercased()
        guard trailingStop[up] == nil else { return }
        if ToolPolicy.webToolsDisabledReason() != nil { return }
        guard let h = await StockSageQuoteService.fetchHistory(symbol, range: "6mo") else { return }
        if let ts = StockSageTrailingStop.suggest(highs: h.highs, lows: h.lows, closes: h.closes) {
            trailingStop[up] = ts
        }
    }

    // Backtest — the honesty check for one symbol.
    @Published private(set) var backtest: BacktestResult?
    /// Same strategy/symbol re-simulated with a WIDE ATR Chandelier trailing exit (vs `backtest`'s
    /// fixed 2:1) — a head-to-head so the owner can judge whether trailing helps (usually drawdown
    /// control, not more return). nil until a single-symbol backtest runs.
    @Published private(set) var backtestTrail: BacktestResult?
    @Published private(set) var backtestSymbol: String?
    @Published private(set) var isBacktesting = false
    @Published private(set) var backtestError: String?

    /// Fetch a multi-year history for `symbol` and walk-forward backtest the
    /// advisor's rules over it. User-triggered; non-destructive on failure.
    func runBacktest(symbol: String) async {
        guard !isBacktesting else { return }
        backtestSymbol = symbol                     // surface which symbol, even while running/failed
        // Clear the prior symbol's result BEFORE any early-return — else a web-disabled
        // (or otherwise bailed) run leaves the old symbol's backtest on screen attributed
        // to the new backtestSymbol (audit L3-02, 2026-07-07).
        backtest = nil
        backtestTrail = nil
        underwater = nil
        if let reason = ToolPolicy.webToolsDisabledReason() {
            backtestError = reason
            return
        }
        isBacktesting = true
        defer { isBacktesting = false }             // stays true across the fetch AND the O(bars²) compute
        backtestError = nil
        // 5 years of daily bars → room to trade after the 200-day warmup.
        let history = await StockSageQuoteService.fetchHistory(symbol, range: "5y")
        guard let history else {
            backtestError = "Couldn't load enough history to backtest \(symbol)."
            return
        }
        // The walk-forward is O(bars²) (advisor re-run each bar) — keep it off-main.
        // Charge the symbol's asset-class round-trip cost so the equity curve is honest.
        let btCosts = StockSageNetEdge.defaultCosts(forSymbol: symbol)
        // Same entry rules, two EXITS — the fixed 2:1 AND a wide ATR Chandelier trail (3×ATR/22) —
        // so the owner sees the research's claim head-to-head (trailing = drawdown control, usually
        // not more return). Both off-main in one hop; entries are identical, only simulateExit differs.
        let (fixed, trail) = await Task.detached(priority: .userInitiated) {
            (StockSageBacktester.run(history, costs: btCosts),
             StockSageBacktester.run(history, costs: btCosts, exitMode: .chandelierTrail(atrMult: 3, period: 22)))
        }.value
        backtest = fixed
        backtestTrail = trail
        // Buy-and-hold underwater curve over the same 5y window (cheap, O(n)).
        underwater = StockSageDrawdown.underwater(history.closes)
    }

    /// Buy-and-hold underwater curve for the last backtested symbol (5y closes).
    @Published private(set) var underwater: UnderwaterCurve?

    /// Ranking score for the "best ideas now" board: strongest conviction buys
    /// first, holds/avoids in the middle, sells last.
    // internal (not private): the board's default `.signal` ordering, pinned by
    // StockSageRankScoreTests (AUDIT F41) — a single sign slip silently reorders the board.
    static func rankScore(_ a: TradeAdvice) -> Double {
        switch a.action {
        case .strongBuy: return 2 + a.conviction
        case .buy:       return 1 + a.conviction
        case .hold:      return 0
        case .avoid:     return -0.1
        case .reduce:    return -1 - a.conviction
        case .sell:      return -2 - a.conviction
        }
    }

    // MARK: - Live worldwide feed

    /// Pure: should a refresh bail on a low-coverage response and keep whatever's already on
    /// screen rather than committing a partial board? True whenever coverage collapsed below 50%
    /// and there's an existing snapshot worth protecting — including the very first live refresh
    /// (the store always has at least the sample seed, so this isn't isSampleData-gated).
    /// Testable without a network fetch.
    nonisolated static func coverageGuardShouldBail(coverage: Double, hasExistingSymbols: Bool) -> Bool {
        coverage < 0.5 && hasExistingSymbols
    }

    /// Pull live quotes for the worldwide universe and swap them in, flipping the
    /// store off "sample". A no-op-with-reason when external access is disabled,
    /// and a non-destructive no-op when the feed is unreachable — the existing
    /// (sample or last-good) data stays on screen rather than blanking out.
    func refresh() async {
        guard !isRefreshing else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            feedError = reason
            return
        }

        isRefreshing = true
        feedError = nil
        let universe = trackedDefs()
        let quotes = await StockSageQuoteService.fetchQuotes(for: universe.map(\.symbol))
        isRefreshing = false

        // Merge each curated symbol (keeps the friendly market label) with its
        // live quote; drop any the feed couldn't price.
        let live: [StockSageSymbol] = universe.compactMap { sym in
            guard let q = quotes[sym.symbol.uppercased()] else { return nil }
            return StockSageSymbol(symbol: sym.symbol, market: sym.market, quotes: [
                StockSageQuote(price: q.previousClose, previousPrice: q.previousClose,
                               time: Date(timeIntervalSinceNow: -86_400)),
                // Carry the real MARKET time separately so per-row staleness can flag a days-old
                // weekend/holiday close; `time` stays the observation time. nil marketTime ⇒ not judged.
                StockSageQuote(price: q.price, previousPrice: q.previousClose, marketTime: q.marketTime),
            ])
        }
        guard !live.isEmpty else {
            feedError = "Couldn't reach the market feed — showing the last data."
            return
        }
        // Don't let a partial outage replace a full board with a handful of rows: if coverage
        // collapsed and there's an existing snapshot on screen (sample, cached, OR already-live —
        // deliberately NOT gated on `!isSampleData`, so a low-coverage FIRST-EVER refresh also
        // bails instead of silently truncating the board with feedError left nil), keep it.
        let coverage = Double(live.count) / Double(max(universe.count, 1))
        if Self.coverageGuardShouldBail(coverage: coverage, hasExistingSymbols: !symbols.isEmpty) {
            feedError = "Partial market data this refresh — keeping the last full snapshot."
            return
        }
        // Preserve user-added tickers this refresh's pre-await snapshot may have
        // missed — e.g. a symbol added DURING the network await would otherwise be
        // wiped by the wholesale replace until the next cycle.
        // A removeSymbol() that landed DURING the await must win: this refresh's pre-await snapshot
        // still fetched + priced that ticker, so it sits in `live` and would otherwise revert the
        // removal on screen AND re-persist it to the cache (surviving relaunch). Drop any user-market
        // row whose symbol is no longer tracked. Curated rows are untouched (removeSymbol no-ops there).
        let tracked = Set(userSymbols.map { $0.uppercased() })
        let liveFiltered = live.filter {
            $0.market != Self.userMarketLabel || tracked.contains($0.symbol.uppercased())
        }
        let liveKeys = Set(liveFiltered.map { $0.symbol.uppercased() })
        let preservedUserRows = symbols.filter {
            $0.market == Self.userMarketLabel && !liveKeys.contains($0.symbol.uppercased())
        }
        let committed = liveFiltered + preservedUserRows
        // Set the new-listing honesty flags only once BOTH non-destructive bails have
        // passed (empty-feed L1162, coverage L1170) — assigning before them let a failed
        // or partial refresh wipe the flags while keeping the old rows, so a cached
        // placeholder-flat IPO row read as a genuine 0.00% move (audit L3-01, 2026-07-07).
        newListings = Set(quotes.filter { $0.value.isNewListing }.keys)
        replaceAll(committed, isSample: false)
        lastUpdated = Date()
        // Newest MARKET time across the priced quotes — the banner uses this (not fetch time) to
        // tell live from a stale close. nil when the feed omitted timestamps for all of them.
        quoteAsOf = quotes.values.compactMap(\.marketTime).max()
        // Persist EXACTLY what is on screen (incl. preserved user-added tickers the feed missed this
        // cycle) — caching only `live` dropped them, so a tracked ticker vanished from the offline /
        // last-good board on next launch.
        loadedFromCache = false
        StockSageQuoteCache.from(symbols: committed, savedAt: lastUpdated ?? Date(), newListings: newListings).save()
    }

    func fetchAllSymbols() -> [StockSageSymbol] {
        symbols.sorted { $0.symbol < $1.symbol }
    }

    func symbol(named name: String) -> StockSageSymbol? {
        symbols.first { $0.symbol.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Replace the whole set (e.g. when a live feed delivers a fresh snapshot).
    /// Marks the store as no-longer-sample.
    func replaceAll(_ newSymbols: [StockSageSymbol], isSample: Bool = false) {
        symbols = newSymbols
        isSampleData = isSample
    }

    // MARK: - Sample data
    //
    // A handful of TASI + US names with one prior + current quote each, chosen to
    // exercise every signal branch (a strong mover, a moderate mover, a flat
    // one). NOT live — see the type doc above.
    // Internal (not private) so a test can deterministically restore the known sample state —
    // the shared singleton's `isSampleData` flips to false once any test calls refresh().
    func seedSampleData() {
        symbols = [
            Self.sample("2222.SR", "TASI", previous: 28.50, current: 30.40),   // +6.7% → strong buy
            Self.sample("1120.SR", "TASI", previous: 92.10, current: 89.30),   // -3.0% → sell
            Self.sample("AAPL",    "NASDAQ", previous: 226.0, current: 227.1), // +0.5% → hold
            Self.sample("NVDA",    "NASDAQ", previous: 118.0, current: 126.5), // +7.2% → strong buy
            Self.sample("7010.SR", "TASI", previous: 41.0,  current: 42.3),    // +3.2% → buy
        ]
        isSampleData = true
    }

    private static func sample(_ ticker: String, _ market: String,
                               previous: Double, current: Double) -> StockSageSymbol {
        StockSageSymbol(symbol: ticker, market: market, quotes: [
            StockSageQuote(price: previous, previousPrice: previous,
                           time: Date(timeIntervalSinceNow: -3600)),
            StockSageQuote(price: current, previousPrice: previous),
        ])
    }

    // MARK: - QA fixture ideas (QA/test-only seam — reachable ONLY from the --qa
    // capture path in QASnapshots.checkAndRun; never on a normal launch)

    /// Deterministic synthetic histories that exercise real advisor branches.
    /// Series are the TEST SUITE'S PROVEN generators (StockSageAdvisorTests /
    /// StockSageBuildIdeasDirectTests) inlined — the test target can't be imported here.
    /// Pure + nonisolated so a test can pipe them through buildIdeas without
    /// touching the shared singleton (parallel-test safe).
    // NOTE — deviation from spec, flagged in the final report: spec said `nonisolated`, but
    // StockSageSymbol's hand-written init (StockSageModels.swift) has no `nonisolated` marker,
    // so under this module's default-actor-isolation build setting it is @MainActor-isolated
    // (unlike StockSagePriceHistory below, whose synthesized memberwise init is nonisolated for
    // free, and unlike StockSageIdea's init at line 38 which IS explicitly marked nonisolated).
    // Spec's two-files-only scope forbids editing StockSageModels.swift, so this stays isolated
    // (main-actor) instead — its only caller, seedQAIdeas, is already on @MainActor.
    static func qaFixtureDefs() -> [StockSageSymbol] {
        [
            StockSageSymbol(symbol: "NVDA",    market: "NASDAQ"),  // strongBuy, bullTrend
            StockSageSymbol(symbol: "AAPL",    market: "NASDAQ"),  // buy (+ seeded earnings warning)
            StockSageSymbol(symbol: "1120.SR", market: "TASI"),    // sell-family, bearTrend (short plan)
            StockSageSymbol(symbol: "BTC-USD", market: "Crypto"),  // crypto strongBuy
            StockSageSymbol(symbol: "7010.SR", market: "TASI"),    // vol-regime brake ⚠ note
        ]
    }

    nonisolated static func qaFixtureHistories() -> [String: StockSagePriceHistory] {
        func hist(_ sym: String, _ closes: [Double]) -> StockSagePriceHistory {
            let dates = closes.enumerated().map { Date(timeIntervalSince1970: Double($0.offset) * 86_400) }
            return StockSagePriceHistory(symbol: sym, dates: dates,
                opens: closes, highs: closes.map { $0 * 1.005 }, lows: closes.map { $0 * 0.995 },
                closes: closes, volumes: closes.map { _ in 100_000 })
        }
        // TrendFixtures.up(250): accelerating uptrend → pinned strongBuy + stop/target + ⏱ note
        // (StockSageBuildIdeasDirectTests.executionTimingNoteAppearsForBullTrendBuy).
        let up250 = (0..<250).map { 50.0 + 0.0153 * pow(Double($0), 2) }
        // TrendFixtures.up(70): lighter 50DMA branch → pinned .buy
        // (StockSageAdvisorTests.fiftyBarHistoryUsesLighterTrendScore).
        let up70 = (0..<70).map { 50.0 + 0.0153 * pow(Double($0), 2) }
        // Gentle linear downtrend 200→~50 → pinned sell/reduce + bearTrend, short stop/target
        // (StockSageAdvisorTests.cleanDowntrendIsASellShortSetup).
        let down250 = (0..<250).map { 200.0 - Double($0) * 0.602 }
        // 293 bars: 272 calm sinusoidal then 21 alternating ±3% → vol-regime brake note
        // (StockSageBuildIdeasDirectTests.volRegimeBrakeNoteAppearsWhenRecentVolElevated).
        var px = 100.0; var brake = [px]
        for i in 0..<272 { px *= (1 + sin(Double(i)) * 0.005); brake.append(px) }
        for i in 0..<20  { px *= (1 + (i % 2 == 0 ? 1.0 : -1.0) * 0.030); brake.append(px) }
        return [
            "NVDA":    hist("NVDA", up250),
            "AAPL":    hist("AAPL", up70),
            "1120.SR": hist("1120.SR", down250),
            // ×600 scale puts BTC at a plausible price level; the advisor is scale-invariant
            // (returns/ATR%/momentum are all ratios), so the action is identical to up250's.
            "BTC-USD": hist("BTC-USD", up250.map { $0 * 600 }),
            "7010.SR": hist("7010.SR", brake),
        ]
    }

    /// Seed the shared store with deterministic fixture ideas COMPUTED THROUGH THE REAL
    /// buildIdeas/advise pipeline. Forces the sample-labeled state first (seedSampleData →
    /// isSampleData = true) so the fixture board is honestly bannered "Sample data" —
    /// never rendered under the cached/live banner. In-memory only: nothing here persists
    /// (ideas/earningsDates are not written to disk; paper-trading/alerts/monitor untouched).
    func seedQAIdeas() async {
        seedSampleData()   // honest labeling: whole board = sample, isSampleData = true
        let built = await Self.buildIdeas(defs: Self.qaFixtureDefs(),
                                          histories: Self.qaFixtureHistories(),
                                          benchmark: nil,          // no RS term → deterministic
                                          calibration: nil,        // prior sizing → deterministic
                                          journalTrades: [])       // sector rotation no-op
        ideas = built.sorted { Self.rankScore($0.advice) > Self.rankScore($1.advice) }
        ideasUpdated = Date()
        // Earnings warning on the buy card: ≤3 days → .imminent (StockSageEarnings severity)
        // → "⚠︎ earnings ~2d" chip + rank demotion visible on the AAPL card. In-memory only.
        earningsDates["AAPL"] = Date().addingTimeInterval(2 * 86_400)
        // Scan deltas: reads whatever baseline is currently in StockSageScanSnapshotStore
        // (QASnapshots.checkAndRun in-memory-seeds it via qaSeed before calling this, then
        // restores it after capture) — this method NEVER calls save(), so the real
        // stocksage.prevscan.v1 key is untouched (PLAN_2026-07-07_scan_deltas.md).
        scanDeltas = StockSageScanDelta.deltas(current: ideas, previous: StockSageScanSnapshotStore.shared.entries)
    }
}
