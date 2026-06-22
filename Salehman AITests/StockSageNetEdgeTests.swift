import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Cost-aware net edge (pure)

struct StockSageNetEdgeTests {
    typealias NE = StockSageNetEdge

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
        #expect(NE.defaultCosts(forSymbol: "BTC-USD").roundTripBps == 50)
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
}
