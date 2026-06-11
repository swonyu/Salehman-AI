import Foundation

// MARK: - Brain routing plan (pure seam)
//
// CODEBASE_REVIEW R1: the single biggest maintainability hazard was that WHO
// can answer (gating), WHO is in each roster (membership), and in WHAT order
// were re-implemented across 11 sites in LocalLLM (`generate` /
// `generateStreaming` / `chat` cascades, `currentBrain`, `anyBrainReachable`,
// the freeAuto / freeAuto-tools / freeCoding / cloudCoding / ensemble
// rosters) — and the drift class was producing real bugs (the Offline-Mode
// cloud leak fixed alongside this file; the ensemble/DeepSeek mismatch noted
// below). This file is now the ONLY place routing decisions live. The
// LocalLLM call sites keep their per-provider execution quirks (which client
// call, which system prompt, stream-then-chat fallback) but consume the plan
// for every decision. Pure — no syscalls, no network — hermetically pinned by
// `BrainRoutingDispatchTests`.

/// The ten cloud chat providers the router can pin or roster. Raw values are
/// stable display-ish names used by the freeAuto cooldown bookkeeping.
nonisolated enum CloudProvider: String, CaseIterable, Sendable {
    case anthropic = "Claude"
    case grok = "Grok"
    case gemini = "Gemini"
    case groq = "Groq"
    case mistral = "Mistral"
    case cerebras = "Cerebras"
    case deepSeek = "DeepSeek"
    case openAI = "OpenAI"
    case copilot = "Copilot"
    case openRouter = "OpenRouter"

    /// FREE tiers in the canonical race order — the ONLY providers `.freeAuto`
    /// may contact (this mode never spends; paid brains are excluded by
    /// construction, not by remembering to skip them at each site).
    static let freeTier: [CloudProvider] = [.groq, .cerebras, .gemini, .mistral, .openRouter]

    /// The free OpenAI-compatible providers that can run the TOOL loop
    /// (Gemini is free but not OpenAI-compat, so it can't run tools).
    static let freeToolCapable: [CloudProvider] = [.groq, .cerebras, .mistral, .openRouter]

    /// FreeCoding RACE order (parallel; DeepSeek opted in by the owner).
    static let codingRace: [CloudProvider] = [.deepSeek, .openRouter, .groq, .cerebras, .mistral]

    /// Sequential coder-loop order shared by freeCodingReply / cloudCoding —
    /// quality+speed order (DeepSeek smartest → Cerebras/Groq blazing →
    /// OpenRouter → Mistral).
    static let coderLoop: [CloudProvider] = [.deepSeek, .cerebras, .groq, .openRouter, .mistral]

    /// Ensemble fan-out membership, in output order. ⚠️ Documented drift,
    /// PRESERVED on purpose: DeepSeek is counted by `anyBrainReachable` but
    /// was never added to the ensemble roster (so a DeepSeek-only setup reads
    /// "reachable" yet fans out to nothing). Flagged to the owner — adding
    /// `.deepSeek` here is the one-line fix if wanted.
    static let ensembleRoster: [CloudProvider] = [.anthropic, .grok, .gemini, .groq,
                                                  .mistral, .cerebras, .openAI,
                                                  .openRouter, .copilot]

    var isFree: Bool { Self.freeTier.contains(self) }

    /// The BrainPreference pin this provider answers to.
    var pin: BrainPreference {
        switch self {
        case .anthropic:  return .claudeHaiku
        case .grok:       return .grok
        case .gemini:     return .gemini
        case .groq:       return .groq
        case .mistral:    return .mistral
        case .cerebras:   return .cerebras
        case .deepSeek:   return .deepSeek
        case .openAI:     return .codex
        case .copilot:    return .copilot
        case .openRouter: return .openRouter
        }
    }

    /// Reverse map: the provider a pinned cloud preference dispatches to
    /// (nil for local pins, engines, and orchestration modes).
    static func provider(for pref: BrainPreference) -> CloudProvider? {
        allCases.first { $0.pin == pref }
    }

    /// The `LocalLLM.Brain` case this provider reports as.
    var brain: LocalLLM.Brain {
        switch self {
        case .anthropic:  return .claudeHaiku
        case .grok:       return .grok
        case .gemini:     return .gemini
        case .groq:       return .groq
        case .mistral:    return .mistral
        case .cerebras:   return .cerebras
        case .deepSeek:   return .deepSeek
        case .openAI:     return .codex
        case .copilot:    return .copilot
        case .openRouter: return .openRouter
        }
    }

    /// Live "has a key / is authed" check — THE one place the ten per-client
    /// key checks live (was copy-pasted in anyBrainReachable, currentBrain,
    /// every roster builder, and the Settings grid).
    var isConfiguredNow: Bool {
        switch self {
        case .anthropic:  return AnthropicClient.isConfigured
        case .grok:       return GrokClient.hasKey()
        case .gemini:     return GeminiClient.hasKey()
        case .groq:       return GroqClient.shared.hasKey()
        case .mistral:    return MistralClient.shared.hasKey()
        case .cerebras:   return CerebrasClient.shared.hasKey()
        case .deepSeek:   return DeepSeekClient.shared.hasKey()
        case .openAI:     return OpenAIClient.hasKey()
        case .copilot:    return CopilotClient.isAuthed()
        case .openRouter: return OpenRouterClient.shared.hasKey()
        }
    }

    /// Snapshot of every configured provider (10 sync Keychain/auth checks).
    static func configuredNow() -> Set<CloudProvider> {
        Set(allCases.filter(\.isConfiguredNow))
    }

    /// The user-selected chat model id from Settings, for providers that
    /// expose one (Anthropic / Copilot manage their model inside the client).
    /// Centralizes the `AppSettings.*ModelCurrent` reads that were repeated
    /// at every roster/ladder site.
    var selectedModel: String? {
        switch self {
        case .grok:       return AppSettings.grokModelCurrent
        case .gemini:     return AppSettings.geminiModelCurrent
        case .groq:       return AppSettings.groqModelCurrent
        case .mistral:    return AppSettings.mistralModelCurrent
        case .cerebras:   return AppSettings.cerebrasModelCurrent
        case .deepSeek:   return AppSettings.deepSeekModelCurrent
        case .openAI:     return AppSettings.openAIModelCurrent
        case .openRouter: return AppSettings.openRouterModelCurrent
        case .anthropic, .copilot: return nil
        }
    }

    /// Coder-model roster for the coding loops (`LocalLLM.freeCoderModel`
    /// picks the most coding-leaning entry). Only the OpenAI-compat coders.
    var coderModels: (all: [String], def: String)? {
        switch self {
        case .deepSeek:   return (DeepSeekClient.allModels, DeepSeekClient.defaultModel)
        case .cerebras:   return (CerebrasClient.allModels, CerebrasClient.defaultModel)
        case .groq:       return (GroqClient.allModels, GroqClient.defaultModel)
        case .openRouter: return (OpenRouterClient.allModels, OpenRouterClient.defaultModel)
        case .mistral:    return (MistralClient.allModels, MistralClient.defaultModel)
        case .anthropic, .grok, .gemini, .openAI, .copilot: return nil
        }
    }

    /// The shared OpenAI-compatible client for tool-loop execution, where one
    /// exists (Anthropic / Gemini / Copilot use bespoke clients → nil).
    var compatClient: OpenAICompatibleClient? {
        switch self {
        case .groq:       return GroqClient.shared
        case .mistral:    return MistralClient.shared
        case .cerebras:   return CerebrasClient.shared
        case .deepSeek:   return DeepSeekClient.shared
        case .openAI:     return OpenAIClient.shared
        case .openRouter: return OpenRouterClient.shared
        case .anthropic, .gemini, .copilot, .grok: return nil
        }
    }
}

/// Immutable snapshot of every signal a routing decision can depend on.
/// Tests construct it directly (pure, no keys, no network); production uses
/// `live()` which probes lazily per-preference, mirroring the old
/// `currentBrain` (e.g. no Ollama HTTP probe when a cloud brain is pinned —
/// BrainStatus polls this every 10s).
nonisolated struct BrainRouteConfig: Sendable {
    var pref: BrainPreference
    var offlineOnly = false
    var configured: Set<CloudProvider> = []
    var ollamaReady = false          // server up + a coder model pulled
    var salehmanCloudReady = false   // SalehmanEngine.hasAnyCloud
    var mlxReady = false
    var ollamaHasCustomModel = false
    var unslothConfigured = false
    var vllmConfigured = false

    /// Live snapshot. Async probes run only when the pinned preference's
    /// reachability rule actually consults them.
    static func live() async -> BrainRouteConfig {
        let pref = AppSettings.brainPreferenceCurrent
        var c = BrainRouteConfig(pref: pref, offlineOnly: AppSettings.isOfflineOnly)
        c.configured = CloudProvider.configuredNow()
        c.unslothConfigured = UnslothStudio.isConfigured
        c.vllmConfigured = VLLM.isConfigured
        c.salehmanCloudReady = SalehmanEngine.hasAnyCloud
        switch pref {
        case .auto, .ollama, .ensemble, .freeAuto, .freeCoding:
            c.ollamaReady = await LocalLLM.ollamaReady()
        case .salehman:
            // Same short-circuit order as the old currentBrain: the cloud
            // check is free; the MLX/custom-model probes only run without it.
            if !c.salehmanCloudReady {
                c.mlxReady = await MLXSalehmanEngine.shared.isReady
                if !c.mlxReady {
                    c.ollamaHasCustomModel = await OllamaClient.hasCustomModel()
                }
            }
        default:
            break
        }
        return c
    }
}

/// THE routing plan. Every function is pure over a `BrainRouteConfig` (or the
/// pin alone, for dispatch). If a routing rule changes, change it HERE and
/// pin it in `BrainRoutingDispatchTests` — the LocalLLM sites only execute.
nonisolated enum BrainRouting {

    // MARK: Dispatch (the single pinned target for generate / streaming / chat)

    enum Dispatch: Equatable, Sendable {
        case mode(BrainPreference)   // .freeAuto / .freeCoding / .cloudCoding / .ensemble
        case cloud(CloudProvider)    // a pinned cloud brain (strict — no fallback)
        case salehman                // the cloud-first engine with a local floor
        case unslothStudio           // explicit endpoint pin
        case vllm                    // explicit endpoint pin
        case localTier               // .auto / .ollama → Ollama
        case unavailable             // offline-gated cloud pin → offMessage
    }

    /// Exactly one target per preference — the cascades of pin-gates this
    /// replaces were single-dispatch ladders in disguise. Offline Mode is the
    /// stronger constraint and hard-gates the ten cloud pins here (the fix
    /// for the Offline leak: `currentBrain` always documented this contract,
    /// but the generate/streaming/chat cascades never enforced it, so direct
    /// callers leaked HTTP — and money, via paid pins — while "offline").
    /// Orchestration modes pass through: they gate their own rosters.
    /// `.salehman` passes through: the engine gates its own chain (and its
    /// local floor must keep answering offline). Endpoint pins pass through
    /// unchanged — `currentBrain` documents them as untouched by Offline
    /// Mode (open owner question for REMOTE endpoints, flagged in the log).
    static func dispatch(pref: BrainPreference, offlineOnly: Bool) -> Dispatch {
        switch pref {
        case .freeAuto, .freeCoding, .cloudCoding, .ensemble:
            return .mode(pref)
        case .auto, .ollama:
            return .localTier
        case .salehman:
            return .salehman
        case .unslothStudio:
            return .unslothStudio
        case .vllm:
            return .vllm
        case .claudeHaiku, .grok, .gemini, .groq, .mistral, .cerebras,
             .deepSeek, .codex, .copilot, .openRouter:
            guard let p = CloudProvider.provider(for: pref) else { return .unavailable }
            return offlineOnly ? .unavailable : .cloud(p)
        }
    }

    // MARK: Rosters (execution membership — offline empties every cloud roster)

    /// Free·Auto race roster. Offline → empty (the local backstop is the
    /// mode's own job); paid providers excluded by construction.
    static func freeAutoRoster(_ c: BrainRouteConfig) -> [CloudProvider] {
        c.offlineOnly ? [] : CloudProvider.freeTier.filter { c.configured.contains($0) }
    }

    /// Free·Auto TOOL-loop roster (Unrestricted Mode): the free
    /// OpenAI-compatible providers only.
    static func freeAutoToolRoster(_ c: BrainRouteConfig) -> [CloudProvider] {
        c.offlineOnly ? [] : CloudProvider.freeToolCapable.filter { c.configured.contains($0) }
    }

    /// FreeCoding RACE roster (parallel; includes DeepSeek).
    static func codingRaceRoster(_ c: BrainRouteConfig) -> [CloudProvider] {
        c.offlineOnly ? [] : CloudProvider.codingRace.filter { c.configured.contains($0) }
    }

    /// Sequential coder-loop roster (freeCodingReply / cloudCoding paths).
    static func coderLoopRoster(_ c: BrainRouteConfig) -> [CloudProvider] {
        c.offlineOnly ? [] : CloudProvider.coderLoop.filter { c.configured.contains($0) }
    }

    /// Ensemble cloud fan-out membership (local inclusion is the call site's
    /// RAM-guard decision). Offline → empty (ensemble runs local-only).
    static func ensembleCloudRoster(_ c: BrainRouteConfig) -> [CloudProvider] {
        c.offlineOnly ? [] : CloudProvider.ensembleRoster.filter { c.configured.contains($0) }
    }

    // MARK: Reachability (the pure currentBrain)

    /// True iff at least one brain (local or any keyed cloud) can answer.
    /// NOTE: deliberately ignores Offline Mode, exactly like the function it
    /// replaces — ensemble stays "reachable" offline and runs local-only.
    static func anyBrainReachable(_ c: BrainRouteConfig) -> Bool {
        c.ollamaReady || !c.configured.isEmpty
    }

    /// The pure `currentBrain` switch. Offline hard-gates the ten cloud pins
    /// to `.none`; local pins, engines, and orchestration modes apply their
    /// own rules (verbatim from the old implementation).
    static func reachableBrain(_ c: BrainRouteConfig) -> LocalLLM.Brain {
        if c.offlineOnly, CloudProvider.provider(for: c.pref) != nil { return .none }

        switch c.pref {
        case .ollama, .auto:
            return c.ollamaReady ? .ollamaCoder : .none
        case .salehman:
            if c.salehmanCloudReady { return .salehman }
            if c.mlxReady { return .salehman }
            if c.ollamaHasCustomModel { return .salehman }
            return .none
        case .unslothStudio:
            return c.unslothConfigured ? .unslothStudio : .none
        case .vllm:
            return c.vllmConfigured ? .vllm : .none
        case .ensemble:
            return anyBrainReachable(c) ? .ensemble : .none
        case .freeAuto:
            // Reachability ignores Offline Mode (the roster empties instead,
            // leaving the local backstop) — verbatim old behavior.
            if CloudProvider.freeTier.contains(where: { c.configured.contains($0) }) { return .freeAuto }
            return c.ollamaReady ? .freeAuto : .none
        case .freeCoding:
            if CloudProvider.codingRace.contains(where: { c.configured.contains($0) }) { return .freeCoding }
            return c.ollamaReady ? .freeCoding : .none
        case .cloudCoding:
            // Cloud-ONLY: offline or keyless → .none (no local fallback).
            if c.offlineOnly { return .none }
            return CloudProvider.coderLoop.contains(where: { c.configured.contains($0) }) ? .cloudCoding : .none
        case .claudeHaiku, .grok, .gemini, .groq, .mistral, .cerebras,
             .deepSeek, .codex, .copilot, .openRouter:
            guard let p = CloudProvider.provider(for: c.pref) else { return .none }
            return c.configured.contains(p) ? p.brain : .none
        }
    }
}
