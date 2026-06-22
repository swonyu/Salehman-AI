import Foundation

// MARK: - StockSageBacktester
//
// A walk-forward backtest of the advisor's LONG rules over one symbol's candle
// history — the honesty check on the whole "ideas" feature. Pure + deterministic
// so it's unit-tested, and built to NOT lie to the owner:
//
//  • No look-ahead: the decision at bar `i` uses ONLY closes/highs/lows up to and
//    including `i`; the entry fills at bar `i+1`'s OPEN (data that exists the next
//    session). We never peek at a bar to decide trading it.
//  • Conservative tie-break: if a single bar touches both the stop and the target,
//    we assume the STOP hit first (worst case), so results aren't flattered.
//  • One position at a time: scanning resumes only after a trade closes — no
//    overlapping, no compounding fantasy.
//  • Honesty surfaced, not hidden: we report trade COUNT and max drawdown, and
//    flag small samples (`isSignificant`). Survivorship bias is inherent (we test
//    today's listed symbols) and overfitting is bounded (few FIXED rules, not
//    per-symbol optimization) — both are called out in the UI caveat.
//
// Past performance is not predictive; this measures whether the rules *held up*,
// nothing more.

/// One simulated trade.
struct BacktestTrade: Sendable, Equatable {
    enum Outcome: String, Sendable { case target, stop, openAtEnd }
    let entryIndex: Int
    let exitIndex: Int
    let entry: Double
    let exit: Double
    /// Result in R-multiples: (exit − entry) ÷ (entry − stop). +2 = hit a 2:1 target.
    let r: Double
    let outcome: Outcome
}

/// Aggregate, honestly-framed backtest metrics.
struct BacktestResult: Sendable, Equatable {
    let trades: Int
    let wins: Int
    let winRate: Double        // 0–1
    let avgR: Double           // expectancy per trade, in R
    let totalR: Double
    let maxDrawdownR: Double   // worst peak-to-trough of cumulative R
    let sharpe: Double         // per-trade mean ÷ stdev (0 when <2 trades or zero variance)
    let avgHoldBars: Double
    let avgWinR: Double        // average R of winning trades
    let avgLossR: Double       // average R of losing trades, as a POSITIVE magnitude

    /// Defaulted new fields so older constructions (empty, tests) stay valid.
    nonisolated init(trades: Int, wins: Int, winRate: Double, avgR: Double, totalR: Double,
                     maxDrawdownR: Double, sharpe: Double, avgHoldBars: Double,
                     avgWinR: Double = 0, avgLossR: Double = 0) {
        self.trades = trades; self.wins = wins; self.winRate = winRate; self.avgR = avgR
        self.totalR = totalR; self.maxDrawdownR = maxDrawdownR; self.sharpe = sharpe
        self.avgHoldBars = avgHoldBars; self.avgWinR = avgWinR; self.avgLossR = avgLossR
    }

    /// Below this, the numbers are noise — the UI must say so.
    var isSignificant: Bool { trades >= 20 }

    nonisolated static let empty = BacktestResult(trades: 0, wins: 0, winRate: 0, avgR: 0,
                                                  totalR: 0, maxDrawdownR: 0, sharpe: 0, avgHoldBars: 0)
}

enum StockSageBacktester {

    /// Walk forward over `history`. `warmup` bars are skipped so the 200-day trend
    /// and the other indicators are valid before the first decision (use a multi-year
    /// history so there's room to trade after the warmup).
    /// `costs` (optional) charges a round-trip friction (spread+slippage, in bps of the
    /// fill price) against EVERY trade's R — so the equity curve reflects what you'd
    /// actually net, not a frictionless fantasy. nil = the original cost-free result,
    /// byte-for-byte (existing callers/tests unchanged). Pass e.g.
    /// `StockSageNetEdge.defaultCosts(forSymbol:)` for an asset-class default.
    nonisolated static func run(_ history: StockSagePriceHistory, warmup: Int = 200,
                                costs: StockSageNetEdge.CostAssumption? = nil) -> BacktestResult {
        let closes = history.closes, opens = history.opens, highs = history.highs, lows = history.lows
        let n = closes.count
        guard n > warmup + 5, opens.count == n, highs.count == n, lows.count == n else { return .empty }

        var trades: [BacktestTrade] = []
        var i = warmup
        while i < n - 1 {
            // Decide using ONLY data available at the close of bar i.
            let advice = StockSageAdvisor.advise(closes: Array(closes[0...i]),
                                                 highs: Array(highs[0...i]),
                                                 lows: Array(lows[0...i]))
            guard advice.action == .buy || advice.action == .strongBuy,
                  let stop = advice.stopPrice else { i += 1; continue }

            // Fill at the NEXT bar's open (no look-ahead). Size the target 2:1 off
            // the actual fill. Skip if the open already gapped below the stop.
            let entryIdx = i + 1
            let entry = opens[entryIdx]
            let risk = entry - stop
            guard risk > 0 else { i += 1; continue }
            let target = entry + 2 * risk

            // Walk forward to the first stop/target touch (stop wins ties).
            var exitIdx = n - 1
            var exitPrice = closes[n - 1]
            var outcome: BacktestTrade.Outcome = .openAtEnd
            var j = entryIdx
            while j < n {
                // Adverse-gap honesty: if the bar gapped open BELOW the stop, a stop
                // order fills at that worse open, not magically at the stop price —
                // so losers aren't flattered. (Target stays a resting limit at `target`.)
                if lows[j] <= stop { exitIdx = j; exitPrice = Swift.min(stop, opens[j]); outcome = .stop; break }
                if highs[j] >= target { exitIdx = j; exitPrice = target; outcome = .target; break }
                j += 1
            }

            // Round-trip friction (in price units) eats into the realized R — the very
            // spread/slippage NetEdge models but the equity curve used to ignore.
            let costPerShare = costs.map { Swift.max(0, $0.roundTripBps) / 10_000 * entry } ?? 0
            let r = (exitPrice - entry - costPerShare) / risk
            trades.append(BacktestTrade(entryIndex: entryIdx, exitIndex: exitIdx,
                                        entry: entry, exit: exitPrice, r: r, outcome: outcome))
            i = exitIdx + 1   // one position at a time — resume after the close
        }
        return summarize(trades)
    }

    /// Contiguous, NON-overlapping test windows that tile the post-warmup region [warmup, n).
    /// Pure index math (no data) so the partition itself is unit-tested. Empty if folds<1 or
    /// there are no post-warmup bars.
    nonisolated static func foldRanges(n: Int, warmup: Int, folds: Int) -> [Range<Int>] {
        guard folds > 0, n > warmup else { return [] }
        let testLen = n - warmup
        return (0..<folds).map { k in
            (warmup + k * testLen / folds) ..< (warmup + (k + 1) * testLen / folds)
        }
    }

    /// Walk-forward / out-of-sample stability: run() over each fold's test window separately,
    /// so the owner sees whether the edge HOLDS across time or was one lucky regime. Each fold
    /// gets its own `warmup` prefix of preceding bars (shared history, NOT counted trades — the
    /// test windows never overlap), then trades only its window. A strategy that worked in one
    /// stretch shows degraded avgR in the others; thin folds carry isSignificant == false so the
    /// UI can't over-trust them. Empty when the history is too short to fold.
    nonisolated static func walkForward(_ history: StockSagePriceHistory, warmup: Int = 200,
                                        folds: Int = 3) -> [BacktestResult] {
        let n = history.closes.count
        guard history.opens.count == n, history.highs.count == n, history.lows.count == n,
              history.dates.count == n, history.volumes.count == n else { return [] }
        return foldRanges(n: n, warmup: warmup, folds: folds).map { range in
            let sliceStart = range.lowerBound - warmup    // ≥ 0 by construction
            guard sliceStart >= 0 else { return .empty }
            return run(subHistory(history, from: sliceStart, to: range.upperBound), warmup: warmup)
        }
    }

    /// A contiguous [lo, hi) slice of a history across every parallel array.
    private nonisolated static func subHistory(_ h: StockSagePriceHistory, from lo: Int, to hi: Int)
        -> StockSagePriceHistory {
        StockSagePriceHistory(symbol: h.symbol,
                              dates: Array(h.dates[lo..<hi]), opens: Array(h.opens[lo..<hi]),
                              highs: Array(h.highs[lo..<hi]), lows: Array(h.lows[lo..<hi]),
                              closes: Array(h.closes[lo..<hi]), volumes: Array(h.volumes[lo..<hi]))
    }

    /// Aggregate the simulated trades into honest metrics. `internal` (not private) so the
    /// aggregation math is unit-tested directly with synthetic trades.
    nonisolated static func summarize(_ trades: [BacktestTrade]) -> BacktestResult {
        guard !trades.isEmpty else { return .empty }
        let rs = trades.map(\.r)
        let winRs = rs.filter { $0 > 0 }
        let lossRs = rs.filter { $0 < 0 }
        let wins = winRs.count
        let totalR = rs.reduce(0, +)
        let avgR = totalR / Double(rs.count)
        let avgWinR = winRs.isEmpty ? 0 : winRs.reduce(0, +) / Double(winRs.count)
        let avgLossR = lossRs.isEmpty ? 0 : -lossRs.reduce(0, +) / Double(lossRs.count)   // positive magnitude

        // Max drawdown of the cumulative-R curve.
        var cum = 0.0, peak = 0.0, maxDD = 0.0
        for r in rs { cum += r; peak = Swift.max(peak, cum); maxDD = Swift.max(maxDD, peak - cum) }

        // Per-trade Sharpe (mean ÷ stdev); 0 when there's no dispersion to measure.
        let sd: Double = {
            guard rs.count > 1 else { return 0 }
            let variance = rs.reduce(0) { $0 + ($1 - avgR) * ($1 - avgR) } / Double(rs.count - 1)
            return variance.squareRoot()
        }()
        let sharpe = sd > 0 ? avgR / sd : 0
        let avgHold = trades.map { Double($0.exitIndex - $0.entryIndex) }.reduce(0, +) / Double(trades.count)

        return BacktestResult(trades: trades.count, wins: wins,
                              winRate: Double(wins) / Double(trades.count),
                              avgR: avgR, totalR: totalR, maxDrawdownR: maxDD,
                              sharpe: sharpe, avgHoldBars: avgHold,
                              avgWinR: avgWinR, avgLossR: avgLossR)
    }
}
