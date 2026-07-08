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
    /// `positions` (TODAY-PARITY, defaulted `[]` — existing callers/tests byte-unchanged) adds
    /// held-position context via `StockSagePortfolio.holding(for:in:)` — the same "you already
    /// hold N sh" awareness the ranked list (`rankedActions`) and the ideas board's Held chip
    /// already carry. Display-only: never affects the gate, size, or EV math.
    nonisolated static func build(idea: StockSageIdea, ev: ExpectedValue?,
                                  account: Double?, riskFraction: Double?,
                                  daysToEarnings: Int? = nil, isSample: Bool = false,
                                  positions: [PortfolioPosition] = []) -> String {
        let a = idea.advice
        let entry = idea.price
        let rf = Swift.max(0, riskFraction ?? 0)
        // Capture resolvedNetRR BEFORE the ?? gross collapse so rrIsNet can be set accurately:
        // pass true ONLY when netRR actually resolved (non-nil), never for the ?? gross fallback
        // which must stay labeled gross to avoid mislabeling a gross value as "Net reward:risk".
        let resolvedNetRR: Double? = {
            guard let s = a.stopPrice, let t = a.targetPrice else { return nil }
            return StockSageNetEdge.netRR(symbol: idea.symbol, entry: entry, stop: s, target: t)
        }()
        let rr: Double? = {
            guard let s = a.stopPrice, let t = a.targetPrice else { return nil }
            let risk = abs(entry - s)
            guard risk > 0 else { return nil }
            let gross = abs(t - entry) / risk
            // Gate on NET reward:risk (after asset-class round-trip costs) — same source of truth as
            // the on-screen gate, so the copied plan can't disagree. Falls back to gross.
            // (No financing threading here: `idea` reaching `build` always came from
            // `bestOpportunity`, which is buy-family only — financing would always be 0.)
            return resolvedNetRR ?? gross
        }()
        let gate = StockSageTradeGate.evaluate(hasStop: a.stopPrice != nil, rewardToRisk: rr,
                                               riskFraction: rf > 0 ? rf : 0.01, daysToEarnings: daysToEarnings,
                                               rrIsNet: resolvedNetRR != nil)

        var lines = ["Today's plan — estimates, not advice. Size with a stop; risk control > signal."]
        // The copied plan is the one artifact pasted into a broker — it MUST carry the
        // SAMPLE-data warning the on-screen banner shows, so a seed price isn't acted on as real.
        if isSample {
            lines.insert("⚠ SAMPLE DATA — illustrative prices, NOT live quotes. Re-price before any order.", at: 0)
        }
        var n = 1
        lines.append("\(n). Best bet: \(idea.symbol) (\(a.action.rawValue))"
            + (ev.map { String(format: " — est. EV %+.2fR (gross)", $0.evR) } ?? "")); n += 1

        let gateExtra = (gate.fails > 0 || gate.warns > 0) ? " (\(gate.fails) fail, \(gate.warns) warn)" : ""
        lines.append("\(n). Gate: \(gate.decision.rawValue)\(gateExtra)"); n += 1

        if let s = a.stopPrice {
            var size = ""
            if let acct = account, acct > 0, rf > 0,
               let ps = StockSagePositionSizer.size(account: acct, riskFraction: rf, entry: entry, stop: s) {
                size = " — \(ps.shares) shares ≈ \(Int(ps.dollarsAtRisk.rounded())) at risk (\(Int(ps.pctOfAccount.rounded()))% of acct)"
            }
            // TODAY-PARITY: pasted into a broker without knowing you already hold the name
            // silently stacks new risk on an existing position — same rationale as the ranked
            // list's "holds N sh" suffix (rankedActions/copyAllText above).
            if let held = StockSagePortfolio.holding(for: idea.symbol, in: positions) {
                size += " | holds \(numShares(held.shares)) sh"
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
    /// `positions`/`journalTrades` (TODAY-PARITY, defaulted `[]` — existing callers/tests
    /// byte-unchanged) populate each plan's optional `heldShares`/`closedTradeCount` via the
    /// SAME batch helpers the ideas board uses (`StockSagePortfolio.holdingBySymbol` /
    /// `StockSageJournal.historyBySymbol`) — display-only, no effect on ranking/sizing/gate.
    nonisolated static func rankedActions(_ ideas: [StockSageIdea], account: Double?, riskFraction: Double?,
                                         holds: VelocityHoldDays = .defaults,
                                         calibration: StockSageConvictionCalibration? = nil,
                                         earnings: [String: EarningsProximity] = [:],
                                         liquidity: [String: LiquidityProfile] = [:],
                                         positions: [PortfolioPosition] = [],
                                         journalTrades: [TradeRecord] = [],
                                         max: Int = 3) -> [TodayActionPlan] {
        let rf = Swift.max(0, riskFraction ?? 0)
        let gateRiskFraction = rf > 0 ? rf : 0.01   // same fallback `build` uses — the gate can't disagree
        let lane = StockSageExpectedValue.fastLane(ideas, holds: holds, calibration: calibration, earnings: earnings, liquidity: liquidity)
        let holdingsBySymbol = StockSagePortfolio.holdingBySymbol(in: positions)
        let historyBySymbol = StockSageJournal.historyBySymbol(in: journalTrades)
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
            // Capture resolvedNetRR BEFORE the ?? gross collapse so rrIsNet is accurate —
            // true only when netRR resolved non-nil. The ?? gross fallback must never be
            // labeled "Net reward:risk" to avoid mislabeling a gross value as net.
            let resolvedNetRR: Double? = StockSageNetEdge.netRR(symbol: idea.symbol, entry: entry, stop: stop, target: target)
            let rr: Double? = {
                let risk = abs(entry - stop)
                guard risk > 0 else { return nil }
                let gross = abs(target - entry) / risk
                // Same NET reward:risk source of truth `build` uses, so a plan in this list can't
                // clear the gate here and then block in the single-idea copy, or vice versa.
                // (No financing threading here: `fastLane()` is buy-family only via
                // `velocityRankKey`'s explicit guard — financing would always be 0.)
                return resolvedNetRR ?? gross
            }()
            let gate = StockSageTradeGate.evaluate(hasStop: true, rewardToRisk: rr, riskFraction: gateRiskFraction,
                                                   daysToEarnings: earnings[idea.symbol.uppercased()]?.daysUntil,
                                                   rrIsNet: resolvedNetRR != nil)
            var shares: Int? = nil
            var dollarsAtRisk: Double? = nil
            if let acct = account, acct > 0, rf > 0,
               let ps = StockSagePositionSizer.size(account: acct, riskFraction: rf, entry: entry, stop: stop) {
                shares = ps.shares; dollarsAtRisk = ps.dollarsAtRisk
            }
            // fastLane() ranks by a demotion-adjusted key (velocityRankKey) but does NOT filter
            // out below-floor/low-conviction ideas — they just sink in the ordering. So a row in
            // this top-N list CAN still be one of them; surface the SAME flags the main ideas
            // board already shows (netCostFloorFlag/isLowConviction) so the reason a plan ranked
            // where it did — or a caution about trusting it — is never hidden here.
            let floorFlag = StockSageExpectedValue.netCostFloorFlag(for: idea, holds: holds, calibration: calibration)
            let lowConviction = StockSageExpectedValue.isLowConviction(idea)
            let heldShares = holdingsBySymbol[idea.symbol.uppercased()]?.shares
            let closedTradeCount = historyBySymbol[idea.symbol.uppercased()]?.count
            out.append(TodayActionPlan(symbol: idea.symbol, velocity: v, entry: entry, stop: stop, target: target,
                                       shares: shares, dollarsAtRisk: dollarsAtRisk, gate: gate,
                                       isCrypto: idea.symbol.uppercased().hasSuffix("-USD"),
                                       netCostFloorFlag: floorFlag, isLowConviction: lowConviction,
                                       heldShares: heldShares, closedTradeCount: closedTradeCount))
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
                + " — \(String(format: "%+.3fR/day gross", p.velocity))"
                + " | entry \(fmt(p.entry)) stop \(fmt(p.stop)) target \(fmt(p.target))"
            if let sh = p.shares, let dr = p.dollarsAtRisk {
                line += " | \(sh) sh (≈$\(Int(dr.rounded())) at risk)"
            }
            // EXPORT-01 precedent: the exported checklist carries the same doubling-hazard
            // context the on-screen row does — acting on this line without knowing you already
            // hold the name silently stacks new risk on an existing position.
            if let held = p.heldShares { line += " | holds \(numShares(held)) sh" }
            line += " | \(p.gate.decision.rawValue)" + (p.gate.decision == .blocked ? " — DO NOT TRADE" : "")
            if p.netCostFloorFlag.isDeranked { line += " | ⚠ below net-cost floor" }
            if p.isLowConviction { line += " | ⚠ low conviction" }
            lines.append(line)
        }
        lines.append("Rule: risk small per trade, always a stop, never chase. A blocked gate means don't take it, however good the velocity looks.")
        return lines.joined(separator: "\n")
    }

    /// ALERT-FMT-1: thin alias onto the single shared formatter (`StockSageCurrency.adaptivePrice`,
    /// pure, tested there) — keeps call sites below unchanged in shape.
    private nonisolated static func fmt(_ v: Double) -> String { StockSageCurrency.adaptivePrice(v) }

    /// Share-count formatter matching `MarketsView.numString` — %.0f, not `String(Int(d))`,
    /// because `Int(Double)` TRAPS past `Int.max` and a persisted pathological share count
    /// would crash on export the same way it would crash the board's own render.
    private nonisolated static func numShares(_ d: Double) -> String {
        d == d.rounded() ? String(format: "%.0f", d) : String(format: "%.2f", d)
    }
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
    /// Same de-rank flag the main ideas/velocity boards already show (`StockSageExpectedValue.
    /// netCostFloorFlag`) — `fastLane()` demotes but does NOT exclude below-floor ideas from its
    /// ordering, so a plan in this list can legitimately be one. Defaulted `.clears` so any other
    /// construction site (tests) stays valid without threading it through.
    var netCostFloorFlag: StockSageExpectedValue.NetCostFloorFlag = .clears
    /// Same low-conviction demotion the rank-key math already applies internally
    /// (`StockSageExpectedValue.isLowConviction`) — again demoted, not excluded, from `fastLane()`.
    var isLowConviction: Bool = false
    /// TODAY-PARITY: shares already held of this symbol, aggregated across lots
    /// (`StockSagePortfolio.holdingBySymbol`) — the same held-position awareness the ideas board's
    /// "Held · N sh" chip already shows. DISPLAY-ONLY: never feeds ranking, sizing, or the gate.
    /// nil when `rankedActions` wasn't given `positions` (existing callers/tests unaffected).
    var heldShares: Double? = nil
    /// TODAY-PARITY: closed-trade count for this symbol from the journal
    /// (`StockSageJournal.historyBySymbol`) — same display-only awareness as `heldShares`.
    /// nil when `rankedActions` wasn't given `journalTrades`.
    var closedTradeCount: Int? = nil
    nonisolated var id: String { symbol }
}
