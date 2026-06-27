import SwiftUI

/// Standalone ideas board component — extracted from MarketsView.
/// Renders sorted/filtered idea cards with toolbar controls, empty states, and
/// a summary strip. Integrate by replacing the inline ideas block in MarketsView
/// with `MarketsIdeasSection(ideaSort: $ideaSort, ...)`.
struct MarketsIdeasSection: View {
    @ObservedObject private var store = StockSageStore.shared

    @Binding var ideaSort: MarketsView.IdeaSort
    @Binding var ideaFilter: MarketsView.IdeaFilter
    @Binding var ideaSearch: String
    @Binding var ideaMinConv: Double
    @Binding var selectedIdea: StockSageIdea?

    let velocityHolds: VelocityHoldDays

    var body: some View {
        Group {
            if store.ideas.isEmpty {
                emptyState
            } else {
                controlsBar
                if displayedIdeas.isEmpty {
                    Text(emptyMessage)
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                } else {
                    summaryStrip
                    ideasList
                }
            }
        }
        .animation(DS.Motion.smooth, value: store.ideas.count)
    }

    // MARK: - Toolbar

    private var controlsBar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(MarketsView.IdeaSort.allCases, id: \.self) { s in
                    Button { ideaSort = s } label: {
                        Label(s.rawValue, systemImage: ideaSort == s ? "checkmark" : "")
                    }
                }
            } label: {
                Label("Sort: \(ideaSort.rawValue)", systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 10)).foregroundStyle(DS.Palette.accent)
            }
            .menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel("Sort ideas")

            Menu {
                ForEach(MarketsView.IdeaFilter.allCases) { f in
                    Button { ideaFilter = f } label: {
                        Label(f.rawValue, systemImage: ideaFilter == f ? "checkmark" : "")
                    }
                }
            } label: {
                Label(ideaFilter == .all ? "Filter" : ideaFilter.rawValue,
                      systemImage: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(ideaFilter == .all ? .secondary : DS.Palette.accent)
            }
            .menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel("Filter ideas by action")

            Menu {
                ForEach([0.0, 0.5, 0.6, 0.7, 0.8], id: \.self) { v in
                    Button { ideaMinConv = v } label: {
                        Label(v == 0 ? "Any conviction" : "≥ \(Int(v * 100))%",
                              systemImage: ideaMinConv == v ? "checkmark" : "")
                    }
                }
            } label: {
                Label(ideaMinConv == 0 ? "Conviction" : "≥ \(Int(ideaMinConv * 100))%",
                      systemImage: "speedometer")
                    .font(.system(size: 10))
                    .foregroundStyle(ideaMinConv == 0 ? .secondary : DS.Palette.accent)
            }
            .menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel("Minimum conviction filter")

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(.secondary)
                TextField("Search", text: $ideaSearch)
                    .textFieldStyle(.plain).font(.system(size: 11)).frame(width: 84)
                if !ideaSearch.isEmpty {
                    Button { ideaSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.white.opacity(0.06), in: Capsule())
            .accessibilityLabel("Search ideas by symbol or market")

            Spacer()
        }
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        let ideas = displayedIdeas
        let strong = ideas.filter { $0.advice.action == .strongBuy }.count
        let buys   = ideas.filter { $0.advice.action == .strongBuy || $0.advice.action == .buy }.count
        let sells  = ideas.filter { $0.advice.action == .sell || $0.advice.action == .reduce }.count
        let avgConv = ideas.isEmpty ? 0.0
            : ideas.map(\.advice.conviction).reduce(0, +) / Double(ideas.count)

        return HStack(spacing: 8) {
            chip("\(ideas.count)", "shown", .white) { ideaFilter = .all; ideaMinConv = 0; ideaSearch = "" }
            if strong > 0 { chip("\(strong)", "strong buy", DS.Palette.successSoft) { ideaFilter = .strongBuy } }
            if buys > 0 { chip("\(buys)", "buys", .white) { ideaFilter = .buys } }
            if sells > 0 { chip("\(sells)", "sells", DS.Palette.warningSoft) { ideaFilter = .sells } }
            chip("\(Int((avgConv * 100).rounded()))%", "avg conv")
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func chip(_ value: String, _ label: String, _ valueColor: Color = .white,
                      action: (() -> Void)? = nil) -> some View {
        let content = HStack(spacing: 3) {
            Text(value).fontWeight(.semibold).foregroundStyle(valueColor)
            Text(label).foregroundStyle(.secondary)
        }
        .font(.system(size: 10))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(DS.Bezel.cardFill, in: RoundedRectangle(cornerRadius: 5))

        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    // MARK: - List

    private var ideasList: some View {
        VStack(spacing: DS.Space.sm) {
            ForEach(displayedIdeas) { idea in
                Button(action: { selectedIdea = idea }) { ideaRow(idea) }
                    .buttonStyle(.plain)
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func ideaRow(_ idea: StockSageIdea) -> some View {
        HStack(spacing: DS.Space.md) {
            Text(idea.advice.action.rawValue)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(actionColor(idea.advice.action))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(actionColor(idea.advice.action).opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 4))
                .frame(width: 60, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(idea.symbol).font(.system(size: 14, weight: .semibold))
                Text(idea.market).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .frame(width: 72, alignment: .leading)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int((idea.advice.conviction * 100).rounded()))%")
                    .font(.system(size: 12, weight: .medium))
                Text("conv").font(.system(size: 9)).foregroundStyle(.secondary)
            }

            if let vel = StockSageExpectedValue.velocity(
                for: idea, holds: velocityHolds, calibration: store.convictionCalibration) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.3fR", vel))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(vel >= 0.005 ? DS.Palette.successSoft : DS.Palette.warningSoft)
                    Text("EV/day").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
        .background(DS.Bezel.cardFill,
                    in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }

    private func actionColor(_ action: TradeAdvice.Action) -> Color {
        switch action {
        case .strongBuy: return DS.Palette.successSoft
        case .buy:       return DS.Palette.accent
        case .hold:      return .secondary
        case .avoid:     return .secondary
        case .reduce:    return DS.Palette.warningSoft
        case .sell:      return DS.Palette.warningSoft
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40)).foregroundStyle(DS.Palette.accent.opacity(0.5))
            Text("No ideas yet").font(.title3.weight(.semibold))
            Text("Tap \u{201C}Find ideas\u{201D} to scan every market")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50)
    }

    // MARK: - Computed state

    private var displayedIdeas: [StockSageIdea] {
        let sorted: [StockSageIdea]
        switch ideaSort {
        case .ev:
            sorted = StockSageExpectedValue.rankByEV(
                store.ideas, regime: store.regime, earnings: store.earnings,
                calibration: store.convictionCalibration)
        case .velocity:
            sorted = StockSageExpectedValue.rankByVelocity(
                store.ideas, holds: velocityHolds, earnings: store.earnings,
                calibration: store.convictionCalibration)
        case .conviction:
            sorted = store.ideas.sorted { $0.advice.conviction > $1.advice.conviction }
        case .rr:
            sorted = store.ideas.sorted { rewardRisk($0) > rewardRisk($1) }
        case .signal:
            sorted = store.ideas
        }

        var result: [StockSageIdea]
        switch ideaFilter {
        case .all:       result = sorted
        case .strongBuy: result = sorted.filter { $0.advice.action == .strongBuy }
        case .buys:      result = sorted.filter { $0.advice.action == .strongBuy || $0.advice.action == .buy }
        case .sells:     result = sorted.filter { $0.advice.action == .sell || $0.advice.action == .reduce }
        }

        if ideaMinConv > 0 { result = result.filter { $0.advice.conviction >= ideaMinConv } }
        let q = ideaSearch.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty { result = result.filter {
            $0.symbol.lowercased().contains(q) || $0.market.lowercased().contains(q)
        }}
        return result
    }

    private var emptyMessage: String {
        if !ideaSearch.trimmingCharacters(in: .whitespaces).isEmpty { return "No ideas match \u{201C}\(ideaSearch)\u{201D}." }
        if ideaMinConv > 0 { return "No ideas at ≥ \(Int(ideaMinConv * 100))% conviction — lower the filter." }
        if ideaFilter != .all { return "No \(ideaFilter.rawValue.lowercased()) ideas in this scan." }
        return "No ideas in this scan."
    }

    private func rewardRisk(_ idea: StockSageIdea) -> Double {
        guard let stop = idea.advice.stopPrice, let target = idea.advice.targetPrice,
              abs(idea.price - stop) > 0 else { return 0 }
        return min(abs(target - idea.price) / abs(idea.price - stop), 50)
    }
}
