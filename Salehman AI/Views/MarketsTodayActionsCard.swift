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

    /// Adaptive price formatter mirroring `MarketsView.adaptivePrice(_:)` — %.2f for ≥$1,
    /// %.4f for sub-dollar, %.6f for sub-cent. Prevents entry/stop from collapsing to the same
    /// 2dp string for sub-dollar crypto (DOGE-USD, ADA-USD) in the analyzed core.
    private func adaptivePrice(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1 || a == 0 { return String(format: "%.2f", v) }
        if a >= 0.01 { return String(format: "%.4f", v) }
        return String(format: "%.6f", v)
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
                    Text(String(format: "%+.3fR/day", plan.velocity)).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Palette.successSoft)
                    Spacer(minLength: 0)
                    gateBadge(plan.gate)
                }
                HStack(spacing: DS.Space.sm) {
                    Text("Entry \(adaptivePrice(plan.entry)) · Stop \(adaptivePrice(plan.stop)) · Target \(adaptivePrice(plan.target))")
                        .font(.system(size: font9)).foregroundStyle(.secondary)
                    if let sh = plan.shares, let dr = plan.dollarsAtRisk {
                        Text("· \(sh) sh (≈$\(Int(dr.rounded())) at risk)")
                            .font(.system(size: font9)).foregroundStyle(.secondary)
                    } else {
                        Text("· set account to size").font(.system(size: font9)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if blocked {
                    Text("DO NOT TRADE — \(plan.gate.checks.first(where: { $0.level == .fail })?.label ?? "gate failed")")
                        .font(.system(size: font8, weight: .semibold)).foregroundStyle(DS.Palette.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, DS.Space.sm).padding(.vertical, 6)
            .background(DS.Bezel.cardFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(LuxPressStyle())
        .accessibilityLabel({
            var label = "Number \(rank): \(plan.symbol), \(String(format: "%+.3f", plan.velocity)) R per day"
            if plan.isCrypto { label += ", 24/7 crypto" }
            label += ". \(plan.gate.decision.rawValue)."
            if blocked { label += " Do not trade." }
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
            : (gate.decision == .caution ? DS.Palette.warningSoft : DS.Palette.danger)
        let label = gate.decision == .clear ? "CLEAR" : (gate.decision == .caution ? "CAUTION" : "BLOCKED")
        Text(label)
            .font(.system(size: font8, weight: .bold)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }
}
