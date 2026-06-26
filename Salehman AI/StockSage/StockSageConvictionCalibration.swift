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

    /// Fit from realized outcomes. Returns nil when too few samples to calibrate honestly.
    /// - binCount: equal-width conviction bands over [0,1].
    /// - minSamples: total-trade floor below which we don't trust a calibration.
    /// - z: Wilson z-score for the lower bound (1.0 ≈ a ~84% one-sided LCB — conservative, not paranoid).
    /// - prior: win-prob assigned to EMPTY bands before isotonic smoothing.
    nonisolated static func fit(_ outcomes: [(conviction: Double, won: Bool)],
                                binCount: Int = 5, minSamples: Int = 30,
                                z: Double = 1.0, prior: Double = 0.5) -> StockSageConvictionCalibration? {
        guard binCount > 0, outcomes.count >= minSamples else { return nil }

        // 1. Bucket by conviction into equal-width bands.
        var wins = [Int](repeating: 0, count: binCount)
        var total = [Int](repeating: 0, count: binCount)
        for o in outcomes {
            let c = Swift.max(0, Swift.min(1, o.conviction))
            // c == 1.0 lands in the last band; index in 0..<binCount.
            let idx = Swift.min(binCount - 1, Int(c * Double(binCount)))
            total[idx] += 1
            if o.won { wins[idx] += 1 }
        }

        // 2. Per-band conservative win prob (Wilson lower bound); empty bands take the prior.
        var values = [Double](repeating: prior, count: binCount)
        var weights = [Double](repeating: 0.5, count: binCount)   // empty bands: tiny weight, easily pooled
        for k in 0..<binCount where total[k] > 0 {
            values[k] = wilsonLowerBound(wins: wins[k], n: total[k], z: z)
            weights[k] = Double(total[k])
        }

        // 3. Isotonic (non-decreasing) regression via pool-adjacent-violators, weighted by n.
        let smoothed = poolAdjacentViolators(values, weights: weights)

        // 4. Emit ascending bands with their upper edges.
        let width = 1.0 / Double(binCount)
        let bins = (0..<binCount).map { k in
            Bin(upper: Double(k + 1) * width, winProb: smoothed[k], n: total[k])
        }
        return StockSageConvictionCalibration(bins: bins, sampleSize: outcomes.count)
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
}
