import SwiftUI
import Combine

/// Lightweight bridge between menu-bar `.commands` (which live in the App scene)
/// and `ContentView`'s local `@State`. Menu items flip an edge-trigger flag here;
/// `ContentView` observes it, performs the action, and resets the flag.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// Which top-level tab is showing (Chat or Markets).
    @Published var selectedTab: AppTab = .chat

    @Published var newChatRequested = false
    @Published var stopRequested = false
    @Published var showSettingsRequested = false
    @Published var showLiveRequested = false
    @Published var toggleSearchRequested = false
    @Published var focusInputRequested = false

    private init() {}
}
