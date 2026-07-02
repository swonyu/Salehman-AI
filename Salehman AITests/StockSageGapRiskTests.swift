import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Gap risk (pure) — a stop is a trigger, not a guaranteed fill.
// All literals python-verified.

struct StockSageGapRiskTests {
    typealias GR = StockSageGapRisk

    @Test func gapRiskExceedsOneRAndCanExceedAccount() {
        // Baseline: no gap → fills at the stop, exactly −1R, nothing beyond plan.
        let base = GR.scenario(side: .long, entry: 100, stop: 95, shares: 100, gapPct: 0, accountEquity: 10_000)!
        #expect(base.gapFillPrice == 95 && abs(base.rMultiple - 1) < 1e-9)
        #expect(base.beyondPlanDollars == 0 && !base.blowsThroughStop)
        // Long gaps 10% THROUGH the stop → fill 85.5, 2.9R, $1450 lost ($950 beyond the planned $500).
        let g = GR.scenario(side: .long, entry: 100, stop: 95, shares: 100, gapPct: 0.10, accountEquity: 10_000)!
        #expect(abs(g.gapFillPrice - 85.5) < 1e-9 && abs(g.rMultiple - 2.9) < 1e-9)
        #expect(abs(g.dollarsLost - 1450) < 1e-9 && abs(g.beyondPlanDollars - 950) < 1e-9 && g.blowsThroughStop)
        // Short mirrors it (gaps UP through the stop).
        let s = GR.scenario(side: .short, entry: 100, stop: 105, shares: 100, gapPct: 0.10, accountEquity: 10_000)!
        #expect(abs(s.gapFillPrice - 115.5) < 1e-9 && abs(s.rMultiple - 3.1) < 1e-9)
        // SACRED floor: a big gap can lose MORE than the account — accountLossPct NEVER clamped.
        let blow = GR.scenario(side: .long, entry: 100, stop: 95, shares: 100, gapPct: 0.35, accountEquity: 1_000)!
        #expect(blow.exceedsAccount && abs(blow.accountLossPct - 3.825) < 1e-9)
        #expect(blow.caveat.lowercased().contains("gap") && blow.verdict.lowercased().contains("more than"))
        // worstCase ladder: one per gap, ascending in loss.
        let wc = GR.worstCase(side: .long, entry: 100, stop: 95, shares: 100, accountEquity: 10_000)
        #expect(wc.count == 4)
        #expect(zip(wc, wc.dropFirst()).allSatisfy { $0.dollarsLost < $1.dollarsLost })
        // Guards → nil (no divide-by-zero / infinite size).
        #expect(GR.scenario(side: .long, entry: 100, stop: 100, shares: 100, gapPct: 0.1, accountEquity: 10_000) == nil)
        #expect(GR.scenario(side: .long, entry: 100, stop: 95, shares: 0, gapPct: 0.1, accountEquity: 10_000) == nil)
        #expect(GR.scenario(side: .long, entry: 100, stop: 95, shares: 100, gapPct: -0.1, accountEquity: 10_000) == nil)
        // Guard: stop must be on the correct side of entry for the given side, else nil
        // (a long's stop above entry, or a short's stop below entry, is not a valid risk scenario).
        #expect(GR.scenario(side: .long, entry: 100, stop: 105, shares: 100, gapPct: 0.1, accountEquity: 10_000) == nil)
        #expect(GR.scenario(side: .short, entry: 100, stop: 95, shares: 100, gapPct: 0.1, accountEquity: 10_000) == nil)
    }
}
