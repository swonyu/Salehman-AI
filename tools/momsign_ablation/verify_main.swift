import Foundation

// INDEPENDENT VERIFIER (written by the correctness verifier, not the implementer).
// Links ONLY the shipped StockSageNetCostSim/StockSageDeflatedSharpe. Recomputes:
//  (a) Variant A (momentum = negated shipped irrxWeights) series with MY OWN loop,
//      checks anti-symmetry residuals against shipped rebalanceSeries (reversal),
//  (b) mean gross/net %s for spot configs vs the claimed table,
//  (c) Variant B weights re-derived by me (clipped long-only industry-relative momentum),
//      spot meanGross/meanNet vs claimed table,
//  (d) look-ahead probe: perturb FUTURE returns (>= t) and confirm weights at t unchanged.

struct PanelJSON: Decodable {
    let returns: [[Double]]
    let industry: [Int]
    let earningsExcludedAt: [String: [Int]]?
    let roundTripBps: Double?
}

let path = CommandLine.arguments[1]
let data = FileManager.default.contents(atPath: path)!
let pj = try! JSONDecoder().decode(PanelJSON.self, from: data)
var excl: [Int: Set<Int>] = [:]
for (k, v) in (pj.earningsExcludedAt ?? [:]) { excl[Int(k)!] = Set(v) }
let rt = pj.roundTripBps ?? 13.0
let panelWith = StockSageNetCostSim.Panel(returns: pj.returns, industry: pj.industry, earningsExcludedAt: excl)
let panelWithout = StockSageNetCostSim.Panel(returns: pj.returns, industry: pj.industry, earningsExcludedAt: [:])

// MY OWN rebalance loop (from the shipped rebalanceSeries doc/semantics).
func mySeries(_ panel: StockSageNetCostSim.Panel, lb: Int, hd: Int,
              weights: (StockSageNetCostSim.Panel, Int, Int, Set<Int>) -> [Double]) -> [(g: Double, to: Double, n: Double)] {
    let S = panel.symbolCount, T = panel.periodCount
    let perSide = rt / 2 / 10_000.0
    var out: [(Double, Double, Double)] = []
    var prev = [Double](repeating: 0, count: S)
    var t = lb
    while t + hd <= T {
        let ex = panel.earningsExcludedAt[t] ?? []
        let w = weights(panel, t, lb, ex)
        var g = 0.0
        for s in 0..<S {
            var f = 0.0
            for u in t..<(t + hd) { f += panel.returns[s][u] }
            g += w[s] * f
        }
        var to = 0.0
        for s in 0..<S { to += abs(w[s] - prev[s]) }
        out.append((g, to, g - to * perSide))
        prev = w
        t += hd
    }
    return out
}

func momW(_ p: StockSageNetCostSim.Panel, _ t: Int, _ lb: Int, _ ex: Set<Int>) -> [Double] {
    StockSageNetCostSim.irrxWeights(p, at: t, lookback: lb, excluded: ex).map { -$0 }
}

// MY OWN Variant B: industry-relative past-return score, clip negatives to 0, normalize to sum 1,
// excluded names get 0 weight.
func myBW(_ p: StockSageNetCostSim.Panel, _ t: Int, _ lb: Int, _ ex: Set<Int>) -> [Double] {
    let S = p.symbolCount
    var past = [Double](repeating: 0, count: S)
    for s in 0..<S { for u in (t - lb)..<t { past[s] += p.returns[s][u] } }
    let inc = (0..<S).filter { !ex.contains($0) }
    var gsum: [Int: Double] = [:], gcnt: [Int: Int] = [:]
    for s in inc { gsum[p.industry[s], default: 0] += past[s]; gcnt[p.industry[s], default: 0] += 1 }
    var w = [Double](repeating: 0, count: S)
    var tot = 0.0
    for s in inc {
        let sc = past[s] - gsum[p.industry[s]]! / Double(gcnt[p.industry[s]]!)
        let c = max(0, sc)
        w[s] = c; tot += c
    }
    guard tot > 0 else { return [Double](repeating: 0, count: S) }
    for s in inc { w[s] /= tot }
    return w
}

// (a)+(b): anti-symmetry across the FULL grid, both arms, with my own loop.
let lbs = [5, 10, 21, 63, 126], hds = [5, 10, 21]
var globalMaxG = 0.0, globalMaxT = 0.0, globalMaxN = 0.0
for lb in lbs { for hd in hds {
    for (panel, arm) in [(panelWithout, "WITHOUT"), (panelWith, "WITH")] {
        let rev = StockSageNetCostSim.rebalanceSeries(panel, lookback: lb, hold: hd, roundTripBps: rt)
        let mom = mySeries(panel, lb: lb, hd: hd, weights: momW)
        precondition(rev.count == mom.count && rev.count > 0, "count mismatch \(lb)/\(hd)/\(arm)")
        var mg = 0.0, mt = 0.0, mn = 0.0
        for i in 0..<rev.count {
            mg = max(mg, abs(mom[i].g + rev[i].grossReturn))
            mt = max(mt, abs(mom[i].to - rev[i].turnover))
            mn = max(mn, abs(mom[i].n - (rev[i].netReturn - 2 * rev[i].grossReturn)))
        }
        globalMaxG = max(globalMaxG, mg); globalMaxT = max(globalMaxT, mt); globalMaxN = max(globalMaxN, mn)
        print(String(format: "ANTISYM lb=%3d hd=%2d %@ maxG=%.3e maxT=%.3e maxN=%.3e", lb, hd, arm, mg, mt, mn))
    }
}}
print(String(format: "ANTISYM GLOBAL maxG=%.3e maxT=%.3e maxN=%.3e  (%@)", globalMaxG, globalMaxT, globalMaxN,
             (globalMaxG < 1e-12 && globalMaxT < 1e-12 && globalMaxN < 1e-12) ? "PASS < 1e-12" : "FAIL"))

// (b) spot means, Variant A, my own loop — compare to claimed table.
func meanPct(_ xs: [Double]) -> Double { xs.reduce(0, +) / Double(xs.count) * 100 }
let spotsA: [(Int, Int, Bool, Double, Double)] = [
    (5, 5, false, 0.00436, -0.08918),
    (21, 21, true, 0.04605, -0.04803),
    (126, 21, false, 0.38692, 0.35017),
]
for (lb, hd, withEx, cg, cn) in spotsA {
    let p = withEx ? panelWith : panelWithout
    let s = mySeries(p, lb: lb, hd: hd, weights: momW)
    print(String(format: "SPOT-A lb=%d hd=%d ex=%@ myGross=%.5f%% (claim %.5f) myNet=%.5f%% (claim %.5f)",
                 lb, hd, withEx ? "T" : "F", meanPct(s.map { $0.g }), cg, meanPct(s.map { $0.n }), cn))
}

// (c) spot means, Variant B, my own weight rule + my own loop.
let spotsB: [(Int, Int, Bool, Double, Double)] = [
    (21, 21, true, 1.72123, 1.62745),
    (5, 5, false, 0.37976, 0.28633),
    (126, 21, true, 2.08462, 2.04438),
]
for (lb, hd, withEx, cg, cn) in spotsB {
    let p = withEx ? panelWith : panelWithout
    let s = mySeries(p, lb: lb, hd: hd, weights: myBW)
    print(String(format: "SPOT-B lb=%d hd=%d ex=%@ myGross=%.5f%% (claim %.5f) myNet=%.5f%% (claim %.5f)",
                 lb, hd, withEx ? "T" : "F", meanPct(s.map { $0.g }), cg, meanPct(s.map { $0.n }), cn))
}

// (d) look-ahead probe: bump ALL returns at u >= t0 by +5%; weights at t0 must be bit-identical.
let t0 = 300, lbProbe = 21
var mutated = pj.returns
for s in 0..<mutated.count { for u in t0..<mutated[s].count { mutated[s][u] += 0.05 } }
let panelMut = StockSageNetCostSim.Panel(returns: mutated, industry: pj.industry, earningsExcludedAt: excl)
let ex0 = panelWith.earningsExcludedAt[t0] ?? []
let wOrig = StockSageNetCostSim.irrxWeights(panelWith, at: t0, lookback: lbProbe, excluded: ex0)
let wMut = StockSageNetCostSim.irrxWeights(panelMut, at: t0, lookback: lbProbe, excluded: ex0)
let bOrig = myBW(panelWith, t0, lbProbe, ex0)
let bMut = myBW(panelMut, t0, lbProbe, ex0)
print("LOOKAHEAD-PROBE irrxWeights(t=\(t0)) unchanged under future(+5%) mutation: \(wOrig == wMut ? "PASS" : "FAIL")")
print("LOOKAHEAD-PROBE variantB weights(t=\(t0)) unchanged under future(+5%) mutation: \(bOrig == bMut ? "PASS" : "FAIL")")
// and the past DOES matter (sanity that the probe bites):
var mutPast = pj.returns
for s in 0..<mutPast.count { mutPast[s][t0 - 1] += 0.05 * Double(s % 7) }
let panelMutPast = StockSageNetCostSim.Panel(returns: mutPast, industry: pj.industry, earningsExcludedAt: excl)
let wMutPast = StockSageNetCostSim.irrxWeights(panelMutPast, at: t0, lookback: lbProbe, excluded: ex0)
print("LOOKAHEAD-PROBE past-mutation changes weights (expected): \(wOrig != wMutPast ? "PASS" : "FAIL")")
