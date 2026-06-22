import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Multi-currency exposure (pure)

struct StockSageCurrencyTests {
    typealias CC = StockSageCurrency

    private func exp(_ b: CurrencyBreakdown, _ ccy: String) -> CurrencyExposure? {
        b.exposures.first { $0.currency == ccy }
    }

    @Test func convertsAndWeightsWithoutFXFlagWhenSpread() {
        let b = CC.breakdown(holdings: [(1000, "USD"), (100, "EUR"), (50, "GBP")],
                             ratesToBase: ["EUR": 1.1, "GBP": 1.25], base: "USD")!
        #expect(abs(b.totalBase - 1172.5) < 1e-9)               // 1000 + 110 + 62.5
        #expect(abs(exp(b, "EUR")!.baseValue - 110) < 1e-9)
        #expect(abs(exp(b, "GBP")!.baseValue - 62.5) < 1e-9)
        #expect(abs(exp(b, "USD")!.weight - 1000.0 / 1172.5) < 1e-9)
        #expect(b.exposures.map(\.currency) == ["USD", "EUR", "GBP"])  // largest first
        #expect(b.concentration == nil && !b.hasFXRisk)         // no non-base > 25%
        #expect(b.unpriced.isEmpty)
    }

    @Test func flagsConcentrationInOneNonBaseCurrency() {
        let b = CC.breakdown(holdings: [(1000, "USD"), (1000, "EUR")],
                             ratesToBase: ["EUR": 1.0], base: "USD")!
        #expect(b.hasFXRisk)
        #expect(b.concentration?.currency == "EUR")
        #expect(abs(b.concentration!.weight - 0.5) < 1e-9)
    }

    @Test func excludesAndNamesUnpricedCurrencies() {
        let b = CC.breakdown(holdings: [(1000, "USD"), (100, "JPY")],
                             ratesToBase: [:], base: "USD")!
        #expect(abs(b.totalBase - 1000) < 1e-9)                 // JPY dropped, not zero-valued
        #expect(b.unpriced == ["JPY"])
        #expect(b.exposures.map(\.currency) == ["USD"])
    }

    @Test func currencyForSymbolFromSuffix() {
        #expect(CC.currencyForSymbol("AAPL") == "USD")       // US-listed
        #expect(CC.currencyForSymbol("BTC-USD") == "USD")    // crypto priced in USD
        #expect(CC.currencyForSymbol("2222.SR") == "SAR")
        #expect(CC.currencyForSymbol("BP.L") == "GBP")
        #expect(CC.currencyForSymbol("7203.T") == "JPY")
        #expect(CC.currencyForSymbol("FOO.ZZ") == "ZZ")      // unknown → suffix (surfaces as unpriced)
    }

    @Test func fxPairMapsToItsNonBaseLeg() {
        #expect(CC.currencyForSymbol("EURUSD=X") == "EUR")   // long EUR vs USD → EUR exposure
        #expect(CC.currencyForSymbol("USDJPY=X") == "JPY")   // base USD → the JPY leg
        #expect(CC.currencyForSymbol("USDSAR=X") == "SAR")
        #expect(CC.currencyForSymbol("EURGBP=X") == "EUR")   // cross (no USD) → its base
        #expect(CC.currencyForSymbol("BTC-USD") == "USD")    // crypto unaffected
    }

    @Test func guardsNothingConvertible() {
        #expect(CC.breakdown(holdings: [], ratesToBase: ["EUR": 1.1], base: "USD") == nil)
        #expect(CC.breakdown(holdings: [(100, "JPY")], ratesToBase: [:], base: "USD") == nil)
    }
}
