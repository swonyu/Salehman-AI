import Foundation

// MARK: - Disk history cache
//
// Persists the last successful price histories (the bulk `fetchHistories` result that
// `buildIdeas` currently discards) so `StockSageNetCostSim` / backtests can run OFFLINE on
// real candles — at ZERO extra network (it saves bytes the app already downloaded). Mirrors
// `StockSageQuoteCache`: a Codable model + a thin Application-Support I/O layer, all pure and
// unit-tested. Honest: cached candles are as-of `savedAt`, NOT live — any surface built from
// them is labeled so, and a missing / short / too-stale / corrupt / schema-mismatched history
// stays nil, never a guessed or zero-filled series (the frozen nil-contract). v1 seeds the SIM
// / backtest path only — it does NOT render the live board (that is an owner-gated, visual-QA
// -gated product decision), so nothing user-visible changes.

nonisolated struct StockSageHistoryCache: Codable, Sendable, Equatable {
    /// Bumped when the on-disk shape or its semantics change; a file whose version != current
    /// decodes to nil (one clean re-fetch), never a partial / guessed read (the `isNewListing`
    /// precedent in `StockSageQuoteCache`).
    static let currentSchemaVersion = 1
    /// One year of daily bars — matches `StockSageQuoteService.fetchHistories`' default range.
    static let defaultMaxBars = 252

    /// Codable mirror of `StockSagePriceHistory` (which is only Sendable/Equatable, not Codable).
    /// Parallel arrays stay equal-length (enforced at build time); newest LAST, as the source.
    nonisolated struct Entry: Codable, Sendable, Equatable {
        let symbol: String
        let dates: [Date]
        let opens: [Double]
        let highs: [Double]
        let lows: [Double]
        let closes: [Double]
        let volumes: [Double]
    }

    var schemaVersion: Int
    var entries: [Entry]
    var savedAt: Date

    // MARK: Build (pure) — trim + universe eviction

    /// Build a cache from a completed `fetchHistories` result. Keeps only the last `maxBars`
    /// bars per symbol (older trimmed) and DROPS symbols not in `universe` (uppercased) so a
    /// rotating / shrinking universe cannot leak storage. Rows with unequal parallel-array
    /// lengths are skipped, never repaired-by-guess. Entries are symbol-sorted so equality and
    /// the on-disk bytes are deterministic (stable tests, stable diffs).
    static func from(histories: [String: StockSagePriceHistory], universe: Set<String>,
                     savedAt: Date, maxBars: Int = defaultMaxBars) -> StockSageHistoryCache {
        let entries = histories.values.compactMap { h -> Entry? in
            guard universe.contains(h.symbol.uppercased()) else { return nil }
            let n = h.closes.count
            guard n > 0, h.dates.count == n, h.opens.count == n, h.highs.count == n,
                  h.lows.count == n, h.volumes.count == n else { return nil }   // malformed → skip, never guess
            let k = Swift.max(0, maxBars)
            return Entry(symbol: h.symbol,
                         dates: Array(h.dates.suffix(k)),  opens:  Array(h.opens.suffix(k)),
                         highs: Array(h.highs.suffix(k)),  lows:   Array(h.lows.suffix(k)),
                         closes: Array(h.closes.suffix(k)), volumes: Array(h.volumes.suffix(k)))
        }.sorted { $0.symbol < $1.symbol }
        return StockSageHistoryCache(schemaVersion: currentSchemaVersion, entries: entries, savedAt: savedAt)
    }

    /// Reconstruct the `[symbol: StockSagePriceHistory]` map (uppercased keys) for consumers.
    func priceHistories() -> [String: StockSagePriceHistory] {
        var out: [String: StockSagePriceHistory] = [:]
        for e in entries {
            out[e.symbol.uppercased()] = StockSagePriceHistory(
                symbol: e.symbol, dates: e.dates, opens: e.opens, highs: e.highs,
                lows: e.lows, closes: e.closes, volumes: e.volumes)
        }
        return out
    }

    // MARK: Staleness (honesty floor)

    /// A symbol's cached history is STALE when its newest bar is more than `maxAgeDays` full
    /// calendar days before `asOf` (≈ 5 trading days at the default 7). Computed from the raw
    /// time interval (timezone-independent, so it can't flake across machines). Stale history
    /// is fine for a backtest (inherently historical) but must NOT back a "fresh idea" presented
    /// as current. Returns true (stale) for an unknown or empty symbol — absence is not freshness.
    func isStale(symbol: String, asOf: Date, maxAgeDays: Int = 7) -> Bool {
        guard let e = entries.first(where: { $0.symbol.uppercased() == symbol.uppercased() }),
              let newest = e.dates.last else { return true }
        let ageDays = Int(asOf.timeIntervalSince(newest) / 86_400)
        return ageDays > maxAgeDays
    }

    // MARK: Thin file I/O (Application Support) — mirrors StockSageQuoteCache

    nonisolated static func diskURL() -> URL? {
        guard let dir = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        return dir.appendingPathComponent("salehman_history_cache.json")
    }

    /// Decode + validate the schema version. Separated from the disk read so the version guard
    /// is unit-testable without touching Application Support.
    nonisolated static func decode(_ data: Data) -> StockSageHistoryCache? {
        guard let cache = try? JSONDecoder().decode(StockSageHistoryCache.self, from: data),
              cache.schemaVersion == currentSchemaVersion else { return nil }
        return cache
    }

    nonisolated static func load() -> StockSageHistoryCache? {
        guard let url = diskURL(), let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    nonisolated func save() {
        guard let url = Self.diskURL(), let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Panel builder for the net-cost sim (offline validation)

    /// Build a `StockSageNetCostSim.Panel` from cached histories, aligned on the DATE axis
    /// SHARED by every included symbol (set intersection — correct across holidays / late
    /// listings; no look-ahead, no fabricated bars). `industryOf` groups symbols for the
    /// industry-relative demeaning. Returns nil when fewer than 2 symbols or fewer than 2
    /// shared dates survive (nothing to simulate) — never a padded or guessed panel.
    static func panel(from histories: [String: StockSagePriceHistory],
                      industryOf: (String) -> Int) -> StockSageNetCostSim.Panel? {
        let syms = histories.keys.sorted()
        guard syms.count >= 2 else { return nil }
        // Bucket by UTC calendar day, not the raw bar timestamp: Yahoo stamps each 1d bar at
        // its exchange's session-open instant (US ~13:30 UTC, Tadawul ~07:00, crypto 00:00), so
        // exact-Date set-intersection drops EVERY cross-exchange pair and returns a null/degenerate
        // panel for any mixed-market universe. Same dayKey the rest of the engine aligns on
        // (StockSagePortfolioAnalytics.alignByDate) — audit L3-05, 2026-07-07.
        func dayKey(_ d: Date) -> Int { Int((d.timeIntervalSince1970 / 86_400).rounded(.down)) }
        var shared: Set<Int>? = nil
        for s in syms {
            let ds = Set(histories[s]!.dates.map(dayKey))
            shared = shared.map { $0.intersection(ds) } ?? ds
        }
        let days = (shared ?? []).sorted()
        guard days.count >= 2 else { return nil }
        var returns: [[Double]] = []
        var industry: [Int] = []
        for s in syms {
            guard let h = histories[s] else { return nil }
            var byDate: [Int: Double] = [:]
            for (d, c) in zip(h.dates, h.closes) { byDate[dayKey(d)] = c }
            let closes = days.map { byDate[$0] ?? Double.nan }
            guard !closes.contains(where: { $0.isNaN || $0 <= 0 }) else { return nil }   // must be present & positive
            let r = (1..<closes.count).map { closes[$0] / closes[$0 - 1] - 1 }
            returns.append(r)
            industry.append(industryOf(s))
        }
        return StockSageNetCostSim.Panel(returns: returns, industry: industry)
    }
}
