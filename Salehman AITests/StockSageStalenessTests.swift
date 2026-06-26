import Testing
import Foundation
@testable import Salehman_AI

// Per-row quote staleness: crypto (24/7) flags fast, equities/FX tolerate an overnight gap but
// flag a multi-day weekend/holiday close. Fixed `now` so the dates are deterministic.
@MainActor
struct StockSageStalenessTests {
    private func sym(_ ticker: String, at time: Date) -> StockSageSymbol {
        StockSageSymbol(symbol: ticker, market: "M",
                        quotes: [StockSageQuote(price: 100, previousPrice: 100, time: time)])
    }

    @Test func equityToleratesOvernightCryptoFlagsFast() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Equity: a 1-day-old quote is fine (overnight), a 60h one (a long weekend) is stale.
        #expect(sym("AAPL", at: now.addingTimeInterval(-24 * 3600)).isStale(asOf: now) == false)
        #expect(sym("AAPL", at: now.addingTimeInterval(-60 * 3600)).isStale(asOf: now) == true)
        // Crypto trades 24/7 → tighter: fresh at 3h, stale by 12h.
        #expect(sym("BTC-USD", at: now.addingTimeInterval(-3 * 3600)).isStale(asOf: now) == false)
        #expect(sym("BTC-USD", at: now.addingTimeInterval(-12 * 3600)).isStale(asOf: now) == true)
        // No quote → can't judge → not stale (no false alarm).
        #expect(StockSageSymbol(symbol: "AAPL", market: "M").isStale(asOf: now) == false)
    }
}
