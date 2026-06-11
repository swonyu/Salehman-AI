import SwiftUI

/// Top-level container: a custom segmented tab bar over the shared background.
/// Every tab — INCLUDING Chat — is created lazily on first visit and then kept
/// alive across switches via `.opacity`, so in-flight tasks, streaming, and
/// message state survive a peek at another tab. (Markets spins up network
/// polling; Agents observes the live mission progress.)
/// `AppTab` lives in `AppState`.
struct RootView: View {
    @ObservedObject private var app = AppState.shared
    @State private var visitedMarkets = false
    @State private var visitedAgents = false
    @State private var visitedScratchpad = false
    @State private var visitedKnowledge = false
    @State private var visitedToday = false
    @State private var visitedCode = false
    // The chat is the HEAVIEST view tree in the app and the default tab is Today —
    // building ContentView at launch was a large slice of "the app always lags
    // when launched" (launch profile: main thread pegged in AttributeGraph /
    // metadata instantiation constructing the unused chat tree). Now lazy like
    // every other tab; launching straight onto .chat still mounts immediately.
    @State private var visitedChat = AppState.shared.selectedTab == .chat

    /// ContentView consumes AppState's one-shot signals (Settings / Live / New
    /// chat…) via `onChange` — which never fires for a value that was ALREADY
    /// true when the view mounts. So when such a signal arrives while the chat
    /// is unmounted: mount it, swallow the signal, and re-pulse it on the next
    /// runloop so the freshly-mounted ContentView sees a false→true transition.
    private func mountChatAndRepulse(_ keyPath: ReferenceWritableKeyPath<AppState, Bool>, _ fired: Bool) {
        guard fired, !visitedChat else { return }
        visitedChat = true
        app[keyPath: keyPath] = false
        // 0.4 s, not "next runloop": the chat tree takes a few frames to mount on
        // a loaded machine, and the re-pulse must land AFTER its `onChange`
        // observers are installed or the signal is lost again. The sheet's own
        // present animation hides the delay completely.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            app[keyPath: keyPath] = true
        }
    }

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 0) {
                TabSwitcherBar(selection: $app.selectedTab)
                Divider().overlay(DS.Palette.hairline)

                ZStack {
                    if visitedChat || app.selectedTab == .chat {
                        ContentView()
                            .opacity(app.selectedTab == .chat ? 1 : 0)
                            .allowsHitTesting(app.selectedTab == .chat)
                            .animation(DS.Motion.spring, value: app.selectedTab)
                    }

                    if visitedCode || app.selectedTab == .code {
                        CodeView()
                            .opacity(app.selectedTab == .code ? 1 : 0)
                            .allowsHitTesting(app.selectedTab == .code)
                            .animation(DS.Motion.spring, value: app.selectedTab)
                    }

                    if visitedAgents || app.selectedTab == .agents {
                        AgentsView()
                            .opacity(app.selectedTab == .agents ? 1 : 0)
                            .allowsHitTesting(app.selectedTab == .agents)
                            .animation(DS.Motion.spring, value: app.selectedTab)
                    }

                    if visitedMarkets || app.selectedTab == .markets {
                        MarketsView()
                            .opacity(app.selectedTab == .markets ? 1 : 0)
                            .allowsHitTesting(app.selectedTab == .markets)
                    }

                    if visitedScratchpad || app.selectedTab == .scratchpad {
                        ScratchpadView()
                            .opacity(app.selectedTab == .scratchpad ? 1 : 0)
                            .allowsHitTesting(app.selectedTab == .scratchpad)
                    }

                    if visitedKnowledge || app.selectedTab == .knowledge {
                        KnowledgeView()
                            .opacity(app.selectedTab == .knowledge ? 1 : 0)
                            .allowsHitTesting(app.selectedTab == .knowledge)
                    }

                    if visitedToday || app.selectedTab == .today {
                        TodayView()
                            .opacity(app.selectedTab == .today ? 1 : 0)
                            .allowsHitTesting(app.selectedTab == .today)
                    }
                }

                // Always-visible shortcut hints, pinned to the bottom.
                BottomShortcutBar()
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: app.selectedTab) { _, tab in
            if tab == .chat    { visitedChat = true }
            if tab == .markets { visitedMarkets = true }
            if tab == .agents  { visitedAgents = true }
            if tab == .code    { visitedCode = true }
            if tab == .scratchpad { visitedScratchpad = true }
            if tab == .knowledge  { visitedKnowledge = true }
            if tab == .today      { visitedToday = true }
        }
        // Signals ContentView owns the UI for (its Settings/Live sheets, new-chat,
        // chat search): if the chat isn't mounted yet, mount + re-deliver.
        .onChange(of: app.showSettingsRequested) { _, v in mountChatAndRepulse(\.showSettingsRequested, v) }
        .onChange(of: app.showLiveRequested)     { _, v in mountChatAndRepulse(\.showLiveRequested, v) }
        .onChange(of: app.newChatRequested)      { _, v in mountChatAndRepulse(\.newChatRequested, v) }
        .onChange(of: app.toggleSearchRequested) { _, v in mountChatAndRepulse(\.toggleSearchRequested, v) }
    }
}
