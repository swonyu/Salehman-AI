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

    private func flip(_ id: Int, _ name: String, buy: Int, limit: Int, profit: Int, gph: Double) -> GEFlip {
        GEFlip(itemId: id, name: name, buyPrice: buy, sellPrice: buy + profit, buyLimit: limit,
               taxPerItem: 0, profitPerItem: profit, gpPerHour: gph)
    }

    @Test func roiRanksByCapitalEfficiency() {
        let a = flip(1, "cheap", buy: 100, limit: 100, profit: 8, gph: 0)     // 8% ROI/cycle
        let b = flip(2, "mid", buy: 1000, limit: 100, profit: 50, gph: 0)      // 5%
        let c = flip(3, "pricey", buy: 10_000, limit: 100, profit: 50, gph: 0) // 0.5%
        #expect(abs(a.roiPct - 8) < 1e-9)
        #expect(abs(b.roiPct - 5) < 1e-9)
        #expect(abs(c.roiPct - 0.5) < 1e-9)
        // Cheap, high-turnover item ranks first by capital efficiency (not gp/hour).
        #expect(StockSageGEFlip.bestFlipsByROI([c, b, a]).map(\.itemId) == [1, 2, 3])
        // Non-positive profit / zero buy are filtered out.
        let loss = flip(4, "loss", buy: 100, limit: 100, profit: -5, gph: 0)
        #expect(!StockSageGEFlip.bestFlipsByROI([a, loss]).contains { $0.itemId == 4 })
    }

    @Test func bestFlipsForBudgetGreedyByVelocity() {
        let a = flip(1, "A", buy: 100, limit: 1000, profit: 28, gph: 7000)   // full gp/hr 28·1000/4
        let b = flip(2, "B", buy: 1000, limit: 100, profit: 78, gph: 1950)   // full gp/hr 78·100/4
        // Budget 50k → funds 500 units of A only (highest gp/hr first): 28·500/4 = 3500.
        let p1 = StockSageGEFlip.bestFlipsForBudget([b, a], budget: 50_000)
        #expect(p1.flips.map(\.itemId) == [1])
        #expect(p1.flips[0].units == 500)
        #expect(p1.totalCapital == 50_000)
        #expect(abs(p1.totalGpPerHour - 3500) < 1e-9)
        // Budget 200k → full A (1000, 7000) + full B (100, 1950) = 8950 gp/hr.
        let p2 = StockSageGEFlip.bestFlipsForBudget([a, b], budget: 200_000)
        #expect(p2.flips.map(\.itemId) == [1, 2])
        #expect(abs(p2.totalGpPerHour - 8950) < 1e-9)
        #expect(StockSageGEFlip.bestFlipsForBudget([a, b], budget: 0).flips.isEmpty)   // no budget
        #expect(StockSageGEFlip.bestFlipsForBudget([b], budget: 500).flips.isEmpty)    // can't afford 1 unit
    }

    @Test func flipsRankByGpPerHourDescDroppingLosers() {
        let a = listing(1, "A", low: 1000, high: 1100, limit: 1000)   // tax 22, profit 78 ×1000/4 = 19500
        let b = listing(2, "B", low: 100, high: 130, limit: 10000)    // tax floor(2.6)=2, profit 28 ×10000/4 = 70000
        let c = listing(3, "C", low: 500, high: 490, limit: 1000)     // negative margin → dropped
        let ranked = StockSageGEFlip.flips([a, c, b])
        #expect(ranked.map(\.itemId) == [2, 1])                       // B (70000) before A (19500); C gone
        #expect(ranked.first?.profitPerItem == 28)
    }

    @Test func flipsFlagStaleLegsWhenGivenAClock() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Same margin (gross 100, tax 22, profit 78, 19500 gp/hr) — but one spread's sell leg is 2 days old.
        let fresh = RuneScapeListing(item: RuneScapeItem(id: 1, name: "Fresh", examine: "", members: false, buyLimit: 1000),
                                     price: RuneScapePrice(high: 1100, highTime: now.addingTimeInterval(-60),
                                                           low: 1000, lowTime: now.addingTimeInterval(-60)))
        let stale = RuneScapeListing(item: RuneScapeItem(id: 2, name: "Stale", examine: "", members: false, buyLimit: 1000),
                                     price: RuneScapePrice(high: 1100, highTime: now.addingTimeInterval(-60),
                                                           low: 1000, lowTime: now.addingTimeInterval(-2 * 86_400)))
        let withClock = StockSageGEFlip.flips([fresh, stale], asOf: now)
        #expect(withClock.first { $0.itemId == 1 }?.stale == false)
        #expect(withClock.first { $0.itemId == 2 }?.stale == true)   // the days-old leg is flagged, not ranked as live
        // No clock → pure ranker, never flags stale (engine stays deterministic / back-compatible).
        #expect(StockSageGEFlip.flips([stale]).first?.stale == false)
        // The budget optimizer carries the stale flag through to the funded plan.
        let plan = StockSageGEFlip.bestFlipsForBudget(withClock, budget: 10_000_000)
        #expect(plan.flips.first { $0.itemId == 2 }?.stale == true)
    }

    @Test func minMarginFloorMatchesThePlugin() {
        let a = listing(1, "A", low: 1000, high: 1100, limit: 1000)   // post-tax profit 78
        let b = listing(2, "B", low: 100, high: 130, limit: 10000)    // post-tax profit 28 (< 50 floor)
        // Engine default (0) is a pure ranker — keeps both.
        #expect(StockSageGEFlip.flips([a, b]).count == 2)
        // The plugin's min-margin floor (50, the value the user-facing strip passes) drops the 28-gp flip.
        let floored = StockSageGEFlip.flips([a, b], minMargin: StockSageGEFlip.defaultMinMargin)
        #expect(floored.map(\.profitPerItem) == [78])
        #expect(StockSageGEFlip.defaultMinMargin == 50)
    }
}
