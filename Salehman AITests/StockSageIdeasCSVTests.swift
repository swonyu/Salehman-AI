import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Ideas board CSV export (pure)

struct StockSageIdeasCSVTests {
    private func idea(_ symbol: String, _ price: Double, _ action: TradeAdvice.Action,
                      conviction: Double = 0.5, stop: Double? = nil, target: Double? = nil,
                      weight: Double = 0.05, regime: TradeAdvice.Regime = .bullTrend,
                      rationale: [String] = []) -> StockSageIdea {
        StockSageIdea(
            symbol: symbol, market: "M", price: price,
            advice: TradeAdvice(action: action, conviction: conviction, regime: regime,
                                rationale: rationale, stopPrice: stop, targetPrice: target,
                                suggestedWeight: weight, caveat: "x"),
            spark: [])
    }

    @Test func headerAndRowCount() {
        let csv = StockSageIdeasCSV.csv([idea("AAPL", 100, .buy), idea("NVDA", 200, .strongBuy)])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.first == StockSageIdeasCSV.header)
        #expect(lines.count == 3)   // header + 2 rows
    }

    @Test func emptyIdeasYieldsHeaderOnly() {
        #expect(StockSageIdeasCSV.csv([]) == StockSageIdeasCSV.header)
    }

    @Test func rankReflectsListOrderAndFieldsAreCorrect() {
        let csv = StockSageIdeasCSV.csv([
            idea("NVDA", 200, .strongBuy, conviction: 0.9, stop: 180, target: 260, weight: 0.12),
            idea("AAPL", 100, .buy),
        ])
        let rows = csv.split(separator: "\n").map(String.init)
        #expect(rows[1].hasPrefix("1,NVDA,M,200.0,Strong Buy,0.90,180.0,260.0,12.0,Bullish trend,"))
        #expect(rows[2].hasPrefix("2,AAPL,M,100.0,Buy,"))
    }

    @Test func missingStopTargetRenderEmpty() {
        let csv = StockSageIdeasCSV.csv([idea("AAPL", 100, .hold, stop: nil, target: nil)])
        // ...,conviction,stop,target,... → two empty fields back to back
        #expect(csv.contains(",0.50,,,"))
    }

    @Test func rationaleWithCommaIsQuoted() {
        let csv = StockSageIdeasCSV.csv([idea("AAPL", 100, .buy, rationale: ["RSI low", "MACD up"])])
        // joined with "; " → "RSI low; MACD up" (no comma) stays unquoted;
        // a comma inside a bullet must be quoted.
        let csv2 = StockSageIdeasCSV.csv([idea("AAPL", 100, .buy, rationale: ["up, then flat"])])
        #expect(!csv.contains("\""))
        #expect(csv2.contains("\"up, then flat\""))
    }
}
