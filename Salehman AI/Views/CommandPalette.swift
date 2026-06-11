import SwiftUI

/// ⌘K quick-command palette — a searchable list of app actions (navigate, new
/// chat, settings, switch brain, …). Self-contained: it reads `AppState` /
/// `AppSettings` and flips the same edge-trigger flags the menu bar uses, so it
/// adds no new control paths. Presented as a sheet over the root window.
struct CommandPalette: View {
    let onClose: () -> Void
    @ObservedObject private var app = AppState.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var query = ""
    @State private var hoveredID: UUID?
    @FocusState private var searchFocused: Bool

    private struct Command: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let run: () -> Void
    }

    private var commands: [Command] {
        var c: [Command] = [
            .init(title: "New Chat", subtitle: "Start a fresh conversation", icon: "square.and.pencil") {
                app.selectedTab = .chat; app.newChatRequested = true },
            .init(title: "Go to Today", subtitle: "Your home dashboard at a glance", icon: "sun.max.fill") { app.selectedTab = .today },
            .init(title: "Go to Chat", subtitle: "", icon: "bubble.left.and.bubble.right.fill") { app.selectedTab = .chat },
            .init(title: "Go to Code", subtitle: "Agentic coding workspace", icon: "chevron.left.forwardslash.chevron.right") { app.selectedTab = .code },
            .init(title: "Go to Agents", subtitle: "Your specialist agent team", icon: "person.3.fill") { app.selectedTab = .agents },
        ]
        // Hidden tabs (owner directive — see `AppTab.hidden`) keep their
        // palette entry out of search; restore by emptying that set.
        if !AppTab.hidden.contains(.markets) {
            c.append(.init(title: "Go to Markets", subtitle: "", icon: "chart.line.uptrend.xyaxis") { app.selectedTab = .markets })
        }
        c += [
            .init(title: "Go to Notes", subtitle: "Your notes & tasks scratchpad", icon: "checklist") { app.selectedTab = .scratchpad },
            .init(title: "Go to Knowledge", subtitle: "Chat with your documents", icon: "books.vertical.fill") { app.selectedTab = .knowledge },
            .init(title: "Open Settings", subtitle: "Brains, keys, voice, privacy", icon: "gearshape.fill") { app.showSettingsRequested = true },
            .init(title: "Live Transcription", subtitle: "Transcribe speech in real time", icon: "waveform") { app.showLiveRequested = true },
            .init(title: "Find in Conversation", subtitle: "Search the current chat", icon: "magnifyingglass") {
                app.selectedTab = .chat; app.toggleSearchRequested = true },
            .init(title: "Stop Generating", subtitle: "Halt the current response", icon: "stop.fill") { app.stopRequested = true },
            .init(title: "Keyboard Shortcuts", subtitle: "See every ⌘ shortcut at a glance", icon: "keyboard") { app.showShortcutsRequested = true },
            .init(title: "About Salehman AI", subtitle: "Identity, capabilities, privacy", icon: "info.circle.fill") { app.showAboutRequested = true },
            .init(title: "Hands-Free Voice", subtitle: "Talk to Salehman, eyes-free", icon: "waveform") { app.showVoiceModeRequested = true },
        ]
        // One "switch brain" command per selectable (non-paid) brain.
        for pref in BrainPreference.selectableCases {
            c.append(.init(title: "Switch brain: \(pref.title)", subtitle: pref.subtitle, icon: pref.icon) {
                settings.brainPreference = pref })
        }
        return c
    }

    private var filtered: [Command] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return commands }
        return commands.filter { $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "command").foregroundStyle(DS.Palette.accent)
                TextField("Type a command…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($searchFocused)
                    .onSubmit { run(filtered.first) }
                    .accessibilityLabel("Command search")
                Text("esc")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(16)

            Divider().overlay(DS.Palette.hairline)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filtered) { cmd in
                        Button { run(cmd) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: cmd.icon)
                                    .font(.system(size: 14)).foregroundStyle(DS.Palette.accent).frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cmd.title).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                                    if !cmd.subtitle.isEmpty {
                                        Text(cmd.subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 4)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(hoveredID == cmd.id ? DS.Palette.accent.opacity(0.14) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hoveredID = $0 ? cmd.id : (hoveredID == cmd.id ? nil : hoveredID) }
                    }
                    if filtered.isEmpty {
                        Text("No matching commands")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 28)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 340)
        }
        .frame(width: 560)
        .background(DS.Palette.bgTop)
        .onAppear { searchFocused = true }
    }

    private func run(_ cmd: Command?) {
        guard let cmd else { return }
        onClose()
        // Let the palette sheet finish dismissing before the action triggers
        // another sheet/tab change, so the two transitions don't fight.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { cmd.run() }
    }
}
