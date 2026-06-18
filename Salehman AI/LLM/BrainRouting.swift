import Foundation

// MARK: - Brain routing plan (pure seam)
//
// CODEBASE_REVIEW R1: the single biggest maintainability hazard was that WHO
// can answer (gating) and in WHAT order were re-implemented across the LocalLLM
// (`generate` / `generateStreaming` / `chat` cascades, `currentBrain`,
// `anyBrainReachable`) call sites — and the drift class was producing real bugs.
// This file is now the ONLY place routing decisions live. The LocalLLM call
// sites keep their per-brain execution quirks (which client call, which system
// prompt, stream-then-chat fallback) but consume the plan for every decision.
// Pure — no syscalls, no network — hermetically pinned by
// `BrainRoutingDispatchTests`.
//
// 2026-06-18: the app is now LOCAL-ONLY. All nine cloud chat providers and the
// four cloud-only composite modes (freeAuto / freeCoding / cloudCoding /
// ensemble) were removed — with them went `enum CloudProvider`, its rosters,
// and every cloud branch here. Routing targets are now exclusively local
// engines (Ollama, MLX/Salehman, vLLM, Unsloth Studio, the uncensored local
// model).

/// Immutable snapshot of every signal a routing decision can depend on.
/// Tests construct it directly (pure, no keys, no network); production uses
/// `live()` which probes lazily per-preference, mirroring the old
/// `currentBrain` (e.g. no Ollama HTTP probe when an endpoint engine is pinned —
/// BrainStatus polls this every 10s).
nonisolated struct BrainRouteConfig: Sendable {
    var pref: BrainPreference
    var offlineOnly = false
    var ollamaReady = false          // server up + a coder model pulled
    var uncensoredReady = false      // server up + the abliterated ~3B model pulled
    var mlxReady = false
    var ollamaHasCustomModel = false
    var unslothConfigured = false
    var vllmConfigured = false

    /// Live snapshot. Async probes run only when the pinned preference's
    /// reachability rule actually consults them.
    static func live() async -> BrainRouteConfig {
        let pref = AppSettings.brainPreferenceCurrent
        var c = BrainRouteConfig(pref: pref, offlineOnly: AppSettings.isOfflineOnly)
        // The endpoint-engine readiness checks are SYNCHRONOUS reads (UnslothStudio
        // / VLLM config). Keep them OFF-main so nothing can park the UI mid-send.
        // Both return Sendable values.
        let probes = await Task.detached(priority: .userInitiated) {
            (unsloth: UnslothStudio.isConfigured,
             vllm: VLLM.isConfigured)
        }.value
        c.unslothConfigured = probes.unsloth
        c.vllmConfigured = probes.vllm
        switch pref {
        case .auto, .ollama:
            c.ollamaReady = await LocalLLM.ollamaReady()
        case .uncensored:
            c.uncensoredReady = await OllamaClient.hasModel(OllamaClient.uncensoredModel)
        case .salehman:
            // Same short-circuit order as the old currentBrain, minus the cloud
            // gate (Salehman is local-only — SalehmanEngine.hasAnyCloud == false):
            // MLX first, then the Ollama custom-model floor.
            c.mlxReady = await MLXSalehmanEngine.shared.isReady
            if !c.mlxReady {
                c.ollamaHasCustomModel = await OllamaClient.hasCustomModel()
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
        case salehman                // the local Salehman engine (vLLM → Unsloth → MLX → Ollama)
        case unslothStudio           // explicit endpoint pin
        case vllm                    // explicit endpoint pin
        case localTier               // .auto / .ollama → Ollama
        case uncensoredLocal         // .uncensored → Ollama, forced abliterated ~3B (web-search capable)
    }

    /// Exactly one target per preference. Every target is local, so Offline
    /// Mode no longer gates anything here — the local engines all keep
    /// answering offline (their web tools self-gate on ToolPolicy). The
    /// `offlineOnly` parameter is retained for signature stability and future
    /// remote-endpoint gating, but currently unused.
    static func dispatch(pref: BrainPreference, offlineOnly: Bool) -> Dispatch {
        switch pref {
        case .auto, .ollama:
            return .localTier
        case .uncensored:
            // Local (Ollama) — the web tools self-gate on ToolPolicy.
            return .uncensoredLocal
        case .salehman:
            return .salehman
        case .unslothStudio:
            return .unslothStudio
        case .vllm:
            return .vllm
        }
    }

    // MARK: Reachability (the pure currentBrain)

    /// True iff at least one local brain can answer.
    static func anyBrainReachable(_ c: BrainRouteConfig) -> Bool {
        c.ollamaReady
            || c.uncensoredReady
            || c.mlxReady
            || c.ollamaHasCustomModel
            || c.unslothConfigured
            || c.vllmConfigured
    }

    /// The pure `currentBrain` switch. Local pins and engines apply their own
    /// readiness rules (verbatim from the old implementation, minus the deleted
    /// cloud/composite arms).
    static func reachableBrain(_ c: BrainRouteConfig) -> LocalLLM.Brain {
        switch c.pref {
        case .ollama, .auto:
            return c.ollamaReady ? .ollamaCoder : .none
        case .uncensored:
            return c.uncensoredReady ? .uncensored : .none
        case .salehman:
            // Local floor: MLX on-device, or the Ollama custom model.
            if c.mlxReady { return .salehman }
            if c.ollamaHasCustomModel { return .salehman }
            return .none
        case .unslothStudio:
            return c.unslothConfigured ? .unslothStudio : .none
        case .vllm:
            return c.vllmConfigured ? .vllm : .none
        }
    }
}
