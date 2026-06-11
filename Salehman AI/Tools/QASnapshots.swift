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

    /// Launch hook: consume `qa/SNAPSHOT_REQUEST` if present, then capture.
    /// Small delay lets the singleton stores finish their first load so the
    /// live views render real content instead of empty flashes.
    static func checkAndRun() {
        let request = qaDir.appendingPathComponent("SNAPSHOT_REQUEST")
        guard FileManager.default.fileExists(atPath: request.path) else { return }
        try? FileManager.default.removeItem(at: request)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            captureAll()
        }
    }

    /// Render every main surface + the deterministic chat gallery.
    static func captureAll() {
        let dir = qaDir.appendingPathComponent("snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        snap(TodayView(),          "today",         CGSize(width: 1000, height: 740), in: dir)
        snap(ContentView(),        "chat_live",     CGSize(width: 1000, height: 780), in: dir)
        snap(ChatSampleGallery(),  "chat_samples",  CGSize(width: 820,  height: 1240), in: dir)
        snap(AgentsView(),         "agents",        CGSize(width: 1000, height: 740), in: dir)
        snap(ScratchpadView(),     "notes",         CGSize(width: 1000, height: 700), in: dir)
        snap(KnowledgeView(),      "knowledge",     CGSize(width: 1000, height: 700), in: dir)
        snap(MarketsView(),        "markets",       CGSize(width: 1000, height: 740), in: dir)
        snap(MemoryView(),         "memory",        CGSize(width: 1000, height: 700), in: dir)
        snap(SettingsView(),       "settings",      CGSize(width: 560,  height: 640), in: dir)
    }

    private static func snap<V: View>(_ view: V, _ name: String, _ size: CGSize, in dir: URL) {
        let renderer = ImageRenderer(
            content: view
                .frame(width: size.width, height: size.height)
                .preferredColorScheme(.dark)
                .tint(DS.Palette.accent)
        )
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
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
