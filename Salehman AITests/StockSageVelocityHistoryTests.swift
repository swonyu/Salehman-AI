import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Velocity history (pure)

struct StockSageVelocityHistoryTests {

    private func snaps(_ rs: [Double]) -> [VelocitySnapshot] {
        rs.enumerated().map { VelocitySnapshot(day: String(format: "2026-06-%02d", $0.offset + 1), weeklyR: $0.element) }
    }

    @Test func recordReplacesSameDayAndCaps() {
        var s = StockSageVelocityHistory.record([], day: "2026-06-01", weeklyR: 2.0)
        s = StockSageVelocityHistory.record(s, day: "2026-06-01", weeklyR: 3.0)   // same day → replace
        #expect(s.count == 1)
        #expect(s[0].weeklyR == 3.0)
        s = StockSageVelocityHistory.record(s, day: "2026-06-02", weeklyR: 4.0, maxDays: 2)
        s = StockSageVelocityHistory.record(s, day: "2026-06-03", weeklyR: 5.0, maxDays: 2)
        #expect(s.count == 2)
        #expect(s.map(\.day) == ["2026-06-02", "2026-06-03"])    // oldest dropped by the cap
    }

    @Test func changeSinceLastNamesTheMover() {
        let prev = VelocitySnapshot(day: "2026-06-01", weeklyR: 1.0, bestSymbol: "AAPL", fastestSymbol: "AAPL")
        let cur = VelocitySnapshot(day: "2026-06-02", weeklyR: 2.5, bestSymbol: "BTC-USD", fastestSymbol: "AAPL")
        let c = StockSageVelocityHistory.changeSinceLast([prev, cur])!
        #expect(abs(c.weeklyRDelta - 1.5) < 1e-9)
        #expect(c.bestChangedTo == "BTC-USD")      // best moved AAPL → BTC-USD
        #expect(c.fastestChangedTo == nil)         // fastest unchanged (AAPL)
        #expect(StockSageVelocityHistory.changeSinceLast([prev]) == nil)   // <2 → nil
    }

    @Test func snapshotDecodesLegacyJSONWithoutSymbols() {
        // Migration safety: snapshots persisted before the symbol fields must still decode.
        let legacy = #"{"day":"2026-06-01","weeklyR":2.0}"#.data(using: .utf8)!
        let s = try! JSONDecoder().decode(VelocitySnapshot.self, from: legacy)
        #expect(s.weeklyR == 2.0)
        #expect(s.bestSymbol == nil)
        #expect(s.fastestSymbol == nil)
    }

    @Test func lastDeltaIsLatestMinusPrevious() {
        #expect(abs(StockSageVelocityHistory.lastDelta(snaps([1, 3]))! - 2) < 1e-9)    // 3 − 1
        #expect(abs(StockSageVelocityHistory.lastDelta(snaps([3, 1]))! - (-2)) < 1e-9) // 1 − 3
        #expect(StockSageVelocityHistory.lastDelta(snaps([5])) == nil)                 // <2 → nil
    }

    @Test func trendComparesRecentHalfToEarly() {
        #expect(StockSageVelocityHistory.trend(snaps([1, 1, 3, 3]))?.direction == .rising)   // 1→3
        #expect(StockSageVelocityHistory.trend(snaps([3, 3, 1, 1]))?.direction == .fading)   // 3→1
        #expect(StockSageVelocityHistory.trend(snaps([2, 2, 2, 2]))?.direction == .flat)     // 2→2
        #expect(StockSageVelocityHistory.trend(snaps([1, 2, 3])) == nil)                     // <4 days
        // Odd count 5: half=2 → early[first 2]=1, recent[last 3]=3 → rising (no off-by-one crash).
        #expect(StockSageVelocityHistory.trend(snaps([1, 1, 3, 3, 3]))?.direction == .rising)
        let t = StockSageVelocityHistory.trend(snaps([1, 1, 3, 3]))!
        #expect(abs(t.earlyAvg - 1) < 1e-9)
        #expect(abs(t.recentAvg - 3) < 1e-9)
        #expect(abs(t.delta - 2) < 1e-9)
    }
}
