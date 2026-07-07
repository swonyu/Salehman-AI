import Foundation

// MARK: - Cap-vs-continuous weekly concentration ablation
//
// Closes research/INDEX.md OPEN FRONTIER "Weekly top-3 concentration mechanics" (2nd/empirical
// exit clause). Does a HARD integer top-N count-cap beat the shipped CONTINUOUS risk-budget
// allocator, net-of-cost, on real data? Compiles the SHIPPED
// StockSageCorrelationCluster.correlationAdjustedWeights + StockSageDeflatedSharpe.deflated/moments
// VERBATIM (this file + those two + StockSagePortfolioAnalytics, which the cluster fn calls
// internally, per the build command). Only the panel load, TSMOM proxy, heat-scale port (ported
// per spec from StockSageCapitalAllocator.allocate lines 114-115 — arithmetic only, not a
// re-implementation of the two gated functions), turnover/cost accounting, and the block-t test
// are written here.
//
// EXPECTED: NULL (no cap beats continuous) closes the axis as a WIN — do not manufacture a positive.

// MARK: Panel

struct PanelJSON: Decodable {
    let symbols: [String]
    let dates: [Int]
    let adjclose: [[Double]]
    let provenance: String?
}

let panelPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "panel.json"
guard let data = FileManager.default.contents(atPath: panelPath),
      let panel = try? JSONDecoder().decode(PanelJSON.self, from: data) else {
    FileHandle.standardError.write("cannot load/decode \(panelPath)\n".data(using: .utf8)!)
    exit(1)
}

let S = panel.symbols.count
let T = panel.adjclose.first?.count ?? 0
guard S == 20, panel.adjclose.allSatisfy({ $0.count == T }), T > 300 else {
    FileHandle.standardError.write("panel shape invalid: S=\(S) T=\(T)\n".data(using: .utf8)!)
    exit(1)
}
// Defensive re-check of the fetch script's sanity gate — STOP, never silently drop a name.
for s in 0..<S {
    var maxAbs = 0.0
    for t in 1..<T {
        let a = panel.adjclose[s][t - 1], b = panel.adjclose[s][t]
        guard a > 0 else { continue }
        maxAbs = max(maxAbs, abs(b / a - 1))
    }
    guard maxAbs < 0.35 else {
        FileHandle.standardError.write("FATAL: \(panel.symbols[s]) max|daily ret|=\(maxAbs) >= 0.35 — split leak, STOPPING\n".data(using: .utf8)!)
        exit(1)
    }
}
print("PANEL: \(S) symbols x \(T) bars (shared calendar)")
if let p = panel.provenance { print("PROVENANCE: \(p)") }

let adj = panel.adjclose   // adj[s][t]
let symbols = panel.symbols

// MARK: TSMOM 12-1 proxy (skip-recent-21, matches the engine's TSMOM skipRecent:21)

func tsmomScore(_ s: Int, _ i: Int) -> Double {
    adj[s][i - 21] / adj[s][i - 252] - 1
}

// MARK: Arms

let capNs = [1, 2, 3, 5]
let armLabels = ["CONTINUOUS"] + capNs.map { "CAP-\($0)" }   // 5 arms, index 0 = CONTINUOUS

let w0 = 0.02
let heatCap = 0.08
let roundTripBps = 13.0
let perUnitTurnoverCost = roundTripBps / 2 / 10_000.0   // PLAN correction (1): 6.5bps one-way, not 13bps

// MARK: Per-decision state — 5 arms x {raw, matched} = 10 independent weight trackers (full 20-vec)

var prevWRaw = [[Double]](repeating: [Double](repeating: 0, count: S), count: armLabels.count)
var prevWMatched = [[Double]](repeating: [Double](repeating: 0, count: S), count: armLabels.count)

var weeklyNetRaw = [[Double]](repeating: [], count: armLabels.count)
var weeklyNetMatched = [[Double]](repeating: [], count: armLabels.count)
var weeklyGrossRaw = [[Double]](repeating: [], count: armLabels.count)
var weeklyTurnoverRaw = [[Double]](repeating: [], count: armLabels.count)
var weeklyExposureRaw = [[Double]](repeating: [], count: armLabels.count)   // diagnostic: deployed heat (sum weight) before matching
var weeklyShortlistCount = [[Int]](repeating: [], count: armLabels.count)  // diagnostic: # names actually held

let lastIndex = T - 1
var t = 252
var nWeeks = 0
while t + 5 <= lastIndex {
    // 1. Score every name, no look-ahead (uses only adj[<=t]).
    var scores = [Double](repeating: -Double.infinity, count: S)
    for s in 0..<S { scores[s] = tsmomScore(s, t) }
    let fundableIdx = (0..<S).filter { scores[$0] > 0 }
    // Deterministic rank: score desc, tie-break symbol asc.
    let ranked = fundableIdx.sorted { a, b in
        if scores[a] != scores[b] { return scores[a] > scores[b] }
        return symbols[a] < symbols[b]
    }

    // 2. Trailing 120-bar daily-return window ending at t, ONLY <=t data (production convention:
    //    StockSagePortfolioAnalytics.dailyReturns on a raw closes slice, same call the shipped
    //    allocator itself uses for its correlation input).
    func trailingReturns(_ s: Int) -> [Double] {
        let lo = max(0, t - 120)
        return StockSagePortfolioAnalytics.dailyReturns(Array(adj[s][lo...t]))
    }

    // 3. Forward weekly return per name (decide at t, hold to t+5, non-overlapping).
    var fwd = [Double](repeating: 0, count: S)
    for s in 0..<S { fwd[s] = adj[s][t + 5] / adj[s][t] - 1 }

    for armIdx in 0..<armLabels.count {
        let shortlist: [Int] = armIdx == 0 ? ranked : Array(ranked.prefix(capNs[armIdx - 1]))

        var wScaledFull = [Double](repeating: 0, count: S)
        if !shortlist.isEmpty {
            let subSymbols = shortlist.map { symbols[$0] }
            let subWeights = [Double](repeating: w0, count: shortlist.count)
            let subReturns = shortlist.map { trailingReturns($0) }
            // VERBATIM shipped function — correlation-de-weight step (allocate() step 2.5).
            let adjWeights = StockSageCorrelationCluster.correlationAdjustedWeights(
                symbols: subSymbols, weights: subWeights, returns: subReturns)
            // Heat-scale, PORTED verbatim from StockSageCapitalAllocator.allocate lines 114-115
            // (arithmetic only — requestedHeat/cap/scaleApplied, not a re-implementation of either
            // gated function above).
            let requestedHeat = adjWeights.reduce(0, +)
            let scaleApplied = requestedHeat > heatCap ? heatCap / requestedHeat : 1.0
            for (k, idx) in shortlist.enumerated() {
                wScaledFull[idx] = adjWeights[k] * scaleApplied
            }
        }

        // RAW variant: as-deployed production answer.
        var turnoverRaw = 0.0
        for s in 0..<S { turnoverRaw += abs(wScaledFull[s] - prevWRaw[armIdx][s]) }
        let costRaw = turnoverRaw * perUnitTurnoverCost
        var grossRaw = 0.0
        for s in 0..<S { grossRaw += wScaledFull[s] * fwd[s] }
        let netRaw = grossRaw - costRaw
        weeklyNetRaw[armIdx].append(netRaw)
        weeklyGrossRaw[armIdx].append(grossRaw)
        weeklyTurnoverRaw[armIdx].append(turnoverRaw)
        weeklyExposureRaw[armIdx].append(wScaledFull.reduce(0, +))
        weeklyShortlistCount[armIdx].append(shortlist.count)
        prevWRaw[armIdx] = wScaledFull

        // MATCHED variant: PRE-REGISTERED exposure-matched amendment — renormalize the SAME
        // post-correlation/post-heat-scale weights to a fixed 0.08 total whenever total>0, then
        // run through the IDENTICAL turnover/cost accounting (its own prevW state).
        let sumScaled = wScaledFull.reduce(0, +)
        var wMatchedFull = [Double](repeating: 0, count: S)
        if sumScaled > 0 {
            let factor = heatCap / sumScaled
            for s in 0..<S { wMatchedFull[s] = wScaledFull[s] * factor }
        }
        var turnoverM = 0.0
        for s in 0..<S { turnoverM += abs(wMatchedFull[s] - prevWMatched[armIdx][s]) }
        let costM = turnoverM * perUnitTurnoverCost
        var grossM = 0.0
        for s in 0..<S { grossM += wMatchedFull[s] * fwd[s] }
        let netM = grossM - costM
        weeklyNetMatched[armIdx].append(netM)
        prevWMatched[armIdx] = wMatchedFull
    }

    nWeeks += 1
    t += 5
}

print("WEEKS: \(nWeeks) non-overlapping rebalances (decide-bar 252 .. \(t - 5), hold +5, calendar last index \(lastIndex))")

// MARK: Per-arm Sharpe (weekly, PER-PERIOD — PLAN correction (2): NOT annualized), DSR

func weeklyStats(_ series: [Double]) -> (mean: Double, sd: Double, sharpe: Double?) {
    let n = series.count
    let mean = series.reduce(0, +) / Double(n)
    guard n > 1 else { return (mean, 0, nil) }
    let variance = series.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(n - 1)
    let sd = variance.squareRoot()
    return (mean, sd, sd > 0 ? mean / sd : nil)
}

struct ArmResult {
    let label: String
    let n: Int
    let weeklySharpe: Double
    let annSharpeDisplay: Double
    let dsr: StockSageDeflatedSharpe.Result?
}

func computeArmResults(_ series: [[Double]], trials: Int) -> [ArmResult] {
    var sharpes: [Double] = []
    for s in series {
        let (_, _, sh) = weeklyStats(s)
        sharpes.append(sh ?? 0)
    }
    let m = sharpes.reduce(0, +) / Double(sharpes.count)
    let varTrial = sharpes.count >= 2
        ? sharpes.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(sharpes.count - 1) : 0
    var out: [ArmResult] = []
    for (i, s) in series.enumerated() {
        let (_, _, shOpt) = weeklyStats(s)
        let sh = shOpt ?? 0
        let n = s.count
        var dsrResult: StockSageDeflatedSharpe.Result? = nil
        if let (skew, kurt) = StockSageDeflatedSharpe.moments(s) {
            // VERBATIM shipped function.
            dsrResult = StockSageDeflatedSharpe.deflated(observedSharpe: sh, nTrades: n,
                                                          skew: skew, kurtosis: kurt,
                                                          trials: trials, varTrialSharpe: varTrial)
        }
        out.append(ArmResult(label: armLabels[i], n: n, weeklySharpe: sh,
                              annSharpeDisplay: sh * 52.0.squareRoot(), dsr: dsrResult))
    }
    return out
}

let trials = armLabels.count   // 5: continuous + 4 cap configs (MINOR recommendation adopted)
let rawArmResults = computeArmResults(weeklyNetRaw, trials: trials)
let matchedArmResults = computeArmResults(weeklyNetMatched, trials: trials)

func printArmTable(_ title: String, _ results: [ArmResult]) {
    print("\n=== \(title) (per-arm weekly net-of-cost stats, trials=\(trials)) ===")
    for r in results {
        let dsrStr = r.dsr.map { String(format: "psr=%.3f dsr=%.3f passes=%@", $0.psr, $0.dsr, $0.passes ? "YES" : "no") } ?? "n/a"
        let paddedLabel = r.label.padding(toLength: 12, withPad: " ", startingAt: 0)
        print("  \(paddedLabel) n=\(String(format: "%4d", r.n)) weeklySharpe=\(String(format: "%+.4f", r.weeklySharpe)) annSharpe(display)=\(String(format: "%+.3f", r.annSharpeDisplay))  \(dsrStr)")
    }
}
printArmTable("RAW (as-deployed)", rawArmResults)
printArmTable("EXPOSURE-MATCHED (renormalized to 0.08 total)", matchedArmResults)

print("\n=== DIAGNOSTIC: mean deployed exposure / turnover / shortlist size per arm (RAW) — sanity check against a mechanical exposure confound ===")
for i in 0..<armLabels.count {
    let meanExp = weeklyExposureRaw[i].reduce(0, +) / Double(weeklyExposureRaw[i].count)
    let meanTurn = weeklyTurnoverRaw[i].reduce(0, +) / Double(weeklyTurnoverRaw[i].count)
    let meanCount = Double(weeklyShortlistCount[i].reduce(0, +)) / Double(weeklyShortlistCount[i].count)
    let meanGross = weeklyGrossRaw[i].reduce(0, +) / Double(weeklyGrossRaw[i].count)
    let paddedLabel = armLabels[i].padding(toLength: 12, withPad: " ", startingAt: 0)
    print("  \(paddedLabel) meanExposure=\(String(format: "%.4f", meanExp)) meanShortlistN=\(String(format: "%.2f", meanCount)) meanTurnover/wk=\(String(format: "%.4f", meanTurn)) meanGrossReturn/wk=\(String(format: "%.5f", meanGross)) meanGross-per-unit-exposure=\(String(format: "%.5f", meanExp > 0 ? meanGross / meanExp : 0))")
}

// MARK: Block-level increment significance (Fama-MacBeth style, blocks of 4 weekly reb ~monthly)

// Regularized incomplete beta (Numerical Recipes betai/betacf) — for the Student-t two-tailed
// p-value. Not a re-implementation of any StockSage engine function; a generic stats primitive
// the shipped code doesn't provide.
func logBeta(_ a: Double, _ b: Double) -> Double { lgamma(a) + lgamma(b) - lgamma(a + b) }

func betacf(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let maxit = 200, eps = 3.0e-16, fpmin = 1.0e-300
    let qab = a + b, qap = a + 1, qam = a - 1
    var c = 1.0
    var d = 1 - qab * x / qap
    if abs(d) < fpmin { d = fpmin }
    d = 1 / d
    var h = d
    for m in 1...maxit {
        let m2 = Double(2 * m)
        var aa = Double(m) * (b - Double(m)) * x / ((qam + m2) * (a + m2))
        d = 1 + aa * d; if abs(d) < fpmin { d = fpmin }
        c = 1 + aa / c; if abs(c) < fpmin { c = fpmin }
        d = 1 / d
        h *= d * c
        aa = -(a + Double(m)) * (qab + Double(m)) * x / ((a + m2) * (qap + m2))
        d = 1 + aa * d; if abs(d) < fpmin { d = fpmin }
        c = 1 + aa / c; if abs(c) < fpmin { c = fpmin }
        d = 1 / d
        let del = d * c
        h *= del
        if abs(del - 1) < eps { break }
    }
    return h
}

func betai(_ a: Double, _ b: Double, _ x: Double) -> Double {
    if x <= 0 { return 0 }
    if x >= 1 { return 1 }
    let bt = exp(-logBeta(a, b) + a * log(x) + b * log(1 - x))
    if x < (a + 1) / (a + b + 2) {
        return bt * betacf(a, b, x) / a
    } else {
        return 1 - bt * betacf(b, a, 1 - x) / b
    }
}

func twoTailedP(t tstat: Double, df: Double) -> Double {
    guard df > 0, tstat.isFinite else { return 1 }
    let x = df / (df + tstat * tstat)
    return min(1, max(0, betai(df / 2, 0.5, x)))
}

struct IncrementResult {
    let label: String
    let meanBps: Double
    let t: Double
    let p: Double
    let blocks: Int
}

func blockIncrement(_ capSeries: [Double], _ contSeries: [Double], label: String) -> IncrementResult {
    let diffs = zip(capSeries, contSeries).map { $0 - $1 }
    let blockSize = 4
    let m = diffs.count / blockSize
    guard m >= 2 else { return IncrementResult(label: label, meanBps: (diffs.reduce(0, +) / Double(max(1, diffs.count))) * 10_000, t: .nan, p: .nan, blocks: m) }
    var blockMeans: [Double] = []
    for b in 0..<m {
        let slice = diffs[(b * blockSize)..<((b + 1) * blockSize)]
        blockMeans.append(slice.reduce(0, +) / Double(slice.count))
    }
    let mean = blockMeans.reduce(0, +) / Double(m)
    let variance = blockMeans.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(m - 1)
    let sd = variance.squareRoot()
    if sd == 0 {
        return IncrementResult(label: label, meanBps: mean * 10_000, t: mean == 0 ? 0 : .infinity, p: mean == 0 ? 1 : 0, blocks: m)
    }
    let se = sd / Double(m).squareRoot()
    let tstat = mean / se
    let p = twoTailedP(t: tstat, df: Double(m - 1))
    return IncrementResult(label: label, meanBps: mean * 10_000, t: tstat, p: p, blocks: m)
}

func printIncrements(_ title: String, _ series: [[Double]]) -> [IncrementResult] {
    print("\n=== \(title) — increment d_t = net(CAP-N) - net(CONTINUOUS), block(4wk) paired t-test ===")
    var results: [IncrementResult] = []
    for (i, n) in capNs.enumerated() {
        let r = blockIncrement(series[i + 1], series[0], label: "CAP-\(n)")
        results.append(r)
        print(String(format: "  CAP-%d  mean_d=%+.2fbps/wk  block-t=%+.3f  block-p=%.4f  #blocks=%d",
                     n, r.meanBps, r.t, r.p, r.blocks))
    }
    return results
}

let rawIncrements = printIncrements("RAW", weeklyNetRaw)
let matchedIncrements = printIncrements("EXPOSURE-MATCHED", weeklyNetMatched)

// MARK: Verdict

var anyBeats = false
for (i, incr) in rawIncrements.enumerated() {
    let armDSR = rawArmResults[i + 1].dsr
    if incr.meanBps > 0, incr.p < 0.05, let d = armDSR, d.dsr > 0.95 {
        anyBeats = true
    }
}
print("\n=== VERDICT ===")
print("ANY_CAP_BEATS_CONTINUOUS_SIG (raw, incr_mean_bps>0 AND incr_p<0.05 AND arm DSR>0.95): \(anyBeats ? "YES — FLAG FOR OWNER, DO NOT ACT" : "NO — null holds")")
print("CONTINUOUS raw: weeklySharpe=\(rawArmResults[0].weeklySharpe) dsr=\(rawArmResults[0].dsr?.dsr ?? .nan)")
for i in 0..<capNs.count {
    print("CAP-\(capNs[i]) raw: weeklySharpe=\(rawArmResults[i+1].weeklySharpe) dsr=\(rawArmResults[i+1].dsr?.dsr ?? .nan) incr_mean_bps=\(rawIncrements[i].meanBps) incr_p=\(rawIncrements[i].p)")
}
