import SwiftUI
import AppKit

/// Ordering for the Memory viewer's fact list. Facts arrive in
/// `MemoryStore.allFacts()` order — oldest first, newest last — so "newest"
/// just reverses. Pure over `[String]`, with the search filter folded in so the
/// view has a single source of truth (and the logic is unit-testable).
enum MemorySort: String, CaseIterable, Identifiable {
    case newest, oldest, alphabetical
    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest:       return "Newest first"
        case .oldest:       return "Oldest first"
        case .alphabetical: return "A → Z"
        }
    }

    var icon: String {
        switch self {
        case .newest:       return "clock.arrow.circlepath"
        case .oldest:       return "clock"
        case .alphabetical: return "textformat.abc"
        }
    }

    /// Apply the optional case-insensitive substring `filter`, then order.
    /// A blank/whitespace filter matches everything.
    func apply(_ facts: [String], filter q: String = "") -> [String] {
        let trimmed = q.trimmingCharacters(in: .whitespaces).lowercased()
        let base = trimmed.isEmpty ? facts : facts.filter { $0.lowercased().contains(trimmed) }
        switch self {
        case .oldest:       return base
        case .newest:       return base.reversed()
        case .alphabetical: return base.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
    }
}

/// "What I know about you" — lists the durable facts Salehman AI has saved to
/// long-term memory, with search, sort, per-fact copy/delete, and a clear-all.
/// MemoryStore stays a plain (non-ObservableObject) store, so we load into local
/// state on appear.
struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var facts: [String] = []
    @State private var confirmClear = false
    /// Staggered row entrance. Pre-set under `--qa` so the offscreen snapshot
    /// (onAppear never fires) captures the settled rows, not the opacity-0 pose.
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")
    @State private var query = ""
    @AppStorage("ui.memorySort") private var sort: MemorySort = .newest
    @State private var hoveredFact: String?
    @State private var newFact = ""
    @State private var copiedFact: String?
    @FocusState private var addFocused: Bool
    /// Focus glow on the search field — consistent with the add field.
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            // Route through DS canvas tokens so this sheet inherits any palette
            // swap (was a hardcoded cold-indigo that bypassed the token layer).
            DS.Palette.codeSurface.ignoresSafeArea()   // flat working canvas (design language)

            // Ambient brand glow — soft atmospheric depth behind the brain icon,
            // consistent with the other sheets (AboutView, OnboardingView). Fixed
            // non-scrolling element so the blur lives on the compositor, no repaints.
            Circle()
                .fill(DS.Palette.accent.opacity(0.12))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: -80, y: -200)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header

                addFactRow

                if facts.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else {
                    if facts.count > 1 { controlsRow }

                    let shown = sort.apply(facts, filter: query)
                    Group {
                        if shown.isEmpty {
                            VStack(spacing: 6) {
                                Spacer()
                                Text("No memories match “\(query)”.")
                                    .font(.callout).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                        } else {
                            ScrollView {
                            VStack(spacing: 1) {
                                ForEach(Array(shown.enumerated()), id: \.element) { idx, fact in
                                    row(fact)
                                        .opacity(appeared ? 1 : 0)
                                        .offset(y: appeared ? 0 : 10)
                                        .animation(DS.Motion.lux.delay(Double(min(idx, 8)) * 0.040),
                                                   value: appeared)
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }
                            .animation(DS.Motion.smooth, value: facts)
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
                        .transition(.opacity)
                    }
                }
                .animation(DS.Motion.smooth, value: shown.isEmpty)

                    Button(role: .destructive) { confirmClear = true } label: {
                        Label("Forget everything", systemImage: "trash")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Palette.danger)
                }
            }
            .padding(DS.Space.xl)
            .animation(DS.Motion.smooth, value: facts.isEmpty)
        }
        .frame(width: 480, height: 540)
        .preferredColorScheme(.dark)
        .onAppear { reload(); appeared = true }
        .confirmationDialog("Forget everything Salehman AI has remembered about you?",
                            isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Forget everything", role: .destructive) {
                MemoryStore.shared.clear(); reload()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.md) {
            // Brand icon tile — consistent with TodayView / AgentsView headers.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Gradient.brand)
                    .frame(width: 40, height: 40)
                    .dsShadow(DS.Elevation.accentGlow(0.40))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.48), .white.opacity(0.02)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.75)
                    )
                KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .bold))
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
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("What I know about you")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Eyebrow(text: "Long-term Memory")
                }
                Text("\(facts.count) fact\(facts.count == 1 ? "" : "s") saved on this Mac")
                    .font(.caption).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: facts.count)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(.secondary)
            }.buttonStyle(.plain).accessibilityLabel("Close")
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.md) {
            Spacer()
            // Halo + tinted glyph — mirrors the chat empty-state's "brand glow"
            // pattern so an empty sheet still feels lived-in, not abandoned.
            ZStack {
                PhaseAnimator([0.14, 0.22, 0.14]) { opacity in
                    Circle()
                        .fill(DS.Palette.accent.opacity(opacity))
                        .frame(width: 84, height: 84)
                        .blur(radius: 16)
                } animation: { opacity in
                    opacity > 0.18
                        ? .spring(duration: 2.2, bounce: 0.06)
                        : .easeOut(duration: 1.8)
                }
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(DS.Palette.accent.opacity(0.85))
            }
            Text("Nothing remembered yet")
                .font(.headline).foregroundStyle(.white)
            Text("As you chat, Salehman AI saves durable facts about you here — like your name, preferences, and projects.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// Search (when there are enough facts to warrant it) + sort menu, on one row.
    private var controlsRow: some View {
        HStack(spacing: 10) {
            if facts.count > 3 {
                searchField.frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }
            sortMenu
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search memories…", text: $query)
                .textFieldStyle(.plain).font(.system(size: 14))
                .focused($searchFocused)
                .onKeyPress(.escape) { query = ""; return .handled }
                .accessibilityLabel("Search memories")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear search")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 9)
        .background(Color.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        .shadow(color: DS.Palette.accent.opacity(searchFocused ? 0.15 : 0), radius: 10, y: 2)
        .animation(DS.Motion.magnetic, value: query.isEmpty)
        .animation(DS.Motion.lux, value: searchFocused)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(MemorySort.allCases) { s in
                    Label(s.title, systemImage: s.icon).tag(s)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down")
                Text(sort.title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Space.md).padding(.vertical, 9)
            .background(Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Sort memories")
    }

    private func row(_ fact: String) -> some View {
        let hovered = hoveredFact == fact
        return HStack(spacing: 12) {
            // Icon well — accent fill brightens on hover.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.well, style: .continuous)
                    .fill(DS.Palette.accent.opacity(hovered ? 0.20 : 0.11))
                    .frame(width: 24, height: 24)
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.well, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
            )
            Text(fact).font(.system(size: 14))
                .foregroundStyle(hovered ? .white : Color.white.opacity(0.9))
                .textSelection(.enabled)
            Spacer(minLength: 8)
            Button { copy(fact) } label: {
                Group {
                    if copiedFact == fact {
                        Text("Copied!").font(.system(size: 10, weight: .semibold))
                            .transition(.opacity)
                    } else {
                        Image(systemName: "doc.on.doc").font(.system(size: 12))
                            .transition(.opacity)
                    }
                }
                .foregroundStyle(copiedFact == fact ? DS.Palette.accent : (hovered ? DS.Palette.accent.opacity(0.7) : .secondary))
            }
            .buttonStyle(LuxPressStyle())
            .help("Copy")
            .accessibilityLabel("Copy memory")
            .animation(DS.Motion.smooth, value: copiedFact == fact)
            Button { MemoryStore.shared.delete(fact); reload() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(hovered ? DS.Palette.danger.opacity(0.70) : .secondary.opacity(0.50))
            }
            .buttonStyle(LuxPressStyle())
            .help("Forget this")
            .accessibilityLabel("Forget this memory")
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 11)
        .background(hovered ? DS.Palette.accent.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.magnetic) {
                hoveredFact = over ? fact : (hoveredFact == fact ? nil : hoveredFact)
            }
        }
    }

    private var addFactRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle").font(.system(size: 13)).foregroundStyle(.secondary)
            TextField("Add a memory…", text: $newFact)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($addFocused)
                .onSubmit { addFact() }
                .onKeyPress(.escape) { newFact = ""; return .handled }
                .accessibilityLabel("New memory text")
            if !newFact.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add", action: addFact)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent)
                    .buttonStyle(LuxPressStyle())
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 8)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        .shadow(color: DS.Palette.accent.opacity(addFocused ? 0.15 : 0), radius: 10, y: 2)
        .animation(DS.Motion.lux, value: addFocused)
        .animation(DS.Motion.smooth, value: newFact.isEmpty)
    }

    private func addFact() {
        let trimmed = newFact.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        MemoryStore.shared.remember(trimmed)
        newFact = ""
        addFocused = true
        reload()
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        copiedFact = s
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if copiedFact == s { copiedFact = nil }
        }
    }

    private func reload() { facts = MemoryStore.shared.allFacts() }
}
