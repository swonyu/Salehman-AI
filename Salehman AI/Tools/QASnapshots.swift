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

    static func captureAll() {
        let dir = qaDir.appendingPathComponent("snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        shots.removeAll()

        // ── Code tab (this session's lane) ──────────────────────────────────
        // CodeView uses HSplitView/VSplitView (AppKit-backed) which ImageRenderer
        // can't draw — so it goes through the NSHostingView path instead.
        snapHosted(CodeView(),     "code_tab",     "Code tab — live (welcome, file tree, composer, collapsed panels)", .init(width: 1180, height: 820), in: dir)
        snap(CodeSampleGallery(),  "code_samples", "Code tab — deterministic states (user block, assistant doc + code, Arabic RTL, streaming, agent strip)", .init(width: 860, height: 1120), in: dir)
        // ── Main chat (other session's lane) ────────────────────────────────
        snap(ContentView(),        "chat_live",    "Main chat — LIVE (owner's real history; gitignored)", .init(width: 1000, height: 780), in: dir)
        snap(ChatSampleGallery(),  "chat_samples", "Main chat — deterministic message/streaming/agent states", .init(width: 820, height: 1240), in: dir)
        // ── Responsive — narrow widths catch layout breaks (centered column, composer wrap) ──
        snap(ContentView(),        "chat_narrow",  "Main chat @ 560pt — responsive / layout-break check", .init(width: 560, height: 760), in: dir)
        snapHosted(CodeView(),     "code_narrow",  "Code tab @ 640pt — responsive / layout-break check", .init(width: 640, height: 760), in: dir)
        // ── Every other tab — flat-canvas restyle spot-check ────────────────
        snap(TodayView(),          "today",        "Today dashboard", .init(width: 1000, height: 740), in: dir)
        snap(AgentsView(),         "agents",       "Agents tab", .init(width: 1000, height: 740), in: dir)
        snap(ScratchpadView(),     "notes",        "Notes / scratchpad", .init(width: 1000, height: 700), in: dir)
        snap(KnowledgeView(),      "knowledge",    "Knowledge tab", .init(width: 1000, height: 700), in: dir)
        snap(MarketsView(),        "markets",      "Markets tab", .init(width: 1000, height: 740), in: dir)
        snap(MemoryView(),         "memory",       "Memory tab", .init(width: 1000, height: 700), in: dir)
        snap(SettingsView(),       "settings",     "Settings sheet", .init(width: 560, height: 640), in: dir)

        writeManifest(in: dir)
        buildContactSheet(in: dir)
        // Keep the simple completion marker too (the other session's watcher reads it).
        let names = shots.map(\.name).sorted()
        let marker = "captured \(shots.filter(\.ok).count)/\(shots.count) snapshots at \(Date())\n"
            + names.joined(separator: "\n") + "\n"
        try? marker.write(to: dir.appendingPathComponent("CAPTURE_DONE.txt"), atomically: true, encoding: .utf8)
    }

    private static func snap<V: View>(_ view: V, _ name: String, _ desc: String, _ size: CGSize, in dir: URL) {
        let start = Date()
        let renderer = ImageRenderer(
            content: view
                .frame(width: size.width, height: size.height)
                .preferredColorScheme(.dark)
                .tint(DS.Palette.accent)
        )
        renderer.scale = 2
        var ok = false
        if let img = renderer.nsImage,
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            ok = (try? png.write(to: dir.appendingPathComponent("\(name).png"))) != nil
        }
        shots.append(Shot(name: name, desc: desc, w: Int(size.width), h: Int(size.height),
                          ok: ok, ms: Int(Date().timeIntervalSince(start) * 1000)))
    }

    /// Render a view that ImageRenderer can't (HSplitView/VSplitView and other
    /// AppKit-backed content) by hosting it offscreen in an NSHostingView and
    /// caching its layer to a bitmap. Heavier than ImageRenderer but it actually
    /// draws split views, so the live Code tab gets a real picture.
    private static func snapHosted<V: View>(_ view: V, _ name: String, _ desc: String, _ size: CGSize, in dir: URL) {
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
        shots.append(Shot(name: name, desc: desc, w: Int(size.width), h: Int(size.height),
                          ok: ok, ms: Int(Date().timeIntervalSince(start) * 1000)))
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
                LazyVStack(spacing: 10) {
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
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
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
