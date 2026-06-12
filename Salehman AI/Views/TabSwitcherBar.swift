import SwiftUI

/// Frosted segmented tab bar matching the app's dark DS aesthetic. Left: brand
/// logo + name. Center: the tab pills. Right: a live market-status dot.
struct TabSwitcherBar: View {
    @Binding var selection: AppTab
    @ObservedObject private var market = MarketStore.shared
    /// Used to ask ContentView to open the Settings sheet — the existing
    /// `AppState` bridge keeps the sheet's `@State` owned by ContentView while
    /// any sibling view (like this tab bar) can trigger it without a new Binding.
    @ObservedObject private var app = AppState.shared
    @ObservedObject private var scratchpad = ScratchpadStore.shared

    /// Pointer hover state for the market status pill — drives a subtle scale +
    /// brightening that signals "this thing has a tooltip / is interactive" to a
    /// keyboard/mouse user without yelling on first paint.
    @State private var marketHovering = false

    /// Namespace that ties the selection-highlight Capsule across pills, so the
    /// `matchedGeometryEffect` interpolates the highlight's FRAME from the old
    /// pill to the new one when `selection` changes — i.e. the red pill SLIDES
    /// instead of fading. The driver is the existing `withAnimation(...)` in
    /// the Button action below.
    @Namespace private var tabHighlight

    /// Measured width of the whole bar. It's window-driven (the bar fills the
    /// window via the Spacers), so it does NOT depend on whether pill labels are
    /// showing — measuring it can't create a layout feedback loop. When the bar
    /// is narrower than `labelThreshold` we collapse unselected pills to
    /// icon-only so 5+ tabs never clip; the selected pill always keeps its label
    /// as a persistent "you are here".
    @State private var barWidth: CGFloat = 0
    /// Scales with the tab count so adding a 6th/7th tab raises the collapse
    /// point automatically instead of silently re-introducing the clip.
    private var labelThreshold: CGFloat { CGFloat(AppTab.pills.count) * 92 + 380 }
    private var showAllLabels: Bool { barWidth == 0 || barWidth >= labelThreshold }

    var body: some View {
        HStack(spacing: DS.Space.md) {
            // Brand — elevated 36pt gradient tile + stacked logotype.
            HStack(spacing: DS.Space.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(DS.Gradient.brand).frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(LinearGradient(colors: [.white.opacity(0.48), .white.opacity(0.02)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
                        )
                    Image(systemName: "sparkles").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                }
                .shadow(color: DS.Palette.accent.opacity(0.30), radius: 8, y: 2)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Salehman")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("AI")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(DS.Palette.accent)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Salehman AI")

            Spacer(minLength: DS.Space.md)

            // Pills
            HStack(spacing: 4) {
                ForEach(AppTab.pills) { tab in pill(tab) }
            }
            .padding(4)
            .background(Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(
                LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                               startPoint: .top, endPoint: .bottom), lineWidth: 1))

            Spacer(minLength: DS.Space.md)

            // Right cluster: live market status pill + Settings gear. Grouped
            // so the rightmost slot reads as one "status + tools" zone.
            HStack(spacing: 8) {
                // Notes + Knowledge — compact corner tabs (owner directive:
                // "really small like the copy button", in the old market-pill
                // spot). Same 28pt metric line as the Settings gear; the
                // brand-filled circle marks the selected tab (the pill row's
                // sliding highlight simply rests while a corner tab is active).
                //
                // Sizing/spacing pass (owner → design chat, 2026-06-12): the
                // nav PAIR groups tighter (6pt) than the outer cluster gap
                // (8pt + divider padding ≈ 10pt) — Gestalt proximity: siblings
                // hug, zones breathe. Unselected nav tint is white@0.70 to
                // match the unselected pills' documented brightening (the
                // gear deliberately stays quieter `.secondary`: navigation
                // reads one step brighter than utility).
                let cornerTabs = AppTab.corner.filter { !AppTab.hidden.contains($0) }
                HStack(spacing: 6) {
                    ForEach(cornerTabs) { tab in
                        let pending = tab == .scratchpad ? scratchpad.pendingTaskCount : 0
                        CircleIconButton(systemName: tab.icon,
                                         size: 28, iconSize: 13,
                                         tint: Color.white.opacity(0.70),
                                         filled: selection == tab,
                                         help: "\(tab.title) (⌘\(tab == .scratchpad ? "6" : "7"))",
                                         accessibilityLabel: tab.title) {
                            withAnimation(DS.Motion.snappy) { selection = tab }
                        }
                        .overlay(alignment: .topTrailing) {
                            if pending > 0 {
                                Text(pending > 9 ? "9+" : "\(pending)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, pending > 9 ? 3.5 : 0)
                                    .frame(minWidth: 14, minHeight: 14)
                                    .background(DS.Palette.accent, in: Capsule())
                                    .offset(x: 4, y: -4)
                                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                                    .animation(DS.Motion.spring, value: pending)
                                    .accessibilityLabel("\(pending) pending task\(pending == 1 ? "" : "s")")
                            }
                        }
                    }
                }

                if !AppTab.hidden.contains(.markets) {
                // Live market status — dot + halo (when open) in a soft pill.
                // Hovering reveals a system tooltip ("Market is closed/open") via
                // `.help()` (also used as the VoiceOver hint — one modifier, both
                // audiences) and a subtle scale so the user gets visual feedback
                // that the pill is informational and explorable.
                HStack(spacing: 7) {
                    ZStack {
                        if market.session.isOpen {
                            // Continuously breathing halo — signals "live market"
                            // more clearly than a static ring.
                            PhaseAnimator([false, true]) { pulsing in
                                ZStack {
                                    Circle()
                                        .fill(DS.Palette.successSoft)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: DS.Palette.successSoft.opacity(pulsing ? 0.80 : 0.20),
                                                radius: pulsing ? 5 : 1)
                                    Circle()
                                        .stroke(DS.Palette.successSoft.opacity(pulsing ? 0.50 : 0.08), lineWidth: 1.5)
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(pulsing ? 2.6 : 1.7)
                                }
                            } animation: { pulsing in
                                pulsing ? .easeIn(duration: 1.5) : .easeOut(duration: 2.2)
                            }
                        } else {
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text(market.session.shortLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(market.session.isOpen ? Color.white : .secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(market.session.isOpen ? DS.Palette.successSoft.opacity(0.12) : Color.white.opacity(0.04),
                            in: Capsule())
                .overlay(
                    Capsule().stroke(
                        LinearGradient(colors: [Color.white.opacity(marketHovering ? 0.28 : 0.14),
                                                Color.white.opacity(marketHovering ? 0.06 : 0.02)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 1)
                )
                .scaleEffect(marketHovering ? 1.04 : 1.0)
                .animation(DS.Motion.smooth, value: market.session.isOpen)
                .onHover { h in withAnimation(DS.Motion.press) { marketHovering = h } }
                .help(market.session.isOpen ? "Market is open" : "Market is closed")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Market")
                .accessibilityValue(market.session.isOpen ? "Open" : "Closed")
                }

                // Hairline divider: navigation/status zone ◦ utility zone. The
                // gear opens a sheet; the circles to its left change tabs —
                // the separator keeps three identical circles from reading as
                // one undifferentiated row (macOS toolbar grouping convention).
                // Decorative only, so it's hidden from accessibility; guarded
                // so it never floats alone if every left-zone item is hidden.
                if !cornerTabs.isEmpty || !AppTab.hidden.contains(.markets) {
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 2)
                        .accessibilityHidden(true)
                }

                // Settings — moved up from the chat header per owner request so it's
                // reachable from EVERY tab, not just Chat. Uses the existing
                // `AppState.showSettingsRequested` bridge so ContentView's `.sheet`
                // still owns presentation — no new Binding to plumb through.
                CircleIconButton(systemName: "gearshape.fill",
                                 size: 28, iconSize: 13,
                                 help: "Settings (⌘,)",
                                 accessibilityLabel: "Open Settings") {
                    app.showSettingsRequested = true
                }
            }
            .frame(minWidth: 96, alignment: .trailing)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm)
        .background(DS.Palette.codeSurfaceSide)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { barWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, w in
                        withAnimation(DS.Motion.snappy) { barWidth = w }
                    }
            }
        )
    }

    private func pill(_ tab: AppTab) -> some View {
        let selected = selection == tab
        return Button {
            withAnimation(DS.Motion.snappy) { selection = tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon).font(.system(size: 12, weight: .semibold))
                // Label shows for every pill when there's room; when the bar is
                // squeezed, only the selected pill keeps its text so the row
                // never clips. Driven by the same `withAnimation` as selection,
                // so it slides/fades in step with the highlight pill.
                if showAllLabels || selected {
                    Text(tab.title).font(.system(size: 13, weight: .semibold))
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                }
            }
            // Brightened unselected from `.secondary` (~white@0.55 on the frosted
            // substrate — borderline contrast) to white@0.70, while selected stays
            // pure white. Keeps the visual hierarchy clear AND legible.
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.70))
            .padding(.horizontal, DS.Space.md).padding(.vertical, 7)
            .background {
                // Only the SELECTED pill emits the highlight Capsule, and ties it
                // to the shared `tabHighlight` namespace. When `selection` changes
                // inside a `withAnimation` block, SwiftUI interpolates the
                // highlight's frame from the old pill to the new one — the
                // "sliding" feel you get in Apple Music's segment picker.
                if selected {
                    Capsule()
                        .fill(DS.Gradient.brand)
                        .matchedGeometryEffect(id: "tabHighlight", in: tabHighlight)
                        .shadow(color: DS.Palette.accent.opacity(0.4), radius: 6, y: 2)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // Tooltip carries the name when the label is collapsed to an icon.
        .help(tab.title)
        .accessibilityLabel(tab.title)
        .accessibilityHint("Show the \(tab.title) tab")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        // Unread dot — appears on the Chat pill while an AI reply has completed
        // but the user is on another tab. The dot rides at the top-trailing edge
        // of the pill, outside the capsule highlight so it's always visible.
        .overlay(alignment: .topTrailing) {
            if tab == .chat && app.chatHasUnread && !selected {
                Circle()
                    .fill(DS.Palette.accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: DS.Palette.accent.opacity(0.6), radius: 3)
                    .offset(x: 3, y: -3)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .animation(DS.Motion.spring, value: app.chatHasUnread)
                    .accessibilityLabel("New message in Chat")
            }
        }
    }
}
