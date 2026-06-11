import SwiftUI
import AppKit

/// **Self-snapshot QA harness** — the app photographs its own surfaces.
///
/// Why: the sandboxed AI session that polishes this UI cannot see the screen
/// (`screencapture` and AppleScript are both blocked there), but it CAN read
/// files in the repo. `ImageRenderer` renders SwiftUI views to PNG entirely
/// in-process — no Screen Recording permission, no window server involvement —
/// so the app can hand that session real pictures of every tab.
///
/// Two triggers:
/// * **File request:** drop a file named `SNAPSHOT_REQUEST` in `<repo>/qa/`,
///   relaunch (or foreground) the app → snapshots appear in
///   `<repo>/qa/snapshots/*.png` and the request file is consumed. This lets
///   a headless session request pictures and a normal launch fulfill them.
/// * **Menu:** View ▸ “Capture QA Snapshots” runs the same capture on demand.
///
/// Determinism: alongside the LIVE views (whatever state the stores hold),
/// `ChatSampleGallery` renders a fixed set of message/composer states so
/// before/after comparisons don't depend on the owner's real chat history.
///
/// Limits (by design): `ImageRenderer` draws static view trees — no hover,
/// focus, or sheet states. Those stay covered by the UI-test flows; this
/// harness is for LAYOUT/STYLE eyes.
@MainActor
enum QASnapshots {

    /// Repo root: this is a personal app pinned to the owner's machine layout
    /// (same assumption the training scripts make). Overridable for safety.
    private static var qaDir: URL {
        if let custom = ProcessInfo.processInfo.environment["QA_SNAPSHOT_DIR"] {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/Salehman AI/qa", isDirectory: true)
    }

    /// Launch hook: capture if `qa/SNAPSHOT_REQUEST` is present. The request
    /// file is consumed AFTER a successful capture — a launch that quits
    /// mid-render (e.g. a quick UI-test run) leaves the request in place so
    /// the NEXT launch retries instead of silently eating it. Small delay
    /// lets the singleton stores finish their first load.
    static func checkAndRun() {
        // Baseline adoption trigger (QAAudit): promote the CURRENT snapshots
        // to qa/baselines so future captures diff against them.
        let adopt = qaDir.appendingPathComponent("ADOPT_BASELINES")
        if FileManager.default.fileExists(atPath: adopt.path) {
            QAAudit.adoptBaselinesDefault()
            try? FileManager.default.removeItem(at: adopt)
        }
        let request = qaDir.appendingPathComponent("SNAPSHOT_REQUEST")
        guard FileManager.default.fileExists(atPath: request.path) else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            captureAll()
            try? FileManager.default.removeItem(at: request)
        }
    }

    /// Render every main surface + the deterministic chat gallery, then write
    /// a `CAPTURE_DONE.txt` marker (timestamp + file list) so a remote session
    /// can verify completion without listing PNGs.
    /// One captured surface, recorded for the manifest + contact sheet.
    private struct Shot { let name: String; let desc: String; let w: Int; let h: Int; let ok: Bool; let ms: Int }
    private static var shots: [Shot] = []

    /// Structural results (layout geometry + accessibility tree) per surface —
    /// written to STRUCTURE.json for `QAAudit` to fold into the verdict.
    private static var structure: [String: QASurfaceStructure] = [:]

    static func captureAll() {
        let dir = qaDir.appendingPathComponent("snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        shots.removeAll()
        structure.removeAll()
        QAGeometry.enabled = true
        defer { QAGeometry.enabled = false }

        // ── Code tab ─────────────────────────────────────────────────────────
        snap(CodeView(),           "code_tab",     "Code tab — live (welcome, file tree, composer, collapsed panels)", .init(width: 1180, height: 820), in: dir)
        snap(CodeSampleGallery(),  "code_samples", "Code tab — deterministic states (blocks, code, table, Arabic RTL, streaming, agent strip, refusal)", .init(width: 860, height: 1560), in: dir)
        // ── Main chat ────────────────────────────────────────────────────────
        // The chat renders also feed the GEOMETRY probe: ContentView reports
        // its reading-column + composer frames, and the audit asserts the
        // 780pt-centered invariants at both widths.
        QAGeometry.reset()
        snap(ContentView(),        "chat_live",    "Main chat — LIVE (owner's real history; gitignored)", .init(width: 1000, height: 780), in: dir)
        structure["chat_live", default: .init()].geo = QAGeometry.chatAssertions(rootWidth: 1000)
        snap(ContentView(qaForceEmptyState: true),
                                   "chat_empty",   "Main chat — first-impression welcome (QA-forced empty state)", .init(width: 1000, height: 780), in: dir)
        snap(ChatSampleGallery(),  "chat_samples", "Main chat — deterministic message/streaming/agent/hover/approval states", .init(width: 820, height: 1780), in: dir)
        // ── Responsive — narrow widths catch layout breaks (centered column, composer wrap) ──
        QAGeometry.reset()
        snap(ContentView(),        "chat_narrow",  "Main chat @ 560pt — responsive / layout-break check", .init(width: 560, height: 760), in: dir)
        structure["chat_narrow", default: .init()].geo = QAGeometry.chatAssertions(rootWidth: 560)
        snap(CodeView(),           "code_narrow",  "Code tab @ 640pt — responsive / layout-break check", .init(width: 640, height: 760), in: dir)
        // ── Every other tab — flat-canvas restyle spot-check ────────────────
        snap(TodayView(),          "today",        "Today dashboard", .init(width: 1000, height: 740), in: dir)
        snap(AgentsView(),         "agents",       "Agents tab", .init(width: 1000, height: 740), in: dir)
        snap(ScratchpadView(),     "notes",        "Notes / scratchpad", .init(width: 1000, height: 700), in: dir)
        snap(KnowledgeView(),      "knowledge",    "Knowledge tab", .init(width: 1000, height: 700), in: dir)
        snap(MarketsView(),        "markets",      "Markets tab", .init(width: 1000, height: 740), in: dir)
        // Memory is a SHEET (round-1 audit caught it floating in a 1000×700
        // frame with uncomposited margins) — capture at its natural sheet size.
        snap(MemoryView(),         "memory",       "Memory sheet", .init(width: 500, height: 620), in: dir)
        snap(SettingsView(),       "settings",     "Settings sheet", .init(width: 560, height: 640), in: dir)
        // ── Readability probe — every text-style/surface pairing the design
        // language uses, in fixed bands the audit measures for CONTRAST (the
        // invisible-code-text class of bug, caught by eyes in round 1, is now
        // caught by arithmetic every capture).
        snap(ContrastProbe(),      "contrast_probe", "Readability probe — text/surface contrast bands (audited vs WCAG-style ratios)", .init(width: 600, height: CGFloat(ContrastProbe.bands.count) * ContrastProbe.bandHeight), in: dir)
        // ── QA v6 (Chat C): previously-uncaptured sheets ─────────────────────
        snap(OnboardingView(onDone: {}),  "onboarding",      "Onboarding — first-run welcome (page 1)", .init(width: 540, height: 600), in: dir)
        snap(AboutView(onClose: {}),      "about",           "About sheet — identity + capabilities", .init(width: 460, height: 560), in: dir)
        snap(ShortcutsView(onClose: {}),  "shortcuts",       "Keyboard-shortcuts cheat sheet (⌘/)", .init(width: 380, height: 470), in: dir)
        snap(CommandPalette(onClose: {}), "command_palette", "Command palette (⌘K)", .init(width: 560, height: 520), in: dir)
        // VoiceModeView is intentionally NOT captured: its .onAppear runs
        // session.start() (the mic) — an offscreen QA render must not trigger it.
        // ── Responsive: narrow widths catch layout breaks on the flexible tabs ──
        snap(TodayView(),     "today_narrow",     "Today @ 560pt — responsive / layout-break check", .init(width: 560, height: 760), in: dir)
        snap(MarketsView(),   "markets_narrow",   "Markets @ 560pt — responsive / layout-break check", .init(width: 560, height: 760), in: dir)
        snap(KnowledgeView(), "knowledge_narrow", "Knowledge @ 560pt — responsive / layout-break check", .init(width: 560, height: 760), in: dir)

        // Bridge layout + accessibility findings to the audit. MERGE, don't
        // overwrite: `captureLiveWindows` contributes window_* entries (the
        // only place AX trees are real), and a fresh offscreen capture was
        // clobbering them (caught when window_0_live lost its axLabels check).
        let url = dir.appendingPathComponent("STRUCTURE.json")
        var merged: [String: QASurfaceStructure] =
            (try? Data(contentsOf: url))
                .flatMap { try? JSONDecoder().decode([String: QASurfaceStructure].self, from: $0) } ?? [:]
        merged = merged.filter { $0.key.hasPrefix("window_") }   // keep only live-window entries
        for (k, v) in structure { merged[k] = v }
        if let data = try? JSONEncoder().encode(merged) {
            try? data.write(to: url)
        }

        writeManifest(in: dir)
        buildContactSheet(in: dir)
        // Keep the simple completion marker too (the other session's watcher reads it).
        let names = shots.map(\.name).sorted()
        let marker = "captured \(shots.filter(\.ok).count)/\(shots.count) snapshots at \(Date())\n"
            + names.joined(separator: "\n") + "\n"
        try? marker.write(to: dir.appendingPathComponent("CAPTURE_DONE.txt"), atomically: true, encoding: .utf8)

        // Self-judge the pictures: AUDIT.json (nonBlank / canvasFlat / baseline
        // diff + heat-maps). The UI-test gate asserts failures == [].
        QAAudit.run(snapshotsDir: dir,
                    baselinesDir: qaDir.appendingPathComponent("baselines"))

        // Color-vision pass (Chat C, QA v6): deuteranopia/protanopia previews +
        // red-green "merge" detection over each surface's vivid colors.
        QAColorVision.run(snapshotsDir: dir)
    }

    /// ONE render path: host the view offscreen in an `NSHostingView` and cache
    /// its layer to a bitmap. Round-1 evidence (see qa history): plain
    /// `ImageRenderer` silently produced blank/placeholder PNGs for everything
    /// wrapping AppKit or lazy/scroll containers — Settings was a flat panel,
    /// Today pure white, the live transcript empty, TextField/Menu drew yellow
    /// "unsupported" boxes. Hosting gives every view a real AppKit context, so
    /// scroll views populate and controls draw. Slightly heavier per shot;
    /// correctness wins.
    private static func snap<V: View>(_ view: V, _ name: String, _ desc: String, _ size: CGSize, in dir: URL) {
        let start = Date()
        let host = NSHostingView(rootView:
            view.frame(width: size.width, height: size.height)
                .preferredColorScheme(.dark)
                .tint(DS.Palette.accent)
        )
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        var ok = false
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            rep.size = host.bounds.size
            host.cacheDisplay(in: host.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                ok = (try? png.write(to: dir.appendingPathComponent("\(name).png"))) != nil
            }
        }
        // Accessibility sweep on the laid-out tree: count interactive elements
        // and collect the UNLABELED ones (icon-only buttons that lost their
        // .accessibilityLabel/.help — the audit fails on any).
        let ax = axScan(host)
        structure[name, default: .init()].axInteractive = ax.interactive
        structure[name, default: .init()].axUnlabeled = ax.unlabeled
        shots.append(Shot(name: name, desc: desc, w: Int(size.width), h: Int(size.height),
                          ok: ok, ms: Int(Date().timeIntervalSince(start) * 1000)))
    }

    /// Recursive accessibility-tree walk. Interactive roles must carry a label,
    /// title, or help text — VoiceOver users get nothing otherwise.
    static func axScan(_ root: NSView) -> (interactive: Int, unlabeled: [String]) {
        var interactive = 0
        var unlabeled: [String] = []
        let interactiveRoles: Set<NSAccessibility.Role> = [
            .button, .popUpButton, .menuButton, .checkBox, .radioButton, .slider, .link,
        ]
        func walk(_ node: Any, depth: Int) {
            guard depth < 60 else { return }
            guard let ax = node as? any NSAccessibilityProtocol else { return }
            if let role = ax.accessibilityRole(), interactiveRoles.contains(role) {
                interactive += 1
                let label = (ax.accessibilityLabel() ?? "").trimmingCharacters(in: .whitespaces)
                let title = (ax.accessibilityTitle() ?? "").trimmingCharacters(in: .whitespaces)
                let help = (ax.accessibilityHelp() ?? "").trimmingCharacters(in: .whitespaces)
                if label.isEmpty && title.isEmpty && help.isEmpty {
                    unlabeled.append(role.rawValue)
                }
            }
            for child in ax.accessibilityChildren() ?? [] { walk(child, depth: depth + 1) }
        }
        walk(root, depth: 0)
        return (interactive, unlabeled)
    }

    /// Markdown manifest: what each PNG shows, its size, render status + time, the
    /// commit it was captured at — so the blind session reading the PNGs has full context.
    private static func writeManifest(in dir: URL) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")          // force Gregorian (owner's locale renders Hijri)
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let okN = shots.filter(\.ok).count
        var md = """
        # QA snapshots — Salehman AI
        **\(f.string(from: Date()))** · commit `\(gitHead())` · **\(okN)/\(shots.count)** surfaces OK · \
        see `contact_sheet.png` for a one-glance montage.

        In-process `ImageRenderer` captures (no Screen-Recording permission). Static layout/style only —
        hover/focus/sheet states stay on the manual checklist. Re-capture: View ▸ Capture QA Snapshots,
        or `touch qa/SNAPSHOT_REQUEST` and launch.

        | file | shows | size | status | render |
        |---|---|---|---|---|

        """
        for s in shots {
            md += "| `\(s.name).png` | \(s.desc) | \(s.w)×\(s.h) | \(s.ok ? "✅" : "❌ FAILED") | \(s.ms) ms |\n"
        }
        try? md.write(to: dir.appendingPathComponent("INDEX.md"), atomically: true, encoding: .utf8)
    }

    /// Montage of every captured surface (thumbnail + label) into one PNG — lets the
    /// remote session eyeball the WHOLE app in a single image before drilling in.
    private static func buildContactSheet(in dir: URL) {
        let cols = 4
        let thumbs: [(String, NSImage)] = shots.filter(\.ok).compactMap { s in
            NSImage(contentsOf: dir.appendingPathComponent("\(s.name).png")).map { (s.name, $0) }
        }
        guard !thumbs.isEmpty else { return }
        let rows = stride(from: 0, to: thumbs.count, by: cols).map { Array(thumbs[$0..<min($0+cols, thumbs.count)]) }
        let sheet = VStack(alignment: .leading, spacing: 14) {
            Text("Salehman AI — QA contact sheet").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 5) {
                            Image(nsImage: item.1).resizable().aspectRatio(contentMode: .fit)
                                .frame(width: 250, height: 170)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.12)))
                            Text(item.0).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        .frame(width: 250)
                    }
                }
            }
        }
        .padding(20).background(DS.Palette.codeSurfaceSide)
        let r = ImageRenderer(content: sheet.frame(width: CGFloat(cols) * 264 + 40).fixedSize()
            .preferredColorScheme(.dark).tint(DS.Palette.accent))
        r.scale = 1.5
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("contact_sheet.png"))
        }
    }

    /// Best-effort short git SHA (reads `.git` directly, no shell-out).
    private static func gitHead() -> String {
        let g = qaDir.deletingLastPathComponent().appendingPathComponent(".git")
        guard let head = try? String(contentsOf: g.appendingPathComponent("HEAD"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return "unknown" }
        guard head.hasPrefix("ref: ") else { return String(head.prefix(8)) }
        let ref = String(head.dropFirst(5))
        if let sha = try? String(contentsOf: g.appendingPathComponent(ref), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) { return String(sha.prefix(8)) }
        if let packed = try? String(contentsOf: g.appendingPathComponent("packed-refs"), encoding: .utf8) {
            for l in packed.split(separator: "\n") where l.hasSuffix(ref) { return String(l.prefix(8)) }
        }
        return "ref:" + (ref.split(separator: "/").last.map(String.init) ?? "?")
    }
}

/// Deterministic chat states for stable before/after comparison: a short user
/// block, a long user paste (wrap-measure check), an assistant markdown
/// document, a follow-up burst, the streaming row, the typing dots, and the
/// agent strip — everything the heavy-polish passes touched.
/// Fixed contrast bands: each row is one text-style/surface pairing at a known
/// fractional y-position, so `QAAudit` can measure glyph-vs-background contrast
/// without OCR — band i's center line sits at (i + 0.5) / bands.count of the
/// image height. Order here MUST match `QAAudit.contrastBands`.
struct ContrastProbe: View {
    static let bandHeight: CGFloat = 56

    /// (label, text style, foreground, background, minimum contrast, enforced).
    /// `enforced=false` = advisory: measured + reported in AUDIT.json/report
    /// but doesn't fail the gate — used while a fix needs the other session's
    /// lane. MainActor like the DS tokens it reads; both consumers
    /// (`captureAll`, `QAAudit.contrastChecks`) are MainActor too.
    static var bands: [(String, CGFloat, Color, Color, Double, Bool)] {
        [
            ("body on canvas",        14,   Color.white.opacity(0.92),      DS.Palette.codeSurface,     4.5, true),
            ("secondary on canvas",   11,   DS.Palette.textSecondary,       DS.Palette.codeSurface,     3.0, true),
            ("body on panel",         14,   Color.white.opacity(0.92),      DS.Palette.codeSurfaceSide, 4.5, true),
            ("secondary on panel",    11,   DS.Palette.textSecondary,       DS.Palette.codeSurfaceSide, 3.0, true),
            ("body on user block",    13.5, .white,                         Color(white: 0.125 + 0.09), 4.5, true),
            ("white on accent (send)", 13,  .white,                         DS.Palette.accent,          3.0, true),
            // v4's first run flagged this at 2.21:1 — root cause was the AUDIT
            // computing luma in gamma space; with proper sRGB linearization the
            // true ratio is ≈4.3:1. Enforced with correct math. (The advisory
            // flag stays available for genuine cross-lane waits.)
            ("accent on canvas",      13,   DS.Palette.accent,              DS.Palette.codeSurface,     3.0, true),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.bands.enumerated()), id: \.offset) { _, band in
                ZStack {
                    band.3
                    // Heavy glyph coverage across the scan line → the sampler
                    // reliably hits glyph cores despite anti-aliasing.
                    Text("HHHH \(band.0) — 0123 السلام HHHH")
                        .font(.system(size: band.1, weight: .medium))
                        .foregroundStyle(band.2)
                        .lineLimit(1)
                }
                .frame(height: Self.bandHeight)
            }
        }
    }
}

private struct ChatSampleGallery: View {
    private let now = Date(timeIntervalSince1970: 1_781_200_000)   // fixed clock

    private var samples: [ChatMessage] {
        [
            ChatMessage(id: UUID(), text: "hi", isUser: true, timestamp: now),
            ChatMessage(id: UUID(),
                        text: "Hello Saleh — ready when you are. What should we work on?",
                        isUser: false, timestamp: now.addingTimeInterval(4)),
            ChatMessage(id: UUID(),
                        text: "Summarize this long requirements paragraph I pasted so we can sanity-check the user block's 480pt wrap measure, padding, and corner radius against the design language.",
                        isUser: true, timestamp: now.addingTimeInterval(60)),
            ChatMessage(id: UUID(),
                        text: """
                        Here's the summary:

                        **Key points**
                        - The composer uses the Claude text-over-controls layout
                        - Assistant replies are flush-left *documents* — no bubbles
                        - Hover actions float on a panel pill

                        ```swift
                        let rhythm = (burst: 10, speakers: 24)
                        ```

                        Want me to apply this to the remaining views?
                        """,
                        isUser: false, timestamp: now.addingTimeInterval(75)),
            ChatMessage(id: UUID(), text: "yes — and keep the motion subtle.",
                        isUser: true, timestamp: now.addingTimeInterval(95)),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            gallerySection("Messages — rhythm, blocks, document flow") {
                // Plain VStack on purpose: round-1 evidence showed a Lazy stack
                // misplacing a sample row below later sections in static renders.
                VStack(spacing: 10) {
                    ForEach(samples) { msg in MessageBubble(message: msg) }
                }
            }
            gallerySection("Streaming row — dot above, leading edge final") {
                StreamingBubble(text: "Streaming a reply right now — the text's left edge must already be at its committed position…")
            }
            gallerySection("Typing dots — pre-stream") {
                TypingIndicator()
            }
            gallerySection("Agent strip — flat panel, live counter, tool round note") {
                AgentRunView(steps: [
                    .init(name: "Reasoning Strategist", icon: "brain.head.profile",
                          status: .running, adapted: "Reasoning Strategist · tool round 3/8"),
                    .init(name: "Final Output Quality Owner", icon: "checkmark.seal.fill",
                          status: .pending),
                ])
            }
            // States a static render can't reach naturally — forced visible so
            // they get eyes + baseline protection like everything else.
            gallerySection("Hover state — floating action pill + reply timing (QA-forced)") {
                MessageBubble(message: ChatMessage(id: UUID(),
                                                   text: "Hover actions float on a panel pill — timing, speak, copy, regenerate — without reserving layout.",
                                                   isUser: false,
                                                   timestamp: now.addingTimeInterval(120),
                                                   duration: 4.2),
                              onRegenerate: { _ in },
                              qaShowActions: true)
                    .padding(.top, 14)   // room for the pill's -4 offset above the row
            }
            gallerySection("Time separator — burst boundary") {
                TimeSeparator(date: now)
            }
            gallerySection("Approval card — the command gate") {
                ApprovalCard(command: "ls -la ~/Desktop", onRun: {}, onCancel: {}, onAlways: {})
                    .frame(height: 300)
                    .clipped()
            }
            gallerySection("Scroll-to-latest — solid accent pill") {
                ScrollToLatestButton(unreadCount: 3) {}
            }
        }
        .padding(28)
        // Pin to the TOP of the fixed snapshot frame — round 1 centered the
        // content vertically, wasting a third of the picture as dead space.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.Palette.codeSurface)
    }

    private func gallerySection<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold)).tracking(1.2)
                .foregroundStyle(DS.Palette.textSecondary)
            content()
        }
    }
}
