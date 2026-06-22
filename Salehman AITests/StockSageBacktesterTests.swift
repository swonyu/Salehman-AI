import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Backtester aggregation (pure) — the metrics the owner actually sees.
// summarize() is exercised directly with synthetic trades; all literals hand-verified.

struct StockSageBacktesterTests {

    /// Only `.r` and `(exitIndex − entryIndex)` matter to summarize; entry/exit are fillers.
    private func trade(_ r: Double, hold: Int = 1) -> BacktestTrade {
        BacktestTrade(entryIndex: 0, exitIndex: hold, entry: 100, exit: 100 + r,
                      r: r, outcome: r > 0 ? .target : .stop)
    }

    @Test func summarizeAggregatesRMultiples() {
        // R = [+2, −1, +2, −1]: total 2, avg 0.5, 2 wins / 4 = 50%.
        // cum 2,1,3,2 → peak 2,2,3,3 → DD 0,1,0,1 → maxDD 1.
        // sd (Bessel): devs ±1.5 → Σsq 9 / 3 = 3 → √3 ; sharpe 0.5/√3.
        let r = StockSageBacktester.summarize([trade(2), trade(-1), trade(2), trade(-1)])
        #expect(r.trades == 4)
        #expect(r.wins == 2)
        #expect(abs(r.winRate - 0.5) < 1e-9)
        #expect(abs(r.totalR - 2) < 1e-9)
        #expect(abs(r.avgR - 0.5) < 1e-9)
        #expect(abs(r.avgWinR - 2) < 1e-9)
        #expect(abs(r.avgLossR - 1) < 1e-9)              // POSITIVE magnitude of the avg loss
        #expect(abs(r.maxDrawdownR - 1) < 1e-9)
        #expect(abs(r.sharpe - 0.5 / 3.0.squareRoot()) < 1e-9)
        #expect(abs(r.avgHoldBars - 1) < 1e-9)
    }

    @Test func summarizeEmptyAndSingleTradeAreSafe() {
        #expect(StockSageBacktester.summarize([]) == BacktestResult.empty)
        let one = StockSageBacktester.summarize([trade(2)])
        #expect(one.trades == 1)
        #expect(one.sharpe == 0)                         // <2 trades → no dispersion, not a crash
        #expect(abs(one.avgWinR - 2) < 1e-9)
        #expect(one.avgLossR == 0)                       // no losing trades
        #expect(abs(one.maxDrawdownR) < 1e-9)            // a single win never draws down
    }

    @Test func significanceThresholdIsTwenty() {
        #expect(!BacktestResult.empty.isSignificant)
        #expect(!StockSageBacktester.summarize(Array(repeating: trade(1), count: 19)).isSignificant)
        #expect(StockSageBacktester.summarize(Array(repeating: trade(1), count: 20)).isSignificant)
    }

    private func history(_ closes: [Double]) -> StockSagePriceHistory {
        StockSagePriceHistory(
            symbol: "X",
            dates: closes.enumerated().map { Date(timeIntervalSince1970: Double($0.offset) * 86_400) },
            opens: closes, highs: closes, lows: closes, closes: closes, volumes: closes.map { _ in 0 })
    }

    @Test func runGuardsInsufficientData() {
        // n must exceed warmup(200)+5; 10 bars → .empty (no decisions, no crash).
        #expect(StockSageBacktester.run(history(Array(repeating: 100.0, count: 10))) == BacktestResult.empty)
    }

    @Test func runOnADowntrendNeverGoesLong() {
        // The advisor's LONG rules require an uptrend; a strict downtrend (always below
        // its 200DMA) must never trigger an entry → zero trades.
        let down = history((0..<260).map { Double(260 - $0) })
        #expect(StockSageBacktester.run(down).trades == 0)
    }

    @Test func costsNeverFlatterAndNilIsByteForByte() {
        // A steady uptrend that actually trades (targets 16% above each entry get hit).
        let up = history((0..<260).map { 100.0 + Double($0) })
        let free = StockSageBacktester.run(up)
        // nil costs == the default (no silent drift for existing callers).
        #expect(StockSageBacktester.run(up, costs: nil) == free)
        // A wide round-trip cost subtracts from EVERY trade's R: same trades, lower totalR.
        let wide = StockSageNetEdge.CostAssumption(spreadBps: 50, slippageBps: 50, assetClass: "crypto")
        let costed = StockSageBacktester.run(up, costs: wide)
        #expect(costed.trades == free.trades)        // costs don't change which trades happen
        #expect(costed.totalR <= free.totalR)        // costs never help
        if free.trades > 0 { #expect(costed.totalR < free.totalR) }   // strictly lower once trading
    }
}
