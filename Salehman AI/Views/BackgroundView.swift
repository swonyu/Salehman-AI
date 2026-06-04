import SwiftUI

/// The app's shared dark gradient + soft accent glows. State-free so SwiftUI
/// keeps it stable across body redraws, and `drawingGroup()`-cached. Promoted out
/// of ContentView so every tab shares one cheap background instead of each
/// drawing its own glows.
struct BackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Soft glows for depth. Smaller blur than before — 160px convolves
            // every frame and was the dominant GPU cost on integrated Macs.
            Circle().fill(Theme.accent.opacity(0.18)).frame(width: 480).blur(radius: 90)
                .offset(x: -220, y: -260)
            Circle().fill(Theme.accent2.opacity(0.16)).frame(width: 420).blur(radius: 90)
                .offset(x: 260, y: 300)
        }
        .ignoresSafeArea()
        .drawingGroup()
    }
}
