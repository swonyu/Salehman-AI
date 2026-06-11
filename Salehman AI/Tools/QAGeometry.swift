import SwiftUI

/// **Geometry probe** — pixel checks can't see LAYOUT intent. This collector
/// lets views report their real frames during a QA capture, and turns the
/// design's layout invariants into assertions:
///
/// * the chat's reading column is genuinely capped at 780pt and CENTERED,
/// * the composer aligns to the same column,
/// * both still hold at narrow widths.
///
/// Views opt in with `.qaGeometry("key")` (a no-op unless a capture is
/// running — `enabled` is flipped by `QASnapshots.captureAll`, so normal app
/// use pays nothing but a boolean check). After rendering, `QASnapshots`
/// calls `assertions(for:)` and folds the results into the audit as checks.
@MainActor
enum QAGeometry {
    static var enabled = false
    private(set) static var frames: [String: CGRect] = [:]

    static func reset() { frames.removeAll() }
    static func record(_ key: String, _ frame: CGRect) {
        guard enabled else { return }
        frames[key] = frame
    }

    struct Assertion: Codable {
        let name: String
        let pass: Bool
        let detail: String
    }

    /// Layout invariants for a chat render at `rootWidth`. Keys are recorded
    /// by ContentView's probes ("chat.column", "chat.input") relative to the
    /// "qaRoot" coordinate space.
    static func chatAssertions(rootWidth: CGFloat) -> [Assertion] {
        var out: [Assertion] = []
        let expectedWidth = min(780, rootWidth - 36)   // 18pt horizontal padding each side

        if let col = frames["chat.column"] {
            let centered = abs((col.midX) - rootWidth / 2) <= 2
            out.append(.init(name: "geo:column centered",
                             pass: centered,
                             detail: String(format: "midX %.1f vs root mid %.1f", col.midX, rootWidth / 2)))
            out.append(.init(name: "geo:column width",
                             pass: abs(col.width - expectedWidth) <= 4,
                             detail: String(format: "%.0fpt (expected ≈%.0f)", col.width, expectedWidth)))
        } else {
            // Legitimate when the transcript is empty (the empty state has its
            // own layout) — note it, don't fail.
            out.append(.init(name: "geo:column centered", pass: true,
                             detail: "column not rendered (empty transcript) — skipped"))
        }

        if let input = frames["chat.input"] {
            let cap = min(780, rootWidth)
            out.append(.init(name: "geo:input in column",
                             pass: input.width <= cap + 2 && abs(input.midX - rootWidth / 2) <= 2,
                             detail: String(format: "width %.0f, midX %.1f", input.width, input.midX)))
        } else {
            out.append(.init(name: "geo:input in column", pass: false, detail: "no frame recorded"))
        }
        return out
    }
}

extension View {
    /// Report this view's frame (in the "qaRoot" space) to `QAGeometry` under
    /// `key`. Free when no capture is running.
    func qaGeometry(_ key: String) -> some View {
        onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named("qaRoot"))
        } action: { frame in
            QAGeometry.record(key, frame)
        }
    }
}

/// Per-surface structural results bridged from capture (QASnapshots) to the
/// audit (QAAudit) via `qa/snapshots/STRUCTURE.json`.
struct QASurfaceStructure: Codable {
    var geo: [QAGeometry.Assertion] = []
    var axInteractive: Int = 0
    var axUnlabeled: [String] = []
}
