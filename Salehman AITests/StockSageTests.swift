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
