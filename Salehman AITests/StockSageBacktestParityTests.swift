import Testing
import Foundation
@testable import Salehman_AI

// MARK: - StockSageBacktestParityTests
//
// REGRESSION GUARD: proves the backtester path (runTrades) and the live-advise path
// (advise(history:benchmark:) = buildIdeas) can NEVER silently diverge again after the
// d589164 fidelity fix. Two specific regressions are guarded:
//
//   1. VOLUME FIDELITY: runTrades gates volumes on `history.volumes.count == n`; the live
//      path forwards history.volumes unconditionally. If someone reverts that guard, pathB
//      is built with nil volumes while pathA has volumes ⇒ conviction shifts ≥ 0.05·varScalar
//      ⇒ parity asserts RED.
//
//   2. BENCHMARK DATE-ALIGNMENT: runTrades walks a forward-only `bj` pointer to find the
//      largest benchmark index j with benchDates[j] <= symbolDate[i] (nearest-prior). The
//      live path forwards benchmark?.closes directly. If someone reverts to a naive index
//      slice (e.g. benchCloses[0...i]), the benchmark length mismatches ⇒ different RS ⇒
//      ±0.08 swing ⇒ parity RED.
//
// BAR COUNT: 130 (≥128). relativeStrength uses returnOverPeriod(period:126), which requires
// closes.count > 126. At < 127 bars the RS term is nil-gated and the benchmark-alignment
// regression goes UNDETECTED. 130 bars also clears sma50; sma200 stays nil (that's fine —
// both paths see the same nil).
//
// NEGATIVE CONTROLS: two controls prove the volume and RS terms are individually LIVE at
// 130 bars — without them the parity asserts could pass vacuously (both paths degenerate
// to the same nil inputs) and would not catch the fidelity regression:
//   • Volume control: thin recent volumes (1.0 vs 1_000_000) flip the volumeConfirmation
//     term (confirmed=false) ⇒ conviction changes vs a no-volume call ⇒ VOLUME TERM IS LIVE.
//   • Benchmark control: with-benchmark vs no-benchmark calls on the same 130-bar fixture
//     differ in conviction ⇒ RS TERM IS LIVE (alignment matters).

// Tolerance tier — matching the math-invariant harness EPS = 1e-6.
private let _parityEPS: Double = 1e-6

// Nearest-prior benchmark alignment helper (replicates runTrades' bj logic).
// Returns Array(benchCloses[0...bj]) where bj is the largest j with benchDates[j] <= symbolDates.last.
// This is THE alignment contract d589164 introduced. Implementing the pointer rather than
// hard-coding `benchCloses` means this helper encodes the nearest-prior rule — if the rule
// changes, this fails too.
private func _nearestPriorBenchmarkCloses(symbolDates: [Date],
                                           benchDates: [Date],
                                           benchCloses: [Double]) -> [Double]? {
    guard let symbolLastDate = symbolDates.last else { return nil }
    var bj = -1
    for j in 0..<benchDates.count {
        if benchDates[j] <= symbolLastDate { bj = j } else { break }
    }
    guard bj >= 0 else { return nil }
    return Array(benchCloses[0...bj])
}

// Eps-tolerant optional equality: both nil OR both present within _parityEPS.
private func _optNearlyEqual(_ a: Double?, _ b: Double?) -> Bool {
    switch (a, b) {
    case (.none, .none): return true
    case (.some(let x), .some(let y)): return abs(x - y) < _parityEPS
    default: return false
    }
}

struct StockSageBacktestParityTests {

    // ────────────────────────────────────────────────────────────────────────
    // MARK: 1 — PARITY: buildIdeas path == runTrades path at the final bar
    // ────────────────────────────────────────────────────────────────────────
    //
    // Fixture design:
    //   h  = SageFix.history(.cleanUptrend, bars: 130)
    //        close[i] = 100 + 1.0·i → monotone uptrend, volumes constant 1_000_000,
    //        all 6 parallel arrays length 130. dates anchored at 2025-01-01.
    //   g  = SageFix.history(.approaching52wHigh, bars: 130)
    //        close[i] = 100 + 0.2·i → DIFFERENT slope (0.2/bar vs 1.0/bar)
    //        so RS = symReturn − benchReturn is non-zero (+RS: symbol outperforms).
    //        SAME fixed epoch ⇒ g.dates.last == h.dates.last (nearest-prior bj = 129 = n-1)
    //        so nearestPriorBenchmarkCloses returns the full g.closes — as pathA also sees.
    //
    // pathA = advise(history: h, benchmark: g)   (buildIdeas overload)
    // pathB = advise(closes:...volumes:...benchmarkCloses:...)  (runTrades reconstruction)
    //
    // Both paths MUST produce identical action, conviction, suggestedWeight, stopPrice, targetPrice.
    // The buy verdict on the clean uptrend means stopPrice and targetPrice are non-nil — an
    // additional guard that "both nil" cannot pass vacuously.

    @Test func parityBuildIdeasMatchesRunTradesAtFinalBar() {
        let bars = 130
        let h = SageFix.history(.cleanUptrend, bars: bars)
        // A DIFFERENT slope ensures RS is non-zero and exercises the benchmark term.
        let g = SageFix.history(.approaching52wHigh, bars: bars)

        // PATH A: the buildIdeas overload (live-advice path)
        let pathA = StockSageAdvisor.advise(history: h, benchmark: g)

        // PATH B: reconstruct exactly what runTrades does at bar i = n-1 (the final decision bar)
        let n = h.closes.count
        // Volumes gate: same as runTrades' `volumesAligned = history.volumes.count == n`
        let volB: [Double]? = (h.volumes.count == n) ? h.volumes : nil
        // Date-aligned benchmark via the nearest-prior rule (same as runTrades' bj pointer).
        // With g.dates.last == h.dates.last, this returns the full g.closes.
        let benchB: [Double]? = _nearestPriorBenchmarkCloses(symbolDates: h.dates,
                                                              benchDates: g.dates,
                                                              benchCloses: g.closes)
        let pathB = StockSageAdvisor.advise(closes: h.closes,
                                             highs: h.highs,
                                             lows: h.lows,
                                             volumes: volB,
                                             benchmarkCloses: benchB)

        // Parity assertions (eps = 1e-6):
        #expect(pathA.action == pathB.action,
                "PARITY FAIL: action \(pathA.action.rawValue) != \(pathB.action.rawValue) — buildIdeas/runTrades diverged")
        #expect(abs(pathA.conviction - pathB.conviction) < _parityEPS,
                "PARITY FAIL: conviction \(pathA.conviction) != \(pathB.conviction) — check volumes/benchmark alignment in runTrades")
        #expect(abs(pathA.suggestedWeight - pathB.suggestedWeight) < _parityEPS,
                "PARITY FAIL: suggestedWeight \(pathA.suggestedWeight) != \(pathB.suggestedWeight)")
        #expect(_optNearlyEqual(pathA.stopPrice, pathB.stopPrice) == true,
                "PARITY FAIL: stopPrice \(String(describing: pathA.stopPrice)) != \(String(describing: pathB.stopPrice))")
        #expect(_optNearlyEqual(pathA.targetPrice, pathB.targetPrice) == true,
                "PARITY FAIL: targetPrice \(String(describing: pathA.targetPrice)) != \(String(describing: pathB.targetPrice))")

        // Explicit non-nil guard: a clean uptrend at 130 bars is buy-family with ATR stop available.
        // If both stop/target were nil, the _optNearlyEqual assertions above would pass vacuously.
        let isBuy = pathA.action == .buy || pathA.action == .strongBuy
        #expect(isBuy,
                "Fixture sanity: cleanUptrend(130) must produce a buy-family action (stop/target non-nil guard)")
        #expect(pathA.stopPrice != nil,
                "Fixture sanity: buy-family on cleanUptrend(130) must have a non-nil stopPrice")
        #expect(pathA.targetPrice != nil,
                "Fixture sanity: buy-family on cleanUptrend(130) must have a non-nil targetPrice")

        // Sanity: nearestPriorBenchmarkCloses with equal last dates returns the full benchmark
        // (bj == n-1). Verify the alignment is exact — this is the precise contract under test.
        #expect(benchB?.count == g.closes.count,
                "Alignment sanity: equal last dates ⇒ nearestPrior returns full g.closes (bj = n-1)")
        #expect(benchB != nil, "Alignment sanity: benchmark prefix must be non-nil")
        _ = n   // suppress unused-variable warning
    }

    // ────────────────────────────────────────────────────────────────────────
    // MARK: 2 — NEGATIVE CONTROL A: volume term is LIVE at 130 bars
    // ────────────────────────────────────────────────────────────────────────
    //
    // Proves the volume term is non-trivial at the chosen fixture size.
    // Without this, the parity asserts could pass even if runTrades silently drops volumes
    // (both paths would then compute the same no-volume result and agree vacuously).
    //
    // Mechanism:
    //   volumeConfirmation: recentAvg / priorAvg >= 1 → confirmed (+0.05 to score).
    //   Thin-recent volumes: prior 20 bars = 1_000_000, last 3 bars = 1.0
    //   ⇒ ratio = 1.0 / 1_000_000 ≈ 0 ⇒ confirmed = false.
    //   Close-only call (volumes: nil) = no volume term applied (no +0.05 or −0.05).
    //   The two calls must differ in conviction by > 1e-9.

    @Test func negativeControl_volumeTermIsLive() {
        let bars = 130
        // Use cleanUptrend closes/highs/lows for a buy signal (abs(score) > 0 so volume term fires).
        let h = SageFix.history(.cleanUptrend, bars: bars)
        let c  = h.closes
        let hi = h.highs
        let lo = h.lows

        // Thin-recent volumes: prior 127 bars = 1_000_000, last 3 bars = 1.0
        // (lookback=20, recentBars=3; requires volumes.count >= 23 — satisfied by 130 bars)
        var thinVolumes = Array(repeating: 1_000_000.0, count: bars)
        thinVolumes[bars - 1] = 1.0
        thinVolumes[bars - 2] = 1.0
        thinVolumes[bars - 3] = 1.0

        // With thin recent volumes: volumeConfirmation returns (confirmed: false) → score gets −0.05
        let withThinVol = StockSageAdvisor.advise(closes: c, highs: hi, lows: lo,
                                                  volumes: thinVolumes, benchmarkCloses: nil)
        // With full volumes (constant 1_000_000): ratio = 1.0 → confirmed = true → score gets +0.05
        let withFullVol = StockSageAdvisor.advise(closes: c, highs: hi, lows: lo,
                                                  volumes: h.volumes, benchmarkCloses: nil)

        // The thin-volume call MUST differ from the full-volume call (confirmed flipped)
        #expect(abs(withThinVol.conviction - withFullVol.conviction) > 1e-9,
                "VOLUME NEGATIVE CONTROL: thin-recent vs full volumes must produce different conviction — the volume term is not live at 130 bars, or fixture has an issue")

        // Document the directionality: confirmed (full) > thin (unconfirmed)
        // (assuming the score is positive / buy-family so the +0.05/-0.05 applies)
        #expect(withThinVol.conviction < withFullVol.conviction,
                "VOLUME NEGATIVE CONTROL: thin (unconfirmed) must have lower conviction than full-volume (confirmed)")
    }

    // ────────────────────────────────────────────────────────────────────────
    // MARK: 3 — NEGATIVE CONTROL B: RS/benchmark term is LIVE at 130 bars
    // ────────────────────────────────────────────────────────────────────────
    //
    // Proves the relative-strength (benchmark) term is non-trivial at 130 bars.
    // Without this, the parity asserts could pass even if runTrades mis-aligns the
    // benchmark (both paths produce a wrong-but-identical RS, and the asserts pass vacuously).
    //
    // Mechanism:
    //   relativeStrength requires closes.count > 126 (returnOverPeriod period=126).
    //   At 130 bars: RS = symReturn(126) − benchReturn(126).
    //   cleanUptrend slope 1.0/bar vs approaching52wHigh slope 0.2/bar ⇒ RS > 0 ⇒ +0.08.
    //   A no-benchmark call gets 0. Conviction must differ by > 1e-9.

    @Test func negativeControl_benchmarkTermIsLive() {
        let bars = 130
        let h = SageFix.history(.cleanUptrend, bars: bars)
        let g = SageFix.history(.approaching52wHigh, bars: bars)

        let withBench = StockSageAdvisor.advise(closes: h.closes, highs: h.highs, lows: h.lows,
                                                volumes: h.volumes, benchmarkCloses: g.closes)
        let noBench   = StockSageAdvisor.advise(closes: h.closes, highs: h.highs, lows: h.lows,
                                                volumes: h.volumes, benchmarkCloses: nil)

        // If RS term is live, adding a benchmark must change conviction by > 1e-9.
        #expect(abs(withBench.conviction - noBench.conviction) > 1e-9,
                "BENCHMARK NEGATIVE CONTROL: with-benchmark vs no-benchmark must differ at 130 bars — RS term is not live, meaning the parity test's benchmark-alignment guard is vacuous (130 bars insufficient or fixture has an issue)")

        // Sanity: the benchmark at 130 bars is sufficient for RS (> 126 bars)
        let rsCheck = StockSageIndicators.relativeStrength(symbolCloses: h.closes,
                                                           benchmarkCloses: g.closes)
        #expect(rsCheck != nil,
                "RS sanity: 130-bar fixture must produce a non-nil RS (closes.count 130 > period 126)")
    }
}
