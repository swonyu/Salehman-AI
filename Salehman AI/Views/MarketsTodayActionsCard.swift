import SwiftUI
import AppKit   // NSPasteboard for "Copy all N"

/// FASTMONEY_BACKLOG #4 — "Today's ranked action list": the top-N fast-lane setups (by
/// velocity, i.e. EV/day) collapsed to one row each — symbol, velocity, the concrete order
/// (entry/stop/target), the SIZE (shares + $ at risk, when an account/risk% are set), and the
/// pre-trade GATE verdict — so the owner doesn't have to open N detail sheets to decide "do I
/// take #1 or #2 today?" Pure display over `StockSageTodayPlan.rankedActions(...)`, which
/// composes only already-tested engines (`StockSageExpectedValue.fastLane`/`velocity`,
/// `StockSagePositionSizer.size`, `StockSageTradeGate.evaluate`) — no new signal, no new
/// ranking math. A blocked gate strikes the row through and badges "DO NOT TRADE" so a bad
/// setup can't be taken — or copied — clean.
struct MarketsTodayActionsCard: View {
    let plans: [TodayActionPlan]
    /// True when the on-screen prices are the seed/sample set, not live quotes — carried into
    /// the copied plan (same honesty rule as `StockSageTodayPlan.build`'s `isSample`).
    let isSampleData: Bool
    /// Called with the tapped row's symbol; the caller resolves it to a `StockSageIdea` (e.g.
    /// `store.ideas.first { $0.symbol == symbol }`) and opens its detail sheet.
    let onSelectSymbol: (String) -> Void
    @ObservedObject private var paperStore = StockSagePaperTradeStore.shared
    @State private var executableOnly = false

    @ScaledMetric(relativeTo: .caption2) private var font8: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var font9: CGFloat = 9

    /// ALERT-FMT-1: thin alias onto the single shared formatter (`StockSageCurrency.adaptivePrice`,
    /// pure, tested there) — keeps call sites below unchanged in shape.
    private func adaptivePrice(_ v: Double) -> String { StockSageCurrency.adaptivePrice(v) }

    /// Share-count formatter matching `MarketsView.numString` / `StockSageTodayPlan.numShares` —
    /// %.0f, not `String(Int(d))` (`Int(Double)` traps past `Int.max`).
    private func numShares(_ d: Double) -> String {
        d == d.rounded() ? String(format: "%.0f", d) : String(format: "%.2f", d)
    }

    var body: some View {
        // Matches fastLaneStrip's own "≥2 to be worth a board" threshold — a single ranked
        // action isn't a ranked LIST, and bestOpportunityCard already covers the lone-idea case.
        if plans.count >= 2 {
            let shownPlans = executableOnly ? plans.filter(isExecutableNow(_:)) : plans
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "list.number").font(.system(size: 11)).foregroundStyle(DS.Palette.accent)
                    Text("Today's plan — ranked by growth rate").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                    Toggle("Executable now only", isOn: $executableOnly)
                        .toggleStyle(.switch)
                        .font(.system(size: font8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text("Top \(shownPlans.count) fastest-compounding setups, sized and gated — do #1 first, unless it's blocked.")
                    .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Ranked by growth rate (log-growth at ½-Kelly) — a steady compounder can out-rank a higher-R/day but higher-variance setup. Shown R/day is raw EV, not the sort key.")
                    .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if executableOnly {
                    Text("Executable now includes only rows that currently clear or caution on the pre-trade gate.")
                        .font(.system(size: 8)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }

                executionRecommendationPanel(shownPlans)
                paperOutcomePanel

                if shownPlans.isEmpty {
                    Text("No executable rows at current risk settings. Lower risk %, or keep blocked rows visible.")
                        .font(.system(size: font9, weight: .medium)).foregroundStyle(DS.Palette.warningSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(shownPlans.enumerated()), id: \.element.id) { i, plan in
                        row(i + 1, plan)
                    }
                }

                HStack(spacing: 6) {
                    Spacer()
                    Button {
                        let text = StockSageTodayPlan.copyAllText(shownPlans, isSample: isSampleData)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Label("Copy all \(shownPlans.count)", systemImage: "doc.on.doc").font(.system(size: font9, weight: .medium))
                    }
                    .buttonStyle(.plain).foregroundStyle(DS.Palette.accent).disabled(shownPlans.isEmpty)
                    .help("Copy the ranked plan — entry/stop/target, size, and each gate verdict — to the clipboard. Estimates, not advice.")
                }
                if let weekly = weeklyExecutedVsBlockedMetric {
                    Text(weekly)
                        .font(.system(size: font8))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("A discipline checklist, not a profit signal — clearing the gate means the trade isn't obviously reckless, not that it wins.")
                    .font(.system(size: font9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Space.sm).frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Palette.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(DS.Palette.accent.opacity(0.25), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func executionRecommendationPanel(_ shownPlans: [TodayActionPlan]) -> some View {
        if let plan = shownPlans.first(where: { $0.gate?.decision != .blocked }) ?? shownPlans.first {
            let urgentEvent = (plan.daysToEarnings ?? Int.max) <= 3
            let timing = StockSageExecutionTiming.sessionNote(action: plan.action, regime: plan.regime)
            let blocked = plan.gate?.decision == .blocked
            let color: Color = blocked ? DS.Palette.dangerSoft : (urgentEvent ? DS.Palette.warningSoft : DS.Palette.successSoft)
            let headline: String = {
                if blocked { return "Execution recommendation: blocked setup for #1." }
                if urgentEvent { return "Execution recommendation: event-near setup, urgency-aware." }
                return "Execution recommendation: patient execution for #1." 
            }()
            let orderText: String = {
                if blocked { return "Do not place this order until the gate clears." }
                if urgentEvent {
                    return "If you still take it, a marketable near-close execution can be justified by event urgency; otherwise skip the trade."
                }
                return "Prefer a patient limit near the close; this is the lower-friction default for uninformed execution."
            }()
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
                Text("#1 \(plan.symbol): \(orderText)")
                    .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let timing {
                    Text("Timing note: \(timing)")
                        .font(.system(size: 8)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(color.opacity(0.35), lineWidth: 1))
        }
    }

    private func isExecutableNow(_ plan: TodayActionPlan) -> Bool {
        guard let decision = plan.gate?.decision else { return false }
        return decision != .blocked
    }

    @ViewBuilder
    private var paperOutcomePanel: some View {
        let (planned, realized, measured) = paperTodayStats

        if measured > 0 {
            let delta = realized - planned
            let color: Color = delta >= 0 ? DS.Palette.successSoft : DS.Palette.warningSoft
            VStack(alignment: .leading, spacing: 2) {
                Text("Paper today: realized vs planned (net-of-cost)")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
                Text(String(format: "%d close%@ today: planned %+.2fR vs realized %+.2fR (%+.2fR)",
                            measured, measured == 1 ? "" : "s", planned, realized, delta))
                    .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let fwd = paperStore.forwardStats {
                    Text(String(format: "Forward paper DSR %.0f%% (%d closed) — %@",
                                fwd.deflated.dsr * 100, fwd.closed,
                                fwd.passesForwardBar ? "passes bar" : "below bar"))
                        .font(.system(size: 8)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(color.opacity(0.35), lineWidth: 1))
        }
    }

    private var paperTodayStats: (planned: Double, realized: Double, measured: Int) {
        let nowDay = Int(Date().timeIntervalSince1970 / 86_400)
        let closedToday = paperStore.trades.filter {
            guard !$0.isOpen, let closedAt = $0.closedAt else { return false }
            return Int(closedAt.timeIntervalSince1970 / 86_400) == nowDay
        }
        var planned = 0.0
        var realized = 0.0
        var measured = 0
        for t in closedToday {
            guard let rr = t.realizedR else { continue }
            let risk = abs(t.entry - t.stop)
            guard risk > 0, let target = t.target else { continue }
            let plannedR: Double = t.side == .long ? (target - t.entry) / risk : (t.entry - target) / risk
            planned += plannedR
            realized += rr
            measured += 1
        }
        return (planned, realized, measured)
    }

    private var weeklyExecutedVsBlockedMetric: String? {
        let recent = paperStore.trades.filter {
            guard let closedAt = $0.closedAt else { return false }
            return closedAt >= Date().addingTimeInterval(-7 * 86_400)
        }
        let executed = recent.compactMap(\.realizedR)
        let executedCount = executed.count
        let executedTotal = executed.reduce(0, +)
        let executedAvg = executedCount > 0 ? (executedTotal / Double(executedCount)) : 0
        let blocked = plans.filter { $0.gate?.decision == .blocked }
        guard executedCount > 0 || !blocked.isEmpty else { return nil }
        let blockedPotential = blocked.reduce(0.0) { $0 + $1.velocity * 5.0 }
        let trend = executedAvg - blockedPotential
        let arrow = trend >= 0 ? "▲" : "▼"
        let direction = trend >= 0 ? "improving" : "deteriorating"
        return String(format: "7d execution vs blocked: %d closed, realized %+.2fR; currently blocked potential ~%+.2fR/week (velocity proxy). %@ %@(Δ %+.2fR).",
                      executedCount, executedTotal, blockedPotential, arrow, direction, trend)
    }

    @ViewBuilder
    private func row(_ rank: Int, _ plan: TodayActionPlan) -> some View {
        let blocked = plan.gate?.decision == .blocked
        Button { onSelectSymbol(plan.symbol) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Space.sm) {
                    Text("#\(rank)").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 16, alignment: .leading)
                    Text(plan.symbol).font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .strikethrough(blocked, color: DS.Palette.dangerSoft)
                    if plan.isCrypto {
                        Text("24/7").font(.system(size: font8)).foregroundStyle(DS.Palette.warningSoft)
                    }
                    Text(String(format: "%+.3fR/day gross", plan.velocity)).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Palette.successSoft)
                    // Same de-rank flags the main ideas/velocity boards already show — fastLane()
                    // demotes but does not EXCLUDE below-floor/low-conviction ideas, so a row here
                    // can legitimately be one; never hide the reason it ranked where it did.
                    if plan.netCostFloorFlag.isDeranked {
                        Text("below net-cost floor").font(.system(size: font8)).foregroundStyle(DS.Palette.warningSoft)
                    }
                    if plan.isLowConviction {
                        Text("low conviction").font(.system(size: font8)).foregroundStyle(DS.Palette.warningSoft)
                    }
                    Spacer(minLength: 0)
                    gateBadge(plan.gate)
                }
                HStack(spacing: DS.Space.sm) {
                    // .fixedSize so a money figure wraps instead of silently truncating under
                    // Dynamic Type / narrow width — a dropped Target price or $-at-risk on a
                    // money row is an honesty failure (audit L2-02, 2026-07-07).
                    Text("Entry \(adaptivePrice(plan.entry)) · Stop \(adaptivePrice(plan.stop)) · Target \(adaptivePrice(plan.target))")
                        .font(.system(size: font9)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let sh = plan.shares, let dr = plan.dollarsAtRisk {
                        // TODAY-PARITY: "· holds N sh" appended when a position is already held —
                        // acting on this row without that context silently stacks new risk on an
                        // existing position (the ideas board's Held chip exists for exactly this).
                        // One short suffix max (compact-row discipline) — closedTradeCount is
                        // lower-value here and carried only in the a11y label below.
                        let heldSuffix = plan.heldShares.map { " · holds \(numShares($0)) sh" } ?? ""
                        Text("· \(sh) sh (≈$\(Int(dr.rounded())) at risk)\(heldSuffix)")
                            .font(.system(size: font9)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("· set account to size").font(.system(size: font9)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if blocked, let gate = plan.gate {
                    Text("DO NOT TRADE — \(gate.checks.first(where: { $0.level == .fail })?.label ?? "gate failed")")
                        .font(.system(size: font8, weight: .semibold)).foregroundStyle(DS.Palette.dangerSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Caution: show the first warn reason as a visible secondary line for sighted users
                // (the a11y label already carries this, but sighted users had no way to see the reason
                // without a tooltip). lineLimit(1) keeps the row tight; '+N more' if several warns.
                if let gate = plan.gate, gate.decision == .caution {
                    let warns = gate.checks.filter { $0.level == .warn }
                    if let first = warns.first {
                        let more = warns.count > 1 ? " +\(warns.count - 1) more" : ""
                        Text("⚠ \(first.label)\(more)")
                            .font(.system(size: font8)).foregroundStyle(DS.Palette.warningSoft)
                            .lineLimit(1)
                    }
                }
                if let scaled = plan.scaledRiskFraction {
                    let scaledPct = scaled * 100
                    let biasText = plan.regimeBias.map { String(format: " (regime ×%.2f)", $0) } ?? ""
                    Text(String(format: "Conviction-scaled risk: %.2f%%%@ — scales size, not odds.", scaledPct, biasText))
                        .font(.system(size: font8)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .help({
                            var text = StockSageConvictionScaler.caveat
                            text += String(format: " Scaled risk shown: %.2f%%.", scaledPct)
                            return text
                        }())
                }
            }
            .padding(.horizontal, DS.Space.sm).padding(.vertical, 6)
            .background(DS.Bezel.cardFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(LuxPressStyle())
        .accessibilityLabel({
            // TODAY-A11Y-02: mirror the visible "%+.3fR/day gross" label (~89) — the spoken
            // label dropped "gross", which is the honesty-floor's required net/gross qualifier.
            var label = "Number \(rank): \(plan.symbol), \(String(format: "%+.3f", plan.velocity)) R per day gross"
            if plan.isCrypto { label += ", 24/7 crypto" }
            if plan.netCostFloorFlag.isDeranked { label += ", below net-cost floor" }
            if plan.isLowConviction { label += ", low conviction" }
            // The actionable order + size — VoiceOver otherwise hears the verdict but never
            // the entry/stop/target/size the row exists to convey (audit L2-01, 2026-07-07).
            label += ". Entry \(adaptivePrice(plan.entry)), stop \(adaptivePrice(plan.stop)), target \(adaptivePrice(plan.target))"
            if let sh = plan.shares, let dr = plan.dollarsAtRisk {
                label += ", \(sh) shares, about $\(Int(dr.rounded())) at risk"
            }
            // TODAY-PARITY a11y: the compact visible row only ever shows "holds N sh" (one
            // suffix max); VoiceOver carries the full held/journal context, matching the ideas
            // board's own a11y phrasing (MarketsView ideaCard label builder).
            if let held = plan.heldShares { label += ", you hold \(numShares(held)) shares" }
            if let closed = plan.closedTradeCount { label += ", \(closed) closed trades in your journal" }
            // F04-parity: nil gate ⇒ risk % wasn't supplied — mirror the sheet chip's a11y wording
            // ("Pre-trade gate: risk percent not set", MarketsView.swift ~5993) instead of forcing
            // a verdict sentence with no verdict to report.
            if let gate = plan.gate {
                label += ". \(gate.decision.rawValue)."
                // TODAY-A11Y-01: mirror the visible "DO NOT TRADE — {reason}" line (~120) — the
                // bare "Do not trade." spoke no reason while caution rows below DO speak theirs.
                if blocked {
                    let failLabel = gate.checks.first(where: { $0.level == .fail })?.label ?? "gate failed"
                    label += " Do not trade — \(failLabel)."
                }
                if gate.decision == .caution,
                   let warn = gate.checks.first(where: { $0.level == .warn }) {
                    label += " Caution: \(warn.label)."
                }
            } else {
                label += ". Pre-trade gate: risk percent not set."
            }
            label += " Tap for the plan."
            return label
        }())
    }

    @ViewBuilder
    private func gateBadge(_ gate: TradeGateVerdict?) -> some View {
        // F04-parity: nil ⇒ gate not evaluated (no real risk % supplied) — the neutral "set risk %"
        // badge mirrors the sheet's pinned-bar chip (MarketsView.swift ~5986-5993) instead of
        // fabricating a CLEAR/CAUTION/BLOCKED verdict from a silently-defaulted risk fraction.
        if let gate {
            let color: Color = gate.decision == .clear ? DS.Palette.successSoft
                : (gate.decision == .caution ? DS.Palette.warningSoft : DS.Palette.dangerSoft)
            let label = gate.decision == .clear ? "CLEAR" : (gate.decision == .caution ? "CAUTION" : "BLOCKED")
            // Build a .help string from the warn/fail check labels so sighted users can hover-reveal
            // the gate reason without opening the detail sheet.
            let reasonLabels = gate.checks.filter { $0.level == .warn || $0.level == .fail }.map(\.label)
            let helpText: String = {
                if reasonLabels.isEmpty { return "\(label) gate verdict." }
                return "\(label): \(reasonLabels.joined(separator: " · "))"
            }()
            Text(label)
                .font(.system(size: font8, weight: .bold)).foregroundStyle(color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color.opacity(0.15), in: Capsule())
                .help(helpText)
        } else {
            Text("SET RISK %")
                .font(.system(size: font8, weight: .bold)).foregroundStyle(DS.Palette.textSecondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(DS.Palette.textSecondary.opacity(0.15), in: Capsule())
                .help("Enter risk % to see the pre-trade gate verdict.")
        }
    }
}
