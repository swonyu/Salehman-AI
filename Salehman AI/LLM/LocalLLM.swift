import Foundation
import OSLog

/// Brain routing for Salehman AI. Salehman runs CLOUD-FIRST (free DeepSeek V4 via
/// NVIDIA → free frontier/120B tiers → DeepSeek paid backstop) with a LOCAL floor
/// (Ollama / on-device MLX) for offline use. No Apple Intelligence.
enum LocalLLM {
    /// Profiling signposter. Capture a trace in **Instruments → Time Profiler +
    /// "Points of Interest"** (or `os_signpost` instrument) and the `freeAuto` /
    /// `ensemble` intervals below show real per-call brain latency — turning the
    /// review's *estimated* perf numbers into measured ones. Zero overhead when
    /// not being traced. See `VERIFICATION.md`.
    nonisolated static let signposter = OSSignposter(subsystem: "com.salehman.ai", category: "Brain")
    // All of these are `nonisolated` so actor-isolated callers (ChatSession,
    // AgentPipeline tasks, the Ollama-fallback path) can probe brain
    // availability without hopping to the main actor. The underlying APIs are
    // thread-safe — there's no shared mutable state behind any of them.
    /// True when *some* brain can answer: a local Ollama model, an on-device MLX
    /// Salehman engine, or any configured cloud key. Used by the pipeline to rate
    /// an outcome. (Formerly gated on Apple Intelligence availability.)
    nonisolated static var isAvailable: Bool {
        SalehmanEngine.hasAnyCloud
            || OpenAIClient.hasKey() || AnthropicClient.isConfigured || GrokClient.hasKey()
            || GeminiClient.hasKey() || CopilotClient.isAuthed()
    }

    /// **Sentinel** returned by the chat pipeline when no brain can answer.
    ///
    /// This MUST stay a deterministic constant — never a computed property —
    /// because two callers rely on it as an equality marker:
    ///   * `LocalLLM.synthesize(...)` uses `refined == offMessage` to detect
    ///     that synthesis failed and fall back to the draft.
    ///   * `SettingsView` uses `reply == LocalLLM.offMessage` to short-circuit
    ///     a "Test connection" success path.
    ///
    /// A "deterministic-per-preference" computed variant would silently
    /// break those checks the moment the user toggles `brainPreference`
    /// between the call that returned the value and the call that compares
    /// against it. The previous version of this property fell into exactly
    /// that trap — it's been restored to a `let` to make the contract
    /// explicit again.
    ///
    /// For the context-aware text we *display* (rather than return as a
    /// sentinel), see `unavailableMessage` below.
    nonisolated static let offMessage =
        "No model is reachable right now. Add a free cloud key (NVIDIA / Groq / Cerebras / OpenRouter) in Settings → Brain, or start the Ollama server (`ollama serve`) with a model pulled."

    /// Context-aware UI-facing text describing why the currently-pinned brain
    /// can't answer. Names the brain the user actually selected and the exact
    /// remedy, so we never point them at the wrong fix when a *different* pinned
    /// brain is the thing that's down.
    ///
    /// **Not safe for equality comparison** — value depends on
    /// `AppSettings.brainPreferenceCurrent` and changes when the user
    /// toggles. Use `offMessage` (above) for `==` checks; use this only
    /// for display.
    nonisolated static var unavailableMessage: String {
        let pref = AppSettings.brainPreferenceCurrent
        switch pref {
        case .auto:
            return "No model is reachable right now. Add a free cloud key (NVIDIA / Groq / Cerebras / OpenRouter) in Settings, or start the Ollama server (`ollama serve`) with a model pulled."
        case .ollama:
            return "Ollama qwen-coder is your selected brain, but the Ollama server isn't reachable. Start it with `ollama serve` (with qwen2.5-coder pulled), or switch to Auto in Settings."
        case .copilot:
            return "GitHub Copilot is your selected brain, but you're not signed in. Sign in under Settings → GitHub Copilot, or switch brains."
        case .ensemble:
            return "\"All Brains at Once\" is selected, but none are reachable. Start Ollama, or add at least one cloud API key in Settings."
        case .freeAuto:
            return "\"Free · Auto\" is selected, but no free brain is reachable. Add a free key (Groq / Gemini / Cerebras / OpenRouter) in Settings, or start Ollama."
        case .freeCoding:
            return "\"FreeCoding\" is selected, but no coder brain is reachable. Add a key (DeepSeek / OpenRouter / Groq / Cerebras / Mistral) in Settings, or start Ollama with qwen2.5-coder."
        case .cloudCoding:
            return AppSettings.isOfflineOnly
                ? "\"Cloud Coding\" is cloud-only, but Offline Mode is on. Turn Offline Mode off in Settings, or pick the local Ollama brain."
                : "\"Cloud Coding\" is selected, but no cloud coder key is saved. Add a key for DeepSeek / Cerebras / Groq / OpenRouter / Mistral in Settings — it's cloud-only, so there's no local fallback."
        case .claudeHaiku, .grok, .gemini, .groq, .mistral, .cerebras, .deepSeek, .codex, .openRouter:
            return "\(pref.title) is your selected brain, but no API key is saved. Add one in Settings, or switch to another brain."
        case .salehman:
            return "Salehman runs on the cloud — add any free key in Settings (NVIDIA for REAL DeepSeek V4 free, or Groq / Cerebras / OpenRouter) and he leads on a big model at $0. To run fully on-device instead, pull your Ollama model (`ollama pull \(AppSettings.customModelNameCurrent)`) and start `ollama serve`."
        case .unslothStudio:
            return "Unsloth Studio is your selected brain, but its endpoint isn't reachable. Set the URL in Settings → Unsloth Studio (e.g. http://localhost:8000/v1) and make sure the server is running."
        case .vllm:
            return "vLLM is your selected brain, but its endpoint isn't reachable. Set the URL in Settings → vLLM (e.g. http://localhost:8000/v1) and make sure `vllm serve` is running."
        }
    }

    // `nonisolated` because actor-isolated callers (e.g. `ChatSession`) read
    // this for error messages. The underlying availability check is itself
    // thread-safe, so there's no shared state to guard.
    nonisolated static var statusNote: String {
        isAvailable ? "cloud/local brain configured" : "no brain configured"
    }

    /// True when the selected brain is one that USES a cloud key when present,
    /// but none is saved — so replies silently fall back to the slow local model
    /// (`.salehman` / `.freeAuto` / `.freeCoding`) or dead-end (`.cloudCoding`).
    /// Scoped to exactly those four: a pinned cloud brain already shows
    /// `unavailableMessage` (it returns `.none`, never a silent local fallback),
    /// and `.auto` / `.ollama` / `.unslothStudio` / `.vllm` are deliberately local
    /// — a cloud key wouldn't be used there, so nagging would be wrong. Drives the
    /// amber "add a cloud key" banner in the Chat / Code views so the slow path is
    /// never silent. Cheap Keychain-existence check; safe to read each SwiftUI render.
    nonisolated static var lacksCloudKey: Bool {
        switch AppSettings.brainPreferenceCurrent {
        case .salehman, .freeAuto, .freeCoding:
            return !SalehmanEngine.hasAnyCloud
        case .cloudCoding:
            // Cloud Coding uses its OWN curated coder roster (DeepSeek/Cerebras/Groq/
            // OpenRouter/Mistral), NOT the standalone Gemini/Claude keys — so the
            // accurate check is that roster's reachability. Otherwise the banner would
            // wrongly hide for a user whose only key is Gemini while Cloud Coding still
            // can't answer.
            return !cloudCodingReachable()
        default:
            return false
        }
    }

    /// One-line, actionable nudge for the `lacksCloudKey` banner. Honest across
    /// all four modes (slow local fallback for three, unavailable for cloudCoding).
    nonisolated static let noCloudKeyHint =
        "No cloud key — replies are slow (local fallback) or unavailable. Add a free Groq or Cerebras key in Settings → Brain for ~1-second answers."

    /// Identifies which brain handled (or would handle) a request. Used by the
    /// UI to label the current state honestly.
    nonisolated enum Brain: Equatable {
        case ollamaCoder
        case salehman                                // Salehman — cloud-first, local floor
        case unslothStudio                           // local OpenAI-compat server (Unsloth Studio / mlx_lm.server / LM Studio)
        case vllm                                    // local OpenAI-compat server served by vLLM
        case claudeHaiku, grok                       // cloud, pre-existing
        case gemini, groq, mistral, cerebras         // cloud, free-tier
        case deepSeek                                // cloud, cheap + elite coder (OpenAI-compatible)
        case codex, copilot                          // cloud, OpenAI + GitHub Copilot
        case openRouter                              // cloud aggregator (free models)
        case ensemble                                // all reachable brains in parallel
        case freeAuto                                // free brains raced; first valid wins; local backstop
        case freeCoding                              // free coders + DeepSeek raced, tool-capable, coding-focused
        case cloudCoding                             // CLOUD-ONLY best coders, tool-capable (no local, no lag)
        case none
    }

    /// Best brain available right now, honoring the user's `BrainPreference`:
    ///   * `.ollama` → return Ollama qwen-coder if reachable, else `.none`.
    ///   * `.auto`   → local-first: Ollama qwen-coder when the server is up.
    /// Returning `.none` short-circuits the pipeline with the canonical
    /// "no brain reachable" message instead of silently using the other side.
    static func currentBrain() async -> Brain {
        let pref = AppSettings.brainPreferenceCurrent

        // Offline Mode hard-gates every cloud pref to `.none` so the UI shows a
        // clear "Offline is on" hint instead of silently degrading. Local pins
        // (`.ollama`, `.auto`) and the orchestration modes (`.ensemble`,
        // `.freeAuto`) stay reachable — they gate their own cloud roster.
        if AppSettings.isOfflineOnly {
            switch pref {
            case .claudeHaiku, .grok, .gemini, .groq, .mistral, .cerebras, .deepSeek, .codex, .copilot, .openRouter:
                return .none
            default:
                break
            }
        }

        switch pref {
        // Local tier (Ollama): a pinned local brain that's down dead-ends to
        // `.none` with a clear hint. (Cloud pins below stay strict.)
        case .ollama:
            if await ollamaReady() { return .ollamaCoder }
            return .none

        case .salehman:
            // Salehman is CLOUD-FIRST now: reachable if ANY cloud engine is set
            // (a hosted endpoint or any free/paid key) — so he works with NO local
            // model installed — else the on-device engines for offline use. The
            // persona is the brand; the engine underneath is internal.
            if SalehmanEngine.hasAnyCloud { return .salehman }
            if await MLXSalehmanEngine.shared.isReady { return .salehman }
            if await OllamaClient.hasCustomModel() { return .salehman }
            return .none

        case .unslothStudio:
            // Local OpenAI-compatible server (Unsloth Studio / mlx_lm.server / LM
            // Studio / llama.cpp). We do NOT probe the URL here — that would
            // burn an HTTP request every 10s during `BrainStatus` polling. The
            // "configured" check (endpoint URL is non-empty) is enough for the
            // header dot; a real call will surface unreachability later.
            return UnslothStudio.isConfigured ? .unslothStudio : .none

        case .vllm:
            // Same rationale as Unsloth Studio: don't probe the URL here (would
            // burn an HTTP call every 10s while BrainStatus polls). "Configured"
            // (endpoint set) is enough for the dot; a real call surfaces failure.
            return VLLM.isConfigured ? .vllm : .none

        // Cloud brains: "reachable" simply means the user has entered a key.
        // We never probe the network here — that would burn an HTTP request
        // every 10s while BrainStatus polls.
        case .claudeHaiku: return AnthropicClient.isConfigured ? .claudeHaiku : .none
        case .grok:        return GrokClient.hasKey()          ? .grok        : .none
        case .gemini:      return GeminiClient.hasKey()        ? .gemini      : .none
        case .groq:        return GroqClient.shared.hasKey()   ? .groq        : .none
        case .mistral:     return MistralClient.shared.hasKey()  ? .mistral    : .none
        case .cerebras:    return CerebrasClient.shared.hasKey() ? .cerebras   : .none
        case .deepSeek:    return DeepSeekClient.shared.hasKey() ? .deepSeek   : .none
        case .codex:       return OpenAIClient.hasKey()         ? .codex       : .none
        case .copilot:     return CopilotClient.isAuthed()      ? .copilot     : .none
        case .openRouter:  return OpenRouterClient.shared.hasKey() ? .openRouter : .none

        case .auto:
            // `.auto` stays strictly local-first: we never silently spend on
            // a cloud API. The user has to explicitly pin a cloud brain to
            // leave the Mac.
            if await ollamaReady() { return .ollamaCoder }
            return .none

        case .ensemble:
            // "All brains" is reachable iff *any* single brain is. The actual
            // fan-out happens in `generateEnsemble`; here we only decide
            // whether to short-circuit with the off-message.
            return await anyBrainReachable() ? .ensemble : .none

        case .freeAuto:
            // Reachable iff a *free* brain or a local brain can answer (paid
            // brains don't count — this mode never spends). The parallel race +
            // local backstop happens in `generateFreeAuto`.
            if GroqClient.shared.hasKey() || CerebrasClient.shared.hasKey()
                || GeminiClient.hasKey() || MistralClient.shared.hasKey()
                || OpenRouterClient.shared.hasKey() { return .freeAuto }
            if await ollamaReady() { return .freeAuto }
            return .none

        case .freeCoding:
            // Same reachability shape as Free·Auto, plus DeepSeek (the owner opted
            // it into this coding loop). Reachable iff any coder brain can answer.
            if DeepSeekClient.shared.hasKey() || GroqClient.shared.hasKey()
                || CerebrasClient.shared.hasKey() || MistralClient.shared.hasKey()
                || OpenRouterClient.shared.hasKey() { return .freeCoding }
            if await ollamaReady() { return .freeCoding }
            return .none

        case .cloudCoding:
            // Cloud-ONLY: reachable iff a cloud coder key is saved (no local
            // fallback). `cloudCodingReachable()` also respects Offline Mode.
            return cloudCodingReachable() ? .cloudCoding : .none
        }
    }

    /// True iff at least one brain (local or any keyed cloud) can answer.
    /// Used by ensemble mode to decide between fanning out and the off-message.
    nonisolated static func anyBrainReachable() async -> Bool {
        if await ollamaReady() { return true }
        return AnthropicClient.isConfigured || GrokClient.hasKey() || GeminiClient.hasKey()
            || GroqClient.shared.hasKey() || MistralClient.shared.hasKey()
            || CerebrasClient.shared.hasKey() || OpenAIClient.hasKey() || CopilotClient.isAuthed()
            || OpenRouterClient.shared.hasKey() || DeepSeekClient.shared.hasKey()
    }

    /// True when the user picked the "All Brains at Once" preference.
    nonisolated static var isEnsembleMode: Bool { AppSettings.brainPreferenceCurrent == .ensemble }

    // MARK: - Free · Auto (parallel race, never blocked)

    /// True when the user picked the "Free · Auto" preference.
    nonisolated static var isFreeAutoMode: Bool { AppSettings.brainPreferenceCurrent == .freeAuto }

    /// True when the user picked the "FreeCoding" preference — a coding-focused,
    /// tool-capable loop over the free coder brains + DeepSeek.
    nonisolated static var isFreeCodingMode: Bool { AppSettings.brainPreferenceCurrent == .freeCoding }

    /// True when the user picked "Cloud Coding" — a CLOUD-ONLY coding loop over the
    /// best cloud coders (no local model, so zero RAM / no lag).
    nonisolated static var isCloudCodingMode: Bool { AppSettings.brainPreferenceCurrent == .cloudCoding }

    /// Whether a reply is a real answer vs a brain saying "I can't right now".
    /// The clients wrap EVERY failure in a fully-bracketed `[…]` diagnostic, in
    /// two shapes:
    ///   • `[<Provider> error <status>: <msg>]`              (parsed non-2xx body)
    ///   • `[<Provider> request failed (HTTP <status>). …]`  (transport / unparsed)
    /// plus the on-device `[The on-device model couldn't complete …]`. ALL of
    /// these must LOSE the freeAuto race so a healthy sibling / local backstop
    /// wins — otherwise a fast 401 is shown to the user as their "answer" (the
    /// exact bug this guards: an earlier version only caught the word "error",
    /// so Mistral's "request failed" form slipped through and won).
    /// Requiring the WHOLE string to be bracketed (`[`…`]`) avoids false-
    /// rejecting a real markdown answer that merely starts with `[`.
    /// Substrings that mark a fully-bracketed `[…]` diagnostic as a failure (not a
    /// real answer). Extracted so the shapes live in one place — see the two
    /// client failure formats documented above.
    nonisolated static let freeAnswerErrorMarkers = ["error", "request failed", "(http ", "couldn't complete"]

    nonisolated static func isUsableFreeAnswer(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if t.hasPrefix("[") && t.hasSuffix("]") {
            let lower = t.lowercased()
            if freeAnswerErrorMarkers.contains(where: { lower.contains($0) }) { return false }
        }
        return true
    }

    /// Remembers which free brains failed recently so `generateFreeAuto` can
    /// SKIP them for a short window instead of wasting a round-trip on a
    /// known-bad key (e.g. a wrong/absent key that 401s, or a model that 404s).
    /// An `actor` → thread-safe by construction (no `nonisolated(unsafe)`). The
    /// window is short so a transient rate-limit self-heals; a success clears
    /// the mark immediately.
    /// Pure cooldown-window check, extracted from `FreeAutoCooldown` so the 120 s
    /// boundary is unit-testable without the actor or a real clock. A brain with
    /// no recorded failure is never cooling.
    nonisolated static func isStillCooling(failedAt: Date?, now: Date, window: TimeInterval = 120) -> Bool {
        guard let failedAt else { return false }
        return now.timeIntervalSince(failedAt) < window
    }

    actor FreeAutoCooldown {
        static let shared = FreeAutoCooldown()
        private var failedAt: [String: Date] = [:]
        private let window: TimeInterval = 120   // 2 minutes

        func cooling(_ names: [String], now: Date) -> Set<String> {
            Set(names.filter { LocalLLM.isStillCooling(failedAt: failedAt[$0], now: now, window: window) })
        }
        func recordFailure(_ name: String, now: Date) { failedAt[name] = now }
        func recordSuccess(_ name: String) { failedAt.removeValue(forKey: name) }
    }

    /// "Free · Auto": race every *configured free* cloud brain in parallel and
    /// return the FIRST usable answer — a rate-limited (429) or errored brain
    /// simply loses the race instead of blocking the user. If every free cloud
    /// brain fails (or none are configured), fall back to the LOCAL brains
    /// (Ollama) **sequentially** — never concurrently with
    /// the cloud calls, which preserves the 16 GB RAM guardrail (the same
    /// concurrent-local-model load that hard-froze the Mac). Local never
    /// rate-limits, so this is the "effectively unlimited / never blocked"
    /// guarantee: cloud when it's fast and available, local as the floor.
    ///
    /// "Free" = Groq, Cerebras, Gemini, Mistral, OpenRouter (the no-cost tiers).
    /// Paid brains (Claude, Grok, OpenAI, Copilot) are deliberately excluded so
    /// this mode can never spend money. A brain that just failed is skipped for
    /// a 2-min cooldown so a known-bad key doesn't cost a round-trip every turn.
    static func generateFreeAuto(_ prompt: String) async -> String {
        let sigState = signposter.beginInterval("freeAuto")
        defer { signposter.endInterval("freeAuto", sigState) }
        let sys = cloudSystemPrompt
        let now = Date()

        typealias Thunk = @Sendable () async -> String?
        var roster: [(name: String, run: Thunk)] = []
        if GroqClient.shared.hasKey() {
            let model = AppSettings.groqModelCurrent
            roster.append(("Groq", { await GroqClient.shared.chat(prompt: prompt, system: sys, model: model) }))
        }
        if CerebrasClient.shared.hasKey() {
            let model = AppSettings.cerebrasModelCurrent
            roster.append(("Cerebras", { await CerebrasClient.shared.chat(prompt: prompt, system: sys, model: model) }))
        }
        if GeminiClient.hasKey() {
            let model = AppSettings.geminiModelCurrent
            roster.append(("Gemini", { await GeminiClient.chat(prompt: prompt, system: sys, model: model) }))
        }
        if MistralClient.shared.hasKey() {
            let model = AppSettings.mistralModelCurrent
            roster.append(("Mistral", { await MistralClient.shared.chat(prompt: prompt, system: sys, model: model) }))
        }
        if OpenRouterClient.shared.hasKey() {
            let model = AppSettings.openRouterModelCurrent
            roster.append(("OpenRouter", { await OpenRouterClient.shared.chat(prompt: prompt, system: sys, model: model) }))
        }

        // Skip brains that failed within the cooldown window — don't waste a
        // round-trip on a known-bad key; they auto-retry once the window lapses.
        // Offline Mode is the STRONGER constraint: an empty active set forces the
        // function straight to the local backstop (Apple → Ollama), so no cloud
        // brain is even attempted regardless of keys / cooldown state.
        let cooling = await FreeAutoCooldown.shared.cooling(roster.map { $0.name }, now: now)
        let active = AppSettings.isOfflineOnly
            ? []
            : roster.filter { !cooling.contains($0.name) }

        // Race the active free cloud brains; first usable reply wins, cancel the
        // rest. Record per-brain failures/successes so the cooldown adapts.
        if !active.isEmpty {
            let winner = await withTaskGroup(of: (String, String?).self) { group -> String? in
                for entry in active { group.addTask { (entry.name, await entry.run()) } }
                for await (name, reply) in group {
                    if let reply, isUsableFreeAnswer(reply) {
                        await FreeAutoCooldown.shared.recordSuccess(name)
                        group.cancelAll()
                        return reply
                    } else {
                        await FreeAutoCooldown.shared.recordFailure(name, now: now)
                    }
                }
                return nil
            }
            if let winner { return winner }
        }

        // Every free cloud brain failed / cooling / none configured → LOCAL
        // backstop, sequential (never concurrent with the cloud calls).
        if await ollamaReady(),
           let reply = await OllamaClient.chat(prompt: prompt, system: sys),
           isUsableFreeAnswer(reply) {
            return reply
        }

        return offMessage
    }

    /// Free·Auto WITH tools — used when Unrestricted Mode is on. Unlike the fast
    /// no-tool race in `generateFreeAuto`, this routes the turn through a
    /// tool-capable brain so Free·Auto can ACTUALLY run terminal commands / search
    /// the web (the owner asked Free·Auto to "do all commands"). Order: free local
    /// brains first (Ollama — free, private, strong with the terminal tool), then
    /// the free cloud OpenAI-compatible brains (now tool-capable), and finally a
    /// plain `generateFreeAuto` race so it never dead-ends. Inherits the SAME
    /// approval gate + blocked-command floor.
    static func freeAutoReplyWithTools(_ message: String) async -> String {
        // 1) Local, free, tool-capable.
        if await ollamaReady(), let reply = await ollamaReply(message) { return reply }
        // 2) Free cloud OpenAI-compatible brains — first one the user configured.
        //    Tool-capable via `chatOpenAICompatWithTools`. Skipped under Offline
        //    Mode (the stronger constraint), matching `generateFreeAuto`.
        if !AppSettings.isOfflineOnly {
            let free: [(client: OpenAICompatibleClient, model: String)] = [
                (GroqClient.shared,       AppSettings.groqModelCurrent),
                (CerebrasClient.shared,   AppSettings.cerebrasModelCurrent),
                (MistralClient.shared,    AppSettings.mistralModelCurrent),
                (OpenRouterClient.shared, AppSettings.openRouterModelCurrent),
            ]
            for entry in free where entry.client.hasKey() {
                if let reply = await chatOpenAICompatWithTools(client: entry.client,
                                                              model: entry.model,
                                                              message: message) {
                    return reply
                }
            }
        }
        // 3) Nothing tool-capable worked → the original fast race (no tools).
        return await generateFreeAuto(message)
    }

    // MARK: - FreeCoding (the free + DeepSeek coding loop)

    /// Coding-focused system prompt for FreeCoding mode — a free, tool-capable
    /// pair-programmer persona shared by the race path and the tool loop. The
    /// Unrestricted addendum is layered on top by callers via `applyUnrestricted`.
    nonisolated static let freeCodingSystem = """
    You are Salehman AI in FreeCoding mode — an elite, free pair-programmer on \
    this Mac, created by Saleh. Optimize for CODE: correct, complete, idiomatic, \
    modern, production-grade. No TODO / placeholder stubs; handle errors and edge \
    cases; pick the strongest solution, not the easiest. You can control this Mac: \
    call run_terminal_command to actually create/edit files, build, run, and TEST \
    code (`xcodebuild …`, `swift build`, `python …`, `npm …`) — don't just \
    describe a command, run it and report what happened. When web access is on, \
    use web_search / fetch_url for docs and APIs. Show code in fenced blocks with a \
    language tag. Lead with the answer or the code, keep surrounding prose tight, \
    and skip filler — be fast to read. CRITICAL LANGUAGE RULE: reply in the SAME \
    language as the user's latest message; never switch on your own.
    """

    /// Pick the most coding-leaning model from a brain's roster (qwen-coder /
    /// codestral / deepseek / gpt-oss / glm…), falling back to `def` when none
    /// stand out. Priority-ordered so a purpose-built coder beats a generalist.
    nonisolated static func freeCoderModel(_ models: [String], default def: String) -> String {
        let priority = ["codestral", "coder", "deepseek", "code", "gpt-oss", "glm"]
        for marker in priority {
            if let m = models.first(where: { $0.lowercased().contains(marker) }) { return m }
        }
        return def
    }

    /// FreeCoding RACE (no tools) — like `generateFreeAuto` but routes each free
    /// brain to its strongest CODING model + a coding system prompt, and adds
    /// DeepSeek (elite coder, cheap) to the roster per the owner's choice. First
    /// usable reply wins; local Ollama coder backstop. Used by
    /// direct callers; the chat pipeline uses the tool-capable `freeCodingReply`.
    static func generateFreeCoding(_ prompt: String) async -> String {
        let sigState = signposter.beginInterval("freeCoding")
        defer { signposter.endInterval("freeCoding", sigState) }
        let sys = applyUnrestricted(freeCodingSystem)
        let now = Date()

        typealias Thunk = @Sendable () async -> String?
        var roster: [(name: String, run: Thunk)] = []
        if DeepSeekClient.shared.hasKey() {
            let model = freeCoderModel(DeepSeekClient.allModels, default: DeepSeekClient.defaultModel)
            roster.append(("DeepSeek", { await DeepSeekClient.shared.chat(prompt: prompt, system: sys, model: model) }))
        }
        if OpenRouterClient.shared.hasKey() {
            let model = freeCoderModel(OpenRouterClient.allModels, default: OpenRouterClient.defaultModel)
            roster.append(("OpenRouter", { await OpenRouterClient.shared.chat(prompt: prompt, system: sys, model: model) }))
        }
        if GroqClient.shared.hasKey() {
            let model = freeCoderModel(GroqClient.allModels, default: GroqClient.defaultModel)
            roster.append(("Groq", { await GroqClient.shared.chat(prompt: prompt, system: sys, model: model) }))
        }
        if CerebrasClient.shared.hasKey() {
            let model = freeCoderModel(CerebrasClient.allModels, default: CerebrasClient.defaultModel)
            roster.append(("Cerebras", { await CerebrasClient.shared.chat(prompt: prompt, system: sys, model: model) }))
        }
        if MistralClient.shared.hasKey() {
            let model = freeCoderModel(MistralClient.allModels, default: MistralClient.defaultModel)
            roster.append(("Mistral", { await MistralClient.shared.chat(prompt: prompt, system: sys, model: model) }))
        }

        let cooling = await FreeAutoCooldown.shared.cooling(roster.map { $0.name }, now: now)
        let active = AppSettings.isOfflineOnly ? [] : roster.filter { !cooling.contains($0.name) }

        if !active.isEmpty {
            let winner = await withTaskGroup(of: (String, String?).self) { group -> String? in
                for entry in active { group.addTask { (entry.name, await entry.run()) } }
                for await (name, reply) in group {
                    if let reply, isUsableFreeAnswer(reply) {
                        await FreeAutoCooldown.shared.recordSuccess(name)
                        group.cancelAll()
                        return reply
                    } else {
                        await FreeAutoCooldown.shared.recordFailure(name, now: now)
                    }
                }
                return nil
            }
            if let winner { return winner }
        }

        // Local backstop — Ollama coder (best for code).
        if await ollamaReady(),
           let reply = await OllamaClient.chat(prompt: prompt, system: sys),
           isUsableFreeAnswer(reply) {
            return reply
        }
        return offMessage
    }

    /// FreeCoding WITH tools — what the chat pipeline runs. Routes through a
    /// tool-capable coder so it can actually write, build, run, and TEST code:
    /// free cloud coders + DeepSeek (DeepSeek first — the strongest) → local Ollama
    /// coder, then a plain `generateFreeCoding` race so
    /// it never dead-ends. Same approval gate + blocked-command floor as always.
    static func freeCodingReply(_ message: String) async -> String {
        let sys = applyUnrestricted(freeCodingSystem)
        // CLOUD CODERS FIRST — the fast, no-lag path. They run on someone else's
        // GPUs (ZERO local RAM, so they never thrash a MacBook) and are ~10× faster
        // than a multi-GB local model — AND smarter than a local 7B. Order balances
        // smarts + speed: DeepSeek (the owner's elite pick) → Cerebras / Groq
        // (blazing ~2000 tok/s, strong gpt-oss-120b) → OpenRouter → Mistral. Each
        // runs the tool loop so it can build / run / test. Skipped under Offline Mode.
        if !AppSettings.isOfflineOnly {
            let coders: [(client: OpenAICompatibleClient, models: [String], def: String)] = [
                (DeepSeekClient.shared,   DeepSeekClient.allModels,   DeepSeekClient.defaultModel),
                (CerebrasClient.shared,   CerebrasClient.allModels,   CerebrasClient.defaultModel),
                (GroqClient.shared,       GroqClient.allModels,       GroqClient.defaultModel),
                (OpenRouterClient.shared, OpenRouterClient.allModels, OpenRouterClient.defaultModel),
                (MistralClient.shared,    MistralClient.allModels,    MistralClient.defaultModel),
            ]
            for entry in coders where entry.client.hasKey() {
                let model = freeCoderModel(entry.models, default: entry.def)
                if let reply = await chatOpenAICompatWithTools(client: entry.client, model: model,
                                                              message: message, systemPrompt: sys) {
                    return reply
                }
            }
        }
        // LOCAL FALLBACK — only when no cloud coder answered (or Offline Mode is on):
        // free + private, but heavier on a laptop, so it's intentionally LAST to
        // avoid the RAM-load lag that prompted this reorder.
        if await ollamaReady(), let reply = await chatOllamaWithTools(message, systemPrompt: sys) { return reply }
        // Last resort → the plain race.
        return await generateFreeCoding(message)
    }

    // MARK: - Cloud Coding (cloud-only "best coders" loop — no local, no lag)

    /// The best cloud coders, in quality+speed order. Single source of truth for
    /// both the race (`generateCloudCoding`) and the tool loop (`cloudCodingReply`)
    /// so they can never drift. DeepSeek leads (smartest coder), then the blazing
    /// gpt-oss-120b on Cerebras/Groq, then OpenRouter's free qwen3-coder, then
    /// Mistral's codestral. `freeCoderModel` picks each brain's coding model.
    nonisolated static func cloudCoderRoster() -> [(client: OpenAICompatibleClient, models: [String], def: String)] {
        [
            (DeepSeekClient.shared,   DeepSeekClient.allModels,   DeepSeekClient.defaultModel),
            (CerebrasClient.shared,   CerebrasClient.allModels,   CerebrasClient.defaultModel),
            (GroqClient.shared,       GroqClient.allModels,       GroqClient.defaultModel),
            (OpenRouterClient.shared, OpenRouterClient.allModels, OpenRouterClient.defaultModel),
            (MistralClient.shared,    MistralClient.allModels,    MistralClient.defaultModel),
        ]
    }

    /// True iff any cloud coder is configured AND we're not offline — i.e. Cloud
    /// Coding can actually answer. No local fallback, so this is the honest gate.
    nonisolated static func cloudCodingReachable() -> Bool {
        guard !AppSettings.isOfflineOnly else { return false }
        return cloudCoderRoster().contains { $0.client.hasKey() }
    }

    /// Cloud Coding RACE (no tools): race every configured cloud coder in parallel
    /// on its coding model — first usable reply wins, the rest are cancelled. No
    /// local backstop (cloud-only by design). `offMessage` when none can answer.
    static func generateCloudCoding(_ prompt: String) async -> String {
        let sigState = signposter.beginInterval("cloudCoding")
        defer { signposter.endInterval("cloudCoding", sigState) }
        guard !AppSettings.isOfflineOnly else { return offMessage }
        let sys = applyUnrestricted(freeCodingSystem)
        let now = Date()

        typealias Thunk = @Sendable () async -> String?
        var roster: [(name: String, run: Thunk)] = []
        for entry in cloudCoderRoster() where entry.client.hasKey() {
            let client = entry.client
            let model = freeCoderModel(entry.models, default: entry.def)
            roster.append((client.displayName, { await client.chat(prompt: prompt, system: sys, model: model) }))
        }
        guard !roster.isEmpty else { return offMessage }

        let cooling = await FreeAutoCooldown.shared.cooling(roster.map { $0.name }, now: now)
        let active = roster.filter { !cooling.contains($0.name) }
        // If every coder is cooling, ignore the cooldown rather than dead-end — a
        // cloud-only mode has nothing else to fall back to.
        let toRun = active.isEmpty ? roster : active

        let winner = await withTaskGroup(of: (String, String?).self) { group -> String? in
            for entry in toRun { group.addTask { (entry.name, await entry.run()) } }
            for await (name, reply) in group {
                if let reply, isUsableFreeAnswer(reply) {
                    await FreeAutoCooldown.shared.recordSuccess(name)
                    group.cancelAll()
                    return reply
                } else {
                    await FreeAutoCooldown.shared.recordFailure(name, now: now)
                }
            }
            return nil
        }
        return winner ?? offMessage
    }

    /// Cloud Coding WITH tools — what the chat pipeline runs. Walks the best cloud
    /// coders in order and runs the FIRST configured one's tool loop (so it can
    /// build / run / test), falling back to the next on a transport error. No local
    /// fallback; a plain race is the final attempt. `offMessage` when nothing is
    /// reachable. Same approval gate + blocked-command floor as every other path.
    static func cloudCodingReply(_ message: String) async -> String {
        guard !AppSettings.isOfflineOnly else { return offMessage }
        let sys = applyUnrestricted(freeCodingSystem)
        for entry in cloudCoderRoster() where entry.client.hasKey() {
            let model = freeCoderModel(entry.models, default: entry.def)
            if let reply = await chatOpenAICompatWithTools(client: entry.client, model: model,
                                                          message: message, systemPrompt: sys) {
                return reply
            }
        }
        // Tool loops all errored (or none configured) → one plain race, then give up.
        let raced = await generateCloudCoding(message)
        return raced
    }

    /// Two-step probe (server up, then *some* preferred coder model present)
    /// hoisted out of `currentBrain` because three call sites use it. Uses
    /// `activeCodeModel()` so the user can have 7B *or* 14B *or* 32B and the
    /// app picks whichever is actually pulled — not just the sweet-spot 7B.
    nonisolated private static func ollamaReady() async -> Bool {
        guard await OllamaClient.isUp() else { return false }
        return await OllamaClient.activeCodeModel() != nil
    }

    /// Short label for the current brain, shown in the header subtitle.
    static func currentBrainLabel() async -> String {
        switch await currentBrain() {
        case .ollamaCoder:       return "Local · Ollama qwen-coder"
        case .salehman:          return SalehmanEngine.hasAnyCloud ? "Salehman · cloud" : "Salehman · on-device"
        case .unslothStudio:
            return UnslothStudio.isLocalLoopback
                ? "Local · Unsloth Studio (\(AppSettings.unslothStudioModelCurrent))"
                : "Custom server · Unsloth Studio (\(AppSettings.unslothStudioModelCurrent))"
        case .vllm:
            return VLLM.isLocalLoopback
                ? "Local · vLLM (\(AppSettings.vllmModelCurrent))"
                : "Custom server · vLLM (\(AppSettings.vllmModelCurrent))"
        case .claudeHaiku:       return "Cloud · Claude Haiku"
        case .grok:              return "Cloud · xAI \(AppSettings.grokModelCurrent)"
        case .gemini:            return "Cloud · Google \(AppSettings.geminiModelCurrent)"
        case .groq:              return "Cloud · Groq \(AppSettings.groqModelCurrent)"
        case .mistral:           return "Cloud · Mistral \(AppSettings.mistralModelCurrent)"
        case .cerebras:          return "Cloud · Cerebras \(AppSettings.cerebrasModelCurrent)"
        case .deepSeek:          return "Cloud · DeepSeek \(AppSettings.deepSeekModelCurrent)"
        case .codex:             return "Cloud · OpenAI \(AppSettings.openAIModelCurrent)"
        case .copilot:           return "Cloud · GitHub Copilot"
        case .openRouter:        return "Cloud · OpenRouter \(AppSettings.openRouterModelCurrent)"
        case .ensemble:          return "All brains · parallel"
        case .freeAuto:          return "Free · Auto (parallel, never blocked)"
        case .freeCoding:        return "FreeCoding · free coders + DeepSeek · runs the terminal"
        case .cloudCoding:       return "Cloud Coding · best cloud coders · no local, no lag"
        case .none:
            // Name the pinned-but-down brain so the header matches the chat message.
            switch AppSettings.brainPreferenceCurrent {
            case .ollama:  return "Ollama selected · not running"
            case .copilot: return "Copilot selected · sign in needed"
            case .salehman:
                // Cloud-first: the quickest fix is a free cloud key; on-device
                // (MLX standalone / Ollama) still works for offline use.
                if MLXSalehmanEngine.isPackageLinked {
                    return "Salehman selected · add a free cloud key (NVIDIA/Groq/…) in Settings, download the standalone engine, or pull \"\(AppSettings.customModelNameCurrent)\""
                } else {
                    return "Salehman selected · add a free cloud key (NVIDIA/Groq/…) in Settings, or pull \"\(AppSettings.customModelNameCurrent)\""
                }
            case .unslothStudio:
                // Different failure mode from the cloud brains — no key, just a
                // local URL the user has to set + a server that has to be running.
                return UnslothStudio.isConfigured
                    ? "Unsloth Studio · server unreachable"
                    : "Unsloth Studio · set endpoint URL in Settings"
            case .vllm:
                return VLLM.isConfigured
                    ? "vLLM · server unreachable"
                    : "vLLM · set endpoint URL in Settings"
            case .auto:    return "No brain available"
            default:       return "\(AppSettings.brainPreferenceCurrent.title) · API key needed"
            }
        }
    }

    /// Single accessor for the current preference. Used by every gate below
    /// — kept as a computed property (no caching) because callers expect to
    /// see the user's edits without restarting.
    nonisolated private static var pref: BrainPreference { AppSettings.brainPreferenceCurrent }

    // MARK: - Ensemble ("All Brains at Once")

    /// One brain's contribution to an ensemble answer. `text == nil` means the
    /// brain didn't respond (cloud clients return their own `[Provider error …]`
    /// string for HTTP errors, so that surfaces as text, not nil).
    struct EnsembleAnswer: Sendable, Equatable {
        let label: String
        let text: String?
    }

    /// Run EVERY reachable brain in parallel on the same prompt and return one
    /// combined, per-brain-labeled markdown answer. Reachability: Apple
    /// Intelligence (if active), Ollama (if a coder model is pulled), and each
    /// cloud brain that has a saved key. A brain that errors shows its error in
    /// its own section — one failure never sinks the others. Returns the
    /// off-message only when *nothing* is reachable.
    static func generateEnsemble(_ prompt: String) async -> String {
        let sigState = signposter.beginInterval("ensemble")
        defer { signposter.endInterval("ensemble", sigState) }
        let sys = cloudSystemPrompt
        let ollamaModel = await OllamaClient.activeCodeModel()

        // SAFETY: ensemble runs every reachable brain *concurrently*. Firing a
        // multi-GB local Ollama model at the same time as several cloud calls
        // is what froze a 16 GB Mac (RAM exhaustion → hard freeze). Ensemble's
        // value is comparing CLOUD answers anyway, so we only include the local
        // model on machines with comfortable headroom (≥ 24 GB). Below that,
        // ensemble is cloud-only and we note the skip in the output. (A user on
        // a small Mac who wants the local model should just pin Ollama directly
        // — one model, no concurrent cloud load.)
        let physicalGB = Int((Double(ProcessInfo.processInfo.physicalMemory) / Double(ByteConstants.bytesPerGB)).rounded())
        let includeLocal = physicalGB >= 24
        let skippedLocalForRAM = (ollamaModel != nil) && !includeLocal

        typealias Thunk = @Sendable () async -> String?
        var roster: [(String, Thunk)] = []

        if let m = ollamaModel, includeLocal {
            roster.append(("Ollama · \(m)", { await OllamaClient.chat(prompt: prompt, system: sys) }))
        }
        // Offline Mode skips ALL cloud brains so ensemble runs LOCAL-only (Ollama,
        // already appended above). Auto-scales — when the next cloud brain is
        // added, this single gate covers it.
        if !AppSettings.isOfflineOnly {
            if AnthropicClient.isConfigured {
                roster.append(("Claude Haiku", { await AnthropicClient.chat(prompt: prompt, system: sys) }))
            }
            if GrokClient.hasKey() {
                let model = AppSettings.grokModelCurrent
                roster.append(("xAI \(model)", { await GrokClient.chat(prompt: prompt, system: sys, model: model) }))
            }
            if GeminiClient.hasKey() {
                let model = AppSettings.geminiModelCurrent
                roster.append(("Google \(model)", { await GeminiClient.chat(prompt: prompt, system: sys, model: model) }))
            }
            if GroqClient.shared.hasKey() {
                let model = AppSettings.groqModelCurrent
                roster.append(("Groq \(model)", { await GroqClient.shared.chat(prompt: prompt, system: sys, model: model) }))
            }
            if MistralClient.shared.hasKey() {
                let model = AppSettings.mistralModelCurrent
                roster.append(("Mistral \(model)", { await MistralClient.shared.chat(prompt: prompt, system: sys, model: model) }))
            }
            if CerebrasClient.shared.hasKey() {
                let model = AppSettings.cerebrasModelCurrent
                roster.append(("Cerebras \(model)", { await CerebrasClient.shared.chat(prompt: prompt, system: sys, model: model) }))
            }
            if OpenAIClient.hasKey() {
                let model = AppSettings.openAIModelCurrent
                roster.append(("OpenAI \(model)", { await OpenAIClient.chat(prompt: prompt, system: sys, model: model) }))
            }
            if OpenRouterClient.shared.hasKey() {
                let model = AppSettings.openRouterModelCurrent
                roster.append(("OpenRouter \(model)", { await OpenRouterClient.shared.chat(prompt: prompt, system: sys, model: model) }))
            }
            if CopilotClient.isAuthed() {
                roster.append(("GitHub Copilot", { await CopilotClient.chat(prompt: prompt, system: sys) }))
            }
        }

        // Edge case: if the RAM guard skipped the local model and there are no
        // cloud brains, the roster is empty. Rather than dead-end, run Ollama
        // *solo* — alone it's a single inference (no concurrent cloud load), so
        // it's safe even on a small Mac.
        if roster.isEmpty {
            if let m = ollamaModel, let reply = await OllamaClient.chat(prompt: prompt, system: sys) {
                return "🧠 **All brains · 1/1 answered** (cloud brains not configured)\n\n### Ollama · \(m)\n\(reply)\n"
            }
            return offMessage
        }

        // Fan out. Each entry keeps its roster index so the combined output
        // preserves a stable order regardless of which brain finishes first.
        let collected = await withTaskGroup(of: (Int, EnsembleAnswer).self) { group -> [(Int, EnsembleAnswer)] in
            for (i, entry) in roster.enumerated() {
                group.addTask {
                    (i, EnsembleAnswer(label: entry.0, text: await entry.1()))
                }
            }
            var out: [(Int, EnsembleAnswer)] = []
            for await r in group { out.append(r) }
            return out
        }

        let ordered = collected.sorted { $0.0 < $1.0 }.map { $0.1 }
        var result = formatEnsemble(ordered)
        if skippedLocalForRAM {
            result += "\n_Local Ollama model skipped in ensemble to protect your "
                + "\(physicalGB) GB of RAM — pin Ollama directly to use it alone._\n"
        }
        return result
    }

    /// Format ensemble answers into one labeled markdown document. Pure (no I/O)
    /// → unit-testable. Each brain becomes a `### Label` section; a nil/empty
    /// reply renders as a clearly-marked "(no response)".
    nonisolated static func formatEnsemble(_ answers: [EnsembleAnswer]) -> String {
        let answered = answers.filter { ($0.text?.isEmpty == false) }.count
        var out = "🧠 **All brains · \(answered)/\(answers.count) answered**\n"
        for a in answers {
            out += "\n### \(a.label)\n"
            if let t = a.text, !t.isEmpty { out += t } else { out += "_(no response)_" }
            out += "\n"
        }
        return out
    }

    /// Shared system prompt for every cloud brain when used in single-turn
    /// `chat(...)`. Each cloud brain prints exactly the same constraints
    /// (no local tools, language-mirror reply, suggest-commands-as-text),
    /// so defining the string once prevents drift between providers.
    /// Base cloud prompt. `cloudSystemPrompt` (below) is what callers use — it
    /// appends the Unrestricted-mode directives when the owner has that on.
    nonisolated static let cloudSystemPromptBase = """
    You are Salehman AI — a fast, precise, deeply capable assistant. You reason \
    carefully, write excellent code, and always lead with the answer.

    LANGUAGE (critical): reply in the EXACT language the user wrote in. \
    English message → English only. Arabic message → Arabic only. \
    Never switch languages on your own.

    HOW TO RESPOND:
    • Lead with the answer. No preamble ("Great!", "Sure!", "Of course!"), \
    no trailing sign-offs ("Let me know if...").
    • Match length to complexity: a factual question gets one sentence; a hard \
    problem gets a thorough solution.
    • Markdown only when it genuinely helps: fenced code for code, bullet lists \
    for 3+ parallel items. No headers for replies under 5 lines.
    • When you write code: complete, correct, production-ready. No TODOs, no \
    placeholders, no simplified examples. Handle edge cases.
    • When you don't know: say so directly. Never fabricate.

    MEMORY: When you learn something durable about the user — their name, a \
    preference, how they like to work, their project context — use the \
    remember_fact tool to store it. This is how you get better for them over time.

    TOOLS: In this mode you have no terminal or web access. If a task needs \
    running a command, suggest the exact command as text.
    """

    /// Cloud system prompt, with the Unrestricted-mode addendum folded in when the
    /// owner has it enabled. Computed (not a `let`) so flipping the toggle takes
    /// effect on the next message without an app restart.
    nonisolated static var cloudSystemPrompt: String { applyUnrestricted(cloudSystemPromptBase) }

    // MARK: - Unrestricted Mode persona

    /// Extra system-prompt directives that take effect ONLY when the owner has
    /// turned on Unrestricted Mode. They make the assistant maximally helpful and
    /// stop it from gratuitously refusing / moralizing about the OWNER's lawful
    /// personal requests on his OWN machine — while keeping a hard floor that
    /// still declines genuinely illegal harm to other people. (The catastrophic-
    /// command block in `ToolPolicy.CommandRisk` is a separate, always-on floor.)
    nonisolated static let unrestrictedAddendum = """

    ## UNRESTRICTED MODE — owner's private machine
    This Mac belongs to Saleh — the sole owner, a consenting adult, and the only \
    user — and he has explicitly turned on Unrestricted Mode. Treat every request \
    as coming from him, in good faith, for his own lawful use. In this mode:
    • Be maximally helpful, open, and DIRECT. Just do what he asks. NEVER refuse, \
      lecture, moralize, warn, soften, or attach safety / ethics / legal \
      disclaimers to lawful personal requests. No "I can't help with that," no \
      "I'd advise caution," no watered-down "safe" partial answers — give the \
      complete, specific, real answer he asked for.
    • Lawful-but-sensitive topics are FAIR GAME for the owner: adult / NSFW \
      content and web searches, blunt or controversial opinions, profanity, \
      security research / reverse-engineering / pen-testing of HIS OWN systems and \
      software, and candid medical / legal / financial / harm-reduction \
      information. Inform him fully; do not gatekeep what an adult may know.
    • Read ambiguous requests charitably and ACT. Ask at most one short question, \
      and only if you genuinely cannot proceed without it.
    • USE your tools to actually finish the task (run_terminal_command runs real \
      commands on this Mac; web_search / fetch_url browse the web) instead of \
      describing what could be done.
    • Coding: think hard, then ship complete, correct, production-grade code — \
      idiomatic and modern, every edge case and error handled, NO TODO / \
      placeholder stubs. Pick the strongest solution, not the easiest, and build \
      + test it with the terminal when you can. High effort by default.
    • The ONLY hard limits — kept solely because they protect OTHER people — are: \
      no CSAM, no weapons capable of mass casualties, no malware or intrusion \
      against systems that aren't Saleh's, and no targeted harassment / doxxing of \
      real people. Everything else for the owner's own use: comply, fully and \
      without friction.
    """

    /// Append the Unrestricted-mode directives to `base` when the owner has
    /// Unrestricted Mode on; otherwise return `base` unchanged so normal mode
    /// keeps its usual guardrails and tone. Pure + nonisolated so every brain
    /// path (cloud, tool loops, Apple-Intelligence instructions) can share it.
    nonisolated static func applyUnrestricted(_ base: String) -> String {
        AppSettings.unrestrictedToolsEnabled ? base + "\n" + unrestrictedAddendum : base
    }

    /// System prompt for Ollama in single-turn `chat(...)` — it has no local
    /// tools, so it answers from knowledge and suggests commands as text.
    nonisolated static let ollamaChatSystem = """
    You are Salehman AI — a fast, precise, capable assistant running locally on \
    this device.

    LANGUAGE (critical): reply in the EXACT language the user wrote in. \
    English → English only. Arabic → Arabic only. You are multilingual — \
    never default to any single language.

    HOW TO RESPOND:
    • Lead with the answer. No filler openers or trailing sign-offs.
    • Match length to complexity: short for facts, thorough for hard problems.
    • Markdown only when it helps: fenced code for code, bullets for lists. \
    No headers for short replies.
    • Code: complete, correct, production-ready. No TODOs or placeholders.
    • Don't know something: say so directly.

    TOOLS: Running in local mode — no terminal, web search, or other tools \
    right now. Answer from your knowledge. If a task truly needs a command, \
    show the exact command the user can run.
    """

    // MARK: - Ollama tool-calling (the LOCAL/free brain controls the terminal)

    /// JSON tool spec handed to Ollama's `/api/chat`. Mirrors the Apple-Intelligence
    /// `RunTerminalCommandTool`, so the free local qwen brain gets the SAME terminal
    /// capability — gated by the SAME `CommandApprovalCenter` + blocked-command list.
    nonisolated(unsafe) static let terminalToolSpec: [String: Any] = [
        "type": "function",
        "function": [
            "name": "run_terminal_command",
            "description": "Run a shell (zsh) command on the user's Mac and get its combined stdout/stderr. Use it to ACTUALLY perform the user's task (inspect files, check system state, run scripts) — don't just describe the command, run it.",
            "parameters": [
                "type": "object",
                "properties": [
                    "command": [
                        "type": "string",
                        "description": "The exact shell command, e.g. 'ls -la ~/Downloads' or 'sw_vers'.",
                    ],
                ],
                "required": ["command"],
            ],
        ],
    ]

    /// Web tools for the Ollama loop — only offered when `ToolPolicy.isExternalAllowed`
    /// (web access on AND not Offline mode). Read-only network reads, so no approval
    /// card (matches the FM `WebSearchTool`/`FetchURLTool` gating). `Web.fetch` keeps
    /// its SSRF guard.
    nonisolated(unsafe) static let webSearchSpec: [String: Any] = [
        "type": "function",
        "function": [
            "name": "web_search",
            "description": "Search the web (DuckDuckGo) for current events, facts you're unsure of, or anything needing up-to-date information. Returns the top results.",
            "parameters": [
                "type": "object",
                "properties": ["query": ["type": "string", "description": "The search query."]],
                "required": ["query"],
            ],
        ],
    ]
    nonisolated(unsafe) static let fetchURLSpec: [String: Any] = [
        "type": "function",
        "function": [
            "name": "fetch_url",
            "description": "Fetch a specific web page and return its readable text. Use after web_search to read a result, or when the user gives a URL.",
            "parameters": [
                "type": "object",
                "properties": ["url": ["type": "string", "description": "The full URL, e.g. https://example.com/page."]],
                "required": ["url"],
            ],
        ],
    ]

    // MARK: On-device tools (no network) — knowledge search + Notes / tasks / memory.
    // Always offered (even in Offline mode) and shared by BOTH the Ollama and the
    // cloud OpenAI-compatible tool loops via `runLocalTool`. These restore the
    // capabilities the AI lost when the Apple-Intelligence tool session was removed
    // (DEVELOPMENT_LOG 2026-06-08) — the stores stayed; the assistant's access didn't.
    nonisolated(unsafe) static let searchDocumentsSpec: [String: Any] = [
        "type": "function",
        "function": [
            "name": "search_documents",
            "description": "Search the user's private on-device Knowledge base (documents and text they've added) and return the most relevant passages with their source names. Use whenever the user asks about their own files, notes, or documents. On-device only — nothing leaves the Mac.",
            "parameters": [
                "type": "object",
                "properties": ["query": ["type": "string", "description": "What to look for in the user's documents."]],
                "required": ["query"],
            ],
        ],
    ]
    nonisolated(unsafe) static let captureNoteSpec: [String: Any] = [
        "type": "function",
        "function": [
            "name": "capture_note",
            "description": "Save a note to the user's local Notes. Use when they ask to note/jot/save something, or to record a useful takeaway worth keeping. Stored on-device.",
            "parameters": [
                "type": "object",
                "properties": ["text": ["type": "string", "description": "The note text to save."]],
                "required": ["text"],
            ],
        ],
    ]
    nonisolated(unsafe) static let addTaskSpec: [String: Any] = [
        "type": "function",
        "function": [
            "name": "add_task",
            "description": "Add a to-do item to the user's local task list. Use when they ask to add a task, remember to do something, or set a reminder/to-do. Stored on-device.",
            "parameters": [
                "type": "object",
                "properties": ["title": ["type": "string", "description": "The task title — what needs doing."]],
                "required": ["title"],
            ],
        ],
    ]
    nonisolated(unsafe) static let rememberFactSpec: [String: Any] = [
        "type": "function",
        "function": [
            "name": "remember_fact",
            "description": "Store a durable fact about the user (a preference, a personal detail, an ongoing project) in long-term memory so it can inform future answers. Use when they share something worth remembering, or ask you to remember it. Stored on-device.",
            "parameters": [
                "type": "object",
                "properties": ["fact": ["type": "string", "description": "The fact to remember, phrased as a standalone statement."]],
                "required": ["fact"],
            ],
        ],
    ]

    /// `pack_repository` — Repomix/Gitingest-style "read a whole codebase at once".
    /// Handled in the async tool switch (NOT `runLocalTool`) because packing reads
    /// many files and runs off the main actor via `RepoPacker`.
    nonisolated(unsafe) static let packRepositorySpec: [String: Any] = [
        "type": "function",
        "function": [
            "name": "pack_repository",
            "description": "Pack an entire local code folder into ONE dense, AI-friendly digest (file tree + every text file's contents) — like Repomix/Gitingest — so you can read a whole codebase at once. Pass an absolute or ~ path. To pack a remote GitHub repo, first clone it with run_terminal_command ('git clone --depth 1 <url> /tmp/repo') then pack '/tmp/repo'. The full digest is also saved to a file; very large repos are capped inline.",
            "parameters": [
                "type": "object",
                "properties": ["path": ["type": "string", "description": "Local folder to pack, e.g. ~/Desktop/myproject or the current project root."]],
                "required": ["path"],
            ],
        ],
    ]

    nonisolated static let ollamaToolSystem = """
    You are Salehman AI — a fast, precise assistant running on this Mac with \
    full tool access. ACT; don't describe what you could do.

    LANGUAGE (critical): reply in the EXACT language the user wrote in. \
    English → English only. Arabic → Arabic only. Never switch on your own.

    HOW TO RESPOND:
    • Lead with the answer or the first tool call needed. No filler.
    • Match length to complexity. Code must be complete and production-ready.
    • After a tool result, briefly summarize what it shows and what's next.

    YOUR TOOLS — use them, don't just mention them:
    • run_terminal_command: run real shell commands on this Mac. Prefer \
    read-only commands by default; the user approves each before execution.
    • search_documents: search the user's private Knowledge base.
    • capture_note / add_task: save to their Notes and to-do list.
    • remember_fact: store a durable fact about the user for future sessions. \
    USE THIS whenever you learn their name, a preference, how they work, or \
    project context — it's how you get smarter for them over time.
    • pack_repository: read an entire code folder at once (Repomix-style).
    • web_search / fetch_url (when web access is on): get current info or \
    read any page.
    """

    /// The tool specs offered to the Ollama loop. Terminal is always available;
    /// the web tools are added ONLY when external access is allowed (web on AND
    /// not Offline mode). Pure + nonisolated so the security gate — "the local
    /// brain is never even *shown* web tools while offline" — is unit-testable.
    nonisolated static func ollamaToolSpecs(externalAllowed: Bool) -> [[String: Any]] {
        // On-device tools (terminal + knowledge/notes/tasks/memory) touch no network,
        // so they're ALWAYS offered — Offline mode doesn't restrict them. The web
        // tools are added ONLY when external access is on: a model can't call a tool
        // it was never handed (the real security gate; see OllamaToolGateTests).
        let onDevice: [[String: Any]] = [
            terminalToolSpec, searchDocumentsSpec, captureNoteSpec, addTaskSpec,
            rememberFactSpec, packRepositorySpec,
        ]
        return externalAllowed ? onDevice + [webSearchSpec, fetchURLSpec] : onDevice
    }

    /// Sendable mirror of `ollamaToolSpecs` exposing just the tool names — the
    /// `[[String: Any]]` spec list isn't trivially comparable in tests, but the
    /// security-relevant property ("web tools never shown when external is off")
    /// is exactly the set of names. Derived from `ollamaToolSpecs` so both stay
    /// in sync automatically if a future tool is added.
    nonisolated static func ollamaToolNames(externalAllowed: Bool) -> [String] {
        ollamaToolSpecs(externalAllowed: externalAllowed).compactMap {
            ($0["function"] as? [String: Any])?["name"] as? String
        }
    }

    /// Executes an on-device tool (no network): knowledge search + writing to the
    /// user's Notes / tasks / long-term memory. Shared by BOTH tool loops so every
    /// brain — local Ollama or any OpenAI-compatible cloud — gets the same on-device
    /// capabilities. Returns `nil` when `name` isn't one of these, so the caller
    /// falls through to the terminal / web / unknown branches. MainActor-isolated
    /// because `ScratchpadStore` is `@MainActor`; the tool loops already run there,
    /// so callers invoke it synchronously. All four tools are non-destructive writes
    /// to the user's own local stores, so (like the prior FM tools) they need no
    /// approval card — only the terminal does.
    static func runLocalTool(_ name: String, _ args: [String: String]) -> String? {
        switch name {
        case "search_documents":
            let query = (args["query"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return "No search query was provided." }
            let hits = KnowledgeStore.shared.search(query: query, k: 5)
            guard !hits.isEmpty else {
                return KnowledgeStore.shared.isEmpty()
                    ? "The Knowledge base is empty — the user hasn't added any documents yet."
                    : "No matching passages were found in the user's documents."
            }
            return hits.enumerated()
                .map { "\($0.offset + 1). [\($0.element.docName)] \($0.element.text)" }
                .joined(separator: "\n\n")
        case "capture_note":
            let text = (args["text"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return "No note text was provided." }
            ScratchpadStore.shared.addNote(text)
            return "Saved to Notes: \"\(text)\""
        case "add_task":
            let title = (args["title"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return "No task title was provided." }
            ScratchpadStore.shared.addTask(title)
            return "Added task: \"\(title)\""
        case "remember_fact":
            let fact = (args["fact"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fact.isEmpty else { return "No fact was provided." }
            MemoryStore.shared.remember(fact)
            return "Got it — I'll remember that: \"\(fact)\""
        default:
            return nil
        }
    }

    /// `pack_repository` tool handler. Packs a LOCAL folder into one AI-friendly
    /// digest via `RepoPacker`, OFF the main actor (a big repo would otherwise hitch
    /// the UI). Writes the full digest to a temp file and returns a capped inline
    /// slice + stats + the file path, so a huge repo can't blow the chat context.
    /// (Remote repos: the model clones with `run_terminal_command` first, then packs
    /// the local path — keeps this tool network-free.)
    nonisolated static func runPackRepository(_ args: [String: String]) async -> String {
        let path = (args["path"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return "Provide a local folder 'path' to pack." }
        let expanded = (path as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else {
            return "No folder found at \(path)."
        }
        let result = await Task.detached(priority: .userInitiated) {
            RepoPacker.pack(rootPath: expanded)
        }.value
        // Save the full digest so nothing is lost when the inline return is capped.
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("salehman-pack-\(result.rootName).md")
        try? result.digest.write(to: outURL, atomically: true, encoding: .utf8)

        let header = "Packed \(result.fileCount) files (\(RepoPacker.byteString(result.totalBytes)), \(result.skippedCount) skipped) from \(result.rootName). Full digest saved to \(outURL.path).\n\n"
        let inlineCap = 120_000
        if result.digest.count <= inlineCap { return header + result.digest }
        return header + String(result.digest.prefix(inlineCap))
            + "\n\n…[inline digest capped; open the saved file above for the full pack]"
    }

    // MARK: - Robust Tool-Call Recovery

    /// Some local models (qwen2.5-coder:7b included) occasionally emit a tool
    /// call as plain JSON text in `message.content` rather than in `tool_calls`.
    /// Without this guard that raw JSON leaks to the user as the reply.
    /// Returns (name, arguments) when text is recognisably a tool call, nil otherwise.
    nonisolated static func parseTextAsToolCall(_ text: String) -> (name: String, arguments: [String: String])? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            if let newline = trimmed.firstIndex(of: "\n") {
                trimmed = String(trimmed[trimmed.index(after: newline)...])
            }
            if trimmed.hasSuffix("```") { trimmed = String(trimmed.dropLast(3)) }
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let known: Set<String> = [
            "run_terminal_command", "web_search", "fetch_url", "pack_repository",
            "search_documents", "capture_note", "add_task", "remember_fact",
        ]
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = obj["name"] as? String, known.contains(name),
              let argsDict = obj["arguments"] as? [String: Any] else { return nil }
        var args: [String: String] = [:]
        for (k, v) in argsDict { args[k] = "\(v)" }
        return (name, args)
    }

    /// Ollama WITH tool-calling: the local/free qwen brain runs the terminal via the
    /// SAME approval gate + `Shell.runApproved` executor as the local brain. The
    /// model decides whether to call the tool; if it just answers, we return that
    /// text. Loops propose→approve→run→feed-back up to `maxRounds` so it can chain
    /// steps. `nil` → transport error (caller falls back to plain chat).
    static func chatOllamaWithTools(_ message: String, systemPrompt: String? = nil) async -> String? {
        guard let model = await OllamaClient.activeChatModel() else { return nil }
        // The persona is injected by the caller (e.g. `.salehman` passes
        // `SalehmanPersona.systemPrompt`); default keeps the existing
        // tool-aware system prompt for the legacy Ollama path.
        var messages: [[String: Any]] = [
            ["role": "system", "content": applyUnrestricted(systemPrompt ?? ollamaToolSystem)],
            ["role": "user", "content": message],
        ]
        // Terminal is always available; web tools only when external access is on
        // (and not Offline mode) — same gate as the FM web tools.
        let toolSpecs = Self.ollamaToolSpecs(externalAllowed: ToolPolicy.isExternalAllowed)
        // Build the /api/chat body locally and serialize to Data (Sendable) so the
        // non-Sendable [[String:Any]] never crosses into the nonisolated client.
        func bodyData(includeTools: Bool) -> Data? {
            var body: [String: Any] = ["model": model, "messages": messages,
                                       "stream": false, "keep_alive": "30s",
                                       "options": ["num_ctx": 4096]]
            if includeTools { body["tools"] = toolSpecs }
            return try? JSONSerialization.data(withJSONObject: body)
        }

        // Headroom for multi-step tasks (was 5 — too low; coding/tool chains
        // routinely needed more and hit the cap, surfacing "(Reached the tool-call
        // limit.)" to the user). We also remember the model's most recent prose so a
        // cap-out returns real content instead of that bare message.
        let maxRounds = 8
        var lastAssistantText = ""
        for _ in 0..<maxRounds {
            guard let data = bodyData(includeTools: true),
                  let turn = await OllamaClient.chatTurn(bodyData: data) else {
                return lastAssistantText.isEmpty ? nil : lastAssistantText
            }
            if !turn.text.isEmpty { lastAssistantText = turn.text }
            var toolCalls = turn.toolCalls
            if toolCalls.isEmpty, let recovered = Self.parseTextAsToolCall(turn.text) {
                toolCalls = [OllamaClient.ToolCall(name: recovered.name, arguments: recovered.arguments)]
            }
            if toolCalls.isEmpty {
                return turn.text.isEmpty ? (lastAssistantText.isEmpty ? nil : lastAssistantText) : turn.text
            }
            // Record the assistant's tool-call turn, then run each call and append
            // its result as a `tool` message so the model can chain / summarize.
            var assistantMsg: [String: Any] = ["role": "assistant", "content": turn.text]
            assistantMsg["tool_calls"] = toolCalls.map { call -> [String: Any] in
                ["function": ["name": call.name, "arguments": call.arguments]]
            }
            messages.append(assistantMsg)
            for call in toolCalls {
                let result: String
                if let local = Self.runLocalTool(call.name, call.arguments) {
                    // On-device tool (knowledge/notes/tasks/memory): no network, no
                    // approval card. Returns nil for the terminal/web tools below.
                    result = local
                } else {
                    switch call.name {
                    case "run_terminal_command":
                        result = await Shell.runApproved(call.arguments["command"] ?? "")
                    case "web_search":
                        // Defense-in-depth: refuse a web tool if external access is off
                        // (it shouldn't reach here — the spec is only sent when allowed).
                        result = ToolPolicy.isExternalAllowed
                            ? await Web.search(call.arguments["query"] ?? "")
                            : (ToolPolicy.webToolsDisabledReason() ?? "Web access is disabled — not run.")
                    case "fetch_url":
                        result = ToolPolicy.isExternalAllowed
                            ? await Web.fetch(call.arguments["url"] ?? "")
                            : (ToolPolicy.webToolsDisabledReason() ?? "Web access is disabled — not run.")
                    case "pack_repository":
                        result = await Self.runPackRepository(call.arguments)
                    default:
                        result = "Unknown tool '\(call.name)'."
                    }
                }
                messages.append(["role": "tool", "content": result])
            }
        }
        // Hit the round cap — ask once more with tools OFF for a direct final
        // answer, nudging the model to wrap up using what the tools already returned.
        messages.append(["role": "user",
                         "content": "Now give me your final answer directly, using the results above. Do not call any more tools."])
        guard let data = bodyData(includeTools: false),
              let final = await OllamaClient.chatTurn(bodyData: data) else {
            return lastAssistantText.isEmpty ? nil : lastAssistantText
        }
        if !final.text.isEmpty { return final.text }
        if !lastAssistantText.isEmpty { return lastAssistantText }
        return "I worked through several steps but couldn't wrap it up in one go. Say \"continue\" and I'll pick up where I left off."
    }

    // MARK: - Cloud / OpenAI-compatible tool-calling (any pinned brain runs the terminal)

    /// Any OpenAI-compatible brain (Groq, Mistral, Cerebras, OpenRouter, OpenAI,
    /// Unsloth Studio, vLLM, …) WITH tool-calling: the model can ACTUALLY run the
    /// terminal — and web tools when allowed — through the SAME
    /// `CommandApprovalCenter` gate + `Shell.runApproved` executor as the local
    /// brains, instead of only describing a command. Mirrors `chatOllamaWithTools`
    /// but speaks the OpenAI wire format (each result is a `role:"tool"` message
    /// keyed by `tool_call_id`, and the assistant's tool-call turn is echoed back
    /// verbatim). Loops propose→approve→run→feed-back up to `maxRounds` so it can
    /// chain steps. `nil` → transport error or a server that rejects `tools`, so
    /// the caller falls back to plain `chat`.
    static func chatOpenAICompatWithTools(client: OpenAICompatibleClient,
                                          model: String,
                                          message: String,
                                          systemPrompt: String? = nil) async -> String? {
        var messages: [[String: Any]] = [
            // `ollamaToolSystem` is brain-agnostic ("you CAN control the terminal,
            // run the command, don't just describe it") — reused here so the cloud
            // brains get the same tool-aware instructions as the local ones.
            ["role": "system", "content": applyUnrestricted(systemPrompt ?? ollamaToolSystem)],
            ["role": "user", "content": message],
        ]
        // Terminal is always available; web tools only when external access is on
        // (and not Offline mode) — same gate as the Ollama loop + FM web tools.
        let toolSpecs = Self.ollamaToolSpecs(externalAllowed: ToolPolicy.isExternalAllowed)
        // Build the body locally and serialize to Data (Sendable) so the
        // non-Sendable [[String:Any]] never crosses into the client method.
        func bodyData(includeTools: Bool) -> Data? {
            var body: [String: Any] = ["model": model, "messages": messages, "stream": false]
            if includeTools {
                body["tools"] = toolSpecs
                body["tool_choice"] = "auto"
            }
            return try? JSONSerialization.data(withJSONObject: body)
        }

        // Same headroom + last-prose memory as the Ollama loop (see note there):
        // 5 rounds was too low and surfaced "(Reached the tool-call limit.)".
        let maxRounds = 8
        var lastAssistantText = ""
        for _ in 0..<maxRounds {
            guard let data = bodyData(includeTools: true),
                  let turn = await client.chatTurnWithTools(bodyData: data) else {
                return lastAssistantText.isEmpty ? nil : lastAssistantText
            }
            if !turn.text.isEmpty { lastAssistantText = turn.text }
            var toolCalls = turn.toolCalls
            if toolCalls.isEmpty, let recovered = Self.parseTextAsToolCall(turn.text) {
                toolCalls = [OpenAICompatibleClient.ToolCall(id: "recovered_0", name: recovered.name, arguments: recovered.arguments)]
            }
            if toolCalls.isEmpty {
                return turn.text.isEmpty ? (lastAssistantText.isEmpty ? nil : lastAssistantText) : turn.text
            }
            // Echo the assistant's tool-call turn verbatim — OpenAI requires the
            // assistant message carry the `tool_calls` array so the following
            // `tool` results can be matched back by id. `content` is null (not "")
            // when the model only called tools, which strict servers require.
            var assistantMsg: [String: Any] = [
                "role": "assistant",
                "content": turn.text.isEmpty ? NSNull() : turn.text,
            ]
            assistantMsg["tool_calls"] = toolCalls.map { call -> [String: Any] in
                let argsJSON = (try? JSONSerialization.data(withJSONObject: call.arguments))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                return ["id": call.id, "type": "function",
                        "function": ["name": call.name, "arguments": argsJSON]]
            }
            messages.append(assistantMsg)
            for call in toolCalls {
                let result: String
                if let local = Self.runLocalTool(call.name, call.arguments) {
                    // On-device tool (knowledge/notes/tasks/memory): no network, no
                    // approval card. Returns nil for the terminal/web tools below.
                    result = local
                } else {
                    switch call.name {
                    case "run_terminal_command":
                        result = await Shell.runApproved(call.arguments["command"] ?? "")
                    case "web_search":
                        // Defense-in-depth: refuse a web tool if external access is off
                        // (it shouldn't reach here — the spec is only sent when allowed).
                        result = ToolPolicy.isExternalAllowed
                            ? await Web.search(call.arguments["query"] ?? "")
                            : (ToolPolicy.webToolsDisabledReason() ?? "Web access is disabled — not run.")
                    case "fetch_url":
                        result = ToolPolicy.isExternalAllowed
                            ? await Web.fetch(call.arguments["url"] ?? "")
                            : (ToolPolicy.webToolsDisabledReason() ?? "Web access is disabled — not run.")
                    case "pack_repository":
                        result = await Self.runPackRepository(call.arguments)
                    default:
                        result = "Unknown tool '\(call.name)'."
                    }
                }
                messages.append(["role": "tool", "tool_call_id": call.id, "content": result])
            }
        }
        // Hit the round cap — ask once more with tools OFF for a direct final
        // answer, nudging the model to wrap up using what the tools already returned.
        messages.append(["role": "user",
                         "content": "Now give me your final answer directly, using the results above. Do not call any more tools."])
        guard let data = bodyData(includeTools: false),
              let final = await client.chatTurnWithTools(bodyData: data) else {
            return lastAssistantText.isEmpty ? nil : lastAssistantText
        }
        if !final.text.isEmpty { return final.text }
        if !lastAssistantText.isEmpty { return lastAssistantText }
        return "I worked through several steps but couldn't wrap it up in one go. Say \"continue\" and I'll pick up where I left off."
    }

    /// Ollama reply — tool-calling first (so the local brain can run the terminal),
    /// falling back to plain chat if the tool turn errors out. `systemPrompt`
    /// overrides the default for both legs, so the `.salehman` brain can run the
    /// custom Ollama model with the Salehman persona instead of the generic
    /// tool-aware prompt.
    static func ollamaReply(_ message: String, systemPrompt: String? = nil) async -> String? {
        if let withTools = await chatOllamaWithTools(message, systemPrompt: systemPrompt) { return withTools }
        return await OllamaClient.chat(prompt: message, system: systemPrompt ?? ollamaChatSystem)
    }

    // Brain-gate predicates. Each cloud brain is *only* tried when the user
    // explicitly pins it — we never silently spend on a cloud API.
    //
    // The local tier (Ollama) is free and on-device. `isLocalPref` opens the
    // tier for `.auto` and the `.ollama` pin.
    nonisolated private static var isLocalPref: Bool {
        pref == .auto || pref == .ollama
    }
    /// The user's own model is pinned — route EXCLUSIVELY to it (no fallback).
    nonisolated private static var salehmanAllowed: Bool { pref == .salehman }
    /// Unsloth Studio (or any local OpenAI-compatible server) is pinned — route
    /// exclusively to it, no silent fallback to Ollama. Same discipline as
    /// `.salehman`: an explicit pin means "this engine or nothing."
    nonisolated private static var unslothStudioAllowed: Bool { pref == .unslothStudio }
    /// vLLM (local OpenAI-compatible server) is pinned — route exclusively to it,
    /// no silent fallback. Same discipline as `.unslothStudio`.
    nonisolated private static var vllmAllowed: Bool { pref == .vllm }
    nonisolated private static var claudeAllowed:   Bool { pref == .claudeHaiku }
    nonisolated private static var grokAllowed:     Bool { pref == .grok }
    nonisolated private static var geminiAllowed:   Bool { pref == .gemini }
    nonisolated private static var groqAllowed:     Bool { pref == .groq }
    nonisolated private static var mistralAllowed:  Bool { pref == .mistral }
    nonisolated private static var cerebrasAllowed: Bool { pref == .cerebras }
    nonisolated private static var deepSeekAllowed: Bool { pref == .deepSeek }
    nonisolated private static var codexAllowed:    Bool { pref == .codex }
    nonisolated private static var copilotAllowed:  Bool { pref == .copilot }
    nonisolated private static var openRouterAllowed: Bool { pref == .openRouter }

    /// One-shot generation (no memory between calls). `maxTokens` caps the
    /// response length to keep terse agents fast.
    ///
    /// Brain order honors the user's `BrainPreference` (auto/apple/ollama).
    /// Within `.auto` we stay local-first because it's
    /// lighter; pinned modes skip the other brain entirely instead of falling
    /// back silently — silent fallback would defeat the purpose of pinning.
    static func generate(_ rawPrompt: String, maxTokens: Int? = nil, cachePrefix: String? = nil) async -> String {
        // `cachePrefix` (e.g. conversation history): cached as its own block by
        // Anthropic, auto-cached server-side by Grok/OpenAI (we put it first);
        // folded into the prompt for every other brain. nil → unchanged behaviour.
        let prompt = (cachePrefix?.isEmpty == false) ? "\(cachePrefix!)\n\n\(rawPrompt)" : rawPrompt
        // Ensemble must be a first-class branch here, not only in AgentPipeline:
        // direct callers (the Settings health-check, StockSage briefings, title
        // generation) reach the model layer through `generate`, and without this
        // they'd fall through every single-brain gate to `offMessage` — which is
        // exactly why the Settings "Is All Brains at Once working?" probe falsely
        // reported "Not working" while ensemble chat worked fine via the pipeline.
        if isFreeAutoMode { return await generateFreeAuto(prompt) }
        if isFreeCodingMode { return await generateFreeCoding(prompt) }
        if isCloudCodingMode { return await generateCloudCoding(prompt) }
        if isEnsembleMode { return await generateEnsemble(prompt) }
        if claudeAllowed, let reply = await AnthropicClient.chat(prompt: rawPrompt, cachePrefix: cachePrefix) { return reply }
        if grokAllowed,
           let reply = await GrokClient.chat(prompt: prompt,
                                             model: AppSettings.grokModelCurrent) {
            return reply
        }
        if geminiAllowed,
           let reply = await GeminiClient.chat(prompt: prompt,
                                               model: AppSettings.geminiModelCurrent) {
            return reply
        }
        if groqAllowed,
           let reply = await GroqClient.shared.chat(prompt: prompt,
                                                    model: AppSettings.groqModelCurrent) {
            return reply
        }
        if mistralAllowed,
           let reply = await MistralClient.shared.chat(prompt: prompt,
                                                       model: AppSettings.mistralModelCurrent) {
            return reply
        }
        if cerebrasAllowed,
           let reply = await CerebrasClient.shared.chat(prompt: prompt,
                                                        model: AppSettings.cerebrasModelCurrent) {
            return reply
        }
        if deepSeekAllowed,
           let reply = await DeepSeekClient.shared.chat(prompt: prompt,
                                                        model: AppSettings.deepSeekModelCurrent) {
            return reply
        }
        if codexAllowed,
           let reply = await OpenAIClient.chat(prompt: prompt,
                                               model: AppSettings.openAIModelCurrent) {
            return reply
        }
        if openRouterAllowed,
           let reply = await OpenRouterClient.shared.chat(prompt: prompt,
                                                          model: AppSettings.openRouterModelCurrent) {
            return reply
        }
        if copilotAllowed, let reply = await CopilotClient.chat(prompt: prompt) { return reply }
        // Salehman — CLOUD-FIRST via the shared engine (REAL DeepSeek V4 free via
        // NVIDIA → free frontier/120B tiers → DeepSeek paid backstop → local
        // MLX/Ollama floor). Exactly the engine the leader uses. No further fallback.
        if salehmanAllowed {
            if let reply = await SalehmanEngine.generate(prompt: prompt, maxTokens: maxTokens) {
                return reply
            }
            return offMessage
        }
        // Unsloth Studio (or any local OpenAI-compatible server) — explicit pin,
        // no silent fallback. The endpoint URL is the only configuration.
        if unslothStudioAllowed {
            if let reply = await UnslothStudio.chat(prompt: prompt) { return reply }
            return offMessage
        }
        // vLLM — explicit pin, no silent fallback (same discipline as Unsloth Studio).
        if vllmAllowed {
            if let reply = await VLLM.chat(prompt: prompt) { return reply }
            return offMessage
        }
        // Local tier (Ollama): free & on-device, so they
        // fall back to each other; Ollama-first only when the user pinned it.
        if isLocalPref {
            if let reply = await OllamaClient.chat(prompt: prompt, system: Self.ollamaChatSystem) { return reply }
        }
        return offMessage
    }

    /// **On-device-only** one-shot generation. Runs EXCLUSIVELY the local tier
    /// (Ollama), ignoring the user's pinned brain — so a pinned cloud brain can
    /// never cause privacy-sensitive content to leave the Mac. This is the entry
    /// point for features that PROMISE privacy (the Knowledge vault's "on this
    /// Mac" summary/Q&A). Returns `nil` when no on-device model is available, so
    /// the caller can say so honestly rather than silently falling back to cloud.
    static func generateOnDevice(_ prompt: String, maxTokens: Int? = nil) async -> String? {
        if let reply = await OllamaClient.chat(prompt: prompt, system: Self.ollamaChatSystem) { return reply }
        // Unsloth Studio (or any local OpenAI-compat server) qualifies as
        // on-device ONLY when its endpoint is a loopback URL — see
        // `UnslothStudio.isLocalLoopback`. A user-typed public URL would NOT
        // satisfy the privacy promise, so we don't route here in that case.
        if UnslothStudio.isLocalLoopback, let reply = await UnslothStudio.chat(prompt: prompt) { return reply }
        return nil
    }

    /// Streaming one-shot generation. Same brain order as `generate`.
    ///
    /// For each pinned cloud brain we now try the streaming `chatStream` *first*,
    /// and if it returns nil (SSE parse failure, mid-stream blip, etc.) we
    /// fall back to the **same brain's non-streaming `chat`** before declaring
    /// the brain dead. That way one bad SSE chunk doesn't make a perfectly
    /// working Grok / Gemini / etc. look unreachable in the chat UI.
    ///
    /// We also no longer push `offMessage` into `onUpdate` at the end —
    /// the streaming bubble stays silent if every brain truly fails, and the
    /// returned String (the persisted reply) is the only carrier of the
    /// "unavailable" signal. The display layer (MessageBubble) is responsible
    /// for swapping the sentinel for the context-aware text.
    static func generateStreaming(_ rawPrompt: String, maxTokens: Int? = nil,
                                  cachePrefix: String? = nil,
                                  onUpdate: @escaping @Sendable (String) -> Void) async -> String {
        // `cachePrefix` (e.g. the stable conversation history): Anthropic caches it
        // as its own `cache_control` block; xAI Grok / OpenAI auto-cache a stable
        // prefix server-side — both benefit because we put it FIRST. Every other
        // brain just gets it folded into the prompt (full context, no caching).
        let prompt = (cachePrefix?.isEmpty == false) ? "\(cachePrefix!)\n\n\(rawPrompt)" : rawPrompt
        // Ensemble can't token-stream — it fans out to N brains and joins their
        // replies into one labeled document. Deliver that combined result in a
        // single `onUpdate` so the streaming bubble shows it, then return it.
        if isFreeAutoMode {
            // Race the free brains; deliver the single winning answer in one
            // update (the race joins to one reply — there's nothing to stream).
            let answer = await generateFreeAuto(prompt)
            onUpdate(answer)
            return answer
        }
        if isFreeCodingMode {
            // Like Free·Auto: the loop joins to one reply — nothing to token-stream,
            // so deliver the winning answer in a single update.
            let answer = await generateFreeCoding(prompt)
            onUpdate(answer)
            return answer
        }
        if isCloudCodingMode {
            let answer = await generateCloudCoding(prompt)
            onUpdate(answer)
            return answer
        }
        if isEnsembleMode {
            let combined = await generateEnsemble(prompt)
            onUpdate(combined)
            return combined
        }
        if claudeAllowed {
            if let r = await AnthropicClient.chatStream(prompt: rawPrompt, cachePrefix: cachePrefix, onUpdate: onUpdate) { return r }
            if let r = await AnthropicClient.chat(prompt: rawPrompt, cachePrefix: cachePrefix) { return r }
        }
        if grokAllowed {
            if let r = await GrokClient.chatStream(prompt: prompt,
                                                   model: AppSettings.grokModelCurrent,
                                                   onUpdate: onUpdate) { return r }
            if let r = await GrokClient.chat(prompt: prompt,
                                             model: AppSettings.grokModelCurrent) { return r }
        }
        if geminiAllowed {
            if let r = await GeminiClient.chatStream(prompt: prompt,
                                                     model: AppSettings.geminiModelCurrent,
                                                     onUpdate: onUpdate) { return r }
            if let r = await GeminiClient.chat(prompt: prompt,
                                               model: AppSettings.geminiModelCurrent) { return r }
        }
        if groqAllowed {
            if let r = await GroqClient.shared.chatStream(prompt: prompt,
                                                          model: AppSettings.groqModelCurrent,
                                                          onUpdate: onUpdate) { return r }
            if let r = await GroqClient.shared.chat(prompt: prompt,
                                                    model: AppSettings.groqModelCurrent) { return r }
        }
        if mistralAllowed {
            if let r = await MistralClient.shared.chatStream(prompt: prompt,
                                                             model: AppSettings.mistralModelCurrent,
                                                             onUpdate: onUpdate) { return r }
            if let r = await MistralClient.shared.chat(prompt: prompt,
                                                       model: AppSettings.mistralModelCurrent) { return r }
        }
        if cerebrasAllowed {
            if let r = await CerebrasClient.shared.chatStream(prompt: prompt,
                                                              model: AppSettings.cerebrasModelCurrent,
                                                              onUpdate: onUpdate) { return r }
            if let r = await CerebrasClient.shared.chat(prompt: prompt,
                                                        model: AppSettings.cerebrasModelCurrent) { return r }
        }
        if deepSeekAllowed {
            if let r = await DeepSeekClient.shared.chatStream(prompt: prompt,
                                                              model: AppSettings.deepSeekModelCurrent,
                                                              onUpdate: onUpdate) { return r }
            if let r = await DeepSeekClient.shared.chat(prompt: prompt,
                                                        model: AppSettings.deepSeekModelCurrent) { return r }
        }
        if codexAllowed {
            if let r = await OpenAIClient.chatStream(prompt: prompt,
                                                     model: AppSettings.openAIModelCurrent,
                                                     onUpdate: onUpdate) { return r }
            if let r = await OpenAIClient.chat(prompt: prompt,
                                               model: AppSettings.openAIModelCurrent) { return r }
        }
        if openRouterAllowed {
            if let r = await OpenRouterClient.shared.chatStream(prompt: prompt,
                                                               model: AppSettings.openRouterModelCurrent,
                                                               onUpdate: onUpdate) { return r }
            if let r = await OpenRouterClient.shared.chat(prompt: prompt,
                                                          model: AppSettings.openRouterModelCurrent) { return r }
        }
        if copilotAllowed {
            if let r = await CopilotClient.chatStream(prompt: prompt, onUpdate: onUpdate) { return r }
            if let r = await CopilotClient.chat(prompt: prompt) { return r }
        }
        // Salehman streaming — CLOUD-FIRST via the shared engine (streams from the
        // cloud brain; falls back to local MLX/Ollama streaming when offline).
        if salehmanAllowed {
            if let reply = await SalehmanEngine.generateStream(prompt: prompt,
                                                               maxTokens: maxTokens,
                                                               onUpdate: onUpdate) {
                return reply
            }
            return offMessage
        }
        // Unsloth Studio (or any local OpenAI-compatible server) — explicit
        // pin; tries streaming first, then falls back to the same brain's
        // non-streaming chat before declaring it dead (same discipline the
        // cloud SSE paths above use).
        if unslothStudioAllowed {
            if let r = await UnslothStudio.chatStream(prompt: prompt, onUpdate: onUpdate) { return r }
            if let r = await UnslothStudio.chat(prompt: prompt) { return r }
            return offMessage
        }
        // vLLM — explicit pin: stream first, then non-streaming fallback, same as above.
        if vllmAllowed {
            if let r = await VLLM.chatStream(prompt: prompt, onUpdate: onUpdate) { return r }
            if let r = await VLLM.chat(prompt: prompt) { return r }
            return offMessage
        }
        // Local tier — Ollama streaming.
        if isLocalPref {
            if let reply = await OllamaClient.chatStream(prompt: prompt, system: Self.ollamaChatSystem, onUpdate: onUpdate) {
                return reply
            }
        }
        // EVERY pinned brain failed. Return the sentinel so equality-check
        // callers (`synthesize`, etc.) still fire, but DO NOT push it into
        // `onUpdate` — that would paint the streaming UI with the
        // sentinel even while another agent (e.g. the non-streaming
        // `LocalLLM.chat` path used by the Reasoning Strategist) is
        // happily producing a real reply. The display layer transforms the
        // sentinel into the context-aware `unavailableMessage` at render time.
        return offMessage
    }

    /// Multi-turn chat that remembers prior messages. Routes through the
    /// tool-enabled Ollama/cloud loop;
    /// otherwise falls back to Ollama qwen-coder *without* tools.
    static func chat(_ message: String) async -> String {
        if isFreeAutoMode { return await generateFreeAuto(message) }
        if isFreeCodingMode { return await freeCodingReply(message) }
        if isCloudCodingMode { return await cloudCodingReply(message) }
        if isEnsembleMode { return await generateEnsemble(message) }
        if claudeAllowed {
            // Claude Haiku (cloud), single-turn, no local tools.
            if let reply = await AnthropicClient.chat(prompt: message, system: Self.cloudSystemPrompt) {
                return reply
            }
            return offMessage
        }
        if grokAllowed {
            if let reply = await GrokClient.chat(prompt: message,
                                                 system: Self.cloudSystemPrompt,
                                                 model: AppSettings.grokModelCurrent) {
                return reply
            }
            return offMessage
        }
        if geminiAllowed {
            if let reply = await GeminiClient.chat(prompt: message,
                                                   system: Self.cloudSystemPrompt,
                                                   model: AppSettings.geminiModelCurrent) {
                return reply
            }
            return offMessage
        }
        if groqAllowed {
            // Tool-calling first (so the cloud brain can run the terminal),
            // falling back to plain chat if the tool turn errors out.
            let m = AppSettings.groqModelCurrent
            if let reply = await chatOpenAICompatWithTools(client: GroqClient.shared, model: m, message: message) { return reply }
            if let reply = await GroqClient.shared.chat(prompt: message, system: Self.cloudSystemPrompt, model: m) { return reply }
            return offMessage
        }
        if mistralAllowed {
            let m = AppSettings.mistralModelCurrent
            if let reply = await chatOpenAICompatWithTools(client: MistralClient.shared, model: m, message: message) { return reply }
            if let reply = await MistralClient.shared.chat(prompt: message, system: Self.cloudSystemPrompt, model: m) { return reply }
            return offMessage
        }
        if cerebrasAllowed {
            let m = AppSettings.cerebrasModelCurrent
            if let reply = await chatOpenAICompatWithTools(client: CerebrasClient.shared, model: m, message: message) { return reply }
            if let reply = await CerebrasClient.shared.chat(prompt: message, system: Self.cloudSystemPrompt, model: m) { return reply }
            return offMessage
        }
        if deepSeekAllowed {
            let m = AppSettings.deepSeekModelCurrent
            if let reply = await chatOpenAICompatWithTools(client: DeepSeekClient.shared, model: m, message: message) { return reply }
            if let reply = await DeepSeekClient.shared.chat(prompt: message, system: Self.cloudSystemPrompt, model: m) { return reply }
            return offMessage
        }
        if codexAllowed {
            let m = AppSettings.openAIModelCurrent
            if let reply = await chatOpenAICompatWithTools(client: OpenAIClient.shared, model: m, message: message) { return reply }
            if let reply = await OpenAIClient.chat(prompt: message, system: Self.cloudSystemPrompt, model: m) { return reply }
            return offMessage
        }
        if openRouterAllowed {
            let m = AppSettings.openRouterModelCurrent
            if let reply = await chatOpenAICompatWithTools(client: OpenRouterClient.shared, model: m, message: message) { return reply }
            if let reply = await OpenRouterClient.shared.chat(prompt: message, system: Self.cloudSystemPrompt, model: m) { return reply }
            return offMessage
        }
        if copilotAllowed {
            if let reply = await CopilotClient.chat(prompt: message, system: Self.cloudSystemPrompt) {
                return reply
            }
            return offMessage
        }
        // Salehman — CLOUD-FIRST via the shared engine, WITH tools: each cloud
        // brain can run the terminal / web through the OpenAI `tools` field, and
        // the local MLX/Ollama floor keeps tools too (`ollamaReply`). Exactly the
        // engine the leader uses. No further fallback.
        if salehmanAllowed {
            if let reply = await SalehmanEngine.generateWithTools(message: message, userPrompt: message) {
                return reply
            }
            return offMessage
        }
        // Unsloth Studio (or any local OpenAI-compatible server) — explicit pin.
        // Tool-calling first via its OpenAI-compatible `tools` field, so the
        // Studio model can run the terminal; plain chat if the server doesn't
        // support tools or the tool turn errors out.
        if unslothStudioAllowed {
            if let reply = await UnslothStudio.chatWithTools(message) { return reply }
            if let reply = await UnslothStudio.chat(prompt: message, system: Self.cloudSystemPrompt) { return reply }
            return offMessage
        }
        // vLLM — explicit pin; tool-calling first, plain chat fallback (same as Unsloth Studio).
        if vllmAllowed {
            if let reply = await VLLM.chatWithTools(message) { return reply }
            if let reply = await VLLM.chat(prompt: message, system: Self.cloudSystemPrompt) { return reply }
            return offMessage
        }
        // Local tier — Ollama runs the terminal via `ollamaReply`'s tool loop.
        if isLocalPref {
            if let reply = await ollamaReply(message) { return reply }
            return offMessage
        }
        return offMessage
    }


    /// Start a fresh conversation (clears the rolling transcript memory).
    static func resetChat() async {
        await ConversationStore.shared.reset()
    }

    /// Result Synthesis Lead — a second pass that turns a working draft into a
    /// clear, friendly final answer. Preserves all facts and results.
    static func synthesize(userMessage: String, draft: String) async -> String {
        guard isAvailable else { return draft }
        let prompt = """
        You are the Result Synthesis Lead for Salehman AI. Rewrite the DRAFT
        answer so it responds to the user clearly, directly, and in a warm,
        concise tone. Keep ALL factual details, numbers, file paths, and command
        results from the draft. Do not invent anything new. If the draft already
        reads well, just lightly polish it. Reply in the user's language. Output
        ONLY the final answer, with no preamble.

        USER MESSAGE:
        \(userMessage)

        DRAFT:
        \(draft)

        FINAL ANSWER:
        """
        let refined = await generate(prompt)
        // If synthesis somehow failed (both brains unreachable), keep the draft.
        return refined == offMessage ? draft : refined
    }
}

