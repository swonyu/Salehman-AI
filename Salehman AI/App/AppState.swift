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
    /// ⌘K quick-command palette (presented over the root window).
    @Published var showCommandPaletteRequested = false
    /// ⌘/ keyboard-shortcuts cheat sheet.
    @Published var showShortcutsRequested = false
    /// "About Salehman AI" sheet — identity, capabilities, privacy stance.
    @Published var showAboutRequested = false
    /// ⌘J hands-free Voice Mode (talk↔listen) — presented over the root window.
    @Published var showVoiceModeRequested = false

    /// Set `true` when an AI reply completes while the user is on a non-Chat tab.
    /// `TabSwitcherBar` uses it to render a pulse dot on the Chat pill; cleared
    /// automatically when the user switches to the Chat tab.
    @Published var chatHasUnread = false

    /// Mirrors `ChatViewModel.isRunning` so components outside ContentView's
    /// subtree (e.g. `BottomShortcutBar`) can show a Stop hint without wiring
    /// the view model through the whole hierarchy.
    @Published var aiIsRunning = false

    /// Edge-trigger: set `true` to ask `ScratchpadView` to focus its add field
    /// on the next appear or on change. Cleared by the view after acting.
    @Published var focusScratchpadAddFieldRequested = false

    /// Companion to `focusScratchpadAddFieldRequested`: when `true`, `ScratchpadView`
    /// also switches its segmented picker to Notes mode before focusing. Set by
    /// any action that means "create a note" (e.g. Today's "New Note" tile).
    @Published var scratchpadFocusNotesMode = false

    /// Edge-triggers for Code-tab actions that originate outside CodeView
    /// (e.g. BottomShortcutBar hints). CodeView observes these and clears them.
    @Published var reviewProjectRequested    = false
    @Published var toggleCodeFindRequested   = false
    @Published var focusCodeInputRequested   = false
    @Published var toggleCodeTreeRequested   = false

    private init() {}
}

/// The top-level surfaces.
enum AppTab: String, CaseIterable, Identifiable {
    // Order defines the tab-bar layout AND ⌘-number mapping: Today (Home) first.
    // `runescape` is appended last so ⌘1–7 stay put; its pill renders right
    // after Markets (pills follow `allCases` order, minus the corner tabs).
    case today, chat, code, agents, markets, scratchpad, knowledge, runescape
    var id: String { rawValue }

    /// The hide-set mechanism (a hidden tab vanishes from every navigation
    /// surface at once — tab bar, View-menu ⌘-number, command palette, shortcuts
    /// sheet, Today nav card, the tab-bar market pill — while its view stays
    /// compiled and programmatically reachable for the QA harness).
    ///
    /// History: Markets was hidden 2026-06-12 ("HIDE THE MARKETS TAB UNTIL
    /// FURTHER NOTICE") while it was sample-only. **Restored 2026-06-20** at the
    /// owner's request once a live worldwide feed landed — the set is now empty.
    /// To hide a tab again, add it here.
    nonisolated static let hidden: Set<AppTab> = []

    /// The user-visible tab roster — navigation surfaces iterate THIS, never
    /// `allCases`, so a hidden tab vanishes everywhere at once.
    nonisolated static var visible: [AppTab] { allCases.filter { !hidden.contains($0) } }

    /// Owner directive (2026-06-12): Notes + Knowledge render as SMALL corner
    /// icon buttons in the tab bar's right cluster ("really small like the
    /// copy button", in the old market-pill spot) instead of full-width
    /// pills. They stay real tabs — ⌘6/⌘7, the palette, and the shortcuts
    /// sheet all still navigate to them.
    nonisolated static let corner: [AppTab] = [.scratchpad, .knowledge]

    /// The full-size pill roster: visible tabs minus the compact corner tabs.
    nonisolated static var pills: [AppTab] { visible.filter { !corner.contains($0) } }

    var title: String {
        switch self {
        case .today:      return "Today"
        case .chat:       return "Chat"
        case .code:       return "Code"
        case .agents:     return "Agents"
        case .markets:    return "Markets"
        case .scratchpad: return "Notes"
        case .knowledge:  return "Knowledge"
        case .runescape:  return "RuneScape"
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
        case .runescape:  return "building.columns.fill"
        }
    }
}
