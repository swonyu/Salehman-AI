import SwiftUI

/// The Today tab — a glanceable home surface that ties the app's surfaces
/// together: a time-of-day greeting, one-tap actions, and stat cards that read
/// the REAL on-device stores (notes/tasks, knowledge docs, market session).
/// Pure read + navigation; it owns no state beyond a cached document count.
/// Quick actions flip the same `AppState` edge-trigger flags the menu bar and
/// Command Palette use, so behaviour is identical across every entry point.
struct TodayView: View {
    @ObservedObject private var app = AppState.shared
    @ObservedObject private var scratchpad = ScratchpadStore.shared
    @ObservedObject private var market = MarketStore.shared
    /// KnowledgeStore isn't an ObservableObject, so its count is cached and
    /// refreshed whenever this tab becomes active (cheap, no timer).
    @State private var knowledgeCount = 0
    /// Count of chat archives modified today — refreshed off-main alongside
    /// knowledge count so the Today dashboard shows live usage.
    @State private var todayChats = 0
    /// Staggered entrance: false → true on onAppear drives the fade-up.
    @State private var appeared = false

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Working late"
        }
    }
    private var greetingIcon: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "sun.and.horizon.fill"
        case 12..<17: return "sun.max.fill"
        case 17..<22: return "moon.stars.fill"
        default:      return "moon.zzz.fill"
        }
    }
    private var timeOfDayTag: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default:      return "Late night"
        }
    }
    private var openTasks: Int { scratchpad.tasks.filter { !$0.done }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                greetingHeader
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(DS.Motion.entrance, value: appeared)
                section("QUICK ACTIONS") { quickActions }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(DS.Motion.entrance.delay(0.08), value: appeared)
                section("AT A GLANCE") { statCards }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(DS.Motion.entrance.delay(0.16), value: appeared)
            }
            .padding(DS.Space.xl)
            // Same centered content column as the chat surfaces (design language).
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            refresh()
            appeared = true
        }
        .onChange(of: app.selectedTab) { _, tab in if tab == .today { refresh() } }
    }

    /// Off-main: the FIRST touch of `KnowledgeStore.shared` decodes the whole
    /// knowledge.json vault (≈5 MB JSON) in its init — doing that synchronously in
    /// `onAppear` of the DEFAULT tab made every cold launch hitch on the main
    /// thread. The store is lock-guarded, so a detached first touch is safe; the
    /// count hops back to main when ready.
    private func refresh() {
        Task.detached(priority: .utility) {
            let n = KnowledgeStore.shared.allDocuments().count
            let c = ChatStore.archivedTodayCount()
            await MainActor.run { knowledgeCount = n; todayChats = c }
        }
    }

    // MARK: Sections

    /// Bezel-style greeting with a brand icon tile, time-specific glyph, and an
    /// ambient glow orb — same layered depth as OnboardingView's hero tile.
    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: DS.Space.lg) {
            // Brand icon tile — top-lit edge highlight gives it dimension.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.modal, style: .continuous)
                    .fill(DS.Gradient.brand)
                    .frame(width: 54, height: 54)
                    .dsShadow(DS.Elevation.accentGlow(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.modal, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.50), .white.opacity(0.02)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 0.75
                            )
                    )
                KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                    Image(systemName: greetingIcon)
                        .font(.system(size: 24, weight: .bold))
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

            VStack(alignment: .leading, spacing: 5) {
                Eyebrow(text: timeOfDayTag)
                Text(greeting)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Your model, your data — always on this Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.xl)
        // Ambient glow: rendered in the background layer so it clips to the
        // bezel shell and never bleeds into adjacent tiles.
        .background(alignment: .leading) {
            // PhaseAnimator cycles rest→pulse→rest continuously, giving the glow
            // a slow organic "breath". The third 0.20 phase acts as a dead frame
            // (same values as the first) — a pause before the next exhale.
            PhaseAnimator([0.20, 0.30, 0.20]) { opacity in
                Circle()
                    .fill(DS.Palette.accent.opacity(opacity))
                    .frame(width: opacity > 0.25 ? 162 : 140,
                           height: opacity > 0.25 ? 162 : 140)
                    .blur(radius: 55)
                    .offset(x: -20, y: 0)
                    .allowsHitTesting(false)
            } animation: { opacity in
                opacity > 0.25
                    ? .spring(duration: 2.4, bounce: 0.08)
                    : .easeOut(duration: 2.0)
            }
        }
        // Inner core: brand-tinted fill + top-lit inner highlight.
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Bezel.innerRadius, style: .continuous)
                    .fill(DS.Gradient.brand.opacity(0.10))
                RoundedRectangle(cornerRadius: DS.Bezel.innerRadius, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        // Outer shell.
        .padding(DS.Bezel.shellPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.Bezel.outerRadius, style: .continuous)
                .fill(DS.Bezel.shellFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Bezel.outerRadius, style: .continuous)
                .stroke(DS.Bezel.shellStroke, lineWidth: 1)
        )
    }

    @ViewBuilder private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Eyebrow(text: title)
            content()
        }
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: DS.Space.md)], spacing: DS.Space.md) {
            ActionTile(icon: "square.and.pencil", title: "New Chat") {
                app.selectedTab = .chat; app.newChatRequested = true
            }
            ActionTile(icon: "waveform", title: "Hands-Free Voice") {
                app.showVoiceModeRequested = true
            }
            ActionTile(icon: "doc.badge.plus", title: "Add to Knowledge") {
                app.selectedTab = .knowledge
            }
            ActionTile(icon: "note.text.badge.plus", title: "New Note") {
                app.selectedTab = .scratchpad
                app.scratchpadFocusNotesMode = true
                app.focusScratchpadAddFieldRequested = true
            }
            ActionTile(icon: "checklist.checked", title: "New Task") {
                app.selectedTab = .scratchpad
                app.scratchpadFocusNotesMode = false
                app.focusScratchpadAddFieldRequested = true
            }
        }
    }

    private var statCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: DS.Space.md)], spacing: DS.Space.md) {
            StatTile(icon: "bubble.left.and.bubble.right.fill", title: "Chat",
                     value: "\(todayChats)",
                     detail: todayChats == 1 ? "conversation today" : "conversations today") {
                app.selectedTab = .chat
            }
            StatTile(icon: "checklist", title: "Notes",
                     value: "\(scratchpad.notes.count + scratchpad.tasks.count)",
                     detail: openTasks == 0 ? "no open tasks" : "\(openTasks) open task\(openTasks == 1 ? "" : "s")") {
                app.selectedTab = .scratchpad
            }
            StatTile(icon: "books.vertical.fill", title: "Knowledge",
                     value: "\(knowledgeCount)",
                     detail: knowledgeCount == 1 ? "document" : "documents") {
                app.selectedTab = .knowledge
            }
            // Market tile hides with the Markets tab (owner directive — see
            // `AppTab.hidden`); its tap navigates to a tab that would no
            // longer exist in the bar.
            if !AppTab.hidden.contains(.markets) {
                StatTile(icon: "chart.line.uptrend.xyaxis", title: "Market",
                         value: market.session.shortLabel,
                         detail: market.session.isOpen ? "open now" : "closed",
                         valueAccent: market.session.isOpen ? DS.Palette.successSoft : .white) {
                    app.selectedTab = .markets
                }
            }
        }
    }
}

// MARK: - Tiles (own their hover state)

/// Quick-action tile — SuggestionCard-style bezel fill, magnetic hover physics,
/// icon well that scales on hover, and a trailing arrow-in-circle so the
/// tap target reads as an interactive button rather than a flat label.
private struct ActionTile: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon well — tint brightens and well scales up on hover.
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                        .fill(DS.Palette.accent.opacity(hovering ? 0.22 : 0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
                )
                .scaleEffect(hovering ? 1.06 : 1.0)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                // Trailing arrow circle — "button-in-button" kinetic tension.
                ZStack {
                    Circle().fill(Color.white.opacity(hovering ? 0.16 : 0.07))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.80))
                }
                .frame(width: 22, height: 22)
                .scaleEffect(hovering ? 1.10 : 1.0)
                .offset(x: hovering ? 1 : 0, y: hovering ? -1 : 0)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(Color.white.opacity(hovering ? 0.07 : 0.04))
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(Color.white.opacity(hovering ? 0.18 : 0.08), lineWidth: 1)
            )
            .scaleEffect(hovering ? 1.015 : 1.0)
            .shadow(color: DS.Palette.accent.opacity(hovering ? 0.15 : 0.0), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.Motion.magnetic) { hovering = h } }
    }
}

/// Stat tile — same bezel fill as ActionTile; chevron nudges right on hover;
/// value uses `.rounded` design for a dashboard-grade number feel.
private struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    var valueAccent: Color = .white
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    // Icon well matches ActionTile's treatment for visual unity.
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.well, style: .continuous)
                            .fill(DS.Palette.accent.opacity(0.12))
                            .frame(width: 26, height: 26)
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Palette.accent)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.well, style: .continuous)
                            .stroke(LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
                    )
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary.opacity(hovering ? 0.85 : 0.30))
                        .offset(x: hovering ? 2 : 0)
                }
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(valueAccent)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: value)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: detail)
            }
            .padding(DS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(Color.white.opacity(hovering ? 0.065 : 0.04))
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(Color.white.opacity(hovering ? 0.15 : 0.07), lineWidth: 1)
            )
            .shadow(color: DS.Palette.accent.opacity(hovering ? 0.10 : 0.0), radius: 10, y: 4)
            .scaleEffect(hovering ? 1.012 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.Motion.magnetic) { hovering = h } }
    }
}
