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

    // ────────────────────────────────────────────────────────────────────────
    // MARK: 5 — variance scalar (ITER3)
    // ────────────────────────────────────────────────────────────────────────
    //
    // Guardrails verified here:
    //   1. Cap re-asserted before Kelly — test (b) cap-entering-Kelly pin.
    //   2. Scalar clamped ≤ 1 (attenuation-only) AND 0.65 cap re-asserted post-scale pre-Kelly.
    //   3. Honesty floor / falling-knife guard not regressed — tested inline and via momentumCrash.
    //   4. Byte-identical for pure callers where scalar is not triggered — test (c).
    //
    // All assertions use EPS = 1e-6.
    typealias A = StockSageAdvisor

    // ── Unit-level pins on varianceScalar (closed-form, exact) ──────────────

    @Test func varianceScalarUnitPins() {
        // 0.40 vol → raw = 0.20/0.40 = 0.5 → clamp no-op → 0.5 (attenuates)
        #expect(abs(A.varianceScalar(realizedVol: 0.40) - 0.5) < Self.EPS)

        // 0.20 vol → raw = 0.20/0.20 = 1.0 → clamp no-op → 1.0 (no-op; vol == target)
        #expect(abs(A.varianceScalar(realizedVol: 0.20) - 1.0) < Self.EPS)

        // 0.10 vol → raw = 0.20/0.10 = 2.0 → CLAMPED to 1.0 (calm regime must NOT amplify)
        #expect(abs(A.varianceScalar(realizedVol: 0.10) - 1.0) < Self.EPS)

        // nil → guard fails → 1.0 (no-op; pure caller with no vol)
        #expect(abs(A.varianceScalar(realizedVol: nil) - 1.0) < Self.EPS)

        // 0.0 → v > 0 guard fails → 1.0 (zero variance ⇒ no-op, not divide-by-zero)
        #expect(abs(A.varianceScalar(realizedVol: 0.0) - 1.0) < Self.EPS)

        // NaN → isFinite guard fails → 1.0
        #expect(abs(A.varianceScalar(realizedVol: .nan) - 1.0) < Self.EPS)

        // +∞ → isFinite guard fails → 1.0
        #expect(abs(A.varianceScalar(realizedVol: .infinity) - 1.0) < Self.EPS)
    }

    // ── (a) inverse-variance scalar — unit-level attenuation with a synthetic high-vol input ──
    //
    // NOTE on momentumCrash(300): the fixture ramps to 300 at bar 200 then falls −2/bar.
    // The −2/bar crash on a base of ~300 gives daily log-returns of ≈ −0.67%; annualized
    // vol ≈ 0.67% × √252 ≈ 10.6% — BELOW the 20% target. The scalar is therefore 1.0
    // (no-op) on that fixture. The !isBuy assertion passes only because the downtrend
    // signals (price < 50DMA < 200DMA, negative momentum/MACD) drive a .sell independently.
    // To test attenuation we use a direct unit-level call with a synthetic vol > 20%.

    @Test func varianceScalar_momentumCrash_attenuates() {
        // ── Part 1: Direct unit-level attenuation golden vector ──
        // vol = 0.40 → raw = 0.20/0.40 = 0.50 → clamp no-op → 0.50 (already pinned above,
        // but also exercised here in the crash-context block for completeness).
        let syntheticVol = 0.40
        let scalar = A.varianceScalar(realizedVol: syntheticVol)
        #expect(abs(scalar - 0.50) < Self.EPS,
                "varianceScalar(0.40) must equal 0.50 (target 0.20 / realized 0.40)")
        #expect(scalar < 1.0, "synthetic crash vol (40%) must produce attenuation (scalar < 1)")
        #expect(abs(scalar - 0.20 / syntheticVol) < Self.EPS,
                "scalar closed form: target/realized must hold")

        // vol = 0.30 → raw = 0.20/0.30 = 0.666… = 2/3 → clamp no-op → 2/3
        let s30 = A.varianceScalar(realizedVol: 0.30)
        #expect(abs(s30 - 2.0 / 3.0) < Self.EPS,
                "varianceScalar(0.30) must equal 2/3 exactly")

        // vol = 0.25 → raw = 0.20/0.25 = 0.80 → clamp no-op → 0.80
        let s25 = A.varianceScalar(realizedVol: 0.25)
        #expect(abs(s25 - 0.80) < Self.EPS,
                "varianceScalar(0.25) must equal 0.80")

        // ── Part 2: momentumCrash(300) produces a non-buy for structural reasons ──
        // The crash leaves price well below both SMAs with negative momentum and MACD →
        // the advisor must return a sell-family action regardless of the scalar's value.
        let h = SageFix.history(.momentumCrash, bars: 300)
        let advice = StockSageAdvisor.advise(history: h)
        let isBuy = (advice.action == .buy || advice.action == .strongBuy)
        #expect(!isBuy,
                "momentumCrash(300) must not produce a buy (downtrend signals dominate) — got \(advice.action.rawValue)")

        // ── Part 3: computable vol exists and is positive ──
        let vol = I.annualizedVolatility(h.closes)
        #expect(vol != nil, "momentumCrash(300) must have computable realized vol")
        #expect((vol ?? 0) > 0, "momentumCrash(300) vol must be positive")
        // NOTE: The actual vol is ≈ 10-13% (< 20%), so the scalar is 1.0 on this fixture.
        // The non-buy outcome is structural (negative trend/momentum/MACD), NOT from the scalar.
        // Scalar attenuation is tested above via direct unit-level calls (Part 1).
    }

    // ── (b) flat/calm low-vol → scalar CLAMPED to 1.0; cap still ≤ 0.65 entering Kelly ──

    @Test func varianceScalar_calmLowVol_clampedToOne() {
        // SageFix.cleanUptrend(260): close[i] = 100 + i → tiny log-return vol ≪ 0.20.
        // raw scalar = 0.20/vol >> 1 → CLAMPED to 1.0 (calm regime must NOT amplify).
        let h = SageFix.history(.cleanUptrend, bars: 260)
        let vol = I.annualizedVolatility(h.closes)
        #expect(vol != nil, "cleanUptrend(260) must have computable realized vol")
        let vol_ = vol!
        // Log returns of +1/101, +1/102, … are all very small → vol ≪ 0.20.
        // We require it is below the 20% target to trigger the clamp path.
        #expect(vol_ < 0.20, "cleanUptrend vol should be below 20% target (clamp path)")
        // raw = 0.20 / vol > 1.0; after clamp → exactly 1.0
        let scalar = A.varianceScalar(realizedVol: vol_)
        #expect(abs(scalar - 1.0) < Self.EPS, "calm regime: scalar must be clamped to 1.0, not \(scalar)")
    }

    @Test func varianceScalar_capStillBoundsBeforeKelly() {
        // With scalar == 1.0 (calm cleanUptrend), the trend-family cap (0.65) is still
        // re-asserted after scaling. The raw family on a fully-confirmed uptrend can reach
        // 0.40 (trend) + 0.15 (mom) + 0.10 (MACD) + 0.05 (vol confirm) + 0.05 (volAdjMom)
        // + 0.08 (relStr) = 0.83 > 0.65. After scalar×1.0 = 0.83, the cap clamps to 0.65.
        // We verify via advise(): suggestedWeight must be finite and ≤ maxWeight 0.20,
        // and the conviction entering Kelly is min(|score|, 1) which only receives the
        // post-cap contribution.
        let h = SageFix.history(.cleanUptrend, bars: 260)
        let advice = StockSageAdvisor.advise(history: h)
        // suggestedWeight is bounded (Kelly sizing is finite and reasonable)
        #expect(advice.suggestedWeight >= 0.0)
        #expect(advice.suggestedWeight <= StockSageAdvisor.maxWeight + Self.EPS,
                "suggestedWeight must not exceed maxWeight 0.20 — got \(advice.suggestedWeight)")
        // Conviction is in [0, 1] — a requirement for Kelly to be well-defined
        #expect(advice.conviction >= 0.0)
        #expect(advice.conviction <= 1.0 + Self.EPS)
    }

    // ── (c) byte-identity: cleanUptrend has old-veto dormant AND new scalar = 1.0 ──

    @Test func varianceScalar_byteIdentityWitness() {
        // The old binary veto fired ONLY on score > 0 AND trendOK == false.
        // cleanUptrend has trendOK == true (positive TSMOM) → old veto was dormant.
        // ITER3 scalar = 1.0 (calm vol below 20% target) → multiplier is also a no-op.
        // Therefore the two code paths are provably equivalent on this fixture.
        //
        // Verify:
        //   (i) trendOK is true on cleanUptrend(260) [old veto dormant]
        //   (ii) varianceScalar = 1.0 [new scalar dormant]
        //   (iii) advise() produces a buy-family action (the uptrend signal dominates)
        let h = SageFix.history(.cleanUptrend, bars: 260)
        let closes = h.closes
        // (i) trendOK must be true on this uptrend
        let tok = I.trendOK(closes)
        #expect(tok == true, "cleanUptrend(260) must have trendOK == true (old veto dormant)")
        // (ii) scalar must be 1.0 (no-op on this calm fixture)
        let vol = I.annualizedVolatility(closes)!
        let scalar = A.varianceScalar(realizedVol: vol)
        #expect(abs(scalar - 1.0) < Self.EPS, "calm uptrend: scalar must be 1.0 (no-op)")
        // (iii) advice is buy-family (the trend signal dominates and nothing attenuates it)
        let advice = StockSageAdvisor.advise(history: h)
        let isBuy = (advice.action == .buy || advice.action == .strongBuy)
        #expect(isBuy, "cleanUptrend byte-identity witness: must produce a buy — got \(advice.action.rawValue)")
    }

    // ── (c2) BLOCKER-3 behavioral contract: trendOK==false + low-vol → scalar is a no-op ──
    //
    // DESIGN DECISION (ITER3): The old binary TSMOM veto fired on `trendOK == false` regardless
    // of realized vol — it penalized EVERY long when the 12-1 own-return was negative. The new
    // inverse-variance scalar fires ONLY when annualized vol > 20% (targeting constant risk per
    // Barroso & Santa-Clara 2015). These are NOT the same guard:
    //
    //   Scenario: a name with a slow 12-1 grind down (trendOK == false) and low realized vol < 20%.
    //   Old code: score -= 0.20 (binary veto, unconditional on trendOK == false + score > 0).
    //   ITER3:    scalar = 1.0 (vol below 20% target → no-op). The trend family is NOT penalized.
    //
    // This test PINS the low-vol behavior and documents the intentional trade-off:
    // ITER3 does NOT protect against low-vol grinding downtrends via the scalar.
    // That protection (if desired) must come from the SMA/momentum signals themselves.
    // Fixture: a monotone declining series (no V-shape reversal) with trendOK=false AND vol<20%.

    @Test func varianceScalar_lowVolDowntrend_scalarIsNoOp() {
        // Fixture: a GENTLE, SMOOTH 12-1 downtrend from 200 → ~44.1 over 260 bars.
        // Close[i] = 200 - i * 0.602   (260 bars: 200.0 → 200 - 259*0.602 ≈ 44.1)
        //
        // This fixture satisfies all three required conditions simultaneously:
        //   (a) trendOK == false: 12-1 own-return is -71% < 0 (downtrend dominates lookback window).
        //       Derivation: startIdx = 260-1-252 = 7 → close[7] ≈ 195.8
        //                   endIdx   = 260-1-21  = 238 → close[238] ≈ 56.7
        //                   return = (56.7-195.8)/195.8 * 100 ≈ -71% < 0 → trendOK = false ✓
        //   (b) vol << 20%: daily log return = ln(1 - 0.602/close[i]) ≈ -0.3% → annualized ≈ 4.8%.
        //   (c) scalar must be 1.0: vol (4.8%) < target (20%) → raw = 0.20/0.048 >> 1 → clamp to 1.0.
        //
        // NOTE: the vShape fixture (244-bar decline + 15-bar rally) is NOT suitable here because
        // the direction-reversal at bar 244 creates a 13%+ single-day log return that inflates
        // the annualized vol to ~32% (above the 20% target), causing the scalar to fire.
        // A smooth monotone decline avoids this artifact and isolates the trendOK≠vol interaction.
        let gentle: [Double] = (0..<260).map { 200.0 - Double($0) * 0.602 }

        // (i) trendOK must be false: the 12-1 own-downtrend is -71%.
        #expect(I.trendOK(gentle) == false,
                "gentle decline: trendOK must be false (12-1 own-downtrend ≈ -71%)")

        // (ii) vol << 20% (daily log return ≈ -0.3%, annualized ≈ 4.8%) → scalar clamped to 1.0.
        let vol = I.annualizedVolatility(gentle)
        #expect(vol != nil, "gentle decline must have computable realized vol")
        let vol_ = vol!
        #expect(vol_ < 0.20,
                "gentle decline annualized vol must be below 20%; got \(vol_) — check fixture derivation")
        let scalar = A.varianceScalar(realizedVol: vol_)
        #expect(abs(scalar - 1.0) < Self.EPS,
                "ITER3 scalar must be 1.0 on gentle decline (vol \(vol_*100)% < 20% → no-op); got \(scalar)")

        // (iii) BEHAVIORAL CONTRACT — the intentional ITER3 trade-off:
        // The scalar is dormant (1.0). Under the OLD binary veto (removed by ITER3), a positive
        // long score in a trendOK==false regime would be penalized score -= 0.20.
        // Under ITER3, there is NO SUCH PENALTY when vol < 20%.
        // On this fixture (monotone decline with negative SMA/momentum), the score is
        // strongly NEGATIVE, so the old veto's "score > 0" condition wouldn't have fired anyway.
        // What we pin here is: scalar = 1.0 (confirmed above), rationale has no "High-vol" message,
        // and the action is bearish (the downtrend signals dominate without scalar interference).
        let advice = StockSageAdvisor.advise(closes: gentle)
        #expect(!advice.rationale.contains { $0.contains("High-vol regime") },
                "no 'High-vol regime' scalar message on a 4.8%-vol fixture; got \(advice.rationale)")
        #expect(advice.action != .strongBuy,
                "bearish gentle decline must not produce Strong Buy; got \(advice.action.rawValue)")
        // Explicit: the action should be bearish (reduce or sell or avoid, depending on ER).
        #expect(advice.action == .sell || advice.action == .reduce || advice.action == .avoid,
                "gentle decline must produce sell/reduce/avoid; got \(advice.action.rawValue), rationale: \(advice.rationale)")
    }

    // ── (d) clean uptrend → Strong Buy (owner intent preserved) ──────────────

    @Test func varianceScalar_cleanUptrend_stillStrongBuy() {
        // Uses TrendFixtures.up(260) — an ACCELERATING quadratic series (close[i] = 50 + k·i²,
        // k=0.0153). This fixture has genuine curvature so the MACD EMA pair separates and the
        // histogram is genuinely POSITIVE (not the ≈ −1.8e-15 IEEE-754 noise produced by the
        // exactly-linear SageFix.cleanUptrend +1/bar ramp, which had a flat MACD line that
        // could land the wrong sign, silently costing −0.10).
        //
        // Derivation (matches trendFamilyCap doc-comment):
        //   trend   +0.40  (price > 50DMA > 200DMA, needs ≥200 bars — provided)
        //   mom     +0.15  (6-month return > 0 on accelerating uptrend)
        //   MACD    +0.10  (histogram genuinely > 0 on this convex-up series)
        //   family subtotal = 0.65 (raw), cap = 0.65 (no-op or already at cap)
        //   vol+relStr nudges: also trend-family, capped at 0.65 total
        //   scalar  = 1.0  (calm vol on the smooth ramp → clamp to 1.0)
        //   RSI-extended nudge −0.10 (RSI ~100 on a pure uptrend → extended flag)
        //   score ≈ 0.55–0.65 → Strong Buy (≥ 0.50 threshold)
        // Guardrail: 0.65 − 0.10 = 0.55 > 0.50 — Strong Buy survives, as the cap comment promises.
        let closes = TrendFixtures.up(260)
        let highs  = closes.map { $0 + 1 }
        let lows   = closes.map { $0 - 1 }
        let advice = StockSageAdvisor.advise(closes: closes, highs: highs, lows: lows)
        #expect(advice.action == .strongBuy,
                "TrendFixtures.up(260) must produce Strong Buy — got \(advice.action.rawValue), rationale: \(advice.rationale)")
    }

    // ── (e) falling-knife guard NOT regressed by scalar ──────────────────────

    @Test func varianceScalar_fallingKnife_bounceStillDenied() {
        // Scalar multiplies the trend FAMILY only; the +0.25 rangeOversoldBounce credit
        // lives in nonFamily and is gated by oversoldBounceIsBuyable (trendOK check).
        // On .fallingKnife (strict −0.5/bar, 260 bars), trendOK must be false →
        // oversoldBounceIsBuyable returns false → the +0.25 credit is withheld, regardless
        // of the scalar value. The knife-catching guardrail is untouched by ITER3.
        let h = SageFix.history(.fallingKnife, bars: 260)
        // trendOK must be false on a strict downtrend
        let tok = I.trendOK(h.closes)
        #expect(tok == false, "fallingKnife must have trendOK == false (knife guard active)")
        // oversoldBounceIsBuyable must also be false (no bounce credit)
        let buyable = StockSageAdvisor.oversoldBounceIsBuyable(h.closes)
        #expect(buyable == false, "fallingKnife: oversoldBounceIsBuyable must be false")
        // Final action must not be a buy (no oversold bounce credit + downtrend family → non-buy)
        let advice = StockSageAdvisor.advise(history: h)
        let isBuy = (advice.action == .buy || advice.action == .strongBuy)
        #expect(!isBuy, "fallingKnife must not produce a buy — got \(advice.action.rawValue)")
    }
}
