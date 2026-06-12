import SwiftUI
import AVFoundation
import AppKit  // NSOpenPanel (custom-model folder picker)

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var approval = CommandApprovalCenter.shared
    @Environment(\.dismiss) private var dismiss

    @State private var ollamaUp = false
    @State private var hasVision = false
    @State private var hasCoder = false
    @State private var showMemory = false
    // Grok key entry state. `grokKeyDraft` only holds what the user is typing
    // *right now* — once they hit Save it's written to Keychain and cleared.
    // The literal key never lives in `@State` after Save.
    @State private var anthropicKeyDraft: String = ""
    @State private var anthropicKeySaved: Bool = AnthropicClient.isConfigured
    // Same idle/"":OK/"msg":error tri-state convention as the other cloud
    // brains. Lets the user run a live API check from Settings instead of
    // discovering a 401 only after sending a chat message.
    @State private var anthropicTesting: Bool = false
    @State private var anthropicTestStatus: String? = nil

    @State private var grokKeyDraft: String = ""
    @State private var grokTestStatus: String? = nil  // nil = idle, "" = OK, "msg" = error
    @State private var grokTesting: Bool = false
    @State private var grokKeySaved: Bool = GrokClient.hasKey()

    // Four free cloud brains. Same idle/"":OK/"msg":error convention as Grok.
    @State private var geminiKeyDraft: String = ""
    @State private var geminiTestStatus: String? = nil
    @State private var geminiTesting: Bool = false
    @State private var geminiKeySaved: Bool = GeminiClient.hasKey()

    @State private var groqKeyDraft: String = ""
    @State private var groqTestStatus: String? = nil
    @State private var groqTesting: Bool = false
    @State private var groqKeySaved: Bool = GroqClient.shared.hasKey()

    @State private var mistralKeyDraft: String = ""
    @State private var mistralTestStatus: String? = nil
    @State private var mistralTesting: Bool = false
    @State private var mistralKeySaved: Bool = MistralClient.shared.hasKey()

    @State private var cerebrasKeyDraft: String = ""
    @State private var cerebrasTestStatus: String? = nil
    @State private var cerebrasTesting: Bool = false
    @State private var cerebrasKeySaved: Bool = CerebrasClient.shared.hasKey()

    @State private var openAIKeyDraft: String = ""
    @State private var openAITestStatus: String? = nil
    @State private var openAITesting: Bool = false
    @State private var openAIKeySaved: Bool = OpenAIClient.hasKey()

    @State private var openRouterKeyDraft: String = ""
    @State private var openRouterTestStatus: String? = nil
    @State private var openRouterTesting: Bool = false
    @State private var openRouterKeySaved: Bool = OpenRouterClient.shared.hasKey()


    // NVIDIA NIM — REAL DeepSeek V4 on a free tier (the "DeepSeek for free" route).
    @State private var nvidiaKeyDraft: String = ""
    @State private var nvidiaTestStatus: String? = nil
    @State private var nvidiaTesting: Bool = false
    @State private var nvidiaKeySaved: Bool = NvidiaClient.shared.hasKey()

    // Unsloth Studio (local OpenAI-compatible server). No key — just an endpoint URL.
    @State private var unslothStudioTestStatus: String? = nil
    @State private var unslothStudioTesting: Bool = false
    @State private var vllmTestStatus: String? = nil
    @State private var vllmTesting: Bool = false
    @State private var vllmKeySaved: Bool = (KeychainStore.read(.vllmAPIKey) != nil)
    @State private var vllmKeyDraft: String = ""
    /// Optional Unsloth API token. Stored in Keychain (never UserDefaults). NOT
    /// needed for the local chat brain — only used so the Claude-Code snippet
    /// can paste the real `ANTHROPIC_AUTH_TOKEN` on copy. `nonisolated` Keychain
    /// read is safe at @State init.
    @State private var unslothStudioKeySaved: Bool = (KeychainStore.read(.unslothStudioAPIKey) != nil)
    @State private var unslothStudioKeyDraft: String = ""

    // GitHub Copilot signs in via OAuth device-flow, not a pasted key.
    @State private var copilotAuthed: Bool = CopilotClient.isAuthed()
    @State private var showCopilotSignIn = false
    @State private var copilotTesting = false
    @State private var copilotWorking: Bool? = nil   // nil = untested, true/false = result

    // Live "is the *selected* brain actually answering" check (covers all
    // brains). The overlap rules (three triggers can race at the await; a
    // superseded run must neither publish a stale verdict nor strand — or
    // prematurely clear — the spinner) live in `ActiveBrainProbe`
    // (SettingsBrainReadiness.swift), pinned by SettingsBrainReadyTests.
    @State private var activeBrain = ActiveBrainProbe()

    // Polled mirror of MLXSalehmanEngine.shared.state. The engine is an actor
    // (not ObservableObject), so a tiny .task polls it while the section is
    // visible — cheap (just a property read) and avoids touching the actor's
    // design just to drive UI updates.
    @State private var mlxState: MLXSalehmanEngine.State = .unavailable(reason: "")

    // 14B-readiness: tri-state probe of the user's own Ollama model (the
    // `.salehman` brain's offline floor — default name "salehman"). Drives
    // `salehmanModelStatusRow`; probed on appear, on name edit, on demand.
    enum LocalModelProbe: Equatable {
        case checking
        case installed(String)   // model with this name is pulled — floor ready
        case missing(String)     // Ollama up but no such model created yet
        case ollamaDown          // server unreachable — can't know either way
    }
    @State private var localModelProbe: LocalModelProbe = .checking

    // Persisted minimize/expand state for the two cloud-key groups. `@AppStorage`
    // (UserDefaults under the hood) survives a Settings-sheet reopen — plain
    // `@State` would reset every time the sheet appears, which would defeat the
    // "minimize and stay minimized" intent. Default is collapsed: Settings opens
    // clean; the count badge ("N/total set") in each header tells the user what
    // they have configured without making them expand.
    @AppStorage("settings.showFreeKeys") private var showFreeKeys: Bool = false
    @AppStorage("settings.showPaidKeys") private var showPaidKeys: Bool = false
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")

    private var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") || $0.language.hasPrefix("ar") }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ZStack {
            // Claude-Code-minimal restyle (owner directive, 2026-06-11): the
            // sheet canvas is FLAT opaque neutral grey — no gradients, no
            // translucent stacking. codeSurfaceSide = the panel shade.
            DS.Palette.codeSurfaceSide.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(DS.Motion.entrance, value: appeared)

                    section("Intelligence", "How Salehman thinks — local-first: vLLM → Unsloth Studio → MLX → Ollama.") {
                        toggle("Offline mode (local only)",
                               "Hard-disable every cloud brain and web tool. Only the local Ollama brain can answer — no network call leaves this Mac.",
                               "wifi.slash", $settings.offlineOnly)
                        toggle("Salehman leads",
                               "Every brain's answer gets a final pass through Salehman, so Salehman always owns the last word. On by default. When Salehman is already the picked brain there's no re-pass — but Effort above Instant still self-critiques its draft. Off = no extra passes for any brain. If Salehman isn't reachable, the draft answer stands.",
                               "crown.fill", $settings.salehmanLeader)
                        toggle("Self-improve loop",
                               "After Salehman answers, a self-critic pass analyzes the reply and Salehman revises it — smarter answers, but ~2–3× slower. OFF by default for speed; turn on for max quality.",
                               "arrow.triangle.2.circlepath", $settings.salehmanRefine)
                        toggle("Auto-continue",
                               "When a reply looks unfinished (hit the tool-call limit, an open code block, or 'shall I continue?'), automatically keep going without you typing 'continue' — up to a few times per message. On by default; press Stop to halt.",
                               "forward.end.alt.fill", $settings.autoContinue)
                        effortRow
                    }

                    section("Power & Privacy", "Two opposite extremes — only one can be on at a time.") {
                        toggle("Unrestricted Mode",
                               "Runs the assistant's shell commands WITHOUT asking for approval. Catastrophic commands (rm -rf /, disk erase, fork bombs, sudo) are STILL refused, but everything else runs unprompted. Off by default — use with extreme caution.",
                               "exclamationmark.triangle.fill", $settings.unrestrictedTools)
                        toggle("Private Mode",
                               "One tap for maximum privacy: forces Offline (no network) and Hide-from-capture on. Cannot be combined with Unrestricted Mode.",
                               "lock.fill", $settings.privateMode)
                    }

                    section("Brain", "Which model answers. Tap a cell to pin one; hover for details. The dot is green when that brain is reachable, orange when not.") {
                        activeBrainStatusRow
                        // Compact 3-column adaptive grid — 13 brains drop from a
                        // long scroll into ~5 short rows. Cell padding lives in
                        // `brainGridCell`; outer padding here keeps the grid off
                        // the section card's edges.
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
                            spacing: 8
                        ) {
                            // Paid providers are hidden per owner request — see
                            // `BrainPreference.selectableCases` / `.isPaid`.
                            ForEach(BrainPreference.selectableCases) { pref in
                                brainGridCell(pref)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        // Rotation status — shown when ≥2 brains are ✓-checked.
                        if settings.isRotating {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(DS.Palette.accent)
                                Text("Rotation on — cycling \(settings.rotationBrains.count) models, one per message:  \(settings.rotationBrains.map(\.title).joined(separator: "  →  "))")
                                    .font(.caption).foregroundStyle(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.bottom, 10)
                        }
                    }

                    section("Salehman engine", "Your own model — vLLM (RunPod or local), Unsloth Studio, on-device MLX, or Ollama. Resolution order: vLLM → Unsloth Studio → MLX → Ollama. No third-party cloud is ever contacted. Pick \u{201C}Salehman\u{201D} in the Brain grid above to activate it.") {
                        // The truly-standalone path. Visible regardless of
                        // package status; the inline state explains what to do.
                        mlxEngineRow

                        // The "your weights" row — point the engine at a local
                        // folder of fine-tuned MLX weights (Unsloth → GGUF
                        // → mlx_lm.convert; or MLX-LM → fuse). Empty = use the
                        // default HF model from mlxEngineRow above.
                        customMLXModelRow

                        Divider().overlay(DS.Palette.hairline).padding(.horizontal, 14)

                        HStack(spacing: 10) {
                            Image(systemName: "brain.head.profile")
                                .foregroundStyle(DS.Palette.accent)
                            TextField("Optional Ollama model name (default: salehman)", text: $settings.customModelName)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled(true)
                                .padding(8)
                                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                                .accessibilityLabel("Your custom Ollama model name")
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)

                        // Live status for the model named above: installed → the
                        // .salehman brain's offline floor is ready; missing → a
                        // copyable `ollama create` command for when the fine-tuned
                        // GGUF lands; Ollama down → can't know.
                        salehmanModelStatusRow
                    }

                    // Unsloth Studio (and any other local OpenAI-compatible server).
                    // No API key — just a local URL. Used for serving a model you've
                    // fine-tuned in Studio, or `mlx_lm.server`, LM Studio, etc.
                    section("Unsloth Studio (local server)", "Connect to a local OpenAI-compatible inference server — typically Unsloth Studio on http://localhost:8000/v1, but also valid for mlx_lm.server (:8080/v1), LM Studio, or llama.cpp. Pick \u{201C}Unsloth Studio\u{201D} in the Brain grid above to route chat here. No key needed. Loopback URLs (localhost / 127.0.0.1) also satisfy Knowledge's on-device privacy guarantee.") {
                        unslothStudioEndpointRow
                        unslothStudioModelRow
                        unslothStudioTestRow
                        unslothStudioKeyRow
                        hfTokenRow
                        claudeCodeUsageRow
                    }

                    // vLLM — local OR cloud-hosted high-throughput OpenAI-compatible server.
                    section("vLLM (local or cloud server)", "Run `vllm serve <model>` locally (http://localhost:8000/v1) OR host it on a cloud GPU (RunPod, etc.) and paste that public URL here — this is how you \u{201C}host the brain on the cloud\u{201D} and drive it from the app. Pick \u{201C}vLLM\u{201D} in the Brain grid to route chat here. For a public/cloud endpoint, start vLLM with `--api-key` and paste that key below so it's not open to the world. Loopback URLs also satisfy Knowledge's on-device privacy guarantee.") {
                        vllmEndpointRow
                        vllmModelRow
                        vllmKeyRow
                        vllmTestRow
                    }

                    // Cloud provider API key sections removed per owner: "i just want salehman alone".
                    // NVIDIA, Gemini, Groq, Mistral, Cerebras, OpenRouter, Claude, Grok, OpenAI,
                    // Copilot sections all removed 2026-06-12. NVIDIA toggle is in the Salehman
                    // engine section above since NVIDIA is SalehmanEngine's free cloud ladder.

                    section("Performance", "Your Mac: \(MachineInfo.summary). Higher = smarter but heavier.") {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkle.magnifyingglass").foregroundStyle(DS.Palette.accent)
                            Text("Recommended for your Mac: \(MachineInfo.recommendedMode.title)")
                                .font(.caption).foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Button { settings.applyRecommendedMode() } label: {
                                Text("Use")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(DS.Palette.accent, in: Capsule())
                                    .shadow(color: DS.Palette.accent.opacity(0.25), radius: 4, y: 1)
                            }
                            .buttonStyle(LuxPressStyle())
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)

                        ForEach(AppSettings.ResponseMode.allCases) { mode in
                            modeRow(mode)
                        }
                    }

                    section("Capabilities", nil) {
                        toggle("Web access", "Search & read the web", "globe", $settings.webAccess)
                        toggle("Image vision", "Understand images with qwen2.5vl", "eye", $settings.useVision)
                        toggle("Autonomous Mode",
                               "Agents can chain tasks, self-correct, and continue working with minimal input",
                               "sparkles",
                               $settings.autonomousMode)
                        toggle("Confirm terminal commands", "Ask before running each command", "lock.shield", $approval.confirmationEnabled)
                    }

                    section("Voice", nil) {
                        toggle("Auto-speak replies", "Read every answer aloud", "speaker.wave.2", $settings.autoSpeak)
                        speedRow
                        voiceRow
                        previewRow
                    }

                    section("Privacy", "Stay hidden while screen-sharing or recording.") {
                        toggle("Hide from screen capture", "Salehman AI won't appear in screenshots, recordings, or shares (you still see it)", "eye.slash", $settings.hideFromCapture)
                        memoryRow
                    }

                    section("Status", nil) {
                        statusRow("Ollama server", ollamaUp)
                        statusRow("Vision model (qwen2.5vl)", hasVision)
                        // Label is generic because the actual resolved model
                        // (7b → 14b → 32b priority) depends on what the user
                        // has pulled. `hasCoder` is true iff *any* of the
                        // preferred variants is on disk.
                        statusRow("Coding model (any qwen2.5-coder)", hasCoder)
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
            }
        }
        .frame(width: 560, height: 640)
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(DS.Motion.smooth) { appeared = true } }
        .sheet(isPresented: $showMemory) { MemoryView() }
        .sheet(isPresented: $showCopilotSignIn) {
            CopilotSignInView { copilotAuthed = CopilotClient.isAuthed() }
        }
        .task {
            // Re-poll Ollama + its models while Settings is open so the
            // picker rows ("Ready" / "Unavailable") stay in sync with the
            // top "Is X working?" panel. Without this loop, the rows would
            // freeze on the values captured the moment Settings opened —
            // which is the bug behind the "Unavailable + Working at the
            // same time" inconsistency. OllamaClient memoizes its probes
            // for 30s, so 5s polling here is effectively free (at most one
            // HTTP probe every 30s). The task ends automatically when
            // Settings is dismissed (SwiftUI cancels `.task` modifiers on
            // view disappear).
            // The active-brain test still only runs once, on first appear.
            var ranActiveBrainTestOnce = false
            while !Task.isCancelled {
                // `hasCoder` must reflect what `LocalLLM.ollamaReady()`
                // actually checks — i.e. "is *any* preferred coder model
                // pulled" via `activeCodeModel()`, not specifically the 7B
                // sweet-spot. Without this, a user with 14B (or 32B) but
                // no 7B sees the Ollama row stuck on "Unavailable" while
                // the actual brain works. `activeCodeModel` itself
                // probes `hasModel` against each entry, so we get the
                // server probe for free.
                async let up      = OllamaClient.isUp()
                async let vision  = OllamaClient.hasModel(OllamaClient.visionModel)
                async let active  = OllamaClient.activeCodeModel()
                let (u, v, a) = await (up, vision, active)
                // The three probes are a suspension point — if Settings was
                // dismissed while they were in flight, the task is now
                // cancelled. Bail before writing state so we don't paint one
                // stale frame onto a view that's going away.
                if Task.isCancelled { break }
                ollamaUp  = u
                hasVision = v
                hasCoder  = (a != nil)
                if !ranActiveBrainTestOnce, activeBrainIsLocal {
                    await testActiveBrain()
                    ranActiveBrainTestOnce = true
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        .onChange(of: settings.brainPreference) { _, _ in
            activeBrain.invalidate()                      // clear stale result on switch
            if activeBrainIsLocal { Task { await testActiveBrain() } }
        }
    }

    private var header: some View {
        HStack(spacing: DS.Space.md) {
            // Brand icon tile — consistent with all other sheet headers.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Gradient.brand)
                    .frame(width: 36, height: 36)
                    .dsShadow(DS.Elevation.accentGlow(0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.02)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.75)
                    )
                KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.60, duration: 0.07)
                        SpringKeyframe(1.18, spring: .snappy, duration: 0.28)
                        SpringKeyframe(1.0, spring: .bouncy, duration: 0.22)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Eyebrow(text: "App Configuration")
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(.secondary)
            }.buttonStyle(.plain).help("Close").accessibilityLabel("Close")
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, _ subtitle: String?, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Minimal section header: quiet tracked uppercase, no decorative
            // stripe — the content box carries the structure (chrome diet).
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(DS.Palette.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Palette.textSecondary)
            }
            VStack(spacing: 1) { content() }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(Color.white.opacity(0.035))
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        }
    }

    private func modeRow(_ mode: AppSettings.ResponseMode) -> some View {
        let sel = settings.responseMode == mode
        return Button { settings.responseMode = mode } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DS.Palette.accent.opacity(sel ? 0.18 : 0.09))
                        .frame(width: 26, height: 26)
                    Image(systemName: mode.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(sel ? DS.Palette.accent : .secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.title).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text(mode.detail).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if sel {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.Palette.successSoft)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Whether the given brain preference is reachable right now. Thin caller
    /// over the pure `BrainReadiness` seam (SettingsBrainReadiness.swift) —
    /// the readiness RULES live there, pinned by SettingsBrainReadyTests.
    /// Reads ONLY cached state: the @State key flags the Save/Clear bindings
    /// maintain plus the polled `ollamaUp`/`hasCoder` — zero Keychain
    /// syscalls per body recompute. (CODEBASE_REVIEW HIGH perf fix: the old
    /// switch here fired live `hasKey()` reads per visible grid cell on
    /// every recompute — each keystroke and each 5s poll tick paid ~25+
    /// SecItemCopyMatching calls; `.salehman` alone walked the whole 10-key
    /// `SalehmanEngine.hasAnyCloud` chain.)
    private func brainReady(_ pref: BrainPreference) -> Bool {
        brainReadiness.ready(pref)
    }

    /// Snapshot of every readiness signal, assembled from cached state only.
    /// Endpoint checks (`UnslothStudio`/`VLLM.isConfigured`) are UserDefaults
    /// reads — in-memory, no Keychain. Trade-off vs the old live reads: a key
    /// saved by something OTHER than this sheet wouldn't repaint the grid —
    /// but every in-app writer (Save/Clear rows, Copilot sign-in callback)
    /// already updates its cached flag, which recomputes body anyway, and the
    /// "N/total set" group badges have trusted these same flags all along.
    private var brainReadiness: BrainReadiness {
        BrainReadiness(
            ollamaUp: ollamaUp,
            hasCoder: hasCoder,
            customModelNamed: !settings.customModelName
                .trimmingCharacters(in: .whitespaces).isEmpty,
            unslothConfigured: UnslothStudio.isConfigured,
            vllmConfigured: VLLM.isConfigured,
            anthropic: anthropicKeySaved,
            grok: grokKeySaved,
            gemini: geminiKeySaved,
            groq: groqKeySaved,
            mistral: mistralKeySaved,
            cerebras: cerebrasKeySaved,
            openAI: openAIKeySaved,
            copilot: copilotAuthed,
            openRouter: openRouterKeySaved,
            nvidia: nvidiaKeySaved
        )
    }

    /// Compact selectable cell for the Brain picker grid. Replaces the old
    /// full-width `brainRow` — with 13 brains in the list, a vertical stack
    /// forced a long scroll. A 3-column adaptive grid drops that to ~5 rows
    /// while keeping every brain glanceable. The full subtitle text moves to
    /// a `.help(...)` tooltip so detail isn't lost, just hidden until hover.
    // MARK: - MLX standalone engine row
    //
    // The "Salehman alone" path. Lives at the top of the Salehman engine section
    // because it's the most independent of the three options (no Ollama, no
    // the local engine). The status text + button track the actor's State
    // enum (.unavailable / .downloading / .loading / .ready).

    private var mlxEngineRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "cpu.fill")
                .foregroundStyle(DS.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Standalone on-device engine")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(mlxStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            mlxStatusControl
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .task(id: "mlx-poll") {
            // Cheap polling loop — reads an actor property every 500 ms while
            // the section is visible (5 s once .ready, since nothing changes).
            // `.task` cancels automatically on view disappear, so this is safe.
            while !Task.isCancelled {
                mlxState = await MLXSalehmanEngine.shared.state
                let napNanos: UInt64 = {
                    if case .ready = mlxState { return 5_000_000_000 }
                    return 500_000_000
                }()
                try? await Task.sleep(nanoseconds: napNanos)
            }
        }
    }

    // MARK: - Custom MLX model folder row
    //
    // Lets the user point `MLXSalehmanEngine` at a LOCAL folder of fine-tuned
    // weights (Unsloth's `save_pretrained_gguf` → mlx convert; or MLX-LM's
    // `lora` + `fuse`). When set, the engine loads from that folder directly —
    // truly the user's own weights running locally, no Ollama, no download.
    // Empty path falls back to the default HuggingFace MLX model.

    private var customMLXModelRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill.badge.gearshape")
                .foregroundStyle(DS.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your fine-tuned MLX weights")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(customMLXSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Button("Choose…") { pickMLXModelFolder() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Choose fine-tuned MLX model folder")
            if !settings.customMLXModelPath.isEmpty {
                Button("Clear") {
                    settings.customMLXModelPath = ""
                    // Drop any loaded container so the next Download Model call
                    // re-loads using the default HF id.
                    Task { await MLXSalehmanEngine.shared.unload() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Clear custom MLX model path")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var customMLXSubtitle: String {
        let path = settings.customMLXModelPath
        if path.isEmpty {
            return "Using the default model. Click Choose… to point Salehman at a local folder of your fine-tuned weights (safetensors + tokenizer + config.json)."
        }
        return path
    }

    /// NSOpenPanel for a model directory. We persist the path string (not a
    /// security-scoped bookmark) because the app already reads other paths in
    /// Application Support without sandboxing — same trust model.
    private func pickMLXModelFolder() {
        let panel = NSOpenPanel()
        panel.title = "Pick the folder with your fine-tuned MLX weights"
        panel.prompt = "Use Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.customMLXModelPath = url.path
            // Drop any currently-loaded container so the next Download Model
            // call picks up the new path. Doesn't trigger a download itself —
            // the user taps Download Model when they're ready.
            Task { await MLXSalehmanEngine.shared.unload() }
        }
    }

    private var mlxStatusText: String {
        switch mlxState {
        case .unavailable(let reason): return reason
        case .downloading(let p):      return String(format: "Downloading… %.0f%%", p * 100)
        case .loading:                 return "Loading into memory…"
        case .ready:                   return "Ready — runs standalone, no Ollama needed"
        }
    }

    @ViewBuilder private var mlxStatusControl: some View {
        if !MLXSalehmanEngine.isPackageLinked {
            // No download button — the package isn't even in the project. Show
            // a clear chip + tooltip explaining the one Xcode step.
            Text("Add package")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(DS.Palette.warningSoft.opacity(0.22), in: Capsule())
                .help("""
                Add MLX Swift Examples via Xcode → File → Add Package Dependencies:
                https://github.com/ml-explore/mlx-swift-examples

                Then add the MLXLLM and MLXLMCommon products to the "Salehman AI" target.
                Rebuild, then tap "Download Model".
                """)
                .accessibilityLabel("Add MLX-Swift package in Xcode")
        } else {
            switch mlxState {
            case .unavailable:
                Button { Task { await MLXSalehmanEngine.shared.downloadAndLoad() } } label: {
                    Text("Download Model")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(DS.Palette.accent, in: Capsule())
                        .shadow(color: DS.Palette.accent.opacity(0.25), radius: 4, y: 1)
                }
                .buttonStyle(LuxPressStyle())
                .accessibilityLabel("Download standalone Salehman model")

            case .downloading(let p):
                ProgressView(value: p)
                    .frame(width: 80)
                    .progressViewStyle(.linear)
                    .tint(DS.Palette.accent)

            case .loading:
                ProgressView()
                    .controlSize(.small)

            case .ready:
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Palette.successSoft)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    /// The "smart modes" — orchestration prefs (not single brains) that get the
    /// premium gradient glyph in the grid. Pure so the cell stays cheap to render.
    private static func isOrchestrationMode(_ pref: BrainPreference) -> Bool {
        pref == .auto || pref == .freeAuto || pref == .freeCoding || pref == .cloudCoding || pref == .ensemble
    }

    private func brainGridCell(_ pref: BrainPreference) -> some View {
        let selected = settings.brainPreference == pref
        let inRotation = settings.rotationBrains.contains(pref)
        let ready = brainReady(pref)
        // Status is conveyed by BOTH a dot AND a text label — never color alone
        // (WCAG 1.4.1). Soft tints read calmer + clear ≥3:1 against the dark cell.
        let statusText = ready ? "Connected" : "Offline"
        let statusColor = ready ? DS.Palette.successSoft : DS.Palette.warningSoft
        return ZStack(alignment: .topLeading) {
        Button { settings.brainPreference = pref } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Group {
                        if Self.isOrchestrationMode(pref) {
                            // The smart "modes" (Auto / Free·Auto / FreeCoding /
                            // Ensemble) get a premium violet→accent gradient glyph
                            // so they read as a distinct tier above the single
                            // brains — cohesive, and makes the flagship loops pop.
                            Image(systemName: pref.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color(red: 0.62, green: 0.40, blue: 0.95), DS.Palette.accent],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        } else {
                            Image(systemName: pref.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selected ? DS.Palette.accent : .secondary)
                        }
                    }
                    .padding(.leading, 18)   // room for the rotation ✓ overlay
                    Spacer()
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(0.5), radius: 3, y: 1)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Palette.successSoft)
                    }
                }
                Text(pref.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (selected ? DS.Palette.accent.opacity(0.15) : Color.white.opacity(0.05)),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? DS.Palette.accent.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(pref.subtitle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pref.title), \(statusText)")
        .accessibilityHint(pref.subtitle)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)

        // Clickable rotation ✓ (top-left), a SEPARATE button from the pin tap.
        // Check ≥2 models to cycle through them — one per message.
        Button { withAnimation(DS.Motion.snappy) { settings.toggleRotation(pref) } } label: {
            Image(systemName: inRotation ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(inRotation ? DS.Palette.accent : Color.white.opacity(0.35))
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(inRotation ? "In rotation — click to remove" : "Add to rotation (cycle through ≥2 models)")
        .accessibilityLabel("\(pref.title) rotation")
        .accessibilityValue(inRotation ? "in rotation" : "not in rotation")
        .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Unsloth Studio rows (local OpenAI-compatible server)
    //
    // No API key — just a base URL the user types (or auto-fills) and an
    // optional model name. The endpoint defaults to Unsloth Studio's docs URL.
    // The Test button calls `UnslothStudio.testConnection()`, which does a real
    // 1-token ping so an unreachable server surfaces immediately. Status uses
    // the file's existing convention: nil = idle, "" = OK ("Connected ✓"),
    // non-empty = error message.

    private var unslothStudioEndpointRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "link").foregroundStyle(DS.Palette.accent)
            TextField("Endpoint URL (e.g. http://localhost:8000/v1)",
                      text: $settings.unslothStudioEndpoint)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .padding(8)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                .accessibilityLabel("Unsloth Studio endpoint URL")
            Button("Use :8000") {
                settings.unslothStudioEndpoint = "http://localhost:8000/v1"
            }
            .buttonStyle(.bordered).controlSize(.small)
            .accessibilityLabel("Fill with Unsloth Studio's default localhost URL")
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var unslothStudioModelRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill").foregroundStyle(DS.Palette.accent)
            TextField("Model name (whatever your server has loaded — leave blank if unsure)",
                      text: $settings.unslothStudioModel)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .padding(8)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                .accessibilityLabel("Unsloth Studio model name")
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var unslothStudioTestRow: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    unslothStudioTesting = true
                    // Convention: testConnection returns nil on success, so we
                    // store "" for OK and the raw message for failure — matches
                    // every other cloudTestRow in this file.
                    unslothStudioTestStatus = (await UnslothStudio.testConnection()) ?? ""
                    unslothStudioTesting = false
                }
            } label: {
                HStack(spacing: 6) {
                    if unslothStudioTesting { ProgressView().controlSize(.small) }
                    Text("Test connection")
                }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(unslothStudioTesting || settings.unslothStudioEndpoint.isEmpty)
            .accessibilityLabel("Test Unsloth Studio connection")

            if let status = unslothStudioTestStatus {
                Text(status.isEmpty ? "Connected ✓" : status)
                    .font(.caption)
                    .foregroundStyle(status.isEmpty ? DS.Palette.successSoft : DS.Palette.warningSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: vLLM rows (keyless local OpenAI-compatible server)

    private var vllmEndpointRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "link").foregroundStyle(DS.Palette.accent)
            TextField("Endpoint URL (e.g. http://localhost:8000/v1)",
                      text: $settings.vllmEndpoint)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .padding(8)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                .accessibilityLabel("vLLM endpoint URL")
            Button("Use :8000") {
                settings.vllmEndpoint = "http://localhost:8000/v1"
            }
            .buttonStyle(.bordered).controlSize(.small)
            .accessibilityLabel("Fill with vLLM's default localhost URL")
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var vllmModelRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill").foregroundStyle(DS.Palette.accent)
            TextField("Model name (what you passed to `vllm serve` — leave blank if unsure)",
                      text: $settings.vllmModel)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .padding(8)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                .accessibilityLabel("vLLM model name")
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var vllmTestRow: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    vllmTesting = true
                    vllmTestStatus = (await VLLM.testConnection()) ?? ""
                    vllmTesting = false
                }
            } label: {
                HStack(spacing: 6) {
                    if vllmTesting { ProgressView().controlSize(.small) }
                    Text("Test connection")
                }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(vllmTesting || settings.vllmEndpoint.isEmpty)
            .accessibilityLabel("Test vLLM connection")

            if let status = vllmTestStatus {
                Text(status.isEmpty ? "Connected ✓" : status)
                    .font(.caption)
                    .foregroundStyle(status.isEmpty ? DS.Palette.successSoft : DS.Palette.warningSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Optional vLLM API key. REQUIRED when you host vLLM on a public cloud GPU
    /// (start the server with `--api-key …`) so the endpoint isn't open to the
    /// world; leave blank for a keyless localhost `vllm serve`. The client sends
    /// it as `Authorization: Bearer …`. Per CLAUDE.md, it lives ONLY in Keychain.
    private var vllmKeyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("vLLM API key (optional)").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(vllmKeySaved
                     ? "Saved in macOS Keychain · sent as a Bearer token to your endpoint"
                     : "Needed for a public/cloud endpoint started with `--api-key`. Leave blank for localhost.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            SecureField("token", text: $vllmKeyDraft)
                .textFieldStyle(.plain).frame(width: 140)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
                .accessibilityLabel("vLLM API key")
            Button("Save") {
                let trimmed = vllmKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                _ = KeychainStore.write(trimmed, to: .vllmAPIKey)
                vllmKeyDraft = ""             // Wipe the in-memory copy immediately.
                vllmKeySaved = true
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(vllmKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            if vllmKeySaved {
                Button("Clear") {
                    _ = KeychainStore.delete(.vllmAPIKey)
                    vllmKeySaved = false
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.red)
                .accessibilityLabel("Clear vLLM API key")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Optional Unsloth API key field. The app's `.unslothStudio` chat brain
    /// talks to a local OpenAI-compatible server with `requiresKey == false`, so
    /// this key is NOT required for chatting. It only auto-fills the Claude-Code
    /// env-var snippet (below) so the copy-to-clipboard payload uses the user's
    /// real token instead of a placeholder. Per CLAUDE.md, the key lives ONLY
    /// in Keychain — never UserDefaults, logs, or source.
    /// Hugging Face token — the free cloud-GPU notebook needs it to download
    /// the private salehman GGUF. Keychain-only (never UserDefaults/files);
    /// Copy puts it on the clipboard for pasting into Colab's login box.
    private var hfTokenRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Hugging Face token").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(hfTokenSaved
                     ? "Saved in macOS Keychain · Copy → paste into the cloud-GPU notebook's token box"
                     : "For the free cloud-GPU notebook (downloads your private salehman model). Read scope is enough.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            SecureField("hf_…", text: $hfTokenDraft)
                .textFieldStyle(.plain).frame(width: 140)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
                .accessibilityLabel("Hugging Face token")
            Button("Save") {
                let trimmed = hfTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                _ = KeychainStore.write(trimmed, to: .hfToken)
                hfTokenDraft = ""                      // Wipe the in-memory copy immediately.
                hfTokenSaved = true
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(hfTokenDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            if hfTokenSaved {
                Button("Copy") {
                    if let token = KeychainStore.read(.hfToken) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(token, forType: .string)
                    }
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help("Copies the token for pasting into the Colab notebook")
                .accessibilityLabel("Copy Hugging Face token")
                Button("Clear") {
                    _ = KeychainStore.delete(.hfToken)
                    hfTokenSaved = false
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.red)
                .accessibilityLabel("Clear Hugging Face token")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    @State private var hfTokenSaved: Bool = (KeychainStore.read(.hfToken) != nil)
    @State private var hfTokenDraft: String = ""

    private var unslothStudioKeyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Unsloth API key (optional)").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(unslothStudioKeySaved
                     ? "Saved in macOS Keychain · auto-filled into the Claude Code snippet below"
                     : "Only needed for the Claude Code env-var snippet — leave blank if you don't have one.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            SecureField("sk-unsloth-…", text: $unslothStudioKeyDraft)
                .textFieldStyle(.plain).frame(width: 140)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
                .accessibilityLabel("Unsloth API key")
            Button("Save") {
                let trimmed = unslothStudioKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                _ = KeychainStore.write(trimmed, to: .unslothStudioAPIKey)
                unslothStudioKeyDraft = ""             // Wipe the in-memory copy immediately.
                unslothStudioKeySaved = true
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(unslothStudioKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            if unslothStudioKeySaved {
                Button("Clear") {
                    _ = KeychainStore.delete(.unslothStudioAPIKey)
                    unslothStudioKeySaved = false
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.red)
                .accessibilityLabel("Clear Unsloth API key")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Per Unsloth's "Run Local LLMs with Claude Code" guide
    /// (https://unsloth.ai/docs/basics/claude-code), Unsloth Studio also serves
    /// an **Anthropic-compatible** endpoint (default `:8888`) alongside the
    /// OpenAI-compatible one (`:8000/v1`) this app uses for chat. The same
    /// running Studio process can therefore back BOTH this app AND Claude Code
    /// (the terminal coding agent). This row surfaces the env-var snippet so
    /// the user doesn't have to keep the Unsloth doc page open, substitutes
    /// the model name they typed above, and copies on tap. The KV-cache tip
    /// (`CLAUDE_CODE_ATTRIBUTION_HEADER: "0"` in `~/.claude/settings.json`'s
    /// `"env"` block) is included because per the Unsloth docs Claude Code's
    /// default attribution header invalidates the model's KV cache and slows
    /// inference by ~90% — easy to miss, real fix when applied.
    private var claudeCodeUsageRow: some View {
        let modelName = settings.unslothStudioModel.trimmingCharacters(in: .whitespaces)
        let modelPlaceholder = modelName.isEmpty ? "<your-model-name>" : modelName
        // What's RENDERED on screen — always the placeholder. We never paint the
        // real key into a visible Text (lesson from the earlier Anthropic-prefix
        // audit finding: secret bytes shouldn't be on screen even briefly).
        let displaySnippet = """
        export ANTHROPIC_BASE_URL="http://localhost:8888"
        export ANTHROPIC_AUTH_TOKEN="sk-unsloth-xxxxxxxxxxxx"
        export ANTHROPIC_MODEL="\(modelPlaceholder)"
        """
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("Unsloth Studio also exposes an Anthropic-compatible endpoint on **:8888** for Claude Code. Start it with `unsloth studio -p 8888`, then export these in your shell — Claude Code will run against your local model instead of Anthropic's API. This is independent of the `:8000/v1` endpoint above, which is what this app uses for chat.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 8) {
                    Text(displaySnippet)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                        .textSelection(.enabled)
                    Button {
                        // Read the real key from Keychain at copy time — never
                        // store it in a Swift String for longer than this scope.
                        // If no key is saved, the placeholder is copied as-is.
                        let realKey = KeychainStore.read(.unslothStudioAPIKey) ?? "sk-unsloth-xxxxxxxxxxxx"
                        let clipboardSnippet = """
                        export ANTHROPIC_BASE_URL="http://localhost:8888"
                        export ANTHROPIC_AUTH_TOKEN="\(realKey)"
                        export ANTHROPIC_MODEL="\(modelPlaceholder)"
                        """
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(clipboardSnippet, forType: .string)
                    } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.bordered).controlSize(.small)
                        .help("Copy env-var snippet").accessibilityLabel("Copy env-var snippet")
                }

                // Small indicator so the user knows what will be on the clipboard.
                HStack(spacing: 6) {
                    Image(systemName: unslothStudioKeySaved ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(unslothStudioKeySaved ? DS.Palette.successSoft : .secondary)
                    Text(unslothStudioKeySaved
                         ? "Copy will substitute your saved Unsloth API key."
                         : "No Unsloth key saved — copy will paste the placeholder. Save one above to substitute the real token.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("⚠️ Also add `\"CLAUDE_CODE_ATTRIBUTION_HEADER\": \"0\"` under the `\"env\"` block in `~/.claude/settings.json`. Claude Code's default attribution header invalidates the local model's KV cache and slows inference by ~90% — this one-line setting brings it back.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "terminal").foregroundStyle(DS.Palette.accent)
                Text("Use this model with Claude Code too").font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Header-only disclosure that groups multiple `section()` cards under one
    /// tappable title with a count badge ("3/5 set"). The inner content stays
    /// styled by the existing `section()` helper — this just decides whether to
    /// render that content or hide it behind a chevron. Persists collapse state
    /// via `@AppStorage` flags at the binding site so the user's choice survives
    /// reopening Settings.
    @ViewBuilder
    private func collapsibleGroup<Content: View>(
        _ title: String,
        configured: Int,
        total: Int,
        isExpanded: Binding<Bool>,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(DS.Motion.snappy) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(configured)/\(total) set")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 14) { content() }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: xAI Grok rows
    //
    // Three small rows make up the Grok config UI:
    //   * grokKeyRow   — paste key into SecureField + Save (writes to Keychain).
    //   * grokModelRow — picker between grok-4 and grok-4-heavy.
    //   * grokTestRow  — "Test connection" button + status text.
    //
    // The literal key only lives in `grokKeyDraft` while the user is typing.
    // After Save, the draft is cleared and the bytes live only in Keychain.

    /// SecureField + Save/Clear. "Save" writes to Keychain and wipes the draft.
    private var grokKeyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("xAI API key").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(grokKeySaved ? "Saved in macOS Keychain · paste a new one to replace"
                                  : "Get one at console.x.ai → API Keys")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            SecureField("xai-…", text: $grokKeyDraft)
                .textFieldStyle(.plain).frame(width: 130)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
            Button("Save") {
                let trimmed = grokKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                _ = KeychainStore.write(trimmed, to: .grokAPIKey)
                grokKeyDraft = ""             // Wipe the in-memory copy immediately.
                grokKeySaved = GrokClient.hasKey()
                Task { await BrainStatus.shared.refresh() }   // Refresh header dot.
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(grokKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            if grokKeySaved {
                Button("Clear") {
                    _ = KeychainStore.delete(.grokAPIKey)
                    grokKeySaved = false
                    grokTestStatus = nil
                    Task { await BrainStatus.shared.refresh() }
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.red)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// 14B-readiness status row under the custom-model-name field: is a model
    /// with the typed name (default "salehman") actually pulled in Ollama?
    /// Uses the SAME accessors the engine routes by (`customModelNameCurrent`,
    /// `OllamaClient.hasModel`), so what this row says is what the brain does.
    private var salehmanModelStatusRow: some View {
        HStack(spacing: 6) {
            switch localModelProbe {
            case .checking:
                ProgressView().controlSize(.small)
                Text("Checking for your local model…")
                    .font(.caption2).foregroundStyle(.secondary)
            case .installed(let name):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.Palette.successSoft)
                Text("\"\(name)\" is installed — Salehman's offline floor is ready.")
                    .font(.caption2).foregroundStyle(.secondary)
            case .missing(let name):
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(DS.Palette.warningSoft)
                Text("Ollama is running but has no \"\(name)\" model yet. When the fine-tuned GGUF lands, run the create command from its folder.")
                    .font(.caption2).foregroundStyle(.secondary)
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString("ollama create \(name) -f Modelfile", forType: .string)
                } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.bordered).controlSize(.small)
                    .help("Copy \"ollama create \(name) -f Modelfile\"")
                    .accessibilityLabel("Copy the ollama create command")
            case .ollamaDown:
                Image(systemName: "circle.dashed").foregroundStyle(.secondary)
                Text("Ollama isn't running — can't check for your local model.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await probeLocalModel() }
            } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Re-check").accessibilityLabel("Re-check local model status")
        }
        .padding(.horizontal, 14).padding(.bottom, 11)
        .task { await probeLocalModel() }
        .onChange(of: settings.customModelName) { Task { await probeLocalModel() } }
    }

    /// Probe Ollama for the model named in Settings. Cheap: `isUp` is a
    /// localhost ping and `hasModel` reads a 30s-cached model list.
    private func probeLocalModel() async {
        localModelProbe = .checking
        guard await OllamaClient.isUp() else { localModelProbe = .ollamaDown; return }
        let name = AppSettings.customModelNameCurrent
        localModelProbe = await OllamaClient.hasModel(name) ? .installed(name) : .missing(name)
    }

    /// Branch-aware cost: `.salehman` brain uses refine-only path (no fan-out),
    /// so its call count is `approxRefineCalls`, not `approxModelCalls`.
    private var effortCallsHint: String {
        let e = settings.salehmanEffort
        let n = settings.brainPreference == .salehman ? e.approxRefineCalls : e.approxModelCalls
        let calls = n == 0 ? "no extra calls" : "~\(n) extra model call\(n == 1 ? "" : "s")"
        return "\(e.subtitle) · \(calls)/reply"
    }

    /// Effort — how hard Salehman thinks before answering (self-critique rounds
    /// + candidate fan-out/judge). Higher = better answers, more model calls.
    private var effortRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Effort").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(effortCallsHint)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Effort", selection: $settings.salehmanEffort) {
                ForEach(Effort.allCases) { e in
                    Text(e.displayName).tag(e)
                }
            }
            .labelsHidden().pickerStyle(.menu).frame(width: 150)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Picker between grok-4 (default) and grok-4-heavy.
    private var grokModelRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Model").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text("`grok-4` is the default; `grok-4-heavy` reasons deeper (slower / more $).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Grok model", selection: $settings.grokModel) {
                ForEach(GrokClient.allModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .labelsHidden().pickerStyle(.menu).frame(width: 150)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Test-connection button. Hits the live API with a tiny prompt to verify
    /// the saved key actually works (vs. a typo we silently 401 on later).
    private var grokTestRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Test connection").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(testStatusText(grokTestStatus))
                    .font(.caption2)
                    .foregroundStyle(testStatusColor(grokTestStatus))
            }
            Spacer()
            Button {
                grokTesting = true
                grokTestStatus = nil
                Task {
                    let err = await GrokClient.testConnection()
                    await MainActor.run {
                        grokTestStatus = err ?? ""    // "" = success
                        grokTesting = false
                    }
                }
            } label: {
                if grokTesting { ProgressView().controlSize(.small) }
                else           { Text("Test") }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(grokTesting || !grokKeySaved)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // Grok used to carry its own `grokTestStatusText` / `grokTestStatusColor` —
    // byte-identical to the shared `testStatusText(_:)` / `testStatusColor(_:)`
    // helpers below. Deleted: the duplication was a maintenance hazard (a future
    // color change would have drifted on Grok if you forgot the second site).
    // Call sites switched to the shared `testStatusText(grokTestStatus)`.

    /// GitHub Copilot OAuth device-flow sign-in + a live "is it working" check.
    private var copilotRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "person.2.badge.gearshape.fill")
                    .foregroundStyle(.secondary).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("GitHub Copilot")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text(copilotAuthed ? "Signed in · token stored in macOS Keychain"
                                       : "Requires an active Copilot subscription")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if copilotAuthed {
                    Button("Sign out") {
                        CopilotAuth.signOut()
                        copilotAuthed = false
                        copilotWorking = nil
                    }
                    .font(.caption.weight(.semibold)).buttonStyle(.bordered)
                    .controlSize(.small).tint(.red)
                } else {
                    Button { showCopilotSignIn = true } label: {
                        Text("Sign in with GitHub")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(DS.Palette.accent, in: Capsule())
                            .shadow(color: DS.Palette.accent.opacity(0.25), radius: 4, y: 1)
                    }
                    .buttonStyle(LuxPressStyle())
                }
            }
            if copilotAuthed {
                HStack(spacing: 8) {
                    workingBadge(testing: copilotTesting, working: copilotWorking)
                    Spacer()
                    Button("Test") { Task { await testCopilot() } }
                        .font(.caption2.weight(.semibold)).buttonStyle(.bordered)
                        .controlSize(.mini).disabled(copilotTesting)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Live "is the selected brain actually working" row. Pings whatever brain
    /// is currently pinned through the real routing path (`LocalLLM.generate`),
    /// so one check covers Ollama and every cloud brain.
    private var activeBrainStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(DS.Palette.accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Is \"\(settings.brainPreference.title)\" working?")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(settings.brainPreference == .ensemble
                     ? "Tap ↻ to check that ≥1 brain is reachable (no paid request)."
                     : activeBrainIsLocal
                       ? "Live check — auto-pings the selected brain."
                       : "Tap ↻ to check (sends one small paid request).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            workingBadge(testing: activeBrain.testing, working: activeBrain.working)
            Button { Task { await testActiveBrain() } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered).controlSize(.small).disabled(activeBrain.testing)
            .help("Test the selected brain").accessibilityLabel("Test the selected brain")
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Whether the pinned brain runs on this Mac (free to ping). Cloud brains
    /// cost money per request, so we only auto-check local ones and make the
    /// cloud check on-demand (the refresh button).
    private var activeBrainIsLocal: Bool {
        switch settings.brainPreference {
        case .auto, .ollama: return true
        default:             return false
        }
    }

    /// Ping the pinned brain and decide if it actually answered. Failure
    /// sentinels: empty reply, the canonical off-message, or the Anthropic
    /// error string (which `AnthropicClient` returns verbatim on a non-200).
    /// We match the specific "[Claude Haiku …" prefix rather than any "[" so a
    /// legitimate reply that begins with a bracket (code, a JSON array) isn't
    /// mistaken for a failure.
    private func testActiveBrain() async {
        // Three triggers (.task poll, brain-switch onChange, refresh button)
        // can overlap at the await below; `ActiveBrainProbe` owns the overlap
        // rules (spinner = any run live; superseded runs exit silently — see
        // SettingsBrainReadiness.swift, pinned by SettingsBrainReadyTests).
        // The pin comparison decides "superseded": only the run whose brain
        // is still selected at the end publishes its verdict.
        let pinned = settings.brainPreference
        activeBrain.begin()
        let working: Bool
        if LocalLLM.isEnsembleMode {
            // Ensemble fans out to EVERY reachable brain — firing a real "ping"
            // would bill several paid clouds just for a health check. Instead
            // verify at least one brain is reachable (Apple / Ollama / any keyed
            // cloud); that's exactly the condition under which ensemble answers.
            // Zero paid round-trips.
            working = await LocalLLM.anyBrainReachable()
        } else {
            let reply = await LocalLLM.generate("ping", maxTokens: 5)
            working = BrainPing.verdict(reply: reply, offMessage: LocalLLM.offMessage)
        }
        activeBrain.finish(verdict: working,
                           superseded: settings.brainPreference != pinned)
    }

    /// Reusable "is this brain actually working" badge: spinner while testing,
    /// then a green ✓ Working / red ✗ Not working / grey "Not tested".
    @ViewBuilder
    private func workingBadge(testing: Bool, working: Bool?) -> some View {
        HStack(spacing: 6) {
            if testing {
                ProgressView().controlSize(.mini)
                Text("Checking…").font(.caption2).foregroundStyle(.secondary)
            } else if let working {
                Image(systemName: working ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(working ? DS.Palette.successSoft : DS.Palette.warningSoft)
                Text(working ? "Working" : "Not working")
                    .font(.caption2).foregroundStyle(working ? DS.Palette.successSoft : DS.Palette.warningSoft)
            } else {
                Image(systemName: "circle.dashed").foregroundStyle(.secondary)
                Text("Not tested").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// Live ping for Copilot — does a one-token chat through the real path.
    private func testCopilot() async {
        copilotTesting = true
        copilotWorking = nil
        let ok = await CopilotClient.chat(prompt: "ping") != nil
        copilotTesting = false
        copilotWorking = ok
    }

    // (Deleted `grokTestStatusColor` — see note above grokTestStatusText.)

    // MARK: Generic OpenAI-compatible cloud rows
    //
    // The three OpenAI-compatible brains (Groq, Mistral, Cerebras) share the
    // exact same UI shape — key entry + model picker + test. These helpers
    // take an `OpenAICompatibleClient` so each provider's Settings section is
    // ~10 lines of call site instead of ~150 lines of copy-paste.

    @ViewBuilder
    private func cloudKeyRow(provider: OpenAICompatibleClient,
                             keySaved: Binding<Bool>,
                             draft: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(provider.displayName) API key")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(keySaved.wrappedValue
                     ? "Saved in macOS Keychain · paste a new one to replace"
                     : "Get one at \(provider.consoleURL)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            SecureField("key…", text: draft)
                .textFieldStyle(.plain).frame(width: 130)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
            Button("Save") {
                let trimmed = draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                // `cloudKeyRow` is only rendered for key-bearing providers, so
                // `keychainAccount` is always non-nil in practice; we guard
                // explicitly because the field is `Account?` to support the
                // new no-auth local servers (Unsloth Studio).
                guard let account = provider.keychainAccount else { return }
                _ = KeychainStore.write(trimmed, to: account)
                draft.wrappedValue = ""
                keySaved.wrappedValue = provider.hasKey()
                Task { await BrainStatus.shared.refresh() }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            if keySaved.wrappedValue {
                Button("Clear") {
                    // Same `Account?` unwrap as Save above — cloudKeyRow is
                    // only used by key-bearing providers.
                    guard let account = provider.keychainAccount else { return }
                    _ = KeychainStore.delete(account)
                    keySaved.wrappedValue = false
                    Task { await BrainStatus.shared.refresh() }
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.red)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    @ViewBuilder
    private func cloudModelRow(displayName: String,
                               models: [String],
                               selection: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cube").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(displayName) model")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text("First in the list is the lightest; last is the heaviest.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("\(displayName) model", selection: selection) {
                ForEach(models, id: \.self) { model in Text(model).tag(model) }
            }
            .labelsHidden().pickerStyle(.menu).frame(width: 200)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    @ViewBuilder
    private func cloudTestRow(provider: OpenAICompatibleClient,
                              keySaved: Binding<Bool>,
                              testing: Binding<Bool>,
                              status: Binding<String?>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Test connection")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(testStatusText(status.wrappedValue))
                    .font(.caption2).foregroundStyle(testStatusColor(status.wrappedValue))
            }
            Spacer()
            Button {
                testing.wrappedValue = true
                status.wrappedValue = nil
                Task {
                    let err = await provider.testConnection()
                    await MainActor.run {
                        status.wrappedValue = err ?? ""
                        testing.wrappedValue = false
                    }
                }
            } label: {
                if testing.wrappedValue { ProgressView().controlSize(.small) }
                else                    { Text("Test") }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(testing.wrappedValue || !keySaved.wrappedValue)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func testStatusText(_ status: String?) -> String {
        switch status {
        case nil:           return "Tap Test after saving the key."
        case .some(""):     return "Connected — your key works."
        case .some(let m):  return m
        }
    }

    private func testStatusColor(_ status: String?) -> Color {
        switch status {
        case nil:        return .secondary
        // Desaturated soft tokens — full-saturation `.green`/`.orange` reads as
        // alarming on the dark canvas (see DS.Palette docstring). One change
        // here cascades to all seven cloud-provider test rows.
        case .some(""):  return DS.Palette.successSoft
        case .some(_):   return DS.Palette.warningSoft
        }
    }

    // MARK: Google Gemini rows
    //
    // Gemini doesn't speak OpenAI's wire format, so it has its own client
    // and its own row triplet. Same shape as the generic cloud rows above.

    private var geminiKeyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Gemini API key").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(geminiKeySaved
                     ? "Saved in macOS Keychain · paste a new one to replace"
                     : "Get one at aistudio.google.com → Get API key")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            SecureField("AIza…", text: $geminiKeyDraft)
                .textFieldStyle(.plain).frame(width: 130)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
            Button("Save") {
                let trimmed = geminiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                _ = KeychainStore.write(trimmed, to: .geminiAPIKey)
                geminiKeyDraft = ""
                geminiKeySaved = GeminiClient.hasKey()
                Task { await BrainStatus.shared.refresh() }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(geminiKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            if geminiKeySaved {
                Button("Clear") {
                    _ = KeychainStore.delete(.geminiAPIKey)
                    geminiKeySaved = false
                    geminiTestStatus = nil
                    Task { await BrainStatus.shared.refresh() }
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.red)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var geminiModelRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Gemini model").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text("`gemini-2.0-flash` is the default; `gemini-1.5-pro` is deeper.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Gemini model", selection: $settings.geminiModel) {
                ForEach(GeminiClient.allModels, id: \.self) { model in Text(model).tag(model) }
            }
            .labelsHidden().pickerStyle(.menu).frame(width: 200)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var geminiTestRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Test connection").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(testStatusText(geminiTestStatus))
                    .font(.caption2).foregroundStyle(testStatusColor(geminiTestStatus))
            }
            Spacer()
            Button {
                geminiTesting = true
                geminiTestStatus = nil
                Task {
                    let err = await GeminiClient.testConnection()
                    await MainActor.run {
                        geminiTestStatus = err ?? ""
                        geminiTesting = false
                    }
                }
            } label: {
                if geminiTesting { ProgressView().controlSize(.small) }
                else             { Text("Test") }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(geminiTesting || !geminiKeySaved)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Anthropic API key entry — only needed for the Claude Haiku (cloud) brain.
    /// Anthropic key entry — Keychain-backed Save/Clear/Test, same pattern
    /// as the other cloud brains (the literal key only lives in
    /// `anthropicKeyDraft` while the user is typing).
    ///
    /// The subtitle below the title shows the **prefix** of the saved key
    /// (e.g. `sk-ant-api03…`) so the user can verify *which* key family is
    /// stored without ever revealing the full string. The most common cause
    /// of "but my key is valid" 401s against Anthropic is a key from the
    /// wrong service silently saved (the SecureField masks input); the
    /// prefix display flags that immediately.
    private var claudeKeyRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Anthropic API key").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text(anthropicSubtitle)
                        .font(.caption2)
                        .foregroundStyle(anthropicSubtitleColor)
                }
                Spacer()
                SecureField("sk-ant-…", text: $anthropicKeyDraft)
                    .textFieldStyle(.plain).frame(width: 130)
                    .multilineTextAlignment(.trailing).foregroundStyle(.white)
                Button("Save") {
                    let trimmed = anthropicKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    _ = KeychainStore.write(trimmed, to: .anthropicAPIKey)
                    anthropicKeyDraft = ""
                    anthropicKeySaved = AnthropicClient.isConfigured
                    anthropicTestStatus = nil   // reset the test indicator
                    Task { await BrainStatus.shared.refresh() }
                }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(anthropicKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                if anthropicKeySaved {
                    Button {
                        anthropicTesting = true
                        anthropicTestStatus = nil
                        Task {
                            let err = await Self.runAnthropicTest()
                            await MainActor.run {
                                anthropicTestStatus = err ?? ""
                                anthropicTesting = false
                            }
                        }
                    } label: {
                        if anthropicTesting { ProgressView().controlSize(.small) }
                        else                { Text("Test") }
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(anthropicTesting)

                    Button("Clear") {
                        _ = KeychainStore.delete(.anthropicAPIKey)
                        anthropicKeySaved = false
                        anthropicTestStatus = nil
                        Task { await BrainStatus.shared.refresh() }
                    }
                    .buttonStyle(.bordered).controlSize(.small).tint(.red)
                }
            }

            // Test-result line. Only visible after the user runs Test. The
            // verbatim message (when error) is what Anthropic returned — same
            // text the chat shows, but you see it here before paying for a
            // full chat round-trip.
            if anthropicKeySaved, let status = anthropicTestStatus {
                HStack {
                    Spacer().frame(width: 22)
                    Text(status.isEmpty
                         ? "Connected — Anthropic accepted the saved key."
                         : status)
                        .font(.caption2)
                        .foregroundStyle(status.isEmpty ? DS.Palette.successSoft : DS.Palette.warningSoft)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Single Keychain read shared by the subtitle text + color, so a body
    /// recompute does ONE Keychain round-trip instead of two. Returns nil
    /// when no key is saved (the subtitle/color fall back to the "not
    /// configured" presentation). Never exposes the full key — callers only
    /// read the prefix and the `sk-ant-` family check.
    private var savedAnthropicKey: String? {
        anthropicKeySaved ? KeychainStore.read(.anthropicAPIKey) : nil
    }

    /// Subtitle for the key row — the masking rule is pure in
    /// `AnthropicKeyPresentation` (SettingsBrainReadiness.swift): echoes the
    /// 12-char family prefix only when the key IS `sk-ant-…`; a misfiled
    /// wrong-service key (whose first chars carry secret bytes) masks to
    /// `sk-…`. No-leak property pinned by SettingsBrainReadyTests.
    private var anthropicSubtitle: String {
        AnthropicKeyPresentation.subtitle(savedKey: savedAnthropicKey)
    }

    /// Orange when the prefix doesn't look like an Anthropic key, secondary
    /// otherwise. Drives attention to the "saved the wrong key" failure mode.
    private var anthropicSubtitleColor: Color {
        AnthropicKeyPresentation.flagsWrongService(savedKey: savedAnthropicKey)
            ? DS.Palette.warningSoft : .secondary
    }

    /// Hit Anthropic with a one-token prompt and surface the actual error.
    /// Returns `nil` for "OK", or a human-readable error string. Static
    /// because the test logic is pure side-effect (network + Keychain
    /// reads) and doesn't touch the view's `@State`.
    private static func runAnthropicTest() async -> String? {
        guard KeychainStore.read(.anthropicAPIKey) != nil else {
            return "No Anthropic key saved. Paste one and tap Save."
        }
        let reply = await AnthropicClient.chat(prompt: "ping", system: nil)
        guard let reply else {
            return "Couldn't reach Anthropic. Check your network and try again."
        }
        // If the reply is a `[Claude Haiku error …]` formatted string, the
        // key reached Anthropic but was rejected — surface their message
        // verbatim so the user knows exactly what to fix.
        if reply.hasPrefix("[Claude Haiku error") || reply.hasPrefix("[Claude Haiku request") {
            return reply
        }
        return nil   // got a real assistant reply → success
    }

    private func toggle(_ title: String, _ subtitle: String, _ icon: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            // Icon well — accent-tinted, consistent with all other list rows.
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DS.Palette.accent.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: binding).labelsHidden().toggleStyle(.switch).tint(DS.Palette.accent)
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: Voice rows
    private var speedRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DS.Palette.accent.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: "speedometer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Speaking speed").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text("How fast replies are read aloud").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Slider(value: $settings.speechRate, in: 0...1).frame(width: 150).tint(DS.Palette.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var voiceRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DS.Palette.accent.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: "person.wave.2")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
            Text("Voice").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
            Spacer()
            Picker("Voice", selection: $settings.speechVoiceID) {
                Text("Automatic").tag("")
                ForEach(voices, id: \.identifier) { v in
                    Text("\(v.name) (\(v.language))").tag(v.identifier)
                }
            }
            .labelsHidden().frame(width: 210)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var previewRow: some View {
        HStack {
            Spacer()
            Button {
                SpeechOut.shared.speak("Hi Saleh, this is how I'll sound when reading your replies.", id: UUID())
            } label: {
                Label("Preview voice", systemImage: "play.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered).controlSize(.small).tint(DS.Palette.accent)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var memoryRow: some View {
        Button { showMemory = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DS.Palette.accent.opacity(0.12))
                        .frame(width: 26, height: 26)
                    Image(systemName: "brain")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Manage memory").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text("See and delete what Salehman AI remembers about you").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusRow(_ title: String, _ ok: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((ok ? DS.Palette.successSoft : DS.Palette.warningSoft).opacity(0.14))
                    .frame(width: 26, height: 26)
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ok ? DS.Palette.successSoft : DS.Palette.warningSoft)
            }
            Text(title).font(.system(size: 14)).foregroundStyle(.white)
            Spacer()
            Text(ok ? "Ready" : "Off").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}

