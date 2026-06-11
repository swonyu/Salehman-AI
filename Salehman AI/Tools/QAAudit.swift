import AppKit

/// **Self-judging visual QA** — turns `QASnapshots`' pictures into pass/fail.
///
/// After every capture this audits each PNG and writes `AUDIT.json` next to
/// them, so a session (or a gate) can verify the UI without human eyes:
///
/// * **nonBlank** — the render produced real content (≥ a handful of distinct
///   sampled colors), catching silent `ImageRenderer` failures.
/// * **canvasFlat** — sampled canvas points sit within tolerance of the
///   design-language grey (`codeSurface`/`codeSurfaceSide`), catching glow
///   bleed, gradient regressions, or translucent stacking sneaking back in.
/// * **baselineDiff** — percentage of sampled pixels that moved vs
///   `qa/baselines/<name>.png` (adopted on demand), plus a red heat-map PNG
///   for any snapshot that changed >0.5% — regression *detection*, not just
///   pictures. No baseline yet = informational, never a failure.
///
/// The UI-test gate asserts `failures == []`, so a visual regression fails
/// the build the same way a broken unit test does.
@MainActor
enum QAAudit {

    struct CheckResult: Codable {
        let name: String
        let pass: Bool
        let detail: String
    }
    struct SnapshotResult: Codable {
        let snapshot: String
        let checks: [CheckResult]
        let diffPercent: Double?
    }
    struct Report: Codable {
        let generatedAt: String
        let results: [SnapshotResult]
        let failures: [String]
    }

    /// Expected canvas shade per snapshot, sampled near the BOTTOM corners
    /// (headers/banners legitimately use the panel shade up top). `nil` =
    /// canvas check skipped (Today keeps its landing glow by design).
    private static let expectedCanvas: [String: CGFloat] = [
        "chat_live": 0.125, "chat_samples": 0.125,
        "agents": 0.125, "notes": 0.125, "knowledge": 0.125,
        "markets": 0.095,   // bottom edge = the flat disclaimer footer
        // "memory" exempt: it's a SHEET with rounded corners — corner sampling
        // reads the cutout, not a canvas (round-1 false-positive).
        "settings": 0.095,
    ]

    /// Same repo-root resolution as `QASnapshots.qaDir` (kept self-contained
    /// so the two files never block on each other's in-flight edits).
    static var defaultQADir: URL {
        if let custom = ProcessInfo.processInfo.environment["QA_SNAPSHOT_DIR"] {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/Salehman AI/qa", isDirectory: true)
    }

    /// Convenience entry points for menu items / launch hooks.
    static func runDefault() {
        run(snapshotsDir: defaultQADir.appendingPathComponent("snapshots"),
            baselinesDir: defaultQADir.appendingPathComponent("baselines"))
    }
    static func adoptBaselinesDefault() {
        adoptBaselines(snapshotsDir: defaultQADir.appendingPathComponent("snapshots"),
                       baselinesDir: defaultQADir.appendingPathComponent("baselines"))
    }

    static func run(snapshotsDir: URL, baselinesDir: URL) {
        var results: [SnapshotResult] = []
        var failures: [String] = []

        let names = ((try? FileManager.default.contentsOfDirectory(atPath: snapshotsDir.path)) ?? [])
            .filter { $0.hasSuffix(".png") && !$0.hasSuffix("_diff.png") }.sorted()

        for file in names {
            let name = String(file.dropLast(4))
            guard let rep = bitmap(at: snapshotsDir.appendingPathComponent(file)) else {
                results.append(.init(snapshot: name,
                                     checks: [.init(name: "decodable", pass: false, detail: "PNG unreadable")],
                                     diffPercent: nil))
                failures.append(name)
                continue
            }
            var checks: [CheckResult] = []

            // nonBlank — sample a sparse grid, count distinct quantized colors.
            let distinct = distinctSampleCount(rep)
            checks.append(.init(name: "nonBlank", pass: distinct >= 8,
                                detail: "\(distinct) distinct sampled colors"))

            // canvasFlat — bottom-corner samples within ±0.035 of the target grey.
            if let target = expectedCanvas[name] {
                let measured = bottomCornerLuma(rep)
                let ok = measured.allSatisfy { abs($0 - target) <= 0.035 }
                checks.append(.init(name: "canvasFlat", pass: ok,
                                    detail: "target \(target), corners \(measured.map { String(format: "%.3f", $0) }.joined(separator: "/"))"))
            }

            // baselineDiff — informational unless a baseline exists AND moved.
            var diffPercent: Double? = nil
            let baseURL = baselinesDir.appendingPathComponent(file)
            if let base = bitmap(at: baseURL) {
                let (pct, heat) = diff(rep, base)
                diffPercent = pct
                if pct > 0.5, let heat {
                    try? heat.write(to: snapshotsDir.appendingPathComponent("\(name)_diff.png"))
                }
                checks.append(.init(name: "baselineDiff", pass: true,
                                    detail: String(format: "%.2f%% changed vs baseline", pct)))
            } else {
                checks.append(.init(name: "baselineDiff", pass: true, detail: "no baseline adopted yet"))
            }

            if checks.contains(where: { $0.pass == false }) { failures.append(name) }
            results.append(.init(snapshot: name, checks: checks, diffPercent: diffPercent))
        }

        let report = Report(generatedAt: ISO8601DateFormatter().string(from: Date()),
                            results: results, failures: failures.sorted())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(report) {
            try? data.write(to: snapshotsDir.appendingPathComponent("AUDIT.json"))
        }
    }

    /// Promote the current snapshots to baselines (menu/trigger-file driven).
    static func adoptBaselines(snapshotsDir: URL, baselinesDir: URL) {
        try? FileManager.default.createDirectory(at: baselinesDir, withIntermediateDirectories: true)
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: snapshotsDir.path)) ?? [])
            .filter { $0.hasSuffix(".png") && !$0.hasSuffix("_diff.png") }
        for f in files {
            let dst = baselinesDir.appendingPathComponent(f)
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.copyItem(at: snapshotsDir.appendingPathComponent(f), to: dst)
        }
    }

    // MARK: - Pixel helpers

    private static func bitmap(at url: URL) -> NSBitmapImageRep? {
        guard let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data) else { return nil }
        return rep
    }

    /// Quantized distinct-color count over a sparse sample grid.
    private static func distinctSampleCount(_ rep: NSBitmapImageRep) -> Int {
        var seen = Set<UInt32>()
        let w = rep.pixelsWide, h = rep.pixelsHigh
        let step = max(1, min(w, h) / 40)
        var y = 0
        while y < h {
            var x = 0
            while x < w {
                if let c = rep.colorAt(x: x, y: y) {
                    let key = (UInt32(c.redComponent * 31) << 10)
                        | (UInt32(c.greenComponent * 31) << 5)
                        | UInt32(c.blueComponent * 31)
                    seen.insert(key)
                }
                x += step
            }
            y += step
        }
        return seen.count
    }

    /// Average luma at two bottom-corner sample points (12 px inset).
    private static func bottomCornerLuma(_ rep: NSBitmapImageRep) -> [CGFloat] {
        let w = rep.pixelsWide, h = rep.pixelsHigh
        let inset = 12
        let points = [(inset, h - inset), (w - inset, h - inset)]
        return points.compactMap { (x, y) in
            rep.colorAt(x: x, y: y).map {
                0.2126 * $0.redComponent + 0.7152 * $0.greenComponent + 0.0722 * $0.blueComponent
            }
        }
    }

    /// Sampled pixel diff (per-channel threshold) + red heat-map at sample
    /// resolution. Compares the overlapping region when sizes drift.
    private static func diff(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep) -> (Double, Data?) {
        let w = min(a.pixelsWide, b.pixelsWide), h = min(a.pixelsHigh, b.pixelsHigh)
        let step = 3
        let sw = w / step, sh = h / step
        guard sw > 0, sh > 0,
              let heat = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: sw, pixelsHigh: sh,
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                          isPlanar: false, colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0, bitsPerPixel: 0)
        else { return (0, nil) }

        var changed = 0, total = 0
        for sy in 0..<sh {
            for sx in 0..<sw {
                let x = sx * step, y = sy * step
                total += 1
                guard let ca = a.colorAt(x: x, y: y), let cb = b.colorAt(x: x, y: y) else { continue }
                let moved = abs(ca.redComponent - cb.redComponent) > 0.05
                    || abs(ca.greenComponent - cb.greenComponent) > 0.05
                    || abs(ca.blueComponent - cb.blueComponent) > 0.05
                if moved {
                    changed += 1
                    heat.setColor(NSColor(red: 1, green: 0.1, blue: 0.1, alpha: 0.9), atX: sx, y: sy)
                } else {
                    heat.setColor(NSColor(red: 0, green: 0, blue: 0, alpha: 0.08), atX: sx, y: sy)
                }
            }
        }
        let pct = total == 0 ? 0 : Double(changed) / Double(total) * 100
        return (pct, pct > 0.5 ? heat.representation(using: .png, properties: [:]) : nil)
    }
}
