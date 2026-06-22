import Testing
import Foundation
@testable import Salehman_AI

// MARK: - GE flip velocity (pure)

struct StockSageGEFlipTests {

    private func listing(_ id: Int, _ name: String, low: Int, high: Int, limit: Int) -> RuneScapeListing {
        RuneScapeListing(item: RuneScapeItem(id: id, name: name, examine: "", members: false, buyLimit: limit),
                         price: RuneScapePrice(high: high, highTime: nil, low: low, lowTime: nil))
    }

    @Test func gpPerHourUsesMarginTaxAndBuyLimit() {
        // buy 1000, sell 1100 → tax floor(1100·0.02)=22, profit 78; ×1000 limit ÷ 4h = 19500 gp/h.
        let gph = StockSageGEFlip.gpPerHour(buy: 1000, sell: 1100, buyLimit: 1000)!
        #expect(abs(gph - 19500) < 1e-9)
        #expect(StockSageGEFlip.gpPerHour(buy: 1100, sell: 1000, buyLimit: 1000) == nil)  // no margin after tax
        #expect(StockSageGEFlip.gpPerHour(buy: 0, sell: 1100, buyLimit: 1000) == nil)     // bad price
        #expect(StockSageGEFlip.gpPerHour(buy: 1000, sell: 1100, buyLimit: 0) == nil)     // no limit
    }

    @Test func sellTaxFlooredCappedAndExempt() {
        #expect(StockSageGEFlip.sellTax(1100) == 22)                  // floor(1100·0.02)=22
        #expect(StockSageGEFlip.sellTax(49) == 0)                     // below 50 → exempt
        #expect(StockSageGEFlip.sellTax(5000) == 100)                 // floor(5000·0.02)=100
        #expect(StockSageGEFlip.sellTax(1_000_000_000) == 5_000_000)  // capped at 5M (cap unchanged)
    }

    @Test func gpPerHourHandlesHugeBuyLimitWithoutOverflow() {
        // postTax 78 (2% tax) × 2e9 ÷ 4h — Double math, so no Int overflow and a finite result.
        let gph = StockSageGEFlip.gpPerHour(buy: 1000, sell: 1100, buyLimit: 2_000_000_000)!
        #expect(gph.isFinite)
        #expect(abs(gph - 78.0 * 2_000_000_000 / 4) < 1.0)
    }

    @Test func flipsRankByGpPerHourDescDroppingLosers() {
        let a = listing(1, "A", low: 1000, high: 1100, limit: 1000)   // tax 22, profit 78 ×1000/4 = 19500
        let b = listing(2, "B", low: 100, high: 130, limit: 10000)    // tax floor(2.6)=2, profit 28 ×10000/4 = 70000
        let c = listing(3, "C", low: 500, high: 490, limit: 1000)     // negative margin → dropped
        let ranked = StockSageGEFlip.flips([a, c, b])
        #expect(ranked.map(\.itemId) == [2, 1])                       // B (70000) before A (19500); C gone
        #expect(ranked.first?.profitPerItem == 28)
    }
}
