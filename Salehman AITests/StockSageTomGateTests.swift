import Testing
import Foundation
@testable import Salehman_AI

// TOM state pin. History: shipped as a default-OFF status lock (2026-07-09 morning, research
// chain underpowered), then ACTIVATED the same day by explicit owner direction ("WIRE
// ACTIVATE") — an owner call, not an evidence promotion; the research lane stays OPEN.
// This suite pins the RATIFIED state so any silent flip (either direction) fails loudly.
struct StockSageTomGateTests {
    @Test func turnOfMonthFlagMatchesOwnerActivatedState() {
        #expect(StockSageAdvisor.turnOfMonthEnabled == true,
                "TOM was owner-activated 2026-07-09 (\"WIRE ACTIVATE\"); changing this default is an owner decision — update this pin only with a cited owner order")
    }

    @Test func seasonalityBonusIsInertWhenFlagIsOff() {
        let saved = StockSageAdvisor.turnOfMonthEnabled
        defer { StockSageAdvisor.turnOfMonthEnabled = saved }
        StockSageAdvisor.turnOfMonthEnabled = false

        let idea = StockSageIdea(
            symbol: "GATE", market: "M", price: 100,
            advice: TradeAdvice(action: .buy, conviction: 0.8, regime: .bullTrend, rationale: [],
                                stopPrice: 90, targetPrice: 120, suggestedWeight: 0.05, caveat: "x"),
            spark: [])
        let m = StockSageSeasonality.currentMonth()
        let s = MonthlySeasonality(months: (1...12).map { month in
            MonthlySeasonality.MonthStat(month: month,
                                         avgReturn: month == m ? 0.05 : 0,
                                         samples: month == m ? 8 : 0)
        }, years: 8)
        // Flag OFF ⇒ the bonus must be EXACTLY zero even with a strong, reliable month stat.
        #expect(StockSageExpectedValue.seasonalityRankBonus(for: idea, seasonality: ["GATE": s]) == 0)
    }

    private func gateIdea(_ symbol: String) -> StockSageIdea {
        StockSageIdea(
            symbol: symbol, market: "M", price: 100,
            advice: TradeAdvice(action: .buy, conviction: 0.8, regime: .bullTrend, rationale: [],
                                stopPrice: 90, targetPrice: 120, suggestedWeight: 0.05, caveat: "x"),
            spark: [])
    }

    private func monthFixture(mean: Double, std: Double, samples: Int) -> MonthlySeasonality {
        let m = StockSageSeasonality.currentMonth()
        return MonthlySeasonality(months: (1...12).map { month in
            MonthlySeasonality.MonthStat(month: month,
                                         avgReturn: month == m ? mean : 0,
                                         samples: month == m ? samples : 0,
                                         stdDev: month == m ? std : 0)
        }, years: Double(samples))
    }

    @Test func noisyMonthIsGatedToZeroDespitePositiveMean() {
        let saved = StockSageAdvisor.turnOfMonthEnabled
        defer { StockSageAdvisor.turnOfMonthEnabled = saved }
        StockSageAdvisor.turnOfMonthEnabled = true
        // Yearly returns [+10%, −8%, +7%]: mean +3% but std 0.09643650760992956 →
        // t = 0.5388… < 1 (hand-derived, /tmp/derive_seasonality_robustness.swift) → NO tilt.
        let s = monthFixture(mean: 0.03, std: 0.09643650760992956, samples: 3)
        #expect(StockSageExpectedValue.seasonalityRankBonus(for: gateIdea("NOISY"),
                                                            seasonality: ["NOISY": s]) == 0)
    }

    @Test func consistentMonthTiltsByTheHandDerivedAmount() {
        let saved = StockSageAdvisor.turnOfMonthEnabled
        defer { StockSageAdvisor.turnOfMonthEnabled = saved }
        StockSageAdvisor.turnOfMonthEnabled = true
        // Yearly returns [+10%, +4%, +7%]: mean 0.07, std 0.03 → t = 4.0414… ≥ 1 → tilt fires.
        // Hand-derived bonus: cap(0.07 → 0.03) × reliability(3/5) = 0.018.
        let s = monthFixture(mean: 0.07, std: 0.03, samples: 3)
        let bonus = StockSageExpectedValue.seasonalityRankBonus(for: gateIdea("STEADY"),
                                                                seasonality: ["STEADY": s])
        #expect(abs(bonus - 0.018) < 1e-12)
    }
}
