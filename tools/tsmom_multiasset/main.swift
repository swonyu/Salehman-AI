import Foundation
import CryptoKit

// TSMOM multi-asset ablation (arms LF/LS/VS × lb × hold × rt) on the frozen 16-ETF/10y panel.
// Links against the SHIPPED StockSageNetCostSim + StockSageDeflatedSharpe (compiled from their
// repo paths, never copied — see build_and_run.sh). Only TWO pieces of logic are reimplemented:
// the generic weight-fn rebalance loop (byte-for-byte the shipped rebalanceSeries statement
// order, port-validated bit-exact below) and the TSMOM weight rules (sign byte-equivalent to the
// shipped StockSageIndicators.timeSeriesMomentum/trendOK by the price-ratio ≡ Π(1+r) identity).
// Architecture cloned from tools/momsign_ablation/main.swift (2026-07-09 precedent) + the
// REVERSED walk-backward mode from tools/altdata_ablation/main.swift.

func abortRun(_ msg: String) -> Never {
    FileHandle.standardError.write(("ABORT: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

// MARK: - SplitMix64 + Box-Muller (deterministic seeded Gaussian — verbatim momsign)

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

// MARK: - Panel JSON (tsmom shape: assetClass strings instead of industry ints; no earnings)

struct PanelJSON: Decodable {
    let frozenAt: String?
    let labels: [String]
    let assetClass: [String]
    let returns: [[Double]]
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "panel_tsmom_multiasset.json"
guard let data = FileManager.default.contents(atPath: path),
      let pj = try? JSONDecoder().decode(PanelJSON.self, from: data) else {
    abortRun("cannot load/decode \(path)")
}

// MARK: - Panel sanity asserts (universe FROZEN 2026-07-09 before data was seen)

let S = pj.returns.count
let T = pj.returns.first?.count ?? 0
let classNames = Array(Set(pj.assetClass)).sorted()
let classCode = Dictionary(uniqueKeysWithValues: classNames.enumerated().map { ($1, $0) })
let industry = pj.assetClass.map { classCode[$0]! }
let labelsHead = Array(pj.labels.prefix(8))
let expectedLabelsHead = ["SPY", "QQQ", "IWM", "EFA", "EEM", "TLT", "IEF", "LQD"]

print("PANEL ASSERTS:")
print("  symbolCount=\(S) (expect 16)")
print("  periodCount=\(T) (expect 2512)")
print("  assetClass distinct=\(classNames.count) (expect 6): \(classNames)")
print("  labels[:8]=\(labelsHead) (expect \(expectedLabelsHead))")
print("  frozenAt=\(pj.frozenAt ?? "nil") (expect 2026-07-09)")

guard S == 16, T == 2512, classNames.count == 6, labelsHead == expectedLabelsHead,
      pj.assetClass.count == 16, pj.frozenAt == "2026-07-09" else {
    abortRun("panel sanity assert FAILED — wrong panel or drifted harness")
}
print("PANEL ASSERTS: ALL PASS")

let panel = StockSageNetCostSim.Panel(returns: pj.returns, industry: industry, earningsExcludedAt: [:])

// MARK: - DSR-responsiveness preflight (verbatim momsign)

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

// MARK: - Generic weight-fn rebalance loop (verbatim momsign — byte-for-byte the shipped
// rebalanceSeries statement order, parameterized on the weight function)

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

// MARK: - TSMOM signal + arms (the reimplemented logic under test)

// The shipped 12-1 skip (StockSageIndicators.timeSeriesMomentum skipRecent default). Env
// TSMOM_SKIP overrides for the PRE-REGISTERED no-skip variant (PREREG_2026-07-09_noskip.md);
// default 21 keeps every print byte-identical to the parent run.
let SKIP = Int(ProcessInfo.processInfo.environment["TSMOM_SKIP"] ?? "") ?? 21
// Trials-accounting overrides for data-suggested variants: the variant must pay for the parent
// run's selection too (trials pooled across runs; varTrialSharpe precomputed over the union).
let TRIALS_PRIMARY = Int(ProcessInfo.processInfo.environment["TSMOM_TRIALS"] ?? "") ?? 54
let VARTRIAL_OVERRIDE = Double(ProcessInfo.processInfo.environment["TSMOM_VARTRIAL"] ?? "")

/// Cumulative simple return over u ∈ [t−lb, t−skip) — by Π(1+r) = P_end/P_start this is EXACTLY
/// the shipped price-ratio timeSeriesMomentum anchored at "now" = t (closes index n−1 = t:
/// startIdx = t−lb, endIdx = t−skip). Data strictly < t: no look-ahead.
func tsmom(_ panel: Panel, _ sym: Int, _ t: Int, _ lb: Int) -> Double? {
    guard lb > SKIP, t >= lb else { return nil }
    var acc = 1.0
    for u in (t - lb)..<(t - SKIP) { acc *= (1.0 + panel.returns[sym][u]) }
    return acc - 1.0
}

/// Trailing-63d realized vol, annualized (√252 · sample sd), data strictly < t.
func trailingVol63(_ panel: Panel, _ sym: Int, _ t: Int) -> Double? {
    let w = 63
    guard t >= w else { return nil }
    var xs = [Double]()
    xs.reserveCapacity(w)
    for u in (t - w)..<t { xs.append(panel.returns[sym][u]) }
    let m = xs.reduce(0, +) / Double(w)
    let v = xs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(w - 1)
    guard v > 0 else { return nil }
    return (v * 252.0).squareRoot()
}

/// Arm LF — long/flat, the shipped trendOK filter semantics: fixed 1/S slots so the book
/// de-levers in downtrends (the crash-filter mechanism under test; renormalizing to the
/// trending subset would fake constant exposure and confound the timing claim).
func lfWeightFn(_ lb: Int) -> (Panel, Int, Int, Set<Int>) -> [Double] {
    { panel, t, _, _ in
        let s = panel.symbolCount
        var w = [Double](repeating: 0, count: s)
        for sym in 0..<s {
            if let m = tsmom(panel, sym, t, lb), m > 0 { w[sym] = 1.0 / Double(s) }
        }
        return w
    }
}

/// Arm LS — long-short sign. Short borrow/financing NOT charged (disclosed gross-favorable:
/// if it fails without borrow it certainly fails with).
func lsWeightFn(_ lb: Int) -> (Panel, Int, Int, Set<Int>) -> [Double] {
    { panel, t, _, _ in
        let s = panel.symbolCount
        var w = [Double](repeating: 0, count: s)
        for sym in 0..<s {
            if let m = tsmom(panel, sym, t, lb) {
                if m > 0 { w[sym] = 1.0 / Double(s) } else if m < 0 { w[sym] = -1.0 / Double(s) }
            }
        }
        return w
    }
}

/// Arm VS — MOP-faithful vol-scaled long-short: sign · min(cap=2, 0.40/σ63) / S.
func vsWeightFn(_ lb: Int) -> (Panel, Int, Int, Set<Int>) -> [Double] {
    { panel, t, _, _ in
        let s = panel.symbolCount
        var w = [Double](repeating: 0, count: s)
        for sym in 0..<s {
            guard let m = tsmom(panel, sym, t, lb), m != 0 else { continue }
            let scale: Double
            if let vol = trailingVol63(panel, sym, t) { scale = min(2.0, 0.40 / vol) } else { scale = 2.0 }
            w[sym] = (m > 0 ? 1.0 : -1.0) * scale / Double(s)
        }
        return w
    }
}

/// EQW always-long benchmark (constant 1/S — zero turnover after the first rebalance).
func eqwWeightFn(_ panel: Panel, _ t: Int, _ lookback: Int, _ excluded: Set<Int>) -> [Double] {
    [Double](repeating: 1.0 / Double(panel.symbolCount), count: panel.symbolCount)
}

// MARK: - Small numeric helpers (verbatim momsign)

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

// MARK: - Trials ledger (verbatim momsign helpers)

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
let ledgerPanelID = "etf16-multiasset-10y/yahoo-2016-2026"
let ledgerRun = ledgerRunID("tsmom-multiasset-54grid-v1")

// MARK: - Grid

let lookbacks = [63, 126, 252]
let holds = [21, 42, 63]
let rtLegs: [Double] = [13.0, 8.0]   // primary shipped bare-US tier; TOM-precedent ETF sensitivity
let arms = ["LF", "LS", "VS"]

func weightFnFor(_ arm: String, _ lb: Int) -> (Panel, Int, Int, Set<Int>) -> [Double] {
    switch arm {
    case "LF": return lfWeightFn(lb)
    case "LS": return lsWeightFn(lb)
    default:   return vsWeightFn(lb)
    }
}

// MARK: - Port validation (must run FIRST): generic loop vs shipped rebalanceSeries with the
// shipped irrxWeights on THIS panel — proves the loop is bit-exact before any TSMOM number.

func runPortValidation() {
    var checks = 0
    for lb in lookbacks { for hd in holds {
        let shipped = StockSageNetCostSim.rebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: 13.0)
        let generic = genericRebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: 13.0, weightFn: irrxWeightFn)
        checks += 1
        guard shipped == generic else {
            abortRun("PORT VALIDATION MISMATCH at lb=\(lb) hd=\(hd): shipped.count=\(shipped.count) generic.count=\(generic.count)")
        }
    }}
    print("PORT-VALIDATION: \(checks)/9 EXACT-EQUAL (generic loop ≡ shipped rebalanceSeries via shipped irrxWeights)")
    guard checks == 9 else { abortRun("port validation ran \(checks) checks, expected 9") }
}
runPortValidation()

// MARK: - Signal spot-check (consumed by the standalone Python hand-derivation)

print("\n=== SIGNAL SPOT-CHECK (t=252, lb=252, skip=\(SKIP) — hand-derive these from the panel JSON) ===")
for sym in [0, 5, 9] {   // SPY, TLT, GLD in the frozen order
    let m = tsmom(panel, sym, 252, 252) ?? Double.nan
    let v = trailingVol63(panel, sym, 252) ?? Double.nan
    print(String(format: "  SPOTCHECK sym=%@ mom=%.10f vol63=%.10f", pj.labels[sym], m, v))
}

// MARK: - Trials accounting: pass 1 — the 54 candidate series' full-series net Sharpes

struct Candidate { let arm: String; let lb: Int; let hd: Int; let rt: Double }
var candidates: [Candidate] = []
for arm in arms { for lb in lookbacks { for hd in holds { for rt in rtLegs {
    candidates.append(Candidate(arm: arm, lb: lb, hd: hd, rt: rt))
}}}}
// 3 × 3 × 3 × 2 = 54

func candidateKey(_ c: Candidate) -> String { "\(c.arm)|\(c.lb)|\(c.hd)|\(Int(c.rt))" }

var candidateSharpes: [String: Double] = [:]
for c in candidates {
    let rebs = genericRebalanceSeries(panel, lookback: c.lb, hold: c.hd, roundTripBps: c.rt, weightFn: weightFnFor(c.arm, c.lb))
    if let sh = fullSharpe(rebs.map { $0.netReturn }) { candidateSharpes[candidateKey(c)] = sh }
}
let allSharpes54 = candidates.compactMap { candidateSharpes[candidateKey($0)] }
let V54 = sampleVariance(allSharpes54)
print("\nTRIALS ACCOUNTING: 54 selection candidates (3 arms × 3 lb × 3 hd × 2 rt); pass-1 Sharpes gathered=\(allSharpes54.count); varTrialSharpe(V54)=\(String(format: "%.4f", V54))")

func rtLegVariance(_ rt: Double) -> Double {
    sampleVariance(candidates.filter { $0.rt == rt }.compactMap { candidateSharpes[candidateKey($0)] })
}

// MARK: - Generic simulate (mirrors momsign simulateGeneric)

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

// MARK: - Pass 2: primary (trials=54) + sensitivity (trials=27 per rt leg) + EQW paired-diff
// (the bull-beta trap killer — mandatory since the momentum-sign precedent) + LF exposure.

struct ResultRow {
    let arm: String; let lb: Int; let hd: Int; let rt: Double
    let rebalCount: Int; let meanGrossPct: Double; let meanNetPct: Double; let meanTurnover: Double
    let dsr54: Double; let tag54: String; let clears54: Bool
    let dsr27: Double; let clears27: Bool
    let meanD: Double; let diffDSR: Double; let diffPasses: Bool
    let lfExposure: Double?   // mean Σw for LF (fraction invested) — timing diagnostic
}

var resultRows: [ResultRow] = []
var eqwLedgered = Set<String>()
let ledgerFilePath = ledgerPath()
var ledgerAppended = 0

let vPrimary = (VARTRIAL_OVERRIDE?.isFinite == true) ? VARTRIAL_OVERRIDE! : V54
if TRIALS_PRIMARY != 54 || VARTRIAL_OVERRIDE != nil {
    print("TRIALS OVERRIDE (pre-registered variant accounting): trials=\(TRIALS_PRIMARY), varTrialSharpe=\(String(format: "%.4f", vPrimary)) (pooled across runs per PREREG)")
}
print("\n=== PRIMARY RESULTS (trials=\(TRIALS_PRIMARY)) + SENSITIVITY (trials=27/rt-leg) + EQW PAIRED-DIFF ===")
for c in candidates {
    let wfn = weightFnFor(c.arm, c.lb)
    guard let sim54 = simulateGeneric(panel, lookback: c.lb, hold: c.hd, roundTripBps: c.rt, weightFn: wfn,
                                       folds: 3, embargo: 1, trials: TRIALS_PRIMARY, varTrialSharpe: vPrimary) else { continue }
    let V27 = rtLegVariance(c.rt)
    guard let sim27 = simulateGeneric(panel, lookback: c.lb, hold: c.hd, roundTripBps: c.rt, weightFn: wfn,
                                       folds: 3, embargo: 1, trials: 27, varTrialSharpe: V27) else { continue }

    // EQW benchmark on the SAME rebalance grid (same lb/hd/rt).
    let eqwRebs = genericRebalanceSeries(panel, lookback: c.lb, hold: c.hd, roundTripBps: c.rt, weightFn: eqwWeightFn)
    let netArm = sim54.rebalances.map { $0.netReturn }
    let netEQW = eqwRebs.map { $0.netReturn }
    guard netArm.count == netEQW.count, netArm.count >= 4 else { continue }
    let d = zip(netArm, netEQW).map { $0 - $1 }
    let meanD = d.reduce(0, +) / Double(d.count)
    let diffVerdict = StockSageNetCostSim.verdict(d, trials: TRIALS_PRIMARY, varTrialSharpe: vPrimary)
    let diffDSR = diffVerdict?.dsr ?? Double.nan
    let diffPasses = diffVerdict?.passes ?? false

    // LF exposure diagnostic: mean fraction invested (Σw) across rebalances.
    var lfExposure: Double? = nil
    if c.arm == "LF" {
        var totalW = 0.0
        var t = c.lb
        var count = 0
        while t + c.hd <= panel.periodCount {
            totalW += wfn(panel, t, c.lb, []).reduce(0, +)
            count += 1
            t += c.hd
        }
        if count > 0 { lfExposure = totalW / Double(count) }
    }

    let dsr54v = sim54.netVerdictOOS?.dsr ?? sim54.netVerdictFull?.dsr ?? Double.nan
    let tag54 = sim54.netVerdictOOS == nil ? "full" : "OOS"
    let dsr27v = sim27.netVerdictOOS?.dsr ?? sim27.netVerdictFull?.dsr ?? Double.nan
    let meanTurn = sim54.rebalances.map { $0.turnover }.reduce(0, +) / Double(sim54.rebalances.count)

    let row = ResultRow(arm: c.arm, lb: c.lb, hd: c.hd, rt: c.rt,
                        rebalCount: sim54.rebalances.count,
                        meanGrossPct: sim54.meanGross * 100, meanNetPct: sim54.meanNet * 100, meanTurnover: meanTurn,
                        dsr54: dsr54v, tag54: tag54, clears54: sim54.clears,
                        dsr27: dsr27v, clears27: sim27.clears,
                        meanD: meanD, diffDSR: diffDSR, diffPasses: diffPasses,
                        lfExposure: lfExposure)
    resultRows.append(row)
    let expStr = lfExposure.map { String(format: " exp=%.2f", $0) } ?? ""
    print(String(format: "  ARM=%@ lb=%3d hd=%2d rt=%2.0f rebals=%3d meanGross=%+.5f%% meanNet=%+.5f%% turn=%.3f DSR%d=%.3f(net-%@) clears%d=%@ DSR27=%.3f | EQWdiff mean(d)=%+.6f diffDSR=%.3f diffPasses=%@%@",
                 c.arm, c.lb, c.hd, c.rt, row.rebalCount, row.meanGrossPct, row.meanNetPct, meanTurn,
                 TRIALS_PRIMARY, dsr54v, tag54, TRIALS_PRIMARY, sim54.clears ? "YES" : "no", dsr27v, meanD, diffDSR, diffPasses ? "YES" : "no", expStr))
    if sim54.clears && meanD <= 0 {
        print("    ⚠ BETA ARTIFACT: clears\(TRIALS_PRIMARY) absolute DSR but mean(netArm-netEQW) <= 0 — not incremental edge over always-long beta.")
    }

    if let lp = ledgerFilePath {
        let skipSuffix = SKIP == 21 ? "" : ",skip=\(SKIP)"
        ledgerAppend(path: lp, run: ledgerRun, family: "tsmom-multiasset", panel: ledgerPanelID,
                     config: "arm=\(c.arm),lb=\(c.lb),hd=\(c.hd),rt=\(Int(c.rt))\(skipSuffix)", role: "trial",
                     meanNetPct: row.meanNetPct, sharpe: candidateSharpes[candidateKey(c)],
                     sharpeBasis: "full-series-net-per-rebalance", dsr: dsr54v.isFinite ? dsr54v : nil,
                     sourceFile: "tools/tsmom_multiasset/main.swift")
        ledgerAppended += 1
        // EQW benchmark row once per (lb,hd,rt)
        let ek = "\(c.lb)|\(c.hd)|\(Int(c.rt))"
        if !eqwLedgered.contains(ek) {
            eqwLedgered.insert(ek)
            let eqwDSR = StockSageNetCostSim.verdict(netEQW, trials: 1)?.dsr
            ledgerAppend(path: lp, run: ledgerRun, family: "tsmom-multiasset", panel: ledgerPanelID,
                         config: "arm=EQW,lb=\(c.lb),hd=\(c.hd),rt=\(Int(c.rt))", role: "benchmark",
                         meanNetPct: (netEQW.reduce(0, +) / Double(netEQW.count)) * 100,
                         sharpe: fullSharpe(netEQW), sharpeBasis: "full-series-net-per-rebalance",
                         dsr: eqwDSR, sourceFile: "tools/tsmom_multiasset/main.swift")
            ledgerAppended += 1
        }
    }
}
if let lp = ledgerFilePath { print("LEDGER: appended \(ledgerAppended) arms → \(lp)") }

// MARK: - Registry-informed deflation print (trial-registry standing note: deflate against the
// selection HISTORY, not just this run's arm count — informational, not the primary accounting)

if let best = resultRows.max(by: { $0.dsr54 < $1.dsr54 }) {
    let wfn = weightFnFor(best.arm, best.lb)
    if let simHist = simulateGeneric(panel, lookback: best.lb, hold: best.hd, roundTripBps: best.rt, weightFn: wfn,
                                      folds: 3, embargo: 1, trials: TRIALS_PRIMARY + 308, varTrialSharpe: vPrimary) {
        let d = simHist.netVerdictOOS?.dsr ?? simHist.netVerdictFull?.dsr ?? Double.nan
        print(String(format: "\nREGISTRY-INFORMED (informational): best config ARM=%@ lb=%d hd=%d rt=%.0f at trials=%d (%d + 308 registry census) → DSR=%.3f",
                     best.arm, best.lb, best.hd, best.rt, TRIALS_PRIMARY + 308, TRIALS_PRIMARY, d))
    }
}

// MARK: - REVERSED walk-backward mode (ported from altdata; no earnings keys to remap here)

func reversedPanel(_ p: Panel) -> Panel {
    Panel(returns: p.returns.map { Array($0.reversed()) }, industry: p.industry, earningsExcludedAt: [:])
}

if ProcessInfo.processInfo.environment["REVERSED"] == "1" {
    print("\n=== FLIP-VS-HOLD (REVERSED period axis; rt=13 primary leg) ===")
    let rev = reversedPanel(panel)
    for arm in arms { for lb in lookbacks { for hd in holds {
        let f = genericRebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: 13.0, weightFn: weightFnFor(arm, lb))
        let r = genericRebalanceSeries(rev, lookback: lb, hold: hd, roundTripBps: 13.0, weightFn: weightFnFor(arm, lb))
        guard !f.isEmpty, !r.isEmpty else { continue }
        let fMean = f.map { $0.netReturn }.reduce(0, +) / Double(f.count)
        let rMean = r.map { $0.netReturn }.reduce(0, +) / Double(r.count)
        let flip = (fMean > 0) != (rMean > 0)
        print(String(format: "  ARM=%@ lb=%3d hd=%2d  forward meanNet=%+.5f  reversed meanNet=%+.5f  sign-flip=%@",
                     arm, lb, hd, fMean, rMean, flip ? "YES" : "no"))
    }}}
    print("""

    INTERPRETATION GUIDE (read before trusting any flip above):
      - Reversal breaks real market dynamics — momentum is TIME-DIRECTIONAL, so a reversed-period
        run is not a valid alternate history, only a diagnostic.
      - A sign-flip on an ALREADY-NULL config adds nothing; the meaningful case is a flip on a
        config that clears DSR>0.95 FORWARD (evidence the "edge" was fit to temporal order).
      - This flag exists for FUTURE would-be positives; on a null panel it is inert commentary.
    """)
}

// MARK: - Summary

print("\n=== SUMMARY ===")
var anyClears = false
var anyClearsWithDiff = false
for arm in arms {
    if let b = resultRows.filter({ $0.arm == arm }).max(by: { $0.dsr54 < $1.dsr54 }) {
        print(String(format: "  BEST ARM=%@: lb=%d hd=%d rt=%.0f net-%@ DSR%d=%.3f clears=%@ | EQWdiff diffDSR=%.3f diffPasses=%@",
                     arm, b.lb, b.hd, b.rt, b.tag54, TRIALS_PRIMARY, b.dsr54, b.clears54 ? "YES" : "no", b.diffDSR, b.diffPasses ? "YES" : "no"))
        if b.clears54 { anyClears = true }
        if b.clears54 && b.diffPasses { anyClearsWithDiff = true }
    }
}
print("  ANY config clears DSR>0.95 (absolute): \(anyClears ? "YES" : "NO")")
print("  ANY config clears absolute AND EQW paired-diff: \(anyClearsWithDiff ? "YES" : "NO")")

print("\nCAVEATS: ETF wrappers are survivor-lite proxies for the asset classes (USO roll drag is real holder experience; no delisted ETFs) · single-vendor Yahoo adjclose · 10y window (2016-2026: one cut-and-recover cycle 2020, one slow bear 2022) · LS/VS short legs charge NO borrow/financing (gross-favorable) · VS per-name cap 2× / target 40%/yr per MOP · correlated-trials DSR caveat: \(StockSageDeflatedSharpe.caveat)")

print("\n=== RUN COMPLETE ===")
