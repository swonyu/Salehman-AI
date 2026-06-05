import SwiftUI

/// Keyboard-shortcuts cheat sheet (⌘/). A static reference of every shortcut,
/// grouped. Self-contained sheet over the root window — pairs with the ⌘K
/// command palette for discoverability.
struct ShortcutsView: View {
    let onClose: () -> Void

    private struct Shortcut: Identifiable { let id = UUID(); let keys: String; let label: String }
    private struct ShortcutGroup: Identifiable { let id = UUID(); let title: String; let items: [Shortcut] }

    private let groups: [ShortcutGroup] = [
        .init(title: "General", items: [
            .init(keys: "⌘K", label: "Command palette"),
            .init(keys: "⌘,", label: "Settings"),
            .init(keys: "⌘/", label: "This shortcuts sheet"),
        ]),
        .init(title: "Navigation", items: [
            .init(keys: "⌘1", label: "Today"),
            .init(keys: "⌘2", label: "Chat"),
            .init(keys: "⌘3", label: "Agents"),
            .init(keys: "⌘4", label: "Markets"),
            .init(keys: "⌘5", label: "Notes"),
            .init(keys: "⌘6", label: "Knowledge"),
        ]),
        .init(title: "Conversation", items: [
            .init(keys: "⌘N", label: "New chat"),
            .init(keys: "⌘J", label: "Hands-free voice"),
            .init(keys: "⌘F", label: "Find in conversation"),
            .init(keys: "⌘.", label: "Stop generating"),
            .init(keys: "⌘L", label: "Live transcription"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Close")
            }
            .padding(.bottom, DS.Space.md)

            ForEach(groups) { group in
                Text(group.title.uppercased())
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(DS.Palette.accent)
                    .tracking(0.8).padding(.top, DS.Space.sm).padding(.bottom, 4)
                ForEach(group.items) { s in
                    HStack {
                        Text(s.label).font(.system(size: 13)).foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text(s.keys)
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .padding(.vertical, 5)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(s.label), \(s.keys)")
                }
            }
            Spacer()
        }
        .padding(DS.Space.xl)
        .frame(width: 380, height: 470)
        .background(DS.Palette.bgTop)
    }
}
