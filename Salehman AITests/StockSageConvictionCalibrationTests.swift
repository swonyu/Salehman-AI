import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Conviction → win-probability calibration (pure)

struct StockSageConvictionCalibrationTests {
    typealias Cal = StockSageConvictionCalibration

    @Test func fitReturnsNilBelowMinSamples() {
        let few = (0..<10).map { (conviction: Double($0) / 10, won: $0.isMultiple(of: 2)) }
        #expect(Cal.fit(few, minSamples: 30) == nil)
    }

    @Test func wilsonLowerBoundIsConservativeAndBounded() {
        // 8/10 raw = 0.8, but the lower bound must sit BELOW it (small-sample haircut) and in [0,1].
        let lb = Cal.wilsonLowerBound(wins: 8, n: 10, z: 1.0)
        #expect(lb < 0.8)
        #expect(lb > 0)
        #expect(Cal.wilsonLowerBound(wins: 0, n: 0) == 0)          // no data → 0
        #expect(Cal.wilsonLowerBound(wins: 10, n: 10) < 1.0)       // even all-wins isn't certainty
        // More samples at the same rate → a TIGHTER (higher) lower bound.
        #expect(Cal.wilsonLowerBound(wins: 80, n: 100) > Cal.wilsonLowerBound(wins: 8, n: 10))
    }

    @Test func poolAdjacentViolatorsProducesMonotoneResult() {
        let out = Cal.poolAdjacentViolators([0.6, 0.3, 0.5], weights: [1, 1, 1])
        #expect(out.count == 3)
        for i in 1..<out.count { #expect(out[i] >= out[i - 1] - 1e-9) }   // non-decreasing
        // The first two violate (0.6 > 0.3) → pooled to their mean 0.45.
        #expect(abs(out[0] - 0.45) < 1e-9)
        #expect(abs(out[1] - 0.45) < 1e-9)
        // Already-monotone input is returned unchanged.
        #expect(Cal.poolAdjacentViolators([0.1, 0.2, 0.9], weights: [1, 1, 1]) == [0.1, 0.2, 0.9])
    }

    @Test func higherConvictionCalibratesToHigherWinProb() {
        // Low-conviction trades mostly lose; high-conviction trades mostly win.
        var outcomes: [(conviction: Double, won: Bool)] = []
        for i in 0..<20 { outcomes.append((conviction: 0.1, won: i < 4)) }   // 20% win
        for i in 0..<20 { outcomes.append((conviction: 0.9, won: i < 16)) }  // 80% win
        let cal = Cal.fit(outcomes, minSamples: 30)
        #expect(cal != nil)
        guard let cal else { return }
        #expect(cal.sampleSize == 40)
        #expect(cal.winProb(0.9) > cal.winProb(0.1))            // edge increases with conviction
        #expect(cal.winProb(0.9) < 0.8)                         // conservative: below the raw 80%
        // Bands are monotonic non-decreasing by construction.
        for i in 1..<cal.bins.count { #expect(cal.bins[i].winProb >= cal.bins[i - 1].winProb - 1e-9) }
    }

    @Test func isotonicFixesAnInvertedSample() {
        // A LUCKY low-conviction band beats a high-conviction one — calibration must not reward it:
        // the monotone fit pools the violation so winProb never decreases with conviction.
        var outcomes: [(conviction: Double, won: Bool)] = []
        for i in 0..<15 { outcomes.append((conviction: 0.1, won: i < 12)) }  // 80% (lucky low band)
        for i in 0..<15 { outcomes.append((conviction: 0.9, won: i < 6)) }   // 40% high band
        let cal = Cal.fit(outcomes, minSamples: 20)
        #expect(cal != nil)
        guard let cal else { return }
        #expect(cal.winProb(0.9) >= cal.winProb(0.1) - 1e-9)   // monotonicity restored
    }

    @Test func winProbClampsAndLooksUpBand() {
        let outcomes = (0..<40).map { (conviction: Double($0 % 10) / 10, won: ($0 % 10) >= 5) }
        guard let cal = Cal.fit(outcomes, minSamples: 30) else { Issue.record("expected a fit"); return }
        #expect(cal.winProb(-5) == cal.winProb(0))     // clamps low
        #expect(cal.winProb(5) == cal.winProb(1))      // clamps high
    }

    @Test func fitFromBacktestUsesPositiveRAsWin() {
        // Build trades: high-conviction winners (r>0), low-conviction losers (r<0).
        var trades: [BacktestTrade] = []
        for _ in 0..<20 { trades.append(BacktestTrade(entryIndex: 0, exitIndex: 1, entry: 100, exit: 110,
                                                      r: 2.0, outcome: .target, conviction: 0.9)) }
        for _ in 0..<20 { trades.append(BacktestTrade(entryIndex: 0, exitIndex: 1, entry: 100, exit: 95,
                                                      r: -1.0, outcome: .stop, conviction: 0.1)) }
        let cal = Cal.fit(fromBacktest: trades, minSamples: 30)
        #expect(cal != nil)
        #expect((cal?.winProb(0.9) ?? 0) > (cal?.winProb(0.1) ?? 1))
    }

    @Test func expectedValueUsesCalibrationWhenProvided() {
        // Without calibration → the linear prior (0.35 + 0.23·c).
        #expect(abs(StockSageExpectedValue.winProbEstimate(conviction: 0.5) - (0.35 + 0.23 * 0.5)) < 1e-9)
        // With calibration → the calibrated band value, not the prior.
        var outcomes: [(conviction: Double, won: Bool)] = []
        for i in 0..<30 { outcomes.append((conviction: 0.9, won: i < 24)) }   // 80%
        for i in 0..<10 { outcomes.append((conviction: 0.1, won: i < 1)) }    // 10%
        guard let cal = StockSageConvictionCalibration.fit(outcomes, minSamples: 30) else {
            Issue.record("expected a fit"); return
        }
        let calibrated = StockSageExpectedValue.winProbEstimate(conviction: 0.9, calibration: cal)
        #expect(calibrated == cal.winProb(0.9))
        #expect(calibrated != 0.35 + 0.23 * 0.9)   // differs from the linear prior
        // EV plumbs it through too.
        let ev = StockSageExpectedValue.ev(conviction: 0.9, entry: 100, stop: 90, target: 120, calibration: cal)
        #expect(ev?.winProbEstimate == cal.winProb(0.9))
    }
}
