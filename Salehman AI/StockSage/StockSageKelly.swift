import Foundation

// MARK: - Fractional Kelly position sizing
//
// The Kelly criterion gives the bet fraction that maximizes long-run geometric
// growth: f* = W − (1−W)/R, where W = win rate and R = payoff ratio (avg win ÷
// avg loss). But FULL Kelly is brutal — Gehm (1983) showed >50% drawdowns even
// with a real edge — so practitioners use a FRACTION (¼–½ Kelly), which cuts
// volatility far more than it cuts growth. Pure + deterministic → unit-tested.
// Honest: Kelly is only as good as your W and R estimates, which are usually
// optimistic; the caveat says so and the suggestion is capped.

struct KellyResult: Sendable, Equatable {
    let edge: Double              // expected value per unit risked: W·R − (1−W)
    let fullKelly: Double         // f* clamped to [0,1]
    let halfKelly: Double
    let quarterKelly: Double
    /// The recommended fraction: half-Kelly, hard-capped at 20% of the account.
    let suggestedFraction: Double
    let dollarsToRisk: Double      // suggestedFraction × accountSize
    let note: String
    let caveat: String
}

enum StockSageKelly {
    nonisolated static let caveat = "Kelly assumes your win-rate and payoff estimates are accurate — they rarely are. Use a fraction (¼–½) and a hard cap; over-betting compounds into ruin."

    /// Kelly inputs (W, R) implied by a backtest: W = win rate, R = avg-win-R ÷
    /// avg-loss-R. nil when the backtest lacks both a winner and a loser to form a
    /// real payoff ratio (a one-sided sample can't size honestly).
    nonisolated static func inputs(winRate: Double, avgWinR: Double, avgLossR: Double)
        -> (winRate: Double, payoffRatio: Double)? {
        guard avgWinR > 0, avgLossR > 0 else { return nil }
        return (winRate, avgWinR / avgLossR)
    }

    /// Never suggest risking more than this share of the account, whatever Kelly says.
    nonisolated static let maxFraction = 0.20

    /// Kelly from win rate `W` (0–1) and payoff ratio `R` (avg win ÷ avg loss).
    nonisolated static func compute(winRate: Double, payoffRatio: Double, accountSize: Double) -> KellyResult {
        let w = Swift.max(0, Swift.min(1, winRate))
        let r = Swift.max(0.0001, payoffRatio)          // guard divide-by-zero
        let edge = w * r - (1 - w)                       // EV per $1 risked
        // f* = W − (1−W)/R, clamped: a non-positive edge ⇒ 0 (don't bet).
        let fStar = Swift.max(0, Swift.min(1, w - (1 - w) / r))
        let half = fStar / 2
        let quarter = fStar / 4
        let suggested = Swift.min(maxFraction, half)

        let note: String
        if fStar <= 0 {
            note = "No positive edge — Kelly says don't bet."
        } else if half >= maxFraction {
            note = "Half-Kelly exceeds the \(Int(maxFraction * 100))% cap — capped for safety."
        } else {
            note = "Half-Kelly recommended; full Kelly risks deep drawdowns."
        }

        return KellyResult(edge: edge, fullKelly: fStar, halfKelly: half, quarterKelly: quarter,
                           suggestedFraction: suggested,
                           dollarsToRisk: suggested * Swift.max(0, accountSize),
                           note: note, caveat: caveat)
    }
}
