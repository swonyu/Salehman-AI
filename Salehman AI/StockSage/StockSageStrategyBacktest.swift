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
    /// Below this the aggregate is still noise.
    var isSignificant: Bool { totalTrades >= 100 }
    let caveat: String
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

    nonisolated static func aggregate(_ results: [BacktestResult]) -> StrategyBacktest {
        let withTrades = results.filter { $0.trades > 0 }
        let totalTrades = results.reduce(0) { $0 + $1.trades }
        let wins = results.reduce(0) { $0 + $1.wins }
        let totalR = results.reduce(0.0) { $0 + $1.totalR }
        let profitable = withTrades.filter { $0.totalR > 0 }.count
        let worstDD = results.map(\.maxDrawdownR).max() ?? 0
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
            caveat: caveat)
    }
}
