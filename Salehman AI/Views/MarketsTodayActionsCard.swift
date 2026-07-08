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
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "list.number").font(.system(size: 11)).foregroundStyle(DS.Palette.accent)
                    Text("Today's plan — ranked by growth rate").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                }
                Text("Top \(plans.count) fastest-compounding setups, sized and gated — do #1 first, unless it's blocked.")
                    .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Ranked by growth rate (log-growth at ½-Kelly) — a steady compounder can out-rank a higher-R/day but higher-variance setup. Shown R/day is raw EV, not the sort key.")
                    .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                ForEach(Array(plans.enumerated()), id: \.element.id) { i, plan in
                    row(i + 1, plan)
                }

                HStack(spacing: 6) {
                    Spacer()
                    Button {
                        let text = StockSageTodayPlan.copyAllText(plans, isSample: isSampleData)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Label("Copy all \(plans.count)", systemImage: "doc.on.doc").font(.system(size: font9, weight: .medium))
                    }
                    .buttonStyle(.plain).foregroundStyle(DS.Palette.accent)
                    .help("Copy the ranked plan — entry/stop/target, size, and each gate verdict — to the clipboard. Estimates, not advice.")
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
    private func row(_ rank: Int, _ plan: TodayActionPlan) -> some View {
        let blocked = plan.gate.decision == .blocked
        Button { onSelectSymbol(plan.symbol) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Space.sm) {
                    Text("#\(rank)").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 16, alignment: .leading)
                    Text(plan.symbol).font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .strikethrough(blocked, color: DS.Palette.danger)
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
                if blocked {
                    Text("DO NOT TRADE — \(plan.gate.checks.first(where: { $0.level == .fail })?.label ?? "gate failed")")
                        .font(.system(size: font8, weight: .semibold)).foregroundStyle(DS.Palette.dangerSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Caution: show the first warn reason as a visible secondary line for sighted users
                // (the a11y label already carries this, but sighted users had no way to see the reason
                // without a tooltip). lineLimit(1) keeps the row tight; '+N more' if several warns.
                if plan.gate.decision == .caution {
                    let warns = plan.gate.checks.filter { $0.level == .warn }
                    if let first = warns.first {
                        let more = warns.count > 1 ? " +\(warns.count - 1) more" : ""
                        Text("⚠ \(first.label)\(more)")
                            .font(.system(size: font8)).foregroundStyle(DS.Palette.warningSoft)
                            .lineLimit(1)
                    }
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
            label += ". \(plan.gate.decision.rawValue)."
            // TODAY-A11Y-01: mirror the visible "DO NOT TRADE — {reason}" line (~120) — the
            // bare "Do not trade." spoke no reason while caution rows below DO speak theirs.
            if blocked {
                let failLabel = plan.gate.checks.first(where: { $0.level == .fail })?.label ?? "gate failed"
                label += " Do not trade — \(failLabel)."
            }
            if plan.gate.decision == .caution,
               let warn = plan.gate.checks.first(where: { $0.level == .warn }) {
                label += " Caution: \(warn.label)."
            }
            label += " Tap for the plan."
            return label
        }())
    }

    @ViewBuilder
    private func gateBadge(_ gate: TradeGateVerdict) -> some View {
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
    }
}
