import SwiftUI
import AppKit   // NSPasteboard for the trade-plan copy

/// The Markets tab — now wired to the live `StockSage` subsystem: per-symbol
/// rule-based momentum signals (`StockSageSignalEngine`, deterministic
/// |Δ%| thresholds) + an on-device daily briefing (`StockSageBriefingService`,
/// routed through `LocalLLM.generateOnDevice`). Data comes from `StockSageStore`
/// (sample seed until a live feed lands — honestly flagged). Sections not yet
/// built show a clear "coming soon".
struct MarketsView: View {
    @State private var section: MarketSection
    @AppStorage("marketsWatchSort") private var sort: MarketSort = .feed
    @State private var showBrowseMarkets = false
    /// Ideas board ordering: by expected value, EV-per-day velocity, or signal rank.
    private enum IdeaSort: String, CaseIterable { case ev = "Expected value", velocity = "EV / day", signal = "Signal rank" }
    @AppStorage("marketsIdeaSort") private var ideaSort: IdeaSort = .ev

    /// Ideas board action filter — jump straight to the strongest setups.
    private enum IdeaFilter: String, CaseIterable, Identifiable {
        case all = "All", strongBuy = "Strong Buy", buys = "Buys", sells = "Sells"
        var id: String { rawValue }
    }
    @AppStorage("marketsIdeaFilter") private var ideaFilter: IdeaFilter = .all

    /// Tunable hold-day assumptions feeding velocity (EV/day). Persisted; defaults match
    /// the engine's (crypto 3d, equity 12d) so nothing shifts until the owner changes it.
    @AppStorage("velocityCryptoHoldDays") private var cryptoHoldDays = 3.0
    @AppStorage("velocityEquityHoldDays") private var equityHoldDays = 12.0
    private var velocityHolds: VelocityHoldDays { VelocityHoldDays(crypto: cryptoHoldDays, equity: equityHoldDays) }
    @ObservedObject private var velocityHistory = StockSageVelocityHistoryStore.shared

    // Dynamic-Type-aware small fonts: each equals its base size at the default text
    // setting (mvFont9 == 9), so the dense layout is unchanged, but they scale up when
    // the user enlarges system text — fixing the "tiny fixed money font" a11y finding.
    @ScaledMetric(relativeTo: .caption2) private var mvFont7: CGFloat = 7
    @ScaledMetric(relativeTo: .caption2) private var mvFont8: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var mvFont9: CGFloat = 9
    @ObservedObject private var store = StockSageStore.shared
    @ObservedObject private var portfolio = StockSagePortfolio.shared
    @ObservedObject private var journal = StockSageJournalStore.shared
    @State private var briefing = ""
    @State private var loadingBriefing = false
    @State private var newSymbol = ""
    @State private var newShares = ""
    @State private var newCost = ""
    /// Watchlist add-symbol field (track any global ticker beyond the universe).
    @State private var newWatchSymbol = ""
    /// Tapped idea → per-symbol detail sheet (full advice + larger sparkline + backtest).
    @State private var selectedIdea: StockSageIdea?
    /// Kelly position-sizer inputs (interactive, no fetch).
    @State private var kellyWinRate = "55"
    @State private var kellyPayoff = "2.0"
    @State private var kellyAccount = "10000"
    /// Trade-journal add form (inline; no sheet to avoid presentation races).
    @State private var showAddTrade = false
    @State private var draftSymbol = ""
    @State private var draftSide: TradeRecord.Side = .long
    @State private var draftEntry = ""
    @State private var draftStop = ""
    @State private var draftTarget = ""
    @State private var draftShares = ""
    @State private var draftNote = ""
    /// Inline close-a-trade: the open trade being closed + its exit-price field.
    @State private var closingTradeID: UUID?
    @State private var closeExitText = ""
    /// Detail-sheet position sizer inputs.
    @AppStorage("marketsSizerAccount") private var sizerAccount = "10000"
    @AppStorage("marketsSizerRiskPct") private var sizerRiskPct = "1"
    /// Focus identity for the three add-holding fields → accent focus glow,
    /// matching the app's other primary inputs.
    private enum AddField: Hashable { case symbol, shares, cost }
    @FocusState private var focusedAddField: AddField?
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
    /// Staggered entrance. Pre-set under `--qa` so the offscreen snapshot
    /// (onAppear never fires) captures the settled layout, not the pre-entrance pose.
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    feedBanner
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(DS.Motion.lux.delay(0.05), value: appeared)
                        .transition(.opacity.combined(with: .offset(y: -4)))
                    regimeCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(DS.Motion.lux.delay(0.06), value: appeared)
                    moneyVelocityCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(DS.Motion.lux.delay(0.07), value: appeared)
                    sectionPicker
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(DS.Motion.lux.delay(0.08), value: appeared)
                    content
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(DS.Motion.lux.delay(0.12), value: appeared)
                }
                .animation(DS.Motion.smooth, value: store.isSampleData)
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
        .task {
            // Auto-pull a live worldwide snapshot on open — skipped under the QA
            // snapshot harness so captures stay deterministic and offline.
            guard !ProcessInfo.processInfo.arguments.contains("--qa") else { return }
            await store.refresh()
            // Snapshot today's money-velocity (one per UTC day) so the trend can build.
            let snap = StockSageExpectedValue.summary(store.ideas, trades: journal.trades, holds: velocityHolds)
            if let wk = snap.weeklyR {
                velocityHistory.record(weeklyR: wk, bestSymbol: snap.bestSymbol, fastestSymbol: snap.fastestSymbol)
            }
        }
        .sheet(item: $selectedIdea) { ideaDetailSheet($0) }
    }

    /// Honest feed status: the live (green) note once real quotes land, otherwise
    /// the sample/offline notice — surfacing `feedError` (web off, unreachable)
    /// when there is one so the message is actionable.
    @ViewBuilder private var feedBanner: some View {
        if store.isSampleData { sampleBanner } else { liveBanner }
    }

    private var liveBanner: some View {
        HStack(spacing: 8) {
            Circle().fill(DS.Palette.successSoft).frame(width: 7, height: 7)
                .shadow(color: DS.Palette.successSoft.opacity(0.7), radius: 4)
            Text("Live worldwide quotes across \(StockSageUniverse.marketCount) market groups (\(StockSageUniverse.worldwide.count) names). Prices may be delayed ~15 min — educational, not financial advice.")
                .font(.caption).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
        .background(DS.Palette.successSoft.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
            .stroke(LinearGradient(colors: [DS.Palette.successSoft.opacity(0.45),
                                            DS.Palette.successSoft.opacity(0.10)],
                                   startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }

    // MARK: Market regime gauge

    @ViewBuilder private var regimeCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: 10) {
                Image(systemName: store.regime.map { regimeIcon($0.state) } ?? "speedometer")
                    .font(.system(size: 16))
                    .foregroundStyle(store.regime.map { regimeColor($0.state) } ?? DS.Palette.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.regime?.state.rawValue ?? "Market regime")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .help(StockSageGlossary.regimeHelp)
                    if let r = store.regime {
                        Text(String(format: "Suggested sizing: ×%.2f of normal", r.sizingBias))
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Risk-on / risk-off gauge — biases how much to size.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { Task { await store.refreshRegime() } } label: {
                    HStack(spacing: 6) {
                        Group {
                            if store.isLoadingRegime { ProgressView().controlSize(.small).tint(.white) }
                            else { Image(systemName: "speedometer").font(.system(size: 11, weight: .semibold)) }
                        }
                        Text(store.isLoadingRegime ? "Gauging…" : (store.regime == nil ? "Gauge" : "Refresh"))
                            .font(.system(size: 11, weight: .semibold)).contentTransition(.opacity)
                    }
                    .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DS.Palette.accent, in: Capsule())
                }
                .buttonStyle(LuxPressStyle()).disabled(store.isLoadingRegime)
                .help("Gauge the market regime (S&P 500 trend, breadth, VIX)")
            }
            if let r = store.regime {
                convictionMeter((r.riskScore + 1) / 2, color: regimeColor(r.state))   // −1…+1 → 0…1
                ForEach(Array(r.signals.prefix(4).enumerated()), id: \.offset) { _, s in
                    Text("· \(s)").font(.caption2).foregroundStyle(DS.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(r.caveat).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let at = store.regimeGaugedAt {
                    Text(store.regimeIsStale
                         ? "⚠︎ Gauged \(at.formatted(.relative(presentation: .named))) — stale, re-gauge."
                         : "Gauged \(at.formatted(.relative(presentation: .named))).")
                        .font(.system(size: mvFont9)).foregroundStyle(store.regimeIsStale ? DS.Palette.warningSoft : DS.Palette.textSecondary)
                }
            }
            if let e = store.regimeError {
                Text(e).font(.caption2).foregroundStyle(DS.Palette.warningSoft)
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(store.regime.map { regimeColor($0.state).opacity(0.35) } ?? DS.Palette.surfaceStroke, lineWidth: 1))
        .animation(DS.Motion.smooth, value: store.regime)
    }

    private func regimeColor(_ s: MarketRegime.State) -> Color {
        switch s {
        case .trendingBull:          return DS.Palette.successSoft
        case .ranging:               return DS.Palette.warningSoft
        case .trendingBear, .crisis: return DS.Palette.danger
        }
    }
    private func regimeIcon(_ s: MarketRegime.State) -> String {
        switch s {
        case .trendingBull: return "arrow.up.right.circle.fill"
        case .ranging:      return "arrow.left.and.right.circle.fill"
        case .trendingBear: return "arrow.down.right.circle.fill"
        case .crisis:       return "exclamationmark.triangle.fill"
        }
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
                if reduceMotion {
                    // Reduce Motion: static icon (no scale bounce-in).
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .scaleEffect(scale)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(0.60, duration: 0.07)
                            SpringKeyframe(1.18, duration: 0.28, spring: .snappy)
                            SpringKeyframe(1.0, duration: 0.22, spring: .bouncy)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Markets")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    Eyebrow(text: "Signals & Portfolio")
                }
                Text(headerSubtitle)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(DS.Motion.smooth, value: headerSubtitle)
            }
            Spacer()
            refreshButton
        }
    }

    /// Live status line: once a real feed lands, show the freshness + market count;
    /// otherwise the educational tagline.
    private var headerSubtitle: String {
        if !store.isSampleData, let when = store.lastUpdated {
            return "Live · \(StockSageUniverse.marketCount) market groups · updated \(Self.timeFormatter.string(from: when))"
        }
        return "Rule-based momentum signals · educational, not financial advice"
    }

    private var refreshButton: some View {
        Button { Task { await store.refresh() } } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                .animation(store.isRefreshing
                           ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                           : .default, value: store.isRefreshing)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(
                    LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                                   startPoint: .top, endPoint: .bottom), lineWidth: 1))
        }
        .buttonStyle(LuxPressStyle())
        .disabled(store.isRefreshing)
        .help("Refresh live quotes")
        .accessibilityLabel("Refresh live quotes")
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private var sampleBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(DS.Palette.warningSoft)
            Text(store.feedError ?? "Sample data — connecting to the live worldwide feed… The signals show the engine running on illustrative prices.")
                .font(.caption).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
        .background(DS.Palette.warningSoft.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
            .stroke(LinearGradient(colors: [DS.Palette.warningSoft.opacity(0.52),
                                            DS.Palette.warningSoft.opacity(0.12)],
                                   startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }

    private var sectionPicker: some View {
        DSSegmentPicker(cases: Array(MarketSection.allCases), selection: $section) { $0.title }
            .frame(maxWidth: 520)
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .watchlist, .all: signalList
        case .ideas:           ideasSection
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
                        .transition(.opacity.combined(with: .offset(y: -4)))
                }
                Button { Task { await checkAlertsNow() } } label: {
                    HStack(spacing: 6) {
                        Group {
                            if checkingAlerts { ProgressView().controlSize(.small) }
                            else { Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold)) }
                        }
                        .transition(.opacity)
                        .animation(DS.Motion.smooth, value: checkingAlerts)
                        Text(checkingAlerts ? "Checking…" : "Check now")
                            .font(.system(size: 11.5, weight: .semibold))
                            .contentTransition(.opacity)
                            .animation(DS.Motion.smooth, value: checkingAlerts)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(
                        LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 1))
                }
                .buttonStyle(LuxPressStyle()).disabled(checkingAlerts)
            }
            .animation(DS.Motion.smooth, value: monitorError.isEmpty)
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(DS.Bezel.cardFill)
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))

            if alertSignals.isEmpty {
                Text("No strong signals right now — mostly Hold. Tap “Check now” to scan again.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .transition(.opacity)
            } else {
                VStack(spacing: 1) {
                    ForEach(alertSignals, id: \.symbol) {
                        signalAlertRow($0)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .animation(DS.Motion.smooth, value: alertSignals.count)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(DS.Bezel.cardFill)
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                .transition(.opacity)
            }
        }
        .animation(DS.Motion.smooth, value: alertSignals.isEmpty)
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
                    .transition(.opacity)
            } else {
                VStack(spacing: 1) {
                    ForEach(portfolio.positions) {
                        positionRow($0)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .animation(DS.Motion.smooth, value: portfolio.positions.count)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(DS.Bezel.cardFill)
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                .transition(.opacity)
            }
            if !portfolio.positions.isEmpty { allocationPanel }
            if !portfolio.positions.isEmpty { riskParityPanel }
            if !portfolio.positions.isEmpty { portfolioAnalyticsPanel }
            correlationHeatmapPanel
            tradeJournalPanel   // records the owner's actual trades + realized P&L/R
            kellySizerPanel   // a standalone calculator — useful with or without holdings
        }
        .animation(DS.Motion.smooth, value: portfolio.positions.isEmpty)
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
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private var addPositionForm: some View {
        HStack(spacing: 8) {
            field($newSymbol, "Symbol", width: 84, focus: .symbol)
            field($newShares, "Shares", width: 66, focus: .shares)
            field($newCost, "Cost/sh", width: 72, focus: .cost)
            Button {
                portfolio.add(symbol: newSymbol, shares: Double(newShares) ?? 0, costBasis: Double(newCost) ?? 0)
                newSymbol = ""; newShares = ""; newCost = ""
            } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(DS.Palette.accent)
            }
            .buttonStyle(LuxPressStyle())
            .help("Add holding").accessibilityLabel("Add holding")
            .disabled(newSymbol.trimmingCharacters(in: .whitespaces).isEmpty || (Double(newShares) ?? 0) <= 0)
            Spacer()
        }
    }

    private func field(_ text: Binding<String>, _ placeholder: String, width: CGFloat, focus: AddField) -> some View {
        let active = focusedAddField == focus
        return TextField(placeholder, text: text)
            .textFieldStyle(.plain).font(.system(size: 13))
            .focused($focusedAddField, equals: focus)
            .padding(.horizontal, 8).padding(.vertical, 6).frame(width: width)
            .background(Color.white.opacity(active ? 0.11 : 0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .stroke(active
                        ? AnyShapeStyle(LinearGradient(colors: [DS.Palette.accent.opacity(0.55), DS.Palette.accent.opacity(0.15)],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(DS.Palette.surfaceStroke), lineWidth: 1))
            .shadow(color: DS.Palette.accent.opacity(active ? 0.15 : 0.0), radius: 8, y: 2)
            .animation(DS.Motion.lux, value: active)
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
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: value)
                if price != nil {
                    Text((up ? "+" : "") + String(format: "%.2f", pl))
                        .font(.caption).foregroundStyle(up ? DS.Palette.successSoft : DS.Palette.danger)
                        .contentTransition(.numericText())
                        .animation(DS.Motion.smooth, value: pl)
                }
            }
            .animation(DS.Motion.smooth, value: up)
            Button { portfolio.remove(p.id) } label: {
                Image(systemName: "trash").font(.system(size: 12))
                    .foregroundStyle(hovered ? DS.Palette.danger.opacity(0.7) : Color.secondary)
            }
            .buttonStyle(LuxPressStyle()).help("Remove holding").accessibilityLabel("Remove \(p.symbol)")
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

    // MARK: Risk parity

    private var riskParityPanel: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "scalemass.fill").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risk-parity weights").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Text("Size each holding by 1 ÷ volatility so they contribute equal risk.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { Task { await store.refreshRiskParity() } } label: {
                    HStack(spacing: 6) {
                        Group {
                            if store.isComputingParity { ProgressView().controlSize(.small).tint(.white) }
                            else { Image(systemName: "scalemass").font(.system(size: 11, weight: .semibold)) }
                        }
                        Text(store.isComputingParity ? "Sizing…" : "Balance by risk")
                            .font(.system(size: 11.5, weight: .semibold)).contentTransition(.opacity)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(DS.Palette.accent, in: Capsule())
                }
                .buttonStyle(LuxPressStyle()).disabled(store.isComputingParity)
            }
            if let err = store.parityError {
                Text(err).font(.caption2).foregroundStyle(DS.Palette.warningSoft)
            }
            if !store.riskParity.isEmpty {
                VStack(spacing: 1) { ForEach(store.riskParity) { parityRow($0) } }
                if let vs = StockSageRiskParity.vsEqualWeight(store.riskParity) {
                    Text(vs.note).font(.caption2).foregroundStyle(DS.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Equalizes risk, not a profit promise. Risk parity can suffer in correlation shocks — keep a cash sleeve.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                // Concrete rebalance: the actual $ trades to reach the risk-parity targets,
                // with a 2% no-trade band so you don't churn on tiny drifts.
                let rebalHoldings = portfolio.positions.map {
                    (symbol: $0.symbol, value: (currentPrice($0.symbol) ?? $0.costBasis) * $0.shares)
                }
                let rebalTargets = Dictionary(store.riskParity.map { ($0.symbol, $0.targetWeight) },
                                              uniquingKeysWith: { a, _ in a })
                if let plan = StockSageRebalance.plan(holdings: rebalHoldings, targets: rebalTargets) {
                    if plan.isBalanced {
                        Text("✓ Within 2% of target — no rebalance needed.")
                            .font(.caption2).foregroundStyle(DS.Palette.successSoft)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("To rebalance (≈$ trades, ignores costs/taxes):")
                                .font(.system(size: mvFont9, weight: .semibold)).foregroundStyle(.secondary)
                            ForEach(plan.trades) { t in
                                Text("\(t.action) \(String(format: "$%.0f", abs(t.deltaValue))) of \(t.symbol)  (\(String(format: "%.0f%%→%.0f%%", t.currentWeight * 100, t.targetWeight * 100)))")
                                    .font(.system(size: mvFont9, design: .monospaced))
                                    .foregroundStyle(t.deltaValue > 0 ? DS.Palette.successSoft : DS.Palette.danger)
                            }
                        }
                    }
                }
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func parityRow(_ t: RiskParityTarget) -> some View {
        let up = t.deltaWeight >= 0
        return HStack(spacing: 10) {
            Text(t.symbol).font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white).frame(width: 70, alignment: .leading).lineLimit(1)
            Text(String(format: "vol %.0f%%", t.volatility * 100)).font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(String(format: "%.0f%% → %.0f%%", t.currentWeight * 100, t.targetWeight * 100))
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                .contentTransition(.numericText())
            Text((up ? "+" : "") + String(format: "%.0f%%", t.deltaWeight * 100))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(up ? DS.Palette.successSoft : DS.Palette.danger)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(t.symbol), target \(Int(t.targetWeight * 100)) percent")
    }

    // MARK: Allocation breakdown

    private var allocationPanel: some View {
        let holdings = portfolio.positions.map {
            (symbol: $0.symbol, value: (currentPrice($0.symbol) ?? $0.costBasis) * $0.shares)
        }
        let alloc = StockSageAllocation.breakdown(holdings)
        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "chart.bar.doc.horizontal.fill").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allocation").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Text("Where the money sits — by asset class, region and sector.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            allocationGroup("By asset class", alloc.byClass)
            allocationGroup("By region", alloc.byRegion)
            allocationGroup("By sector", StockSageAllocation.slices(holdings, by: StockSageSector.sector))
            if alloc.topClassConcentration > 0.6 {
                Text("⚠︎ \(Int(alloc.topClassConcentration * 100))% in one asset class — concentrated.")
                    .font(.caption2).foregroundStyle(DS.Palette.warningSoft)
            }

            // Currency exposure — only worth showing when there's an actual FX dimension.
            let ccyHoldings = portfolio.positions.map {
                (value: (currentPrice($0.symbol) ?? $0.costBasis) * $0.shares,
                 currency: StockSageCurrency.currencyForSymbol($0.symbol))
            }
            let fxRates: [String: Double] = Dictionary(uniqueKeysWithValues:
                Set(ccyHoldings.map(\.currency)).subtracting(["USD"]).compactMap { ccy -> (String, Double)? in
                    guard let r = currentPrice("\(ccy)USD=X"), r > 0 else { return nil }
                    return (ccy, r)
                })
            if let cb = StockSageCurrency.breakdown(holdings: ccyHoldings, ratesToBase: fxRates, base: "USD"),
               cb.exposures.count > 1 || !cb.unpriced.isEmpty {
                Text("Currency exposure (base USD)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(cb.exposures) { e in
                    HStack(spacing: 8) {
                        Text(e.currency).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).frame(width: 46, alignment: .leading)
                        Text(String(format: "%.0f%%", e.weight * 100)).font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(e.baseValue.formatted(.number.precision(.fractionLength(0)))).font(.caption2).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(e.currency): \(Int(e.weight * 100)) percent of the priced book")
                }
                if let c = cb.concentration {
                    Text("⚠︎ \(Int(c.weight * 100))% in \(c.currency) — FX risk (currency moves swing your USD value).")
                        .font(.caption2).foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                }
                if !cb.unpriced.isEmpty {
                    Text("Unpriced (track \(cb.unpriced.first ?? "")USD=X to convert): \(cb.unpriced.joined(separator: ", ")) — excluded from the split.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Text("Local prices assumed in each market's currency (London .L in pence may distort). Rates are snapshots; FX moves are real, un-modeled risk.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func allocationGroup(_ title: String, _ slices: [AllocationBreakdown.Slice]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(slices) { s in
                HStack(spacing: 8) {
                    Text(s.label).font(.system(size: 11)).foregroundStyle(.white)
                        .frame(width: 92, alignment: .leading).lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                            Capsule().fill(DS.Palette.accent)
                                .frame(width: max(4, geo.size.width * s.fraction), height: 6)
                        }
                    }
                    .frame(height: 6)
                    Text(String(format: "%.0f%%", s.fraction * 100))
                        .font(.caption2).foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(s.label) \(Int(s.fraction * 100)) percent")
            }
        }
    }

    // MARK: Correlation heatmap

    @ViewBuilder private var correlationHeatmapPanel: some View {
        if let c = store.correlation, c.symbols.count >= 2 {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: DS.Space.md) {
                    Image(systemName: "square.grid.3x3.fill").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Correlation heatmap").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            .help(StockSageGlossary.heatmapHelp)
                        Text("Green = independent · red = moves together (concentration risk).")
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(c.symbols.indices, id: \.self) { i in
                            HStack(spacing: 2) {
                                Text(String(c.symbols[i].prefix(6)))
                                    .font(.system(size: mvFont8, weight: .semibold)).foregroundStyle(.secondary)
                                    .frame(width: 46, alignment: .leading).lineLimit(1)
                                ForEach(c.symbols.indices, id: \.self) { j in
                                    let v = c.matrix[i][j]
                                    Rectangle().fill(correlationColor(v))
                                        .frame(width: 26, height: 18)
                                        .overlay(Text(String(format: "%.1f", v))
                                            .font(.system(size: mvFont7, weight: .bold)).foregroundStyle(.white.opacity(0.92)))
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel("\(c.symbols[i]) vs \(c.symbols[j]), correlation \(String(format: "%.1f", v))")
                                }
                            }
                        }
                    }
                }
                if let cluster = StockSageCorrelationCluster.largest(c) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "link").font(.system(size: 11)).foregroundStyle(DS.Palette.danger)
                        Text(cluster.note).font(.caption2).foregroundStyle(DS.Palette.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Pairwise daily-return correlation over the overlapping window — lower (greener) off-diagonal = better diversified.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        }
    }

    /// ≤0 (green, independent/hedged) → +1 (red, moves together / concentration).
    /// A correlation of ~0 IS the diversified case, so it must read green, not red.
    private func correlationColor(_ v: Double) -> Color {
        if v > 0 { return DS.Palette.danger.opacity(0.22 + min(v, 1) * 0.55) }
        return DS.Palette.successSoft.opacity(0.22 + min(-v, 1) * 0.55)
    }

    // MARK: Trade journal

    private var tradeJournalPanel: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "book.closed.fill").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trade journal").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .help(StockSageGlossary.journalHelp)
                    Text("Log the trades you actually take, then close them to build your realized track record.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if !journal.trades.isEmpty {
                    Button {
                        let csv = StockSageJournalCSV.csv(journal.trades)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(csv, forType: .string)
                    } label: {
                        Text("Copy CSV").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy the whole journal as CSV (Excel / Sheets / Python-ready)")
                }
                Button { withAnimation(.easeOut(duration: 0.15)) { showAddTrade.toggle() } } label: {
                    HStack(spacing: 5) {
                        Image(systemName: showAddTrade ? "xmark" : "plus").font(.system(size: 10, weight: .bold))
                        Text(showAddTrade ? "Close" : "Log trade").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white).padding(.horizontal, 11).padding(.vertical, 6)
                    .background(DS.Palette.accent, in: Capsule())
                }.buttonStyle(LuxPressStyle())
            }

            if let health = journal.systemHealth {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: healthIcon(health.verdict)).font(.system(size: 11)).foregroundStyle(healthColor(health.verdict))
                    Text(health.verdict.rawValue).font(.system(size: 11, weight: .bold)).foregroundStyle(healthColor(health.verdict))
                    Text(health.reason).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }

            if showAddTrade { addTradeForm }

            // Realized stats (closed trades only).
            let s = journal.stats
            if s.closed > 0 {
                HStack(spacing: 16) {
                    ideaMetric("Closed", "\(s.closed)")
                    ideaMetric("Win", String(format: "%.0f%%", s.winRate * 100),
                               color: s.winRate >= 0.5 ? DS.Palette.successSoft : DS.Palette.danger)
                    ideaMetric("Total R", String(format: "%+.2f", s.totalR),
                               color: s.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                    ideaMetric("Avg R", String(format: "%+.2f", s.avgR),
                               color: s.avgR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                    ideaMetric("Realized P&L", String(format: "%+.0f", s.totalProfit),
                               color: s.totalProfit >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                    Spacer(minLength: 0)
                }
                let edge = journal.edgeStats
                if edge.closedWithR > 0 {
                    HStack(spacing: 16) {
                        ideaMetric("Expectancy", String(format: "%+.2fR", edge.expectancyR),
                                   color: edge.expectancyR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                        ideaMetric("Avg win", String(format: "+%.2fR", edge.avgWinR), color: DS.Palette.successSoft)
                        ideaMetric("Avg loss", String(format: "−%.2fR", edge.avgLossR), color: DS.Palette.danger)
                        ideaMetric("Payoff", edge.payoffRatio > 0 ? String(format: "%.2f", edge.payoffRatio) : "—")
                        ideaMetric("PF", edge.profitFactor.map { String(format: "%.2f", $0) } ?? "—",
                                   color: (edge.profitFactor ?? 0) >= 1 ? DS.Palette.successSoft : DS.Palette.danger)
                        Spacer(minLength: 0)
                    }
                    if let pf = edge.profitFactor {
                        Text(String(format: "Profit factor %.2f — for every 1R you lost, you won %.2fR (>1 = net positive). R-based; a record, not a promise.", pf, pf))
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Expectancy = R you make per trade on average. Positive = the system has paid you so far; it's a record, not a promise.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let ci = journal.expectancyCI {
                        Text(ci.note).font(.caption2)
                            .foregroundStyle(ci.isSignificant ? DS.Palette.successSoft : DS.Palette.warningSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        if let sig = journal.tradesToSignificance, sig.more > 0 {
                            Text("≈ \(sig.more) more trades to confirm the edge at 2σ (95%).")
                                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        if let trend = journal.expectancyTrend {
                            Text(String(format: "Recent %+.2fR vs early %+.2fR — %@.", trend.recentR, trend.earlyR, trend.direction.rawValue))
                                .font(.caption2)
                                .foregroundStyle(trend.direction == .improving ? DS.Palette.successSoft
                                                 : (trend.direction == .fading ? DS.Palette.danger : .secondary))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let streak = journal.streakSummary {
                    let run = streak.streakCount == 0 ? "—"
                        : "\(streak.streakCount) \(streak.streakIsWin ? "win" : "loss")\(streak.streakCount == 1 ? "" : (streak.streakIsWin ? "s" : "es"))"
                    Text(String(format: "Best %+.2fR (%@) · worst %+.2fR (%@) · current run: %@",
                                streak.bestR, streak.bestSymbol, streak.worstR, streak.worstSymbol, run))
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let hp = journal.holdingPeriod {
                    Text(hp.note).font(.caption2)
                        .foregroundStyle(hp.ridingLosers ? DS.Palette.warningSoft : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let risk = journal.equityRisk {
                    Text(String(format: "Worst losing run: %d · max drawdown −%.2fR (your realized path so far).",
                                risk.maxConsecutiveLosses, risk.maxDrawdownR))
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let dd = StockSageRiskOfRuin.scenario(losses: risk.maxConsecutiveLosses, fraction: 0.01) {
                        Text(String(format: "Stay in the game: %d 1R stops in a row at 1%%/trade ≈ −%.1f%% to the account — %@",
                                    dd.losses, dd.drawdownPct * 100,
                                    dd.isSteep ? "size down; surviving variance is how velocity compounds."
                                               : "survivable — staying in the game is what lets velocity pay off."))
                            .font(.caption2)
                            .foregroundStyle(dd.isSteep ? DS.Palette.warningSoft : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .help(StockSageGlossary.explain(.drawdownSurvival))
                    }
                }
                if let comp = journal.compounding, comp.multiples.count >= 2 {
                    let up = comp.finalMultiple >= 1
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(format: "Compounded to ×%.2f at %.0f%%/trade", comp.finalMultiple, comp.fraction * 100))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(up ? DS.Palette.successSoft : DS.Palette.danger)
                        Sparkline(values: comp.multiples)
                            .stroke(up ? DS.Palette.successSoft : DS.Palette.danger,
                                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(height: 26).opacity(0.9)
                        Text("Your OWN logged R compounded at a fixed risk % — the past path of your trades, NOT a projection of future returns.")
                            .font(.system(size: mvFont9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .help(StockSageGlossary.explain(.compounding))
                }
                if journal.closed.count >= 20,
                   let proj = StockSageJournal.projectGrowth(expectancyR: journal.edgeStats.expectancyR, trades: 100, fraction: 0.01) {
                    Text(String(format: "What-if (HYPOTHETICAL): at your measured %+.2fR/trade & 1%%/trade, 100 trades ≈ ×%.2f. %@",
                                proj.expectancyR, proj.multiple, MoneyVelocityCopy.growthProjection))
                        .font(.caption2)
                        .foregroundStyle(proj.multiple >= 1 ? DS.Palette.warningSoft : DS.Palette.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .help("A deterministic compounding of your measured average R — it ignores variance and drawdown, which make the real path lower and bumpier. Not advice, not a forecast.")
                }
                if let dist = journal.rDistribution, dist.total >= 3 {
                    let maxC = max(dist.bins.map(\.count).max() ?? 1, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("R-multiple distribution").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(dist.bins.indices, id: \.self) { i in
                                let bin = dist.bins[i]
                                VStack(spacing: 2) {
                                    Text("\(bin.count)").font(.system(size: mvFont8)).foregroundStyle(.secondary)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(i < 2 ? DS.Palette.danger : DS.Palette.successSoft)
                                        .frame(width: 26, height: max(2, CGFloat(bin.count) / CGFloat(maxC) * 26))
                                    Text(bin.label).font(.system(size: mvFont7)).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                let months = journal.monthlyPnL
                if months.count >= 2 {
                    Text("By month").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(months.prefix(6)) { mo in
                        HStack(spacing: 8) {
                            Text(mo.month).font(.system(size: 11)).foregroundStyle(.white).frame(width: 72, alignment: .leading)
                            Text("\(mo.trades) tr").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%+.2fR", mo.totalR)).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(mo.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                let years = journal.yearlyPnL
                if !years.isEmpty {
                    Text("By year (realized — record-keeping, not tax advice)")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(years) { yr in
                        HStack(spacing: 8) {
                            Text(yr.year).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).frame(width: 48, alignment: .leading)
                            Text("\(yr.trades) tr · \(Int(yr.winRate * 100))% win").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(yr.realizedDollars.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always()))).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(yr.realizedDollars >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                            Text(String(format: "%+.1fR", yr.totalR)).font(.caption2).foregroundStyle(.secondary)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                }
                let sides = journal.sideStats
                if sides.count == 2 {
                    Text("By side").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(sides) { s in
                        HStack(spacing: 8) {
                            Text(s.side.rawValue).font(.system(size: 11)).foregroundStyle(.white).frame(width: 60, alignment: .leading)
                            Text("\(s.trades) tr · \(Int(s.winRate * 100))% win · \(String(format: "%+.2f", s.avgR))R avg")
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%+.2fR", s.totalR)).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(s.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                let sectors = journal.sectorPnL
                if sectors.count >= 2 {
                    Text("By sector").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(sectors) { sec in
                        HStack(spacing: 8) {
                            Text(sec.sector).font(.system(size: 11)).foregroundStyle(.white)
                                .frame(width: 96, alignment: .leading).lineLimit(1)
                            Text("\(sec.trades) tr · \(Int(sec.winRate * 100))% win").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%+.2fR", sec.totalR)).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(sec.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }

            if journal.trades.isEmpty {
                Text("No trades logged yet. \"Log trade\" records a decision you made — the journal tracks it, it doesn't endorse it.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                if !journal.open.isEmpty {
                    Text("Open").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(journal.open) { journalOpenRow($0) }
                }
                if !journal.closed.isEmpty {
                    Text("Closed").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(journal.closed) { journalClosedRow($0) }
                }
            }

            Text(StockSageJournal.caveat).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func healthColor(_ v: SystemHealth.Verdict) -> Color {
        switch v {
        case .strong: return DS.Palette.successSoft
        case .developing: return DS.Palette.accent
        case .unproven: return DS.Palette.textSecondary
        case .negative: return DS.Palette.danger
        }
    }
    private func healthIcon(_ v: SystemHealth.Verdict) -> String {
        switch v {
        case .strong: return "checkmark.seal.fill"
        case .developing: return "chart.line.uptrend.xyaxis"
        case .unproven: return "questionmark.circle"
        case .negative: return "exclamationmark.triangle.fill"
        }
    }

    private var addTradeForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                journalField("Symbol", text: $draftSymbol, width: 90)
                Picker("", selection: $draftSide) {
                    ForEach(TradeRecord.Side.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.labelsHidden().pickerStyle(.segmented).frame(width: 130)
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                journalField("Entry", text: $draftEntry)
                journalField("Stop", text: $draftStop)
                journalField("Target", text: $draftTarget)
                journalField("Shares", text: $draftShares)
            }
            journalField("Note (optional)", text: $draftNote, width: 280)
            HStack(spacing: 10) {
                Button { saveDraftTrade() } label: {
                    Text("Save").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6).background(DS.Palette.accent, in: Capsule())
                }.buttonStyle(LuxPressStyle()).disabled(!draftIsValid)
                if !draftIsValid {
                    Text("Symbol, entry, stop, shares required — protective stop (below entry for Long, above for Short).")
                        .font(.system(size: mvFont9)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
    }

    private func journalField(_ placeholder: String, text: Binding<String>, width: CGFloat = 70) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain).font(.system(size: 12))
            .padding(.horizontal, 8).padding(.vertical, 6).frame(width: width)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private var draftIsValid: Bool {
        guard !draftSymbol.trimmingCharacters(in: .whitespaces).isEmpty,
              let e = Double(draftEntry), let st = Double(draftStop), let sh = Double(draftShares),
              e > 0, st > 0, sh > 0, e != st,
              // Stop must be PROTECTIVE, else the recorded R is meaningless.
              (draftSide == .long ? st < e : st > e) else { return false }
        return true
    }

    private func saveDraftTrade() {
        guard draftIsValid, let e = Double(draftEntry), let st = Double(draftStop), let sh = Double(draftShares) else { return }
        let trimmedNote = draftNote.trimmingCharacters(in: .whitespaces)
        let trade = TradeRecord(symbol: draftSymbol.trimmingCharacters(in: .whitespaces).uppercased(),
                                side: draftSide, entry: e, stop: st, target: Double(draftTarget),
                                shares: sh, openedAt: Date(),
                                note: trimmedNote.isEmpty ? nil : trimmedNote)
        journal.add(trade)
        draftSymbol = ""; draftEntry = ""; draftStop = ""; draftTarget = ""; draftShares = ""; draftNote = ""
        draftSide = .long
        withAnimation(.easeOut(duration: 0.15)) { showAddTrade = false }
    }

    /// Prefill the journal's inline add form from an idea, dismiss the detail
    /// sheet, and jump to the Portfolio section where the form lives. Robust —
    /// the form is inline, so there's no sheet-over-sheet presentation race.
    /// Ideas worth logging as a trade — bullish (Buy/Strong Buy) or bearish
    /// (Sell/Reduce) entries. Hold/Avoid are "stand aside", not trades.
    private func isLoggableIdea(_ action: TradeAdvice.Action) -> Bool {
        switch action {
        case .strongBuy, .buy, .sell, .reduce: return true
        case .hold, .avoid: return false
        }
    }

    private func prefillTradeFromIdea(_ idea: StockSageIdea) {
        let bearish = idea.advice.action == .sell || idea.advice.action == .reduce
        draftSymbol = idea.symbol
        draftEntry = String(format: "%.2f", idea.price)
        // Advisor only fills stop/target for long-biased buys; a short leaves them
        // blank for the owner to set (the form requires a protective stop per side).
        draftStop = bearish ? "" : (idea.advice.stopPrice.map { String(format: "%.2f", $0) } ?? "")
        draftTarget = bearish ? "" : (idea.advice.targetPrice.map { String(format: "%.2f", $0) } ?? "")
        draftShares = ""
        draftNote = "From idea: \(idea.advice.action.rawValue), \(Int(idea.advice.conviction * 100))% conviction"
        draftSide = bearish ? .short : .long   // side follows the idea's direction
        showAddTrade = true
        selectedIdea = nil          // dismiss the detail sheet
        section = .portfolio        // the journal lives in the Portfolio section
    }

    private func journalOpenRow(_ trade: TradeRecord) -> some View {
        let mark = currentPrice(trade.symbol)
        let pnl = mark.map { trade.profit(at: $0) }
        let r = mark.flatMap { trade.rMultiple(at: $0) }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(trade.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).frame(width: 64, alignment: .leading).lineLimit(1)
                Text(trade.side.rawValue).font(.system(size: mvFont9, weight: .semibold))
                    .foregroundStyle(trade.side == .long ? DS.Palette.successSoft : DS.Palette.danger)
                Text(String(format: "@ %.2f", trade.entry)).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if let pnl, let r {
                    Text(String(format: "%+.0f", pnl)).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(pnl >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                    Text(String(format: "%+.2fR", r)).font(.caption2).foregroundStyle(.secondary).frame(width: 48, alignment: .trailing)
                } else {
                    Text("no live px").font(.caption2).foregroundStyle(.secondary)
                }
                Button {
                    closeExitText = mark.map { String(format: "%.2f", $0) } ?? ""
                    withAnimation(.easeOut(duration: 0.12)) { closingTradeID = (closingTradeID == trade.id) ? nil : trade.id }
                } label: {
                    Text(closingTradeID == trade.id ? "Cancel" : "Close").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            if let note = trade.note, !note.isEmpty {
                Text(note).font(.system(size: mvFont9)).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            if closingTradeID == trade.id {
                HStack(spacing: 8) {
                    journalField("Exit px", text: $closeExitText, width: 80)
                    Button {
                        if let exit = Double(closeExitText), exit > 0 { journal.close(trade.id, exitPrice: exit); closingTradeID = nil }
                    } label: {
                        Text("Confirm close").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5).background(DS.Palette.danger, in: Capsule())
                    }.buttonStyle(LuxPressStyle()).disabled((Double(closeExitText) ?? 0) <= 0)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func journalClosedRow(_ trade: TradeRecord) -> some View {
        let pnl = trade.realizedProfit ?? 0
        return HStack(spacing: 8) {
            Text(trade.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.85)).frame(width: 64, alignment: .leading).lineLimit(1)
            Text(String(format: "%.2f→%.2f", trade.entry, trade.exitPrice ?? 0)).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%+.0f", pnl)).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(pnl >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
            if let r = trade.realizedR {
                Text(String(format: "%+.2fR", r)).font(.caption2).foregroundStyle(.secondary).frame(width: 48, alignment: .trailing)
            }
            Button { journal.remove(trade.id) } label: {
                Image(systemName: "trash").font(.system(size: mvFont9)).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    // MARK: Kelly position sizer

    private var kellySizerPanel: some View {
        let k = StockSageKelly.compute(winRate: (Double(kellyWinRate) ?? 0) / 100,
                                       payoffRatio: Double(kellyPayoff) ?? 0,
                                       accountSize: Double(kellyAccount) ?? 0)
        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "percent").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Position sizer (Kelly)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .help(StockSageGlossary.kellyHelp)
                    Text("How much to risk per trade, from your win-rate & payoff.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                kellyField($kellyWinRate, "Win %", width: 56)
                kellyField($kellyPayoff, "Payoff R", width: 64)
                kellyField($kellyAccount, "Account $", width: 92)
                Spacer(minLength: 0)
            }
            if let bt = store.backtest, bt.isSignificant,
               let inp = StockSageKelly.inputs(winRate: bt.winRate, avgWinR: bt.avgWinR, avgLossR: bt.avgLossR) {
                Button {
                    kellyWinRate = String(format: "%.0f", inp.winRate * 100)
                    kellyPayoff = String(format: "%.2f", inp.payoffRatio)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc.fill").font(.system(size: 10, weight: .semibold))
                        Text("Use \(store.backtestSymbol ?? "symbol") backtest (\(bt.trades) trades)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(DS.Palette.accent)
                }
                .buttonStyle(.plain)
                .help("Fill Win% and Payoff from the backtested win-rate and avg-win÷avg-loss — still a backward-looking estimate.")
            }
            if let ji = journal.kellyInputs {
                Button {
                    kellyWinRate = String(format: "%.0f", ji.winRate * 100)
                    kellyPayoff = String(format: "%.2f", ji.payoffRatio)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "book.closed.fill").font(.system(size: 10, weight: .semibold))
                        Text("Use my journal (\(ji.n) trades)").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(DS.Palette.accent)
                }
                .buttonStyle(.plain)
                .help("Fill Win% and Payoff from your OWN logged trades (≥10 closed, with wins and losses) — your real edge, not a backtest.")
            }
            HStack(spacing: 18) {
                ideaMetric("Full Kelly", String(format: "%.0f%%", k.fullKelly * 100))
                ideaMetric("Half", String(format: "%.0f%%", k.halfKelly * 100), color: DS.Palette.successSoft)
                ideaMetric("Suggested", String(format: "%.0f%%", k.suggestedFraction * 100), color: DS.Palette.accent)
                ideaMetric("Risk $", String(format: "%.0f", k.dollarsToRisk))
                Spacer(minLength: 0)
            }
            Text(k.note).font(.caption2)
                .foregroundStyle(k.fullKelly > 0 ? DS.Palette.successSoft : DS.Palette.warningSoft)
            Text(k.caveat).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func kellyField(_ text: Binding<String>, _ label: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: mvFont9, weight: .semibold)).foregroundStyle(.secondary)
            TextField("", text: text)
                .textFieldStyle(.plain).font(.system(size: 13)).frame(width: width)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                    .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                .accessibilityLabel(label)
        }
    }

    // MARK: Portfolio risk analytics

    private var portfolioAnalyticsPanel: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "chart.pie.fill").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risk analytics").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .help(StockSageGlossary.analyticsHelp)
                    Text("Sharpe · drawdown · VaR · correlation across your holdings.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { Task { await store.refreshPortfolioAnalytics() } } label: {
                    HStack(spacing: 6) {
                        Group {
                            if store.isLoadingAnalytics { ProgressView().controlSize(.small).tint(.white) }
                            else { Image(systemName: "function").font(.system(size: 11, weight: .semibold)) }
                        }
                        Text(store.isLoadingAnalytics ? "Analyzing…" : "Analyze")
                            .font(.system(size: 11.5, weight: .semibold)).contentTransition(.opacity)
                    }
                    .foregroundStyle(.white).padding(.horizontal, 11).padding(.vertical, 6)
                    .background(DS.Palette.accent, in: Capsule())
                }
                .buttonStyle(LuxPressStyle()).disabled(store.isLoadingAnalytics)
            }
            if let e = store.analyticsError {
                Text(e).font(.caption2).foregroundStyle(DS.Palette.warningSoft)
            }
            if let a = store.analytics {
                HStack(spacing: 18) {
                    ideaMetric("Ann. return", String(format: "%+.1f%%", a.annualizedReturn),
                               color: a.annualizedReturn >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                    ideaMetric("Volatility", String(format: "%.1f%%", a.annualizedVolatility))
                    ideaMetric("Sharpe", a.sharpe.map { String(format: "%.2f", $0) } ?? "n/a",
                               color: a.sharpe == nil ? .secondary : (a.sharpe! >= 1 ? DS.Palette.successSoft : (a.sharpe! >= 0.3 ? .white : DS.Palette.danger)))
                    ideaMetric("Sortino", a.sortino.map { String(format: "%.2f", $0) } ?? "n/a")
                    Spacer(minLength: 0)
                }
                HStack(spacing: 18) {
                    ideaMetric("Max DD", String(format: "−%.1f%%", a.maxDrawdown), color: DS.Palette.danger)
                    ideaMetric("Calmar", String(format: "%.2f", a.calmar))
                    ideaMetric("VaR 95%", String(format: "−%.1f%%", a.valueAtRisk95), color: DS.Palette.danger)
                    ideaMetric("Avg corr", String(format: "%.2f", a.avgCorrelation))
                    if let beta = store.portfolioBeta {
                        ideaMetric("β vs S&P", String(format: "%.2f", beta),
                                   color: beta > 1.15 ? DS.Palette.warningSoft : (beta < 0 ? DS.Palette.accent : .white))
                            .help(StockSageGlossary.betaHelp)
                    }
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Diversification").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f / 100", a.diversificationScore)).font(.caption2).foregroundStyle(.white)
                    }
                    convictionMeter(a.diversificationScore / 100,
                                    color: a.diversificationScore >= 60 ? DS.Palette.successSoft
                                         : (a.diversificationScore >= 30 ? DS.Palette.warningSoft : DS.Palette.danger))
                }
                Text("\(a.observations) days · \(a.holdingsAnalyzed) holdings · \(a.caveat)")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    // MARK: Heatmap

    private var heatmap: some View {
        Group {
            if store.symbols.isEmpty {
                emptyState
                    .transition(.opacity)
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
                .transition(.opacity)
            }
        }
        .animation(DS.Motion.smooth, value: store.symbols.isEmpty)
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
            addSymbolBar
            if store.symbols.isEmpty {
                emptyState
                    .transition(.opacity)
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

    private var addSymbolBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
                TextField("Track any ticker — AAPL · 2222.SR · BTC-USD · EURUSD=X", text: $newWatchSymbol)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .onSubmit { Task { await addWatchSymbol() } }
                    .accessibilityLabel("Ticker to add to watchlist")
                if store.isAddingSymbol {
                    ProgressView().controlSize(.small)
                } else {
                    Button { Task { await addWatchSymbol() } } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundStyle(DS.Palette.accent)
                    }
                    .buttonStyle(LuxPressStyle())
                    .disabled(newWatchSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
                    .help("Validate against a live quote, then add to the watchlist")
                    .accessibilityLabel("Add ticker to watchlist")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))

            // Catalog autocomplete — search the full directory (incl. names not yet on
            // the board) and one-tap add. Hidden once the query already matches a tracked row.
            let q = newWatchSymbol.trimmingCharacters(in: .whitespaces)
            let suggestions: [StockSageSymbol] = q.isEmpty ? [] :
                StockSageUniverse.search(q, limit: 6).filter { sug in
                    !store.symbols.contains { $0.symbol.uppercased() == sug.symbol.uppercased() }
                }
            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { sug in
                        Button {
                            newWatchSymbol = sug.symbol
                            Task { await addWatchSymbol() }
                        } label: {
                            HStack(spacing: 8) {
                                Text(sug.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                                    .frame(minWidth: 64, alignment: .leading)
                                Text(sug.market).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "plus.circle").font(.system(size: 12)).foregroundStyle(DS.Palette.accent)
                            }
                            .padding(.vertical, 5).padding(.horizontal, 8).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add \(sug.symbol), \(sug.market)")
                    }
                }
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                    .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
            }
            if let err = store.addSymbolError {
                Text(err).font(.caption2).foregroundStyle(DS.Palette.warningSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            Button { showBrowseMarkets = true } label: {
                Label("Browse all \(StockSageUniverse.catalog.count) markets", systemImage: "square.grid.2x2")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(DS.Palette.accent)
            }
            .buttonStyle(.plain)
            .help("Browse the full searchable directory by region & asset class; tap + to track any (fetches one quote).")
        }
        .animation(DS.Motion.smooth, value: store.addSymbolError)
        .sheet(isPresented: $showBrowseMarkets) { BrowseMarketsView(store: store) }
    }

    private func addWatchSymbol() async {
        await store.addSymbol(newWatchSymbol)
        if store.addSymbolError == nil { newWatchSymbol = "" }
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
                    Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.system(size: mvFont9, weight: .bold))
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
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(hovered ? Color.white.opacity(0.055) : DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(hovered ? DS.Palette.accent.opacity(0.35) : DS.Palette.surfaceStroke, lineWidth: 1))
        .scaleEffect(hovered ? 1.008 : 1.0)
        .shadow(color: DS.Palette.accent.opacity(hovered ? 0.10 : 0), radius: 10, y: 3)
        .animation(DS.Motion.smooth, value: hovered)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.smooth) {
                if over { hoveredSignalID = sym.id }
                else if hoveredSignalID == sym.id { hoveredSignalID = nil }
            }
        }
        .help(signal?.reason ?? "")
        .contextMenu {
            if sym.market == "★ My watchlist" {
                Button(role: .destructive) { store.removeSymbol(sym.symbol) } label: {
                    Label("Remove “\(sym.symbol)” from watchlist", systemImage: "trash")
                }
            }
        }
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
        default:                 return Color(white: 0.06)   // darker ink → AA contrast on bright pastels
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
                        Group {
                            if loadingBriefing { ProgressView().controlSize(.small).tint(.white) }
                            else { Image(systemName: "sparkles") }
                        }
                        .transition(.opacity)
                        .animation(DS.Motion.smooth, value: loadingBriefing)
                        Text(loadingBriefing ? "Generating…" : "Generate")
                            .contentTransition(.opacity)
                            .animation(DS.Motion.smooth, value: loadingBriefing)
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
                .contentTransition(.opacity)
                .animation(DS.Motion.smooth, value: briefing.isEmpty)
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func generateBriefing() async {
        loadingBriefing = true
        briefing = await StockSageBriefingService.generateBriefing(for: store.symbols)
        loadingBriefing = false
    }

    // MARK: Ideas (the advisor across the universe)

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            ideasHeader
            bestOpportunityCard
            fastLaneStrip
            alertsPanel
            strategyBacktestPanel
            backtestPanel
            if store.ideas.isEmpty {
                Text(store.isLoadingIdeas
                     ? "Analyzing every market on 1-year price history…"
                     : "Tap “Find ideas” to scan every market and rank the strongest rules-based setups.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 22)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            } else {
                HStack(spacing: 8) {
                    Text("Sort:").font(.system(size: 10)).foregroundStyle(.secondary)
                    Picker("", selection: $ideaSort) {
                        ForEach(IdeaSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 300)
                    Menu {
                        ForEach(IdeaFilter.allCases) { f in
                            Button { ideaFilter = f } label: { Label(f.rawValue, systemImage: ideaFilter == f ? "checkmark" : "") }
                        }
                    } label: {
                        Label(ideaFilter == .all ? "Filter" : ideaFilter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 10)).foregroundStyle(ideaFilter == .all ? .secondary : DS.Palette.accent)
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel("Filter ideas by action")
                    Spacer()
                }
                if displayedIdeas.isEmpty {
                    Text("No \(ideaFilter.rawValue.lowercased()) ideas in this scan.")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 12)
                } else {
                    VStack(spacing: DS.Space.sm) {
                        ForEach(displayedIdeas) { ideaCard($0) }
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(DS.Motion.smooth, value: store.ideas.count)
    }

    /// The ideas in display order — by expected value (best bet first) or the
    /// store's default signal rank.
    private var displayedIdeas: [StockSageIdea] {
        let sorted: [StockSageIdea]
        switch ideaSort {
        case .ev:       sorted = StockSageExpectedValue.rankByEV(store.ideas)
        case .velocity: sorted = StockSageExpectedValue.rankByVelocity(store.ideas, holds: velocityHolds)
        case .signal:   sorted = store.ideas
        }
        switch ideaFilter {
        case .all:       return sorted
        case .strongBuy: return sorted.filter { $0.advice.action == .strongBuy }
        case .buys:      return sorted.filter { $0.advice.action == .strongBuy || $0.advice.action == .buy }
        case .sells:     return sorted.filter { $0.advice.action == .sell || $0.advice.action == .reduce }
        }
    }

    private var ideasHeader: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 18)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trade ideas").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Text("Rules-based what / when / how-much across the \(StockSageUniverse.worldwide.count)-name analyzed core, on 1-year history.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { Task { await store.refreshIdeas() } } label: {
                    HStack(spacing: 6) {
                        Group {
                            if store.isLoadingIdeas { ProgressView().controlSize(.small).tint(.white) }
                            else { Image(systemName: "wand.and.stars").font(.system(size: 11, weight: .semibold)) }
                        }
                        Text(store.isLoadingIdeas ? "Analyzing…" : "Find ideas")
                            .font(.system(size: 11.5, weight: .semibold)).contentTransition(.opacity)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(DS.Palette.accent, in: Capsule())
                    .shadow(color: DS.Palette.accent.opacity(0.25), radius: 4, y: 1)
                }
                .buttonStyle(LuxPressStyle()).disabled(store.isLoadingIdeas)
            }
            if let when = store.ideasUpdated {
                let stale = when.timeIntervalSinceNow < -4 * 3600   // scan older than 4h
                Text(stale
                     ? "⚠︎ Analyzed \(when.formatted(.relative(presentation: .named))) — over 4h old; re-scan for current ideas · ranked by \(ideaSort.rawValue.lowercased())"
                     : "Analyzed \(Self.timeFormatter.string(from: when)) · ranked by \(ideaSort.rawValue.lowercased())")
                    .font(.caption2).foregroundStyle(stale ? DS.Palette.warningSoft : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !store.ideasMissing.isEmpty {
                let miss = store.ideasMissing
                HStack(alignment: .top, spacing: 6) {
                    Text("⚠︎ \(store.ideas.count) priced · \(miss.count) couldn't be fetched (\(miss.prefix(3).joined(separator: ", "))\(miss.count > 3 ? "…" : "")) — ranking covers only what loaded.")
                        .font(.caption2).foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button { Task { await store.retryFailedIdeas() } } label: {
                        Text("Retry failed").font(.caption2.weight(.semibold)).foregroundStyle(DS.Palette.accent)
                    }
                    .buttonStyle(.plain).disabled(store.isLoadingIdeas)
                    .accessibilityLabel("Retry fetching the \(miss.count) symbols that failed")
                }
            }
            if let err = store.ideasError {
                Text(err).font(.caption2).foregroundStyle(DS.Palette.warningSoft)
            }
            Text(StockSageAdvisor.caveat)
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func ideaCard(_ idea: StockSageIdea) -> some View {
        let a = idea.advice
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(idea.symbol).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(idea.market).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(a.action.rawValue)
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(actionTextColor(a.action))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(actionColor(a.action), in: Capsule())
                if let ev = StockSageExpectedValue.ev(for: idea) {
                    Text(String(format: "%+.2fR EV", ev.evR))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ev.isPositive ? DS.Palette.successSoft : DS.Palette.warningSoft)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((ev.isPositive ? DS.Palette.successSoft : DS.Palette.warningSoft).opacity(0.14), in: Capsule())
                        .help("Estimated expected value per trade (conviction→win-prob estimate × reward:risk). An estimate, not a forecast.")
                }
                Button { Task { await store.runBacktest(symbol: idea.symbol) } } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                }
                .buttonStyle(LuxPressStyle()).disabled(store.isBacktesting)
                .help("Backtest \(idea.symbol) over 5 years")
                .accessibilityLabel("Backtest \(idea.symbol)")
            }
            convictionMeter(a.conviction, color: actionColor(a.action))
            if idea.spark.count >= 2 {
                Sparkline(values: idea.spark)
                    .stroke(sparkColor(idea.spark),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(height: 22)
                    .opacity(0.9)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 16) {
                ideaMetric("Price", String(format: "%.2f", idea.price))
                if let stop = a.stopPrice {
                    ideaMetric("Stop", String(format: "%.2f", stop), color: DS.Palette.danger)
                }
                if let target = a.targetPrice {
                    ideaMetric("Target", String(format: "%.2f", target), color: DS.Palette.successSoft)
                }
                if a.suggestedWeight > 0 {
                    ideaMetric("Size", String(format: "%.1f%%", a.suggestedWeight * 100), color: DS.Palette.accent)
                }
                Spacer(minLength: 0)
            }
            Text("\(a.regime.rawValue) · " + a.rationale.prefix(2).joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        // One combined, activatable element (mirrors the watchlist card): the
        // custom label carries the conviction, the DEFAULT action opens the detail
        // sheet (VoiceOver double-tap), and Backtest is a named rotor action — so
        // both stay reachable WITHOUT losing the summary (the `.contain` attempt
        // dropped the label and left the tap non-activatable).
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(idea.symbol), \(a.action.rawValue), conviction \(Int(a.conviction * 100)) percent")
        .accessibilityHint("Opens full advice and backtest")
        .accessibilityAction { selectedIdea = idea }
        .accessibilityAction(named: "Backtest") { Task { await store.runBacktest(symbol: idea.symbol) } }
        .contentShape(Rectangle())
        .onTapGesture { selectedIdea = idea }
        .help("Tap for full advice + backtest")
    }

    // Signal alerts — opt-in event log of flips / stop / target crossings.
    private var alertsPanel: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "bell.badge.fill").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signal alerts").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Text("Flags when an idea turns bullish/bearish or its price crosses the advised stop or target — between refreshes.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $store.alertsEnabled).labelsHidden().toggleStyle(.switch).tint(DS.Palette.accent)
            }
            if !store.alertsEnabled {
                Text("Off — turn on, then refresh ideas to start detecting events. Events fire on a crossing, so they don't repeat every refresh.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if store.alerts.isEmpty {
                Text("On — no events yet. They'll appear here when an idea flips or a stop/target is crossed on a future refresh.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(store.alerts.prefix(12).enumerated()), id: \.offset) { _, alert in
                    HStack(spacing: 8) {
                        Image(systemName: alertIcon(alert.kind))
                            .font(.system(size: 11)).foregroundStyle(alert.isWarning ? DS.Palette.danger : DS.Palette.successSoft)
                            .frame(width: 14)
                        Text(alert.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 64, alignment: .leading).lineLimit(1)
                        Text(alert.kind.rawValue).font(.caption2)
                            .foregroundStyle(alert.isWarning ? DS.Palette.danger : DS.Palette.successSoft)
                            .frame(width: 86, alignment: .leading)
                        Text(alert.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                Button { store.clearAlerts() } label: {
                    Text("Clear").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func alertIcon(_ kind: IdeaAlert.Kind) -> String {
        switch kind {
        case .flipBullish: return "arrow.up.right.circle.fill"
        case .flipBearish: return "arrow.down.right.circle.fill"
        case .stopBreach:  return "exclamationmark.triangle.fill"
        case .targetHit:   return "target"
        }
    }

    // Best opportunity now — the single highest positive-EV buy idea (money velocity).
    @ViewBuilder private var bestOpportunityCard: some View {
        if let best = StockSageExpectedValue.bestOpportunity(store.ideas) {
            let idea = best.idea, ev = best.ev
            VStack(alignment: .leading, spacing: 6) {
            Button { selectedIdea = idea } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill").font(.system(size: 13)).foregroundStyle(DS.Palette.accent)
                        Text("Best opportunity now").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                        Text(idea.advice.action.rawValue).font(.system(size: 10, weight: .bold))
                            .foregroundStyle(actionTextColor(idea.advice.action))
                            .padding(.horizontal, 7).padding(.vertical, 2).background(actionColor(idea.advice.action), in: Capsule())
                    }
                    HStack(spacing: 16) {
                        Text(idea.symbol).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        ideaMetric("Est. EV", String(format: "%+.2fR", ev.evR), color: DS.Palette.successSoft)
                        ideaMetric("R:R", String(format: "%.1f:1", ev.rewardR))
                        ideaMetric("Win est.", String(format: "~%.0f%%", ev.winProbEstimate * 100))
                        if idea.advice.suggestedWeight > 0 {
                            ideaMetric("Size", String(format: "%.1f%%", idea.advice.suggestedWeight * 100))
                        }
                        Spacer(minLength: 0)
                    }
                    if let stop = idea.advice.stopPrice, let acct = Double(sizerAccount), acct > 0,
                       let rp = Double(sizerRiskPct), rp > 0,
                       let ps = StockSagePositionSizer.size(account: acct, riskFraction: rp / 100, entry: idea.price, stop: stop) {
                        Text("Size it now: \(StockSagePositionSizer.summaryLine(ps, riskPct: rp))")
                            .font(.system(size: mvFont9, weight: .medium))
                            .foregroundStyle(ps.pctOfAccount > 100 ? DS.Palette.warningSoft : DS.Palette.successSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(MoneyVelocityCopy.bestOpportunity)
                        .font(.system(size: mvFont9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(DS.Palette.accent.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(LuxPressStyle())
            .accessibilityLabel("Best opportunity: \(idea.symbol), estimated EV \(String(format: "%.2f", ev.evR)) R")
            HStack(spacing: 6) {
                Spacer()
                Button {
                    let plan = StockSageTodayPlan.build(
                        idea: idea, ev: ev,
                        account: Double(sizerAccount),
                        riskFraction: Double(sizerRiskPct).map { $0 / 100 },
                        daysToEarnings: store.earnings[idea.symbol.uppercased()]?.daysUntil)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(plan, forType: .string)
                } label: {
                    Label("Copy today's plan", systemImage: "checklist").font(.system(size: mvFont9, weight: .medium))
                }
                .buttonStyle(.plain).foregroundStyle(DS.Palette.accent)
                .help("Copy a checklist — best bet, the pre-trade gate verdict, and the size — to the clipboard. Estimates, not advice.")
            }
            }
        }
    }

    // Money-velocity summary — one-glance header (best bet · fastest · est. weekly R),
    // visible across every section. Tappable to the best opportunity's plan.
    @ViewBuilder private var moneyVelocityCard: some View {
        let s = StockSageExpectedValue.summary(store.ideas, trades: journal.trades, holds: velocityHolds)
        if s.hasContent {
            VStack(alignment: .leading, spacing: 6) {
            Button {
                if let best = StockSageExpectedValue.bestOpportunity(store.ideas) { selectedIdea = best.idea }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundStyle(DS.Palette.accent)
                        Text("Money velocity — fastest moves now").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                    }
                    HStack(alignment: .top, spacing: 18) {
                        if let sym = s.bestSymbol, let ev = s.bestEV {
                            summaryStat("Best now", sym, String(format: "%+.2fR EV", ev))
                        }
                        if let sym = s.fastestSymbol, let v = s.fastestVelocity {
                            summaryStat("Fastest", sym, String(format: "%+.2fR/day", v))
                        }
                        if let wk = s.weeklyR {
                            summaryStat("Est./week", String(format: "%+.1fR", wk), "if you run top 3")
                        }
                        Spacer(minLength: 0)
                    }
                    if let acct = Double(sizerAccount), acct > 0, let rp = Double(sizerRiskPct), rp > 0,
                       let usd = StockSageExpectedValue.expectedWeeklyDollars(store.ideas, account: acct, riskFraction: rp / 100, holds: velocityHolds) {
                        Text(String(format: "≈ +$%.0f/week at $%.0f acct, %.1f%% risk — %@", usd, acct, rp, MoneyVelocityCopy.weeklyDollars))
                            .font(.system(size: mvFont9, weight: .medium))
                            .foregroundStyle(DS.Palette.successSoft).fixedSize(horizontal: false, vertical: true)
                    }
                    if let d = velocityHistory.lastDelta, abs(d) >= 0.05 {
                        Text(String(format: "Since last session: weekly-R %@ %.1fR — %@", d >= 0 ? "↑" : "↓", abs(d), MoneyVelocityCopy.ownHistory))
                            .font(.system(size: mvFont8))
                            .foregroundStyle(d >= 0 ? DS.Palette.successSoft : DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                    }
                    if let ch = velocityHistory.change {
                        let movers = [ch.bestChangedTo.map { "best → \($0)" }, ch.fastestChangedTo.map { "fastest → \($0)" }].compactMap { $0 }
                        if !movers.isEmpty {
                            Text("Mover: \(movers.joined(separator: ", ")) — \(MoneyVelocityCopy.ownHistory)")
                                .font(.system(size: mvFont8)).foregroundStyle(DS.Palette.accent).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let t = velocityHistory.trend {
                        let rising = t.direction == .rising, fading = t.direction == .fading
                        HStack(spacing: 5) {
                            Image(systemName: rising ? "arrow.up.right" : (fading ? "arrow.down.right" : "arrow.right"))
                                .font(.system(size: mvFont8, weight: .bold))
                                .foregroundStyle(rising ? DS.Palette.successSoft : (fading ? DS.Palette.warningSoft : .secondary))
                            Text(String(format: "Your opportunity set is %@ (recent wk-R %+.1f vs %+.1f early) — %@",
                                        t.direction.rawValue, t.recentAvg, t.earlyAvg, MoneyVelocityCopy.ownHistory))
                                .font(.system(size: mvFont8)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            if velocityHistory.series.count >= 2 {
                                Sparkline(values: velocityHistory.series.map(\.weeklyR))
                                    .stroke(rising ? DS.Palette.successSoft : (fading ? DS.Palette.warningSoft : DS.Palette.surfaceStroke),
                                            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                                    .frame(width: 48, height: 14)
                            }
                        }
                    }
                    if let ddPct = s.worstRunDrawdownPct, let losses = s.worstRunLosses {
                        Text(String(format: "⚠︎ Brake — your worst run (%d) at 1%%/trade ≈ −%.1f%% to the account. %@", losses, ddPct * 100, MoneyVelocityCopy.drawdownBrake))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(String(format: "Risk warning: worst losing run %d trades at 1 percent risk is about %.1f percent drawdown. Size to survive variance.", losses, ddPct * 100))
                    }
                    Text(MoneyVelocityCopy.summary)
                        .font(.system(size: mvFont9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(DS.Palette.accent.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(LuxPressStyle())
            .accessibilityLabel("Money velocity summary; tap for the best opportunity")
            .help(StockSageGlossary.moneyVelocityHelp)
            HStack(spacing: 6) {
                Spacer()
                Button {
                    let plan = StockSageExpectedValue.playbook(s)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(plan, forType: .string)
                } label: {
                    Label("Copy plan", systemImage: "doc.on.doc").font(.system(size: mvFont9, weight: .medium))
                }
                .buttonStyle(.plain).foregroundStyle(DS.Palette.accent)
                .help("Copy a short, caveated money-velocity action list to the clipboard.")
            }
            }
        }
    }

    private func summaryStat(_ label: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(.system(size: mvFont8, weight: .semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
            Text(sub).font(.system(size: mvFont8)).foregroundStyle(DS.Palette.successSoft).lineLimit(1)
        }
    }

    // Fast lane — the highest-turnover positive-EV setups (fastest compounding).
    @ViewBuilder private var fastLaneStrip: some View {
        let lane = StockSageExpectedValue.fastLane(store.ideas, holds: velocityHolds)
        if lane.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "hare.fill").font(.system(size: 11)).foregroundStyle(DS.Palette.accent)
                    Text("Fast lane — fastest compounding").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                }
                ForEach(lane.prefix(3), id: \.id) { idea in
                    if let v = StockSageExpectedValue.velocity(for: idea, holds: velocityHolds) {
                        Button { selectedIdea = idea } label: {
                            HStack(spacing: 8) {
                                Text(idea.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                                    .frame(width: 84, alignment: .leading)
                                Text(String(format: "%+.3fR/day", v)).font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(DS.Palette.successSoft)
                                if idea.symbol.hasSuffix("-USD") {
                                    Text("24/7 · volatile").font(.system(size: mvFont8)).foregroundStyle(DS.Palette.warningSoft)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.system(size: mvFont8)).foregroundStyle(.secondary)
                            }.contentShape(Rectangle())
                        }.buttonStyle(LuxPressStyle())
                        .accessibilityLabel("\(idea.symbol): \(String(format: "%+.3f", v)) R per day velocity\(idea.symbol.hasSuffix("-USD") ? ", 24/7 volatile" : ""). Tap for the plan.")
                    }
                }
                if let wk = StockSageExpectedValue.expectedWeeklyR(store.ideas, holds: velocityHolds) {
                    Text(String(format: "≈ %+.1fR/week if you run the top %d — estimate, high variance, assumes you take and re-cycle these. Not a promise.", wk, Swift.min(3, lane.count)))
                        .font(.system(size: mvFont9, weight: .medium))
                        .foregroundStyle(DS.Palette.successSoft).fixedSize(horizontal: false, vertical: true)
                    if let acct = Double(sizerAccount), acct > 0, let rp = Double(sizerRiskPct), rp > 0,
                       let usd = StockSageExpectedValue.expectedWeeklyDollars(store.ideas, account: acct, riskFraction: rp / 100, holds: velocityHolds) {
                        Text(String(format: "≈ +$%.0f/week at $%.0f account, %.1f%% risk — estimate, high variance, NOT income.", usd, acct, rp))
                            .font(.system(size: mvFont9, weight: .medium))
                            .foregroundStyle(DS.Palette.successSoft).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let conc = StockSageExpectedValue.fastLaneConcentration(store.ideas, holds: velocityHolds), conc.isConcentrated {
                    Text("⚠︎ Your top \(conc.total) fastest are all \(conc.dominantClass) — that's closer to ONE bet than \(conc.total); they tend to move together. Diversify or size them as one.")
                        .font(.system(size: mvFont9, weight: .medium))
                        .foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                }
                Text(MoneyVelocityCopy.fastLane)
                    .font(.system(size: mvFont9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Text("Hold est:").font(.system(size: mvFont9)).foregroundStyle(.secondary)
                    Stepper(value: $cryptoHoldDays, in: 1...60, step: 1) {
                        Text("crypto \(Int(cryptoHoldDays))d").font(.system(size: mvFont9)).foregroundStyle(.white)
                    }.frame(maxWidth: 132)
                    Stepper(value: $equityHoldDays, in: 1...180, step: 1) {
                        Text("equity \(Int(equityHoldDays))d").font(.system(size: mvFont9)).foregroundStyle(.white)
                    }.frame(maxWidth: 132)
                    Spacer(minLength: 0)
                }
                .help("Typical days you hold each — velocity is EV ÷ hold, so a shorter hold raises EV/day. A rough assumption, not a measurement.")
            }
            .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Palette.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(DS.Palette.accent.opacity(0.25), lineWidth: 1))
            .help(StockSageGlossary.explain(.fastLane))
        }
    }

    // Strategy backtest — the advisor's rules aggregated across the sample universe.
    private var strategyBacktestPanel: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "chart.bar.xaxis").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strategy backtest").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .help(StockSageGlossary.strategyHelp)
                    Text(store.strategyBacktest.map { "Tested \($0.symbolsTested)/\(StockSageStrategyBacktest.sampleSymbols.count) names, ~5 years — does the system hold up?" }
                         ?? "The advisor's rules across the sample (~\(StockSageStrategyBacktest.sampleSymbols.count) names), ~5 years — does the system hold up?")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { Task { await store.refreshStrategyBacktest() } } label: {
                    HStack(spacing: 6) {
                        Group {
                            if store.isLoadingStrategy { ProgressView().controlSize(.small).tint(.white) }
                            else { Image(systemName: "play.fill").font(.system(size: 10, weight: .semibold)) }
                        }
                        Text(store.isLoadingStrategy ? "Running…" : "Run").font(.system(size: 11, weight: .semibold)).contentTransition(.opacity)
                    }
                    .foregroundStyle(.white).padding(.horizontal, 11).padding(.vertical, 6)
                    .background(DS.Palette.accent, in: Capsule())
                }
                .buttonStyle(LuxPressStyle()).disabled(store.isLoadingStrategy)
                .help("Backtest the advisor's rules across the sample universe (~5y each)")
            }
            if let e = store.strategyError {
                Text(e).font(.caption2).foregroundStyle(DS.Palette.warningSoft)
            }
            if let s = store.strategyBacktest {
                HStack(spacing: 16) {
                    ideaMetric("Trades", "\(s.totalTrades)")
                    ideaMetric("Win", String(format: "%.0f%%", s.blendedWinRate * 100),
                               color: s.blendedWinRate >= 0.5 ? DS.Palette.successSoft : DS.Palette.danger)
                    ideaMetric("Avg R", String(format: "%+.2f", s.avgR),
                               color: s.avgR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                    ideaMetric("Total R", String(format: "%+.0f", s.totalR),
                               color: s.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                    ideaMetric("Worst-name DD", String(format: "−%.0fR", s.worstDrawdownR), color: DS.Palette.danger)
                    ideaMetric("Profit.", "\(s.symbolsProfitable)/\(s.symbolsWithTrades)")
                    Spacer(minLength: 0)
                }
                if !s.isSignificant && s.totalTrades > 0 {
                    Text("⚠︎ \(s.totalTrades) trades — still a small sample; treat as illustrative.")
                        .font(.caption2).foregroundStyle(DS.Palette.warningSoft)
                }
                Text(s.caveat).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    // Backtest result panel — appears when a symbol has been (or is being) tested.
    @ViewBuilder private var backtestPanel: some View {
        if store.isBacktesting || store.backtest != nil || store.backtestError != nil {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 13)).foregroundStyle(DS.Palette.accent)
                    Text(backtestTitle).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    if store.isBacktesting { ProgressView().controlSize(.small) }
                }
                if let err = store.backtestError {
                    Text(err).font(.caption2).foregroundStyle(DS.Palette.warningSoft)
                } else if let bt = store.backtest {
                    HStack(spacing: 16) {
                        ideaMetric("Trades", "\(bt.trades)")
                        ideaMetric("Win", String(format: "%.0f%%", bt.winRate * 100),
                                   color: bt.winRate >= 0.5 ? DS.Palette.successSoft : DS.Palette.danger)
                        ideaMetric("Avg R", String(format: "%+.2f", bt.avgR),
                                   color: bt.avgR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                        ideaMetric("Total R", String(format: "%+.1f", bt.totalR),
                                   color: bt.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                        ideaMetric("Max DD", String(format: "−%.1fR", bt.maxDrawdownR), color: DS.Palette.danger)
                        ideaMetric("Sharpe", String(format: "%.2f", bt.sharpe))
                        Spacer(minLength: 0)
                    }
                    if !bt.isSignificant && bt.trades > 0 {
                        Text("⚠︎ Only \(bt.trades) trades — too small a sample to trust; treat as illustrative.")
                            .font(.caption2).foregroundStyle(DS.Palette.warningSoft)
                    } else if bt.trades == 0 {
                        Text("The rules never triggered a long entry over this window.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let u = store.underwater, !u.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Buy & hold underwater (5y)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "worst −%.0f%% · longest %d bars under", u.maxDrawdown, u.longestUnderwaterBars))
                                    .font(.system(size: mvFont9, weight: .semibold)).foregroundStyle(DS.Palette.danger)
                            }
                            underwaterSparkline(u)
                        }
                    }
                    Text("Past performance ≠ future. Survivorship bias — only currently-listed names are tested. Rules are fixed, not optimized per symbol.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Palette.accent.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.accent.opacity(0.30), lineWidth: 1))
            .transition(.opacity.combined(with: .offset(y: -4)))
        }
    }

    /// Red area chart hanging from a 0 (new-high) line down to the worst drawdown.
    private func underwaterSparkline(_ u: UnderwaterCurve) -> some View {
        // Downsample for the path (5y daily ≈ 1250 pts) while keeping depth/duration from the full series.
        let s = u.series
        // Min-preserving buckets: each plotted point is the WORST (most negative)
        // value in its window, so downsampling can never skip the trough and
        // visually understate the drawdown vs the stated worst number.
        let k = max(1, s.count / 240)
        let plot: [Double] = s.count > 240
            ? stride(from: 0, to: s.count, by: k).map { lo in s[lo..<min(lo + k, s.count)].min() ?? s[lo] }
            : s
        let denom = -Swift.max(u.maxDrawdown, 0.5)   // bottom of the chart (avoid /0)
        return GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let n = plot.count
            let point: (Int) -> CGPoint = { i in
                let x = n > 1 ? w * CGFloat(i) / CGFloat(n - 1) : 0
                let frac = CGFloat(plot[i] / denom)   // 0 at a new high → 1 at the worst
                return CGPoint(x: x, y: h * min(max(frac, 0), 1))
            }
            ZStack {
                Path { p in
                    guard n > 0 else { return }
                    p.move(to: CGPoint(x: 0, y: 0))
                    for i in 0..<n { p.addLine(to: point(i)) }
                    p.addLine(to: CGPoint(x: w, y: 0))
                    p.closeSubpath()
                }.fill(DS.Palette.danger.opacity(0.18))
                Path { p in
                    guard n > 0 else { return }
                    p.move(to: point(0))
                    for i in 1..<n { p.addLine(to: point(i)) }
                }.stroke(DS.Palette.danger.opacity(0.85), lineWidth: 1)
            }
        }
        .frame(height: 34)
        .accessibilityLabel(String(format: "Underwater curve, worst drawdown %.0f percent", u.maxDrawdown))
    }

    @ViewBuilder private func positionSizerPanel(_ idea: StockSageIdea) -> some View {
        if let stop = idea.advice.stopPrice {
            let entry = idea.price
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "function").font(.system(size: 11)).foregroundStyle(DS.Palette.accent)
                    Text("Position size").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Text("Acct $").font(.system(size: mvFont9)).foregroundStyle(.secondary)
                    journalField("10000", text: $sizerAccount, width: 72)
                    Text("Risk %").font(.system(size: mvFont9)).foregroundStyle(.secondary)
                    journalField("1", text: $sizerRiskPct, width: 40)
                }
                if let acct = Double(sizerAccount), let rp = Double(sizerRiskPct),
                   let ps = StockSagePositionSizer.size(account: acct, riskFraction: rp / 100, entry: entry, stop: stop) {
                    let leveraged = ps.pctOfAccount > 100
                    HStack(spacing: 16) {
                        ideaMetric("Shares", "\(ps.shares)", color: DS.Palette.accent)
                        ideaMetric("At risk", String(format: "$%.0f", ps.dollarsAtRisk), color: DS.Palette.danger)
                        ideaMetric("Notional", String(format: "$%.0f", ps.notional))
                        ideaMetric("% acct", String(format: "%.0f%%", ps.pctOfAccount),
                                   color: leveraged ? DS.Palette.danger : .white)
                        Spacer(minLength: 0)
                    }
                    Text(String(format: "Sizes the LOSS: a stop-out at %.2f costs ~$%.0f (%@%% of the account). Not a profit promise.",
                                stop, ps.dollarsAtRisk, sizerRiskPct))
                        .font(.system(size: mvFont9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if leveraged {
                        Text("⚠︎ Notional exceeds your account — this needs margin/leverage. A gap or slippage THROUGH the stop can lose well more than the stated risk. Tight stops inflate share count; widen the stop or cut risk %.")
                            .font(.system(size: mvFont9)).foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("Enter a valid account size and risk %.").font(.system(size: mvFont9)).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
        }
    }

    private func riskChip(_ flag: RiskFlag) -> some View {
        let color = flag.level == .high ? DS.Palette.danger
                  : (flag.level == .caution ? DS.Palette.warningSoft : DS.Palette.textSecondary)
        return HStack(spacing: 4) {
            Image(systemName: flag.level == .high ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                .font(.system(size: mvFont9))
            Text(flag.label).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.5))
        .accessibilityLabel("Risk: \(flag.label)")
    }

    private var backtestTitle: String {
        if store.isBacktesting { return "Backtesting \(store.backtestSymbol ?? "")… (5y, walk-forward)" }
        if let s = store.backtestSymbol { return "Backtest: \(s) · 5y walk-forward" }
        return "Backtest"
    }

    // MARK: Idea detail sheet

    // Pre-trade gate verdict block for the detail sheet (go / caution / no-go + checks).
    @ViewBuilder private func tradeGateView(_ v: TradeGateVerdict) -> some View {
        let color: Color = v.decision == .blocked ? DS.Palette.danger
            : (v.decision == .caution ? DS.Palette.warningSoft : DS.Palette.successSoft)
        let icon = v.decision == .blocked ? "xmark.octagon.fill"
            : (v.decision == .caution ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
                Text("Pre-trade gate — \(v.decision.rawValue)").font(.system(size: 12, weight: .bold)).foregroundStyle(color)
                Spacer()
            }
            ForEach(v.checks.indices, id: \.self) { i in
                let c = v.checks[i]
                let cc: Color = c.level == .fail ? DS.Palette.danger : (c.level == .warn ? DS.Palette.warningSoft : DS.Palette.successSoft)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: c.level == .fail ? "xmark" : (c.level == .warn ? "exclamationmark" : "checkmark"))
                        .font(.system(size: mvFont9, weight: .bold)).foregroundStyle(cc).frame(width: 10)
                    Text(c.label).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(v.caveat).font(.system(size: mvFont9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.sm).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pre-trade gate: \(v.decision.rawValue). \(v.fails) failed, \(v.warns) warnings, \(v.passes) passed.")
    }

    private func ideaDetailSheet(_ idea: StockSageIdea) -> some View {
        let a = idea.advice
        return ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(idea.symbol).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text(idea.market).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(a.action.rawValue)
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(actionTextColor(a.action))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(actionColor(a.action), in: Capsule())
                    Button { selectedIdea = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain).help("Close").accessibilityLabel("Close")
                }

                if idea.spark.count >= 2 {
                    Sparkline(values: idea.spark)
                        .stroke(sparkColor(idea.spark), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(height: 64)
                        .accessibilityHidden(true)
                }

                convictionMeter(a.conviction, color: actionColor(a.action))
                Text("Conviction \(Int(a.conviction * 100))% · \(a.regime.rawValue)")
                    .font(.caption).foregroundStyle(.secondary)

                let riskFlags = StockSageRiskFlags.flags(
                    action: a.action, conviction: a.conviction, symbol: idea.symbol,
                    earnings: store.earnings[idea.symbol.uppercased()],
                    precheck: store.precheck[idea.symbol.uppercased()],
                    regimeIsStale: store.regimeIsStale, hasRegime: store.regime != nil,
                    liquidityTier: store.liquidity[idea.symbol.uppercased()]?.tier)
                if !riskFlags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) { ForEach(riskFlags) { riskChip($0) } }
                    }
                }

                if a.action == .buy || a.action == .strongBuy {
                    let rr: Double? = {
                        guard let stop = a.stopPrice, let tgt = a.targetPrice else { return nil }
                        let risk = abs(idea.price - stop)
                        guard risk > 0 else { return nil }
                        return abs(tgt - idea.price) / risk
                    }()
                    let rf = Double(sizerRiskPct).map { $0 / 100 } ?? 0.01
                    let gate = StockSageTradeGate.evaluate(
                        hasStop: a.stopPrice != nil, rewardToRisk: rr, riskFraction: rf,
                        daysToEarnings: store.earnings[idea.symbol.uppercased()]?.daysUntil)
                    tradeGateView(gate)

                    // Concentration-in-disguise: warn if this idea moves in lockstep with
                    // something already held (series sourced from the ideas board's sparklines).
                    let candReturns = StockSagePortfolioAnalytics.dailyReturns(idea.spark)
                    let heldSeries = portfolio.positions.compactMap { p -> (symbol: String, returns: [Double])? in
                        guard let sp = store.ideas.first(where: { $0.symbol.uppercased() == p.symbol.uppercased() })?.spark,
                              sp.count >= 2 else { return nil }
                        return (p.symbol, StockSagePortfolioAnalytics.dailyReturns(sp))
                    }
                    if let cc = StockSageClusterCheck.check(candidate: idea.symbol, candidateReturns: candReturns, holdings: heldSeries) {
                        // Show the verdict either way: a warning when it concentrates,
                        // an affirmation when it genuinely diversifies the book.
                        let cColor = cc.isConcentrating ? DS.Palette.warningSoft : DS.Palette.textSecondary
                        let cIcon = cc.isConcentrating ? "exclamationmark.triangle.fill" : "checkmark.shield.fill"
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: cIcon).font(.system(size: 11)).foregroundStyle(cColor)
                            Text(cc.note).font(.caption2).foregroundStyle(cColor).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(spacing: 20) {
                    ideaMetric("Price", String(format: "%.2f", idea.price))
                    if let s = a.stopPrice { ideaMetric("Stop", String(format: "%.2f", s), color: DS.Palette.danger) }
                    if let t = a.targetPrice { ideaMetric("Target", String(format: "%.2f", t), color: DS.Palette.successSoft) }
                    if a.suggestedWeight > 0 { ideaMetric("Size", String(format: "%.1f%%", a.suggestedWeight * 100), color: DS.Palette.accent) }
                    if a.suggestedWeight > 0, let r = store.regime {
                        let adj = StockSageRegime.adjustedWeight(base: a.suggestedWeight, bias: r.sizingBias, cap: StockSageAdvisor.maxWeight)
                        // Green ONLY when the regime CUTS size (de-risking). An up-size
                        // is neutral — bigger is not "safer".
                        ideaMetric("Regime size", String(format: "%.1f%%", adj * 100),
                                   color: adj < a.suggestedWeight ? DS.Palette.successSoft : DS.Palette.accent)
                    }
                    Spacer(minLength: 0)
                }
                if let stop = a.stopPrice, let target = a.targetPrice,
                   let rr = StockSageRewardRisk.assess(entry: idea.price, stop: stop, target: target) {
                    let c = rr.quality == .strong ? DS.Palette.successSoft
                          : (rr.quality == .poor ? DS.Palette.warningSoft : DS.Palette.textSecondary)
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "scalemass.fill").font(.system(size: 11)).foregroundStyle(c)
                        Text(rr.note).font(.caption2).foregroundStyle(c).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let stop = a.stopPrice, let target = a.targetPrice {
                    let costs = StockSageNetEdge.defaultCosts(forSymbol: idea.symbol)
                    if let ne = StockSageNetEdge.evaluate(
                        entry: idea.price, stop: stop, target: target,
                        spreadBps: costs.spreadBps, slippageBps: costs.slippageBps,
                        winProb: StockSageExpectedValue.ev(conviction: a.conviction, entry: idea.price, stop: stop, target: target)?.winProbEstimate) {
                        let c = ne.costErodesEdge ? DS.Palette.warningSoft : DS.Palette.textSecondary
                        let pre = "After ~\(Int(costs.roundTripBps))bps est. \(costs.assetClass) costs: "
                        let body = ne.netRR > 0
                            ? pre + String(format: "net R:R %.1f:1 (gross %.1f:1). %@", ne.netRR, ne.grossRR, ne.verdict)
                            : pre + ne.verdict
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "scissors").font(.system(size: 11)).foregroundStyle(c)
                            Text(body).font(.caption2).foregroundStyle(c).fixedSize(horizontal: false, vertical: true)
                                .help("Nets an asset-class round-trip spread+slippage estimate out of the reward:risk (crypto widest, FX/large-cap tightest). Your real costs differ — wide-margin trades barely notice; thin scalps can lose the whole edge.")
                        }
                    }
                }
                if let stop = a.stopPrice, let target = a.targetPrice,
                   let ev = StockSageExpectedValue.ev(conviction: a.conviction, entry: idea.price, stop: stop, target: target) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill").font(.system(size: 11))
                            .foregroundStyle(ev.isPositive ? DS.Palette.successSoft : DS.Palette.warningSoft)
                        Text(String(format: "Est. EV %+.2fR per trade (~%.0f%% est. win × %.1f:1) — estimate, not a forecast.",
                                    ev.evR, ev.winProbEstimate * 100, ev.rewardR))
                            .font(.caption2)
                            .foregroundStyle(ev.isPositive ? DS.Palette.successSoft : DS.Palette.warningSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .help(StockSageExpectedValue.caveat)
                    }
                }
                if let vel = StockSageExpectedValue.velocity(for: idea, holds: velocityHolds) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(String(format: "≈ %+.3fR/day velocity (EV ÷ typical hold) — faster turnover compounds faster. An estimate.", vel))
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if a.suggestedWeight > 0, store.regime != nil {
                    Text(store.regimeIsStale
                         ? "Regime size uses a STALE regime read — re-gauge the regime for a current number."
                         : "Regime size = base × the regime's risk bias — a gauge, not a forecast; green = a de-risking cut.")
                        .font(.caption2)
                        .foregroundStyle(store.regimeIsStale ? DS.Palette.warningSoft : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = StockSageGlossary.assetClassRiskNote(for: idea.symbol) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 11)).foregroundStyle(DS.Palette.warningSoft)
                        Text(note).font(.caption2).foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let pc = store.precheck[idea.symbol.uppercased()], pc.verdict != .noHoldings {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: pc.isWarning ? "exclamationmark.triangle.fill"
                              : (pc.verdict == .diversifying ? "checkmark.seal.fill" : "circle.grid.2x2.fill"))
                            .font(.system(size: 11))
                            .foregroundStyle(pc.isWarning ? DS.Palette.danger
                                             : (pc.verdict == .diversifying ? DS.Palette.successSoft : DS.Palette.textSecondary))
                        Text(pc.note).font(.caption2)
                            .foregroundStyle(pc.isWarning ? DS.Palette.danger : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let ep = store.earnings[idea.symbol.uppercased()], ep.isWarning {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "calendar.badge.exclamationmark").font(.system(size: 11))
                            .foregroundStyle(ep.severity == .imminent ? DS.Palette.danger : DS.Palette.warningSoft)
                        Text(ep.note).font(.caption2)
                            .foregroundStyle(ep.severity == .imminent ? DS.Palette.danger : DS.Palette.warningSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let s = store.seasonality[idea.symbol.uppercased()] {
                    let m = Calendar.current.component(.month, from: Date())
                    if let stat = StockSageSeasonality.stat(s, month: m), stat.samples > 0 {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "calendar").font(.system(size: 11)).foregroundStyle(.secondary)
                            Text(stat.note(monthName: DateFormatter().monthSymbols[m - 1]))
                                .font(.caption2)
                                .foregroundStyle(stat.isReliable ? .secondary : DS.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let liq = store.liquidity[idea.symbol.uppercased()] {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: liq.tier == .thin ? "drop.triangle.fill" : "drop.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(liq.tier == .thin ? DS.Palette.warningSoft : .secondary)
                        Text(liq.note).font(.caption2)
                            .foregroundStyle(liq.tier == .thin ? DS.Palette.warningSoft : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let ts = store.trailingStop[idea.symbol.uppercased()] {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.up.forward.circle").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(String(format: "Chandelier exit ~%.2f (highest high − %.0f×ATR, %.0f%% below) — a STARTING trailing level; move it up as new highs print, never down. An exit rule, not a target.",
                                    ts.level, ts.multiple, ts.distancePct))
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                let whatIfHoldings = portfolio.positions.map {
                    (symbol: $0.symbol, value: (currentPrice($0.symbol) ?? $0.costBasis) * $0.shares)
                }
                if !whatIfHoldings.isEmpty {
                    let bookTotal = whatIfHoldings.reduce(0) { $0 + $1.value }
                    let sizedNotional: Double? = {
                        if let stop = a.stopPrice, let acct = Double(sizerAccount), let rp = Double(sizerRiskPct),
                           let ps = StockSagePositionSizer.size(account: acct, riskFraction: rp / 100, entry: idea.price, stop: stop) {
                            return ps.notional
                        }
                        return nil
                    }()
                    // Cap to cash actually deployable — the sizer's notional can be leveraged.
                    let addValue = StockSageWhatIf.proposedAddValue(
                        sizedNotional: sizedNotional, account: Double(sizerAccount), bookTotal: bookTotal)
                    let impact = StockSageWhatIf.addingHolding(symbol: idea.symbol, addedValue: addValue, to: whatIfHoldings)
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: impact.isWarning ? "exclamationmark.triangle.fill" : "chart.pie.fill")
                            .font(.system(size: 11)).foregroundStyle(impact.isWarning ? DS.Palette.danger : .secondary)
                        Text(impact.note).font(.caption2)
                            .foregroundStyle(impact.isWarning ? DS.Palette.danger : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Surface a SECTOR concentration warning only when it newly crosses
                    // (the class line above already covers the common case).
                    let sectorImpact = StockSageWhatIf.addingHolding(symbol: idea.symbol, addedValue: addValue,
                                                                     to: whatIfHoldings, classify: StockSageSector.sector)
                    if sectorImpact.isWarning {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(DS.Palette.danger)
                            Text("By sector — " + sectorImpact.note).font(.caption2)
                                .foregroundStyle(DS.Palette.danger).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let mtf = store.multiTimeframe[idea.symbol.uppercased()] {
                    HStack(spacing: 8) {
                        Image(systemName: mtf.aligned ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 12)).foregroundStyle(mtf.aligned ? DS.Palette.successSoft : DS.Palette.warningSoft)
                        Text("Daily \(mtf.daily.rawValue) · Weekly \(mtf.weekly.rawValue)")
                            .font(.caption).foregroundStyle(.white)
                        Spacer()
                    }
                    Text(mtf.note).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Checking the weekly timeframe…").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                if !a.rationale.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        ForEach(Array(a.rationale.enumerated()), id: \.offset) { _, reason in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "circle.fill").font(.system(size: 4)).foregroundStyle(.secondary).padding(.top, 6)
                                    .accessibilityHidden(true)   // decorative bullet
                                Text(reason).font(.caption).foregroundStyle(DS.Palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                positionSizerPanel(idea)

                HStack(spacing: 8) {
                    Button { Task { await store.runBacktest(symbol: idea.symbol) } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath").font(.system(size: 11, weight: .semibold))
                            Text("Backtest 5 years").font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Color.white.opacity(0.10), in: Capsule())
                        .overlay(Capsule().stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                    }
                    .buttonStyle(LuxPressStyle()).disabled(store.isBacktesting)

                    if isLoggableIdea(a.action) {
                        Button { prefillTradeFromIdea(idea) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.pencil").font(.system(size: 11, weight: .semibold))
                                Text("Log this trade").font(.system(size: 11.5, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(DS.Palette.accent.opacity(0.9), in: Capsule())
                        }
                        .buttonStyle(LuxPressStyle())
                        .help("Prefill the trade journal with this idea's direction, entry, stop and target")
                    }

                    Button {
                        let rr = a.stopPrice.flatMap { s in
                            a.targetPrice.flatMap { t in StockSageRewardRisk.assess(entry: idea.price, stop: s, target: t) }
                        }
                        let size: PositionSize? = a.stopPrice.flatMap { s in
                            guard let acct = Double(sizerAccount), let rp = Double(sizerRiskPct) else { return nil }
                            return StockSagePositionSizer.size(account: acct, riskFraction: rp / 100, entry: idea.price, stop: s)
                        }
                        let plan = StockSageTradePlan.text(symbol: idea.symbol, market: idea.market, price: idea.price,
                                                           advice: a, rewardRisk: rr, size: size, flags: riskFlags)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(plan, forType: .string)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard").font(.system(size: 11, weight: .semibold))
                            Text("Copy plan").font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(.white).padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Color.white.opacity(0.10), in: Capsule())
                        .overlay(Capsule().stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                    }
                    .buttonStyle(LuxPressStyle())
                    .help("Copy a clean text trade plan (entry/stop/target/R:R/size/flags) to the clipboard")
                }

                if store.backtestSymbol == idea.symbol { backtestPanel }

                Text(a.caveat).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 440, minHeight: 480)
        .background(DS.Palette.codeSurface)
        .task(id: idea.symbol) {
            guard !ProcessInfo.processInfo.arguments.contains("--qa") else { return }
            await store.refreshMultiTimeframe(symbol: idea.symbol)
            await store.refreshPrecheck(symbol: idea.symbol)
            await store.refreshEarnings(symbol: idea.symbol)
            await store.refreshSeasonality(symbol: idea.symbol)
            await store.refreshLiquidity(symbol: idea.symbol)
            await store.refreshTrailingStop(symbol: idea.symbol)
        }
    }

    private func ideaMetric(_ label: String, _ value: String, color: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: mvFont9, weight: .semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12.5, weight: .semibold, design: .rounded)).foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }

    private func convictionMeter(_ value: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                Capsule().fill(color)
                    .frame(width: max(4, geo.size.width * min(max(value, 0), 1)), height: 5)
            }
        }
        .frame(height: 5)
    }

    private func actionColor(_ a: TradeAdvice.Action) -> Color {
        switch a {
        case .strongBuy, .buy: return DS.Palette.successSoft
        case .hold:            return DS.Palette.warningSoft
        case .avoid:           return Color.white.opacity(0.22)
        case .reduce, .sell:   return DS.Palette.danger
        }
    }

    /// Dark ink on the light pastel badges (success/warning), white on the darker
    /// red/grey ones — same legibility rule as `recTextColor`.
    private func actionTextColor(_ a: TradeAdvice.Action) -> Color {
        switch a {
        case .reduce, .sell, .avoid: return .white
        default:                     return Color(white: 0.06)   // darker ink → AA contrast on bright pastels
        }
    }

    /// Sparkline tint by net direction over the shown window.
    private func sparkColor(_ spark: [Double]) -> Color {
        guard let first = spark.first, let last = spark.last else { return DS.Palette.accent }
        return last >= first ? DS.Palette.successSoft : DS.Palette.danger
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                if reduceMotion {
                    // Reduce Motion: static halo (no breathing loop).
                    Circle()
                        .fill(DS.Palette.accent.opacity(0.14))
                        .frame(width: 52, height: 52)
                        .blur(radius: 14)
                        .allowsHitTesting(false)
                } else {
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
                }
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(DS.Palette.accent)
                    .frame(width: 50, height: 50)
                    .background(RadialGradient(colors: [DS.Palette.accent.opacity(0.18), DS.Palette.accent.opacity(0.05)],
                                               center: .center, startRadius: 0, endRadius: 25), in: Circle())
                    .overlay(Circle().stroke(LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                                                            startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .shadow(color: DS.Palette.accent.opacity(0.26), radius: 14, y: 3)
            }
            Text("No symbols tracked yet.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 28)
    }
}

/// Sections shown inside the single Markets tab.
enum MarketSection: String, CaseIterable, Identifiable {
    case watchlist, ideas, all, heatmap, portfolio, alerts, briefing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .watchlist: return "Watchlist"
        case .ideas:     return "Ideas"
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
