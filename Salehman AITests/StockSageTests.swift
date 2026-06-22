import Testing
import Foundation
@testable import Salehman_AI

// MARK: - StockSage signal engine
//
// The signal engine is the one pure, real, deterministic piece carried over from
// the StockSage v32 package. These tests pin every recommendation branch + the
// confidence rules so a future threshold tweak is a conscious change.

struct StockSageSignalEngineTests {

    private func signal(_ prev: Double, _ now: Double) -> StockSageSignal {
        StockSageSignalEngine.generateSignal(symbol: "T", currentPrice: now, previousPrice: prev)
    }

    @Test func strongBuyAboveSixPercentUp() {
        let s = signal(100, 107)            // +7%
        #expect(s.recommendation == .strongBuy)
        #expect(s.confidence <= 0.92)
    }

    @Test func strongSellAboveSixPercentDown() {
        let s = signal(100, 92)             // -8%
        #expect(s.recommendation == .strongSell)
    }

    @Test func buyBetweenTwoPointFiveAndSix() {
        #expect(signal(100, 104).recommendation == .buy)   // +4%
    }

    @Test func sellBetweenNegativeTwoPointFiveAndSix() {
        #expect(signal(100, 96).recommendation == .sell)   // -4%
    }

    @Test func holdInsideTheQuietBand() {
        #expect(signal(100, 101).recommendation == .hold)  // +1%
        #expect(signal(100, 99).recommendation == .hold)   // -1%
    }

    @Test func holdConfidenceIsFlat() {
        #expect(signal(100, 100).confidence == 0.65)
    }

    @Test func confidenceCappedAtNinetyTwo() {
        // A 50% move would push raw confidence well past the cap.
        #expect(signal(100, 150).confidence == 0.92)
    }

    @Test func boundaryAtExactlySixPercentIsBuyNotStrong() {
        // 6% is NOT > 6, so it stays in the buy band (the `> 6` boundary).
        #expect(signal(100, 106).recommendation == .buy)
    }

    @Test func zeroPreviousPriceDoesNotCrashAndHolds() {
        // Divide-by-zero guard: a 0 previous price reports 0% → hold, no NaN.
        let s = signal(0, 50)
        #expect(s.recommendation == .hold)
        #expect(s.confidence == 0.65)
    }

    @Test func generateFromSymbolUsesLatestQuote() {
        let sym = StockSageSymbol(symbol: "X", market: "TASI", quotes: [
            StockSageQuote(price: 10, previousPrice: 10),
            StockSageQuote(price: 11, previousPrice: 10),   // +10% → strong buy
        ])
        #expect(StockSageSignalEngine.generateSignal(for: sym)?.recommendation == .strongBuy)
    }

    @Test func generateFromSymbolWithNoQuotesIsNil() {
        let sym = StockSageSymbol(symbol: "X", market: "TASI", quotes: [])
        #expect(StockSageSignalEngine.generateSignal(for: sym) == nil)
    }
}

// MARK: - Quote model math

struct StockSageQuoteTests {
    @Test func changePercentComputesCorrectly() {
        #expect(StockSageQuote(price: 110, previousPrice: 100).changePercent == 10)
        #expect(StockSageQuote(price: 90, previousPrice: 100).changePercent == -10)
    }
    @Test func changePercentGuardsZeroPrevious() {
        #expect(StockSageQuote(price: 50, previousPrice: 0).changePercent == 0)
    }
}

// MARK: - Briefing (deterministic / offline path)
//
// Only the sync `deterministicSummary` is unit-tested — the async
// `generateBriefing` routes through `LocalLLM` (network/Apple Intelligence) and
// belongs in an integration test, not a pure unit test.

struct StockSageBriefingTests {

    @Test func emptySymbolsReportsNothingTracked() {
        #expect(StockSageBriefingService.deterministicSummary(for: []) == "No symbols are being tracked yet.")
    }

    @Test func surfacesStrengthAndWeakness() {
        let symbols = [
            StockSageSymbol(symbol: "UP", market: "TASI", quotes: [
                StockSageQuote(price: 100, previousPrice: 100),
                StockSageQuote(price: 110, previousPrice: 100),   // +10% strong buy
            ]),
            StockSageSymbol(symbol: "DN", market: "TASI", quotes: [
                StockSageQuote(price: 100, previousPrice: 100),
                StockSageQuote(price: 92, previousPrice: 100),    // -8% strong sell
            ]),
        ]
        let summary = StockSageBriefingService.deterministicSummary(for: symbols)
        #expect(summary.contains("UP"))
        #expect(summary.contains("DN"))
        #expect(summary.contains("Strength"))
        #expect(summary.contains("Weakness"))
    }

    @Test func allConsolidatingReportsNoStrongSignals() {
        let flat = [StockSageSymbol(symbol: "FLAT", market: "TASI", quotes: [
            StockSageQuote(price: 100, previousPrice: 100),
            StockSageQuote(price: 100.5, previousPrice: 100),     // +0.5% hold
        ])]
        #expect(StockSageBriefingService.deterministicSummary(for: flat).contains("consolidating"))
    }
}

// MARK: - Live quote feed (pure parsing — no network)
//
// `parseChart` is the only place raw Yahoo JSON becomes a quote, so it carries the
// whole feed's correctness. These pin the happy path, the index-only fallback, and
// every malformed shape that must degrade to nil (never crash, never a bogus 0).

struct StockSageQuoteServiceTests {

    private func parse(_ json: String) -> StockSageQuoteService.LiveQuote? {
        StockSageQuoteService.parseChart(Data(json.utf8))
    }

    @Test func parsesPriceAndPreviousClose() {
        let q = parse(#"{"chart":{"result":[{"meta":{"symbol":"AAPL","regularMarketPrice":227.1,"previousClose":226.0,"chartPreviousClose":226.0}}],"error":null}}"#)
        #expect(q?.symbol == "AAPL")
        #expect(q?.price == 227.1)
        #expect(q?.previousClose == 226.0)
    }

    @Test func fallsBackToChartPreviousCloseForIndices() {
        // Index payloads often omit `previousClose` and carry only `chartPreviousClose`.
        let q = parse(#"{"chart":{"result":[{"meta":{"symbol":"^GSPC","regularMarketPrice":5500.0,"chartPreviousClose":5450.0}}],"error":null}}"#)
        #expect(q?.symbol == "^GSPC")
        #expect(q?.previousClose == 5450.0)
    }

    @Test func missingPreviousCloseIsTreatedAsFlat() {
        // No prior close at all → previousClose == price → 0% move → hold (no crash).
        let q = parse(#"{"chart":{"result":[{"meta":{"symbol":"NEW","regularMarketPrice":42.0}}],"error":null}}"#)
        #expect(q?.previousClose == 42.0)
    }

    @Test func errorPayloadYieldsNil() {
        #expect(parse(#"{"chart":{"result":null,"error":{"code":"Not Found","description":"No data found"}}}"#) == nil)
    }

    @Test func zeroOrMissingPriceYieldsNil() {
        #expect(parse(#"{"chart":{"result":[{"meta":{"symbol":"X","regularMarketPrice":0,"previousClose":10}}]}}"#) == nil)
        #expect(parse(#"{"chart":{"result":[{"meta":{"symbol":"X","previousClose":10}}]}}"#) == nil)
    }

    @Test func garbageYieldsNilNotCrash() {
        #expect(parse("not json at all") == nil)
        #expect(parse("{}") == nil)
    }
}

// MARK: - Candle history parsing (feeds the indicators/advisor)

struct StockSageHistoryTests {

    @Test func parsesCandlesAndDropsNullGapBars() {
        // Middle bar is a non-trading gap (all-null OHLC) → dropped; arrays stay aligned.
        let json = #"{"chart":{"result":[{"timestamp":[1700000000,1700086400,1700172800],"indicators":{"quote":[{"open":[10,null,12],"high":[11,null,13],"low":[9,null,11],"close":[10.5,null,12.5],"volume":[1000,null,1200]}]}}],"error":null}}"#
        let h = StockSageQuoteService.parseHistory(Data(json.utf8), symbol: "TEST")
        #expect(h?.count == 2)
        #expect(h?.closes == [10.5, 12.5])
        #expect(h?.highs == [11, 13])
        #expect(h?.symbol == "TEST")
        #expect(h?.latestClose == 12.5)
    }

    @Test func malformedHistoryYieldsNil() {
        #expect(StockSageQuoteService.parseHistory(Data("{}".utf8), symbol: "X") == nil)
        #expect(StockSageQuoteService.parseHistory(Data("garbage".utf8), symbol: "X") == nil)
        // A single usable bar isn't enough to compute anything → nil.
        let one = #"{"chart":{"result":[{"timestamp":[1],"indicators":{"quote":[{"open":[1],"high":[1],"low":[1],"close":[1],"volume":[1]}]}}]}}"#
        #expect(StockSageQuoteService.parseHistory(Data(one.utf8), symbol: "X") == nil)
    }

    @Test func adviceFromHistoryUsesAtrStop() {
        // A clean uptrend history (with highs/lows) should advise a buy with a stop.
        let closes = (1...250).map(Double.init)
        let history = StockSagePriceHistory(
            symbol: "UP", dates: closes.map { Date(timeIntervalSince1970: $0 * 86_400) },
            opens: closes, highs: closes.map { $0 + 1 }, lows: closes.map { $0 - 1 },
            closes: closes, volumes: closes.map { _ in 1000 })
        let advice = StockSageAdvisor.advise(history: history)
        #expect(advice.action == .strongBuy)
        #expect(advice.stopPrice != nil)
        #expect(advice.suggestedWeight > 0)
    }
}

// MARK: - Worldwide universe

struct StockSageUniverseTests {

    @Test func spansManyMarketsWithUniqueTickers() {
        let u = StockSageUniverse.worldwide
        #expect(u.count > 30)                                   // genuinely global, not a token list
        #expect(Set(u.map(\.symbol)).count == u.count)          // no duplicate tickers
        #expect(StockSageUniverse.marketCount >= 10)            // 10+ distinct exchanges/regions
    }

    @Test func leadsWithSaudiAndCoversEveryContinent() {
        let u = StockSageUniverse.worldwide
        #expect(u.first?.symbol == "2222.SR")                   // Aramco — owner's home market first
        let tickers = Set(u.map(\.symbol))
        // A representative name from each major region must be present.
        for t in ["AAPL", "SHEL.L", "7203.T", "0700.HK", "RELIANCE.NS", "BHP.AX", "^GSPC"] {
            #expect(tickers.contains(t))
        }
    }

    @Test func includesForexAndCrypto() {
        let tickers = Set(StockSageUniverse.worldwide.map(\.symbol))
        for t in ["EURUSD=X", "USDSAR=X", "BTC-USD", "ETH-USD"] {
            #expect(tickers.contains(t))
        }
    }
}

// MARK: - User watchlist symbol validation (pure)

@MainActor
struct StockSageSymbolValidationTests {

    @Test func normalizesAndUppercases() {
        let r = StockSageStore.validateNewSymbol("  aapl ", alreadyTracked: [])
        #expect(r.symbol == "AAPL")
        #expect(r.error == nil)
    }

    @Test func rejectsEmptyAndMalformed() {
        #expect(StockSageStore.validateNewSymbol("", alreadyTracked: []).symbol == nil)
        #expect(StockSageStore.validateNewSymbol("a b", alreadyTracked: []).symbol == nil)        // has a space
        #expect(StockSageStore.validateNewSymbol(String(repeating: "X", count: 21), alreadyTracked: []).symbol == nil)
    }

    @Test func rejectsAlreadyTracked() {
        let r = StockSageStore.validateNewSymbol("nvda", alreadyTracked: ["NVDA"])
        #expect(r.symbol == nil)
        #expect(r.error?.contains("already") == true)
    }

    @Test func acceptsSuffixedAndPairSymbols() {
        #expect(StockSageStore.validateNewSymbol("2222.SR", alreadyTracked: []).symbol == "2222.SR")
        #expect(StockSageStore.validateNewSymbol("btc-usd", alreadyTracked: []).symbol == "BTC-USD")
        #expect(StockSageStore.validateNewSymbol("eurusd=x", alreadyTracked: []).symbol == "EURUSD=X")
    }
}

// MARK: - Store (sample seed shape)

@MainActor
struct StockSageStoreTests {

    @Test func sampleSeedIsLabeledAndNonEmpty() {
        let store = StockSageStore.shared
        #expect(store.isSampleData)
        #expect(!store.fetchAllSymbols().isEmpty)
    }

    @Test func fetchIsSortedByTicker() {
        let tickers = StockSageStore.shared.fetchAllSymbols().map(\.symbol)
        #expect(tickers == tickers.sorted())
    }

    @Test func replaceAllClearsSampleFlag() {
        let store = StockSageStore.shared
        let original = store.fetchAllSymbols()
        defer { store.replaceAll(original, isSample: true) }   // restore for other tests

        store.replaceAll([StockSageSymbol(symbol: "LIVE", market: "NYSE",
                                          quotes: [StockSageQuote(price: 1, previousPrice: 1)])],
                         isSample: false)
        #expect(!store.isSampleData)
        #expect(store.symbol(named: "live")?.symbol == "LIVE")   // case-insensitive lookup
    }
}
