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

    /// User's preferred brain. `.auto` is local-first (Ollama qwen-coder when
    /// reachable). `.ollama` / `.salehman` force a specific brain. Defaults to
    /// `.auto`.
    @Published var brainPreference: BrainPreference {
        didSet { UserDefaults.standard.set(brainPreference.rawValue, forKey: Keys.brainPreference) }
    }
    /// The user's OWN local model name, used by the `.salehman` brain's local
    /// floor (an Ollama model the user pulled or built with a Modelfile). Salehman
    /// itself is cloud-first; this is its offline fallback model.
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
    /// OpenAI model id for the "Codex" (OpenAI) cloud brain. The API **key**
    /// lives in the Keychain (`KeychainStore.Account.openAIAPIKey`), matching the
    /// other cloud brains — never here.
    @Published var openAIModel: String {
        didSet { UserDefaults.standard.set(openAIModel, forKey: Keys.openAIModel) }
    }
    /// Which xAI Grok model to call when `BrainPreference.grok` is active.
    /// Defaults to `grok-4`; the Settings picker lets the user upgrade to
    /// `grok-4-heavy` for deeper reasoning at higher latency/cost. The API
    /// **key** itself never lives here — it's stored in the macOS Keychain
    /// via `KeychainStore.Account.grokAPIKey`.
    @Published var grokModel: String {
        didSet { UserDefaults.standard.set(grokModel, forKey: Keys.grokModel) }
    }
    /// Picked model for each of the four free cloud brains. The API **key**
    /// for each lives in macOS Keychain — see `KeychainStore.Account`.
    @Published var geminiModel: String {
        didSet { UserDefaults.standard.set(geminiModel, forKey: Keys.geminiModel) }
    }
    @Published var groqModel: String {
        didSet { UserDefaults.standard.set(groqModel, forKey: Keys.groqModel) }
    }
    @Published var mistralModel: String {
        didSet { UserDefaults.standard.set(mistralModel, forKey: Keys.mistralModel) }
    }
    @Published var cerebrasModel: String {
        didSet { UserDefaults.standard.set(cerebrasModel, forKey: Keys.cerebrasModel) }
    }
    @Published var deepSeekModel: String {
        didSet { UserDefaults.standard.set(deepSeekModel, forKey: Keys.deepSeekModel) }
    }
    @Published var openRouterModel: String {
        didSet { UserDefaults.standard.set(openRouterModel, forKey: Keys.openRouterModel) }
    }
    @Published var responseMode: ResponseMode { didSet { UserDefaults.standard.set(responseMode.rawValue, forKey: "set_responseMode") } }
    @Published var autoSpeak: Bool    { didSet { UserDefaults.standard.set(autoSpeak, forKey: Keys.autoSpeak) } }
    /// Read-aloud speed, normalized 0…1 (mapped to AVSpeechUtterance min/max).
    @Published var speechRate: Double { didSet { UserDefaults.standard.set(speechRate, forKey: Keys.speechRate) } }
    /// Selected voice identifier; empty = automatic (by language).
    @Published var speechVoiceID: String { didSet { UserDefaults.standard.set(speechVoiceID, forKey: Keys.speechVoiceID) } }
    @Published var webAccess: Bool    { didSet { UserDefaults.standard.set(webAccess, forKey: Keys.webAccess) } }
    @Published var useCodeModel: Bool { didSet { UserDefaults.standard.set(useCodeModel, forKey: Keys.codeModel) } }
    @Published var useVision: Bool    { didSet { UserDefaults.standard.set(useVision, forKey: Keys.vision) } }
    /// Autonomous Mode — lets the Agents tab kick off a self-directed Orchestrator
    /// run (chain tasks, self-correct, keep working with minimal input). Off by default.
    @Published var autonomousMode: Bool { didSet { UserDefaults.standard.set(autonomousMode, forKey: Keys.autonomousMode) } }
    /// **Offline / Local-Only mode.** Hard-disables every cloud brain (Claude, Grok,
    /// Gemini, Groq, Mistral, Cerebras, OpenAI/Codex, Copilot, OpenRouter) AND the
    /// external tools (`web_search`, `fetch_url`) — even when their keys/toggles
    /// are saved. With this on, only the local Ollama brain can answer, and
    /// no network call ever leaves the Mac. Off by default (opt-in).
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
    /// last word regardless of which brain drafted it. Default ON. Becomes a no-op
    /// when the brain is already `.salehman`, the draft is an error/off message, or
    /// the Salehman engine isn't reachable (then it returns the draft unchanged).
    @Published var salehmanLeader: Bool {
        didSet { UserDefaults.standard.set(salehmanLeader, forKey: Keys.salehmanLeader) }
    }

    /// Self-improvement loop: after Salehman answers, a DeepSeek reasoner (R1-class)
    /// critiques the answer and Salehman revises it. Smarter replies, but ~2–3× slower
    /// and more quota — **default OFF for speed** (owner asked to make it faster);
    /// turn ON for max-quality single answers.
    @Published var salehmanRefine: Bool {
        didSet { UserDefaults.standard.set(salehmanRefine, forKey: Keys.salehmanRefine) }
    }

    /// **Effort.** How hard Salehman thinks before answering — one knob over the
    /// Core-Intelligence primitives (self-critique rounds + candidate fan-out/judge).
    /// `.instant` = single pass; `.ultra` = several drafts, judged. Default `.balanced`.
    /// (Independent of `salehmanRefine`, which is the older DeepSeek-critique toggle.)
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
        nonisolated static let codeModel = "set_useCodeModel"
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
        nonisolated static let openAIModel     = "set_openAIModel"
        nonisolated static let grokModel       = "set_grokModel"
        nonisolated static let geminiModel     = "set_geminiModel"
        nonisolated static let groqModel       = "set_groqModel"
        nonisolated static let mistralModel    = "set_mistralModel"
        nonisolated static let cerebrasModel   = "set_cerebrasModel"
        nonisolated static let deepSeekModel   = "set_deepSeekModel"
        nonisolated static let openRouterModel = "set_openRouterModel"
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

    /// `nonisolated` read of the selected OpenAI/Codex model (key is in Keychain).
    nonisolated static var openAIModelCurrent: String {
        let raw = UserDefaults.standard.string(forKey: Keys.openAIModel) ?? ""
        return OpenAIClient.allModels.contains(raw) ? raw : OpenAIClient.defaultModel
    }

    /// `nonisolated` reads for the four free cloud brains' selected model.
    /// Each validates against its own `allModels` and falls back to the
    /// provider's default if the stored value is unrecognized — keeps a
    /// renamed-model rollout from silently 404ing every call.
    nonisolated static var geminiModelCurrent: String {
        let raw = UserDefaults.standard.string(forKey: Keys.geminiModel) ?? ""
        return GeminiClient.allModels.contains(raw) ? raw : GeminiClient.defaultModel
    }
    nonisolated static var groqModelCurrent: String {
        let raw = UserDefaults.standard.string(forKey: Keys.groqModel) ?? ""
        return GroqClient.allModels.contains(raw) ? raw : GroqClient.defaultModel
    }
    nonisolated static var mistralModelCurrent: String {
        let raw = UserDefaults.standard.string(forKey: Keys.mistralModel) ?? ""
        return MistralClient.allModels.contains(raw) ? raw : MistralClient.defaultModel
    }
    nonisolated static var cerebrasModelCurrent: String {
        let raw = UserDefaults.standard.string(forKey: Keys.cerebrasModel) ?? ""
        return CerebrasClient.allModels.contains(raw) ? raw : CerebrasClient.defaultModel
    }
    nonisolated static var deepSeekModelCurrent: String {
        let raw = UserDefaults.standard.string(forKey: Keys.deepSeekModel) ?? ""
        return DeepSeekClient.allModels.contains(raw) ? raw : DeepSeekClient.defaultModel
    }
    nonisolated static var openRouterModelCurrent: String {
        let raw = UserDefaults.standard.string(forKey: Keys.openRouterModel) ?? ""
        return OpenRouterClient.allModels.contains(raw) ? raw : OpenRouterClient.defaultModel
    }

    /// `nonisolated` read of the selected Grok model. The API **key** is in
    /// Keychain — read it via `KeychainStore.read(.grokAPIKey)`.
    nonisolated static var grokModelCurrent: String {
        let raw = UserDefaults.standard.string(forKey: Keys.grokModel) ?? ""
        // Falls back to the GrokClient default if the stored value isn't a
        // recognized model — prevents a renamed-model rollout from silently
        // 404ing every Grok request.
        return GrokClient.allModels.contains(raw) ? raw : GrokClient.defaultModel
    }

    /// Thread-safe read of the Salehman Leader switch (defaults ON) so the agent
    /// pipeline can gate the final Salehman pass from off the main actor.
    nonisolated static var salehmanLeaderEnabled: Bool { boolDefaultTrue(Keys.salehmanLeader) }
    nonisolated static var salehmanRefineEnabled: Bool { UserDefaults.standard.bool(forKey: Keys.salehmanRefine) }
    /// Auto-continue switch (defaults ON) — read off-main by the chat send loop.
    nonisolated static var autoContinueEnabled: Bool { boolDefaultTrue(Keys.autoContinue) }

    /// Thread-safe read of the Offline / Local-Only switch so
    /// `LocalLLM.currentBrain()`, `generateFreeAuto`, and `ToolPolicy` can gate
    /// cloud paths from outside the main actor. Defaults OFF (opt-in).
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
        useCodeModel = AppSettings.boolDefaultTrue(Keys.codeModel)
        useVision    = AppSettings.boolDefaultTrue(Keys.vision)
        autonomousMode = d.bool(forKey: Keys.autonomousMode)   // default off
        offlineOnly    = d.bool(forKey: Keys.offlineOnly)      // default off (opt-in)
        hideFromCapture = d.bool(forKey: Keys.hideCapture)   // default false
        unrestrictedTools = d.bool(forKey: Keys.unrestrictedTools)  // default off (opt-in)
        salehmanLeader = AppSettings.boolDefaultTrue(Keys.salehmanLeader)  // default ON (owner: Salehman leads)
        salehmanRefine = UserDefaults.standard.bool(forKey: Keys.salehmanRefine)  // default OFF — speed (it's ~2-3× slower); opt-in for max quality
        salehmanEffort = Effort(rawValue: d.string(forKey: Keys.salehmanEffort) ?? "") ?? .ultra  // default Ultra (max effort: 3 candidates → self-critique each → judge)
        autoContinue = AppSettings.boolDefaultTrue(Keys.autoContinue)      // default ON (owner: claude-autocontinue)
        privateMode = d.bool(forKey: Keys.privateMode)             // default off
        brainPreference = BrainPreference(rawValue: d.string(forKey: Keys.brainPreference) ?? "") ?? .salehman
        customModelName = d.string(forKey: Keys.customModel) ?? "salehman"   // your own model, default name
        customMLXModelPath = d.string(forKey: Keys.customMLXModelPath) ?? "" // empty = use default HF MLX model
        unslothStudioEndpoint = d.string(forKey: Keys.unslothStudioEndpoint) ?? "" // empty = not configured
        unslothStudioModel    = d.string(forKey: Keys.unslothStudioModel)    ?? ""
        vllmEndpoint = d.string(forKey: Keys.vllmEndpoint) ?? "" // empty = not configured
        vllmModel    = d.string(forKey: Keys.vllmModel)    ?? ""
        rotationBrains = (d.array(forKey: Keys.rotationBrains) as? [String] ?? []).compactMap(BrainPreference.init(rawValue:))
        let storedOAI = d.string(forKey: Keys.openAIModel) ?? ""
        openAIModel = OpenAIClient.allModels.contains(storedOAI) ? storedOAI : OpenAIClient.defaultModel
        let storedGrok = d.string(forKey: Keys.grokModel) ?? ""
        grokModel = GrokClient.allModels.contains(storedGrok) ? storedGrok : GrokClient.defaultModel
        let storedGemini = d.string(forKey: Keys.geminiModel) ?? ""
        geminiModel = GeminiClient.allModels.contains(storedGemini) ? storedGemini : GeminiClient.defaultModel
        let storedGroq = d.string(forKey: Keys.groqModel) ?? ""
        groqModel = GroqClient.allModels.contains(storedGroq) ? storedGroq : GroqClient.defaultModel
        let storedMistral = d.string(forKey: Keys.mistralModel) ?? ""
        mistralModel = MistralClient.allModels.contains(storedMistral) ? storedMistral : MistralClient.defaultModel
        let storedCerebras = d.string(forKey: Keys.cerebrasModel) ?? ""
        cerebrasModel = CerebrasClient.allModels.contains(storedCerebras) ? storedCerebras : CerebrasClient.defaultModel
        let storedDeepSeek = d.string(forKey: Keys.deepSeekModel) ?? ""
        deepSeekModel = DeepSeekClient.allModels.contains(storedDeepSeek) ? storedDeepSeek : DeepSeekClient.defaultModel
        let storedOpenRouter = d.string(forKey: Keys.openRouterModel) ?? ""
        openRouterModel = OpenRouterClient.allModels.contains(storedOpenRouter) ? storedOpenRouter : OpenRouterClient.defaultModel
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
/// app's primary identity; cloud-first with a free-tier chain and a local floor.
///
/// * `.salehman` — THE primary brain: NVIDIA DeepSeek V4 free → free frontier/
///   120B tiers → paid backstop → local MLX/Ollama floor. Self-improves via
///   DeepSeek critique pass. Works with zero local models if any cloud key is set.
/// * `.auto` — local-first: Ollama qwen-coder if reachable, else `.none`.
/// * `.ollama` — pin to Ollama qwen-coder. The pipeline automatically collapses
///   to a single agent on this brain (see AgentPipeline).
nonisolated enum BrainPreference: String, CaseIterable, Identifiable {
    case auto, freeAuto, freeCoding, cloudCoding, ollama, claudeHaiku, grok, gemini, groq, mistral, cerebras, codex, copilot
    case openRouter // aggregator with free `:free` models
    case deepSeek   // cloud · cheap pay-as-you-go, very strong at coding/reasoning · OpenAI-compatible (gets tools)
    case ensemble   // run ALL reachable brains in parallel, show every answer
    case salehman   // THE primary brain: cloud-first (NVIDIA DeepSeek V4 free → free frontier/120B tiers → paid backstop) + local floor (MLX, Ollama)
    case unslothStudio // local OpenAI-compatible server (Unsloth Studio / mlx_lm.server / LM Studio / llama.cpp)
    case vllm          // local OpenAI-compatible server served by vLLM (`vllm serve`, default :8000/v1)
    // freeAuto: race the FREE brains in parallel, first valid answer wins,
    // local (Ollama) backstop → effectively never rate-limited, never paid.

    var id: String { rawValue }

    /// Subscription / paid-per-call cloud providers. Hidden from the UI per owner
    /// request ("hide every paid api") — the Brain grid and Settings both consult
    /// this so the two surfaces can never drift. Free-tier clouds (Gemini, Groq,
    /// Mistral, Cerebras, OpenRouter), the local brains, and the orchestration
    /// modes (Auto / Free·Auto / Ensemble) are NOT paid.
    var isPaid: Bool {
        switch self {
        case .claudeHaiku, .grok, .codex, .copilot: return true
        default: return false
        }
    }

    /// Cases shown in the Brain picker — paid providers excluded.
    static var selectableCases: [BrainPreference] { allCases.filter { !$0.isPaid } }

    var title: String {
        switch self {
        case .auto:        return "Auto"
        case .freeAuto:    return "Free · Auto"
        case .freeCoding:  return "FreeCoding"
        case .cloudCoding: return "Cloud Coding"
        case .ollama:      return "Ollama qwen-coder"
        case .claudeHaiku: return "Claude Haiku (Cloud)"
        case .grok:        return "xAI Grok (Cloud)"
        case .gemini:      return "Google Gemini (Cloud)"
        case .groq:        return "Groq (Cloud)"
        case .mistral:     return "Mistral (Cloud)"
        case .cerebras:    return "Cerebras (Cloud)"
        case .deepSeek:    return "DeepSeek (Cloud)"
        case .codex:       return "Codex / OpenAI (Cloud)"
        case .copilot:     return "GitHub Copilot (Cloud)"
        case .openRouter:  return "OpenRouter (Cloud · free models)"
        case .ensemble:    return "All Brains at Once"
        case .salehman:    return "Salehman AI"
        case .unslothStudio: return "Unsloth Studio (local server)"
        case .vllm:          return "vLLM (local server)"
        }
    }
    var subtitle: String {
        switch self {
        case .auto:        return "Local-first · Ollama qwen-coder when reachable"
        case .freeAuto:    return "Races your free brains in parallel; first answer wins; falls back to local — never rate-limited, never paid"
        case .freeCoding:  return "Coding loop · races your free coder models + DeepSeek, runs & tests code in the terminal · local backstop"
        case .cloudCoding: return "Cloud-only coding loop · the best cloud coders (DeepSeek, gpt-oss-120b, qwen3-coder, codestral), raced · zero local RAM, no lag · needs a cloud key"
        case .ollama:      return "Local · qwen2.5-coder:7b · honors response mode (full = 15 agents)"
        case .claudeHaiku: return "Cloud · fast · ~zero local RAM · needs API key"
        case .grok:        return "Cloud · deepest reasoning · ~zero local RAM · needs API key"
        case .gemini:      return "Cloud · generous free tier · ~zero local RAM · needs API key"
        case .groq:        return "Cloud · blazing-fast Llama · ~zero local RAM · needs API key"
        case .mistral:     return "Cloud · EU-hosted · ~zero local RAM · needs API key"
        case .cerebras:    return "Cloud · ~2000 tok/s Llama · ~zero local RAM · needs API key"
        case .deepSeek:    return "Cloud · cheap + elite at code/reasoning · runs the terminal · ~zero local RAM · needs API key"
        case .codex:       return "Cloud · OpenAI GPT · ~zero local RAM · needs API key"
        case .copilot:     return "Cloud · your Copilot sub · ~zero local RAM · sign in with GitHub"
        case .openRouter:  return "Cloud · free `:free` models, no card · keys at openrouter.ai/keys"
        case .ensemble:    return "Runs every configured brain in parallel & shows all answers · pays each cloud brain per message"
        case .salehman:    return "Cloud-first · REAL DeepSeek V4 free (NVIDIA) → free frontier/120B tiers → local floor; self-improves via a DeepSeek critique pass"
        case .unslothStudio: return "Local · your fine-tuned model served by Unsloth Studio (or mlx_lm.server / LM Studio) over OpenAI-compatible HTTP · no key needed"
        case .vllm:          return "Local · high-throughput vLLM server over OpenAI-compatible HTTP (`vllm serve`, :8000/v1) · no key needed"
        }
    }
    var icon: String {
        switch self {
        case .auto:        return "sparkles"
        case .freeAuto:    return "infinity.circle.fill"
        case .freeCoding:  return "terminal.fill"
        case .cloudCoding: return "cloud.bolt.fill"
        case .ollama:      return "cpu"
        case .claudeHaiku: return "cloud.fill"
        case .grok:        return "bolt.horizontal.circle.fill"
        case .gemini:      return "diamond.fill"
        case .groq:        return "hare.fill"
        case .mistral:     return "leaf.circle.fill"
        case .cerebras:    return "rays"
        case .deepSeek:    return "curlybraces"
        case .codex:       return "chevron.left.forwardslash.chevron.right"
        case .copilot:     return "person.2.badge.gearshape.fill"
        case .openRouter:  return "arrow.triangle.branch"
        case .ensemble:    return "rectangle.3.group.fill"
        case .salehman:    return "brain.head.profile"
        case .unslothStudio: return "server.rack"
        case .vllm:          return "speedometer"
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
