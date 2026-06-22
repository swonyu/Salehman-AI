import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Today's plan (pure compose)

struct StockSageTodayPlanTests {

    private func idea(_ symbol: String, action: TradeAdvice.Action = .strongBuy, conviction: Double,
                      stop: Double?, target: Double?) -> StockSageIdea {
        StockSageIdea(symbol: symbol, market: "M", price: 100,
                      advice: TradeAdvice(action: action, conviction: conviction, regime: .bullTrend, rationale: [],
                                          stopPrice: stop, targetPrice: target, suggestedWeight: 0.05, caveat: "x"),
                      spark: [])
    }

    @Test func composesBestGateSizeAndCaveat() {
        let i = idea("BTC-USD", conviction: 0.9, stop: 90, target: 130)
        let plan = StockSageTodayPlan.build(idea: i, ev: StockSageExpectedValue.ev(for: i),
                                            account: 10_000, riskFraction: 0.01)
        #expect(plan.contains("BTC-USD"))
        #expect(plan.contains("Gate"))
        #expect(plan.contains("Clear to trade"))          // stop + 4:1 RR + 1% risk → clears
        #expect(plan.lowercased().contains("stop"))
        #expect(plan.lowercased().contains("estimate"))   // honesty
        #expect(plan.contains("1.") && plan.contains("2.") && plan.contains("3."))
        #expect(plan.contains("shares"))                  // size present (account+risk supplied)
    }

    @Test func sampleDataIsFlaggedInTheCopiedPlan() {
        let i = idea("AAPL", conviction: 0.9, stop: 90, target: 130)
        // Sample data → the copied plan (pasted into a broker) must carry the SAMPLE warning.
        let sample = StockSageTodayPlan.build(idea: i, ev: StockSageExpectedValue.ev(for: i),
                                              account: 10_000, riskFraction: 0.01, isSample: true)
        #expect(sample.uppercased().contains("SAMPLE"))
        #expect(sample.lowercased().contains("re-price"))
        // Live data (default) → no SAMPLE line, byte-for-byte the original behavior.
        let live = StockSageTodayPlan.build(idea: i, ev: StockSageExpectedValue.ev(for: i),
                                            account: 10_000, riskFraction: 0.01)
        #expect(!live.uppercased().contains("SAMPLE"))
    }

    @Test func noStopWarnsAndGateBlocks() {
        let i = idea("X", conviction: 0.9, stop: nil, target: nil)
        let plan = StockSageTodayPlan.build(idea: i, ev: nil, account: nil, riskFraction: nil)
        #expect(plan.lowercased().contains("no stop"))
        #expect(plan.contains("Don't take this trade"))   // gate blocks on no stop
        #expect(!plan.contains("shares"))                 // no account → no size line
    }
}
