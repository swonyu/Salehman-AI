import SwiftUI
import Combine
import AppKit

/// Central, persisted settings the user controls from the Settings panel.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum ResponseMode: String, CaseIterable, Identifiable {
        case fast, balanced, full
        var id: String { rawValue }
        var title: String {
            switch self {
            case .fast: return "Low"
            case .balanced: return "Balanced"
            case .full: return "Maximum"
            }
        }
        var detail: String {
            switch self {
            case .fast: return "Lightest load · 1 agent · instant replies"
            case .balanced: return "Medium load · 2 agents · streamed & polished"
            case .full: return "Heaviest · all 15 agents · best on powerful Macs"
            }
        }
        var icon: String {
            switch self {
            case .fast: return "leaf.fill"
            case .balanced: return "gauge.medium"
            case .full: return "bolt.fill"
            }
        }
    }

    /// User's preferred brain. Defaults to `.salehman` — the trained primary, which
    /// resolves vLLM → Unsloth Studio → MLX → Ollama, all local. `.auto` is
    /// local-first (Ollama qwen-coder when reachable). See `selectableCases`.
    @Published var brainPreference: BrainPreference {
        didSet { UserDefaults.standard.set(brainPreference.rawValue, forKey: Keys.brainPreference) }
    }
    /// The user's OWN local model name, used by the `.salehman` brain's local
    /// floor (an Ollama model the user pulled or built with a Modelfile). Salehman
    /// is fully local; this is its Ollama-tier model.
    @Published var customModelName: String {
        didSet { UserDefaults.standard.set(customModelName, forKey: Keys.customModel) }
    }
    /// Optional **local directory** containing a fine-tuned MLX model (safetensors
    /// + tokenizer + config.json). When non-empty, `MLXSalehmanEngine` loads
    /// THIS folder directly instead of downloading `defaultModelID` from HuggingFace
    /// — so a fine-tune produced by Unsloth/MLX-LM lives in the app as the true
    /// "your weights, no Ollama" engine. Empty = use the default HF model.
    @Published var customMLXModelPath: String {
        didSet { UserDefaults.standard.set(customMLXModelPath, forKey: Keys.customMLXModelPath) }
    }
    /// Base URL of a **local OpenAI-compatible** inference server — typically
    /// **Unsloth Studio** on `http://localhost:8000/v1` (its docs serve `/v1` on
    /// port 8000), but also valid for `mlx_lm.server` (default `:8080/v1`),
    /// LM Studio, llama.cpp's server, etc. When non-empty and `.unslothStudio`
    /// is pinned, chat routes here through `OpenAICompatibleClient` (no API
    /// key required — `requiresKey: false`). Empty = brain reported as
    /// "not configured" in Settings / BrainStatus.
    @Published var unslothStudioEndpoint: String {
        didSet { UserDefaults.standard.set(unslothStudioEndpoint, forKey: Keys.unslothStudioEndpoint) }
    }
    /// Model id passed in the OpenAI-compat `{"model": "..."}` request body for
    /// the `.unslothStudio` brain. Many local servers only have one model
    /// loaded and ignore this field, but Studio/MLX let you swap models, so we
    /// surface it. Empty falls back to `"local"` (a harmless sentinel).
    @Published var unslothStudioModel: String {
        didSet { UserDefaults.standard.set(unslothStudioModel, forKey: Keys.unslothStudioModel) }
    }
    /// vLLM endpoint URL (e.g. http://localhost:8000/v1) for the `.vllm` brain.
    /// Empty = not configured (the brain gate treats that as unreachable).
    @Published var vllmEndpoint: String {
        didSet { UserDefaults.standard.set(vllmEndpoint, forKey: Keys.vllmEndpoint) }
    }
    /// Model id passed to vLLM's OpenAI-compatible `{"model": …}` body. vLLM
    /// typically serves a single model; blank falls back to a `"local"` sentinel.
    @Published var vllmModel: String {
        didSet { UserDefaults.standard.set(vllmModel, forKey: Keys.vllmModel) }
    }
    /// Brains the user checked (✓) for ROTATION. When ≥2 are selected the app
    /// cycles to the next one on each sent message (`advanceRotation`). Persisted
    /// as raw values; list order IS the rotation order.
    @Published var rotationBrains: [BrainPreference] {
        didSet { UserDefaults.standard.set(rotationBrains.map(\.rawValue), forKey: Keys.rotationBrains) }
    }
    @Published var responseMode: ResponseMode { didSet { UserDefaults.standard.set(responseMode.rawValue, forKey: "set_responseMode") } }
    @Published var autoSpeak: Bool    { didSet { UserDefaults.standard.set(autoSpeak, forKey: Keys.autoSpeak) } }
    /// Read-aloud speed, normalized 0…1 (mapped to AVSpeechUtterance min/max).
    @Published var speechRate: Double { didSet { UserDefaults.standard.set(speechRate, forKey: Keys.speechRate) } }
    /// Selected voice identifier; empty = automatic (by language).
    @Published var speechVoiceID: String { didSet { UserDefaults.standard.set(speechVoiceID, forKey: Keys.speechVoiceID) } }
    @Published var webAccess: Bool    { didSet { UserDefaults.standard.set(webAccess, forKey: Keys.webAccess) } }
    @Published var useVision: Bool    { didSet { UserDefaults.standard.set(useVision, forKey: Keys.vision) } }
    /// Autonomous Mode — lets the Agents tab kick off a self-directed Orchestrator
    /// run (chain tasks, self-correct, keep working with minimal input). Off by default.
    @Published var autonomousMode: Bool { didSet { UserDefaults.standard.set(autonomousMode, forKey: Keys.autonomousMode) } }
    /// **Offline / Local-Only mode.** Hard-disables the external tools
    /// (`web_search`, `fetch_url`) — even when their toggles are saved. With this
    /// on, no network call ever leaves the Mac. Off by default (opt-in). (The app
    /// is already local-only for inference — all brains are on-device.)
    @Published var offlineOnly: Bool { didSet { UserDefaults.standard.set(offlineOnly, forKey: Keys.offlineOnly) } }
    @Published var hideFromCapture: Bool {
        didSet { UserDefaults.standard.set(hideFromCapture, forKey: Keys.hideCapture); applyCapturePrivacy() }
    }

    /// **Unrestricted Mode.** Opt-in power-user switch that removes the
    /// per-command approval PROMPT — shell commands the assistant issues run without
    /// asking. Off by default. SAFETY FLOOR PRESERVED: `Shell.runApproved` still runs
    /// `Shell.isBlocked` BEFORE approval, so outright-catastrophic commands (`rm -rf /`,
    /// fork bombs, disk erase, `sudo`, etc.) are refused regardless of this mode —
    /// Unrestricted Mode only auto-approves what already passed that floor (see
    /// `CommandApprovalCenter.requestApproval`). Mutually exclusive with Private Mode.
    @Published var unrestrictedTools: Bool {
        didSet {
            UserDefaults.standard.set(unrestrictedTools, forKey: Keys.unrestrictedTools)
            if unrestrictedTools && privateMode { privateMode = false }  // opposite extremes
        }
    }

    /// **Private Mode.** One tap for maximum privacy: forces Offline (no cloud/network)
    /// and Hide-from-capture ON. Mutually exclusive with Unrestricted Mode. Off by default.
    @Published var privateMode: Bool {
        didSet {
            UserDefaults.standard.set(privateMode, forKey: Keys.privateMode)
            if privateMode {
                if unrestrictedTools { unrestrictedTools = false }
                if !offlineOnly { offlineOnly = true }
                if !hideFromCapture { hideFromCapture = true }
            }
        }
    }

    /// **Salehman Leader.** When ON, every brain's answer is passed through the
    /// Salehman model for one final pass — Salehman is the "leader" that owns the
    /// last word regardless of which brain drafted it. Default ON. OFF = zero extra
    /// passes for ALL brains (including pinned `.salehman`). Becomes a no-op when
    /// the draft is an error/off message or Salehman is unreachable. Pinned
    /// `.salehman` with Leader ON: the Effort dial applies (self-critique only).
    @Published var salehmanLeader: Bool {
        didSet { UserDefaults.standard.set(salehmanLeader, forKey: Keys.salehmanLeader) }
    }

    /// Self-improvement loop: after Salehman answers, a self-critic pass analyses
    /// the reply and Salehman revises it via `SelfCritique.refine`. Smarter replies,
    /// but ~2–3× slower — **default OFF for speed**; turn ON for max-quality
    /// single answers.
    @Published var salehmanRefine: Bool {
        didSet { UserDefaults.standard.set(salehmanRefine, forKey: Keys.salehmanRefine) }
    }

    /// **Effort.** How hard Salehman thinks before answering — one knob over the
    /// Core-Intelligence primitives (self-critique rounds + candidate fan-out/judge).
    /// `.instant` = single pass; `.ultra` = several drafts, judged. Default `.instant`
    /// (preserves pre-Effort behavior — no surprise extra model calls on upgrade).
    /// (Independent of `salehmanRefine`, which is the older critique-loop toggle.)
    @Published var salehmanEffort: Effort {
        didSet { UserDefaults.standard.set(salehmanEffort.rawValue, forKey: Keys.salehmanEffort) }
    }

    /// Auto-continue (claude-autocontinue style): when a reply looks unfinished — it
    /// hit the tool-call round cap, ended on an unterminated code block, or the model
    /// offered to go on — the chat auto-sends "continue" up to a small cap, so the
    /// owner needn't nudge it each time. Default ON (owner request); cancellable via
    /// Stop, and a no-op for normal complete answers.
    @Published var autoContinue: Bool {
        didSet { UserDefaults.standard.set(autoContinue, forKey: Keys.autoContinue) }
    }

    // UserDefaults keys — `nonisolated` so the policy layer (which runs off
    // the main actor) can read them without an actor hop. They're just
    // immutable string constants, so no isolation is needed.
    enum Keys {
        nonisolated static let autoSpeak = "set_autoSpeak"
        nonisolated static let webAccess = "set_webAccess"
        nonisolated static let vision    = "set_useVision"
        nonisolated static let autonomousMode = "set_autonomousMode"
        nonisolated static let offlineOnly    = "set_offlineOnly"
        nonisolated static let hideCapture = "set_hideCapture"
        nonisolated static let unrestrictedTools = "set_unrestrictedTools"
        nonisolated static let salehmanLeader    = "set_salehmanLeader"
        nonisolated static let salehmanRefine    = "set_salehmanRefine"
        nonisolated static let salehmanEffort    = "set_salehmanEffort"
        nonisolated static let autoContinue      = "set_autoContinue"
        nonisolated static let privateMode       = "set_privateMode"
        nonisolated static let speechRate = "set_speechRate"
        nonisolated static let speechVoiceID = "set_speechVoiceID"
        nonisolated static let brainPreference = "set_brainPreference"
        nonisolated static let customModel        = "set_customModelName"
        nonisolated static let customMLXModelPath = "set_customMLXModelPath"
        nonisolated static let unslothStudioEndpoint = "set_unslothStudioEndpoint"
        nonisolated static let unslothStudioModel    = "set_unslothStudioModel"
        nonisolated static let vllmEndpoint = "set_vllmEndpoint"
        nonisolated static let vllmModel    = "set_vllmModel"
        nonisolated static let rotationBrains  = "set_rotationBrains"
    }

    /// `nonisolated` read of the user's own model name for the `.salehman` brain.
    /// Defaults to `"salehman"`; trimmed so a stray space can't 404 every call.
    /// Nonisolated read of the user's custom MLX model directory (empty = use
    /// the default HF model). Trimmed so a stray space can't break path lookup.
    nonisolated static var customMLXModelPathCurrent: String {
        (UserDefaults.standard.string(forKey: Keys.customMLXModelPath) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static var customModelNameCurrent: String {
        (UserDefaults.standard.string(forKey: Keys.customModel) ?? "salehman")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Nonisolated read of the user's Unsloth-Studio (or other local
    /// OpenAI-compat) endpoint URL. Empty string means "not configured" — the
    /// brain gate treats that as unreachable so it falls through to the next
    /// brain instead of issuing a doomed HTTP call.
    nonisolated static var unslothStudioEndpointCurrent: String {
        (UserDefaults.standard.string(forKey: Keys.unslothStudioEndpoint) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Nonisolated read of the model id passed to the local server.
    /// Falls back to a harmless `"local"` sentinel when the user leaves it
    /// blank — most single-model servers ignore the field anyway.
    nonisolated static var unslothStudioModelCurrent: String {
        let stored = (UserDefaults.standard.string(forKey: Keys.unslothStudioModel) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stored.isEmpty ? "local" : stored
    }

    /// Nonisolated reads for the vLLM endpoint + model (mirrors Unsloth Studio).
    nonisolated static var vllmEndpointCurrent: String {
        (UserDefaults.standard.string(forKey: Keys.vllmEndpoint) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    nonisolated static var vllmModelCurrent: String {
        let stored = (UserDefaults.standard.string(forKey: Keys.vllmModel) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stored.isEmpty ? "local" : stored
    }

    /// Rotation mode is active when the user checked ≥2 brains to cycle through.
    var isRotating: Bool { rotationBrains.count >= 2 }

    /// Toggle a brain's membership in the rotation set (✓ in the Brain grid).
    /// List order = rotation order.
    func toggleRotation(_ pref: BrainPreference) {
        if let i = rotationBrains.firstIndex(of: pref) { rotationBrains.remove(at: i) }
        else { rotationBrains.append(pref) }
    }

    /// Advance the active brain to the NEXT model in the rotation set. Called once
    /// per sent message when rotation is active. Mutating `brainPreference` reuses
    /// the entire single-pin routing — and the highlighted Brain cell visibly
    /// moves so the user can see the rotation happening.
    func advanceRotation() {
        guard isRotating else { return }
        if let i = rotationBrains.firstIndex(of: brainPreference) {
            brainPreference = rotationBrains[(i + 1) % rotationBrains.count]
        } else {
            brainPreference = rotationBrains[0]
        }
    }

    /// Thread-safe read of the Salehman Leader switch (defaults ON) so the agent
    /// pipeline can gate the final Salehman pass from off the main actor.
    nonisolated static var salehmanLeaderEnabled: Bool { boolDefaultTrue(Keys.salehmanLeader) }
    nonisolated static var salehmanRefineEnabled: Bool { UserDefaults.standard.bool(forKey: Keys.salehmanRefine) }
    /// Thread-safe read of the Effort dial (validate-or-default, like the
    /// `*ModelCurrent` accessors) so the answer path reads it off the main actor.
    nonisolated static var salehmanEffortCurrent: Effort {
        Effort(rawValue: UserDefaults.standard.string(forKey: Keys.salehmanEffort) ?? "") ?? .instant
    }
    /// Auto-continue switch (defaults ON) — read off-main by the chat send loop.
    nonisolated static var autoContinueEnabled: Bool { boolDefaultTrue(Keys.autoContinue) }

    /// Thread-safe read of the Offline / Local-Only switch so `ToolPolicy` can
    /// gate the external tools from outside the main actor. Defaults OFF (opt-in).
    nonisolated static var isOfflineOnly: Bool { UserDefaults.standard.bool(forKey: Keys.offlineOnly) }

    /// Thread-safe read of the Unrestricted Mode switch, for any
    /// off-main caller. Defaults OFF. The catastrophic-command floor
    /// (`Shell.isBlocked`) is independent of this and always applies.
    nonisolated static var unrestrictedToolsEnabled: Bool { UserDefaults.standard.bool(forKey: Keys.unrestrictedTools) }

    /// Excludes (or re-includes) every current app window — main window, sheets,
    /// popovers, menus, the approval card — from screen capture/recording/sharing.
    func applyCapturePrivacy() {
        let type: NSWindow.SharingType = hideFromCapture ? .none : .readOnly
        for window in NSApplication.shared.windows { window.sharingType = type }
    }

    /// Notifications that catch new windows the moment they appear so a sheet,
    /// popover, or menu opened *after* the toggle is flipped also stays hidden.
    private var captureObservers: [NSObjectProtocol] = []

    private func installCaptureObservers() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didChangeScreenNotification,
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didExposeNotification,
        ]
        for name in names {
            let obs = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    // `applyCapturePrivacy()` sweeps EVERY window (the one in
                    // `note.object` included), so we don't read the notification's
                    // object — that would send a non-Sendable `Notification` across
                    // the isolation boundary (a Swift 6 language-mode error).
                    self.applyCapturePrivacy()
                }
            }
            captureObservers.append(obs)
        }
    }

    private init() {
        let d = UserDefaults.standard
        responseMode = ResponseMode(rawValue: d.string(forKey: "set_responseMode") ?? "fast") ?? .fast
        autoSpeak    = d.object(forKey: Keys.autoSpeak) == nil ? false : d.bool(forKey: Keys.autoSpeak)
        speechRate   = d.object(forKey: Keys.speechRate) == nil ? 0.5 : d.double(forKey: Keys.speechRate)
        speechVoiceID = d.string(forKey: Keys.speechVoiceID) ?? ""
        webAccess    = AppSettings.boolDefaultTrue(Keys.webAccess)
        useVision    = AppSettings.boolDefaultTrue(Keys.vision)
        autonomousMode = d.bool(forKey: Keys.autonomousMode)   // default off
        offlineOnly    = d.bool(forKey: Keys.offlineOnly)      // default off (opt-in)
        hideFromCapture = d.bool(forKey: Keys.hideCapture)   // default false
        unrestrictedTools = d.bool(forKey: Keys.unrestrictedTools)  // default off (opt-in)
        salehmanLeader = AppSettings.boolDefaultTrue(Keys.salehmanLeader)  // default ON (owner: Salehman leads)
        salehmanRefine  = UserDefaults.standard.bool(forKey: Keys.salehmanRefine)  // default OFF — speed (it's ~2-3× slower); opt-in for max quality
        salehmanEffort = Effort(rawValue: d.string(forKey: Keys.salehmanEffort) ?? "") ?? .instant  // default Instant — preserves pre-Effort call count; opt in to quality via the dial
        autoContinue = AppSettings.boolDefaultTrue(Keys.autoContinue)      // default ON (owner: claude-autocontinue)
        privateMode = d.bool(forKey: Keys.privateMode)             // default off
        // The Brain menu is now pared to `selectableCases` (Salehman + Auto). Migrate a
        // stale/hidden saved pick (e.g. an old cloud brain that's no longer in the menu)
        // to the default so the picker is never blank — and PERSIST it, because
        // `brainPreferenceCurrent` reads UserDefaults directly in the LLM layer and must
        // agree with what the menu can show.
        let savedBrain = BrainPreference(rawValue: d.string(forKey: Keys.brainPreference) ?? "") ?? .salehman
        let normalizedBrain = BrainPreference.selectableCases.contains(savedBrain) ? savedBrain : .salehman
        if normalizedBrain != savedBrain { d.set(normalizedBrain.rawValue, forKey: Keys.brainPreference) }
        brainPreference = normalizedBrain
        customModelName = d.string(forKey: Keys.customModel) ?? "salehman"   // your own model, default name
        customMLXModelPath = d.string(forKey: Keys.customMLXModelPath) ?? "" // empty = use default HF MLX model
        unslothStudioEndpoint = d.string(forKey: Keys.unslothStudioEndpoint) ?? "" // empty = not configured
        unslothStudioModel    = d.string(forKey: Keys.unslothStudioModel)    ?? ""
        vllmEndpoint = d.string(forKey: Keys.vllmEndpoint) ?? "" // empty = not configured
        vllmModel    = d.string(forKey: Keys.vllmModel)    ?? ""
        rotationBrains = (d.array(forKey: Keys.rotationBrains) as? [String] ?? []).compactMap(BrainPreference.init(rawValue:))
        installCaptureObservers()
    }

    /// `nonisolated` accessor so `LocalLLM` (which decides which brain to use
    /// from an actor context) can read the user's preference without an
    /// actor hop. Falls back to `.auto` when the stored value is missing or
    /// unrecognized — never crashes the chain on a typo.
    nonisolated static var brainPreferenceCurrent: BrainPreference {
        let raw = UserDefaults.standard.string(forKey: Keys.brainPreference) ?? ""
        return BrainPreference(rawValue: raw) ?? .salehman
    }

    /// Thread-safe reads for tools running off the main actor.
    nonisolated static func boolDefaultTrue(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil ? true : UserDefaults.standard.bool(forKey: key)
    }

    func applyRecommendedMode() { responseMode = MachineInfo.recommendedMode }
}

/// User's preferred chat brain. Read by `LocalLLM.currentBrain()` to decide
/// which model is asked for the next response. **Default: `.salehman`** — the
/// app's primary identity, fully local with no third-party cloud.
///
/// * `.salehman` — THE primary brain: local-first (vLLM → Unsloth Studio → MLX →
///   Ollama). Self-improves via a critique pass. No third-party cloud is ever
///   contacted.
/// * `.auto` — local-first: Ollama qwen-coder if reachable, else `.none`.
/// * `.ollama` — pin to Ollama qwen-coder. The pipeline automatically collapses
///   to a single agent on this brain (see AgentPipeline).
nonisolated enum BrainPreference: String, CaseIterable, Identifiable {
    case auto, ollama
    case salehman   // THE primary brain: local-first (vLLM → Unsloth Studio → MLX → Ollama). No third-party cloud is ever contacted.
    case unslothStudio // local OpenAI-compatible server (Unsloth Studio / mlx_lm.server / LM Studio / llama.cpp)
    case vllm          // local OpenAI-compatible server served by vLLM (`vllm serve`, default :8000/v1)
    case uncensored    // local Ollama, abliterated (refusal-removed) ~3B; web-search capable, on-device, free

    var id: String { rawValue }

    /// The app is local-only — there are no paid cloud brains, so this is always
    /// false. Kept so the Brain grid and Settings can consult one source of truth.
    var isPaid: Bool { false }

    /// Cases shown in the Brain picker. Salehman is the trained primary — it
    /// resolves vLLM → Unsloth Studio → MLX → Ollama internally, all local.
    /// `.auto` stays for pure-local / offline use. (`.ollama` and `.vllm` still
    /// function if set directly — e.g. by the brain-rotation hotkey — they're
    /// just no longer surfaced in the menu.)
    // Salehman + Auto, plus the custom-server brain so you can point the app at your
    // OWN model served on a free cloud GPU (Kaggle/Colab → Ollama → cloudflared URL)
    // or any local OpenAI-compatible server. See salehman-training/cloud_serve_salehman.md.
    static var selectableCases: [BrainPreference] { [.salehman, .auto, .unslothStudio, .uncensored] }

    var title: String {
        switch self {
        case .auto:        return "Auto"
        case .ollama:      return "Ollama qwen-coder"
        case .salehman:    return "Salehman AI"
        case .unslothStudio: return "Custom server (local / cloud GPU)"
        case .vllm:          return "vLLM (local server)"
        case .uncensored:    return "Uncensored (Local · web)"
        }
    }
    var subtitle: String {
        switch self {
        case .auto:        return "Local-first · Ollama qwen-coder when reachable"
        case .ollama:      return "Local · qwen2.5-coder:7b · honors response mode (full = 15 agents)"
        case .salehman:    return "Your own model — vLLM (RunPod or local), Unsloth Studio, on-device MLX, or Ollama. Resolution order: vLLM → Unsloth Studio → MLX → Ollama. No third-party cloud."
        case .unslothStudio: return "Your fine-tune on a FREE cloud GPU (Kaggle/Colab → Ollama → cloudflared URL) or any local OpenAI-compatible server. Set the endpoint + model in Settings · no key needed"
        case .vllm:          return "Local · high-throughput vLLM server over OpenAI-compatible HTTP (`vllm serve`, :8000/v1) · no key needed"
        case .uncensored:    return "Unfiltered local model via Ollama — small (~3B), on-device, free, no key. Can use web search to find anything online (lawful personal use). Pull it: `ollama pull \(OllamaClient.uncensoredModel)`"
        }
    }
    var icon: String {
        switch self {
        case .auto:        return "sparkles"
        case .ollama:      return "cpu"
        case .salehman:    return "brain.head.profile"
        case .unslothStudio: return "server.rack"
        case .vllm:          return "speedometer"
        case .uncensored:    return "eye.trianglebadge.exclamationmark.fill"
        }
    }
}

/// Detects the Mac's capability to recommend a performance tier.
enum MachineInfo {
    static var memoryGB: Int {
        Int((Double(ProcessInfo.processInfo.physicalMemory) / Double(ByteConstants.bytesPerGB)).rounded())
    }
    static var cores: Int { ProcessInfo.processInfo.processorCount }

    static var summary: String { "\(memoryGB) GB RAM · \(cores) cores" }

    static var recommendedMode: AppSettings.ResponseMode {
        if memoryGB >= 24 && cores >= 10 { return .full }      // powerful Mac
        if memoryGB >= 16 { return .balanced }
        return .fast                                            // lighter Mac
    }
}
