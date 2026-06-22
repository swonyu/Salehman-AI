import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Pre-trade gate (pure)

struct StockSageTradeGateTests {
    typealias G = StockSageTradeGate

    @Test func cleanTradeClears() {
        let v = G.evaluate(hasStop: true, rewardToRisk: 2.5, riskFraction: 0.01,
                           maxCorrelation: 0.3, daysToEarnings: 30)
        #expect(v.decision == .clear)
        #expect(v.fails == 0 && v.warns == 0)
    }

    @Test func noStopBlocks() {
        let v = G.evaluate(hasStop: false, rewardToRisk: 3.0, riskFraction: 0.01)
        #expect(v.decision == .blocked)            // undefined risk is an automatic no
        #expect(v.fails >= 1)
    }

    @Test func overRiskBlocks() {
        let v = G.evaluate(hasStop: true, rewardToRisk: 3.0, riskFraction: 0.03, maxRiskFraction: 0.02)
        #expect(v.decision == .blocked)            // 3% > 2% cap
    }

    @Test func negativeSkewBlocksButThinSkewOnlyCautions() {
        #expect(G.evaluate(hasStop: true, rewardToRisk: 0.8, riskFraction: 0.01).decision == .blocked)   // <1:1
        #expect(G.evaluate(hasStop: true, rewardToRisk: 1.5, riskFraction: 0.01).decision == .caution)   // 1–2:1
        #expect(G.evaluate(hasStop: true, rewardToRisk: 2.0, riskFraction: 0.01).decision == .clear)     // ≥2:1
    }

    @Test func correlationAndEarningsCaution() {
        // Highly correlated with the book → caution (not a hard block).
        #expect(G.evaluate(hasStop: true, rewardToRisk: 2.5, riskFraction: 0.01, maxCorrelation: 0.85).decision == .caution)
        // Earnings in 2 days → caution.
        #expect(G.evaluate(hasStop: true, rewardToRisk: 2.5, riskFraction: 0.01, daysToEarnings: 2).decision == .caution)
        // Earnings far out → clear.
        #expect(G.evaluate(hasStop: true, rewardToRisk: 2.5, riskFraction: 0.01, daysToEarnings: 20).decision == .clear)
    }

    @Test func failTrumpsWarn() {
        // A warn (thin skew) AND a fail (no stop) → blocked (fail wins).
        let v = G.evaluate(hasStop: false, rewardToRisk: 1.5, riskFraction: 0.01, maxCorrelation: 0.9)
        #expect(v.decision == .blocked)
        #expect(v.fails >= 1 && v.warns >= 1)
    }
}
