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

    @Test func momentCorrectedTStatIsHonestVsRaw() {
        func agg(_ rs: [Double]) -> StrategyBacktest {
            let t = rs.map { BacktestTrade(entryIndex: 0, exitIndex: 1, entry: 100, exit: 100, r: $0,
                                           outcome: .target, conviction: 0.5) }
            return StockSageStrategyBacktest.aggregate([], trades: t)
        }
        // Positive-edge sample: the skew/fat-tail-adjusted t is positive but BELOW the raw t
        // (the Sharpe-estimator SE widens with SR, and uses n−1 not n).
        let edge = Array(repeating: 1.0, count: 60) + Array(repeating: -1.0, count: 40)
        let a = agg(edge)
        #expect(a.tStat > 0)
        #expect(a.momentCorrectedTStat > 0)
        #expect(a.momentCorrectedTStat < a.tStat)
        // Inject a rare fat negative tail → heavier left tail lowers the adjusted t below the raw further.
        let b = agg(edge + [-8.0, -8.0])
        #expect(b.momentCorrectedTStat < b.tStat)
        // Too few trades → undefined moments → 0 (no false precision).
        #expect(agg([0.5, -0.5, 0.5]).momentCorrectedTStat == 0)
    }

    @Test func honestSignificanceGatesOnSampleAndFatTails() {
        func bt(trades: Int, t: Double, adj: Double) -> StrategyBacktest {
            StrategyBacktest(symbolsTested: 1, symbolsWithTrades: 1, symbolsProfitable: 1,
                             totalTrades: trades, wins: trades / 2, blendedWinRate: 0.5, avgR: 0.1,
                             totalR: 1, worstDrawdownR: 1, tStat: t, momentCorrectedTStat: adj, caveat: "x")
        }
        // <100 trades but raw t>3 → NOT an honest pass; verdict says not meaningful (no green check, #8).
        let thin = bt(trades: 40, t: 4.0, adj: 4.0)
        #expect(!thin.passesHonestSignificance)
        #expect(thin.significanceVerdict.contains("isn't statistically meaningful"))
        // Enough trades, raw t>3, but the fat-tail-corrected t FAILS → not a pass; verdict flags it (#10).
        let fat = bt(trades: 200, t: 4.0, adj: 2.5)
        #expect(!fat.passesHonestSignificance)
        #expect(fat.significanceVerdict.contains("does NOT"))
        // Enough trades, both raw and adjusted clear → honest pass.
        let solid = bt(trades: 200, t: 4.0, adj: 3.5)
        #expect(solid.passesHonestSignificance)
        #expect(solid.significanceVerdict.contains("clears the t>3"))
        // Adjusted unknown (0) doesn't block a pass (can't penalize what we couldn't compute).
        #expect(bt(trades: 200, t: 4.0, adj: 0).passesHonestSignificance)
    }

    @Test func pooledTStatFromTrades() {
        // No trades supplied → tStat 0 (default, behaviour unchanged).
        #expect(StockSageStrategyBacktest.aggregate([result(trades: 10, wins: 6, totalR: 5, maxDD: 3)]).tStat == 0)
        // Pooled trades with a positive mean and real dispersion → positive, finite t.
        let trades = (0..<120).map { i in
            BacktestTrade(entryIndex: 0, exitIndex: 1, entry: 100, exit: 100,
                          r: i.isMultiple(of: 3) ? -1.0 : 2.0, outcome: .target)   // ~2/3 win, mean>0
        }
        let agg = result(trades: 120, wins: 80, totalR: 80, maxDD: 5)
        let s = StockSageStrategyBacktest.aggregate([agg], trades: trades)
        #expect(s.tStat > 0)
        #expect(s.isSignificant)                       // 120 ≥ 100
        #expect(s.significanceVerdict.contains("t ="))
        // Zero dispersion (all identical R) → tStat 0, not a divide-by-zero.
        let flat = (0..<120).map { _ in BacktestTrade(entryIndex: 0, exitIndex: 1, entry: 100, exit: 100, r: 1.0, outcome: .target) }
        #expect(StockSageStrategyBacktest.aggregate([agg], trades: flat).tStat == 0)
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
