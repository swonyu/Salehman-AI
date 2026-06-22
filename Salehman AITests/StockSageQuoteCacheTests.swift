import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Disk quote cache (pure round-trip + rebuild)

@MainActor
struct StockSageQuoteCacheTests {

    @Test func roundTripsAndRebuildsSymbolsLosslessly() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = StockSageQuoteCache(entries: [
            .init(symbol: "AAPL", price: 110, previousClose: 100, time: t),
            .init(symbol: "BTC-USD", price: 50, previousClose: 50, time: t),
        ], savedAt: t)

        // Codable round-trip is exact (default Date strategy).
        let data = try! JSONEncoder().encode(cache)
        let back = try! JSONDecoder().decode(StockSageQuoteCache.self, from: data)
        #expect(back == cache)

        // Rebuild rows — latest price, change%, and label preserved.
        let syms = cache.symbols(marketFor: { _ in "M" })
        let aapl = syms.first { $0.symbol == "AAPL" }!
        #expect(aapl.latest?.price == 110)
        #expect(abs((aapl.latest?.changePercent ?? 0) - 10) < 1e-9)   // (110−100)/100 = 10%
        #expect(aapl.market == "M")

        // from(symbols:) is the inverse of symbols(marketFor:).
        let rebuilt = StockSageQuoteCache.from(symbols: syms, savedAt: t)
        #expect(rebuilt.entries.count == 2)
        #expect(rebuilt.entries.first { $0.symbol == "AAPL" }?.price == 110)
        #expect(rebuilt.entries.first { $0.symbol == "AAPL" }?.previousClose == 100)
    }
}
