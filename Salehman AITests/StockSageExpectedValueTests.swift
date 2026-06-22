import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Expected value (pure)

struct StockSageExpectedValueTests {

    typealias EV = StockSageExpectedValue

    @Test func winProbBandIsConservative() {
        #expect(abs(EV.winProbEstimate(conviction: 0) - 0.35) < 1e-9)
        #expect(abs(EV.winProbEstimate(conviction: 1) - 0.58) < 1e-9)
        #expect(EV.winProbEstimate(conviction: 5) == 0.58)    // clamped
        #expect(EV.winProbEstimate(conviction: -1) == 0.35)   // clamped
    }

    @Test func evCombinesProbabilityAndReward() {
        // conviction 1 → p 0.58; R:R = 20/10 = 2 → EV = 0.58·2 − 0.42 = 0.74.
        let high = EV.ev(conviction: 1, entry: 100, stop: 90, target: 120)!
        #expect(abs(high.rewardR - 2) < 1e-9)
        #expect(abs(high.evR - 0.74) < 1e-9)
        #expect(high.isPositive)
        // conviction 0 → p 0.35; same 2:1 → EV = 0.70 − 0.65 = 0.05 (barely positive).
        let low = EV.ev(conviction: 0, entry: 100, stop: 90, target: 120)!
        #expect(abs(low.evR - 0.05) < 1e-9)
        // A higher-EV setup ranks above a lower one.
        #expect(high.evR > low.evR)
    }

    @Test func noDefinedRiskOrRewardIsNil() {
        #expect(EV.ev(conviction: 0.8, entry: 100, stop: 100, target: 120) == nil)   // no risk
        #expect(EV.ev(conviction: 0.8, entry: 100, stop: 90, target: 100) == nil)    // no reward
    }

    private func idea(_ symbol: String, action: TradeAdvice.Action = .buy, conviction: Double,
                      stop: Double?, target: Double?) -> StockSageIdea {
        StockSageIdea(symbol: symbol, market: "M", price: 100,
                      advice: TradeAdvice(action: action, conviction: conviction, regime: .bullTrend, rationale: [],
                                          stopPrice: stop, targetPrice: target, suggestedWeight: 0.05, caveat: "x"),
                      spark: [])
    }

    @Test func velocityRewardsFastTurnover() {
        // Same EV (1.228), but crypto hold 3 beats equity hold 12.
        let equity = idea("AAPL", conviction: 0.9, stop: 90, target: 130)
        let crypto = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130)
        let ve = EV.velocity(for: equity)!, vc = EV.velocity(for: crypto)!
        #expect(abs(ve - 1.228 / 12) < 1e-9)
        #expect(abs(vc - 1.228 / 3) < 1e-9)
        #expect(vc > ve)
        #expect(EV.expectedHoldDays(forSymbol: "^GSPC") == nil)                            // index → no velocity
        #expect(EV.velocity(for: idea("EURUSD=X", conviction: 0.9, stop: 90, target: 130)) == nil)
    }

    @Test func bestOpportunityPicksHighestPositiveEVBuy() {
        let a = idea("A", action: .buy, conviction: 0.2, stop: 90, target: 120)        // EV 0.188
        let b = idea("B", action: .strongBuy, conviction: 0.9, stop: 90, target: 130)  // EV 1.228
        let c = idea("C", action: .sell, conviction: 0.9, stop: 90, target: 130)       // not buy-family
        let d = idea("D", action: .buy, conviction: 0.0, stop: 90, target: 110)        // EV −0.30 (negative)
        let best = EV.bestOpportunity([a, c, d, b])!
        #expect(best.idea.symbol == "B")
        #expect(abs(best.ev.evR - 1.228) < 1e-9)
        // No positive-EV buy idea → nil (don't manufacture one).
        #expect(EV.bestOpportunity([c, d]) == nil)
    }

    @Test func ranksIdeasByEVBestFirstNoEVLast() {
        // A: conv 0.2, 2:1 → EV 0.188 ; B: conv 0.9, 3:1 → EV 1.228 ; C: no stop → no EV.
        let a = idea("A", conviction: 0.2, stop: 90, target: 120)
        let b = idea("B", conviction: 0.9, stop: 90, target: 130)
        let c = idea("C", conviction: 0.9, stop: nil, target: nil)
        let ranked = EV.rankByEV([a, c, b])
        #expect(ranked.map(\.symbol) == ["B", "A", "C"])
    }
}
