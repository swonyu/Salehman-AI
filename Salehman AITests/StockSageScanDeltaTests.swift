import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Scan deltas ("New" / "was <Action>") — pure static deltas(), hand-derived
//
// Fixtures hand-derived from PLAN_2026-07-07_scan_deltas.md's prose spec (Delta computation
// section), never from calling the implementation (F40 discipline). See scratchpad
// derive_deltas.md for the derivation notes.

struct StockSageScanDeltaTests {

    private func idea(_ symbol: String, _ action: TradeAdvice.Action) -> StockSageIdea {
        StockSageIdea(
            symbol: symbol, market: symbol, price: 100,
            advice: TradeAdvice(action: action, conviction: 0.5, regime: .range, rationale: [],
                                stopPrice: nil, targetPrice: nil, suggestedWeight: 0.05, caveat: "x"),
            spark: [])
    }

    @Test func newSymbolAbsentFromPreviousIsNew() {
        let current = [idea("AAA", .buy), idea("BBB", .hold)]
        let previous = ["BBB": "Hold"]
        let result = StockSageScanDelta.deltas(current: current, previous: previous)
        #expect(result.count == 1)
        #expect(result["AAA"] == .new)
        #expect(result["BBB"] == nil)   // unchanged -> absent
    }

    @Test func changedActionIsActionChangedWithRightPrevious() {
        let current = [idea("AAPL", .buy)]
        let previous = ["AAPL": "Hold"]
        let result = StockSageScanDelta.deltas(current: current, previous: previous)
        #expect(result["AAPL"] == .actionChanged(previous: "Hold"))
    }

    @Test func unchangedActionIsAbsentFromResult() {
        let current = [idea("NVDA", .strongBuy)]
        let previous = ["NVDA": "Strong Buy"]   // TradeAdvice.Action.strongBuy.rawValue
        let result = StockSageScanDelta.deltas(current: current, previous: previous)
        #expect(result.isEmpty)
    }

    @Test func symbolMatchIsCaseInsensitive() {
        // Same action under a different symbol casing -> unchanged, not new.
        let unchanged = StockSageScanDelta.deltas(current: [idea("btc-usd", .strongBuy)],
                                                   previous: ["BTC-USD": "Strong Buy"])
        #expect(unchanged.isEmpty)

        // Different action under a different symbol casing -> matched, actionChanged (not new).
        let changed = StockSageScanDelta.deltas(current: [idea("btc-usd", .buy)],
                                                 previous: ["BTC-USD": "Strong Buy"])
        #expect(changed["btc-usd"] == .actionChanged(previous: "Strong Buy"))
    }

    @Test func emptyPreviousIsEmptyResultFirstRunRule() {
        let current = [idea("AAA", .buy), idea("BBB", .hold)]
        let result = StockSageScanDelta.deltas(current: current, previous: [:])
        #expect(result.isEmpty)   // absence of baseline renders nothing, never "everything is new"
    }
}
