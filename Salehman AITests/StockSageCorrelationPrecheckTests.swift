import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Portfolio-correlation pre-check (pure)

struct StockSageCorrelationPrecheckTests {

    typealias PC = StockSageCorrelationPrecheck

    @Test func emptyHoldingsReadsNoHoldings() {
        let r = PC.assess(candidate: [0.1, 0.2, 0.3, 0.4, 0.5], holdings: [])
        #expect(r.verdict == .noHoldings)
        #expect(r.comparedCount == 0)
    }

    @Test func perfectlyCorrelatedHoldingsConcentrate() {
        let base: [Double] = [0.01, -0.02, 0.03, -0.01, 0.02, 0.00, 0.015]
        let r = PC.assess(candidate: base, holdings: [("TWIN", base)])   // identical → corr 1
        #expect(r.verdict == .concentrating)
        #expect(r.isWarning)
        #expect(abs(r.avgCorrelation - 1.0) < 1e-9)
        #expect(r.mostCorrelatedSymbol == "TWIN")
    }

    @Test func antiCorrelatedHoldingDiversifies() {
        let base: [Double] = [0.01, -0.02, 0.03, -0.01, 0.02, 0.00, 0.015]
        let opp = base.map { -$0 }
        let r = PC.assess(candidate: base, holdings: [("HEDGE", opp)])   // corr −1
        #expect(r.verdict == .diversifying)
        #expect(!r.isWarning)
    }

    @Test func tooLittleOverlapIsSkipped() {
        // Only 3 overlapping points (< minOverlap 5) → nothing to compare → noHoldings.
        let r = PC.assess(candidate: [0.1, 0.2, 0.3], holdings: [("X", [0.1, 0.2, 0.3])])
        #expect(r.verdict == .noHoldings)
    }

    @Test func averagesAcrossHoldingsAndNamesTheMostCorrelated() {
        let base: [Double] = [0.01, -0.02, 0.03, -0.01, 0.02, 0.00, 0.015]
        // One identical (corr ~1), one anti (corr ~−1) → avg ~0 → neutral-ish (diversifying band).
        let r = PC.assess(candidate: base, holdings: [("SAME", base), ("OPP", base.map { -$0 })])
        #expect(r.comparedCount == 2)
        #expect(abs(r.avgCorrelation) < 1e-6)
        #expect(r.mostCorrelatedSymbol == "SAME")   // the positively-correlated one
    }
}
