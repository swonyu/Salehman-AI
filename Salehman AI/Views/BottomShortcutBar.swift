import SwiftUI

/// A slim, always-visible footer of the most-used keyboard shortcuts. Each hint
/// is clickable and flips the same `AppState` edge-trigger flags the menu bar
/// and Command Palette use — so it doubles as a cheat-sheet and a shortcut.
/// Subtle by design: a hairline-topped frosted strip that never competes with
/// the content above it.
struct BottomShortcutBar: View {
    @ObservedObject private var app = AppState.shared

    private struct Hint: Identifiable {
        let id = UUID()
        let keys: String
        let label: String
        let run: () -> Void
    }

    private var hints: [Hint] {
        [
            .init(keys: "⌘K", label: "Palette") { app.showCommandPaletteRequested = true },
            .init(keys: "⌘N", label: "New Chat") { app.selectedTab = .chat; app.newChatRequested = true },
            .init(keys: "⌘J", label: "Voice") { app.showVoiceModeRequested = true },
            .init(keys: "⌘/", label: "Shortcuts") { app.showShortcutsRequested = true },
            .init(keys: "⌘,", label: "Settings") { app.showSettingsRequested = true },
        ]
    }

    var body: some View {
        HStack(spacing: DS.Space.md) {
            ForEach(hints) { hint in
                Button { hint.run() } label: {
                    HStack(spacing: 5) {
                        Text(hint.keys)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        Text(hint.label)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("\(hint.label) (\(hint.keys))")
                .accessibilityLabel("\(hint.label), \(hint.keys)")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(DS.Palette.hairline).frame(height: 1) }
    }
}
