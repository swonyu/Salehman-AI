import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Leverage risk (pure) — none of what leverage changes is upside.

struct StockSageLeverageTests {
    typealias L = StockSageLeverage

    @Test func leverageQuantifiesLiquidationAndAmplification() {
        // 3×: a 33.3% adverse move wipes you; long liquidation at entry·(1−1/3) = 66.67.
        let l3 = L.assess(leverage: 3, entry: 100)!
        #expect(abs(l3.liquidationMovePct - 100.0 / 3) < 1e-9)
        #expect(abs(l3.liquidationPrice - 100 * (1 - 1.0 / 3)) < 1e-9)
        #expect(abs(l3.drawdownMultiplier - 3) < 1e-9 && l3.canLoseMoreThanAccount)
        #expect(l3.caveat.lowercased().contains("more than") && l3.verdict.lowercased().contains("wipes"))
        // From a real book: a $30k position on a $10k account = 3×.
        let book = L.assess(account: 10_000, notional: 30_000, entry: 100)!
        #expect(abs(book.leverage - 3) < 1e-9 && book.canLoseMoreThanAccount)
        // Cash (1×): no margin liquidation, not loss-more-than-account.
        let cash = L.assess(leverage: 1, entry: 100)!
        #expect(!cash.canLoseMoreThanAccount && cash.liquidationPrice == 0)
        // An option flagged loss-more-than-account even at ≤1× notional.
        #expect(L.assess(leverage: 1, entry: 100, instrumentCanLoseMoreThanAccount: true)!.canLoseMoreThanAccount)
        // Guards → nil.
        #expect(L.assess(leverage: 0, entry: 100) == nil)
        #expect(L.assess(account: 0, notional: 30_000, entry: 100) == nil)
    }
}
