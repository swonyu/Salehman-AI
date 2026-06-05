import SwiftUI

/// Slim persistent shortcuts hint bar pinned to the bottom of the app window.
/// Surfaces the most-used ⌘ shortcuts ambiently so users discover them without
/// opening the ⌘/ cheat sheet, and each chip is tappable — clicking flips the
/// same `AppState` edge-trigger flag the menu bar and Command Palette use, so
/// every entry point shares one control path (fix once, fixed everywhere).
struct ShortcutsFooter: View {
    @ObservedObject private var app = AppState.shared

    var body: some View {
        HStack(spacing: DS.Space.lg) {
            chip("⌘K", "Palette") { app.showCommandPaletteRequested = true }
            chip("⌘N", "New chat") { app.selectedTab = .chat; app.newChatRequested = true }
            chip("⌘J", "Voice") { app.showVoiceModeRequested = true }
            chip("⌘,", "Settings") { app.showSettingsRequested = true }
            Spacer(minLength: DS.Space.md)
            chip("⌘/", "All shortcuts") { app.showShortcutsRequested = true }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        // Hairline separator at the top of the footer matches the one above
        // `TabSwitcherBar`, so the chrome reads as one cohesive frame.
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard shortcuts")
    }

    private func chip(_ keys: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(keys)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.white.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(label) (\(keys))")
        .accessibilityLabel("\(label), \(keys)")
    }
}
