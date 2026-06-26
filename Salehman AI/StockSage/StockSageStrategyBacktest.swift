import Foundation

// MARK: - Aggregate (strategy-wide) backtest
//
// The per-symbol backtester answers "did these rules work on AAPL?" This rolls
// many symbols up into one honest verdict on the strategy itself: how it did
// across the whole watchlist, not cherry-picked names. Pure aggregation →
// unit-tested. Brutally honest about its own limits (small samples, survivorship,
// fixed-not-optimized rules) — past performance is not predictive.

struct StrategyBacktest: Sendable, Equatable {
    let symbolsTested: Int
    let symbolsWithTrades: Int
    let symbolsProfitable: Int     // total R > 0
    let totalTrades: Int
    let wins: Int
    let blendedWinRate: Double     // wins ÷ total trades
    let avgR: Double               // total R ÷ total trades (expectancy)
    let totalR: Double
    let worstDrawdownR: Double     // worst single-symbol max drawdown, in R
    /// Pooled per-trade t-statistic across ALL symbols' trades = (mean R ÷ stdev R) × √trades.
    /// 0 when unknown (<2 pooled trades or no dispersion). Honest significance gauge.
    let tStat: Double
    /// Below this the aggregate is still noise.
    var isSignificant: Bool { totalTrades >= 100 }
    /// Clears the t > 3 multiple-testing bar (Harvey-Liu-Zhu 2016) — NOT the textbook 2.0. Necessary,
    /// not sufficient: it can't see how many rule variants were tried, which only raises the hurdle.
    var clearsMultipleTestingBar: Bool { tStat > 3.0 }
    var significanceVerdict: String {
        if !isSignificant { return "Only \(totalTrades) trades — the aggregate isn't statistically meaningful yet." }
        if tStat > 3.0 { return String(format: "t = %.1f — clears the t>3 multiple-testing bar (necessary, not sufficient).", tStat) }
        if tStat > 2.0 { return String(format: "t = %.1f — significant at 2σ but BELOW the t>3 bar; treat as unproven.", tStat) }
        return String(format: "t = %.1f — not significant; likely noise.", tStat)
    }
    let caveat: String

    nonisolated init(symbolsTested: Int, symbolsWithTrades: Int, symbolsProfitable: Int, totalTrades: Int,
                     wins: Int, blendedWinRate: Double, avgR: Double, totalR: Double, worstDrawdownR: Double,
                     tStat: Double = 0, caveat: String) {
        self.symbolsTested = symbolsTested; self.symbolsWithTrades = symbolsWithTrades
        self.symbolsProfitable = symbolsProfitable; self.totalTrades = totalTrades; self.wins = wins
        self.blendedWinRate = blendedWinRate; self.avgR = avgR; self.totalR = totalR
        self.worstDrawdownR = worstDrawdownR; self.tStat = tStat; self.caveat = caveat
    }
}

enum StockSageStrategyBacktest {
    /// A bounded sample of liquid global equities (no indices/FX/crypto — the
    /// long-side rules are built for equities). Keeps the run cost reasonable.
    nonisolated static let sampleSymbols: [String] = [
        "AAPL", "MSFT", "NVDA", "AMZN", "GOOGL", "META", "TSLA", "JPM",
        "SHEL.L", "AZN.L", "SAP.DE", "MC.PA", "NESN.SW", "ASML.AS",
        "7203.T", "6758.T", "0700.HK", "RELIANCE.NS", "TCS.NS",
        "BHP.AX", "RY.TO", "2222.SR", "1120.SR", "005930.KS",
    ]

    nonisolated static let caveat = "Aggregate of the advisor's FIXED rules over ~5y of these names — backward-looking, small-sample-prone, and survivorship-biased (only currently-listed symbols). Past performance is not future performance."

    /// `trades` (optional) are the POOLED per-trade records across all symbols — when supplied, the
    /// aggregate carries an honest pooled t-statistic. Omit (default) → tStat 0, behaviour unchanged.
    nonisolated static func aggregate(_ results: [BacktestResult], trades: [BacktestTrade] = []) -> StrategyBacktest {
        let withTrades = results.filter { $0.trades > 0 }
        let totalTrades = results.reduce(0) { $0 + $1.trades }
        let wins = results.reduce(0) { $0 + $1.wins }
        let totalR = results.reduce(0.0) { $0 + $1.totalR }
        let profitable = withTrades.filter { $0.totalR > 0 }.count
        let worstDD = results.map(\.maxDrawdownR).max() ?? 0
        // Pooled per-trade t-stat across every symbol's trades (mean/stdev × √n).
        let rs = trades.map(\.r)
        let tStat: Double = {
            guard rs.count >= 2 else { return 0 }
            let mean = rs.reduce(0, +) / Double(rs.count)
            let variance = rs.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(rs.count - 1)
            let sd = variance.squareRoot()
            return sd > 0 ? (mean / sd) * Double(rs.count).squareRoot() : 0
        }()
        return StrategyBacktest(
            symbolsTested: results.count,
            symbolsWithTrades: withTrades.count,
            symbolsProfitable: profitable,
            totalTrades: totalTrades,
            wins: wins,
            blendedWinRate: totalTrades > 0 ? Double(wins) / Double(totalTrades) : 0,
            avgR: totalTrades > 0 ? totalR / Double(totalTrades) : 0,
            totalR: totalR,
            worstDrawdownR: worstDD,
            tStat: tStat,
            caveat: caveat)
    }
}
