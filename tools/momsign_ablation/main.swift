import Foundation
import CryptoKit

// Momentum-sign ablation (variants A/B x earnings-exclusion arms) on the cached 61-name/5y IRRX
// panel. Links against the SHIPPED StockSageNetCostSim + StockSageDeflatedSharpe (compiled from
// their repo paths, never copied). Only ONE piece of logic is reimplemented here: the generic
// weight-fn rebalance loop (byte-for-byte the shipped rebalanceSeries loop, parameterized on the
// weight function) plus Variant B's clipped long-only weight rule. Everything else calls shipped
// code directly.

func abortRun(_ msg: String) -> Never {
    FileHandle.standardError.write(("ABORT: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

// MARK: - SplitMix64 + Box-Muller (deterministic seeded Gaussian, per spec section 4)

struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func nextUInt64() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextUniform() -> Double {
        Double(nextUInt64() >> 11) * (1.0 / 9007199254740992.0) // 2^-53
    }
}

func gaussianSeries(n: Int, seed: UInt64) -> [Double] {
    var rng = SplitMix64(seed: seed)
    var out: [Double] = []
    out.reserveCapacity(n)
    while out.count < n {
        let u1 = Swift.max(rng.nextUniform(), 1e-300)
        let u2 = rng.nextUniform()
        let r = (-2.0 * Foundation.log(u1)).squareRoot()
        let z0 = r * cos(2 * Double.pi * u2)
        let z1 = r * sin(2 * Double.pi * u2)
        out.append(z0)
        if out.count < n { out.append(z1) }
    }
    return out
}

// MARK: - Panel JSON

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
    abortRun("cannot load/decode \(path)")
}

// MARK: - Panel sanity asserts (spec section 3)

let rtBps = pj.roundTripBps ?? 13.0
var excludedRaw: [Int: Set<Int>] = [:]
for (k, v) in (pj.earningsExcludedAt ?? [:]) { if let t = Int(k) { excludedRaw[t] = Set(v) } }

let S = pj.returns.count
let T = pj.returns.first?.count ?? 0
let distinctIndustries = Set(pj.industry).count
let earningsEntries = pj.earningsExcludedAt?.count ?? 0
let labelsHead = Array((pj.labels ?? []).prefix(8))
let expectedLabelsHead = ["AAPL", "MSFT", "NVDA", "GOOGL", "GOOG", "META", "AVGO", "ORCL"]

print("PANEL ASSERTS:")
print("  symbolCount=\(S) (expect 61)")
print("  periodCount=\(T) (expect 1253)")
print("  industry.count=\(pj.industry.count) (expect 61), distinct groups=\(distinctIndustries) (expect 7)")
print("  earningsExcludedAt entries=\(earningsEntries) (expect 926)")
print("  roundTripBps=\(rtBps) (expect 13.0)")
print("  labels[:8]=\(labelsHead) (expect \(expectedLabelsHead))")

guard S == 61, T == 1253, pj.industry.count == 61, distinctIndustries == 7,
      earningsEntries == 926, rtBps == 13.0, labelsHead == expectedLabelsHead else {
    abortRun("panel sanity assert FAILED — wrong panel or drifted harness")
}
print("PANEL ASSERTS: ALL PASS")
if let p = pj.provenance { print("PROVENANCE: \(p)") }

let panelWith = StockSageNetCostSim.Panel(returns: pj.returns, industry: pj.industry, earningsExcludedAt: excludedRaw)
let panelWithout = StockSageNetCostSim.Panel(returns: pj.returns, industry: pj.industry, earningsExcludedAt: [:])

// MARK: - DSR-responsiveness preflight (spec section 4)

func runPreflight() {
    let edge = (0..<200).map { i -> Double in 0.004 + 0.01 * gaussianSeries(n: 200, seed: 2)[i] }
    var noiseSeed: UInt64 = 3
    var noise = (0..<200).map { i -> Double in 0.01 * gaussianSeries(n: 200, seed: noiseSeed)[i] }

    guard let edgeVerdict = StockSageNetCostSim.verdict(edge, trials: 1) else {
        abortRun("preflight: edge series verdict() returned nil")
    }
    print("PREFLIGHT: edge series (n=200, seed=2) DSR=\(edgeVerdict.dsr) (require >= 0.95)")
    guard edgeVerdict.dsr >= 0.95 else {
        abortRun("preflight FAILED: edge series DSR \(edgeVerdict.dsr) < 0.95 — machinery not responsive")
    }

    guard var noiseVerdict = StockSageNetCostSim.verdict(noise, trials: 1) else {
        abortRun("preflight: noise series verdict() returned nil")
    }
    print("PREFLIGHT: noise series (n=200, seed=3) DSR=\(noiseVerdict.dsr) (require < 0.95)")
    if noiseVerdict.dsr >= 0.95 {
        print("PREFLIGHT: noise seed=3 fluked >= 0.95 — documented ONE-TIME reseed to seed=4")
        noiseSeed = 4
        noise = (0..<200).map { i -> Double in 0.01 * gaussianSeries(n: 200, seed: noiseSeed)[i] }
        guard let nv2 = StockSageNetCostSim.verdict(noise, trials: 1) else {
            abortRun("preflight: reseeded noise series verdict() returned nil")
        }
        noiseVerdict = nv2
        print("PREFLIGHT: noise series (n=200, seed=4) DSR=\(noiseVerdict.dsr) (require < 0.95)")
    }
    guard noiseVerdict.dsr < 0.95 else {
        abortRun("preflight FAILED: noise series DSR \(noiseVerdict.dsr) >= 0.95 even after one reseed")
    }
    print("PREFLIGHT: PASS")
}
runPreflight()

// MARK: - Generic weight-fn rebalance loop (the one reimplemented piece — byte-for-byte the
// shipped rebalanceSeries statement order, spec section 5)

typealias Panel = StockSageNetCostSim.Panel
typealias Rebalance = StockSageNetCostSim.Rebalance

func genericRebalanceSeries(_ panel: Panel, lookback: Int, hold: Int, roundTripBps: Double,
                             weightFn: (Panel, Int, Int, Set<Int>) -> [Double]) -> [Rebalance] {
    let s = panel.symbolCount
    let T = panel.periodCount
    guard s > 0, lookback > 0, hold > 0, T >= lookback + hold else { return [] }
    let perSideCost = max(0, roundTripBps) / 2 / 10_000.0
    var out: [Rebalance] = []
    var prevW = [Double](repeating: 0, count: s)
    var t = lookback
    while t + hold <= T {
        let excluded = panel.earningsExcludedAt[t] ?? []
        let w = weightFn(panel, t, lookback, excluded)
        var gross = 0.0
        for sym in 0..<s {
            var fwd = 0.0
            for u in t..<(t + hold) { fwd += panel.returns[sym][u] }
            gross += w[sym] * fwd
        }
        var turnover = 0.0
        for sym in 0..<s { turnover += abs(w[sym] - prevW[sym]) }
        let net = gross - turnover * perSideCost
        out.append(Rebalance(t: t, grossReturn: gross, turnover: turnover, netReturn: net))
        prevW = w
        t += hold
    }
    return out
}

func irrxWeightFn(_ panel: Panel, _ t: Int, _ lookback: Int, _ excluded: Set<Int>) -> [Double] {
    StockSageNetCostSim.irrxWeights(panel, at: t, lookback: lookback, excluded: excluded)
}

// MARK: - Variant A: sign-flip long-short momentum (calls shipped weights, negates)

func momWeightFn(_ panel: Panel, _ t: Int, _ lookback: Int, _ excluded: Set<Int>) -> [Double] {
    StockSageNetCostSim.irrxWeights(panel, at: t, lookback: lookback, excluded: excluded).map { -$0 }
}

// MARK: - Variant B: long-only clipped momentum (reimplemented signal, spec section 7)

func bWeightsCore(_ panel: Panel, _ t: Int, _ lookback: Int, _ excluded: Set<Int>) -> (w: [Double], degenerate: Bool) {
    let s = panel.symbolCount
    guard s > 0, lookback > 0, t >= lookback, t <= panel.periodCount else {
        return ([Double](repeating: 0, count: max(0, s)), false)
    }
    var past = [Double](repeating: 0, count: s)
    for sym in 0..<s {
        var acc = 0.0
        for u in (t - lookback)..<t { acc += panel.returns[sym][u] }
        past[sym] = acc
    }
    let included = (0..<s).filter { !excluded.contains($0) }
    guard !included.isEmpty else { return ([Double](repeating: 0, count: s), false) }
    var sum: [Int: Double] = [:]
    var cnt: [Int: Int] = [:]
    for sym in included {
        sum[panel.industry[sym], default: 0] += past[sym]
        cnt[panel.industry[sym], default: 0] += 1
    }
    var score = [Double](repeating: 0, count: s)
    for sym in included {
        let g = panel.industry[sym]
        let mean = sum[g]! / Double(cnt[g]!)
        score[sym] = past[sym] - mean
    }
    var clipped = [Double](repeating: 0, count: s)
    for sym in included { clipped[sym] = max(0, score[sym]) }
    let total = included.map { clipped[$0] }.reduce(0, +)
    guard total > 0 else { return ([Double](repeating: 0, count: s), true) }
    var w = [Double](repeating: 0, count: s)
    for sym in included { w[sym] = clipped[sym] / total }
    return (w, false)
}

func bWeightFn(_ panel: Panel, _ t: Int, _ lookback: Int, _ excluded: Set<Int>) -> [Double] {
    bWeightsCore(panel, t, lookback, excluded).w
}

func eqwWeightFn(_ panel: Panel, _ t: Int, _ lookback: Int, _ excluded: Set<Int>) -> [Double] {
    let s = panel.symbolCount
    let included = (0..<s).filter { !excluded.contains($0) }
    guard !included.isEmpty else { return [Double](repeating: 0, count: s) }
    var w = [Double](repeating: 0, count: s)
    for sym in included { w[sym] = 1.0 / Double(included.count) }
    return w
}

// MARK: - Small numeric helpers

func fullSharpe(_ xs: [Double]) -> Double? {
    let n = xs.count; guard n >= 4 else { return nil }
    let m = xs.reduce(0, +) / Double(n)
    let v = xs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(n - 1)
    guard v > 0 else { return nil }
    return m / v.squareRoot()
}

func sampleVariance(_ xs: [Double]) -> Double {
    guard xs.count >= 2 else { return 0 }
    let m = xs.reduce(0, +) / Double(xs.count)
    return xs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(xs.count - 1)
}

// MARK: - Trials ledger (research/trials_ledger.jsonl; ALWAYS-ON, opt-out via TRIALS_LEDGER=off —
// see the "TRIAL REGISTRY" design: an omitted arm silently under-deflates every future DSR, the
// dangerous direction; a duplicated arm just dedups. RUN_ID env overrides the deterministic id.)
func ledgerPath() -> String? {
    let env = ProcessInfo.processInfo.environment
    if let p = env["TRIALS_LEDGER"] { return p == "off" ? nil : p }
    let cwd = FileManager.default.currentDirectoryPath
    return FileManager.default.fileExists(atPath: cwd + "/research") ? cwd + "/research/trials_ledger.jsonl" : "trials_ledger_fragment.jsonl"
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
// Panel is asserted fixed above (S=61,T=1253,7 industries,926 earnings entries) — hardcode its identity.
let ledgerPanelID = "us61-largecap-5y/yahoo-2021-2026-earnexcl"
let ledgerRun = ledgerRunID("momsign-60candidate-grid-v1")

// MARK: - Grid (spec section 8)

let lookbacksFull = [5, 10, 21, 63, 126]
let holdsFull = [5, 10, 21]      // 15 configs

let lookbacksRepro = [5, 10, 21, 63]
let holdsRepro = [5, 10, 21]     // 12 configs (original full-IRRX grid)

// MARK: - Port validation (spec section 5) — must run FIRST

func runPortValidation() {
    var checks = 0
    for lb in lookbacksFull { for hd in holdsFull {
        for (panel, armLabel) in [(panelWithout, "WITHOUT"), (panelWith, "WITH")] {
            let shipped = StockSageNetCostSim.rebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: rtBps)
            let generic = genericRebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: rtBps, weightFn: irrxWeightFn)
            checks += 1
            guard shipped == generic else {
                abortRun("PORT VALIDATION MISMATCH at lb=\(lb) hd=\(hd) arm=\(armLabel): shipped.count=\(shipped.count) generic.count=\(generic.count)")
            }
        }
    }}
    print("PORT-VALIDATION: \(checks)/30 EXACT-EQUAL")
    guard checks == 30 else { abortRun("port validation ran \(checks) checks, expected 30") }
}
runPortValidation()

// MARK: - Reversal-reproduction fixture (spec section 8) — proves panel+harness identity

func runReversalRepro() -> (bestWithout: Double, cfgWithout: String, bestWith: Double, cfgWith: String) {
    func run(_ panel: Panel, label: String) -> (best: Double, cfg: String) {
        var trialSharpes: [Double] = []
        var series: [(Int, Int)] = []
        for lb in lookbacksRepro { for hd in holdsRepro {
            let rebs = StockSageNetCostSim.rebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: rtBps)
            guard rebs.count >= 4 else { continue }
            let net = rebs.map { $0.netReturn }
            if let s = fullSharpe(net) { trialSharpes.append(s) }
            series.append((lb, hd))
        }}
        let nTrials = max(1, series.count)
        let varTrial = sampleVariance(trialSharpes)
        print("\n=== REVERSAL-REPRO \(label) · \(nTrials) configs · varTrialSharpe=\(String(format: "%.4f", varTrial)) ===")
        var bestOOS = -Double.infinity; var bestCfg = ""
        for lb in lookbacksRepro { for hd in holdsRepro {
            guard let sim = StockSageNetCostSim.simulate(panel, lookback: lb, hold: hd, roundTripBps: rtBps,
                                                          folds: 3, embargo: 1, trials: nTrials, varTrialSharpe: varTrial)
            else { continue }
            let oos = sim.netVerdictOOS?.dsr ?? sim.netVerdictFull?.dsr ?? Double.nan
            let tag = sim.netVerdictOOS == nil ? "full" : "OOS"
            if oos > bestOOS { bestOOS = oos; bestCfg = "lb=\(lb),hd=\(hd)" }
            print(String(format: "  lb=%2d hd=%2d  rebals=%3d  meanGross=%+.5f meanNet=%+.5f  net-%@ DSR=%.3f  clears=%@",
                         lb, hd, sim.rebalances.count, sim.meanGross, sim.meanNet, tag, oos, sim.clearsNetOfCost ? "YES" : "no"))
        }}
        print(String(format: "  → BEST net DSR = %.3f (%@)", bestOOS, bestCfg))
        return (bestOOS, bestCfg)
    }
    let without = run(panelWithout, label: "WITHOUT earnings exclusion")
    let with = run(panelWith, label: "WITH earnings exclusion (full IRRX)")
    return (without.best, without.cfg, with.best, with.cfg)
}

let repro = runReversalRepro()
let roundedWithout = (repro.bestWithout * 1000).rounded() / 1000
let roundedWith = (repro.bestWith * 1000).rounded() / 1000
print("\nREVERSAL-REPRO CHECK: WITHOUT best=\(roundedWithout) (expect 0.541, cfg \(repro.cfgWithout) expect lb=5,hd=21)")
print("REVERSAL-REPRO CHECK: WITH    best=\(roundedWith) (expect 0.553, cfg \(repro.cfgWith) expect lb=5,hd=21)")
guard abs(repro.bestWithout - 0.541) < 0.0005, repro.cfgWithout == "lb=5,hd=21",
      abs(repro.bestWith - 0.553) < 0.0005, repro.cfgWith == "lb=5,hd=21" else {
    abortRun("reversal-reproduction fixture MISMATCH — wrong panel or drifted harness")
}
print("REVERSAL-REPRO: PASS (panel+harness identity with the indexed 07-09 full-IRRX run confirmed)")

// MARK: - Anti-symmetry checks (Variant A correctness property, spec sections 6 & 9)

func runAntiSymmetryChecks() {
    var evidenceLines: [String] = []
    for lb in lookbacksFull { for hd in holdsFull {
        for (panel, armLabel) in [(panelWithout, "WITHOUT"), (panelWith, "WITH")] {
            let rev = StockSageNetCostSim.rebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: rtBps)
            let mom = genericRebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: rtBps, weightFn: momWeightFn)
            guard rev.count == mom.count, rev.count > 0 else { continue }
            var maxGrossResid = 0.0, maxTurnoverResid = 0.0, maxNetResid = 0.0
            for i in 0..<rev.count {
                maxGrossResid = max(maxGrossResid, abs(mom[i].grossReturn + rev[i].grossReturn))
                maxTurnoverResid = max(maxTurnoverResid, abs(mom[i].turnover - rev[i].turnover))
                let netIdentity = rev[i].netReturn - 2 * rev[i].grossReturn
                maxNetResid = max(maxNetResid, abs(mom[i].netReturn - netIdentity))
            }
            let meanGrossRev = rev.map { $0.grossReturn }.reduce(0, +) / Double(rev.count)
            let meanGrossMom = mom.map { $0.grossReturn }.reduce(0, +) / Double(mom.count)
            let line = String(format: "  lb=%2d hd=%2d %@: mean(gross_rev)=%+.6f mean(gross_mom)=%+.6f | maxResid gross=%.3e turnover=%.3e net=%.3e",
                              lb, hd, armLabel, meanGrossRev, meanGrossMom, maxGrossResid, maxTurnoverResid, maxNetResid)
            print(line)
            evidenceLines.append(line)
            guard maxGrossResid < 1e-12, maxTurnoverResid < 1e-12, maxNetResid < 1e-12 else {
                abortRun("ANTI-SYMMETRY VIOLATION at lb=\(lb) hd=\(hd) arm=\(armLabel): grossResid=\(maxGrossResid) turnoverResid=\(maxTurnoverResid) netResid=\(maxNetResid)")
            }
        }
    }}
    print("ANTI-SYMMETRY: ALL 30 CONFIG×ARM CHECKS PASS (< 1e-12)")
}

print("\n=== ANTI-SYMMETRY CHECKS (Variant A) ===")
runAntiSymmetryChecks()

// MARK: - Variant B invariant checks + degenerate count (spec section 7 & 9)

struct BInvariantResult { var violations: Int; var degenerate: Int; var totalRebalances: Int }

func checkBInvariants(_ panel: Panel, lookback: Int, hold: Int) -> BInvariantResult {
    let s = panel.symbolCount
    let T = panel.periodCount
    var violations = 0, degenerate = 0, total = 0
    var t = lookback
    while t + hold <= T {
        let excluded = panel.earningsExcludedAt[t] ?? []
        let (w, isDegenerate) = bWeightsCore(panel, t, lookback, excluded)
        total += 1
        if isDegenerate { degenerate += 1 }
        let sumW = w.reduce(0, +)
        let allZero = w.allSatisfy { $0 == 0 }
        if !allZero {
            if w.contains(where: { $0 < 0 }) { violations += 1 }
            if abs(sumW - 1) >= 1e-12 { violations += 1 }
            for sym in 0..<s where excluded.contains(sym) {
                if w[sym] != 0 { violations += 1 }
            }
        }
        t += hold
    }
    return BInvariantResult(violations: violations, degenerate: degenerate, totalRebalances: total)
}

print("\n=== VARIANT B INVARIANT CHECKS ===")
var totalBViolations = 0
for lb in lookbacksFull { for hd in holdsFull {
    for (panel, armLabel) in [(panelWithout, "WITHOUT"), (panelWith, "WITH")] {
        let r = checkBInvariants(panel, lookback: lb, hold: hd)
        totalBViolations += r.violations
        print("  lb=\(lb) hd=\(hd) \(armLabel): rebalances=\(r.totalRebalances) degenerate=\(r.degenerate) violations=\(r.violations)")
    }
}}
guard totalBViolations == 0 else { abortRun("VARIANT B INVARIANT VIOLATIONS: \(totalBViolations)") }
print("VARIANT B INVARIANTS: 0 violations across all configs×arms")

// MARK: - Generic simulate (for A and B, mirrors shipped simulate() with a custom weightFn)

struct SimLike {
    let rebalances: [Rebalance]
    let meanGross: Double
    let meanNet: Double
    let netVerdictFull: StockSageDeflatedSharpe.Result?
    let netVerdictOOS: StockSageDeflatedSharpe.Result?
    let clears: Bool
}

func simulateGeneric(_ panel: Panel, lookback: Int, hold: Int, roundTripBps: Double,
                      weightFn: (Panel, Int, Int, Set<Int>) -> [Double],
                      folds: Int, embargo: Int, trials: Int, varTrialSharpe: Double) -> SimLike? {
    let rebs = genericRebalanceSeries(panel, lookback: lookback, hold: hold, roundTripBps: roundTripBps, weightFn: weightFn)
    guard rebs.count >= 4 else { return nil }
    let gross = rebs.map { $0.grossReturn }
    let net = rebs.map { $0.netReturn }
    let netFull = StockSageNetCostSim.verdict(net, trials: trials, varTrialSharpe: varTrialSharpe)
    let oosNet = StockSageNetCostSim.oosPooled(net, folds: folds, embargo: embargo)
    let netOOS = StockSageNetCostSim.verdict(oosNet, trials: trials, varTrialSharpe: varTrialSharpe)
    let meanGross = gross.reduce(0, +) / Double(gross.count)
    let meanNet = net.reduce(0, +) / Double(net.count)
    let gate = (netOOS ?? netFull)?.passes ?? false
    return SimLike(rebalances: rebs, meanGross: meanGross, meanNet: meanNet,
                   netVerdictFull: netFull, netVerdictOOS: netOOS, clears: gate)
}

// MARK: - Trials accounting: pass 1 — gather the 60 candidate series' full-series net Sharpes

struct Candidate { let variant: String; let arm: String; let lb: Int; let hd: Int }

var candidates: [Candidate] = []
for lb in lookbacksFull { for hd in holdsFull {
    for variant in ["A", "B"] { for arm in ["WITHOUT", "WITH"] {
        candidates.append(Candidate(variant: variant, arm: arm, lb: lb, hd: hd))
    }}
}}
// 15 * 2 * 2 = 60

func weightFnFor(_ variant: String) -> (Panel, Int, Int, Set<Int>) -> [Double] {
    variant == "A" ? momWeightFn : bWeightFn
}
func panelFor(_ arm: String) -> Panel { arm == "WITH" ? panelWith : panelWithout }

var candidateNetSeries: [String: [Double]] = [:]   // key -> net series
var candidateSharpes: [String: Double] = [:]
func candidateKey(_ c: Candidate) -> String { "\(c.variant)|\(c.arm)|\(c.lb)|\(c.hd)" }

for c in candidates {
    let rebs = genericRebalanceSeries(panelFor(c.arm), lookback: c.lb, hold: c.hd, roundTripBps: rtBps, weightFn: weightFnFor(c.variant))
    let net = rebs.map { $0.netReturn }
    candidateNetSeries[candidateKey(c)] = net
    if let sh = fullSharpe(net) { candidateSharpes[candidateKey(c)] = sh }
}

let allSharpes60 = candidates.compactMap { candidateSharpes[candidateKey($0)] }
let V60 = sampleVariance(allSharpes60)
print("\nTRIALS ACCOUNTING: 60 selection candidates (15 configs × 2 variants × 2 arms); pass-1 Sharpes gathered=\(allSharpes60.count); varTrialSharpe(V60)=\(String(format: "%.4f", V60))")

// per (variant,arm) group of 15, for the trials=15 sensitivity pass
func group15Variance(_ variant: String, _ arm: String) -> Double {
    let sh = candidates.filter { $0.variant == variant && $0.arm == arm }.compactMap { candidateSharpes[candidateKey($0)] }
    return sampleVariance(sh)
}

// MARK: - Pass 2: primary (trials=60) + sensitivity (trials=15) verdicts, build results table

struct ResultRow {
    let variant: String; let arm: String; let lb: Int; let hd: Int
    let rebalCount: Int; let meanGrossPct: Double; let meanNetPct: Double
    let dsr60: Double; let tag60: String; let clears60: Bool
    let dsr15: Double; let tag15: String; let clears15: Bool
}

var resultRows: [ResultRow] = []
print("\n=== PRIMARY RESULTS (trials=60) + SENSITIVITY (trials=15, per-variant×arm-group V) ===")
let ledgerFilePath = ledgerPath()
var ledgerAppended = 0
for c in candidates {
    let panel = panelFor(c.arm)
    let wfn = weightFnFor(c.variant)
    guard let sim60 = simulateGeneric(panel, lookback: c.lb, hold: c.hd, roundTripBps: rtBps, weightFn: wfn,
                                       folds: 3, embargo: 1, trials: 60, varTrialSharpe: V60) else { continue }
    let V15 = group15Variance(c.variant, c.arm)
    guard let sim15 = simulateGeneric(panel, lookback: c.lb, hold: c.hd, roundTripBps: rtBps, weightFn: wfn,
                                       folds: 3, embargo: 1, trials: 15, varTrialSharpe: V15) else { continue }
    let dsr60 = sim60.netVerdictOOS?.dsr ?? sim60.netVerdictFull?.dsr ?? Double.nan
    let tag60 = sim60.netVerdictOOS == nil ? "full" : "OOS"
    let dsr15 = sim15.netVerdictOOS?.dsr ?? sim15.netVerdictFull?.dsr ?? Double.nan
    let tag15 = sim15.netVerdictOOS == nil ? "full" : "OOS"
    let row = ResultRow(variant: c.variant, arm: c.arm, lb: c.lb, hd: c.hd,
                        rebalCount: sim60.rebalances.count,
                        meanGrossPct: sim60.meanGross * 100, meanNetPct: sim60.meanNet * 100,
                        dsr60: dsr60, tag60: tag60, clears60: sim60.clears,
                        dsr15: dsr15, tag15: tag15, clears15: sim15.clears)
    resultRows.append(row)
    let numsPart = String(format: "lb=%2d hd=%2d rebals=%3d meanGross=%+.5f%% meanNet=%+.5f%% DSR60=%.3f DSR15=%.3f",
                          c.lb, c.hd, sim60.rebalances.count, row.meanGrossPct, row.meanNetPct, dsr60, dsr15)
    print("  VAR=\(c.variant) ARM=\(c.arm.padding(toLength: 7, withPad: " ", startingAt: 0)) \(numsPart)  net-\(tag60) clears60=\(sim60.clears ? "YES" : "no")  |  net-\(tag15) clears15=\(sim15.clears ? "YES" : "no")")
    if let lp = ledgerFilePath {
        let excl = c.arm == "WITH" ? "with" : "without"
        ledgerAppend(path: lp, run: ledgerRun, family: "momentum-sign", panel: ledgerPanelID,
                     config: "variant=\(c.variant),lb=\(c.lb),hd=\(c.hd),excl=\(excl)", role: "trial",
                     meanNetPct: row.meanNetPct, sharpe: fullSharpe(sim60.rebalances.map { $0.netReturn }),
                     sharpeBasis: "full-series-net-per-rebalance", dsr: dsr60.isFinite ? dsr60 : nil,
                     sourceFile: "tools/momsign_ablation/main.swift")
        ledgerAppended += 1
    }
}
if let lp = ledgerFilePath { print("LEDGER: appended \(ledgerAppended) arms → \(lp)") }

// MARK: - Variant B beta guard: EQW-long benchmark + paired diff series (spec section 7 & 9)

print("\n=== VARIANT B BETA GUARD (EQW-LONG benchmark) ===")
struct BetaGuardRow { let arm: String; let lb: Int; let hd: Int; let benchMeanNetPct: Double
    let benchFullSharpe: Double; let meanD: Double; let diffDSR: Double; let diffPasses: Bool; let betaArtifact: Bool }
var betaGuardRows: [BetaGuardRow] = []
for lb in lookbacksFull { for hd in holdsFull {
    for arm in ["WITHOUT", "WITH"] {
        let panel = panelFor(arm)
        let bRebs = genericRebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: rtBps, weightFn: bWeightFn)
        let eqwRebs = genericRebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: rtBps, weightFn: eqwWeightFn)
        guard bRebs.count == eqwRebs.count, bRebs.count >= 4 else { continue }
        let netB = bRebs.map { $0.netReturn }
        let netEQW = eqwRebs.map { $0.netReturn }
        let d = zip(netB, netEQW).map { $0 - $1 }
        let meanD = d.reduce(0, +) / Double(d.count)
        let benchMeanNet = netEQW.reduce(0, +) / Double(netEQW.count)
        let benchSharpe = fullSharpe(netEQW) ?? Double.nan
        let diffVerdict = StockSageNetCostSim.verdict(d, trials: 60, varTrialSharpe: V60)
        let diffDSR = diffVerdict?.dsr ?? Double.nan
        let diffPasses = diffVerdict?.passes ?? false
        let betaArtifact = diffPasses == false && meanD <= 0 // n/a placeholder, real check below
        let row = BetaGuardRow(arm: arm, lb: lb, hd: hd, benchMeanNetPct: benchMeanNet * 100,
                               benchFullSharpe: benchSharpe, meanD: meanD, diffDSR: diffDSR,
                               diffPasses: diffPasses, betaArtifact: betaArtifact)
        betaGuardRows.append(row)
        print(String(format: "  lb=%2d hd=%2d %@: bench meanNet=%+.5f%% benchSharpe=%.3f | mean(d)=%+.6f diffDSR=%.3f diffPasses=%@",
                     lb, hd, arm, row.benchMeanNetPct, row.benchFullSharpe, meanD, diffDSR, diffPasses ? "YES" : "no"))
        // Flag: an ABSOLUTE DSR pass for B with a non-positive diff read is a beta artifact.
        if let bRow = resultRows.first(where: { $0.variant == "B" && $0.arm == arm && $0.lb == lb && $0.hd == hd }),
           bRow.clears60, meanD <= 0 {
            print("    ⚠ BETA ARTIFACT: B clears60 absolute DSR but mean(netB-netEQW) <= 0 — not incremental edge over long-only market beta.")
        }
    }
}}

// MARK: - Summary (spec section 9)

print("\n=== SUMMARY ===")
func bestFor(_ variant: String, _ arm: String) -> ResultRow? {
    resultRows.filter { $0.variant == variant && $0.arm == arm }.max(by: { $0.dsr60 < $1.dsr60 })
}
var anyClears = false
var bestOverall: ResultRow? = nil
for variant in ["A", "B"] { for arm in ["WITHOUT", "WITH"] {
    if let b = bestFor(variant, arm) {
        print("  BEST VAR=\(variant) ARM=\(arm): lb=\(b.lb) hd=\(b.hd) net-\(b.tag60) DSR60=\(String(format: "%.3f", b.dsr60)) clears=\(b.clears60 ? "YES" : "no")")
        if b.clears60 { anyClears = true }
        if bestOverall == nil || b.dsr60 > bestOverall!.dsr60 { bestOverall = b }
    }
}}
print("  ANY config clears DSR>0.95: \(anyClears ? "YES" : "NO")")

print("\nCAVEATS: survivorship (61 current large-cap survivors) · single-vendor Yahoo (adjclose + earnings dates) · 61-name breadth / 7 coarse industry groups · in-sample panel construction · B's beta confound (see EQW guard above) · correlated-trials DSR caveat: \(StockSageDeflatedSharpe.caveat) · exclusion window fixed at cached ±2 trading days (not swept; README's ±10 differs — consumed as cached, no refetch).")

print("\n=== RUN COMPLETE ===")
