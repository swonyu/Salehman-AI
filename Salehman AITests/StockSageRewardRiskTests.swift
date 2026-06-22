import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Reward:risk quality (pure)

struct StockSageRewardRiskTests {

    typealias RR = StockSageRewardRisk

    // entry 100, stop 90 → risk 10. target varies.
    @Test func strongSetupHasHighRatioAndLowBreakeven() {
        // target 130 → reward 30, ratio 3.0 → strong; breakeven 1/(1+3)=0.25
        let r = RR.assess(entry: 100, stop: 90, target: 130)!
        #expect(abs(r.ratio - 3.0) < 1e-9)
        #expect(r.quality == .strong)
        #expect(abs(r.breakevenWinRate - 0.25) < 1e-9)
    }

    @Test func fairSetupAtRatioTwo() {
        // target 120 → reward 20, ratio 2.0 → fair; breakeven 1/3
        let r = RR.assess(entry: 100, stop: 90, target: 120)!
        #expect(abs(r.ratio - 2.0) < 1e-9)
        #expect(r.quality == .fair)
        #expect(abs(r.breakevenWinRate - (1.0 / 3.0)) < 1e-9)
    }

    @Test func poorSetupNeedsAMajorityWinRate() {
        // target 110 → reward 10, ratio 1.0 → poor; breakeven 0.5
        let r = RR.assess(entry: 100, stop: 90, target: 110)!
        #expect(abs(r.ratio - 1.0) < 1e-9)
        #expect(r.quality == .poor)
        #expect(abs(r.breakevenWinRate - 0.5) < 1e-9)
    }

    @Test func bandBoundaries() {
        // exactly 1.5 → fair, exactly 2.5 → strong (inclusive lower bounds)
        #expect(RR.assess(entry: 100, stop: 90, target: 115)!.quality == .fair)    // ratio 1.5
        #expect(RR.assess(entry: 100, stop: 90, target: 125)!.quality == .strong)  // ratio 2.5
    }

    @Test func zeroRiskOrRewardIsNil() {
        #expect(RR.assess(entry: 100, stop: 100, target: 120) == nil)   // risk 0
        #expect(RR.assess(entry: 100, stop: 90, target: 100) == nil)    // reward 0
    }
}
