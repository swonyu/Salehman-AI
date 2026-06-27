import Testing
import Foundation
@testable import Salehman_AI

// MARK: - StockSage MATH-INVARIANT golden-vector harness
//
// The bedrock the 15h autonomous loop pins Kelly / TSMOM / volatility math
// against: every assertion below is a GOLDEN VECTOR — a hand-derived closed-form
// expected value (the full arithmetic is in the comment above each `#expect`).
// If a future edit perturbs the core formulas, exactly the broken invariant goes
// red and names the number that moved.
//
// Why these and not the existing inline-golden tests: StockSageKellyTests /
// StockSageIndicatorsTests verify behavior over ad-hoc literals; this file fixes a
// MINIMAL, fully-derived spanning set drawn (where the endpoints are exact) from
// the shared `SageFix` closed-form series, so the loop has one stable, machine-
// independent input surface. RNG-free by construction (SageFix uses no Date()/
// random).
//
// Tolerance tiers (two separate constants):
//   • EXACT_EPS = 1e-9: used for pure-integer closed-form Kelly values where the
//     analytic result is representable exactly in IEEE-754 double arithmetic. This
//     matches (and does not weaken) the existing StockSageKellyTests contract.
//   • EPS = 1e-6: used for irrational results (TSMOM repeating decimal, log-return
//     volatility) where a finite binary expansion genuinely limits precision. This
//     is the autonomous-loop's Phase-4 gate tolerance.
//
// Conventions:
//   • Every series is newest-LAST (the convention every indicator expects).
//   • Assertions marked "structural consistency" verify an algebraic relationship
//     between two computed outputs (e.g. half == full/2); they are intentionally
//     tautological w.r.t. the engine and serve as sanity-checks only — the
//     independent absolute-value assertions above them are the real golden pins.
struct StockSageMathInvariantTests {
    typealias K = StockSageKelly
    typealias I = StockSageIndicators

    /// Tight tolerance for pure-integer Kelly results exact in IEEE-754 double arithmetic.
    /// Matches and does not weaken the existing StockSageKellyTests contract.
    static let EXACT_EPS = 1e-9

    /// The autonomous loop's Phase-4 gate tolerance — used for irrational results
    /// (TSMOM repeating decimal, log-return vol) where binary floating-point limits precision.
    static let EPS = 1e-6

    // ────────────────────────────────────────────────────────────────────────
    // MARK: 1 — Kelly fraction  f* = W − (1−W)/R
    // ────────────────────────────────────────────────────────────────────────
    //
    // compute() clamps f* to [0,1], then half = f*/2, quarter = f*/4, and
    // suggested = min(maxFraction 0.20, half). edge = W·R − (1−W).
    // Four hand-derived (W,R) points spanning positive / zero / negative / capped
    // edge — the arithmetic is shown to the digit so the Opus reviewer can verify
    // each without running code.

    @Test func kellyGoldenVectors() {
        // ── Point A: W=0.60, R=2 (a clean positive edge) ──
        //   f*      = 0.60 − (1−0.60)/2 = 0.60 − 0.40/2 = 0.60 − 0.20 = 0.40  (exact)
        //   half    = 0.40 / 2 = 0.20                                             (exact)
        //   quarter = 0.40 / 4 = 0.10                                             (exact)
        //   edge    = 0.60·2 − 0.40 = 1.20 − 0.40 = 0.80                         (exact)
        //   suggest = min(0.20, 0.20) = 0.20  (half exactly meets the cap)         (exact)
        // All values are exact in IEEE-754 double arithmetic → EXACT_EPS = 1e-9.
        let a = K.compute(winRate: 0.60, payoffRatio: 2.0, accountSize: 10_000)
        #expect(abs(a.fullKelly    - 0.40) < Self.EXACT_EPS)
        #expect(abs(a.halfKelly    - 0.20) < Self.EXACT_EPS)
        #expect(abs(a.quarterKelly - 0.10) < Self.EXACT_EPS)
        #expect(abs(a.edge         - 0.80) < Self.EXACT_EPS)
        #expect(abs(a.suggestedFraction - 0.20) < Self.EXACT_EPS)
        // dollarsToAllocate = suggested 0.20 × $10,000 = $2,000 (exact).
        #expect(abs(a.dollarsToAllocate - 2_000.0) < Self.EXACT_EPS)

        // ── Point B: W=0.55, R=2 (smaller positive edge) ──
        //   f*      = 0.55 − (1−0.55)/2 = 0.55 − 0.45/2 = 0.55 − 0.225 = 0.325  (exact)
        //   half    = 0.325 / 2 = 0.1625                                            (exact)
        //   quarter = 0.325 / 4 = 0.08125                                           (exact)
        //   edge    = 0.55·2 − 0.45 = 1.10 − 0.45 = 0.65                           (exact)
        //   suggest = min(0.20, 0.1625) = 0.1625  (under the cap → no-op)           (exact)
        let b = K.compute(winRate: 0.55, payoffRatio: 2.0, accountSize: 10_000)
        #expect(abs(b.fullKelly    - 0.325)   < Self.EXACT_EPS)
        #expect(abs(b.halfKelly    - 0.1625)  < Self.EXACT_EPS)
        #expect(abs(b.quarterKelly - 0.08125) < Self.EXACT_EPS)
        #expect(abs(b.edge         - 0.65)    < Self.EXACT_EPS)
        #expect(abs(b.suggestedFraction - 0.1625) < Self.EXACT_EPS)

        // ── Point C: W=0.50, R=1 (even-money coin flip → no edge) ──
        //   f*      = 0.50 − (1−0.50)/1 = 0.50 − 0.50 = 0.00  (clamp is a no-op here)
        //   half = quarter = 0 ; edge = 0.50·1 − 0.50 = 0.00 ; suggest = 0.
        let c = K.compute(winRate: 0.50, payoffRatio: 1.0, accountSize: 10_000)
        #expect(abs(c.fullKelly    - 0.0) < Self.EXACT_EPS)
        #expect(abs(c.halfKelly    - 0.0) < Self.EXACT_EPS)
        #expect(abs(c.quarterKelly - 0.0) < Self.EXACT_EPS)
        #expect(abs(c.edge         - 0.0) < Self.EXACT_EPS)
        #expect(abs(c.suggestedFraction - 0.0) < Self.EXACT_EPS)

        // ── Point D: W=0.40, R=1 (negative raw edge → f* CLAMPED to 0) ──
        //   raw f* = 0.40 − (1−0.40)/1 = 0.40 − 0.60 = −0.20 → max(0, −0.20) = 0.00
        //   edge   = 0.40·1 − 0.60 = −0.20  (edge is NOT clamped — it reports the true −EV)
        let d = K.compute(winRate: 0.40, payoffRatio: 1.0, accountSize: 10_000)
        #expect(abs(d.fullKelly        - 0.0) < Self.EXACT_EPS)   // clamped, not −0.20
        #expect(abs(d.suggestedFraction - 0.0) < Self.EXACT_EPS)
        #expect(abs(d.edge - (-0.20)) < Self.EXACT_EPS)           // edge keeps its sign
    }

    @Test func kellyHalfAndQuarterAreExactDivisions() {
        // The half/quarter relationship is the invariant the sizing layer leans on:
        // halfKelly ≡ fullKelly/2 and quarterKelly ≡ fullKelly/4 for ANY positive-edge
        // point, before the 0.20 cap is applied to `suggested` (not to half/quarter).
        // W=0.70, R=3 → f* = 0.70 − (1−0.70)/3 = 0.70 − 0.30/3 = 0.70 − 0.10 = 0.60.
        //   half    = 0.60/2 = 0.30   (note: ABOVE the 0.20 cap — but half itself is uncapped)
        //   quarter = 0.60/4 = 0.15
        //   suggest = min(0.20, 0.30) = 0.20  ← the cap binds here, ONLY on suggested
        // All exact in IEEE-754 → EXACT_EPS = 1e-9.
        let k = K.compute(winRate: 0.70, payoffRatio: 3.0, accountSize: 10_000)
        #expect(abs(k.fullKelly    - 0.60) < Self.EXACT_EPS)
        #expect(abs(k.halfKelly    - 0.30) < Self.EXACT_EPS)              // uncapped (golden pin)
        #expect(abs(k.quarterKelly - 0.15) < Self.EXACT_EPS)             // golden pin
        // Structural consistency checks (intentionally tautological w.r.t. the engine
        // which computes half=f*/2 and quarter=f*/4 directly — not independent golden pins):
        #expect(abs(k.halfKelly    - k.fullKelly / 2.0) < Self.EXACT_EPS) // tautological
        #expect(abs(k.quarterKelly - k.fullKelly / 4.0) < Self.EXACT_EPS) // tautological
        #expect(abs(k.suggestedFraction - K.maxFraction) < Self.EXACT_EPS) // 0.20 cap binds
    }

    // ────────────────────────────────────────────────────────────────────────
    // MARK: 1b — SageFix.idea() geometry: short direction has stop ABOVE entry
    // ────────────────────────────────────────────────────────────────────────
    //
    // For a SHORT at price=100, riskDistance=10, rr=2:
    //   stop   = 100 + 10  = 110   (above entry — a stop-out is price rising)
    //   target = 100 − 2·10 = 80   (below entry — profit on the down move)
    //   |(target − price)| / |(price − stop)| = 20/10 = rr = 2.0 exactly.
    //
    // For a LONG at price=100, riskDistance=10, rr=2:
    //   stop   = 100 − 10  = 90    (below entry)
    //   target = 100 + 2·10 = 120  (above entry)

    @Test func ideaShortHasStopAboveEntry() {
        let price = 100.0
        let rd    = 10.0
        let rr    = 2.0

        let shortIdea = SageFix.idea("X", conviction: 0.8, action: .sell, rr: rr,
                                     price: price, riskDistance: rd)
        let stop   = shortIdea.advice.stopPrice!
        let target = shortIdea.advice.targetPrice!

        // Geometric correctness for a short:
        #expect(stop   > price)   // short stop must be ABOVE entry
        #expect(target < price)   // short target must be BELOW entry
        #expect(abs(stop   - (price + rd))      < Self.EXACT_EPS)  // = 110
        #expect(abs(target - (price - rr * rd)) < Self.EXACT_EPS)  // = 80
        // Reward:risk ratio is exactly rr:
        let actualRR = abs(target - price) / abs(stop - price)
        #expect(abs(actualRR - rr) < Self.EXACT_EPS)

        // .reduce also maps to short geometry in SageFix:
        let reduceIdea = SageFix.idea("Y", conviction: 0.9, action: .reduce, rr: rr,
                                      price: price, riskDistance: rd)
        #expect(reduceIdea.advice.stopPrice!   > price)
        #expect(reduceIdea.advice.targetPrice! < price)

        // Long (.buy) is the mirror image — stop below, target above:
        let longIdea = SageFix.idea("Z", conviction: 0.8, action: .buy, rr: rr,
                                    price: price, riskDistance: rd)
        #expect(longIdea.advice.stopPrice!   < price)
        #expect(longIdea.advice.targetPrice! > price)
        let longRR = abs(longIdea.advice.targetPrice! - price) / abs(price - longIdea.advice.stopPrice!)
        #expect(abs(longRR - rr) < Self.EXACT_EPS)
    }

    // ────────────────────────────────────────────────────────────────────────
    // MARK: 2 — portfolioCap uniform down-scaling on a known vector
    // ────────────────────────────────────────────────────────────────────────
    //
    // portfolioCap(fracs, cap) clamps cap to [0,1], floors each fraction at 0,
    // requested = Σ fracs, scale = (requested > cap && requested > 0) ? cap/requested : 1,
    // scaled[i] = fracs[i]·scale, bookHeat = Σ scaled.

    @Test func portfolioCapScalingGoldenVector() {
        // ── Over-cap book: ten half-Kelly bets at 0.20 each ──
        //   requested = 10 × 0.20 = 2.00          (2× the account — per-position Kelly can't see this)
        //   2.00 > cap 0.30 → scale = 0.30 / 2.00 = 0.15
        //   each scaled = 0.20 × 0.15 = 0.03
        //   bookHeat = Σ = 10 × 0.03 = 0.30        (pinned to the cap, NOT 2.00)
        let over = K.portfolioCap(Array(repeating: 0.20, count: 10), maxPortfolioHeat: 0.30)
        #expect(abs(over.bookRequestedHeat - 2.00) < Self.EPS)
        #expect(abs(over.scaleApplied      - 0.15) < Self.EPS)
        #expect(abs((over.scaledFractions.first ?? -1) - 0.03) < Self.EPS)
        #expect(abs(over.bookHeat          - 0.30) < Self.EPS)   // pinned to the ceiling

        // ── Under-cap book: scale is a no-op (scale ≡ 1) ──
        //   fracs [0.10, 0.10, 0.05] → requested = 0.25 ≤ cap 0.30 → scale = 1
        //   bookHeat = 0.25 (untouched); each scaled fraction equals its input.
        let under = K.portfolioCap([0.10, 0.10, 0.05], maxPortfolioHeat: 0.30)
        #expect(abs(under.scaleApplied - 1.0)  < Self.EPS)
        #expect(abs(under.bookHeat     - 0.25) < Self.EPS)
        #expect(abs((under.scaledFractions.last ?? -1) - 0.05) < Self.EPS)

        // ── Exactly-at-cap book: requested == cap → NOT strictly greater → no scaling ──
        //   fracs [0.15, 0.15] → requested = 0.30 == cap 0.30 → scale = 1, bookHeat = 0.30.
        let atCap = K.portfolioCap([0.15, 0.15], maxPortfolioHeat: 0.30)
        #expect(abs(atCap.scaleApplied - 1.0)  < Self.EPS)
        #expect(abs(atCap.bookHeat     - 0.30) < Self.EPS)
    }

    // ────────────────────────────────────────────────────────────────────────
    // MARK: 3 — timeSeriesMomentum on closed-form ramps with EXACT endpoints
    // ────────────────────────────────────────────────────────────────────────
    //
    // timeSeriesMomentum(closes, lookback, skipRecent):
    //   startIdx = count − 1 − lookback   (the `lookback`-bars-ago close)
    //   endIdx   = count − 1 − skipRecent (the `skipRecent`-bars-ago close, the 12-1 skip)
    //   return   = (closes[endIdx] − closes[startIdx]) / closes[startIdx] · 100
    // We pick series whose start/end CLOSES are exact integers so the percentage is
    // exact to machine precision.

    @Test func tsmomUpRampExactEndpoints() {
        // The canonical +150% case (mirrors StockSageIndicatorsTests, kept here as a
        // pinned invariant). closes = 1,2,…,25 then a 5-bar pullback [24,22,20,18,16].
        //   count = 30, lookback = 20, skipRecent = 5
        //   startIdx = 30 − 1 − 20 = 9  → closes[9]  = 10   (the 10th element of 1…25)
        //   endIdx   = 30 − 1 −  5 = 24 → closes[24] = 25   (the 25th element of 1…25)
        //   return   = (25 − 10) / 10 · 100 = 15/10 · 100 = +150.0
        // The skip WORKS: the last 5 bars (24…16) are excluded, so the late drop
        // doesn't pull the figure down.
        let up = (1...25).map(Double.init) + [24.0, 22, 20, 18, 16]
        let m = I.timeSeriesMomentum(up, lookback: 20, skipRecent: 5)
        #expect(m != nil)
        #expect(abs((m ?? 0) - 150.0) < Self.EPS)
        #expect(I.trendOK(up, lookback: 20, skipRecent: 5) == true)   // > 0 → risk-on
    }

    @Test func tsmomDownRampExactEndpoints() {
        // A strict DOWN ramp: closes[i] = 100 − i, i = 0…29 (count 30).
        //   startIdx = 30 − 1 − 20 = 9  → closes[9]  = 100 − 9  = 91
        //   endIdx   = 30 − 1 −  5 = 24 → closes[24] = 100 − 24 = 76
        //   return   = (76 − 91) / 91 · 100 = (−15 / 91) · 100 = −16.483516483516483…
        // Hand value: −1500 / 91 = −16.4835164835…  (a repeating decimal — the ε<1e-6
        // band is what makes the golden vector robust to that).
        let down = (0..<30).map { 100.0 - Double($0) }
        let m = I.timeSeriesMomentum(down, lookback: 20, skipRecent: 5)
        #expect(m != nil)
        let EXPECTED = -1500.0 / 91.0    // = (76−91)/91·100, written as the exact ratio
        #expect(abs((m ?? 0) - EXPECTED) < Self.EPS)
        #expect((m ?? 0) < 0)                                        // own downtrend
        #expect(I.trendOK(down, lookback: 20, skipRecent: 5) == false) // veto a long
    }

    @Test func tsmomNotEnoughBarsIsNil() {
        // Guard branch: the function needs count > lookback. SageFix.cleanUptrend over
        // 30 bars (count 30) with lookback 40 → 30 > 40 is false → nil (never a crash,
        // never a fabricated number). Drawn from the SHARED fixture so the input is the
        // exact closed form documented in SageFix.
        let cu = SageFix.history(.cleanUptrend, bars: 30).closes   // closes[i] = 100 + i
        #expect(I.timeSeriesMomentum(cu, lookback: 40, skipRecent: 5) == nil)
        // …and one bar too few is still nil: count must be STRICTLY greater than lookback.
        let exactly = SageFix.history(.cleanUptrend, bars: 21).closes   // count 21
        #expect(I.timeSeriesMomentum(exactly, lookback: 21, skipRecent: 5) == nil) // 21 > 21 false
        #expect(I.timeSeriesMomentum(SageFix.history(.cleanUptrend, bars: 22).closes,
                                     lookback: 21, skipRecent: 5) != nil)          // 22 > 21 true
    }

    @Test func tsmomOnSharedCleanUptrendFixture() {
        // Pin TSMOM against the SHARED SageFix.cleanUptrend closed form so the loop's
        // fixture and its math harness can never silently disagree.
        //   SageFix.cleanUptrend: closes[i] = 100 + 1.0·i, bars = 30 (count 30).
        //   startIdx = 30 − 1 − 20 = 9  → closes[9]  = 100 + 9  = 109
        //   endIdx   = 30 − 1 −  5 = 24 → closes[24] = 100 + 24 = 124
        //   return   = (124 − 109) / 109 · 100 = (15 / 109) · 100 = +13.7614678899082…
        let closes = SageFix.history(.cleanUptrend, bars: 30).closes
        #expect(abs(closes[9]  - 109.0) < Self.EPS)   // fixture endpoints are what we derived
        #expect(abs(closes[24] - 124.0) < Self.EPS)
        let m = I.timeSeriesMomentum(closes, lookback: 20, skipRecent: 5)
        let EXPECTED = 1500.0 / 109.0    // = (124−109)/109·100
        #expect(abs((m ?? 0) - EXPECTED) < Self.EPS)
    }

    @Test func tsmomFlatFixtureIsZero() {
        // SageFix.flat: closes[i] = 100 (constant). Any (start,end) pair has equal
        // closes → (100 − 100)/100·100 = 0 exactly. trendOK is then false (0 is not > 0).
        let flat = SageFix.history(.flat, bars: 30).closes
        let m = I.timeSeriesMomentum(flat, lookback: 20, skipRecent: 5)
        #expect(abs((m ?? -1) - 0.0) < Self.EPS)
        #expect(I.trendOK(flat, lookback: 20, skipRecent: 5) == false)  // exactly 0 → not risk-on
    }

    // ────────────────────────────────────────────────────────────────────────
    // MARK: 4 — annualizedVolatility on a known 2-return series (σ derived analytically)
    // ────────────────────────────────────────────────────────────────────────
    //
    // annualizedVolatility(closes, periodsPerYear=252):
    //   rets[i] = ln(closes[i]/closes[i−1])  (only where closes[i−1] > 0)
    //   mean    = Σ rets / n
    //   variance = Σ (ret − mean)² / (n − 1)     ← SAMPLE variance (Bessel, n−1)
    //   σ_ann   = √variance · √periodsPerYear
    // Needs ≥ 3 closes (⇒ ≥ 2 returns); fewer → nil.

    @Test func annualizedVolatilityTwoReturnSeriesGolden() {
        // closes = [100, 110, 100] → exactly TWO log returns, symmetric about 0:
        //   r1 = ln(110/100) = ln(1.1) =  0.0953101798043…
        //   r2 = ln(100/110) = −ln(1.1) = −0.0953101798043…
        //   mean = (r1 + r2)/2 = 0  (the two returns cancel)
        //   variance = [(r1−0)² + (r2−0)²] / (2−1)
        //            = ln(1.1)² + ln(1.1)² = 2·ln(1.1)²
        //   σ_ann = √(2·ln(1.1)²) · √252 = ln(1.1)·√2·√252 = ln(1.1)·√504
        // Numeric: ln(1.1)=0.09531017980432486 → σ_ann ≈ 2.139708229797629.
        let v = I.annualizedVolatility([100, 110, 100])
        #expect(v != nil)
        // EXPECTED written as the analytic closed form, NOT a copied decimal:
        let EXPECTED = (2.0 * pow(log(1.1), 2)).squareRoot() * Double(252).squareRoot()
        #expect(abs((v ?? 0) - EXPECTED) < Self.EPS)
        // Independent cross-check against the decimal value computed off-line (Python):
        #expect(abs((v ?? 0) - 2.139708229797629) < Self.EPS)
        // The mean of the two symmetric returns is exactly 0 — verify the analytic
        // simplification σ = ln(1.1)·√504 matches (same number, different grouping).
        #expect(abs((v ?? 0) - log(1.1) * Double(504).squareRoot()) < Self.EPS)
    }

    @Test func annualizedVolatilityGeometricSeriesIsZero() {
        // A perfectly GEOMETRIC series has IDENTICAL log returns ⇒ zero variance ⇒ σ = 0.
        // closes = [100, 110, 121] → r1 = ln(110/100), r2 = ln(121/110) = ln(1.1) BOTH.
        //   mean = ln(1.1); variance = [(0)² + (0)²]/(2−1) = 0; σ_ann = 0·√252 = 0.
        let v = I.annualizedVolatility([100, 110, 121])
        #expect(v != nil)
        #expect(abs((v ?? -1) - 0.0) < Self.EPS)   // constant-growth ⇒ no realized vol
    }

    @Test func annualizedVolatilityNeedsAtLeastThreeCloses() {
        // Guard: < 3 closes (⇒ < 2 returns, no sample variance) → nil, never a crash.
        #expect(I.annualizedVolatility([100, 110]) == nil)
        #expect(I.annualizedVolatility([100]) == nil)
        #expect(I.annualizedVolatility([]) == nil)
    }
}
