import SwiftUI

/// The Markets tab — now wired to the live `StockSage` subsystem: per-symbol
/// rule-based momentum signals (`StockSageSignalEngine`, deterministic
/// |Δ%| thresholds) + an on-device daily briefing (`StockSageBriefingService`,
/// routed through `LocalLLM.generateOnDevice`). Data comes from `StockSageStore`
/// (sample seed until a live feed lands — honestly flagged). Sections not yet
/// built show a clear "coming soon".
struct MarketsView: View {
    @State private var section: MarketSection
    @State private var sort: MarketSort = .feed
    @ObservedObject private var store = StockSageStore.shared
    @ObservedObject private var portfolio = StockSagePortfolio.shared
    @State private var briefing = ""
    @State private var loadingBriefing = false
    @State private var newSymbol = ""
    @State private var newShares = ""
    @State private var newCost = ""
    // Alerts (wired to StockSageMonitor — strong-signal Mac notifications).
    @State private var monitoring = false
    @State private var alertSignals: [StockSageSignal] = []
    @State private var checkingAlerts = false
    @State private var monitorError = ""
    // Hover states — one per interactive surface type.
    @State private var hoveredSignalID: UUID?
    @State private var hoveredPositionID: UUID?
    @State private var hoveredAlertSymbol: String?
    @State private var hoveredHeatID: UUID?
    @State private var appeared = false

    /// `qaSection` lets the QA harness capture a specific sub-section (e.g. the
    /// heatmap) offscreen; normal use defaults to the watchlist.
    init(qaSection: MarketSection = .watchlist) { _section = State(initialValue: qaSection) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    header
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(DS.Motion.lux, value: appeared)
                    if store.isSampleData {
                        sampleBanner
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(DS.Motion.lux.delay(0.05), value: appeared)
                    }
                    sectionPicker
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(DS.Motion.lux.delay(0.08), value: appeared)
                    content
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(DS.Motion.lux.delay(0.12), value: appeared)
                }
                .padding(DS.Space.xl)
                // Centered content column, same as the chat surfaces.
                .frame(maxWidth: 780, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            MarketDisclaimerFooter()
        }
        // Flat opaque working canvas (design language).
        .background(DS.Palette.codeSurface.ignoresSafeArea())
        .onAppear { appeared = true }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Gradient.brand)
                    .frame(width: 36, height: 36)
                    .dsShadow(DS.Elevation.accentGlow(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.02)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.75)
                    )
                KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.60, duration: 0.07)
                        SpringKeyframe(1.18, spring: .snappy, duration: 0.28)
                        SpringKeyframe(1.0, spring: .bouncy, duration: 0.22)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Markets")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    Eyebrow(text: "Signals & Portfolio")
                }
                Text("Rule-based momentum signals · educational, not financial advice")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var sampleBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(DS.Palette.warningSoft)
            Text("Sample data — no live market feed connected yet. The signals show the engine running on illustrative prices.")
                .font(.caption).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
        .background(DS.Palette.warningSoft.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
            .stroke(DS.Palette.warningSoft.opacity(0.30), lineWidth: 1))
    }

    private var sectionPicker: some View {
        Picker("Markets section", selection: $section) {
            ForEach(MarketSection.allCases) { Text($0.title).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(maxWidth: 520)
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .watchlist, .all: signalList
        case .heatmap:         heatmap
        case .portfolio:       portfolioSection
        case .alerts:          alertsSection
        case .briefing:        briefingSection
        }
    }

    // MARK: Alerts

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: DS.Space.md) {
                    Image(systemName: "bell.badge.fill").font(.system(size: 18)).foregroundStyle(DS.Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strong-signal alerts").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Text("Get a Mac notification when a Strong Buy or Strong Sell appears.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { monitoring }, set: { toggleMonitoring($0) }))
                        .labelsHidden().tint(DS.Palette.accent)
                        .accessibilityLabel("Strong-signal monitoring")
                }
                if !monitorError.isEmpty {
                    Text(monitorError).font(.caption2).foregroundStyle(DS.Palette.warningSoft)
                }
                Button { Task { await checkAlertsNow() } } label: {
                    HStack(spacing: 6) {
                        if checkingAlerts { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.clockwise") }
                        Text(checkingAlerts ? "Checking…" : "Check now")
                    }
                }
                .buttonStyle(.bordered).controlSize(.small).disabled(checkingAlerts)
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))

            if alertSignals.isEmpty {
                Text("No strong signals right now — mostly Hold. Tap “Check now” to scan again.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                VStack(spacing: 1) {
                    ForEach(alertSignals, id: \.symbol) {
                        signalAlertRow($0)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .animation(DS.Motion.smooth, value: alertSignals.count)
                .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
            }
        }
    }

    private func signalAlertRow(_ s: StockSageSignal) -> some View {
        let hovered = hoveredAlertSymbol == s.symbol
        return HStack(spacing: 10) {
            Text(s.symbol).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(s.reason).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            Text(s.recommendation.rawValue)
                .font(.system(size: 11, weight: .bold)).foregroundStyle(recTextColor(s.recommendation))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(recColor(s.recommendation), in: Capsule())
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 10)
        .background(hovered ? DS.Palette.accent.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.smooth) {
                if over { hoveredAlertSymbol = s.symbol }
                else if hoveredAlertSymbol == s.symbol { hoveredAlertSymbol = nil }
            }
        }
    }

    private func toggleMonitoring(_ on: Bool) {
        monitorError = ""
        if on {
            do { try StockSageMonitor.shared.start(); monitoring = true }
            catch { monitorError = error.localizedDescription; monitoring = false }
        } else {
            StockSageMonitor.shared.stop(); monitoring = false
        }
    }

    private func checkAlertsNow() async {
        checkingAlerts = true
        alertSignals = await StockSageMonitor.shared.runCycle(notify: false)
        checkingAlerts = false
    }

    // MARK: Portfolio

    private func currentPrice(_ symbol: String) -> Double? {
        store.symbols.first { $0.symbol.uppercased() == symbol.uppercased() }?.latest?.price
    }

    private var portfolioTotals: (cost: Double, value: Double) {
        var cost = 0.0, value = 0.0
        for p in portfolio.positions {
            cost += p.totalCost
            value += (currentPrice(p.symbol) ?? p.costBasis) * p.shares
        }
        return (cost, value)
    }

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            portfolioSummary
            addPositionForm
            if portfolio.positions.isEmpty {
                Text("No holdings yet — add one above to track value & P&L.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                VStack(spacing: 1) {
                    ForEach(portfolio.positions) {
                        positionRow($0)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .animation(DS.Motion.smooth, value: portfolio.positions.count)
                .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
            }
        }
    }

    private var portfolioSummary: some View {
        let t = portfolioTotals
        let pl = t.value - t.cost
        let plPct = t.cost > 0 ? pl / t.cost * 100 : 0
        let up = pl >= 0
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portfolio value").font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.2f", t.value))
                    .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: t.value)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Total P&L").font(.caption).foregroundStyle(.secondary)
                Text((up ? "+" : "") + String(format: "%.2f (%+.1f%%)", pl, plPct))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(up ? DS.Palette.successSoft : DS.Palette.danger)
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: pl)
            }
        }
        .padding(DS.Space.md)
        .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private var addPositionForm: some View {
        HStack(spacing: 8) {
            field($newSymbol, "Symbol", width: 84)
            field($newShares, "Shares", width: 66)
            field($newCost, "Cost/sh", width: 72)
            Button {
                portfolio.add(symbol: newSymbol, shares: Double(newShares) ?? 0, costBasis: Double(newCost) ?? 0)
                newSymbol = ""; newShares = ""; newCost = ""
            } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(DS.Palette.accent)
            }
            .buttonStyle(.plain)
            .help("Add holding").accessibilityLabel("Add holding")
            .disabled(newSymbol.trimmingCharacters(in: .whitespaces).isEmpty || (Double(newShares) ?? 0) <= 0)
            Spacer()
        }
    }

    private func field(_ text: Binding<String>, _ placeholder: String, width: CGFloat) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain).font(.system(size: 13))
            .padding(.horizontal, 8).padding(.vertical, 6).frame(width: width)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
            .accessibilityLabel(placeholder)
    }

    private func positionRow(_ p: PortfolioPosition) -> some View {
        let price = currentPrice(p.symbol)
        let value = (price ?? p.costBasis) * p.shares
        let pl = value - p.totalCost
        let up = pl >= 0
        let hovered = hoveredPositionID == p.id
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.symbol).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("\(numString(p.shares)) sh @ \(String(format: "%.2f", p.costBasis))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(price == nil ? "— no price" : String(format: "%.2f", value))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                if price != nil {
                    Text((up ? "+" : "") + String(format: "%.2f", pl))
                        .font(.caption).foregroundStyle(up ? DS.Palette.successSoft : DS.Palette.danger)
                }
            }
            Button { portfolio.remove(p.id) } label: {
                Image(systemName: "trash").font(.system(size: 12))
                    .foregroundStyle(hovered ? DS.Palette.danger.opacity(0.7) : Color.secondary)
            }
            .buttonStyle(.plain).help("Remove holding").accessibilityLabel("Remove \(p.symbol)")
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 10)
        .background(hovered ? DS.Palette.accent.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.smooth) {
                if over { hoveredPositionID = p.id }
                else if hoveredPositionID == p.id { hoveredPositionID = nil }
            }
        }
    }

    private func numString(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2f", d)
    }

    // MARK: Heatmap

    private var heatmap: some View {
        Group {
            if store.symbols.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(store.symbols) { sym in
                        let change = sym.latest?.changePercent ?? 0
                        let heatHovered = hoveredHeatID == sym.id
                        VStack(spacing: 3) {
                            Text(sym.symbol)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                            Text(String(format: "%+.1f%%", change))
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.92))
                                .contentTransition(.numericText())
                                .animation(DS.Motion.smooth, value: change)
                        }
                        // Legibility on saturated tiles: white on a strong green/red is
                        // borderline — a subtle dark shadow lifts the text on any shade.
                        .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
                        .frame(maxWidth: .infinity).frame(height: 66)
                        .background(heatColor(change), in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .stroke(Color.white.opacity(heatHovered ? 0.22 : 0.08), lineWidth: 1))
                        .scaleEffect(heatHovered ? 1.04 : 1.0)
                        .animation(DS.Motion.press, value: heatHovered)
                        .onHover { over in
                            withAnimation(DS.Motion.press) {
                                if over { hoveredHeatID = sym.id }
                                else if hoveredHeatID == sym.id { hoveredHeatID = nil }
                            }
                        }
                        .help(sym.market)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(sym.symbol), \(String(format: "%+.1f percent", change))")
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                }
                .animation(DS.Motion.smooth, value: store.symbols.count)
            }
        }
    }

    /// Tile color: green-to-red by change magnitude (gain → green, loss → red,
    /// flat → neutral). Opacity scales with the move so a big swing reads hotter.
    private func heatColor(_ change: Double) -> Color {
        if change > 0.05 { return DS.Palette.success.opacity(min(0.28 + change / 18, 0.85)) }
        if change < -0.05 { return DS.Palette.danger.opacity(min(0.28 + abs(change) / 18, 0.85)) }
        return Color.white.opacity(0.10)
    }

    // MARK: Signals

    private var signalList: some View {
        VStack(spacing: DS.Space.sm) {
            if store.symbols.isEmpty {
                emptyState
            } else {
                HStack {
                    Spacer()
                    Menu {
                        ForEach(MarketSort.allCases) { s in
                            Button { sort = s } label: {
                                Label(s.title, systemImage: sort == s ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Label("Sort: \(sort.title)", systemImage: "arrow.up.arrow.down")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel("Sort watchlist")
                }
                ForEach(sort.apply(store.symbols)) { signalCard($0)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
        .animation(DS.Motion.smooth, value: store.symbols.count)
    }

    private func signalCard(_ sym: StockSageSymbol) -> some View {
        let signal = StockSageSignalEngine.generateSignal(for: sym)
        let change = sym.latest?.changePercent ?? 0
        let up = change >= 0
        let hovered = hoveredSignalID == sym.id
        return HStack(spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sym.symbol).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(sym.market).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if let p = sym.latest?.price {
                    Text(String(format: "%.2f", p))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(DS.Motion.smooth, value: p)
                }
                HStack(spacing: 3) {
                    Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.system(size: 9, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                        .animation(DS.Motion.smooth, value: up)
                    Text(String(format: "%+.2f%%", change))
                        .font(.system(size: 12, weight: .medium))
                        .contentTransition(.numericText())
                        .animation(DS.Motion.smooth, value: change)
                }
                .foregroundStyle(up ? DS.Palette.successSoft : DS.Palette.danger)
            }
            if let signal {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(signal.recommendation.rawValue)
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(recTextColor(signal.recommendation))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(recColor(signal.recommendation), in: Capsule())
                    // "Strength %" only makes sense for an actual buy/sell signal —
                    // SignalEngine hardcodes 0.65 for hold ("price consolidating"),
                    // which would read as "65% strength of doing nothing." Hide it.
                    if signal.recommendation != .hold {
                        Text("strength \(Int(signal.confidence * 100))%").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 96, alignment: .trailing)
            }
        }
        .padding(DS.Space.md)
        .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(hovered ? DS.Palette.accent.opacity(0.35) : DS.Palette.surfaceStroke, lineWidth: 1))
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.smooth) {
                if over { hoveredSignalID = sym.id }
                else if hoveredSignalID == sym.id { hoveredSignalID = nil }
            }
        }
        .help(signal?.reason ?? "")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sym.symbol), \(sym.market), \(String(format: "%.2f", sym.latest?.price ?? 0)), \(String(format: "%+.1f percent", change)), signal \(signal?.recommendation.rawValue ?? "none")")
    }

    private func recColor(_ r: StockSageRecommendation) -> Color {
        switch r {
        case .strongBuy, .buy:   return DS.Palette.successSoft
        case .hold:              return DS.Palette.warningSoft
        case .sell, .strongSell: return DS.Palette.danger
        }
    }

    /// Badge text colour for legibility. The buy/hold badges sit on LIGHT pastel
    /// backgrounds (successSoft/warningSoft), where white text is only ~1.9:1 (the
    /// QA textContrast scan flagged exactly this) — use a dark ink there; white
    /// still reads on the darker red sell badge.
    private func recTextColor(_ r: StockSageRecommendation) -> Color {
        switch r {
        case .sell, .strongSell: return .white
        default:                 return Color(white: 0.12)
        }
    }

    // MARK: Briefing

    private var briefingSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                Text("Daily briefing")
                    .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Button { Task { await generateBriefing() } } label: {
                    HStack(spacing: 6) {
                        if loadingBriefing { ProgressView().controlSize(.small).tint(.white) }
                        else { Image(systemName: "sparkles") }
                        Text(loadingBriefing ? "Generating…" : "Generate")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DS.Palette.accent, in: Capsule())
                    .shadow(color: DS.Palette.accent.opacity(0.25), radius: 4, y: 1)
                }
                .buttonStyle(LuxPressStyle())
                .disabled(loadingBriefing)
            }
            Text(briefing.isEmpty ? StockSageBriefingService.deterministicSummary(for: store.symbols) : briefing)
                .font(.callout).foregroundStyle(DS.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func generateBriefing() async {
        loadingBriefing = true
        briefing = await StockSageBriefingService.generateBriefing(for: store.symbols)
        loadingBriefing = false
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                PhaseAnimator([0.10, 0.18, 0.10]) { opacity in
                    Circle()
                        .fill(DS.Palette.accent.opacity(opacity))
                        .frame(width: 52, height: 52)
                        .blur(radius: 14)
                        .allowsHitTesting(false)
                } animation: { opacity in
                    opacity > 0.14
                        ? .spring(duration: 2.2, bounce: 0.06)
                        : .easeOut(duration: 1.8)
                }
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent.opacity(0.80))
            }
            Text("No symbols tracked yet.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 28)
    }
}

/// Sections shown inside the single Markets tab.
enum MarketSection: String, CaseIterable, Identifiable {
    case watchlist, all, heatmap, portfolio, alerts, briefing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .watchlist: return "Watchlist"
        case .all:       return "All"
        case .heatmap:   return "Heatmap"
        case .portfolio: return "Portfolio"
        case .alerts:    return "Alerts"
        case .briefing:  return "Briefing"
        }
    }
}

/// Watchlist ordering (Chat C feature). `apply` is pure → unit-tested.
enum MarketSort: String, CaseIterable, Identifiable {
    case feed, change, signal, symbol
    var id: String { rawValue }
    var title: String {
        switch self {
        case .feed:   return "Default"
        case .change: return "Top gainers"
        case .signal: return "Strongest signal"
        case .symbol: return "A–Z"
        }
    }
    /// Rank for the "strongest signal" sort: strong > buy/sell > hold.
    static func rank(_ r: StockSageRecommendation) -> Int {
        switch r {
        case .strongBuy, .strongSell: return 2
        case .buy, .sell:             return 1
        case .hold:                   return 0
        }
    }
    func apply(_ syms: [StockSageSymbol]) -> [StockSageSymbol] {
        switch self {
        case .feed:   return syms
        case .symbol: return syms.sorted { $0.symbol.localizedCaseInsensitiveCompare($1.symbol) == .orderedAscending }
        case .change: return syms.sorted { ($0.latest?.changePercent ?? 0) > ($1.latest?.changePercent ?? 0) }
        case .signal:
            return syms.sorted { a, b in
                let ra = StockSageSignalEngine.generateSignal(for: a).map { MarketSort.rank($0.recommendation) } ?? -1
                let rb = StockSageSignalEngine.generateSignal(for: b).map { MarketSort.rank($0.recommendation) } ?? -1
                if ra != rb { return ra > rb }
                return abs(a.latest?.changePercent ?? 0) > abs(b.latest?.changePercent ?? 0)
            }
        }
    }
}

/// Reusable disclaimer footer (reuses the canonical StockSageMini text).
struct MarketDisclaimerFooter: View {
    var body: some View {
        Text(StockSageMini.disclaimer)
            .font(.caption2).foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Flat opaque footer + hairline (was translucent material).
            .background(DS.Palette.codeSurfaceSide)
            .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
    }
}
