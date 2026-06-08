import SwiftUI
import Combine

/// Lightweight bridge between menu-bar `.commands` (which live in the App scene)
/// and `ContentView`'s local `@State`. Menu items flip an edge-trigger flag here;
/// `ContentView` observes it, performs the action, and resets the flag.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// Which top-level tab is showing. Launches on Today (the home dashboard).
    @Published var selectedTab: AppTab = .today

    @Published var newChatRequested = false
    @Published var stopRequested = false
    @Published var showSettingsRequested = false
    @Published var showLiveRequested = false
    @Published var toggleSearchRequested = false
    @Published var focusInputRequested = false
    /// ⌘K quick-command palette (presented over the root window).
    @Published var showCommandPaletteRequested = false
    /// ⌘/ keyboard-shortcuts cheat sheet.
    @Published var showShortcutsRequested = false
    /// "About Salehman AI" sheet — identity, capabilities, privacy stance.
    @Published var showAboutRequested = false
    /// ⌘J hands-free Voice Mode (talk↔listen) — presented over the root window.
    @Published var showVoiceModeRequested = false

    private init() {}
}

/// The top-level surfaces.
enum AppTab: String, CaseIterable, Identifiable {
    // Order defines the tab-bar layout AND ⌘-number mapping: Today (Home) first.
    case today, chat, code, agents, markets, scratchpad, knowledge
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:      return "Today"
        case .chat:       return "Chat"
        case .code:       return "Code"
        case .agents:     return "Agents"
        case .markets:    return "Markets"
        case .scratchpad: return "Notes"
        case .knowledge:  return "Knowledge"
        }
    }

    var icon: String {
        switch self {
        case .today:      return "sun.max.fill"
        case .chat:       return "bubble.left.and.bubble.right.fill"
        case .code:       return "chevron.left.forwardslash.chevron.right"
        case .agents:     return "person.3.fill"
        case .markets:    return "chart.line.uptrend.xyaxis"
        case .scratchpad: return "checklist"
        case .knowledge:  return "books.vertical.fill"
        }
    }
}
