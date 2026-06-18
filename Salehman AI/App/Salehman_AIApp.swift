//
//  Salehman_AIApp.swift
//  Salehman AI
//

import SwiftUI

@main
struct Salehman_AIApp: App {
    @StateObject private var app = AppState.shared
    /// First-run welcome flow. Persisted so it shows exactly once.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 720, minHeight: 560)
                // One-time: seed the "external AI tools" docs into the Knowledge vault
                // so the assistant can answer about them via search_documents. Runs
                // off-main and only on the first launch after this version.
                .task {
                    await OllamaClient.ensureServing()
                    // If the Uncensored brain is selected, warm its abliterated
                    // ~3B into RAM now so the first reply is instant (owner: "run
                    // it automatically when I open the app").
                    OllamaClient.warmUncensoredIfSelected()
                }
                .task { ExternalToolsKnowledge.seedIfNeeded() }
                // QA: if qa/SNAPSHOT_REQUEST exists, render every surface to
                // qa/snapshots/*.png so the screen-blind polish session can SEE
                // the app (see QASnapshots.swift). WINDOW_REQUEST captures the
                // real on-screen window (QACapture.swift); the audit then
                // self-judges the pictures (QAAudit.swift).
                .task { QASnapshots.checkAndRun() }
                .task { QACapture.checkAndRun() }
                // One global `.tint(...)` so every descendant that uses the SwiftUI
                // system accent — Buttons/Toggles/Pickers + literal `Color.accentColor`
                // call sites (SettingsView.brainGridCell, AgentsView, CopilotSignInView) —
                // picks up our Apple-Music red instead of the OS default blue. Avoids
                // touching ~13 individual call sites across contended view files.
                .tint(DS.Palette.accent)
                // First-run welcome — shown once over the root window.
                .sheet(isPresented: Binding(
                    get: { !hasSeenOnboarding },
                    set: { presenting in if !presenting { hasSeenOnboarding = true } }
                )) {
                    OnboardingView { hasSeenOnboarding = true }
                }
                // ⌘K quick-command palette.
                .sheet(isPresented: $app.showCommandPaletteRequested) {
                    CommandPalette { app.showCommandPaletteRequested = false }
                }
                // ⌘/ keyboard-shortcuts cheat sheet.
                .sheet(isPresented: $app.showShortcutsRequested) {
                    ShortcutsView { app.showShortcutsRequested = false }
                }
                // About Salehman AI — macOS-canonical "About" sheet.
                .sheet(isPresented: $app.showAboutRequested) {
                    AboutView { app.showAboutRequested = false }
                }
                // ⌘J hands-free Voice Mode.
                .sheet(isPresented: $app.showVoiceModeRequested) {
                    VoiceModeView { app.showVoiceModeRequested = false }
                }
        }
        .defaultSize(width: 980, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            // Replace the default macOS "About App" with our branded sheet —
            // lands in the app menu (top-left), the canonical macOS slot.
            CommandGroup(replacing: .appInfo) {
                Button("About Salehman AI") { app.showAboutRequested = true }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Chat") { app.selectedTab = .chat; app.newChatRequested = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("View") {
                Button("Command Palette…") { app.showCommandPaletteRequested = true }
                    .keyboardShortcut("k", modifiers: .command)
                // Renders every surface to qa/snapshots/*.png (QASnapshots.swift)
                // so the screen-blind polish session can see the app on demand.
                Button("Capture QA Snapshots") { QASnapshots.captureAll() }
                // True pixels of the real window(s) — QACapture.swift.
                Button("Capture Live Window") { QACapture.captureLiveWindows() }
                // Audit current snapshots (AUDIT.json) / adopt them as baselines.
                Button("Run QA Audit") { QAAudit.runDefault() }
                Button("Adopt QA Baselines") { QAAudit.adoptBaselinesDefault() }
                Divider()
                Button("Today") { app.selectedTab = .today }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Chat") { app.selectedTab = .chat }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Code") { app.selectedTab = .code }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Agents") { app.selectedTab = .agents }
                    .keyboardShortcut("4", modifiers: .command)
                if !AppTab.hidden.contains(.markets) {
                    Button("Markets") { app.selectedTab = .markets }
                        .keyboardShortcut("5", modifiers: .command)
                }
                Button("Notes") { app.selectedTab = .scratchpad }
                    .keyboardShortcut("6", modifiers: .command)
                Button("Knowledge") { app.selectedTab = .knowledge }
                    .keyboardShortcut("7", modifiers: .command)
                Divider()
                Button("Keyboard Shortcuts") { app.showShortcutsRequested = true }
                    .keyboardShortcut("/", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { app.showSettingsRequested = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Conversation") {
                Button("Stop Generating") { app.stopRequested = true }
                    .keyboardShortcut(".", modifiers: .command)
                Button("Find in Conversation") { app.toggleSearchRequested = true }
                    .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button("Hands-Free Voice…") { app.showVoiceModeRequested = true }
                    .keyboardShortcut("j", modifiers: .command)
                Button("Live Transcription") { app.showLiveRequested = true }
                    .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}
