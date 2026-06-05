import SwiftUI

/// The app's shared dark gradient + soft accent glows. State-free so SwiftUI
/// keeps it stable across body redraws, and `drawingGroup()`-cached. Promoted out
/// of ContentView so every tab shares one cheap background instead of each
/// drawing its own glows.
struct BackgroundView: View {
    /// The two big accent glows, isolated into their own `.drawingGroup()` so
    /// the 90 px blur convolution rasterizes ONCE into a cached texture instead
    /// of every time anything above this view invalidates. The (free) gradient
    /// then composites natively on top — pulling `.drawingGroup()` off the
    /// outer `ZStack` keeps the cheap gradient cheap. Both layers are
    /// state-free → the cached texture survives all parent redraws.
    private var glows: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.18)).frame(width: 480).blur(radius: 90)
                .offset(x: -220, y: -260)
            Circle().fill(Theme.accent2.opacity(0.16)).frame(width: 420).blur(radius: 90)
                .offset(x: 260, y: 300)
        }
        .drawingGroup()
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            glows
        }
        .ignoresSafeArea()
    }
}
