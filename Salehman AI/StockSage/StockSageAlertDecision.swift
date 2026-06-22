import Foundation

// MARK: - Alert decision (what's worth a notification)
//
// Pure, stateless decision: given a symbol's current state + a little prior context
// (its previous price, and the recommendation it was LAST alerted on), decide whether
// THIS update warrants a fresh notification — and never re-fire the same one. Keeping
// this pure means the (@MainActor, side-effecting) monitor stays a thin shell over a
// tested rule. Honest: an alert flags an EVENT, not a profit — act with your own plan.

struct StockSageAlert: Sendable, Equatable {
    enum Kind: String, Sendable {
        case newStrongBuy  = "Strong Buy"
        case newStrongSell = "Strong Sell"
        case flip          = "Signal flip"
        case stopBreach    = "Stop breached"
        case targetHit     = "Target hit"
    }
    let symbol: String
    let kind: Kind
    let reason: String
}

enum StockSageAlertDecision {
    /// Decide the single most-actionable alert for this update, or nil to stay silent.
    /// Priority: a price level CROSSED this bar (stop, then target) beats a signal change;
    /// signal alerts dedupe against `lastAlertedRecommendation` so the same one never repeats.
    nonisolated static func evaluate(symbol: String,
                                     recommendation: StockSageRecommendation,
                                     price: Double,
                                     priorPrice: Double,
                                     stop: Double?,
                                     target: Double?,
                                     lastAlertedRecommendation: StockSageRecommendation?) -> StockSageAlert? {
        // 1. Stop crossed DOWN through the level this update (priorPrice above, now at/below).
        if let s = stop, s > 0, priorPrice > s, price <= s {
            return StockSageAlert(symbol: symbol, kind: .stopBreach,
                                  reason: "\(symbol) hit its stop (\(fmt(price)) ≤ \(fmt(s))) — the setup is invalidated; risk is realized.")
        }
        // 2. Target crossed UP through the level this update.
        if let t = target, t > 0, priorPrice < t, price >= t {
            return StockSageAlert(symbol: symbol, kind: .targetHit,
                                  reason: "\(symbol) reached its target (\(fmt(price)) ≥ \(fmt(t))) — consider taking profit or trailing the stop.")
        }
        // 3. Strong-signal events only (buy/sell/hold don't notify), deduped vs last alert.
        let isStrong = recommendation == .strongBuy || recommendation == .strongSell
        guard isStrong, recommendation != lastAlertedRecommendation else { return nil }

        let flipped = (recommendation == .strongBuy && lastAlertedRecommendation == .strongSell)
            || (recommendation == .strongSell && lastAlertedRecommendation == .strongBuy)
        if flipped {
            return StockSageAlert(symbol: symbol, kind: .flip,
                                  reason: "\(symbol) FLIPPED to \(recommendation.rawValue) — re-evaluate any open position.")
        }
        return StockSageAlert(symbol: symbol,
                              kind: recommendation == .strongBuy ? .newStrongBuy : .newStrongSell,
                              reason: "\(symbol): new \(recommendation.rawValue) signal — check the plan before acting.")
    }

    private nonisolated static func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
}
