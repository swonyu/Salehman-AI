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

    @Test func trailLevelsRatchetUpAndMatchSuggestAtTheEnd() {
        let closes = (1...60).map(Double.init)            // clean monotonic uptrend
        let highs  = closes.map { $0 + 0.5 }
        let lows   = closes.map { $0 - 0.5 }
        let levels = StockSageBacktester.trailLevels(highs: highs, lows: lows, closes: closes,
                                                     entryIndex: 20, atrMult: 3, period: 14)!
        #expect(levels.count == 39)                       // entryIndex+1 … last = 21…59
        // Up-only ratchet: a long's stop never falls.
        #expect(zip(levels, levels.dropFirst()).allSatisfy { $0 <= $1 })
        // Final element consistent with the static Chandelier engine on the same series.
        let s = StockSageTrailingStop.suggest(highs: highs, lows: lows, closes: closes, multiple: 3, period: 14)!
        #expect(abs(levels.last! - s.level) < 1e-9)
        // entry == last bar → no post-entry bars; out-of-range index → nil.
        #expect(StockSageBacktester.trailLevels(highs: highs, lows: lows, closes: closes, entryIndex: 59)!.isEmpty)
        #expect(StockSageBacktester.trailLevels(highs: highs, lows: lows, closes: closes, entryIndex: 60) == nil)
    }

    @Test func exitModeAllAtTargetIsGoldenMaster() {
        // The seam must not change anything: default run == explicit .allAtTarget, on real-ish series.
        let up = history((0..<260).map { 100.0 + Double($0) })
        #expect(StockSageBacktester.run(up, exitMode: .allAtTarget) == StockSageBacktester.run(up))
        let down = history((0..<260).map { Double(260 - $0) })
        #expect(StockSageBacktester.run(down, exitMode: .allAtTarget) == StockSageBacktester.run(down))
        let costed = StockSageNetEdge.CostAssumption(spreadBps: 30, slippageBps: 20, assetClass: "equity")
        #expect(StockSageBacktester.run(up, costs: costed, exitMode: .allAtTarget) == StockSageBacktester.run(up, costs: costed))
    }

    @Test func simulateExitResolvesEachMode() {
        let opens  = [10.0, 10, 10, 10, 10, 10]
        let highs  = [10.0, 10, 10, 10, 10, 10]   // never reaches target 20
        let lows   = [10.0, 10, 10, 10, 10, 10]   // never reaches stop 5
        let closes = [10.0, 10, 11, 12, 13, 14]
        // allAtTarget: neither level hit → open at the last bar's close.
        let a = StockSageBacktester.simulateExit(entryIdx: 1, stop: 5, target: 20,
                    opens: opens, highs: highs, lows: lows, closes: closes, n: 6, mode: .allAtTarget)
        #expect(a.outcome == .openAtEnd && a.exitIdx == 5 && a.exitPrice == 14)
        // timeStop(2): exits 2 bars after entry (idx 3), at that close.
        let t = StockSageBacktester.simulateExit(entryIdx: 1, stop: 5, target: 20,
                    opens: opens, highs: highs, lows: lows, closes: closes, n: 6, mode: .timeStop(maxBars: 2))
        #expect(t.outcome == .timeStop && t.exitIdx == 3 && t.exitPrice == 12)
        // A real stop still wins over the time limit when it triggers first (bar 2 dips to 4 ≤ 5).
        let lows2 = [10.0, 10, 4, 10, 10, 10]
        let s = StockSageBacktester.simulateExit(entryIdx: 1, stop: 5, target: 20,
                    opens: opens, highs: highs, lows: lows2, closes: closes, n: 6, mode: .timeStop(maxBars: 2))
        #expect(s.outcome == .stop && s.exitIdx == 2 && s.exitPrice == 5)
    }

    @Test func foldRangesTileThePostWarmupRegion() {
        let r = StockSageBacktester.foldRanges(n: 350, warmup: 50, folds: 3)
        #expect(r.count == 3)
        #expect(r.first?.lowerBound == 50)               // starts at the first post-warmup bar
        #expect(r.last?.upperBound == 350)               // covers through the last bar
        for (a, b) in zip(r, r.dropFirst()) { #expect(a.upperBound == b.lowerBound) }  // contiguous, no overlap/gap
        #expect(StockSageBacktester.foldRanges(n: 50, warmup: 50, folds: 3).isEmpty)   // no post-warmup bars
    }

    @Test func walkForwardSurfacesRegimeAcrossFolds() {
        // A strict downtrend never goes long in ANY fold (the regime is surfaced, not hidden).
        let down = history((0..<350).map { Double(350 - $0) })
        let dWF = StockSageBacktester.walkForward(down, warmup: 50, folds: 3)
        #expect(dWF.count == 3)
        #expect(dWF.allSatisfy { $0.trades == 0 })
        // A clean uptrend DOES trade across the folds, and each thin fold is flagged not-significant.
        let up = history((0..<350).map { 100.0 + Double($0) })
        let uWF = StockSageBacktester.walkForward(up, warmup: 50, folds: 3)
        #expect(uWF.count == 3)
        #expect(uWF.reduce(0) { $0 + $1.trades } > 0)
        #expect(uWF.allSatisfy { !$0.isSignificant })    // ~100-bar folds are far short of 20 trades
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
