import Foundation

// MARK: - Today's plan
//
// Composes the already-tested pieces — the best positive-EV opportunity, its pre-trade
// GATE verdict, and the position SIZE — into one copyable, ordered checklist: "here's
// the single best thing to do right now, whether the gate clears it, and exactly how
// big." Pure builder over verified engines. Honesty: estimates, not advice; clearing
// the gate isn't a win, it's "not obviously reckless."

enum StockSageTodayPlan {
    /// Build the plan text for one idea (typically the best opportunity). Returns a
    /// multi-line checklist. `account`/`riskFraction` add the concrete share size when set.
    nonisolated static func build(idea: StockSageIdea, ev: ExpectedValue?,
                                  account: Double?, riskFraction: Double?,
                                  daysToEarnings: Int? = nil, isSample: Bool = false) -> String {
        let a = idea.advice
        let entry = idea.price
        let rf = Swift.max(0, riskFraction ?? 0)
        let rr: Double? = {
            guard let s = a.stopPrice, let t = a.targetPrice else { return nil }
            let risk = abs(entry - s)
            guard risk > 0 else { return nil }
            let gross = abs(t - entry) / risk
            // Gate on NET reward:risk (after asset-class round-trip costs) — same source of truth as
            // the on-screen gate, so the copied plan can't disagree. Falls back to gross.
            return StockSageNetEdge.netRR(symbol: idea.symbol, entry: entry, stop: s, target: t) ?? gross
        }()
        let gate = StockSageTradeGate.evaluate(hasStop: a.stopPrice != nil, rewardToRisk: rr,
                                               riskFraction: rf > 0 ? rf : 0.01, daysToEarnings: daysToEarnings)

        var lines = ["Today's plan — estimates, not advice. Size with a stop; risk control > signal."]
        // The copied plan is the one artifact pasted into a broker — it MUST carry the
        // SAMPLE-data warning the on-screen banner shows, so a seed price isn't acted on as real.
        if isSample {
            lines.insert("⚠ SAMPLE DATA — illustrative prices, NOT live quotes. Re-price before any order.", at: 0)
        }
        var n = 1
        lines.append("\(n). Best bet: \(idea.symbol) (\(a.action.rawValue))"
            + (ev.map { String(format: " — est. EV %+.2fR", $0.evR) } ?? "")); n += 1

        let gateExtra = (gate.fails > 0 || gate.warns > 0) ? " (\(gate.fails) fail, \(gate.warns) warn)" : ""
        lines.append("\(n). Gate: \(gate.decision.rawValue)\(gateExtra)"); n += 1

        if let s = a.stopPrice {
            var size = ""
            if let acct = account, acct > 0, rf > 0,
               let ps = StockSagePositionSizer.size(account: acct, riskFraction: rf, entry: entry, stop: s) {
                size = " — \(ps.shares) shares ≈ \(Int(ps.dollarsAtRisk.rounded())) at risk (\(Int(ps.pctOfAccount.rounded()))% of acct)"
            }
            lines.append("\(n). Entry ~\(fmt(entry)), stop \(fmt(s))"
                + (a.targetPrice.map { ", target \(fmt($0))" } ?? "") + size); n += 1
        } else {
            lines.append("\(n). No stop defined — DO NOT enter until you set one (risk is undefined)."); n += 1
        }

        lines.append("\(n). Rule: risk small per trade, always a stop, never chase. The gate and EV are estimates, not a forecast.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Ranked action list (FASTMONEY_BACKLOG #4)
    //
    // "Do I take #1 or #2 today?" — collapses the fast lane's top-N by velocity into one
    // glance: the number (velocity), the concrete order (entry/stop/target), the SIZE
    // (PositionSizer, same flat per-trade risk% every other card uses), and the pre-trade
    // GATE verdict (TradeGate, same net-RR source of truth `build` already uses). Pure
    // composition over already-tested engines — fastLane() supplies the order and the
    // positive-EV filter, so this adds no new signal or ranking math.

    /// Top-`max` ranked "what do I do today" plans, ordered exactly as `StockSageExpectedValue.
    /// fastLane` ranks them (fastest compounding, positive-EV only). `account`/`riskFraction`
    /// add the concrete share size when set (nil/0 ⇒ no size, matching `build`'s own fallback).
    /// `calibration`/`earnings` are optional pass-throughs to the same-named engines so the
    /// gate and the number can't disagree with the rest of the board; both default to "none",
    /// i.e. the uncalibrated linear prior and no earnings demotion.
    nonisolated static func rankedActions(_ ideas: [StockSageIdea], account: Double?, riskFraction: Double?,
                                         holds: VelocityHoldDays = .defaults,
                                         calibration: StockSageConvictionCalibration? = nil,
                                         earnings: [String: EarningsProximity] = [:],
                                         max: Int = 3) -> [TodayActionPlan] {
        let rf = Swift.max(0, riskFraction ?? 0)
        let gateRiskFraction = rf > 0 ? rf : 0.01   // same fallback `build` uses — the gate can't disagree
        let lane = StockSageExpectedValue.fastLane(ideas, holds: holds, calibration: calibration)
        var out: [TodayActionPlan] = []
        for idea in lane {
            guard out.count < Swift.max(0, max) else { break }
            // fastLane() already guarantees a defined stop+target (it requires `ev(for:)` != nil,
            // which itself requires both) — re-guarded here so this composer never force-unwraps
            // an assumption about another engine's internals.
            guard let stop = idea.advice.stopPrice, let target = idea.advice.targetPrice,
                  let v = StockSageExpectedValue.velocity(for: idea, holds: holds, calibration: calibration)
            else { continue }
            let entry = idea.price
            let rr: Double? = {
                let risk = abs(entry - stop)
                guard risk > 0 else { return nil }
                let gross = abs(target - entry) / risk
                // Same NET reward:risk source of truth `build` uses, so a plan in this list can't
                // clear the gate here and then block in the single-idea copy, or vice versa.
                return StockSageNetEdge.netRR(symbol: idea.symbol, entry: entry, stop: stop, target: target) ?? gross
            }()
            let gate = StockSageTradeGate.evaluate(hasStop: true, rewardToRisk: rr, riskFraction: gateRiskFraction,
                                                   daysToEarnings: earnings[idea.symbol.uppercased()]?.daysUntil)
            var shares: Int? = nil
            var dollarsAtRisk: Double? = nil
            if let acct = account, acct > 0, rf > 0,
               let ps = StockSagePositionSizer.size(account: acct, riskFraction: rf, entry: entry, stop: stop) {
                shares = ps.shares; dollarsAtRisk = ps.dollarsAtRisk
            }
            out.append(TodayActionPlan(symbol: idea.symbol, velocity: v, entry: entry, stop: stop, target: target,
                                       shares: shares, dollarsAtRisk: dollarsAtRisk, gate: gate,
                                       isCrypto: idea.symbol.uppercased().hasSuffix("-USD")))
        }
        return out
    }

    /// "Copy all N" clipboard text for a ranked list — one line per plan (symbol, velocity,
    /// entry/stop/target, size, gate), with the same honesty caveats `build`'s single-idea
    /// text carries. A blocked gate is called out explicitly so it can't be copied clean.
    nonisolated static func copyAllText(_ plans: [TodayActionPlan], isSample: Bool = false) -> String {
        var lines = ["Today's ranked actions — top \(plans.count) by velocity (EV/day). Estimates, not advice; a per-trade risk cap always applies."]
        if isSample {
            lines.insert("⚠ SAMPLE DATA — illustrative prices, NOT live quotes. Re-price before any order.", at: 0)
        }
        for (i, p) in plans.enumerated() {
            var line = "#\(i + 1). \(p.symbol)\(p.isCrypto ? " (24/7 crypto)" : "")"
                + " — \(String(format: "%+.3fR/day", p.velocity))"
                + " | entry \(fmt(p.entry)) stop \(fmt(p.stop)) target \(fmt(p.target))"
            if let sh = p.shares, let dr = p.dollarsAtRisk {
                line += " | \(sh) sh (≈$\(Int(dr.rounded())) at risk)"
            }
            line += " | \(p.gate.decision.rawValue)" + (p.gate.decision == .blocked ? " — DO NOT TRADE" : "")
            lines.append(line)
        }
        lines.append("Rule: risk small per trade, always a stop, never chase. A blocked gate means don't take it, however good the velocity looks.")
        return lines.joined(separator: "\n")
    }

    private nonisolated static func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
}

/// One row of `StockSageTodayPlan.rankedActions` — a ranked, sized, gated action for today.
/// `shares`/`dollarsAtRisk` are nil exactly when no account/riskFraction was supplied (mirrors
/// `build`'s own size fallback); `stop`/`target` are always defined because `fastLane()` only
/// ever includes ideas with both (it requires a non-nil `ev(for:)`, which itself requires both).
struct TodayActionPlan: Sendable, Equatable, Identifiable {
    let symbol: String
    let velocity: Double   // EV per day (R), the fastLane ranking number
    let entry: Double
    let stop: Double
    let target: Double
    let shares: Int?
    let dollarsAtRisk: Double?
    let gate: TradeGateVerdict
    let isCrypto: Bool     // symbol.hasSuffix("-USD") — the existing crypto predicate, shown upfront
    nonisolated var id: String { symbol }
}
