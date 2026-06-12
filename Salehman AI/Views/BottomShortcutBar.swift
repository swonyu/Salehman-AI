import SwiftUI

/// A slim, always-visible footer of the most-used keyboard shortcuts. Each hint
/// is clickable and flips the same `AppState` edge-trigger flags the menu bar
/// and Command Palette use — so it doubles as a cheat-sheet and a shortcut.
/// Subtle by design: a hairline-topped frosted strip that never competes with
/// the content above it.
struct BottomShortcutBar: View {
    @ObservedObject private var app = AppState.shared
    @State private var hoveredHintID: String?

    private struct Hint: Identifiable {
        let keys: String
        let label: String
        let run: () -> Void
        var id: String { keys }
    }

    private var hints: [Hint] {
        switch app.selectedTab {
        case .chat:
            // Chat-specific bar: surface ⌘F Search and, when the AI is generating,
            // promote ⌘. Stop to the first slot so it's the most visible affordance.
            var h: [Hint] = []
            if app.aiIsRunning {
                h.append(.init(keys: "⌘.", label: "Stop") { app.stopRequested = true })
            }
            h += [
                .init(keys: "⌘F", label: "Search") { app.toggleSearchRequested = true },
                .init(keys: "⌘N", label: "New Chat") { app.selectedTab = .chat; app.newChatRequested = true },
                .init(keys: "⌘J", label: "Voice") { app.showVoiceModeRequested = true },
                .init(keys: "⌘K", label: "Palette") { app.showCommandPaletteRequested = true },
                .init(keys: "⌘,", label: "Settings") { app.showSettingsRequested = true },
            ]
            return Array(h.prefix(5))
        case .code:
            // Code-specific bar: the primary Code tab actions at a glance.
            return [
                .init(keys: "⌘R", label: "Review")  { app.reviewProjectRequested = true },
                .init(keys: "⌘F", label: "Find in file") { app.toggleCodeFindRequested = true },
                .init(keys: "⌘L", label: "Focus chat") { app.focusCodeInputRequested = true },
                .init(keys: "⌘⇧E", label: "Tree")   { app.toggleCodeTreeRequested = true },
                .init(keys: "⌘K", label: "Palette")  { app.showCommandPaletteRequested = true },
            ]
        default:
            return [
                .init(keys: "⌘K", label: "Palette") { app.showCommandPaletteRequested = true },
                .init(keys: "⌘N", label: "New Chat") { app.selectedTab = .chat; app.newChatRequested = true },
                .init(keys: "⌘J", label: "Voice") { app.showVoiceModeRequested = true },
                .init(keys: "⌘/", label: "Shortcuts") { app.showShortcutsRequested = true },
                .init(keys: "⌘,", label: "Settings") { app.showSettingsRequested = true },
            ]
        }
    }

    var body: some View {
        HStack(spacing: DS.Space.md) {
            ForEach(hints) { hint in
                let hinted = hoveredHintID == hint.id
                Button { hint.run() } label: {
                    HStack(spacing: 5) {
                        Text(hint.keys)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(hinted ? 1.0 : 0.85))
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Color.white.opacity(hinted ? 0.14 : 0.08),
                                        in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(hinted ? 0.22 : 0.12), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.18), radius: 1, y: 1)
                        Text(hint.label)
                            .font(.system(size: 11))
                            .foregroundStyle(hinted ? Color.white.opacity(0.7) : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.75, anchor: .leading).combined(with: .opacity))
                .onHover { over in
                    withAnimation(DS.Motion.press) {
                        hoveredHintID = over ? hint.id : (hoveredHintID == hint.id ? nil : hoveredHintID)
                    }
                }
                .help("\(hint.label) (\(hint.keys))")
                .accessibilityLabel("\(hint.label), \(hint.keys)")
            }
            Spacer(minLength: 0)
        }
        .animation(DS.Motion.smooth, value: app.aiIsRunning)
        .animation(DS.Motion.smooth, value: app.selectedTab)
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(DS.Palette.codeSurfaceSide)
        .overlay(alignment: .top) { Rectangle().fill(DS.Palette.hairline).frame(height: 1) }
    }
}
