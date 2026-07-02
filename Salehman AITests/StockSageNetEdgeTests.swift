import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Cost-aware net edge (pure)

struct StockSageNetEdgeTests {
    typealias NE = StockSageNetEdge

    @Test func breakEvenWinRateIsTheAfterCostBar() {
        // Clean 3:1, zero cost → netRR 3 → break-even p* = 1/(1+3) = 0.25.
        let e = NE.evaluate(entry: 100, stop: 90, target: 130)!
        #expect(abs(e.netRR - 3) < 1e-9)
        #expect(abs((e.breakEvenWinRate ?? -1) - 0.25) < 1e-9)
        #expect(e.clearsCost(estWinProb: 0.40))      // 40% beats the 25% bar
        #expect(!e.clearsCost(estWinProb: 0.20))     // 20% below it → fails
        // Costs that exceed the target → netRR ≤ 0 → no break-even, never clears at any win rate.
        let dead = NE.evaluate(entry: 100, stop: 99, target: 100.5, spreadBps: 100, slippageBps: 100)!
        #expect(dead.netRR <= 0)
        #expect(dead.breakEvenWinRate == nil)
        #expect(!dead.clearsCost(estWinProb: 0.99))
    }

    @Test func wideSetupBarelyDentedByCosts() {
        // entry 100, stop 95, target 110 → gross 2:1. 30bps round-trip + $0.05 comm = $0.35/sh.
        let e = NE.evaluate(entry: 100, stop: 95, target: 110,
                            spreadBps: 20, slippageBps: 10, commissionPerShare: 0.05, winProb: 0.5)!
        #expect(abs(e.grossRR - 2) < 1e-9)
        #expect(abs(e.costPerShare - 0.35) < 1e-9)
        #expect(abs(e.netRR - 9.65 / 5.35) < 1e-9)        // 1.8037…
        #expect(abs(e.costAsPctOfReward - 0.035) < 1e-9)  // 3.5% of the target
        #expect(abs(e.netExpectancyR! - 0.43) < 1e-9)     // (.5·9.65 − .5·5.35)/5
        #expect(!e.costErodesEdge)
        #expect(e.verdict.contains("acceptable"))
    }

    @Test func thinScalpEatenAliveByCosts() {
        // entry 100, stop 99, target 101 → gross 1:1. 100bps + $0.10 = $1.10/sh > the $1 target.
        let e = NE.evaluate(entry: 100, stop: 99, target: 101,
                            spreadBps: 50, slippageBps: 50, commissionPerShare: 0.10)!
        #expect(abs(e.costPerShare - 1.10) < 1e-9)
        #expect(e.netRR <= 0)                              // net reward negative
        #expect(e.costErodesEdge)
        #expect(e.verdict.contains("Costs exceed the target"))
    }

    @Test func zeroCostsLeaveGrossUnchanged() {
        let e = NE.evaluate(entry: 100, stop: 90, target: 130)!
        #expect(abs(e.grossRR - 3) < 1e-9 && abs(e.netRR - 3) < 1e-9)
        #expect(e.costPerShare == 0 && e.costAsPctOfReward == 0)
        #expect(e.netExpectancyR == nil)                  // no winProb → nil
    }

    @Test func defaultCostsScaleByAssetClass() {
        #expect(NE.defaultCosts(forSymbol: "BTC-USD").assetClass == "crypto")
        // 30 spread + 20 slippage + 20 round-trip taker fee (~0.1%/fill) = 70bps.
        #expect(NE.defaultCosts(forSymbol: "BTC-USD").roundTripBps == 70)
        #expect(NE.defaultCosts(forSymbol: "BTC-USD").takerFeeBps == 20)
        #expect(NE.defaultCosts(forSymbol: "EURUSD=X").assetClass == "FX")
        #expect(NE.defaultCosts(forSymbol: "EURUSD=X").roundTripBps == 7)
        #expect(NE.defaultCosts(forSymbol: "^GSPC").assetClass == "index")
        #expect(NE.defaultCosts(forSymbol: "2222.SR").assetClass == "intl")
        #expect(NE.defaultCosts(forSymbol: "2222.SR").roundTripBps == 30)
        #expect(NE.defaultCosts(forSymbol: "AAPL").assetClass == "US large-cap")
        #expect(NE.defaultCosts(forSymbol: "AAPL").roundTripBps == 13)
        // Crypto's wider spread must eat strictly more of the same setup than a US large-cap.
        let cr = NE.defaultCosts(forSymbol: "BTC-USD"), us = NE.defaultCosts(forSymbol: "AAPL")
        let eCr = NE.evaluate(entry: 100, stop: 90, target: 130, spreadBps: cr.spreadBps, slippageBps: cr.slippageBps)!
        let eUs = NE.evaluate(entry: 100, stop: 90, target: 130, spreadBps: us.spreadBps, slippageBps: us.slippageBps)!
        #expect(eCr.netRR < eUs.netRR)
    }

    @Test func worksForShortsAndGuardsDegenerate() {
        // Short: entry 100, stop 105 (above), target 90 (below) → gross 10/5 = 2:1.
        let s = NE.evaluate(entry: 100, stop: 105, target: 90, spreadBps: 0, slippageBps: 0)!
        #expect(abs(s.grossRR - 2) < 1e-9)
        #expect(NE.evaluate(entry: 100, stop: 100, target: 110) == nil)  // zero risk
        #expect(NE.evaluate(entry: 100, stop: 95, target: 100) == nil)   // zero reward
    }

    @Test func netExpectancyRAtExtremeWinProbs() {
        let e0 = StockSageNetEdge.evaluate(entry: 100, stop: 90, target: 130, winProb: 0)!
        let e1 = StockSageNetEdge.evaluate(entry: 100, stop: 90, target: 130, winProb: 1)!
        #expect(abs(e0.netExpectancyR! - (-1.0)) < 1e-9)
        #expect(abs(e1.netExpectancyR! - 3.0) < 1e-9)
    }

    @Test func financingCostShrinksNetFiguresAndDefaultsToZero() {
        // entry 100, stop 90, target 130 (risk 10, reward 30, R:R 3), no spread/slippage/commission
        // — isolates financing. rate 10%/yr over EXACTLY 365 days -> financingCost = entry*rate = 10
        // (rate·days/365 collapses to rate). Hand-verified via a standalone Swift snippet before
        // writing this fixture: no-financing netRR=3.0/netExpectancyR=1.0; with-financing
        // netRR=1.0/netExpectancyR=0.0 (financing DOUBLES effective risk here: netRisk 10->20).
        let noFinancing = NE.evaluate(entry: 100, stop: 90, target: 130, winProb: 0.5)!
        #expect(abs(noFinancing.netRR - 3.0) < 1e-9)
        #expect(abs(noFinancing.netExpectancyR! - 1.0) < 1e-9)

        let withFinancing = NE.evaluate(entry: 100, stop: 90, target: 130,
                                        annualFinancingRate: 0.10, holdDays: 365, winProb: 0.5)!
        #expect(abs(withFinancing.netRR - 1.0) < 1e-9)
        #expect(abs(withFinancing.netExpectancyR! - 0.0) < 1e-9)
        #expect(withFinancing.costPerShare > noFinancing.costPerShare)

        // Explicit rate/days: 0 (the default) must match omitting them entirely — same cost,
        // same net figures (compared field-by-field with tolerance, not whole-struct `==`, since
        // `verdict` is a formatted String and costPct/breakEven derive through several divisions).
        let explicitZero = NE.evaluate(entry: 100, stop: 90, target: 130,
                                       annualFinancingRate: 0, holdDays: 0, winProb: 0.5)!
        #expect(abs(explicitZero.costPerShare - noFinancing.costPerShare) < 1e-9)
        #expect(abs(explicitZero.netRR - noFinancing.netRR) < 1e-9)
        #expect(abs(explicitZero.netExpectancyR! - noFinancing.netExpectancyR!) < 1e-9)

        // A negative rate/days (caller bug) must not GENERATE a subsidy — clamped to 0, same as
        // every other cost input in this function.
        let negativeInputs = NE.evaluate(entry: 100, stop: 90, target: 130,
                                         annualFinancingRate: -0.5, holdDays: -100, winProb: 0.5)!
        #expect(abs(negativeInputs.costPerShare - noFinancing.costPerShare) < 1e-9)
        #expect(abs(negativeInputs.netRR - noFinancing.netRR) < 1e-9)
        #expect(abs(negativeInputs.netExpectancyR! - noFinancing.netExpectancyR!) < 1e-9)
    }

    @Test func hairThinStopCapsNetFiguresAtTheSame50to1CeilingEvUses() {
        // entry 100, stop 99.99 (risk 0.01), target 110 (reward 10) → gross 1000:1, a degenerate
        // stop distance. netRR/netExpectancyR/breakEvenWinRate must be derived from the SAME 50:1
        // ceiling ev() applies, not the raw 1000:1 ratio — otherwise the cost gate (clearsCost)
        // becomes toothless (breakEvenWinRate collapsing toward 0) for exactly this setup.
        let e = NE.evaluate(entry: 100, stop: 99.99, target: 110,
                            spreadBps: 8, slippageBps: 5, winProb: 0.5)!
        #expect(abs(e.grossRR - 1000) < 1)          // grossRR itself stays the true uncapped ratio
        #expect(e.netRR < 10)                        // capped netRR ≈ 2.64, nowhere near the uncapped ≈70.5
        #expect(abs(e.netRR - 0.37 / 0.14) < 1e-6)
        #expect(e.netExpectancyR! < 20)               // capped ≈ 11.5, nowhere near the uncapped ≈486.5
        #expect(abs(e.netExpectancyR! - 11.5) < 1e-3)
        #expect(e.breakEvenWinRate! > 0.2)            // capped ≈ 0.275, not an absurd ≈0.014 bar
        #expect(!e.clearsCost(estWinProb: 0.05))      // a 5% win rate must NOT clear a real 50:1-capped bar
    }
}
