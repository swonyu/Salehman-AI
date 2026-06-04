import SwiftUI

/// Top-level container: a custom segmented tab bar over the shared background.
/// Chat (`ContentView`) stays alive across tab switches via `.opacity` so its
/// in-flight task, streaming, and message state survive a peek at another tab.
/// Agents and Markets are created lazily on first visit (Markets spins up
/// network polling; Agents observes the live mission progress).
/// `AppTab` lives in `AppState`.
struct RootView: View {
    @ObservedObject private var app = AppState.shared
    @State private var visitedMarkets = false
    @State private var visitedAgents = false

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 0) {
                TabSwitcherBar(selection: $app.selectedTab)
                Divider().overlay(DS.Palette.hairline)

                ZStack {
                    ContentView()
                        .opacity(app.selectedTab == .chat ? 1 : 0)
                        .allowsHitTesting(app.selectedTab == .chat)

                    if visitedAgents || app.selectedTab == .agents {
                        AgentsView()
                            .opacity(app.selectedTab == .agents ? 1 : 0)
                            .allowsHitTesting(app.selectedTab == .agents)
                    }

                    if visitedMarkets || app.selectedTab == .markets {
                        MarketsView()
                            .opacity(app.selectedTab == .markets ? 1 : 0)
                            .allowsHitTesting(app.selectedTab == .markets)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: app.selectedTab) { _, tab in
            if tab == .markets { visitedMarkets = true }
            if tab == .agents  { visitedAgents = true }
        }
    }
}
