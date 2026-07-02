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

    // MARK: - wave-11 rrIsNet label tests (F16) — hand-derived via derive_wave11f.swift

    // (a) rrIsNet:true → check label reads "Net reward:risk (after est. costs) 2.5:1"
    // Derived: "Net reward:risk (after est. costs) 2.5:1 — positive skew"
    @Test func rrIsNetTrueLabelsNetCostCheck() {
        let v = G.evaluate(hasStop: true, rewardToRisk: 2.5, riskFraction: 0.01, rrIsNet: true)
        #expect(v.decision == .clear)
        let rrCheck = v.checks.first { $0.label.contains("reward:risk") }
        #expect(rrCheck != nil)
        if let c = rrCheck {
            // Label must contain the net prefix (not the bare "Reward:risk" prefix)
            #expect(c.label.contains("Net reward:risk (after est. costs) 2.5:1"))
        }
    }

    // (b) rrIsNet:false (default) → label is byte-identical to the old "Reward:risk 2.5:1 — positive skew"
    // Derived: "Reward:risk 2.5:1 — positive skew"
    // Note: "Reward:risk" has a capital R (gross label); search case-insensitively to find it.
    @Test func rrIsNetFalseDefaultLabelIsGrossPrefix() {
        let v = G.evaluate(hasStop: true, rewardToRisk: 2.5, riskFraction: 0.01, rrIsNet: false)
        #expect(v.decision == .clear)
        let rrCheck = v.checks.first { $0.label.lowercased().contains("reward:risk") }
        #expect(rrCheck != nil)
        if let c = rrCheck {
            // Must NOT contain "Net" prefix (that would indicate rrIsNet=true leaked through)
            #expect(!c.label.hasPrefix("Net"))
            #expect(c.label == "Reward:risk 2.5:1 \u{2014} positive skew")
        }
    }

    // (c) net-negative rr (-0.3) → blocked + "costs exceed the reward (net-negative)" fail label
    // Derived: "Net reward:risk (after est. costs) -0.3:1 — costs exceed the reward (net-negative)"
    @Test func netNegativeRRBlocksWithCostExceedFailLabel() {
        let v = G.evaluate(hasStop: true, rewardToRisk: -0.3, riskFraction: 0.01, rrIsNet: true)
        #expect(v.decision == .blocked)
        let rrCheck = v.checks.first { $0.label.contains("reward:risk") }
        #expect(rrCheck != nil)
        if let c = rrCheck {
            #expect(c.level == .fail)
            #expect(c.label.contains("costs exceed the reward (net-negative)"))
            // Must use the net prefix (rrIsNet:true)
            #expect(c.label.contains("Net reward:risk (after est. costs)"))
        }
    }
}
