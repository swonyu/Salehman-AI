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

default:
    die("unknown command '\(cmd)' (have: netcost)")
}
