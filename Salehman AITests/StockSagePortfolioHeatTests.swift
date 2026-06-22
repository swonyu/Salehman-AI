import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Portfolio heat (pure)

struct StockSagePortfolioHeatTests {
    typealias H = StockSagePortfolioHeat

    @Test func sumsOpenRiskAndLevels() {
        // 10·|100−95| + 5·|200−180| = 50 + 100 = 150 on a 10k account → 1.5% → cool.
        let h = H.compute(openTrades: [(10, 100, 95), (5, 200, 180)], accountSize: 10_000)!
        #expect(abs(h.dollarsAtRisk - 150) < 1e-9)
        #expect(abs(h.heatPct - 0.015) < 1e-9)
        #expect(h.level == .cool && h.openCount == 2)
        #expect(h.verdict.contains("room to add"))
    }

    @Test func warmAndHotBands() {
        // 7% → warm.
        #expect(H.compute(openTrades: [(70, 100, 90)], accountSize: 10_000)!.level == .warm)   // 70·10=700 → 7%
        // 12% → hot.
        let hot = H.compute(openTrades: [(120, 100, 90)], accountSize: 10_000)!                 // 120·10=1200 → 12%
        #expect(hot.level == .hot)
        #expect(hot.verdict.lowercased().contains("heavy"))
        #expect(hot.caveat.lowercased().contains("gap"))
    }

    @Test func guardsAndEmpties() {
        #expect(H.compute(openTrades: [], accountSize: 10_000)?.dollarsAtRisk == 0)   // no trades → 0% heat (valid)
        #expect(H.compute(openTrades: [], accountSize: 10_000)?.level == .cool)
        #expect(H.compute(openTrades: [(10, 100, 95)], accountSize: 0) == nil)        // no account → nil
    }
}
