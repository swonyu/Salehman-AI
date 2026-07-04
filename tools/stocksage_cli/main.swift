import Foundation

// Thin CLI over the REAL StockSage engine — compiles the app's own pure engine files (zero port).
// Honesty floor is the engine's: nil=unknown, gross vs net labeled, "no proven edge" carried.

func die(_ m: String) -> Never { FileHandle.standardError.write((m + "\n").data(using: .utf8)!); exit(2) }
func f6(_ d: Double) -> String { String(format: "%.6f", d) }

var argv = Array(CommandLine.arguments.dropFirst())
guard let cmd = argv.first else { die("usage: stocksage <netcost|idea> ...") }
argv = Array(argv.dropFirst())
func opt(_ name: String) -> String? {
    guard let i = argv.firstIndex(of: "--\(name)"), i + 1 < argv.count else { return nil }
    return argv[i + 1]
}

// FREE daily closes from CoinGecko (keyless, crypto only). Synchronous via a semaphore (CLI).
func fetchDailyCloses(coin: String, days: Int) -> [Double]? {
    let id = coin.lowercased()
    guard let url = URL(string: "https://api.coingecko.com/api/v3/coins/\(id)/market_chart?vs_currency=usd&days=\(days)&interval=daily") else { return nil }
    var out: [Double]?
    let sem = DispatchSemaphore(value: 0)
    var req = URLRequest(url: url); req.timeoutInterval = 25
    URLSession.shared.dataTask(with: req) { data, _, _ in
        defer { sem.signal() }
        guard let data = data,
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prices = j["prices"] as? [[Double]] else { return }
        out = prices.compactMap { $0.count >= 2 ? $0[1] : nil }
    }.resume()
    _ = sem.wait(timeout: .now() + 30)
    return out
}

switch cmd {
case "netcost":
    guard let e = opt("entry").flatMap(Double.init),
          let s = opt("stop").flatMap(Double.init),
          let t = opt("target").flatMap(Double.init) else {
        die("netcost needs --entry E --stop S --target T [--symbol SYM]")
    }
    let sym = opt("symbol") ?? "AAPL"
    let c = StockSageNetEdge.defaultCosts(forSymbol: sym)
    guard let ne = StockSageNetEdge.evaluate(entry: e, stop: s, target: t,
                                             spreadBps: c.spreadBps, slippageBps: c.slippageBps,
                                             takerFeeBps: c.takerFeeBps) else {
        die("degenerate setup (need target≠entry, |entry−stop|>0, entry>0)")
    }
    let be = ne.breakEvenWinRate.map(f6) ?? "null"
    print("""
    {
      "symbol": "\(sym)",
      "assetClass": "\(c.assetClass)",
      "roundTripBps": \(f6(c.roundTripBps)),
      "grossRR": \(f6(ne.grossRR)),
      "netRR": \(f6(ne.netRR)),
      "costPerShare": \(f6(ne.costPerShare)),
      "costAsPctOfReward": \(f6(ne.costAsPctOfReward)),
      "breakEvenWinRate": \(be),
      "verdict": "\(ne.verdict)",
      "_note": "net after a LABELED asset-class cost estimate, not a venue quote; the engine has no proven edge (DSR≈0)."
    }
    """)

case "deflated-sharpe":
    guard let rstr = opt("returns") else {
        die("deflated-sharpe needs --returns \"r1,r2,r3,…\" (per-period returns, ≥4) [--trials N] [--var-trial-sharpe X]")
    }
    let rs = rstr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard rs.count >= 4 else { die("need ≥4 numeric returns (got \(rs.count)) — DSR moments are nil below 4") }
    let trials = opt("trials").flatMap(Int.init) ?? 1
    let vts = opt("var-trial-sharpe").flatMap(Double.init) ?? 0
    let n = rs.count
    let mean = rs.reduce(0, +) / Double(n)
    let sd = (rs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(n - 1)).squareRoot()  // SAMPLE (n−1)
    let sharpe = sd > 0 ? mean / sd : 0
    guard let m = StockSageDeflatedSharpe.moments(rs) else { die("moments nil (need ≥4 returns)") }
    let r = StockSageDeflatedSharpe.deflated(observedSharpe: sharpe, nTrades: n, skew: m.skew,
                                             kurtosis: m.kurtosis, trials: Swift.max(1, trials), varTrialSharpe: vts)
    print("""
    {
      "n": \(n),
      "sharpe": \(f6(sharpe)),
      "psr": \(f6(r.psr)),
      "dsr": \(f6(r.dsr)),
      "trials": \(r.trials),
      "passesDSRbar": \(r.passes),
      "_note": "sharpe = per-period mean ÷ SAMPLE stdev (backtester convention); DSR>0.95 = the honest 'real edge' bar (trials≥2 applies the selection-bias haircut). The shipped engine has no proven edge (DSR≈0)."
    }
    """)

case "indicators":
    guard let coin = opt("coin") else {
        die("indicators needs --coin <coingecko-id, e.g. bitcoin|ethereum|solana> [--days N] (crypto only — free CoinGecko)")
    }
    let days = opt("days").flatMap(Int.init) ?? 365
    guard let closes = fetchDailyCloses(coin: coin, days: days), closes.count >= 30 else {
        die("fetch failed or <30 daily closes for '\(coin)' — check the CoinGecko coin-id (not the ticker) + network")
    }
    let n = closes.count
    func jn(_ d: Double?) -> String { d.map(f6) ?? "null" }
    func jb(_ b: Bool?) -> String { b.map { $0 ? "true" : "false" } ?? "null" }
    print("""
    {
      "coin": "\(coin.lowercased())",
      "bars": \(n),
      "lastClose": \(f6(closes.last!)),
      "rsi14": \(jn(StockSageIndicators.rsi(closes))),
      "sma50": \(jn(StockSageIndicators.sma(closes, period: 50))),
      "sma200": \(jn(StockSageIndicators.sma(closes, period: 200))),
      "tsMomentum12_1": \(jn(StockSageIndicators.timeSeriesMomentum(closes))),
      "trendOK": \(jb(StockSageIndicators.trendOK(closes))),
      "efficiencyRatio": \(jn(StockSageIndicators.efficiencyRatio(closes))),
      "annualizedVol_fraction": \(jn(StockSageIndicators.annualizedVolatility(closes))),
      "_note": "real StockSageIndicators on CoinGecko daily closes (free, keyless). nil=unknown (insufficient history — trendOK/tsMomentum need ~253 bars, sma200 needs 200), NEVER fabricated. annualizedVol is a FRACTION (0.20=20%). Analysis, not advice; the engine has no proven edge (DSR≈0)."
    }
    """)

default:
    die("unknown command '\(cmd)' (have: netcost, deflated-sharpe, indicators)")
}
