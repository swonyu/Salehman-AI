import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Trade-plan export (pure)

struct StockSageTradePlanTests {

    private func advice() -> TradeAdvice {
        TradeAdvice(action: .buy, conviction: 0.72, regime: .bullTrend,
                    rationale: ["50DMA rising", "RSI not overbought"],
                    stopPrice: 95, targetPrice: 124, suggestedWeight: 0.08,
                    caveat: "Not a guarantee — manage your risk.")
    }

    @Test func planContainsTheKeyLinesAndCaveat() {
        let rr = StockSageRewardRisk.assess(entry: 100, stop: 95, target: 124)   // ratio 4.8 → strong
        let size = StockSagePositionSizer.size(account: 10_000, riskFraction: 0.01, entry: 100, stop: 95)
        let flags = [RiskFlag(label: "Earnings ≤3d", level: .high)]
        let plan = StockSageTradePlan.text(symbol: "AAPL", market: "NASDAQ", price: 100,
                                           advice: advice(), rewardRisk: rr, size: size, flags: flags)
        #expect(plan.contains("TRADE PLAN — AAPL (NASDAQ)"))
        #expect(plan.contains("Action: Buy"))
        #expect(plan.contains("Entry: 100.00"))
        #expect(plan.contains("Stop: 95.00"))
        #expect(plan.contains("Target: 124.00"))
        #expect(plan.contains("R:R:"))
        #expect(plan.contains("Size: 20 shares"))          // $100 budget ÷ $5 stop = 20
        #expect(plan.contains("Risk flags: Earnings ≤3d"))
        #expect(plan.contains("Why: 50DMA rising; RSI not overbought"))
        #expect(plan.contains("Not a guarantee"))          // the caveat is always present
    }

    @Test func planMirrorsTheLeverageWarning() {
        // entry 400, stop 399 → risk/share 1; $100 budget → 100 sh, notional $40k = 400% → leveraged.
        let lev = StockSagePositionSizer.size(account: 10_000, riskFraction: 0.01, entry: 400, stop: 399)
        let plan = StockSageTradePlan.text(symbol: "X", market: "M", price: 400,
                                           advice: advice(), rewardRisk: nil, size: lev, flags: [])
        #expect(plan.contains("margin/leverage"))
        // Normal sizing (20 sh, 20% of account) → no warning.
        let normal = StockSagePositionSizer.size(account: 10_000, riskFraction: 0.01, entry: 100, stop: 95)
        let plan2 = StockSageTradePlan.text(symbol: "X", market: "M", price: 100,
                                            advice: advice(), rewardRisk: nil, size: normal, flags: [])
        #expect(!plan2.contains("margin/leverage"))
    }

    @Test func planOmitsAbsentOptionalsButKeepsCaveat() {
        var a = advice()
        a = TradeAdvice(action: .hold, conviction: 0.3, regime: .range, rationale: [],
                        stopPrice: nil, targetPrice: nil, suggestedWeight: 0, caveat: "Stand aside.")
        let plan = StockSageTradePlan.text(symbol: "X", market: "M", price: 50,
                                           advice: a, rewardRisk: nil, size: nil, flags: [])
        #expect(!plan.contains("Stop:"))
        #expect(!plan.contains("R:R:"))
        #expect(!plan.contains("Risk flags:"))
        #expect(!plan.contains("Why:"))
        #expect(plan.contains("Stand aside."))             // caveat still there
    }
}
