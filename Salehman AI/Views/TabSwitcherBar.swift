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
    private var labelThreshold: CGFloat { CGFloat(AppTab.visible.count) * 92 + 380 }
    private var showAllLabels: Bool { barWidth == 0 || barWidth >= labelThreshold }

    var body: some View {
        HStack(spacing: DS.Space.md) {
            // Brand — elevated 36pt gradient tile + stacked logotype.
            HStack(spacing: DS.Space.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(DS.Gradient.brand).frame(width: 36, height: 36)
                    Image(systemName: "sparkles").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                }
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
                ForEach(AppTab.visible) { tab in pill(tab) }
            }
            .padding(4)
            .background(Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))

            Spacer(minLength: DS.Space.md)

            // Right cluster: live market status pill + Settings gear. Grouped
            // so the rightmost slot reads as one "status + tools" zone.
            HStack(spacing: 8) {
                if !AppTab.hidden.contains(.markets) {
                // Live market status — dot + halo (when open) in a soft pill.
                // Hovering reveals a system tooltip ("Market is closed/open") via
                // `.help()` (also used as the VoiceOver hint — one modifier, both
                // audiences) and a subtle scale so the user gets visual feedback
                // that the pill is informational and explorable.
                HStack(spacing: 7) {
                    ZStack {
                        Circle().fill(market.session.isOpen ? DS.Palette.success : Color.secondary)
                            .frame(width: 8, height: 8)
                        if market.session.isOpen {
                            Circle().stroke(DS.Palette.success.opacity(0.45), lineWidth: 2)
                                .frame(width: 8, height: 8).scaleEffect(1.7).opacity(0.6)
                        }
                    }
                    Text(market.session.shortLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(market.session.isOpen ? Color.white : .secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(market.session.isOpen ? DS.Palette.success.opacity(0.12) : Color.white.opacity(0.04),
                            in: Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(marketHovering ? 0.18 : 0.08), lineWidth: 1)
                )
                .scaleEffect(marketHovering ? 1.04 : 1.0)
                .onHover { h in withAnimation(DS.Motion.press) { marketHovering = h } }
                .help(market.session.isOpen ? "Market is open" : "Market is closed")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Market")
                .accessibilityValue(market.session.isOpen ? "Open" : "Closed")
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
    }
}
