import SwiftUI
import AppKit

/// **QA capture v3 — real-window rendering.**
///
/// Round 1 of the snapshot harness used `ImageRenderer`, and the pictures
/// told the truth about it: pure-SwiftUI galleries render perfectly, but
/// anything wrapping AppKit (TextField/Menu → yellow "unsupported"
/// placeholders) or lazy/scroll containers (Settings → blank panel, Today →
/// white void, live transcript → empty) does not survive a context-free
/// render. The fix is to give views what they actually need — a window:
///
/// * `renderInWindow(_:size:)` mounts the view in an **offscreen borderless
///   `NSWindow`** via `NSHostingView`, forces a real layout pass, and
///   captures with `bitmapImageRepForCachingDisplay` — full AppKit fidelity
///   (scroll views populate, text fields draw, menus show their labels).
/// * `captureLiveWindows(to:)` photographs the app's **actual on-screen
///   windows** — an app may always capture its own windows, no Screen
///   Recording permission involved — giving TRUE screenshots of the running
///   UI (real chat history, real settings state).
///
/// Triggers (independent of QASnapshots so the two files never block on each
/// other): `qa/WINDOW_REQUEST` consumed on launch after success, and the
/// View ▸ "Capture Live Window" menu item.
@MainActor
enum QACapture {

    static var qaDir: URL {
        if let custom = ProcessInfo.processInfo.environment["QA_SNAPSHOT_DIR"] {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/Salehman AI/qa", isDirectory: true)
    }

    // (Offscreen per-view rendering lives in QASnapshots.snap — the hosted
    // NSHostingView path. This file owns only what QASnapshots can't do:
    // photographing the REAL windows.)

    /// Photograph every visible app window (true pixels of the running UI).
    /// Returns the file names written.
    @discardableResult
    static func captureLiveWindows(to dir: URL? = nil) -> [String] {
        let out = dir ?? qaDir.appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var written: [String] = []
        for (i, window) in NSApp.windows.enumerated() where window.isVisible {
            guard let view = window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { continue }
            let name = "window_\(i)_live.png"
            if (try? png.write(to: out.appendingPathComponent(name))) != nil {
                written.append(name)
            }
        }
        return written
    }

    /// Launch hook — `qa/WINDOW_REQUEST` → capture live windows; consumed
    /// only after at least one window was written (premature launch states
    /// retry on the next launch).
    static func checkAndRun() {
        let request = qaDir.appendingPathComponent("WINDOW_REQUEST")
        guard FileManager.default.fileExists(atPath: request.path) else { return }
        Task { @MainActor in
            // Let the main window actually appear + first layout settle.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let written = captureLiveWindows()
            if !written.isEmpty {
                try? FileManager.default.removeItem(at: request)
            }
        }
    }
}
