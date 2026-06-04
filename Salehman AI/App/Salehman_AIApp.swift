//
//  Salehman_AIApp.swift
//  Salehman AI
//

import SwiftUI

@main
struct Salehman_AIApp: App {
    @StateObject private var app = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 980, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") { app.selectedTab = .chat; app.newChatRequested = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("View") {
                Button("Chat") { app.selectedTab = .chat }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Markets") { app.selectedTab = .markets }
                    .keyboardShortcut("2", modifiers: .command)
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
                Button("Live Transcription") { app.showLiveRequested = true }
                    .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}
