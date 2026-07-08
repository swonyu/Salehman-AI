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

    /// Same repo-root resolution as `QASnapshots.qaDir` — both delegate to the
    /// shared `QADir.resolved`. This used to be a self-contained copy; it drifted
    /// on the 2026-07-05 repo move (still resolving the dead ~/Desktop copy while
    /// captures landed in the live repo), which silently disabled the baseline
    /// tripwire until 2026-07-08. Never fork this resolution again.
    static var defaultQADir: URL { QADir.resolved }

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
            .filter { $0.hasSuffix(".png") && !$0.hasSuffix("_diff.png")
                      && !$0.hasSuffix("_deuter.png") && !$0.hasSuffix("_protan.png") }.sorted()

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
                // edgeClear (v6) — scan the FULL left/right edge columns, not just
                // the 4 canvasFlat points: catches content overflowing or clipping
                // at the frame edge anywhere down the side (the truncation class).
                let edge = edgeDeviation(rep, target: target)
                checks.append(.init(name: "edgeClear", pass: edge <= 0.06,
                                    detail: String(format: "%.1f%% of side-edge pixels off-canvas%@", edge * 100,
                                                   edge > 0.06 ? " — content reaching the frame edge?" : "")))
            }

            // contrast — the readability probe's bands, measured for real.
            if name == "contrast_probe" {
                checks.append(contentsOf: contrastChecks(rep))
            }

            // textContrast (v6.1) — scan the REAL surface for low-contrast text the
            // synthetic ContrastProbe (fixed token strips) can't see. Heuristic, so
            // advisory (never gates). Skip the montage (tiny scaled thumbnails read
            // as low-contrast text) + the probe (synthetic, intentionally includes
            // failing bands — the dedicated `contrast` check owns it).
            if name != "contact_sheet" && name != "contrast_probe" {
                let tc = scanTextContrast(rep)
                if tc.cells >= 4 {
                    let extra = tc.low45 > tc.low3 ? ", \(tc.low45) <4.5:1" : ""
                    let detail = tc.low3 == 0
                        ? "worst real-text \(String(format: "%.1f", tc.worst)):1 over \(tc.cells) cells — clear (advisory)"
                        : "worst real-text \(String(format: "%.1f", tc.worst)):1 · \(tc.low3) cell(s) <3:1\(extra) (advisory)"
                    checks.append(.init(name: "textContrast", pass: true, detail: detail))
                }
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
                // tapTargets (v6) — interactive elements too small to click reliably.
                // Only assessable when the live-window AX tree is present (offscreen
                // hosts expose no AX frames), so it skips silently otherwise.
                if !s.axTargets.isEmpty {
                    let tiny = s.axTargets.filter { $0 < 12 }
                    checks.append(.init(name: "tapTargets", pass: tiny.isEmpty,
                                        detail: tiny.isEmpty
                                            ? "\(s.axTargets.count) targets, smallest \(String(format: "%.0f", s.axTargets.min() ?? 0))pt"
                                            : "\(tiny.count) target(s) <12pt — too small to click reliably"))
                }
                // renderTime (v6) — advisory budget; only fails on a pathological hang.
                if s.renderMs > 0 {
                    checks.append(.init(name: "renderTime", pass: s.renderMs < 3000,
                                        detail: "\(s.renderMs) ms\(s.renderMs >= 3000 ? " — render too slow" : "")"))
                }
            }

            // baselineDiff — informational for live surfaces; a FAILURE for
            // deterministic ones that exceed their drift budget.
            var diffPercent: Double? = nil
            let baseURL = baselinesDir.appendingPathComponent(file)
            if let base = bitmap(at: baseURL) {
                let (pct, heat) = diff(rep, base)
                diffPercent = pct
                let diffURL = snapshotsDir.appendingPathComponent("\(name)_diff.png")
                if pct > 0.5, let heat {
                    try? heat.write(to: diffURL)
                } else {
                    // BUG FIX (2026-07-08): a surface that was >0.5% on an earlier
                    // run (e.g. a transient) left its _diff.png behind forever once
                    // it settled back under threshold — qa.sh kept flagging it as
                    // "pixels moved" long after the diff was actually 0.05%. Clear
                    // any stale heat-map the moment this run's pct drops <= 0.5.
                    try? FileManager.default.removeItem(at: diffURL)
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
            try? data.write(to: snapshotsDir.appendingPathComponent("AUDIT.json"), options: .atomic)
        }

        // Trend trail: one JSONL line per audit run (timestamp, fail count,
        // total diff) — cheap history for "when did this start drifting?".
        let totalDiff = results.compactMap(\.diffPercent).reduce(0, +)
        let cvdRisks = (try? Data(contentsOf: snapshotsDir.appendingPathComponent("cvd.json")))
            .flatMap { try? JSONDecoder().decode(QAColorVision.Report.self, from: $0) }?.flagged.count ?? 0
        let histLine = "{\"at\":\"\(report.generatedAt)\",\"failures\":\(failures.count),\"surfaces\":\(results.count),\"totalDiffPct\":\(String(format: "%.2f", totalDiff)),\"cvdRisks\":\(cvdRisks)}\n"
        if let d = histLine.data(using: .utf8) {
            let url = snapshotsDir.deletingLastPathComponent().appendingPathComponent("history.jsonl")
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile(); handle.write(d); try? handle.close()
            } else {
                try? d.write(to: url)
            }
        }

        writeHTMLReport(report, structure: structure, in: snapshotsDir)
    }

    /// One-glance owner dashboard (v6): pass/fail summary, failing-check tally,
    /// total drift, slowest render, color-blind risks, and a fail-history
    /// sparkline — then every surface with severity-coloured checks, its render
    /// time, and current/baseline/diff/deuteranopia images. Pure static HTML.
    private static func writeHTMLReport(_ report: Report, structure: [String: QASurfaceStructure], in dir: URL) {
        // CVD findings (cvd.json is written just before the audit) + run history.
        let cvd = (try? Data(contentsOf: dir.appendingPathComponent("cvd.json")))
            .flatMap { try? JSONDecoder().decode(QAColorVision.Report.self, from: $0) }
        let cvdFail = Set((cvd?.surfaces ?? []).filter { !$0.pass }.map(\.surface))
        let cvdFlagged = cvd?.flagged ?? []
        let hist = Array(loadHistory(dir).suffix(40))

        let totalChecks = report.results.reduce(0) { $0 + $1.checks.count }
        let failChecks  = report.results.reduce(0) { $0 + $1.checks.filter { !$0.pass }.count }
        var failByName: [String: Int] = [:]
        for r in report.results {
            for c in r.checks where !c.pass {
                failByName[String(c.name.split(separator: ":").first ?? ""), default: 0] += 1
            }
        }
        // Exclude inherently-live surfaces (real chat history, the live window) so
        // the number reflects the DETERMINISTIC UI's drift, not conversation churn.
        let totalDrift = report.results
            .filter { !$0.snapshot.hasPrefix("chat_live") && !$0.snapshot.hasSuffix("_live") }
            .compactMap(\.diffPercent).reduce(0, +)
        let slow = structure.max { $0.value.renderMs < $1.value.renderMs }

        let maxFail = max(1, hist.map(\.failures).max() ?? 0)
        let sparks = hist.map { h -> String in
            let ht = Int(Double(h.failures) / Double(maxFail) * 26) + 3
            return "<i class=\"sp\" style=\"height:\(ht)px;background:\(h.failures == 0 ? "#4ca85f" : "#cc4a4a")\" title=\"\(h.at): \(h.failures) fail · \(String(format: "%.1f", h.totalDiffPct))% drift\"></i>"
        }.joined()

        func stat(_ big: String, _ label: String, _ cls: String = "") -> String {
            "<div class=\"stat\"><b class=\"\(cls)\">\(big)</b><span>\(label)</span></div>"
        }

        var html = """
        <!doctype html><meta charset="utf-8"><title>Salehman AI — QA report</title>
        <style>
        body{background:#161616;color:#eee;font:13px -apple-system,system-ui,sans-serif;margin:22px;max-width:1100px}
        h1{font-size:17px;margin:0 0 12px} a{color:#7fb0ff}
        .ok{color:#5dd167}.bad{color:#ff6b5d}.warn{color:#f0a83c}.info{color:#8a8a8a}
        .dash{display:flex;gap:10px;flex-wrap:wrap;margin:10px 0 14px}
        .stat{background:#202020;border:1px solid #333;border-radius:10px;padding:10px 14px;min-width:92px}
        .stat b{display:block;font-size:20px;font-weight:700}.stat span{font-size:11px;color:#999}
        .sparks{display:flex;align-items:flex-end;gap:2px;height:30px}.sp{display:inline-block;width:5px;border-radius:1px}
        .failsum{border-radius:8px;padding:8px 12px;margin:8px 0;font-size:12px}
        .failsum.bad{background:#2a1d1d;border:1px solid #4a3030}.failsum.warn{background:#2a2318;border:1px solid #4a3a20}
        .card{background:#1f1f1f;border:1px solid #333;border-radius:10px;padding:13px;margin:12px 0}
        .card>b{font-size:14px}.rt{color:#888;font-size:11px;margin-left:6px}
        .badge{display:inline-block;font-size:11px;padding:2px 8px;border-radius:8px;background:#2c2c2c;margin:2px 6px 2px 0}
        .badge.bad{background:#3a2020}.badge.warn{background:#332a18}.badge.info{background:#262626;color:#888}
        .imgs{display:flex;gap:10px;flex-wrap:wrap;margin-top:8px}.imgs figure{margin:0}
        .imgs img{max-width:300px;border:1px solid #444;border-radius:6px}
        figcaption{font-size:11px;color:#999;margin-top:3px}small{color:#aaa}
        </style>
        <h1>Salehman AI — QA report · \(report.generatedAt)</h1>
        <div class="dash">
        """
        html += stat(report.failures.isEmpty ? "GREEN" : "\(report.failures.count) ✗",
                     "\(report.results.count) surfaces", report.failures.isEmpty ? "ok" : "bad")
        html += stat("\(totalChecks - failChecks)/\(totalChecks)", "checks pass")
        html += stat(String(format: "%.1f%%", totalDrift), "det. drift")
        html += stat("\(slow?.value.renderMs ?? 0) ms", "slowest · \(slow?.key ?? "—")")
        html += stat("\(cvdFlagged.count)", "color-blind risks", cvdFlagged.isEmpty ? "ok" : "warn")
        html += "<div class=\"stat\"><div class=\"sparks\">\(sparks)</div><span>fail history · \(hist.count) runs</span></div>"
        html += "</div>"

        if !failByName.isEmpty {
            html += "<div class=\"failsum bad\">Failing: " + failByName.sorted { $0.value > $1.value }
                .map { "\($0.key) ×\($0.value)" }.joined(separator: " · ") + "</div>"
        }
        if !cvdFlagged.isEmpty {
            html += "<div class=\"failsum warn\">⬣ Red/green merges on <b>\(cvdFlagged.joined(separator: ", "))</b> — color-blind users can't tell these apart by colour. Previews: <a href=\"cvd_report.html\">cvd_report.html</a></div>"
        }

        // Accessibility rollup (v6.1): consolidate every a11y signal — CVD merges,
        // low-contrast text, unlabeled controls, tiny tap targets — per surface so
        // the real issues are unmissable in one place.
        var a11y: [(String, String)] = []
        for r in report.results {
            var fs: [String] = []
            if cvdFail.contains(r.snapshot) { fs.append("red/green-only") }
            for c in r.checks {
                if c.name == "textContrast", c.detail.contains("<3:1") { fs.append("low-contrast text") }
                if c.name == "axLabels", !c.pass { fs.append("unlabeled control") }
                if c.name == "tapTargets", !c.pass { fs.append("tiny target") }
            }
            if !fs.isEmpty { a11y.append((r.snapshot, fs.joined(separator: ", "))) }
        }
        if !a11y.isEmpty {
            let items = a11y.map { "<b>\($0.0)</b>: \($0.1)" }.joined(separator: " · ")
            html += "<div class=\"failsum warn\">♿ Accessibility findings (advisory) — \(items)</div>"
        }

        for r in report.results {
            let rms = structure[r.snapshot]?.renderMs ?? 0
            let cvdBadge = cvdFail.contains(r.snapshot) ? "<span class=\"badge warn\">⬣ CVD merge</span>" : ""
            html += "<div class=\"card\"><b>\(r.snapshot)</b><span class=\"rt\">\(rms) ms</span> \(cvdBadge)<br>"
            for c in r.checks {
                html += "<span class=\"badge \(severityClass(c))\">\(c.pass ? "✓" : "✗") \(c.name)</span> <small>\(esc(c.detail))</small> "
            }
            html += "<div class=\"imgs\">"
            for (src, cap) in [("\(r.snapshot).png", "current"),
                               ("../baselines/\(r.snapshot).png", "baseline"),
                               ("\(r.snapshot)_diff.png", "diff heat-map"),
                               ("\(r.snapshot)_deuter.png", "deuteranopia")] {
                html += "<figure><img src=\"\(src)\" onerror=\"this.parentElement.style.display='none'\"><figcaption>\(cap)</figcaption></figure>"
            }
            html += "</div></div>"
        }
        try? html.write(to: dir.appendingPathComponent("report.html"), atomically: true, encoding: .utf8)
    }

    private struct Hist: Codable { let at: String; let failures: Int; let totalDiffPct: Double }
    private static func loadHistory(_ dir: URL) -> [Hist] {
        let url = dir.deletingLastPathComponent().appendingPathComponent("history.jsonl")
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let dec = JSONDecoder()
        return s.split(separator: "\n").compactMap { try? dec.decode(Hist.self, from: Data($0.utf8)) }
    }
    /// 3-level severity for display: failing = bad, soft/advisory pass = info, else ok.
    private static func severityClass(_ c: CheckResult) -> String {
        if !c.pass { return "bad" }
        let d = c.detail.lowercased()
        // An advisory textContrast WITH findings still wants a visible (warn) badge.
        if c.name == "textContrast" { return d.contains("<3:1") ? "warn" : "info" }
        return (d.contains("advisory") || d.contains("not assessable") || d.contains("no baseline")) ? "info" : "ok"
    }

    /// Heuristic real-surface text-contrast scan: grid the image into small cells,
    /// and in each cell that looks like TEXT (a thin "ink" minority over a uniform
    /// background) measure the WCAG ratio between the ink and the background. Returns
    /// the worst ratio + how many cells fall below the AA thresholds. Background
    /// median vs the farther extreme = bg vs ink; cells without a clean fg/bg split
    /// (gradients, photos, solid fills, icons) are skipped, keeping it conservative.
    private static func scanTextContrast(_ rep: NSBitmapImageRep) -> (worst: Double, low3: Int, low45: Int, cells: Int) {
        let w = rep.pixelsWide, h = rep.pixelsHigh
        guard w > 48, h > 48 else { return (21, 0, 0, 0) }
        let cw = 32, ch = 16, step = 3
        var worst = 21.0, low3 = 0, low45 = 0, cells = 0
        var cy = 0
        while cy + ch <= h {
            var cx = 0
            while cx + cw <= w {
                var ls: [CGFloat] = []
                var y = cy
                while y < cy + ch {
                    var x = cx
                    while x < cx + cw {
                        if let c = rep.colorAt(x: x, y: y) { ls.append(luma(c)) }
                        x += step
                    }
                    y += step
                }
                cx += cw
                guard ls.count >= 20 else { continue }
                ls.sort()
                let med = ls[ls.count / 2], lo = ls.first!, hi = ls.last!
                let ink = (med - lo) > (hi - med) ? lo : hi          // extreme farther from bg median
                guard abs(ink - med) > 0.12 else { continue }        // real fg/bg separation
                let inkFrac = Double(ls.filter { abs($0 - ink) <= 0.06 }.count) / Double(ls.count)
                let bgFrac  = Double(ls.filter { abs($0 - med) <= 0.06 }.count) / Double(ls.count)
                guard inkFrac >= 0.03, inkFrac <= 0.40, bgFrac >= 0.45 else { continue }  // thin ink / uniform bg = text
                let ratio = Double((max(med, ink) + 0.05) / (min(med, ink) + 0.05))
                cells += 1
                worst = min(worst, ratio)
                if ratio < 3.0 { low3 += 1 }
                if ratio < 4.5 { low45 += 1 }
            }
            cy += ch
        }
        return (cells == 0 ? 21 : worst, low3, low45, cells)
    }
    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
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

    /// Fraction of pixels in the outer left+right edge columns whose luma is OFF
    /// the canvas target — a full-height version of `canvasSampleLuma`'s 4 points,
    /// so a clip/overflow anywhere down the side is caught. Skips the top eighth
    /// (headers/banners legitimately use the panel shade up there).
    private static func edgeDeviation(_ rep: NSBitmapImageRep, target: CGFloat) -> Double {
        let w = rep.pixelsWide, h = rep.pixelsHigh
        guard w > 6, h > 8 else { return 0 }
        let cols = [1, 2, w - 3, w - 2]
        var off = 0, total = 0
        var y = h / 8
        while y < h - 2 {
            for x in cols {
                if let c = rep.colorAt(x: x, y: y) {
                    let l = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
                    total += 1
                    if abs(l - target) > 0.05 { off += 1 }
                }
            }
            y += 2
        }
        return total == 0 ? 0 : Double(off) / Double(total)
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
    ///
    /// `internal` (not `private`) so `QAAuditHeatMapTests` can drive it directly
    /// via `@testable import` and read back the written heat-map bytes — this is
    /// the ONLY caller-visible surface of the pixel-writing logic, so testing it
    /// here (rather than extracting a separate helper) covers the real code path.
    static func diff(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep) -> (Double, Data?) {
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
                // BUG FIX (2026-07-08): NSColor(red:green:blue:alpha:) is the
                // CALIBRATED-RGB initializer. setColor() into this .deviceRGB
                // bitmap silently no-ops a calibrated color on readback (proven:
                // wrote r=1 calibrated red, read back r=0 g=0 b=0 a=0 — fully
                // transparent black). Raw setPixel with an explicit 0-255 byte
                // array writes into the bitmap's actual (device) color space, so
                // it round-trips correctly through PNG encode + readback, and
                // (being simplest) is preferred here over NSColor(deviceRed:...).
                if moved {
                    changed += 1
                    var px: [Int] = [255, 40, 40, 255] // opaque red — legible over the dark UI
                    heat.setPixel(&px, atX: sx, y: sy)
                } else {
                    var px: [Int] = [0, 0, 0, 20] // faint, near-transparent marker
                    heat.setPixel(&px, atX: sx, y: sy)
                }
            }
        }
        let pct = total == 0 ? 0 : Double(changed) / Double(total) * 100
        return (pct, pct > 0.5 ? heat.representation(using: .png, properties: [:]) : nil)
    }
}
