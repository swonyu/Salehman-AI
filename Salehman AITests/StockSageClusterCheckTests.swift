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

    @Test func excludesAZeroVarianceHoldingRatherThanTreatingItAsDiversifying() {
        // A flat (zero-variance) holding's correlation with the candidate is UNDEFINED (0/0), not
        // a genuine "uncorrelated" 0 — it must be excluded from nearest/highlyCorrelated, not let
        // through as a fake diversifying match.
        let flat: [Double] = [0.0, 0.0, 0.0, 0.0]
        let r = CK.check(candidate: "NEW", candidateReturns: cand,
                         holdings: [("A", identical), ("FLAT", flat)])!
        #expect(r.highlyCorrelated.map(\.symbol) == ["A"])   // FLAT never appears
        #expect(r.nearest?.symbol == "A")                    // FLAT never becomes "nearest"

        // When the ONLY holding is flat, there's nothing usable to compare against — nearest is
        // nil and nothing is flagged, rather than a flat holding masquerading as "diversifying".
        let onlyFlat = CK.check(candidate: "NEW", candidateReturns: cand, holdings: [("FLAT", flat)])!
        #expect(onlyFlat.nearest == nil)
        #expect(onlyFlat.highlyCorrelated.isEmpty)
        #expect(!onlyFlat.isConcentrating)
    }
}
