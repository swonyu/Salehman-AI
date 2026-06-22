import Foundation

// MARK: - Expected value (the "what's the best BET" score)
//
// Signal strength ranks how confident the RULES are; expected value ranks how much
// you can EXPECT to make. EV (in R) = pWin·rewardR − (1−pWin)·1, where the loss is
// −1R (a stop-out) and rewardR is the reward:risk ratio. The catch: pWin is an
// ESTIMATE — the advisor's conviction is NOT a probability, so we map it into a
// deliberately conservative band and SAY it's an estimate. EV ranks opportunities
// by payoff, but it is not a promise; over-betting a positive-EV edge still ruins.

struct ExpectedValue: Sendable, Equatable {
    let winProbEstimate: Double   // 0–1, an ESTIMATE derived from conviction
    let rewardR: Double           // reward:risk
    let evR: Double               // expected R per trade
    nonisolated var isPositive: Bool { evR > 0 }
}

enum StockSageExpectedValue {
    /// Conviction (0–1) → an estimated win probability in a conservative band:
    /// 0 → 35%, 1 → 58%. Never claims high certainty; conviction ≠ probability.
    nonisolated static func winProbEstimate(conviction: Double) -> Double {
        0.35 + Swift.max(0, Swift.min(1, conviction)) * 0.23
    }

    /// Expected value in R: pWin·rewardR − (1−pWin)·1. nil if there's no defined
    /// risk or reward (entry==stop or no target).
    nonisolated static func ev(conviction: Double, entry: Double, stop: Double, target: Double) -> ExpectedValue? {
        let risk = abs(entry - stop), reward = abs(target - entry)
        guard risk > 0, reward > 0 else { return nil }
        let rewardR = reward / risk
        let p = winProbEstimate(conviction: conviction)
        return ExpectedValue(winProbEstimate: p, rewardR: rewardR, evR: p * rewardR - (1 - p))
    }

    /// EV for a ranked idea, or nil when it lacks a stop/target (no defined R:R).
    nonisolated static func ev(for idea: StockSageIdea) -> ExpectedValue? {
        guard let stop = idea.advice.stopPrice, let target = idea.advice.targetPrice else { return nil }
        return ev(conviction: idea.advice.conviction, entry: idea.price, stop: stop, target: target)
    }

    /// Ideas sorted by EV (best bet first). Ideas without a defined EV fall to the
    /// bottom keeping their original relative order (stable).
    nonisolated static func rankByEV(_ ideas: [StockSageIdea]) -> [StockSageIdea] {
        ideas.enumerated().sorted { a, b in
            switch (ev(for: a.element)?.evR, ev(for: b.element)?.evR) {
            case let (x?, y?): return x == y ? a.offset < b.offset : x > y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map(\.element)
    }

    /// The single best BET right now: the buy-family idea with the highest POSITIVE
    /// expected value. nil if no buy idea has positive EV (don't manufacture one).
    nonisolated static func bestOpportunity(_ ideas: [StockSageIdea]) -> (idea: StockSageIdea, ev: ExpectedValue)? {
        ideas.compactMap { idea -> (StockSageIdea, ExpectedValue)? in
            guard idea.advice.action == .buy || idea.advice.action == .strongBuy,
                  let e = ev(for: idea), e.evR > 0 else { return nil }
            return (idea, e)
        }
        .max { $0.1.evR < $1.1.evR }
        .map { (idea: $0.0, ev: $0.1) }
    }

    nonisolated static let caveat =
        "EV uses an ESTIMATED win probability from conviction (not a real probability) and a −1R loss. It ranks payoff, it doesn't predict it — size with the cap and a stop."
}
