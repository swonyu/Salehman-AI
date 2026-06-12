import SwiftUI

/// Keyboard-shortcuts cheat sheet (⌘/). A static reference of every shortcut,
/// grouped. Self-contained sheet over the root window — pairs with the ⌘K
/// command palette for discoverability.
struct ShortcutsView: View {
    let onClose: () -> Void
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")
    @State private var hoveredID: UUID?

    private struct Shortcut: Identifiable { let id = UUID(); let keys: String; let label: String }
    private struct ShortcutGroup: Identifiable { let id = UUID(); let title: String; let items: [Shortcut] }

    private let groups: [ShortcutGroup] = [
        .init(title: "GENERAL", items: [
            .init(keys: "⌘K", label: "Command palette"),
            .init(keys: "⌘,", label: "Settings"),
            .init(keys: "⌘/", label: "This shortcuts sheet"),
        ]),
        .init(title: "NAVIGATION", items: {
            var nav: [Shortcut] = [
                .init(keys: "⌘1", label: "Today"),
                .init(keys: "⌘2", label: "Chat"),
                .init(keys: "⌘3", label: "Code"),
                .init(keys: "⌘4", label: "Agents"),
                .init(keys: "⌘5", label: "Markets"),
                .init(keys: "⌘6", label: "Notes"),
                .init(keys: "⌘7", label: "Knowledge"),
            ]
            if AppTab.hidden.contains(.markets) { nav.removeAll { $0.label == "Markets" } }
            return nav
        }()),
        .init(title: "CONVERSATION", items: [
            .init(keys: "⌘N", label: "New chat"),
            .init(keys: "⌘J", label: "Hands-free voice"),
            .init(keys: "⌘F", label: "Find in conversation"),
            .init(keys: "⌘.", label: "Stop generating"),
            .init(keys: "⌘L", label: "Live transcription"),
        ]),
        .init(title: "CODE TAB", items: [
            .init(keys: "⌘R",  label: "Review project"),
            .init(keys: "⌘F",  label: "Find in file"),
            .init(keys: "⌘⌥F", label: "Find in conversation"),
            .init(keys: "⌘L",  label: "Focus chat input"),
            .init(keys: "⌘⇧E", label: "Toggle file tree"),
            .init(keys: "⌘⇧I", label: "Toggle right panel"),
            .init(keys: "⌘⇧O", label: "Open folder"),
        ]),
    ]

    var body: some View {
        ZStack {
            DS.Gradient.bgVertical.ignoresSafeArea()

            // Ambient accent glow — depth on the flat canvas.
            Circle()
                .fill(DS.Palette.accent.opacity(0.14))
                .frame(width: 220)
                .blur(radius: 80)
                .offset(x: 130, y: -150)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Header — brand tile + eyebrow component.
                HStack(alignment: .center, spacing: DS.Space.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .fill(DS.Gradient.brand)
                            .frame(width: 36, height: 36)
                            .dsShadow(DS.Elevation.accentGlow(0.38))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                                    .stroke(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.02)],
                                                           startPoint: .top, endPoint: .bottom),
                                            lineWidth: 0.75)
                            )
                        KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                            Image(systemName: "keyboard")
                                .font(.system(size: 15, weight: .bold))
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Every shortcut in one place")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Eyebrow(text: "Keyboard Shortcuts")
                    }
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain).accessibilityLabel("Close")
                }
                .padding(.bottom, DS.Space.lg)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Space.lg) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { idx, group in
                            groupSection(group)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 8)
                                .animation(DS.Motion.lux.delay(Double(idx) * 0.07), value: appeared)
                        }
                    }
                }
            }
            .padding(DS.Space.xl)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .frame(width: 400, height: 500)
        .onAppear { withAnimation(DS.Motion.smooth) { appeared = true } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard Shortcuts")
    }

    private func groupSection(_ group: ShortcutGroup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(DS.Palette.accent)
                .padding(.bottom, 4)

            VStack(spacing: 1) {
                ForEach(group.items) { s in shortcutRow(s) }
            }
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
    }

    private func shortcutRow(_ s: Shortcut) -> some View {
        let hovered = hoveredID == s.id
        return HStack {
            Text(s.label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text(s.keys)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(hovered ? 0.14 : 0.08))
                        // Top-lit edge highlight — key badge reads dimensional.
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(LinearGradient(
                                colors: [.white.opacity(0.45), .white.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    }
                )
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 9)
        .background(hovered ? DS.Palette.accent.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.magnetic) {
                if over { hoveredID = s.id }
                else if hoveredID == s.id { hoveredID = nil }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(s.label), \(s.keys)")
    }
}
