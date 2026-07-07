import SwiftUI

// MARK: - SparkSeries (pure, testable)
//
// Helpers for the inline sparklines: downsample a long close history to a handful
// of evenly-spaced points, and normalize a series into 0…1 for drawing. Pure +
// deterministic so they're unit-tested without any view.
enum SparkSeries {

    /// Downsample to at most `maxPoints` evenly-spaced samples (keeps first+last).
    /// Series already short enough are returned unchanged. `nonisolated` so the
    /// nonisolated `Sparkline.path(in:)` (a Shape requirement) can call it.
    nonisolated static func downsample(_ values: [Double], maxPoints: Int = 32) -> [Double] {
        guard maxPoints >= 2, values.count > maxPoints else { return values }
        let step = Double(values.count - 1) / Double(maxPoints - 1)
        var out: [Double] = []
        out.reserveCapacity(maxPoints)
        for i in 0..<maxPoints {
            let idx = Int((Double(i) * step).rounded())
            out.append(values[min(idx, values.count - 1)])
        }
        return out
    }

    /// Map values to 0…1 (min→0, max→1). A flat series renders as a mid-line (0.5).
    nonisolated static func normalize(_ values: [Double]) -> [Double] {
        guard let lo = values.min(), let hi = values.max() else { return [] }
        guard hi > lo else { return values.map { _ in 0.5 } }
        return values.map { ($0 - lo) / (hi - lo) }
    }

    /// The y-domain [lo, hi] the Sparkline shape actually draws against, EXTENDED to
    /// include `extra` prices (e.g. a stop/target that fall outside the series' own
    /// min/max) so an overlay line can be positioned in the same normalized space the
    /// Shape uses. Never clamps — a price outside [lo, hi] before extension is folded
    /// into the domain, not silently pinned to the nearest edge (a mis-placed stop/target
    /// line would be a fabricated visual claim; OSS-borrow B2).
    /// nil when there is no meaningful range (empty series, or every point + extra identical).
    nonisolated static func domain(_ values: [Double], extending extra: [Double] = []) -> (lo: Double, hi: Double)? {
        var lo = values.min()
        var hi = values.max()
        for e in extra {
            lo = min(lo ?? e, e)
            hi = max(hi ?? e, e)
        }
        guard let lo, let hi, hi > lo else { return nil }
        return (lo, hi)
    }

    /// Fraction (0 = bottom/lo, 1 = top/hi) of `price` within `domain`. Domain must have
    /// hi > lo (call `domain(_:extending:)` first and guard its nil case — never derive a
    /// domain from `price` itself, that would trivially always be in-range).
    nonisolated static func fraction(_ price: Double, in domain: (lo: Double, hi: Double)) -> Double {
        (price - domain.lo) / (domain.hi - domain.lo)
    }
}

// MARK: - Sparkline (pure SwiftUI Shape)

/// A tiny inline line chart over a raw value series (normalized internally).
/// Snapshot-safe: no animation, no onAppear — it just draws.
struct Sparkline: Shape {
    let values: [Double]

    // `nonisolated` — Shape.path(in:) is a nonisolated protocol requirement, but the
    // project defaults every type to MainActor isolation; without this the conformance
    // "crosses into main actor-isolated code" (a Swift 6 data-race error in Xcode).
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let norm = SparkSeries.normalize(values)
        guard norm.count >= 2, rect.width > 0, rect.height > 0 else { return path }
        let stepX = rect.width / CGFloat(norm.count - 1)
        for (i, v) in norm.enumerated() {
            let x = rect.minX + CGFloat(i) * stepX
            let y = rect.maxY - CGFloat(v) * rect.height   // 0 → bottom, 1 → top
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}
