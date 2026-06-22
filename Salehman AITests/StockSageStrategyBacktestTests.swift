import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Aggregate (strategy-wide) backtest (pure)

struct StockSageStrategyBacktestTests {

    private func result(trades: Int, wins: Int, totalR: Double, maxDD: Double) -> BacktestResult {
        BacktestResult(trades: trades, wins: wins,
                       winRate: trades > 0 ? Double(wins) / Double(trades) : 0,
                       avgR: trades > 0 ? totalR / Double(trades) : 0,
                       totalR: totalR, maxDrawdownR: maxDD, sharpe: 0, avgHoldBars: 5)
    }

    @Test func aggregatesSumsAndRates() {
        let a = result(trades: 10, wins: 6, totalR: 5, maxDD: 3)     // profitable
        let b = result(trades: 5, wins: 2, totalR: -1, maxDD: 4)     // losing
        let c = result(trades: 0, wins: 0, totalR: 0, maxDD: 0)      // never traded
        let s = StockSageStrategyBacktest.aggregate([a, b, c])
        #expect(s.symbolsTested == 3)
        #expect(s.symbolsWithTrades == 2)
        #expect(s.symbolsProfitable == 1)                            // only `a`
        #expect(s.totalTrades == 15)
        #expect(s.wins == 8)
        #expect(abs(s.blendedWinRate - 8.0 / 15.0) < 1e-9)
        #expect(abs(s.totalR - 4) < 1e-9)
        #expect(abs(s.avgR - 4.0 / 15.0) < 1e-9)
        #expect(s.worstDrawdownR == 4)                               // max(3,4)
        #expect(s.isSignificant == false)                           // 15 < 100
    }

    @Test func emptyAggregatesToZero() {
        let s = StockSageStrategyBacktest.aggregate([])
        #expect(s.symbolsTested == 0)
        #expect(s.totalTrades == 0)
        #expect(s.blendedWinRate == 0)
        #expect(s.avgR == 0)
        #expect(s.isSignificant == false)
    }

    @Test func significanceNeedsHundredTrades() {
        let big = result(trades: 120, wins: 60, totalR: 10, maxDD: 8)
        #expect(StockSageStrategyBacktest.aggregate([big]).isSignificant)
    }

    @Test func sampleIsNonTrivialAndUnique() {
        let s = StockSageStrategyBacktest.sampleSymbols
        #expect(s.count >= 15)
        #expect(Set(s).count == s.count)
    }
}
