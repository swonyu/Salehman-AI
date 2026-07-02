import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Execution-timing advisory tests (pure, deterministic)
// Spec: RESEARCH_2026-07-02_week_horizon_velocity.md roadmap item #2
//   ✓ Trending buy/sell actions get the overnight-session note
//   ✓ Range regime never gets it (different signal type, not covered by the finding)
//   ✓ Hold/avoid never get it (not actionable)
//   ✓ caveat is non-empty

struct StockSageExecutionTimingTests {
    typealias ET = StockSageExecutionTiming

    @Test func trendingBuyGetsTheOvernightNote() {
        #expect(ET.sessionNote(action: .strongBuy, regime: .bullTrend) != nil)
        #expect(ET.sessionNote(action: .buy, regime: .bullTrend)!.lowercased().contains("overnight"))
    }

    @Test func trendingSellGetsTheOvernightNoteToo() {
        // Sell/reduce ideas are also a trend-following (short) construction — the finding covers
        // past-return strategies generally, not just long-side momentum.
        #expect(ET.sessionNote(action: .sell, regime: .bearTrend) != nil)
        #expect(ET.sessionNote(action: .reduce, regime: .bearTrend) != nil)
    }

    @Test func rangeRegimeNeverGetsTheNote() {
        // .range is the RSI-oversold-bounce / mean-reversion read, a structurally different
        // signal type than the past-return momentum families the finding covers.
        #expect(ET.sessionNote(action: .strongBuy, regime: .range) == nil)
        #expect(ET.sessionNote(action: .sell, regime: .range) == nil)
    }

    @Test func nonActionableAdviceNeverGetsTheNote() {
        #expect(ET.sessionNote(action: .hold, regime: .bullTrend) == nil)
        #expect(ET.sessionNote(action: .avoid, regime: .bullTrend) == nil)
        #expect(ET.sessionNote(action: .hold, regime: .range) == nil)
    }

    @Test func caveatIsNonEmptyAndHonest() {
        #expect(!ET.caveat.isEmpty)
        #expect(ET.caveat.lowercased().contains("not a promise"))
    }
}
