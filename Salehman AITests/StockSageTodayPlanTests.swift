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
        // F04-parity (2nd-read hunt, 2026-07-08): riskFraction must be supplied for the gate to
        // evaluate at all now — this test pins "no stop → gate blocks" given a real risk %, not
        // the honest-nil-gate path (that's rankedActionGateIsNilWhenRiskFractionNotSupplied below).
        let plan = StockSageTodayPlan.build(idea: i, ev: nil, account: nil, riskFraction: 0.01)
        #expect(plan.lowercased().contains("no stop"))
        #expect(plan.contains("Don't take this trade"))   // gate blocks on no stop
        #expect(!plan.contains("shares"))                 // no account → no size line
    }

    // F04-parity (2nd-read hunt, 2026-07-08): nil riskFraction must NOT fabricate a gate verdict
    // (the old `rf > 0 ? rf : 0.01` default always produced one) — mirrors
    // rankedActionGateIsNilWhenRiskFractionNotSuppliedAndCopyTextSaysNotEvaluated in
    // StockSageTodayPlanRankedTests.swift, but for the single-idea `build()` surface (the "Copy
    // today's plan" button, MarketsView.swift ~3878/~4215).
    @Test func rankedActionGateIsNilWhenRiskFractionNotSuppliedAndCopyTextSaysNotEvaluated() {
        let i = idea("AAPL", conviction: 0.9, stop: 90, target: 130)
        let plan = StockSageTodayPlan.build(idea: i, ev: nil, account: nil, riskFraction: nil)
        // Verbatim wording match with the sheet's copy-plan (MarketsView.swift ~5064-5065) and
        // copyAllText — all surfaces must agree on the exact same honest phrasing.
        #expect(plan.contains("Pre-trade gate: not evaluated — enter risk % to see the verdict."))
        #expect(!plan.contains("Clear to trade"))
        #expect(!plan.contains("Proceed with caution"))
        #expect(!plan.contains("Don't take this trade"))
    }

    // MARK: - TODAY-PARITY: held-position context (defaulted absent, held → present)

    @Test func heldContextAbsentWithoutPositions() {
        let i = idea("AAPL", conviction: 0.9, stop: 90, target: 130)
        // Defaulted `positions: []` — existing callers/tests byte-unchanged, no holds line.
        let plan = StockSageTodayPlan.build(idea: i, ev: StockSageExpectedValue.ev(for: i),
                                            account: 10_000, riskFraction: 0.01)
        #expect(!plan.contains("holds"))
        #expect(StockSagePortfolio.holding(for: "AAPL", in: []) == nil)   // pins the absent case
    }

    @Test func heldContextPresentWhenPositionsResolveViaStockSagePortfolioHolding() {
        let i = idea("AAPL", conviction: 0.9, stop: 90, target: 130)
        let positions = [PortfolioPosition(symbol: "AAPL", shares: 30, costBasis: 90)]
        let plan = StockSageTodayPlan.build(idea: i, ev: StockSageExpectedValue.ev(for: i),
                                            account: 10_000, riskFraction: 0.01, positions: positions)
        // Pinned against the SAME source-of-truth StockSagePortfolio.holding call, not a
        // re-derivation — can't silently diverge from the ideas board's own held-shares math.
        let expectedShares = StockSagePortfolio.holding(for: "AAPL", in: positions)?.shares
        #expect(expectedShares == 30)
        #expect(plan.contains("holds 30 sh"))
    }
}
