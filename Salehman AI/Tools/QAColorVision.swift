import AppKit

/// **Color-vision QA (CVD)** — the pixel/contrast checks verify text *legibility*,
/// but say nothing about whether the app's *semantic colors* survive color
/// blindness. Salehman leans on red/green a lot (Markets buy/sell badges, the
/// success/danger tokens, status dots), and red-green deficiency is the most
/// common form (~8% of men). This pass:
///
///  1. Simulates **deuteranopia** + **protanopia** on every captured surface
///     (Machado et al. 2009 matrices, applied in LINEAR RGB) → `<name>_deuter.png`
///     / `<name>_protan.png` previews to eyeball.
///  2. Extracts each surface's vivid colors and **flags any originally-distinct
///     pair that collapses to look the same** under simulation — e.g. a green
///     "Strong Buy" pill and a red "Sell" pill becoming indistinguishable. That's
///     the actual failure mode, caught by arithmetic, not just a preview.
///
/// Writes `qa/snapshots/cvd.json` (machine) + `cvd_report.html` (human). Advisory
/// by design — it does NOT gate the build (a flagged merge wants a human call on
/// whether an icon/label already disambiguates), but `merges` is there to promote
/// to the gate later. Run from `QASnapshots.captureAll` after the audit.
@MainActor
enum QAColorVision {

    // Machado et al. (2009), severity 1.0 — applied to LINEARIZED sRGB.
    private static let deuteranopia: [[Double]] = [
        [0.367322, 0.860646, -0.227968],
        [0.280085, 0.672501,  0.047413],
        [-0.011820, 0.042940, 0.968881],
    ]
    private static let protanopia: [[Double]] = [
        [0.152286, 1.052583, -0.204868],
        [0.114503, 0.786281,  0.099216],
        [-0.003882, -0.048116, 1.051998],
    ]

    struct Merge: Codable { let a: String; let b: String; let origDist: Int; let cvdDist: Int; let type: String }
    struct SurfaceCVD: Codable { let surface: String; let vivid: [String]; let merges: [Merge]; let pass: Bool }
    struct Report: Codable { let generatedAt: String; let surfaces: [SurfaceCVD]; let flagged: [String] }

    static func run(snapshotsDir dir: URL) {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
            .filter { $0.hasSuffix(".png") }
            .filter { n in !["_diff.png", "_deuter.png", "_protan.png"].contains(where: n.hasSuffix)
                          && n != "contact_sheet.png" }
            .sorted()

        var surfaces: [SurfaceCVD] = []
        var flagged: [String] = []

        for file in names {
            let name = String(file.dropLast(4))
            guard let src = canonical(at: dir.appendingPathComponent(file), maxDim: 520) else { continue }

            // Previews (write the simulated images next to the originals).
            if let d = simulate(src, deuteranopia) { try? png(d)?.write(to: dir.appendingPathComponent("\(name)_deuter.png")) }
            if let p = simulate(src, protanopia)  { try? png(p)?.write(to: dir.appendingPathComponent("\(name)_protan.png")) }

            // Merge check on the surface's vivid colors (deuteranopia — the common case).
            let vivid = vividColors(src, topK: 6)
            var merges: [Merge] = []
            for i in 0..<vivid.count {
                for j in (i + 1)..<vivid.count {
                    let (ca, cb) = (vivid[i], vivid[j])
                    let orig = redmean(ca, cb)
                    guard orig >= 120 else { continue }                 // originally clearly distinct
                    let (sa, sb) = (simColor(ca, deuteranopia), simColor(cb, deuteranopia))
                    let cvd = redmean(sa, sb)
                    if cvd <= 45 {
                        // Indistinguishable under deuteranopia (hue AND brightness collapse).
                        merges.append(.init(a: hex(ca), b: hex(cb), origDist: Int(orig),
                                            cvdDist: Int(cvd), type: "deuteranopia · indistinguishable"))
                    } else if hueDiff(ca, cb) >= 45, hueDiff(sa, sb) <= 12 {
                        // Same HUE under deuteranopia — the colors now differ ONLY in
                        // brightness, i.e. meaning is carried by hue alone (fragile:
                        // Markets buy=green/sell=red is the canonical case). Advisory.
                        merges.append(.init(a: hex(ca), b: hex(cb), origDist: Int(orig),
                                            cvdDist: Int(cvd), type: "deuteranopia · hue collapses (relies on brightness only)"))
                    }
                }
            }
            let pass = merges.isEmpty
            if !pass { flagged.append(name) }
            surfaces.append(.init(surface: name, vivid: vivid.map(hex), merges: merges, pass: pass))
        }

        let report = Report(generatedAt: ISO8601DateFormatter().string(from: Date()),
                            surfaces: surfaces, flagged: flagged.sorted())
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(report) { try? data.write(to: dir.appendingPathComponent("cvd.json")) }
        writeHTML(report, in: dir)
    }

    // MARK: - Simulation

    /// Apply a CVD matrix in linear-RGB space to every pixel of a copy.
    private static func simulate(_ src: NSBitmapImageRep, _ m: [[Double]]) -> NSBitmapImageRep? {
        guard let out = src.copy() as? NSBitmapImageRep, let px = out.bitmapData else { return nil }
        let w = out.pixelsWide, h = out.pixelsHigh, spp = out.samplesPerPixel, row = out.bytesPerRow
        guard spp >= 3 else { return nil }
        for y in 0..<h {
            for x in 0..<w {
                let o = y * row + x * spp
                let r = lin(Double(px[o]) / 255), g = lin(Double(px[o + 1]) / 255), b = lin(Double(px[o + 2]) / 255)
                px[o]     = enc8(m[0][0] * r + m[0][1] * g + m[0][2] * b)
                px[o + 1] = enc8(m[1][0] * r + m[1][1] * g + m[1][2] * b)
                px[o + 2] = enc8(m[2][0] * r + m[2][1] * g + m[2][2] * b)
            }
        }
        return out
    }

    /// Simulate a single sRGB color (0–255 components) through a CVD matrix.
    private static func simColor(_ c: (Int, Int, Int), _ m: [[Double]]) -> (Int, Int, Int) {
        let r = lin(Double(c.0) / 255), g = lin(Double(c.1) / 255), b = lin(Double(c.2) / 255)
        return (Int(enc8(m[0][0] * r + m[0][1] * g + m[0][2] * b)),
                Int(enc8(m[1][0] * r + m[1][1] * g + m[1][2] * b)),
                Int(enc8(m[2][0] * r + m[2][1] * g + m[2][2] * b)))
    }

    // MARK: - Vivid-color extraction

    /// Top-K most frequent *saturated* colors (coarsely quantized), ignoring the
    /// near-grey UI chrome that dominates by area.
    private static func vividColors(_ rep: NSBitmapImageRep, topK: Int) -> [(Int, Int, Int)] {
        guard let px = rep.bitmapData else { return [] }
        let w = rep.pixelsWide, h = rep.pixelsHigh, spp = rep.samplesPerPixel, row = rep.bytesPerRow
        guard spp >= 3 else { return [] }
        // Group into coarse buckets, but accumulate the REAL pixel values so we
        // return each cluster's true average color — not a lossy bucket center.
        var acc: [Int: (n: Int, r: Int, g: Int, b: Int)] = [:]
        let step = max(1, min(w, h) / 200)
        var y = 0
        while y < h {
            var x = 0
            while x < w {
                let o = y * row + x * spp
                let r = Int(px[o]), g = Int(px[o + 1]), b = Int(px[o + 2])
                let mx = max(r, g, b), mn = min(r, g, b)
                // saturated, not too dark/blown-out → a real semantic color
                if mx > 50, mx < 245, mx - mn > 70 {
                    let key = ((r >> 5) << 10) | ((g >> 5) << 5) | (b >> 5)   // 8³ coarse buckets
                    let a = acc[key] ?? (0, 0, 0, 0)
                    acc[key] = (a.n + 1, a.r + r, a.g + g, a.b + b)
                }
                x += step
            }
            y += step
        }
        return acc.sorted { $0.value.n > $1.value.n }.prefix(topK).map { _, a in
            (a.r / a.n, a.g / a.n, a.b / a.n)
        }
    }

    // MARK: - Helpers

    private static func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    private static func enc8(_ v: Double) -> UInt8 {
        let c = max(0, min(1, v))
        let s = c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
        return UInt8(max(0, min(255, (s * 255).rounded())))
    }
    /// Perceptual-ish color distance (Thiadmer Riemersma "redmean"), 0…~765.
    private static func redmean(_ a: (Int, Int, Int), _ b: (Int, Int, Int)) -> Double {
        let rm = Double(a.0 + b.0) / 2
        let dr = Double(a.0 - b.0), dg = Double(a.1 - b.1), db = Double(a.2 - b.2)
        return (((2 + rm / 256) * dr * dr) + 4 * dg * dg + ((2 + (255 - rm) / 256) * db * db)).squareRoot()
    }
    /// HSV hue in degrees (0–360); grey returns 0.
    private static func hue(_ c: (Int, Int, Int)) -> Double {
        let r = Double(c.0) / 255, g = Double(c.1) / 255, b = Double(c.2) / 255
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        guard d > 0.001 else { return 0 }
        var h: Double = (mx == r) ? (g - b) / d : (mx == g) ? 2 + (b - r) / d : 4 + (r - g) / d
        h *= 60; if h < 0 { h += 360 }
        return h
    }
    /// Smallest circular distance between two hues (0–180°).
    private static func hueDiff(_ a: (Int, Int, Int), _ b: (Int, Int, Int)) -> Double {
        let d = abs(hue(a) - hue(b)).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }
    private static func hex(_ c: (Int, Int, Int)) -> String { String(format: "#%02X%02X%02X", c.0, c.1, c.2) }
    private static func png(_ rep: NSBitmapImageRep) -> Data? { rep.representation(using: .png, properties: [:]) }

    /// Load a PNG and redraw it into a canonical 8-bit RGBA bitmap (so
    /// `bitmapData` has a known layout), optionally downscaled for speed.
    private static func canonical(at url: URL, maxDim: Int) -> NSBitmapImageRep? {
        guard let data = try? Data(contentsOf: url), let src = NSBitmapImageRep(data: data) else { return nil }
        let longest = max(src.pixelsWide, src.pixelsHigh)
        let scale = min(1.0, Double(maxDim) / Double(max(1, longest)))
        let w = max(1, Int(Double(src.pixelsWide) * scale)), h = max(1, Int(Double(src.pixelsHigh) * scale))
        guard let dst = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: dst)
        src.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        return dst
    }

    private static func writeHTML(_ report: Report, in dir: URL) {
        var html = """
        <!doctype html><meta charset="utf-8"><title>Salehman AI — color-vision QA</title>
        <style>
        body{background:#1b1b1b;color:#eee;font:14px -apple-system,sans-serif;margin:24px}
        h1{font-size:18px}.ok{color:#5dd167}.bad{color:#ff7b5d}
        .card{background:#252525;border:1px solid #3a3a3a;border-radius:10px;padding:14px;margin:14px 0}
        .imgs{display:flex;gap:10px;flex-wrap:wrap}.imgs figure{margin:0}
        .imgs img{max-width:300px;border:1px solid #444;border-radius:6px}
        figcaption{font-size:11px;color:#999;margin-top:4px}
        .sw{display:inline-block;width:14px;height:14px;border-radius:3px;border:1px solid #555;vertical-align:middle;margin:0 2px}
        .merge{color:#ff7b5d;font-size:12px}
        </style>
        <h1>Color-vision QA — \(report.generatedAt) ·
        <span class="\(report.flagged.isEmpty ? "ok" : "bad")">\(report.flagged.isEmpty ? "no red/green merges detected" : "\(report.flagged.count) surface(s) with a merge: \(report.flagged.joined(separator: ", "))")</span></h1>
        <p style="color:#999;font-size:12px">Each row: original · deuteranopia · protanopia. A "merge" = two
        normally-distinct colors that look the same to a red-green-deficient viewer (verify an icon/label
        disambiguates).</p>
        """
        for s in report.surfaces {
            html += "<div class=\"card\"><b>\(s.surface)</b> <span class=\"\(s.pass ? "ok" : "bad")\">\(s.pass ? "✓" : "✗ merge")</span><br>"
            html += "<small>vivid: " + s.vivid.map { "<span class=\"sw\" style=\"background:\($0)\"></span>\($0)" }.joined(separator: " ") + "</small>"
            for m in s.merges {
                html += "<div class=\"merge\">⚠︎ <span class=\"sw\" style=\"background:\(m.a)\"></span>\(m.a) &amp; <span class=\"sw\" style=\"background:\(m.b)\"></span>\(m.b) merge under \(m.type) (orig Δ\(m.origDist) → Δ\(m.cvdDist))</div>"
            }
            html += "<div class=\"imgs\">"
            html += "<figure><img src=\"\(s.surface).png\"><figcaption>original</figcaption></figure>"
            html += "<figure><img src=\"\(s.surface)_deuter.png\" onerror=\"this.parentElement.style.display='none'\"><figcaption>deuteranopia</figcaption></figure>"
            html += "<figure><img src=\"\(s.surface)_protan.png\" onerror=\"this.parentElement.style.display='none'\"><figcaption>protanopia</figcaption></figure>"
            html += "</div></div>"
        }
        try? html.write(to: dir.appendingPathComponent("cvd_report.html"), atomically: true, encoding: .utf8)
    }
}
