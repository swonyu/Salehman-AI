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

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Working late"
        }
    }
    private var openTasks: Int { scratchpad.tasks.filter { !$0.done }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                greetingHeader
                section("QUICK ACTIONS") { quickActions }
                section("AT A GLANCE") { statCards }
            }
            .padding(DS.Space.xl)
            // Same centered content column as the chat surfaces (design language).
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: refresh)
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
            await MainActor.run { knowledgeCount = n }
        }
    }

    // MARK: Sections

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(DS.Typography.titleXL).foregroundStyle(.white)
            Text("Welcome back to Salehman AI — many brains, real tools, your own model.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.xl)
        .background(DS.Gradient.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
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
            }
        }
    }

    private var statCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: DS.Space.md)], spacing: DS.Space.md) {
            StatTile(icon: "checklist", title: "Notes",
                     value: "\(scratchpad.notes.count)",
                     detail: openTasks == 0 ? "no open tasks" : "\(openTasks) open task\(openTasks == 1 ? "" : "s")") {
                app.selectedTab = .scratchpad
            }
            StatTile(icon: "books.vertical.fill", title: "Knowledge",
                     value: "\(knowledgeCount)",
                     detail: knowledgeCount == 1 ? "document" : "documents") {
                app.selectedTab = .knowledge
            }
            StatTile(icon: "chart.line.uptrend.xyaxis", title: "Market",
                     value: market.session.shortLabel,
                     detail: market.session.isOpen ? "open now" : "closed",
                     accent: market.session.isOpen ? DS.Palette.success : .white) {
                app.selectedTab = .markets
            }
        }
    }
}

// MARK: - Tiles (own their hover state)

private struct ActionTile: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                        .fill(DS.Palette.accent.opacity(0.16)).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(DS.Palette.accent)
                }
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Opaque tile per the design language — no translucent stacking
            // over the landing glow.
            .background(DS.Palette.codeSurface, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(hovering ? DS.Palette.accent.opacity(0.5) : DS.Palette.surfaceStroke, lineWidth: 1))
            .scaleEffect(hovering ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
    }
}

private struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    var accent: Color = .white
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.Palette.accent)
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary.opacity(hovering ? 0.9 : 0.35))
                }
                Text(value).font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.6)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .padding(DS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Opaque tile per the design language (see ActionTile).
            .background(DS.Palette.codeSurface, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(hovering ? DS.Palette.accent.opacity(0.4) : DS.Palette.surfaceStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
    }
}
