import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Correlation-cluster add pre-check (pure)

struct StockSageClusterCheckTests {
    typealias CK = StockSageClusterCheck

    // A clean, linearly-related set: A is identical to the candidate (corr +1),
    // B is its negation (corr −1).
    private let cand: [Double] = [0.01, -0.02, 0.03, -0.01]
    private var identical: [Double] { cand }
    private var negated: [Double] { cand.map { -$0 } }

    @Test func flagsAHighlyCorrelatedHolding() {
        let r = CK.check(candidate: "NEW",
                         candidateReturns: cand,
                         holdings: [("A", identical), ("B", negated)])!
        #expect(r.isConcentrating)
        #expect(r.highlyCorrelated.map(\.symbol) == ["A"])           // only the +1 holding
        #expect(abs(r.highlyCorrelated.first!.correlation - 1) < 1e-9)
        #expect(r.nearest?.symbol == "A")                            // highest positive corr
        #expect(r.note.contains("doubling down on A"))
    }

    @Test func anticorrelatedHoldingIsNotConcentration() {
        let r = CK.check(candidate: "NEW", candidateReturns: cand, holdings: [("B", negated)])!
        #expect(!r.isConcentrating)
        #expect(abs(r.nearest!.correlation - (-1)) < 1e-9)
        #expect(r.note.contains("adds diversification"))
    }

    @Test func skipsTheSameSymbolAndGuardsEmpties() {
        // Candidate already held under the same ticker → skipped → no other holdings → nil.
        #expect(CK.check(candidate: "A", candidateReturns: cand, holdings: [("a", identical)]) == nil)
        #expect(CK.check(candidate: "NEW", candidateReturns: cand, holdings: []) == nil)
        #expect(CK.check(candidate: "NEW", candidateReturns: [0.01], holdings: [("A", identical)]) == nil)  // too short
    }
}
