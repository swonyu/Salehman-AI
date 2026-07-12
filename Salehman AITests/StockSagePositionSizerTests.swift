import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Position-size calculator (pure)

struct StockSagePositionSizerTests {

    typealias PS = StockSagePositionSizer

    @Test func sizeRejectsNonFiniteInputsInsteadOfCrashing() {
        // "inf"/"infinity" in a field parses to +Infinity, passes `> 0`, and would trap at
        // Int(.infinity) — a hard crash that persists via UserDefaults. Now returns nil.
        #expect(PS.size(account: .infinity, riskFraction: 0.01, entry: 100, stop: 90) == nil)
        #expect(PS.size(account: 10_000, riskFraction: .infinity, entry: 100, stop: 90) == nil)
        #expect(PS.size(account: 10_000, riskFraction: 0.01, entry: .infinity, stop: 90) == nil)
        #expect(PS.size(account: .nan, riskFraction: 0.01, entry: 100, stop: 90) == nil)
        // Boundary: raw == 2^63 (Double(Int.max) rounds UP to 2^63, so the old `<= Double(Int.max)`
        // guard passed and Int(2^63) still trapped). Int(exactly:) returns nil → no trap.
        #expect(PS.size(account: 9_223_372_036_854_775_808.0, riskFraction: 1, entry: 2, stop: 1) == nil)
        // A normal size is unchanged.
        #expect(PS.size(account: 10_000, riskFraction: 0.01, entry: 100, stop: 90)?.shares == 10)
    }

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

    // Audit 2026-07-12 (ideas-card F1): `dollarsAtRisk` is in the SYMBOL's own currency, so a
    // hardcoded "$" mis-stated a non-USD row ~3.75× (SAR) / ~100× (pence). Threading `symbol`
    // renders the amount in its true currency; the default (symbol: "") stays "$" byte-identical.
    @Test func summaryLineLabelsAtRiskInTheSymbolsOwnCurrency() {
        let ps = PS.size(account: 10000, riskFraction: 0.01, entry: 100, stop: 90)!   // dollarsAtRisk == 100
        // No symbol → keeps the "$" form (backward-compatible default).
        #expect(PS.summaryLine(ps, riskPct: 1).contains("$100"))
        // A .SR symbol → the at-risk amount reads in SAR, NOT "$" (the exact bug).
        let sr = PS.summaryLine(ps, riskPct: 1, symbol: "2222.SR")
        #expect(sr.contains("SAR"))
        #expect(!sr.contains("$100"))
        // A USD symbol → still "$".
        #expect(PS.summaryLine(ps, riskPct: 1, symbol: "AAPL").contains("$100"))
        // Pence (.L): still labeled — the currency, never a bare "$" (the ~100× mislabel).
        #expect(PS.summaryLine(ps, riskPct: 1, symbol: "VOD.L").contains("GBP"))
    }

    // F1/F3 (2026-07-09): whole-share flooring can round a real setup to 0 shares while the idea
    // still holds a top rank slot — the sized-order line must say so. Straddle at the 1-share
    // boundary: $100 account, 1% risk → $1 budget. stop-distance 2 → budget/risk = 0.5 → floors
    // to 0 shares (unfundable); stop-distance 1 → budget/risk = 1.0 → exactly 1 share (fundable,
    // right at the boundary) — genuinely brackets the disclosure condition, not just "both sides
    // nonzero".
    @Test func summaryLineDisclosesUnfundableAtZeroSharesButFundableJustAboveIt() {
        let unfundable = PS.size(account: 100, riskFraction: 0.01, entry: 100, stop: 98)!
        #expect(unfundable.shares == 0)
        let unfundableLine = PS.summaryLine(unfundable, riskPct: 1)
        #expect(unfundableLine.contains("0 shares"))
        #expect(unfundableLine.contains("Below the 1-share minimum at your account size"))
        #expect(unfundableLine.contains("not fundable as sized"))

        let fundable = PS.size(account: 100, riskFraction: 0.01, entry: 100, stop: 99)!
        #expect(fundable.shares == 1)
        let fundableLine = PS.summaryLine(fundable, riskPct: 1)
        #expect(fundableLine.contains("1 shares"))
        #expect(!fundableLine.contains("1-share minimum"))
        #expect(!fundableLine.contains("not fundable"))
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
