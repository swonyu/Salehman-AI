import Foundation

// Scratch runner for the IRRX net-of-cost ablation. It reuses the VERBATIM shipped
// StockSageNetCostSim + StockSageDeflatedSharpe (compiled alongside) — zero reimplementation,
// so the math is exactly what ships. It only (a) loads a real return panel, (b) sweeps a
// horizon grid with selection-deflation, (c) reports net DSR with vs without the earnings
// exclusion. Nothing here is an edge claim; the verdict is whatever the panel yields.
//
// panel.json shape: { "returns": [[Double]], "industry": [Int],
//                     "earningsExcludedAt": { "<t>": [Int] },   // optional
//                     "roundTripBps": Double, "labels": [String], "provenance": "..." }

struct PanelJSON: Decodable {
    let returns: [[Double]]
    let industry: [Int]
    let earningsExcludedAt: [String: [Int]]?
    let roundTripBps: Double?
    let labels: [String]?
    let provenance: String?
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "panel.json"
guard let data = FileManager.default.contents(atPath: path),
      let pj = try? JSONDecoder().decode(PanelJSON.self, from: data) else {
    FileHandle.standardError.write("cannot load/decode \(path)\n".data(using: .utf8)!); exit(1)
}

let rtBps = pj.roundTripBps ?? 13.0
var excluded: [Int: Set<Int>] = [:]
for (k, v) in (pj.earningsExcludedAt ?? [:]) { if let t = Int(k) { excluded[t] = Set(v) } }

let panelWith = StockSageNetCostSim.Panel(returns: pj.returns, industry: pj.industry, earningsExcludedAt: excluded)
let panelWithout = StockSageNetCostSim.Panel(returns: pj.returns, industry: pj.industry, earningsExcludedAt: [:])

let S = panelWith.symbolCount, T = panelWith.periodCount
print("PANEL: \(S) symbols × \(T) periods · roundTripBps=\(rtBps) · earnings-excl entries=\(excluded.count)")
if let p = pj.provenance { print("PROVENANCE: \(p)") }

// Horizon grid over DAILY periods (lookback/hold in trading days). 12 configs → selection haircut.
let lookbacks = [5, 10, 21, 63]
let holds = [5, 10, 21]

func fullSharpe(_ xs: [Double]) -> Double? {
    let n = xs.count; guard n >= 4 else { return nil }
    let m = xs.reduce(0,+)/Double(n)
    let v = xs.map { ($0-m)*($0-m) }.reduce(0,+)/Double(n-1)
    guard v > 0 else { return nil }
    return m / v.squareRoot()
}

func run(_ panel: StockSageNetCostSim.Panel, label: String) {
    // Pass 1: gather each config's net full-series Sharpe → trial variance for the DSR deflation.
    var trialSharpes: [Double] = []
    var series: [(Int,Int,[Double])] = []
    for lb in lookbacks { for hd in holds {
        let rebs = StockSageNetCostSim.rebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: rtBps)
        guard rebs.count >= 4 else { continue }
        let net = rebs.map { $0.netReturn }
        if let s = fullSharpe(net) { trialSharpes.append(s) }
        series.append((lb, hd, net))
    }}
    let nTrials = max(1, series.count)
    let varTrial: Double = {
        guard trialSharpes.count >= 2 else { return 0 }
        let m = trialSharpes.reduce(0,+)/Double(trialSharpes.count)
        return trialSharpes.map { ($0-m)*($0-m) }.reduce(0,+)/Double(trialSharpes.count-1)
    }()
    print("\n=== \(label) · \(nTrials) configs · varTrialSharpe=\(String(format: "%.4f", varTrial)) ===")
    var bestOOS = -Double.infinity; var bestCfg = ""; var anyClears = false
    for lb in lookbacks { for hd in holds {
        guard let sim = StockSageNetCostSim.simulate(panel, lookback: lb, hold: hd, roundTripBps: rtBps,
                                                     folds: 3, embargo: 1, trials: nTrials, varTrialSharpe: varTrial)
        else { continue }
        let oos = sim.netVerdictOOS?.dsr ?? sim.netVerdictFull?.dsr ?? Double.nan
        let tag = sim.netVerdictOOS == nil ? "full" : "OOS"
        if oos > bestOOS { bestOOS = oos; bestCfg = "lb=\(lb),hd=\(hd)" }
        if sim.clearsNetOfCost { anyClears = true }
        print(String(format: "  lb=%2d hd=%2d  rebals=%3d  meanGross=%+.5f meanNet=%+.5f  net-%@ DSR=%.3f  clears=%@",
                     lb, hd, sim.rebalances.count, sim.meanGross, sim.meanNet, tag, oos, sim.clearsNetOfCost ? "YES" : "no"))
    }}
    print(String(format: "  → BEST net DSR = %.3f (%@);  ANY config clears DSR>0.95: %@",
                 bestOOS, bestCfg, anyClears ? "YES" : "NO"))
}

run(panelWithout, label: "WITHOUT earnings exclusion (industry-relative reversal)")
if !excluded.isEmpty { run(panelWith, label: "WITH earnings-window exclusion (full IRRX)") }
else { print("\n(no earnings-exclusion data in panel → IRRX variant skipped)") }
