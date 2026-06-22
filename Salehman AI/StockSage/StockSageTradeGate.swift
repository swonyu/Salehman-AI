import Foundation

// MARK: - Pre-trade gate ("should I take this trade?")
//
// A single disciplined go/no-go verdict that composes the rules the owner already
// has into one answer BEFORE entering: is risk defined (a stop)? is it within the
// cap? is the reward skew acceptable? is there an earnings gap or a correlated-book
// concentration? It BLOCKS undefined-risk / over-sized trades, CAUTIONS on poor
// skew / event risk, and otherwise clears. Pure + deterministic.
//
// Honesty: a discipline checklist, NOT a profit signal — passing the gate does not
// mean the trade wins; it means it isn't obviously reckless. Risk control > signal.

struct TradeGateCheck: Sendable, Equatable {
    enum Level: String, Sendable { case pass, warn, fail }
    let level: Level
    let label: String
}

struct TradeGateVerdict: Sendable, Equatable {
    enum Decision: String, Sendable {
        case clear   = "Clear to trade"
        case caution = "Proceed with caution"
        case blocked = "Don't take this trade"
    }
    let decision: Decision
    let checks: [TradeGateCheck]
    nonisolated var caveat: String {
        "A discipline checklist, not a profit signal — clearing it means the trade isn't obviously reckless, not that it wins. Risk control > signal."
    }
    nonisolated var passes: Int { checks.filter { $0.level == .pass }.count }
    nonisolated var warns: Int { checks.filter { $0.level == .warn }.count }
    nonisolated var fails: Int { checks.filter { $0.level == .fail }.count }
}

enum StockSageTradeGate {
    /// Evaluate a proposed trade. Inputs are already-computed primitives so the gate is
    /// a pure decision over them (the caller supplies risk %, R:R, correlation, earnings).
    /// `rewardToRisk`/`maxCorrelation`/`daysToEarnings` are nil when unknown/not applicable.
    nonisolated static func evaluate(hasStop: Bool,
                                     rewardToRisk: Double?,
                                     riskFraction: Double,
                                     maxRiskFraction: Double = 0.02,
                                     maxCorrelation: Double? = nil,
                                     daysToEarnings: Int? = nil) -> TradeGateVerdict {
        var checks: [TradeGateCheck] = []

        // 1. A defined stop — without it, risk is undefined and sizing is meaningless.
        checks.append(hasStop
            ? TradeGateCheck(level: .pass, label: "Stop defined — risk is bounded")
            : TradeGateCheck(level: .fail, label: "No stop — risk is UNDEFINED; set one before entering"))

        // 2. Risk within the per-trade cap.
        if riskFraction <= 0 {
            checks.append(TradeGateCheck(level: .fail, label: "Risk fraction must be positive"))
        } else if riskFraction <= maxRiskFraction {
            checks.append(TradeGateCheck(level: .pass, label: String(format: "Risk %.1f%% within the %.1f%% cap", riskFraction * 100, maxRiskFraction * 100)))
        } else {
            checks.append(TradeGateCheck(level: .fail, label: String(format: "Risk %.1f%% EXCEEDS the %.1f%% cap — size down", riskFraction * 100, maxRiskFraction * 100)))
        }

        // 3. Reward:risk skew.
        if let rr = rewardToRisk {
            if rr >= 2 { checks.append(TradeGateCheck(level: .pass, label: String(format: "Reward:risk %.1f:1 — positive skew", rr))) }
            else if rr >= 1 { checks.append(TradeGateCheck(level: .warn, label: String(format: "Reward:risk %.1f:1 — thin; below 2:1", rr))) }
            else { checks.append(TradeGateCheck(level: .fail, label: String(format: "Reward:risk %.1f:1 — NEGATIVE skew; target below 1R", rr))) }
        } else {
            checks.append(TradeGateCheck(level: .warn, label: "No target set — define one to judge skew"))
        }

        // 4. Correlation with the existing book (concentration).
        if let c = maxCorrelation, c >= 0.8 {
            checks.append(TradeGateCheck(level: .warn, label: String(format: "Highly correlated (%.2f) with a holding — sizes as one bet, not two", c)))
        } else if let c = maxCorrelation {
            checks.append(TradeGateCheck(level: .pass, label: String(format: "Low correlation (%.2f) with the book — adds diversification", c)))
        }

        // 5. Earnings-gap proximity.
        if let d = daysToEarnings, d >= 0, d <= 3 {
            checks.append(TradeGateCheck(level: .warn, label: "Earnings in \(d) day\(d == 1 ? "" : "s") — overnight gap risk through the stop"))
        }

        let decision: TradeGateVerdict.Decision =
            checks.contains { $0.level == .fail } ? .blocked
            : (checks.contains { $0.level == .warn } ? .caution : .clear)
        return TradeGateVerdict(decision: decision, checks: checks)
    }
}
