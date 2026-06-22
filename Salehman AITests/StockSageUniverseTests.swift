import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Universe + catalog search (pure)

struct StockSageUniverseTests {
    typealias U = StockSageUniverse

    @Test func catalogIsASupersetOfTheAnalyzedCore() {
        let coreSyms = Set(U.worldwide.map { $0.symbol.uppercased() })
        let catSyms = Set(U.catalog.map { $0.symbol.uppercased() })
        #expect(U.catalog.count > U.worldwide.count)       // discovery long-tail adds names
        #expect(coreSyms.isSubset(of: catSyms))            // every core symbol is in the catalog
        #expect(catSyms.count == U.catalog.count)          // catalog is deduped (no repeats)
    }

    @Test func searchRanksExactThenPrefixThenSubstring() {
        #expect(U.search("AAPL").first?.symbol == "AAPL")              // exact match first
        #expect(U.search("aap").contains { $0.symbol == "AAPL" })      // case-insensitive prefix
        #expect(U.search("BTC").contains { $0.symbol == "BTC-USD" })   // crypto discoverable
        #expect(U.search("A", limit: 5).count <= 5)                    // bounded by limit
        #expect(U.search("").isEmpty)                                  // empty query → nothing
        #expect(U.search("ZZZZNOPE").isEmpty)                          // no match → nothing
    }
}
