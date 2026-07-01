import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Cross-sectional relative-strength ranking (pure, standalone, NOT wired anywhere —
// HARDENING_BACKLOG #32, deliberately unwired pending a dedicated backtest)

struct StockSageRelativeStrengthTests {
    typealias RS = StockSageRelativeStrength

    @Test func distinctReturnsGetEvenlySpacedPercentilesWeakestToStrongest() {
        // python-verified: sorted A(-5) C(0) B(10) D(20), n=4, denom=3.
        let ranked = RS.rank(["A": -5.0, "B": 10.0, "C": 0.0, "D": 20.0])
        let byPct = Dictionary(uniqueKeysWithValues: ranked.map { ($0.symbol, $0.percentile) })
        #expect(abs(byPct["A"]! - 0.0) < 1e-9)
        #expect(abs(byPct["C"]! - (1.0 / 3.0)) < 1e-9)
        #expect(abs(byPct["B"]! - (2.0 / 3.0)) < 1e-9)
        #expect(abs(byPct["D"]! - 1.0) < 1e-9)
    }

    @Test func rankingIsMonotonicInTheInputReturn() {
        let ranked = RS.rank(["A": -5.0, "B": 10.0, "C": 0.0, "D": 20.0])
        let sortedByReturn = ranked.sorted { $0.inputReturnPct < $1.inputReturnPct }
        let sortedByPercentile = ranked.sorted { $0.percentile < $1.percentile }
        #expect(sortedByReturn.map(\.symbol) == sortedByPercentile.map(\.symbol))
    }

    @Test func everyPercentileIsBoundedZeroToOne() {
        let ranked = RS.rank(["A": -100.0, "B": 0.001, "C": 50.0, "D": -3.0, "E": 200.0])
        for r in ranked { #expect(r.percentile >= 0 && r.percentile <= 1) }
    }

    @Test func tiedReturnsGetTheAveragedPercentileNotAnArbitraryOrder() {
        // python-verified: A=0.0, B&C tie at 5.0 (avg idx 1,2 of 0...3 → 0.5), D=1.0.
        let ranked = RS.rank(["A": 0.0, "B": 5.0, "C": 5.0, "D": 10.0])
        let byPct = Dictionary(uniqueKeysWithValues: ranked.map { ($0.symbol, $0.percentile) })
        #expect(abs(byPct["A"]! - 0.0) < 1e-9)
        #expect(abs(byPct["B"]! - 0.5) < 1e-9)
        #expect(abs(byPct["C"]! - 0.5) < 1e-9)
        #expect(byPct["B"] == byPct["C"])   // exact tie, not merely close
        #expect(abs(byPct["D"]! - 1.0) < 1e-9)
    }

    @Test func allTiedReturnsAllLandAtTheNeutralMidpoint() {
        // python-verified: 3-way tie → every symbol lands at exactly 0.5.
        let ranked = RS.rank(["A": 5.0, "B": 5.0, "C": 5.0])
        for r in ranked { #expect(abs(r.percentile - 0.5) < 1e-9) }
    }

    @Test func singleHoldingIsNeutralNotTriviallyStrongest() {
        let ranked = RS.rank(["A": 7.0])
        #expect(ranked.count == 1)
        #expect(ranked[0].symbol == "A")
        #expect(abs(ranked[0].percentile - 0.5) < 1e-9)
        #expect(abs(ranked[0].inputReturnPct - 7.0) < 1e-9)
    }

    @Test func emptyInputReturnsEmptyNeverCrashes() {
        #expect(RS.rank([:]).isEmpty)
    }

    @Test func twoHoldingsSplitZeroAndOne() {
        let ranked = RS.rank(["A": -1.0, "B": 1.0])
        let byPct = Dictionary(uniqueKeysWithValues: ranked.map { ($0.symbol, $0.percentile) })
        #expect(abs(byPct["A"]! - 0.0) < 1e-9)
        #expect(abs(byPct["B"]! - 1.0) < 1e-9)
    }

    @Test func inputReturnPctIsPreservedVerbatim() {
        let ranked = RS.rank(["A": 12.345])
        #expect(ranked[0].inputReturnPct == 12.345)
    }

    @Test func caveatIsAlwaysPresentAndNamesTheTiebreakerLimit() {
        #expect(!RS.caveat.isEmpty)
        #expect(RS.caveat.localizedCaseInsensitiveContains("tiebreaker"))
    }
}
