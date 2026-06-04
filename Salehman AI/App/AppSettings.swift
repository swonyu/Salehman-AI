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

    /// Master switch for Apple Intelligence (the on-device chat brain). When off,
    /// the assistant politely declines to generate; vision, transcription and
    /// dictation keep working. Defaults ON so the app works out of the box.
    @Published var useAppleIntelligence: Bool { didSet { UserDefaults.standard.set(useAppleIntelligence, forKey: Keys.appleIntelligence) } }

    /// User's preferred brain. `.auto` picks Apple Intelligence when it's
    /// available, otherwise Ollama qwen-coder. `.apple` / `.ollama` force a
    /// specific brain — useful for testing, or when the user prefers one over
    /// the other for quality / speed reasons. Defaults to `.auto`.
    @Published var brainPreference: BrainPreference {
        didSet { UserDefaults.standard.set(brainPreference.rawValue, forKey: Keys.brainPreference) }
    }
    /// Anthropic API key for the optional Claude Haiku (cloud) brain. Empty = not
    /// configured. Stored locally; only sent to Anthropic when Claude is the brain.
    @Published var anthropicAPIKey: String {
        didSet { UserDefaults.standard.set(anthropicAPIKey, forKey: Keys.anthropicAPIKey) }
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
    @Published var responseMode: ResponseMode { didSet { UserDefaults.standard.set(responseMode.rawValue, forKey: "set_responseMode") } }
    @Published var autoSpeak: Bool    { didSet { UserDefaults.standard.set(autoSpeak, forKey: Keys.autoSpeak) } }
    /// Read-aloud speed, normalized 0…1 (mapped to AVSpeechUtterance min/max).
    @Published var speechRate: Double { didSet { UserDefaults.standard.set(speechRate, forKey: Keys.speechRate) } }
    /// Selected voice identifier; empty = automatic (by language).
    @Published var speechVoiceID: String { didSet { UserDefaults.standard.set(speechVoiceID, forKey: Keys.speechVoiceID) } }
    @Published var webAccess: Bool    { didSet { UserDefaults.standard.set(webAccess, forKey: Keys.webAccess) } }
    @Published var useCodeModel: Bool { didSet { UserDefaults.standard.set(useCodeModel, forKey: Keys.codeModel) } }
    @Published var useVision: Bool    { didSet { UserDefaults.standard.set(useVision, forKey: Keys.vision) } }
    @Published var hideFromCapture: Bool {
        didSet { UserDefaults.standard.set(hideFromCapture, forKey: Keys.hideCapture); applyCapturePrivacy() }
    }

    // UserDefaults keys — `nonisolated` so the policy layer (which runs off
    // the main actor) can read them without an actor hop. They're just
    // immutable string constants, so no isolation is needed.
    enum Keys {
        nonisolated static let appleIntelligence = "set_appleIntelligence"
        nonisolated static let autoSpeak = "set_autoSpeak"
        nonisolated static let webAccess = "set_webAccess"
        nonisolated static let codeModel = "set_useCodeModel"
        nonisolated static let vision    = "set_useVision"
        nonisolated static let hideCapture = "set_hideCapture"
        nonisolated static let speechRate = "set_speechRate"
        nonisolated static let speechVoiceID = "set_speechVoiceID"
        nonisolated static let brainPreference = "set_brainPreference"
        nonisolated static let anthropicAPIKey = "set_anthropicAPIKey"
        nonisolated static let openAIModel     = "set_openAIModel"
        nonisolated static let grokModel       = "set_grokModel"
        nonisolated static let geminiModel     = "set_geminiModel"
        nonisolated static let groqModel       = "set_groqModel"
        nonisolated static let mistralModel    = "set_mistralModel"
        nonisolated static let cerebrasModel   = "set_cerebrasModel"
    }

    /// `nonisolated` read of the Anthropic key for the model layer (off main actor).
    nonisolated static var anthropicAPIKeyCurrent: String {
        UserDefaults.standard.string(forKey: Keys.anthropicAPIKey) ?? ""
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

    /// `nonisolated` read of the selected Grok model. The API **key** is in
    /// Keychain — read it via `KeychainStore.read(.grokAPIKey)`.
    nonisolated static var grokModelCurrent: String {
        let raw = UserDefaults.standard.string(forKey: Keys.grokModel) ?? ""
        // Falls back to the GrokClient default if the stored value isn't a
        // recognized model — prevents a renamed-model rollout from silently
        // 404ing every Grok request.
        return GrokClient.allModels.contains(raw) ? raw : GrokClient.defaultModel
    }

    /// Thread-safe read of the Apple Intelligence master switch for the model
    /// layer, which runs off the main actor. Defaults ON.
    nonisolated static var appleIntelligenceEnabled: Bool { boolDefaultTrue(Keys.appleIntelligence) }

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
            let obs = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let type: NSWindow.SharingType = self.hideFromCapture ? .none : .readOnly
                    if let win = note.object as? NSWindow { win.sharingType = type }
                    // Sweep siblings (sheet + parent, popover stack, etc.).
                    self.applyCapturePrivacy()
                }
            }
            captureObservers.append(obs)
        }
    }

    private init() {
        let d = UserDefaults.standard
        useAppleIntelligence = AppSettings.boolDefaultTrue(Keys.appleIntelligence)   // default ON
        responseMode = ResponseMode(rawValue: d.string(forKey: "set_responseMode") ?? "fast") ?? .fast
        autoSpeak    = d.object(forKey: Keys.autoSpeak) == nil ? false : d.bool(forKey: Keys.autoSpeak)
        speechRate   = d.object(forKey: Keys.speechRate) == nil ? 0.5 : d.double(forKey: Keys.speechRate)
        speechVoiceID = d.string(forKey: Keys.speechVoiceID) ?? ""
        webAccess    = AppSettings.boolDefaultTrue(Keys.webAccess)
        useCodeModel = AppSettings.boolDefaultTrue(Keys.codeModel)
        useVision    = AppSettings.boolDefaultTrue(Keys.vision)
        hideFromCapture = d.bool(forKey: Keys.hideCapture)   // default false
        brainPreference = BrainPreference(rawValue: d.string(forKey: Keys.brainPreference) ?? "") ?? .auto
        anthropicAPIKey = d.string(forKey: Keys.anthropicAPIKey) ?? ""
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
        installCaptureObservers()
    }

    /// `nonisolated` accessor so `LocalLLM` (which decides which brain to use
    /// from an actor context) can read the user's preference without an
    /// actor hop. Falls back to `.auto` when the stored value is missing or
    /// unrecognized — never crashes the chain on a typo.
    nonisolated static var brainPreferenceCurrent: BrainPreference {
        let raw = UserDefaults.standard.string(forKey: Keys.brainPreference) ?? ""
        return BrainPreference(rawValue: raw) ?? .auto
    }

    /// Thread-safe reads for tools running off the main actor.
    nonisolated static func boolDefaultTrue(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil ? true : UserDefaults.standard.bool(forKey: key)
    }

    func applyRecommendedMode() { responseMode = MachineInfo.recommendedMode }
}

/// User's preferred chat brain. Read by `LocalLLM.currentBrain()` to decide
/// which model is asked for the next response.
///
/// * `.auto` — try Apple Intelligence first, then fall back to Ollama. This is
///   the right default: lightweight when it works, graceful when it doesn't.
/// * `.apple` — pin to Apple Intelligence. If unavailable (hardware doesn't
///   support it, or the master switch is off), no fallback happens.
/// * `.ollama` — pin to Ollama qwen-coder. Heavier per-turn but free of
///   Apple Intelligence's content guardrails. The pipeline automatically
///   collapses to a single agent on this brain (see AgentPipeline).
enum BrainPreference: String, CaseIterable, Identifiable {
    case auto, apple, ollama, claudeHaiku, grok, gemini, groq, mistral, cerebras, codex, copilot

    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto:        return "Auto"
        case .apple:       return "Apple Intelligence"
        case .ollama:      return "Ollama qwen-coder"
        case .claudeHaiku: return "Claude Haiku (Cloud)"
        case .grok:        return "xAI Grok (Cloud)"
        case .gemini:      return "Google Gemini (Cloud)"
        case .groq:        return "Groq (Cloud)"
        case .mistral:     return "Mistral (Cloud)"
        case .cerebras:    return "Cerebras (Cloud)"
        case .codex:       return "Codex / OpenAI (Cloud)"
        case .copilot:     return "GitHub Copilot (Cloud)"
        }
    }
    var subtitle: String {
        switch self {
        case .auto:        return "Apple if available, otherwise Ollama"
        case .apple:       return "On-device · lightweight · 15-agent pipeline"
        case .ollama:      return "Local · heavier · single-agent for safety"
        case .claudeHaiku: return "Cloud · fast · ~zero local RAM · needs API key"
        case .grok:        return "Cloud · deepest reasoning · ~zero local RAM · needs API key"
        case .gemini:      return "Cloud · generous free tier · ~zero local RAM · needs API key"
        case .groq:        return "Cloud · blazing-fast Llama · ~zero local RAM · needs API key"
        case .mistral:     return "Cloud · EU-hosted · ~zero local RAM · needs API key"
        case .cerebras:    return "Cloud · ~2000 tok/s Llama · ~zero local RAM · needs API key"
        case .codex:       return "Cloud · OpenAI GPT · ~zero local RAM · needs API key"
        case .copilot:     return "Cloud · your Copilot sub · ~zero local RAM · sign in with GitHub"
        }
    }
    var icon: String {
        switch self {
        case .auto:        return "sparkles"
        case .apple:       return "apple.logo"
        case .ollama:      return "cpu"
        case .claudeHaiku: return "cloud.fill"
        case .grok:        return "bolt.horizontal.circle.fill"
        case .gemini:      return "diamond.fill"
        case .groq:        return "hare.fill"
        case .mistral:     return "leaf.circle.fill"
        case .cerebras:    return "rays"
        case .codex:       return "chevron.left.forwardslash.chevron.right"
        case .copilot:     return "person.2.badge.gearshape.fill"
        }
    }
}

/// Detects the Mac's capability to recommend a performance tier.
enum MachineInfo {
    static var memoryGB: Int {
        Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824).rounded())
    }
    static var cores: Int { ProcessInfo.processInfo.processorCount }

    static var summary: String { "\(memoryGB) GB RAM · \(cores) cores" }

    static var recommendedMode: AppSettings.ResponseMode {
        if memoryGB >= 24 && cores >= 10 { return .full }      // powerful Mac
        if memoryGB >= 16 { return .balanced }
        return .fast                                            // lighter Mac
    }
}
