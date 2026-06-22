import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Position-size calculator (pure)

struct StockSagePositionSizerTests {

    typealias PS = StockSagePositionSizer

    @Test func summaryLineStatesSharesRiskAndHonestyCaveat() {
        // account 10000 · 1% · entry 100 · stop 90 → risk/share 10, budget 100 → 10 shares, $100 at risk, 10% acct.
        let ps = PS.size(account: 10000, riskFraction: 0.01, entry: 100, stop: 90)!
        #expect(ps.shares == 10)
        #expect(abs(ps.dollarsAtRisk - 100) < 1e-9)
        let line = PS.summaryLine(ps, riskPct: 1)
        #expect(line.contains("10 shares"))
        #expect(line.contains("$100"))
        #expect(line.lowercased().contains("loss"))      // honesty: sizes the loss
    }

    @Test func sizesToTheRiskBudget() {
        // $10k account, 1% risk = $100 budget; $10 stop distance → 10 shares.
        let p = PS.size(account: 10_000, riskFraction: 0.01, entry: 100, stop: 90)!
        #expect(p.shares == 10)
        #expect(abs(p.dollarsAtRisk - 100) < 1e-9)
        #expect(abs(p.notional - 1000) < 1e-9)
        #expect(abs(p.pctOfAccount - 10) < 1e-9)
    }

    @Test func roundsDownNeverOverRisking() {
        // $100 budget ÷ $12 stop = 8.33 → 8 shares, $96 at risk (≤ budget).
        let p = PS.size(account: 10_000, riskFraction: 0.01, entry: 50, stop: 38)!
        #expect(p.shares == 8)
        #expect(abs(p.dollarsAtRisk - 96) < 1e-9)
        #expect(p.dollarsAtRisk <= 100)
    }

    @Test func worksForAShort() {
        // entry 50, stop 55 → risk/share 5; $100 budget → 20 shares.
        let p = PS.size(account: 10_000, riskFraction: 0.01, entry: 50, stop: 55)!
        #expect(p.shares == 20)
        #expect(abs(p.dollarsAtRisk - 100) < 1e-9)
    }

    @Test func entryEqualsStopIsNil() {
        #expect(PS.size(account: 10_000, riskFraction: 0.01, entry: 100, stop: 100) == nil)
    }

    @Test func invalidInputsAreNil() {
        #expect(PS.size(account: 0, riskFraction: 0.01, entry: 100, stop: 90) == nil)
        #expect(PS.size(account: 10_000, riskFraction: 0, entry: 100, stop: 90) == nil)
        #expect(PS.size(account: 10_000, riskFraction: 0.01, entry: -1, stop: 90) == nil)
    }
}
