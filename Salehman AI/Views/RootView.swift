import SwiftUI

/// The two top-level surfaces.
enum AppTab: String, CaseIterable, Identifiable {
    case chat, markets
    var id: String { rawValue }
    var title: String { self == .chat ? "Chat" : "Markets" }
    var icon: String  { self == .chat ? "bubble.left.and.bubble.right.fill" : "chart.line.uptrend.xyaxis" }
}

/// Top-level container: a custom segmented tab bar over the shared background.
/// Chat (`ContentView`) stays alive across tab switches via `.opacity` so its
/// in-flight task, streaming, and message state survive a peek at Markets.
/// Markets is created lazily on first visit (it spins up network polling).
struct RootView: View {
    @ObservedObject private var app = AppState.shared
    @State private var visitedMarkets = false

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
        }
    }
}
