import Foundation
import CryptoKit

// Scratch runner for the IRRX net-of-cost ablation. It reuses the VERBATIM shipped
// StockSageNetCostSim + StockSageDeflatedSharpe (compiled alongside) — zero reimplementation,
// so the math is exactly what ships. It only (a) loads a real return panel, (b) sweeps a
// horizon grid with selection-deflation, (c) reports net DSR with vs without the earnings
// exclusion. Nothing here is an edge claim; the verdict is whatever the panel yields.
//
// panel.json shape: { "returns": [[Double]], "industry": [Int],
//                     "earningsExcludedAt": { "<t>": [Int] },   // optional
//                     "roundTripBps": Double, "labels": [String], "provenance": "..." }
//
// WALK-BACKWARD ROBUSTNESS MODE (env REVERSED=1; research/INDEX §5 checklist #6). Reverses the
// panel's PERIOD ORDER — each period's cross-section (all symbols' returns at that t) stays
// intact, only the SEQUENCE of periods flips. `earningsExcludedAt` keys remap
// newIndex = (periodCount-1) - oldIndex so an exclusion tagged at old period t still lands on
// the same calendar date's new position. When set, runs forward AND reversed in one process and
// prints a FLIP-VS-HOLD comparison (see `printFlipVsHold` for the honest-interpretation guide).

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
// 2026-07-09: grid extended to match the runs indexed in RESEARCH_2026-07-09_yahoo5y_multiyear.md
// and the momsign harness (lb=126 rows are formable on any >=1,253-bar panel; on shorter panels the
// runner already skips unformable configs). Committed so the repo runner reproduces the indexed grids.
let lookbacks = [5, 10, 21, 63, 126]
let holds = [5, 10, 21]

// MARK: - Trials ledger (research/trials_ledger.jsonl; ALWAYS-ON, opt-out via TRIALS_LEDGER=off —
// see the "TRIAL REGISTRY" design: an omitted arm silently under-deflates every future DSR, the
// dangerous direction; a duplicated arm just dedups. RUN_ID env overrides the deterministic id.)
func ledgerPath() -> String? {
    let env = ProcessInfo.processInfo.environment
    if let p = env["TRIALS_LEDGER"] { return p == "off" ? nil : p }
    let cwd = FileManager.default.currentDirectoryPath
    return FileManager.default.fileExists(atPath: cwd + "/research") ? cwd + "/research/trials_ledger.jsonl" : "trials_ledger_fragment.jsonl"
}
func slug(_ s: String) -> String {
    var out = ""
    for c in s.lowercased() { out.append(c.isLetter || c.isNumber ? c : "-") }
    while out.contains("--") { out = out.replacingOccurrences(of: "--", with: "-") }
    return String(out.prefix(48)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}
func ledgerRunID(_ seed: String) -> String {
    if let id = ProcessInfo.processInfo.environment["RUN_ID"] { return id }
    let hash = SHA256.hash(data: Data(seed.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    return "\(String(ISO8601DateFormatter().string(from: Date()).prefix(10)))_\(hash.prefix(8))"
}
func ledgerNum(_ d: Double?) -> String { guard let d = d, d.isFinite else { return "null" }; return String(d) }
func ledgerAppend(path: String, run: String, family: String, panel: String, config: String, role: String,
                   meanNetPct: Double?, sharpe: Double?, sharpeBasis: String, dsr: Double?, sourceFile: String) {
    let date = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
    let line = "{\"date\":\"\(date)\",\"run\":\"\(run)\",\"family\":\"\(family)\",\"panel\":\"\(panel)\"," +
        "\"config\":\"\(config)\",\"role\":\"\(role)\",\"meanNetPct\":\(ledgerNum(meanNetPct))," +
        "\"sharpe\":\(ledgerNum(sharpe)),\"sharpe_basis\":\"\(sharpeBasis)\"," +
        "\"dsr\":\(ledgerNum(dsr)),\"source_file\":\"\(sourceFile)\"}\n"
    guard let d = line.data(using: .utf8) else { return }
    if let h = FileHandle(forWritingAtPath: path) { h.seekToEndOfFile(); h.write(d); h.closeFile() }
    else { FileManager.default.createFile(atPath: path, contents: d) }
}
let ledgerPanelID = "\(S)x\(T)-panel/" + slug(pj.provenance ?? "unspecified")
let ledgerGridSeed = (pj.provenance ?? "") + lookbacks.map(String.init).joined(separator: ",") + "|" + holds.map(String.init).joined(separator: ",")
let ledgerRun = ledgerRunID(ledgerGridSeed)

func fullSharpe(_ xs: [Double]) -> Double? {
    let n = xs.count; guard n >= 4 else { return nil }
    let m = xs.reduce(0,+)/Double(n)
    let v = xs.map { ($0-m)*($0-m) }.reduce(0,+)/Double(n-1)
    guard v > 0 else { return nil }
    return m / v.squareRoot()
}

// Per-config net result, kept around so a reversed run can be diffed against its forward twin.
struct ConfigNet { let lb: Int; let hd: Int; let meanNet: Double }
struct RunResult { let configs: [ConfigNet]; let bestOOS: Double; let bestCfg: String }

@discardableResult
func run(_ panel: StockSageNetCostSim.Panel, label: String, role: String = "trial", excl: String = "without") -> RunResult {
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
    var configs: [ConfigNet] = []
    let lp = ledgerPath()
    var ledgerAppended = 0
    for lb in lookbacks { for hd in holds {
        guard let sim = StockSageNetCostSim.simulate(panel, lookback: lb, hold: hd, roundTripBps: rtBps,
                                                     folds: 3, embargo: 1, trials: nTrials, varTrialSharpe: varTrial)
        else { continue }
        let oos = sim.netVerdictOOS?.dsr ?? sim.netVerdictFull?.dsr ?? Double.nan
        let tag = sim.netVerdictOOS == nil ? "full" : "OOS"
        if oos > bestOOS { bestOOS = oos; bestCfg = "lb=\(lb),hd=\(hd)" }
        if sim.clearsNetOfCost { anyClears = true }
        configs.append(ConfigNet(lb: lb, hd: hd, meanNet: sim.meanNet))
        print(String(format: "  lb=%2d hd=%2d  rebals=%3d  meanGross=%+.5f meanNet=%+.5f  net-%@ DSR=%.3f  clears=%@",
                     lb, hd, sim.rebalances.count, sim.meanGross, sim.meanNet, tag, oos, sim.clearsNetOfCost ? "YES" : "no"))
        if let lp = lp {
            ledgerAppend(path: lp, run: ledgerRun, family: "reversal-irrx", panel: ledgerPanelID,
                         config: "lb=\(lb),hd=\(hd),excl=\(excl)", role: role, meanNetPct: sim.meanNet * 100,
                         sharpe: fullSharpe(sim.netReturns), sharpeBasis: "full-series-net-per-rebalance",
                         dsr: oos.isFinite ? oos : nil, sourceFile: "tools/altdata_ablation/main.swift")
            ledgerAppended += 1
        }
    }}
    print(String(format: "  → BEST net DSR = %.3f (%@);  ANY config clears DSR>0.95: %@",
                 bestOOS, bestCfg, anyClears ? "YES" : "NO"))
    if let lp = lp { print("LEDGER: appended \(ledgerAppended) arms → \(lp)") }
    return RunResult(configs: configs, bestOOS: bestOOS, bestCfg: bestCfg)
}

// Reverses period ORDER only: each column t (all symbols' returns at that date) stays intact,
// the sequence of columns flips. earningsExcludedAt keys remap onto the same reversed axis —
// see the WALK-BACKWARD doc comment at the top of this file for why (periodCount-1)-t is correct.
func reversedPanel(_ panel: StockSageNetCostSim.Panel) -> StockSageNetCostSim.Panel {
    let T = panel.periodCount
    let revReturns = panel.returns.map { Array($0.reversed()) }
    var revExcluded: [Int: Set<Int>] = [:]
    for (t, syms) in panel.earningsExcludedAt { revExcluded[(T - 1) - t] = syms }
    return StockSageNetCostSim.Panel(returns: revReturns, industry: panel.industry, earningsExcludedAt: revExcluded)
}

func printFlipVsHold(_ label: String, forward: RunResult, reversed: RunResult) {
    print("\n=== FLIP-VS-HOLD: \(label) ===")
    for (i, f) in forward.configs.enumerated() where i < reversed.configs.count {
        let r = reversed.configs[i]
        let flip = (f.meanNet > 0) != (r.meanNet > 0)
        print(String(format: "  lb=%2d hd=%2d  forward meanNet=%+.5f  reversed meanNet=%+.5f  sign-flip=%@",
                     f.lb, f.hd, f.meanNet, r.meanNet, flip ? "YES" : "no"))
    }
    print(String(format: "  BEST forward net DSR = %.3f (%@)   BEST reversed net DSR = %.3f (%@)",
                 forward.bestOOS, forward.bestCfg, reversed.bestOOS, reversed.bestCfg))
}

let forwardWithout = run(panelWithout, label: "WITHOUT earnings exclusion (industry-relative reversal)", role: "trial", excl: "without")
var forwardWith: RunResult? = nil
if !excluded.isEmpty { forwardWith = run(panelWith, label: "WITH earnings-window exclusion (full IRRX)", role: "trial", excl: "with") }
else { print("\n(no earnings-exclusion data in panel → IRRX variant skipped)") }

if ProcessInfo.processInfo.environment["REVERSED"] == "1" {
    let panelWithoutRev = reversedPanel(panelWithout)
    let reversedWithout = run(panelWithoutRev, label: "REVERSED WITHOUT earnings exclusion", role: "diagnostic", excl: "without")
    var reversedWith: RunResult? = nil
    if !excluded.isEmpty {
        reversedWith = run(reversedPanel(panelWith), label: "REVERSED WITH earnings-window exclusion (full IRRX)", role: "diagnostic", excl: "with")
    }

    printFlipVsHold("WITHOUT earnings exclusion", forward: forwardWithout, reversed: reversedWithout)
    if let fw = forwardWith, let rv = reversedWith {
        printFlipVsHold("WITH earnings-window exclusion (full IRRX)", forward: fw, reversed: rv)
    }

    print("""

    INTERPRETATION GUIDE (read before trusting any flip above):
      - Reversal breaks real market dynamics — momentum/reversal are TIME-DIRECTIONAL, so a
        reversed-period run is not a valid alternate history, only a diagnostic.
      - A sign-flip on an ALREADY-NULL config (clears=no both directions) adds nothing: the
        forward result was never significant, so there is nothing for the flip to overfit.
      - A sign-flip on a config that clears DSR>0.95 FORWARD is the meaningful case: it is
        direct evidence that "edge" was fit to this specific temporal order, not real
        time-directional structure — i.e., overfitting.
      - This flag exists for FUTURE would-be positives; on a null panel it is inert commentary.
    """)
}
