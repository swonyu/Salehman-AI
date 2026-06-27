import Foundation

// MARK: - Conviction → win-probability calibration
//
// The advisor's `conviction` is a 0–1 signal-STRENGTH ordinal, NOT a probability of profit. The
// expected-value engine historically mapped it with a hand-picked line (winProb = 0.35 + 0.23·c),
// which has no grounding in realized outcomes — yet it is fed into Kelly, whose bet fraction is
// acutely sensitive to it (over-state the win rate and you over-bet into ruin).
//
// This learns the map from realized (conviction, won) trades — e.g. the walk-forward backtester:
//   1. Bin trades by conviction.
//   2. Each bin's win prob = a CONSERVATIVE Wilson LOWER confidence bound (so a thin or lucky bin
//      can't over-state edge → Kelly stays cautious; under-stating only under-bets, which is safe).
//   3. Enforce MONOTONICITY (higher conviction ⇒ ≥ win prob) via pool-adjacent-violators (isotonic
//      regression), weighting by sample size.
//   4. Require a minimum total sample; below it, `fit` returns nil and the caller keeps the
//      conservative linear prior.
//
// Pure + deterministic → unit-tested. Calibrating is honest about uncertainty (lower bound), not
// optimistic — the whole point is to stop sizing on an invented probability.
struct StockSageConvictionCalibration: Sendable, Equatable {
    /// One ascending conviction band and its calibrated win probability.
    struct Bin: Sendable, Equatable {
        let upper: Double     // upper edge of the half-open band [lower, upper) — matches fit()'s bucketing
        let winProb: Double   // calibrated P(win) for this band (monotonic non-decreasing in `upper`)
        let n: Int            // realized trades in the band (transparency)
    }
    let bins: [Bin]           // ascending by `upper`, equal-width over [0,1]
    let sampleSize: Int       // total trades the fit was built from

    /// Calibrated win probability for a conviction in [0,1]: the band it falls into. Uses the SAME
    /// half-open index math as `fit()`'s bucketing, so a conviction on an exact internal edge is
    /// looked up in the band it was trained into (not the one below).
    nonisolated func winProb(_ conviction: Double) -> Double {
        guard !bins.isEmpty else { return 0.5 }
        let c = Swift.max(0, Swift.min(1, conviction))
        let idx = Swift.min(bins.count - 1, Int(c * Double(bins.count)))
        return bins[idx].winProb
    }

    /// [AUDIT] Sample-count seam: isotonic regression is unreliable below ~1000–2000 realized
    /// outcomes (Niculescu-Mizil & Caruana 2005; Alasalmi 2020 ACM TKDD; sklearn: "isotonic
    /// ≥ ~1000 samples"). Below it we fit a 2-parameter Platt sigmoid (parametric, small-N-safe);
    /// at or above it we keep the existing Wilson-lower-bound + isotonic path BYTE-IDENTICAL.
    /// 1000 is the canonical lower edge of the isotonic-reliable range — the conservative choice
    /// (a retail journal is far below it, so it almost always takes the Platt branch).
    nonisolated static let isotonicMinSamples = 1000

    /// Fit from realized outcomes. Returns nil when too few samples to calibrate honestly.
    /// - binCount: MAX equal-width conviction bands over [0,1] (the effective count adapts down to
    ///   keep ~`minPerBin` samples/band on small samples — see below).
    /// - minSamples: total-trade floor below which we don't trust a calibration.
    /// - minPerBin: target samples per band; the effective bin count is capped so bands aren't starved.
    /// - z: Wilson z-score for the lower bound (1.0 ≈ a ~84% one-sided LCB — conservative, not paranoid).
    /// - prior: win-prob assigned to EMPTY bands before isotonic smoothing.
    nonisolated static func fit(_ outcomes: [(conviction: Double, won: Bool)],
                                binCount: Int = 5, minSamples: Int = 30, minPerBin: Int = 20,
                                z: Double = 1.0, prior: Double = 0.5) -> StockSageConvictionCalibration? {
        guard binCount > 0, outcomes.count >= minSamples else { return nil }
        // [AUDIT] Selection seam. <1000 → Platt (parametric, small-N-safe); ≥1000 → the existing
        // Wilson+isotonic path, reached BYTE-IDENTICALLY (same args threaded through unchanged).
        if outcomes.count < isotonicMinSamples {
            return fitPlatt(outcomes, binCount: binCount, minPerBin: minPerBin, prior: prior)
        }
        return fitIsotonic(outcomes, binCount: binCount, minPerBin: minPerBin, z: z, prior: prior)
    }

    /// The existing Wilson-lower-bound + isotonic fit, unchanged. Reached only for ≥isotonicMinSamples
    /// outcomes, so for every history that took this path before, it is byte-for-byte identical.
    private nonisolated static func fitIsotonic(_ outcomes: [(conviction: Double, won: Bool)],
                                                binCount: Int, minPerBin: Int,
                                                z: Double, prior: Double) -> StockSageConvictionCalibration? {
        // Adapt the band count to sample size: too many bands with too few samples each over-fits —
        // the documented small-sample failure mode of isotonic/binned calibration (Niculescu-Mizil &
        // Caruana 2005, which prefers Platt below ~1–2k samples). Keep ≥ ~minPerBin samples/band on
        // average; the Wilson lower bound + monotonic pooling below add further conservatism. A
        // 60-trade backtest → 3 bands, not 5; a 30-trade one → 2.
        let nBins = Swift.max(2, Swift.min(binCount, Swift.max(1, outcomes.count / Swift.max(1, minPerBin))))

        // 1. Bucket by conviction into equal-width bands.
        var wins = [Int](repeating: 0, count: nBins)
        var total = [Int](repeating: 0, count: nBins)
        for o in outcomes {
            let c = Swift.max(0, Swift.min(1, o.conviction))
            let idx = Swift.min(nBins - 1, Int(c * Double(nBins)))   // c == 1.0 → last band
            total[idx] += 1
            if o.won { wins[idx] += 1 }
        }

        // 2. Per-band conservative win prob (Wilson lower bound); empty bands take the prior.
        var values = [Double](repeating: prior, count: nBins)
        var weights = [Double](repeating: 0.5, count: nBins)   // empty bands: tiny weight, easily pooled
        for k in 0..<nBins where total[k] > 0 {
            values[k] = wilsonLowerBound(wins: wins[k], n: total[k], z: z)
            weights[k] = Double(total[k])
        }

        // 3. Isotonic (non-decreasing) regression via pool-adjacent-violators, weighted by n.
        let smoothed = poolAdjacentViolators(values, weights: weights)

        // 4. Emit ascending bands with their upper edges.
        let width = 1.0 / Double(nBins)
        let bins = (0..<nBins).map { k in
            Bin(upper: Double(k + 1) * width, winProb: smoothed[k], n: total[k])
        }
        return StockSageConvictionCalibration(bins: bins, sampleSize: outcomes.count)
    }

    /// [AUDIT] Platt scaling: P(win | s) = 1 / (1 + exp(A·s + B)) fit by MLE on (conviction s,
    /// realized-win y) with Platt's target smoothing — the small-N-safe parametric alternative to
    /// isotonic. Deterministic (fixed init, bounded Newton). Produces the SAME [Bin] substrate as the
    /// isotonic path (sigmoid evaluated at each band's midpoint), so winProb(_:)/bins/sampleSize and
    /// every downstream consumer are unchanged. Monotone non-decreasing iff A ≤ 0, which we enforce.
    private nonisolated static func fitPlatt(_ outcomes: [(conviction: Double, won: Bool)],
                                             binCount: Int, minPerBin: Int,
                                             prior: Double) -> StockSageConvictionCalibration? {
        let n = outcomes.count
        let nPos = outcomes.lazy.filter { $0.won }.count          // [AUDIT] N+
        let nNeg = n - nPos                                        // [AUDIT] N-

        // [AUDIT] Band count: SAME adaptive rule as the isotonic path so the two paths emit an
        // identically-shaped Bin array (display parity). 40 trades → 2 bands, etc.
        let nBins = Swift.max(2, Swift.min(binCount, Swift.max(1, n / Swift.max(1, minPerBin))))
        let width = 1.0 / Double(nBins)

        // [AUDIT] Per-band realized n (transparency only — Platt fits on the raw pairs, NOT bins, so
        // tail bands keep their true sparse n; calibration does NOT flatten the distribution).
        var total = [Int](repeating: 0, count: nBins)
        for o in outcomes {
            let c = Swift.max(0, Swift.min(1, o.conviction))
            total[Swift.min(nBins - 1, Int(c * Double(nBins)))] += 1
        }

        // [AUDIT] Degenerate guards → fall back to the conservative flat prior (same shape the
        // isotonic empty-band case uses). A one-sided sample (no winner OR no loser) cannot identify
        // a slope; inventing one would be the small-N overfit Platt exists to avoid.
        guard nPos > 0, nNeg > 0 else {
            let bins = (0..<nBins).map { k in
                Bin(upper: Double(k + 1) * width, winProb: Swift.max(0, Swift.min(1, prior)), n: total[k])
            }
            return StockSageConvictionCalibration(bins: bins, sampleSize: n)
        }

        // [AUDIT] Platt target smoothing (Platt 1999; Lin–Lin–Weng 2007). GLOBAL counts:
        //   t+ = (N+ + 1)/(N+ + 2)   t- = 1/(N- + 2)
        let tPos = (Double(nPos) + 1.0) / (Double(nPos) + 2.0)    // [AUDIT]
        let tNeg = 1.0 / (Double(nNeg) + 2.0)                     // [AUDIT]

        // [AUDIT] Standard Platt init: A = 0, B = ln((N- + 1)/(N+ + 1)) — the all-features-zero log-odds.
        var A = 0.0
        var B = Foundation.log((Double(nNeg) + 1.0) / (Double(nPos) + 1.0))

        // [AUDIT] Newton's method on the cross-entropy of the smoothed targets. Bounded to 25 iters,
        // early-exit on ‖Δ‖ < 1e-12. dL/dz = (t − p), Hessian weight w = p(1−p), z = A·s + B.
        // (Verified: converges to full double precision by ~iter 5 on the golden set.)
        let smoothed = outcomes.map { o -> (s: Double, t: Double) in
            (s: Swift.max(0, Swift.min(1, o.conviction)), t: o.won ? tPos : tNeg)
        }
        for _ in 0..<25 {
            var g0 = 0.0, g1 = 0.0, h00 = 0.0, h01 = 0.0, h11 = 0.0
            for st in smoothed {
                let fz = A * st.s + B
                let p = 1.0 / (1.0 + Foundation.exp(fz))          // [AUDIT] sigmoid(−z)
                let dz = st.t - p
                let w = p * (1.0 - p)
                g0 += dz * st.s;  g1 += dz
                h00 += w * st.s * st.s;  h01 += w * st.s;  h11 += w
            }
            let det = h00 * h11 - h01 * h01                       // [AUDIT]
            guard abs(det) > 1e-12 else { break }                 // singular → stop at current estimate
            let dA = (h11 * g0 - h01 * g1) / det                  // [AUDIT] H⁻¹·g, row 0
            let dB = (h00 * g1 - h01 * g0) / det                  // [AUDIT] H⁻¹·g, row 1
            A -= dA;  B -= dB
            if abs(dA) + abs(dB) < 1e-12 { break }                // [AUDIT] converged
        }

        // [AUDIT] Monotonicity clamp: winProb is non-decreasing in conviction iff A ≤ 0 (since
        // p = 1/(1+e^{A·s+B}) decreases in (A·s+B)). A degenerate fit could land A > 0 (e.g. a tiny,
        // noisy inverted sample); clamp A to ≤ 0 so a higher conviction can NEVER map to a lower
        // win-prob. CRITICAL: when A is clamped, also re-anchor B to the smoothed prior log-odds
        // (= B_init = ln((N-+1)/(N++1))). Leaving B at the Newton-converged value (which was
        // co-fitted for the now-discarded positive slope) produces a flat sigmoid far above the true
        // base rate — e.g. 88.5% vs 50% on a symmetric inverted sample — which inflates Kelly EV
        // for every conviction band and violates the module's conservatism contract.
        if A > 0 {
            A = 0
            B = Foundation.log((Double(nNeg) + 1.0) / (Double(nPos) + 1.0))  // [AUDIT] reset to prior log-odds
        }

        // [AUDIT] Emit the SAME Bin substrate: evaluate the (now monotone) sigmoid at each band's
        // MIDPOINT and clamp to [0,1]. Midpoint (not edge) is the band's representative conviction,
        // matching winProb(_:)'s "value for the whole band" contract. Non-decreasing midpoints +
        // A ≤ 0 ⇒ bins are non-decreasing by construction.
        let bins = (0..<nBins).map { k -> Bin in
            let mid = (Double(k) + 0.5) * width                   // [AUDIT] band-k center
            let p = 1.0 / (1.0 + Foundation.exp(A * mid + B))     // [AUDIT]
            return Bin(upper: Double(k + 1) * width,
                       winProb: Swift.max(0, Swift.min(1, p)), n: total[k])
        }
        return StockSageConvictionCalibration(bins: bins, sampleSize: n)
    }

    /// Wilson score interval LOWER bound for a binomial proportion — well-behaved for small n
    /// (unlike the naive p̂ ± z·SE), and never below 0. Conservative by design.
    nonisolated static func wilsonLowerBound(wins: Int, n: Int, z: Double = 1.0) -> Double {
        guard n > 0 else { return 0 }
        let nD = Double(n), p = Double(wins) / nD, z2 = z * z
        let denom = 1 + z2 / nD
        let center = p + z2 / (2 * nD)
        let margin = z * ((p * (1 - p) + z2 / (4 * nD)) / nD).squareRoot()
        return Swift.max(0, (center - margin) / denom)
    }

    /// Pool-adjacent-violators: the L2-optimal non-decreasing fit to `y` with weights `w`.
    /// Merges any block whose value would exceed its right neighbour, replacing both with their
    /// weighted mean, until the sequence is monotone non-decreasing.
    nonisolated static func poolAdjacentViolators(_ y: [Double], weights w: [Double]) -> [Double] {
        guard y.count == w.count, !y.isEmpty else { return y }
        struct Block { var value: Double; var weight: Double; var count: Int }
        var blocks: [Block] = []
        for k in 0..<y.count {
            var b = Block(value: y[k], weight: Swift.max(w[k], 1e-9), count: 1)
            while let last = blocks.last, last.value > b.value {
                blocks.removeLast()
                let wgt = last.weight + b.weight
                b = Block(value: (last.value * last.weight + b.value * b.weight) / wgt,
                          weight: wgt, count: last.count + b.count)
            }
            blocks.append(b)
        }
        var out: [Double] = []
        out.reserveCapacity(y.count)
        for b in blocks { out.append(contentsOf: repeatElement(b.value, count: b.count)) }
        return out
    }
}

// MARK: - Build straight from backtest trades
extension StockSageConvictionCalibration {
    /// Fit from walk-forward backtest trades (a win is a positive realized R). nil when too thin.
    nonisolated static func fit(fromBacktest trades: [BacktestTrade],
                                binCount: Int = 5, minSamples: Int = 30,
                                z: Double = 1.0, prior: Double = 0.5) -> StockSageConvictionCalibration? {
        fit(trades.map { (conviction: $0.conviction, won: $0.r > 0) },
            binCount: binCount, minSamples: minSamples, z: z, prior: prior)
    }

    /// Fit from the owner's JOURNAL — their OWN realized executions (fills, slippage, discipline),
    /// which the sample-universe backtest can't capture. Only CLOSED trades that carry a conviction
    /// contribute (a win = realized R > 0); manual trades without a conviction are excluded. nil when
    /// too thin — the caller keeps the backtest fit / conservative prior.
    nonisolated static func fit(fromJournal trades: [TradeRecord],
                                binCount: Int = 5, minSamples: Int = 30,
                                z: Double = 1.0, prior: Double = 0.5) -> StockSageConvictionCalibration? {
        let outcomes = trades.compactMap { t -> (conviction: Double, won: Bool)? in
            guard let c = t.conviction, let r = t.realizedR else { return nil }
            return (conviction: c, won: r > 0)
        }
        return fit(outcomes, binCount: binCount, minSamples: minSamples, z: z, prior: prior)
    }

    /// Chronological train/test split of CLOSED journal trades for OUT-OF-SAMPLE calibration validation:
    /// fit the conviction→win-prob map on `train`, then score it on `test` — trades it never saw. Trades
    /// are ordered by CLOSE time; the most recent `testFraction` become the test set, and `embargo`
    /// trades straddling the boundary are DROPPED (purge) so a position whose window spans the split can't
    /// leak its outcome across. Returns empty sets when too few closed trades to split honestly.
    /// (The backtest's headline R/Sharpe/t carry no such leakage — those rules don't use the calibration;
    /// the calibration is the only FITTED component, so it's the one that needs OOS validation.)
    nonisolated static func chronologicalSplit(_ trades: [TradeRecord],
                                               testFraction: Double = 0.3,
                                               embargo: Int = 1) -> (train: [TradeRecord], test: [TradeRecord]) {
        let closed = trades.filter { $0.closedAt != nil }
            .sorted { ($0.closedAt ?? .distantPast) < ($1.closedAt ?? .distantPast) }
        let f = Swift.max(0, Swift.min(1, testFraction))
        let n = closed.count
        let testN = Int((Double(n) * f).rounded())
        let gap = Swift.max(0, embargo)
        guard testN >= 1, n - testN - gap >= 1 else { return (train: [], test: []) }
        let trainEnd = n - testN - gap   // [0, trainEnd) train · [trainEnd, n-testN) embargoed · [n-testN, n) test
        return (train: Array(closed[0..<trainEnd]), test: Array(closed[(n - testN)..<n]))
    }

    /// Out-of-sample quality of the conviction→win-prob map: fit on the chronological TRAIN slice, then
    /// score the held-out TEST slice it never saw. `oosBrier`/`oosLogLoss` are proper scores (lower =
    /// better); `baselineBrier` is the no-skill predictor (TRAIN base win-rate for every test trade). The
    /// map only EARNS its place if it beats that baseline OOS (`addsSkill`). nil when too thin to fit/score.
    /// Honest + small-sample-noisy by nature — a few-dozen-trade journal gives a wide, jumpy estimate.
    struct OOSCalibrationCheck: Sendable, Equatable {
        let oosBrier: Double
        let baselineBrier: Double
        let oosLogLoss: Double
        let n: Int
        /// The calibration generalizes only if it beats the no-skill base-rate predictor out-of-sample.
        nonisolated var addsSkill: Bool { oosBrier < baselineBrier }
    }

    nonisolated static func validateOutOfSample(_ trades: [TradeRecord],
                                                testFraction: Double = 0.3, embargo: Int = 1,
                                                minTrainSamples: Int = 30) -> OOSCalibrationCheck? {
        let (train, test) = chronologicalSplit(trades, testFraction: testFraction, embargo: embargo)
        guard let cal = fit(fromJournal: train, minSamples: minTrainSamples) else { return nil }
        // No-skill baseline = the TRAIN base win-rate (what you'd predict knowing nothing about conviction).
        let trainWon = train.compactMap { t -> Bool? in
            guard t.conviction != nil, let r = t.realizedR else { return nil }
            return r > 0
        }
        guard !trainWon.isEmpty else { return nil }
        let baseRate = Double(trainWon.filter { $0 }.count) / Double(trainWon.count)

        let eps = 1e-9
        var brier = 0.0, baseBrier = 0.0, logloss = 0.0, count = 0
        for t in test {
            guard let c = t.conviction, let r = t.realizedR else { continue }
            let a = r > 0 ? 1.0 : 0.0
            let p = Swift.max(eps, Swift.min(1 - eps, cal.winProb(c)))
            brier += (p - a) * (p - a)
            baseBrier += (baseRate - a) * (baseRate - a)
            logloss += -(a * Foundation.log(p) + (1 - a) * Foundation.log(1 - p))
            count += 1
        }
        guard count >= 1 else { return nil }
        let nD = Double(count)
        return OOSCalibrationCheck(oosBrier: brier / nD, baselineBrier: baseBrier / nD,
                                   oosLogLoss: logloss / nD, n: count)
    }
}
