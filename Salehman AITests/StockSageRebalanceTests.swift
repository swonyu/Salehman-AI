import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Rebalance-to-target (pure)

struct StockSageRebalanceTests {
    typealias RB = StockSageRebalance

    private func trade(_ p: RebalancePlan, _ sym: String) -> RebalanceTrade? {
        p.trades.first { $0.symbol == sym }
    }

    @Test func computesDriftTradesOutsideBand() {
        // A 60% / B 40% → target 50/50: sell 1000 of A, buy 1000 of B (total 10k).
        let p = RB.plan(holdings: [("A", 6000), ("B", 4000)], targets: ["A": 0.5, "B": 0.5])!
        #expect(abs(p.totalValue - 10_000) < 1e-9)
        #expect(abs(trade(p, "A")!.deltaValue - (-1000)) < 1e-9)
        #expect(abs(trade(p, "B")!.deltaValue - 1000) < 1e-9)
        #expect(trade(p, "A")!.action == "Sell" && trade(p, "B")!.action == "Buy")
    }

    @Test func noTradeBandSuppressesSmallDrift() {
        // Each side drifts only 0.01 < 0.02 band → nothing to do.
        let p = RB.plan(holdings: [("A", 6000), ("B", 4000)], targets: ["A": 0.59, "B": 0.41], band: 0.02)!
        #expect(p.trades.isEmpty)
        #expect(p.isBalanced)
    }

    @Test func normalizesTargetsAndSellsUntargetedToZero() {
        // targets sum 0.8 → normalize to A=1.0; B not targeted → sell fully.
        let p = RB.plan(holdings: [("A", 5000), ("B", 5000)], targets: ["A": 0.8])!
        #expect(abs(trade(p, "A")!.deltaValue - 5000) < 1e-9)    // cw .5 → tw 1.0 → buy 5000
        #expect(abs(trade(p, "B")!.deltaValue - (-5000)) < 1e-9) // cw .5 → tw 0 → sell 5000
    }

    @Test func equalWeightTargetsSumToOne() {
        let t = RB.equalWeightTargets(["A", "B", "C", "A"])   // dedups
        #expect(t.count == 3)
        #expect(abs((t["A"] ?? 0) - 1.0 / 3) < 1e-9)
        #expect(abs(t.values.reduce(0, +) - 1) < 1e-9)
    }

    @Test func guardsEmptyOrZero() {
        #expect(RB.plan(holdings: [], targets: ["A": 1]) == nil)          // nothing invested
        #expect(RB.plan(holdings: [("A", 1000)], targets: [:]) == nil)    // no targets
        #expect(RB.plan(holdings: [("A", 0)], targets: ["A": 1]) == nil)  // zero value
    }
}
