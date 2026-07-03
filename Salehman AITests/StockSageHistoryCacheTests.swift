import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Disk history cache (pure model + panel builder)

struct StockSageHistoryCacheTests {

    typealias HC = StockSageHistoryCache

    /// Deterministic price history: `closes[i] = base + i`, dates one day apart from epoch.
    /// OHLC mirror closes; volumes = closes. Newest LAST (as the real feed produces).
    private func history(_ symbol: String, bars: Int, base: Double = 0) -> StockSagePriceHistory {
        let closes = (0..<bars).map { base + Double($0) }
        let dates = (0..<bars).map { Date(timeIntervalSince1970: Double($0) * 86_400) }
        return StockSagePriceHistory(symbol: symbol, dates: dates, opens: closes,
                                     highs: closes, lows: closes, closes: closes, volumes: closes)
    }

    // 1. Codec round-trip: encode → decode preserves entries and parallel-array equality.
    @Test func codecRoundTripPreservesEntries() throws {
        let e = HC.Entry(symbol: "AAA",
                         dates: [Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 86_400)],
                         opens: [1, 2], highs: [1, 2], lows: [1, 2], closes: [10, 11], volumes: [100, 200])
        let cache = HC(schemaVersion: HC.currentSchemaVersion, entries: [e], savedAt: Date(timeIntervalSince1970: 500))
        let data = try JSONEncoder().encode(cache)
        let back = try #require(HC.decode(data))          // hard: must decode
        #expect(back == cache)                            // full value equality (all parallel arrays)
        #expect(back.entries.first?.closes == [10, 11])   // spot-check a reconstructed field
        #expect(back.entries.first?.dates.count == back.entries.first?.closes.count)  // arrays stay equal-length
    }

    // 2. Trim: a 400-bar history keeps exactly the last 252 (149…400 for closes = 1…400).
    @Test func fromTrimsToLastMaxBars() {
        // closes = base 1 → [1,2,…,400]; suffix(252) = indices 148…399 = values 149…400.
        // 400 − 252 + 1 = 149 (first kept); 400 (last kept). Derived by hand.
        let h = history("AAA", bars: 400, base: 1)
        let cache = HC.from(histories: ["AAA": h], universe: ["AAA"], savedAt: Date(timeIntervalSince1970: 0), maxBars: 252)
        let entry = cache.entries.first
        #expect(cache.entries.count == 1)
        #expect(entry?.closes.count == 252)
        #expect(entry?.closes.first == 149)
        #expect(entry?.closes.last == 400)
        #expect(entry?.dates.count == 252)   // dates trimmed in lock-step with closes
    }

    // 3. Universe eviction: a symbol absent from `universe` is dropped; a present one survives.
    @Test func fromDropsSymbolsNotInUniverse() {
        let hs = ["AAA": history("AAA", bars: 5), "BBB": history("BBB", bars: 5)]
        let cache = HC.from(histories: hs, universe: ["AAA"], savedAt: Date(timeIntervalSince1970: 0))
        #expect(cache.entries.count == 1)
        #expect(cache.entries.first?.symbol == "AAA")
    }

    // 4. Schema-version + corruption guard: wrong version → nil; malformed JSON → nil; current → non-nil.
    @Test func decodeRejectsWrongVersionAndMalformed() throws {
        let wrong = HC(schemaVersion: 999, entries: [], savedAt: Date(timeIntervalSince1970: 0))
        #expect(HC.decode(try JSONEncoder().encode(wrong)) == nil)      // version mismatch → clean nil
        let ok = HC(schemaVersion: HC.currentSchemaVersion, entries: [], savedAt: Date(timeIntervalSince1970: 0))
        #expect(HC.decode(try JSONEncoder().encode(ok)) != nil)         // current version → decodes
        #expect(HC.decode(Data("{\"schemaVersion\":1}".utf8)) == nil)   // missing entries/savedAt → decode fails, no guess
    }

    // 5. Staleness straddle (F05): full-day age 7 → fresh, 8 → stale; unknown symbol → stale.
    @Test func isStaleStraddlesTheDayBoundary() {
        let newest = Date(timeIntervalSince1970: 100 * 86_400)
        let e = HC.Entry(symbol: "AAA", dates: [newest], opens: [1], highs: [1], lows: [1], closes: [1], volumes: [1])
        let cache = HC(schemaVersion: HC.currentSchemaVersion, entries: [e], savedAt: newest)
        let asOf7 = Date(timeIntervalSince1970: 107 * 86_400)   // exactly 7 full days later
        let asOf8 = Date(timeIntervalSince1970: 108 * 86_400)   // 8 full days later
        #expect(cache.isStale(symbol: "AAA", asOf: asOf7, maxAgeDays: 7) == false)  // 7 > 7 is false → fresh
        #expect(cache.isStale(symbol: "AAA", asOf: asOf8, maxAgeDays: 7) == true)   // 8 > 7 → stale
        #expect(cache.isStale(symbol: "ZZZ", asOf: asOf7, maxAgeDays: 7) == true)   // unknown → stale (absence ≠ fresh)
    }

    // 6. The O6 unblock: cached candles feed StockSageNetCostSim (was 0 usable panels offline).
    //    3 symbols × 40 shared daily bars → 39 aligned returns each; lookback 5 + hold 2 ⇒ ≥ 4 rebalances.
    @Test func cachedHistoriesEnableTheNetCostSim() {
        let hs = ["AAA": history("AAA", bars: 40, base: 100),
                  "BBB": history("BBB", bars: 40, base: 50),
                  "CCC": history("CCC", bars: 40, base: 200)]
        let cache = HC.from(histories: hs, universe: ["AAA", "BBB", "CCC"], savedAt: Date(timeIntervalSince1970: 39 * 86_400))
        let panel = HC.panel(from: cache.priceHistories(), industryOf: { $0 == "CCC" ? 1 : 0 })
        #expect(panel != nil)
        guard let panel else { Issue.record("panel builder returned nil from a valid 3-symbol cache"); return }
        #expect(panel.symbolCount == 3)
        let result = StockSageNetCostSim.simulate(panel, lookback: 5, hold: 2, roundTripBps: 13)
        #expect(result != nil)                              // ← the unblock: cached data now simulates
        #expect((result?.rebalances.count ?? 0) >= 4)       // ≥ 4 rebalances (the sim's own non-nil floor)
    }
}
