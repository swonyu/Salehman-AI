import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Today's ranked action list (FASTMONEY_BACKLOG #4)

struct StockSageTodayPlanRankedTests {

    private func idea(_ symbol: String, action: TradeAdvice.Action = .strongBuy, conviction: Double,
                      price: Double = 100, stop: Double?, target: Double?) -> StockSageIdea {
        StockSageIdea(symbol: symbol, market: "M", price: price,
                      advice: TradeAdvice(action: action, conviction: conviction, regime: .bullTrend, rationale: [],
                                          stopPrice: stop, targetPrice: target, suggestedWeight: 0.05, caveat: "x"),
                      spark: [])
    }

    // A comfortably-clear setup: normal stop distance ⇒ costs barely register ⇒ net R:R ≥ 2.
    private func clearIdea(_ symbol: String, conviction: Double = 0.95, price: Double = 100,
                           riskAbs: Double = 5, rewardAbs: Double = 20) -> StockSageIdea {
        idea(symbol, conviction: conviction, price: price, stop: price - riskAbs, target: price + rewardAbs)
    }

    @Test func orderMatchesFastLaneCappedAtThree() {
        let ideas = [clearIdea("A", conviction: 0.6, riskAbs: 5, rewardAbs: 11),
                     clearIdea("B", conviction: 0.95, riskAbs: 2, rewardAbs: 12),
                     clearIdea("C", conviction: 0.8, riskAbs: 4, rewardAbs: 16),
                     clearIdea("D", conviction: 0.7, riskAbs: 6, rewardAbs: 13)]
        let lane = StockSageExpectedValue.fastLane(ideas)
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        #expect(plans.count == Swift.min(3, lane.count))
        #expect(plans.map(\.symbol) == Array(lane.prefix(3)).map(\.symbol))
    }

    @Test func sharesXorNilAccount() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let noAccount = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        #expect(!noAccount.isEmpty)
        for p in noAccount { #expect(p.shares == nil && p.dollarsAtRisk == nil) }

        let withAccount = StockSageTodayPlan.rankedActions(ideas, account: 10_000, riskFraction: 0.01)
        #expect(!withAccount.isEmpty)
        for p in withAccount { #expect(p.shares != nil && p.dollarsAtRisk != nil) }
    }

    @Test func everyPlanCarriesADefinedStopAndTarget() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        for p in plans { #expect(p.stop > 0 && p.target > 0 && p.entry > 0) }
    }

    @Test func gateVerdictMatchesTradeGateEvaluateOnTheSameInputs() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: 0.01)
        for p in plans {
            let rr = StockSageNetEdge.netRR(symbol: p.symbol, entry: p.entry, stop: p.stop, target: p.target)
                ?? abs(p.target - p.entry) / abs(p.entry - p.stop)
            let expected = StockSageTradeGate.evaluate(hasStop: true, rewardToRisk: rr, riskFraction: 0.01)
            #expect(p.gate == expected)
        }
    }

    // An oversized risk% (5%, above the gate's 2% cap) deterministically blocks every plan,
    // regardless of the setup's own R:R — the cleanest way to force a known-blocked row.
    @Test func overRiskCapBlocksEveryPlanAndTheRowIsFlagged() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15),
                     clearIdea("C", conviction: 0.85, riskAbs: 4, rewardAbs: 18)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: 10_000, riskFraction: 0.05)
        #expect(!plans.isEmpty)
        for p in plans { #expect(p.gate.decision == .blocked) }
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("DO NOT TRADE"))
        for p in plans { #expect(text.contains(p.symbol)) }
    }

    @Test func copyTextParsesWithSymbolVelocityAndStop() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: 10_000, riskFraction: 0.01)
        let text = StockSageTodayPlan.copyAllText(plans)
        let lines = text.split(separator: "\n")
        #expect(lines.count >= plans.count)
        for p in plans {
            #expect(text.contains(p.symbol))
            #expect(text.contains("R/day"))
            #expect(text.contains(String(format: "%.2f", p.stop)))
        }
    }

    @Test func caveatSweepContainsEstimateAndPerTradeRiskCap() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        let text = StockSageTodayPlan.copyAllText(plans).lowercased()
        #expect(text.contains("estimate"))
        #expect(text.contains("per-trade risk cap") || text.contains("per trade"))
    }

    @Test func cryptoSuffixShownUpfront() {
        let ideas = [idea("BTC-USD", conviction: 0.9, price: 100, stop: 95, target: 120),
                     clearIdea("AAPL", conviction: 0.85, riskAbs: 3, rewardAbs: 15)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil)
        #expect(plans.contains { $0.symbol == "BTC-USD" && $0.isCrypto })
        #expect(plans.contains { $0.symbol == "AAPL" && !$0.isCrypto })
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("BTC-USD (24/7 crypto)"))
        #expect(!text.contains("AAPL (24/7 crypto)"))
    }

    // Thin-but-gross-positive setup (conviction exactly AT minConvictionToRank, so isLowConviction
    // is false and this isolates the floor flag): p=0.442, R:R=1.4 → grossEvR≈0.061 (clears
    // fastLane's evR>0 filter) but netExpectancyR≈0.035 ÷ 12-day equity hold ≈0.0029R/day, under
    // the 0.005 floor. Hand-verified via a standalone Swift snippet mirroring ev()/netEVR()/
    // netVelocity() exactly before writing this fixture.
    @Test func rankedActionPlanSurfacesTheNetCostFloorFlagWhenBelowIt() {
        let thin = idea("A", conviction: 0.40, price: 100, stop: 95, target: 107)
        let comfortable = clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)
        let plans = StockSageTodayPlan.rankedActions([thin, comfortable], account: nil, riskFraction: nil, max: 2)
        guard let thinPlan = plans.first(where: { $0.symbol == "A" }) else {
            Issue.record("expected A's positive-but-thin gross EV to clear fastLane's filter")
            return
        }
        #expect(thinPlan.netCostFloorFlag.isDeranked)
        #expect(!thinPlan.isLowConviction)   // isolates: this row is flagged for cost, not conviction
        guard let comfortablePlan = plans.first(where: { $0.symbol == "B" }) else {
            Issue.record("expected B in the plan list")
            return
        }
        #expect(!comfortablePlan.netCostFloorFlag.isDeranked)
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("below net-cost floor"))
    }

    // Low-conviction (0.20 < 0.40 minConvictionToRank) but comfortable 3:1 R:R keeps net EV/day
    // well above the floor — isolates the conviction flag from the cost flag. Hand-verified:
    // netExpectancyR≈0.558, netVelocity≈0.0465R/day (well above 0.005).
    @Test func rankedActionPlanSurfacesLowConvictionWhenBelowTheRankingFloor() {
        let lowConv = idea("A", conviction: 0.20, price: 100, stop: 95, target: 115)
        let comfortable = clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15)
        let plans = StockSageTodayPlan.rankedActions([lowConv, comfortable], account: nil, riskFraction: nil, max: 2)
        guard let lowConvPlan = plans.first(where: { $0.symbol == "A" }) else {
            Issue.record("expected A's positive gross EV to clear fastLane's filter")
            return
        }
        #expect(lowConvPlan.isLowConviction)
        #expect(!lowConvPlan.netCostFloorFlag.isDeranked)   // isolates: flagged for conviction, not cost
        guard let comfortablePlan = plans.first(where: { $0.symbol == "B" }) else {
            Issue.record("expected B in the plan list")
            return
        }
        #expect(!comfortablePlan.isLowConviction)
        let text = StockSageTodayPlan.copyAllText(plans)
        #expect(text.contains("low conviction"))
    }

    @Test func neitherFlagFiresForACleanHighConvictionSetup() {
        let clean = clearIdea("A", conviction: 0.95, riskAbs: 5, rewardAbs: 20)
        let plans = StockSageTodayPlan.rankedActions([clean], account: nil, riskFraction: nil, max: 1)
        #expect(plans.count == 1)
        #expect(!plans[0].netCostFloorFlag.isDeranked)
        #expect(!plans[0].isLowConviction)
    }

    @Test func maxCapsBelowThree() {
        let ideas = [clearIdea("A"), clearIdea("B", conviction: 0.9, riskAbs: 3, rewardAbs: 15),
                     clearIdea("C", conviction: 0.85, riskAbs: 4, rewardAbs: 18)]
        let plans = StockSageTodayPlan.rankedActions(ideas, account: nil, riskFraction: nil, max: 1)
        #expect(plans.count == 1)
    }

    @Test func emptyIdeasProducesEmptyPlanList() {
        #expect(StockSageTodayPlan.rankedActions([], account: nil, riskFraction: nil).isEmpty)
    }
}
