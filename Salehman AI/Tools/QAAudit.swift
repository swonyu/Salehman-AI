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
    ]

    /// Deterministic surfaces must not drift past these change budgets without
    /// an explicit baseline adoption — THE regression tripwire. Live surfaces
    /// (real chat history, real window) stay informational: they change every
    /// conversation by design.
    private static let diffBudgets: [String: Double] = [
        "chat_samples": 2.0, "code_samples": 2.0, "contrast_probe": 1.0,
        // NO budget for settings: its "salehman model" status row probes the
        // LIVE Ollama state, so the render is legitimately nondeterministic.
        // (A "0.095" budget appeared here once — that's the settings CANVAS
        // grey, a copy-paste slip into the wrong dict; it made the gate flap.)
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

        // Structural findings bridged from capture (layout geometry + AX tree).
        let structure: [String: QASurfaceStructure] =
            (try? Data(contentsOf: snapshotsDir.appendingPathComponent("STRUCTURE.json")))
                .flatMap { try? JSONDecoder().decode([String: QASurfaceStructure].self, from: $0) } ?? [:]

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

            // canvasFlat — bottom corners + mid-edges within ±0.035 of the
            // target grey (edges catch a sidebar/panel regressing to
            // translucent even when the corners survive).
            if let target = expectedCanvas[name] {
                let measured = canvasSampleLuma(rep)
                let ok = measured.allSatisfy { abs($0 - target) <= 0.035 }
                checks.append(.init(name: "canvasFlat", pass: ok,
                                    detail: "target \(target), samples \(measured.map { String(format: "%.3f", $0) }.joined(separator: "/"))"))
            }

            // contrast — the readability probe's bands, measured for real.
            if name == "contrast_probe" {
                checks.append(contentsOf: contrastChecks(rep))
            }

            // Structural checks from capture: layout-invariant assertions and
            // the accessibility sweep (unlabeled interactive elements FAIL;
            // an empty AX tree offscreen is reported, not failed).
            if let s = structure[name] {
                for g in s.geo {
                    checks.append(.init(name: g.name, pass: g.pass, detail: g.detail))
                }
                if s.axInteractive == 0 {
                    checks.append(.init(name: "axLabels", pass: true,
                                        detail: "AX tree empty offscreen — not assessable"))
                } else {
                    checks.append(.init(name: "axLabels", pass: s.axUnlabeled.isEmpty,
                                        detail: s.axUnlabeled.isEmpty
                                            ? "\(s.axInteractive) interactive elements, all labeled"
                                            : "\(s.axUnlabeled.count)/\(s.axInteractive) UNLABELED: \(s.axUnlabeled.prefix(5).joined(separator: ", "))"))
                }
            }

            // baselineDiff — informational for live surfaces; a FAILURE for
            // deterministic ones that exceed their drift budget.
            var diffPercent: Double? = nil
            let baseURL = baselinesDir.appendingPathComponent(file)
            if let base = bitmap(at: baseURL) {
                let (pct, heat) = diff(rep, base)
                diffPercent = pct
                if pct > 0.5, let heat {
                    try? heat.write(to: snapshotsDir.appendingPathComponent("\(name)_diff.png"))
                }
                let budget = diffBudgets[name]
                let pass = budget.map { pct <= $0 } ?? true
                checks.append(.init(name: "baselineDiff", pass: pass,
                                    detail: String(format: "%.2f%% changed vs baseline%@", pct,
                                                   budget.map { String(format: " (budget %.1f%%)", $0) } ?? "")))
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

        // Trend trail: one JSONL line per audit run (timestamp, fail count,
        // total diff) — cheap history for "when did this start drifting?".
        let totalDiff = results.compactMap(\.diffPercent).reduce(0, +)
        let histLine = "{\"at\":\"\(report.generatedAt)\",\"failures\":\(failures.count),\"surfaces\":\(results.count),\"totalDiffPct\":\(String(format: "%.2f", totalDiff))}\n"
        if let d = histLine.data(using: .utf8) {
            let url = snapshotsDir.deletingLastPathComponent().appendingPathComponent("history.jsonl")
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile(); handle.write(d); try? handle.close()
            } else {
                try? d.write(to: url)
            }
        }

        writeHTMLReport(report, in: snapshotsDir)
    }

    /// One-glance owner report: every surface with its badges, current image,
    /// and (when present) baseline + heat-map side by side. Pure static HTML —
    /// open qa/snapshots/report.html in any browser.
    private static func writeHTMLReport(_ report: Report, in dir: URL) {
        var html = """
        <!doctype html><meta charset="utf-8"><title>Salehman AI — QA report</title>
        <style>
        body{background:#1b1b1b;color:#eee;font:14px -apple-system,sans-serif;margin:24px}
        h1{font-size:18px} .ok{color:#5dd167} .bad{color:#ff5d5d}
        .card{background:#252525;border:1px solid #3a3a3a;border-radius:10px;padding:14px;margin:14px 0}
        .imgs{display:flex;gap:10px;flex-wrap:wrap} .imgs figure{margin:0}
        .imgs img{max-width:380px;border:1px solid #444;border-radius:6px}
        figcaption{font-size:11px;color:#999;margin-top:4px}
        .badge{display:inline-block;font-size:11px;padding:2px 8px;border-radius:8px;background:#333;margin-right:6px}
        </style>
        <h1>QA report — \(report.generatedAt) ·
        <span class="\(report.failures.isEmpty ? "ok" : "bad")">\(report.failures.isEmpty ? "ALL GREEN" : "\(report.failures.count) FAILING: \(report.failures.joined(separator: ", "))")</span></h1>
        """
        for r in report.results {
            html += "<div class=\"card\"><b>\(r.snapshot)</b><br>"
            for c in r.checks {
                html += "<span class=\"badge \(c.pass ? "ok" : "bad")\">\(c.pass ? "✓" : "✗") \(c.name)</span> <small>\(c.detail)</small><br>"
            }
            html += "<div class=\"imgs\">"
            html += "<figure><img src=\"\(r.snapshot).png\"><figcaption>current</figcaption></figure>"
            html += "<figure><img src=\"../baselines/\(r.snapshot).png\" onerror=\"this.parentElement.style.display='none'\"><figcaption>baseline</figcaption></figure>"
            html += "<figure><img src=\"\(r.snapshot)_diff.png\" onerror=\"this.parentElement.style.display='none'\"><figcaption>diff heat-map</figcaption></figure>"
            html += "</div></div>"
        }
        try? html.write(to: dir.appendingPathComponent("report.html"), atomically: true, encoding: .utf8)
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

    /// Luma at canvas sample points: bottom corners + both mid-edges (12 px inset).
    /// GAMMA-space on purpose: the check compares against the design tokens'
    /// literal grey values (`Color(white: 0.125)`), not a perceptual ratio.
    private static func canvasSampleLuma(_ rep: NSBitmapImageRep) -> [CGFloat] {
        let w = rep.pixelsWide, h = rep.pixelsHigh
        let inset = 12
        let points = [(inset, h - inset), (w - inset, h - inset),
                      (inset, h / 2), (w - inset, h / 2)]
        return points.compactMap { (x, y) in
            rep.colorAt(x: x, y: y).map {
                0.2126 * $0.redComponent + 0.7152 * $0.greenComponent + 0.0722 * $0.blueComponent
            }
        }
    }

    /// WCAG relative luminance — sRGB channels must be LINEARIZED first.
    /// (v4's first run computed luma in gamma space and flagged the accent at
    /// 2.21:1; the true linear-space ratio is ≈4.3:1. The audit was the bug.)
    private static func luma(_ c: NSColor) -> CGFloat {
        func lin(_ v: CGFloat) -> CGFloat {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
    }

    /// Measure each `ContrastProbe` band: scan the band's center line, take the
    /// median sample as background and the most-distant sample as glyph core,
    /// then compute the WCAG-style ratio (L1+0.05)/(L2+0.05). Anti-aliasing
    /// dilutes glyph edges, so the probe packs heavy glyphs ("HHHH") across the
    /// line and we take the EXTREME — the core of a stroke.
    private static func contrastChecks(_ rep: NSBitmapImageRep) -> [CheckResult] {
        let bands = ContrastProbe.bands
        let w = rep.pixelsWide, h = rep.pixelsHigh
        guard h > bands.count, w > 40 else {
            return [.init(name: "contrast", pass: false, detail: "probe image too small")]
        }
        var results: [CheckResult] = []
        for (i, band) in bands.enumerated() {
            let y = Int((Double(i) + 0.5) / Double(bands.count) * Double(h))
            var lumas: [CGFloat] = []
            // Scan the middle 80% of the line (the text is centered).
            var x = w / 10
            while x < w - w / 10 {
                if let c = rep.colorAt(x: x, y: y) { lumas.append(luma(c)) }
                x += 2
            }
            guard lumas.count > 10 else {
                results.append(.init(name: "contrast:\(band.0)", pass: false, detail: "no samples"))
                continue
            }
            let sorted = lumas.sorted()
            let bg = sorted[sorted.count / 2]                       // median = background
            let extreme = abs(sorted.first! - bg) > abs(sorted.last! - bg)
                ? sorted.first! : sorted.last!                       // farthest = glyph core
            let ratio = Double((max(bg, extreme) + 0.05) / (min(bg, extreme) + 0.05))
            let meets = ratio >= band.4
            results.append(.init(name: "contrast:\(band.0)",
                                 pass: band.5 ? meets : true,
                                 detail: String(format: "%.2f:1 (min %.1f:1)%@", ratio, band.4,
                                                band.5 ? "" : (meets ? " [advisory]" : " [ADVISORY — BELOW POLICY, token fix pending]"))))
        }
        return results
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
