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
}

// MARK: - Sparkline (pure SwiftUI Shape)

/// A tiny inline line chart over a raw value series (normalized internally).
/// Snapshot-safe: no animation, no onAppear — it just draws.
struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
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
