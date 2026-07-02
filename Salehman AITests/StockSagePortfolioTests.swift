import Testing
import Foundation
@testable import Salehman_AI

/// Pins the Markets Portfolio holdings store: the cost math, the input guards
/// (a fat-fingered form submit must not store garbage), and JSON persistence.
/// Each test uses its OWN UserDefaults suite (cleared first) so the parallel
/// runner never races on a shared key.
@MainActor
struct StockSagePortfolioTests {

    private func freshStore(_ tag: String) -> StockSagePortfolio {
        let name = "test.portfolio.\(tag)"
        UserDefaults().removePersistentDomain(forName: name)
        let ud = UserDefaults(suiteName: name)!
        ud.removePersistentDomain(forName: name)
        return StockSagePortfolio(userDefaults: ud)
    }

    @Test func totalCostMultipliesSharesByBasis() {
        #expect(PortfolioPosition(symbol: "X", shares: 10, costBasis: 5).totalCost == 50)
    }

    @Test func addUppercasesAndTrimsSymbol() {
        let p = freshStore("trim")
        p.add(symbol: "  aapl ", shares: 10, costBasis: 100)
        #expect(p.positions.map(\.symbol) == ["AAPL"])
    }

    @Test func addRejectsBlankSymbolAndNonPositiveShares() {
        let p = freshStore("reject")
        p.add(symbol: "", shares: 10, costBasis: 100)
        p.add(symbol: "   ", shares: 10, costBasis: 100)
        p.add(symbol: "X", shares: 0, costBasis: 100)
        p.add(symbol: "Y", shares: -3, costBasis: 100)
        #expect(p.positions.isEmpty)
    }

    @Test func addRejectsNonFiniteSharesAndCostBasis() {
        let p = freshStore("nonfinite")
        p.add(symbol: "X", shares: .infinity, costBasis: 100)
        p.add(symbol: "Y", shares: -.infinity, costBasis: 100)
        p.add(symbol: "Z", shares: .nan, costBasis: 100)
        p.add(symbol: "W", shares: 10, costBasis: .infinity)
        p.add(symbol: "V", shares: 10, costBasis: .nan)
        #expect(p.positions.isEmpty)
    }

    @Test func addAllowsZeroCostBasis() {
        let p = freshStore("zerocost")            // a gifted/vested lot can be free
        p.add(symbol: "GIFT", shares: 5, costBasis: 0)
        #expect(p.positions.count == 1)
        #expect(p.positions[0].totalCost == 0)
    }

    @Test func removeDeletesByIdAndClearEmpties() {
        let p = freshStore("remove")
        p.add(symbol: "A", shares: 1, costBasis: 1)
        p.add(symbol: "B", shares: 2, costBasis: 2)
        p.remove(p.positions[0].id)
        #expect(p.positions.map(\.symbol) == ["B"])
        p.clear()
        #expect(p.positions.isEmpty)
    }

    @Test func holdingsPersistAcrossInstances() {
        let name = "test.portfolio.persist"
        UserDefaults().removePersistentDomain(forName: name)
        let ud = UserDefaults(suiteName: name)!
        ud.removePersistentDomain(forName: name)
        StockSagePortfolio(userDefaults: ud).add(symbol: "AAPL", shares: 10, costBasis: 150)
        let reloaded = StockSagePortfolio(userDefaults: ud)
        #expect(reloaded.positions.map(\.symbol) == ["AAPL"])
        #expect(reloaded.positions.first?.shares == 10)
        #expect(reloaded.positions.first?.totalCost == 1500)
    }
}
