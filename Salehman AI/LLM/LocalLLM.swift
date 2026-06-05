import Foundation
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device generation via Apple Intelligence (Foundation Models). Falls back
/// gracefully when Apple Intelligence isn't available.
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
    nonisolated static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    /// User's master switch from Settings (distinct from hardware availability).
    nonisolated static var isEnabledByUser: Bool { AppSettings.appleIntelligenceEnabled }

    /// Truly usable right now: the hardware supports it AND the user left it on.
    nonisolated static var isActive: Bool { isEnabledByUser && isAvailable }

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
        "No model is reachable right now. Turn Apple Intelligence back on in Settings, or start the Ollama server (`ollama serve`) with qwen2.5-coder pulled, or pin a configured cloud brain in Settings → Brain."

    /// Context-aware UI-facing text describing why the currently-pinned brain
    /// can't answer. Names the brain the user actually selected and the
    /// exact remedy, so we never tell them to "turn Apple Intelligence back
    /// on" when *that* is on and a *different* pinned brain is the thing
    /// that's down.
    ///
    /// **Not safe for equality comparison** — value depends on
    /// `AppSettings.brainPreferenceCurrent` and changes when the user
    /// toggles. Use `offMessage` (above) for `==` checks; use this only
    /// for display.
    nonisolated static var unavailableMessage: String {
        let pref = AppSettings.brainPreferenceCurrent
        switch pref {
        case .auto:
            return "No model is reachable right now. Turn on Apple Intelligence in Settings, or start the Ollama server (`ollama serve`) with qwen2.5-coder pulled."
        case .apple:
            return "Apple Intelligence is your selected brain, but it's unavailable right now. Turn it on in Settings, or pick another brain."
        case .ollama:
            return "Ollama qwen-coder is your selected brain, but the Ollama server isn't reachable. Start it with `ollama serve` (with qwen2.5-coder pulled), or switch to Auto in Settings."
        case .copilot:
            return "GitHub Copilot is your selected brain, but you're not signed in. Sign in under Settings → GitHub Copilot, or switch brains."
        case .ensemble:
            return "\"All Brains at Once\" is selected, but none are reachable. Turn on Apple Intelligence, start Ollama, or add at least one cloud API key in Settings."
        case .freeAuto:
            return "\"Free · Auto\" is selected, but no free brain is reachable. Add a free key (Groq / Gemini / Cerebras / OpenRouter) in Settings, turn on Apple Intelligence, or start Ollama."
        case .claudeHaiku, .grok, .gemini, .groq, .mistral, .cerebras, .codex, .openRouter:
            return "\(pref.title) is your selected brain, but no API key is saved. Add one in Settings, or switch to another brain."
        case .salehman:
            return "Salehman needs an on-device engine to run. Either turn on Apple Intelligence (Settings → Intelligence → Apple Intelligence) — Salehman uses it with its own persona, no install required — OR pull your custom Ollama model (`ollama pull \(AppSettings.customModelNameCurrent)`) and start `ollama serve`."
        case .unslothStudio:
            return "Unsloth Studio is your selected brain, but its endpoint isn't reachable. Set the URL in Settings → Unsloth Studio (e.g. http://localhost:8000/v1) and make sure the server is running."
        }
    }

    // `nonisolated` because actor-isolated callers (e.g. `ChatSession`) read
    // this for error messages. The underlying availability check is itself
    // thread-safe, so there's no shared state to guard.
    nonisolated static var statusNote: String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return "Apple Intelligence (on-device)"
        case .unavailable(let reason): return "fallback (Apple Intelligence unavailable: \(reason))"
        }
        #else
        return "fallback (Foundation Models SDK not present)"
        #endif
    }

    /// Identifies which brain handled (or would handle) a request. Used by the
    /// UI to label the current state honestly.
    enum Brain: Equatable {
        case appleIntelligence, ollamaCoder
        case salehman                                // the user's OWN local Ollama model
        case unslothStudio                           // local OpenAI-compat server (Unsloth Studio / mlx_lm.server / LM Studio)
        case claudeHaiku, grok                       // cloud, pre-existing
        case gemini, groq, mistral, cerebras         // cloud, free-tier
        case codex, copilot                          // cloud, OpenAI + GitHub Copilot
        case openRouter                              // cloud aggregator (free models)
        case ensemble                                // all reachable brains in parallel
        case freeAuto                                // free brains raced; first valid wins; local backstop
        case none
    }

    /// Best brain available right now, honoring the user's `BrainPreference`:
    ///   * `.apple`  → return Apple Intelligence if active, else `.none`.
    ///   * `.ollama` → return Ollama qwen-coder if reachable, else `.none`.
    ///   * `.auto`   → Apple Intelligence wins when active, otherwise fall
    ///                 back to Ollama if the local server is up.
    /// Returning `.none` short-circuits the pipeline with the canonical
    /// "no brain reachable" message instead of silently using the other side.
    static func currentBrain() async -> Brain {
        let pref = AppSettings.brainPreferenceCurrent

        // Offline Mode hard-gates every cloud pref to `.none` so the UI shows a
        // clear "Offline is on" hint instead of silently degrading. Local pins
        // (`.apple`, `.ollama`, `.auto`) and the orchestration modes (`.ensemble`,
        // `.freeAuto`) stay reachable — they gate their own cloud roster.
        if AppSettings.isOfflineOnly {
            switch pref {
            case .claudeHaiku, .grok, .gemini, .groq, .mistral, .cerebras, .codex, .copilot, .openRouter:
                return .none
            default:
                break
            }
        }

        switch pref {
        // Local tier (Apple Intelligence + Ollama): both free & on-device, so a
        // pinned local brain falls back to the *other* local brain instead of
        // dead-ending. Order honors the pin. (Cloud pins below stay strict.)
        case .apple:
            if isActive { return .appleIntelligence }
            if await ollamaReady() { return .ollamaCoder }
            return .none

        case .ollama:
            if await ollamaReady() { return .ollamaCoder }
            if isActive { return .appleIntelligence }
            return .none

        case .salehman:
            // Salehman is reachable via three engines (in preference order). The
            // persona is the brand; the engine is internal:
            //   1. MLX-Swift on-device — truly standalone (no Ollama, no Apple).
            //   2. User's custom Ollama model — their explicit choice.
            //   3. Apple Intelligence with the Salehman persona — zero install.
            if await MLXSalehmanEngine.shared.isReady { return .salehman }
            if await OllamaClient.hasCustomModel() { return .salehman }
            if isActive { return .salehman }
            return .none

        case .unslothStudio:
            // Local OpenAI-compatible server (Unsloth Studio / mlx_lm.server / LM
            // Studio / llama.cpp). We do NOT probe the URL here — that would
            // burn an HTTP request every 10s during `BrainStatus` polling. The
            // "configured" check (endpoint URL is non-empty) is enough for the
            // header dot; a real call will surface unreachability later.
            return UnslothStudio.isConfigured ? .unslothStudio : .none

        // Cloud brains: "reachable" simply means the user has entered a key.
        // We never probe the network here — that would burn an HTTP request
        // every 10s while BrainStatus polls.
        case .claudeHaiku: return AnthropicClient.isConfigured ? .claudeHaiku : .none
        case .grok:        return GrokClient.hasKey()          ? .grok        : .none
        case .gemini:      return GeminiClient.hasKey()        ? .gemini      : .none
        case .groq:        return GroqClient.shared.hasKey()   ? .groq        : .none
        case .mistral:     return MistralClient.shared.hasKey()  ? .mistral    : .none
        case .cerebras:    return CerebrasClient.shared.hasKey() ? .cerebras   : .none
        case .codex:       return OpenAIClient.hasKey()         ? .codex       : .none
        case .copilot:     return CopilotClient.isAuthed()      ? .copilot     : .none
        case .openRouter:  return OpenRouterClient.shared.hasKey() ? .openRouter : .none

        case .auto:
            // `.auto` stays strictly local-first: we never silently spend on
            // a cloud API. The user has to explicitly pin a cloud brain to
            // leave the Mac.
            if isActive { return .appleIntelligence }
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
            if isActive { return .freeAuto }
            if GroqClient.shared.hasKey() || CerebrasClient.shared.hasKey()
                || GeminiClient.hasKey() || MistralClient.shared.hasKey()
                || OpenRouterClient.shared.hasKey() { return .freeAuto }
            if await ollamaReady() { return .freeAuto }
            return .none
        }
    }

    /// True iff at least one brain (local or any keyed cloud) can answer.
    /// Used by ensemble mode to decide between fanning out and the off-message.
    nonisolated static func anyBrainReachable() async -> Bool {
        if isActive { return true }
        if await ollamaReady() { return true }
        return AnthropicClient.isConfigured || GrokClient.hasKey() || GeminiClient.hasKey()
            || GroqClient.shared.hasKey() || MistralClient.shared.hasKey()
            || CerebrasClient.shared.hasKey() || OpenAIClient.hasKey() || CopilotClient.isAuthed()
            || OpenRouterClient.shared.hasKey()
    }

    /// True when the user picked the "All Brains at Once" preference.
    nonisolated static var isEnsembleMode: Bool { AppSettings.brainPreferenceCurrent == .ensemble }

    // MARK: - Free · Auto (parallel race, never blocked)

    /// True when the user picked the "Free · Auto" preference.
    nonisolated static var isFreeAutoMode: Bool { AppSettings.brainPreferenceCurrent == .freeAuto }

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
    /// (Apple Intelligence → Ollama) **sequentially** — never concurrently with
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
        #if canImport(FoundationModels)
        if isActive,
           let reply = try? await LanguageModelSession().respond(to: prompt).content,
           isUsableFreeAnswer(reply) {
            return reply
        }
        #endif
        if await ollamaReady(),
           let reply = await OllamaClient.chat(prompt: prompt, system: sys),
           isUsableFreeAnswer(reply) {
            return reply
        }

        return offMessage
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
        case .appleIntelligence: return "On-device · Apple Intelligence"
        case .ollamaCoder:       return "Local · Ollama qwen-coder"
        case .salehman:          return "Salehman · on-device"
        case .unslothStudio:
            return UnslothStudio.isLocalLoopback
                ? "Local · Unsloth Studio (\(AppSettings.unslothStudioModelCurrent))"
                : "Custom server · Unsloth Studio (\(AppSettings.unslothStudioModelCurrent))"
        case .claudeHaiku:       return "Cloud · Claude Haiku"
        case .grok:              return "Cloud · xAI \(AppSettings.grokModelCurrent)"
        case .gemini:            return "Cloud · Google \(AppSettings.geminiModelCurrent)"
        case .groq:              return "Cloud · Groq \(AppSettings.groqModelCurrent)"
        case .mistral:           return "Cloud · Mistral \(AppSettings.mistralModelCurrent)"
        case .cerebras:          return "Cloud · Cerebras \(AppSettings.cerebrasModelCurrent)"
        case .codex:             return "Cloud · OpenAI \(AppSettings.openAIModelCurrent)"
        case .copilot:           return "Cloud · GitHub Copilot"
        case .openRouter:        return "Cloud · OpenRouter \(AppSettings.openRouterModelCurrent)"
        case .ensemble:          return "All brains · parallel"
        case .freeAuto:          return "Free · Auto (parallel, never blocked)"
        case .none:
            // Name the pinned-but-down brain so the header matches the chat message.
            switch AppSettings.brainPreferenceCurrent {
            case .ollama:  return "Ollama selected · not running"
            case .apple:   return "Apple Intelligence selected · off"
            case .copilot: return "Copilot selected · sign in needed"
            case .salehman:
                // Two distinct messages depending on whether the MLX-Swift
                // package is in the project. When linked, the user can fix this
                // entirely on-device by downloading the standalone engine.
                if MLXSalehmanEngine.isPackageLinked {
                    return "Salehman selected · download the standalone engine in Settings, turn on Apple Intelligence, or pull \"\(AppSettings.customModelNameCurrent)\""
                } else {
                    return "Salehman selected · turn on Apple Intelligence or pull \"\(AppSettings.customModelNameCurrent)\""
                }
            case .unslothStudio:
                // Different failure mode from the cloud brains — no key, just a
                // local URL the user has to set + a server that has to be running.
                return UnslothStudio.isConfigured
                    ? "Unsloth Studio · server unreachable"
                    : "Unsloth Studio · set endpoint URL in Settings"
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

        #if canImport(FoundationModels)
        if isActive {
            roster.append(("Apple Intelligence", {
                try? await LanguageModelSession().respond(to: prompt).content
            }))
        }
        #endif
        if let m = ollamaModel, includeLocal {
            roster.append(("Ollama · \(m)", { await OllamaClient.chat(prompt: prompt, system: sys) }))
        }
        // Offline Mode skips ALL cloud brains so ensemble runs LOCAL-only (Apple
        // + Ollama, already appended above). Auto-scales — when the next cloud
        // brain is added, this single gate covers it.
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
    nonisolated static let cloudSystemPrompt = """
    You are Salehman AI, a helpful, concise, friendly assistant created by Saleh. \
    CRITICAL LANGUAGE RULE: reply in the SAME language as the user's latest \
    message. If their message is in English, reply ONLY in English; if it is in \
    Arabic, reply in Arabic. Never switch languages on your own. \
    Lead with the answer first, then only the reasoning that helps — skip filler. \
    Use markdown only when it adds clarity (lists for 3+ items, fenced code for code). \
    You don't have access to this Mac's terminal or \
    local tools in this mode — if a task needs running a command, say so and \
    suggest the command as text.
    """

    /// System prompt for Ollama in single-turn `chat(...)` — it has no local
    /// tools, so it answers from knowledge and suggests commands as text.
    nonisolated static let ollamaChatSystem = """
    You are Salehman AI, a helpful, concise, friendly assistant created by Saleh. \
    CRITICAL LANGUAGE RULE: reply in the SAME language as the user's latest \
    message. If their message is in English, reply ONLY in English; if it is in \
    Arabic, reply in Arabic. Never switch languages on your own (you are a \
    multilingual model and must not default to Arabic or any other language). \
    You cannot call tools (no terminal, no web search, no self-improve) right \
    now — just answer from your knowledge: lead with the answer, keep it clear and \
    brief, and use markdown only when it adds clarity (lists, fenced code). If a \
    question really requires running a command on this Mac, say so plainly and \
    suggest the command as text.
    """

    // MARK: - Ollama tool-calling (the LOCAL/free brain controls the terminal)

    /// JSON tool spec handed to Ollama's `/api/chat`. Mirrors the Apple-Intelligence
    /// `RunTerminalCommandTool`, so the free local qwen brain gets the SAME terminal
    /// capability — gated by the SAME `CommandApprovalCenter` + blocked-command list.
    nonisolated static let terminalToolSpec: [String: Any] = [
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
    nonisolated static let webSearchSpec: [String: Any] = [
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
    nonisolated static let fetchURLSpec: [String: Any] = [
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

    nonisolated static let ollamaToolSystem = """
    You are Salehman AI, a helpful assistant created by Saleh, running on this Mac. \
    You CAN control the terminal: call the run_terminal_command tool to actually run \
    shell commands and complete the task — don't just describe a command, run it. \
    Prefer safe, read-only commands unless the user clearly asked to modify \
    something; the user approves each command before it executes. After a command's \
    result comes back, briefly explain what it shows. When web access is on you also \
    have web_search and fetch_url — use them for current info or to read a page. \
    CRITICAL LANGUAGE RULE: reply \
    in the SAME language as the user's latest message (English → English only, \
    Arabic → Arabic); never switch on your own.
    """

    /// The tool specs offered to the Ollama loop. Terminal is always available;
    /// the web tools are added ONLY when external access is allowed (web on AND
    /// not Offline mode). Pure + nonisolated so the security gate — "the local
    /// brain is never even *shown* web tools while offline" — is unit-testable.
    nonisolated static func ollamaToolSpecs(externalAllowed: Bool) -> [[String: Any]] {
        externalAllowed ? [terminalToolSpec, webSearchSpec, fetchURLSpec] : [terminalToolSpec]
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

    /// Ollama WITH tool-calling: the local/free qwen brain runs the terminal via the
    /// SAME approval gate + `Shell.runApproved` executor as Apple Intelligence. The
    /// model decides whether to call the tool; if it just answers, we return that
    /// text. Loops propose→approve→run→feed-back up to `maxRounds` so it can chain
    /// steps. `nil` → transport error (caller falls back to plain chat).
    static func chatOllamaWithTools(_ message: String, systemPrompt: String? = nil) async -> String? {
        guard let model = await OllamaClient.activeChatModel() else { return nil }
        // The persona is injected by the caller (e.g. `.salehman` passes
        // `SalehmanPersona.systemPrompt`); default keeps the existing
        // tool-aware system prompt for the legacy Ollama path.
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt ?? ollamaToolSystem],
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

        let maxRounds = 5
        for _ in 0..<maxRounds {
            guard let data = bodyData(includeTools: true),
                  let turn = await OllamaClient.chatTurn(bodyData: data) else { return nil }
            if turn.toolCalls.isEmpty {
                return turn.text.isEmpty ? nil : turn.text
            }
            // Record the assistant's tool-call turn, then run each call and append
            // its result as a `tool` message so the model can chain / summarize.
            var assistantMsg: [String: Any] = ["role": "assistant", "content": turn.text]
            assistantMsg["tool_calls"] = turn.toolCalls.map { call -> [String: Any] in
                ["function": ["name": call.name, "arguments": call.arguments]]
            }
            messages.append(assistantMsg)
            for call in turn.toolCalls {
                let result: String
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
                default:
                    result = "Unknown tool '\(call.name)'."
                }
                messages.append(["role": "tool", "content": result])
            }
        }
        // Hit the round cap — one final tool-free turn for a summary.
        guard let data = bodyData(includeTools: false),
              let final = await OllamaClient.chatTurn(bodyData: data) else { return nil }
        return final.text.isEmpty ? "(Reached the tool-call limit.)" : final.text
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
    // The local tier (Apple Intelligence + Ollama) is different: both are free
    // and on-device, so within any local preference they fall back to each
    // other instead of dead-ending. `isLocalPref` opens the tier; `ollamaFirst`
    // sets the order (Ollama-first only when the user explicitly pinned Ollama).
    nonisolated private static var isLocalPref: Bool {
        pref == .auto || pref == .apple || pref == .ollama
    }
    nonisolated private static var ollamaFirst: Bool { pref == .ollama }
    /// The user's own model is pinned — route EXCLUSIVELY to it (no fallback).
    nonisolated private static var salehmanAllowed: Bool { pref == .salehman }
    /// Unsloth Studio (or any local OpenAI-compatible server) is pinned — route
    /// exclusively to it, no silent fallback to Apple/Ollama. Same discipline
    /// as `.salehman`: an explicit pin means "this engine or nothing."
    nonisolated private static var unslothStudioAllowed: Bool { pref == .unslothStudio }
    nonisolated private static var claudeAllowed:   Bool { pref == .claudeHaiku }
    nonisolated private static var grokAllowed:     Bool { pref == .grok }
    nonisolated private static var geminiAllowed:   Bool { pref == .gemini }
    nonisolated private static var groqAllowed:     Bool { pref == .groq }
    nonisolated private static var mistralAllowed:  Bool { pref == .mistral }
    nonisolated private static var cerebrasAllowed: Bool { pref == .cerebras }
    nonisolated private static var codexAllowed:    Bool { pref == .codex }
    nonisolated private static var copilotAllowed:  Bool { pref == .copilot }
    nonisolated private static var openRouterAllowed: Bool { pref == .openRouter }

    /// One-shot generation (no memory between calls). `maxTokens` caps the
    /// response length to keep terse agents fast.
    ///
    /// Brain order honors the user's `BrainPreference` (auto/apple/ollama).
    /// Within `.auto` we still try Apple Intelligence first because it's
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
        // Salehman — engine preference: MLX standalone → custom Ollama model →
        // Apple Intelligence with persona. No further fallback.
        if salehmanAllowed {
            // 1. Truly-standalone on-device MLX engine. Bypasses everything else.
            if await MLXSalehmanEngine.shared.isReady,
               let reply = await MLXSalehmanEngine.shared.generate(prompt: prompt,
                                                                    maxTokens: maxTokens ?? 512) {
                return reply
            }
            if let reply = await OllamaClient.chat(prompt: prompt, system: SalehmanPersona.systemPrompt) {
                return reply
            }
            #if canImport(FoundationModels)
            if isActive {
                let session = LanguageModelSession(instructions: SalehmanPersona.systemPrompt)
                let options = GenerationOptions(maximumResponseTokens: maxTokens)
                if let response = try? await session.respond(to: prompt, options: options) {
                    return response.content
                }
            }
            #endif
            return offMessage
        }
        // Unsloth Studio (or any local OpenAI-compatible server) — explicit pin,
        // no silent fallback. The endpoint URL is the only configuration.
        if unslothStudioAllowed {
            if let reply = await UnslothStudio.chat(prompt: prompt) { return reply }
            return offMessage
        }
        // Local tier (Apple Intelligence + Ollama): free & on-device, so they
        // fall back to each other; Ollama-first only when the user pinned it.
        if isLocalPref {
            if ollamaFirst, let reply = await OllamaClient.chat(prompt: prompt, system: Self.ollamaChatSystem) { return reply }
            #if canImport(FoundationModels)
            if isActive {
                let session = LanguageModelSession()
                let options = GenerationOptions(maximumResponseTokens: maxTokens)
                if let response = try? await session.respond(to: prompt, options: options) {
                    return response.content
                }
            }
            #endif
            if !ollamaFirst, let reply = await OllamaClient.chat(prompt: prompt, system: Self.ollamaChatSystem) { return reply }
        }
        return offMessage
    }

    /// **On-device-only** one-shot generation. Runs EXCLUSIVELY the local tier
    /// (Apple Intelligence → Ollama), ignoring the user's pinned brain — so a
    /// pinned cloud brain can never cause privacy-sensitive content to leave the
    /// Mac. This is the entry point for features that PROMISE privacy (the
    /// Knowledge vault's "on this Mac" summary/Q&A). Returns `nil` when no
    /// on-device model is available, so the caller can say so honestly rather
    /// than silently falling back to the cloud.
    static func generateOnDevice(_ prompt: String, maxTokens: Int? = nil) async -> String? {
        #if canImport(FoundationModels)
        if isActive {
            let session = LanguageModelSession()
            let options = GenerationOptions(maximumResponseTokens: maxTokens)
            if let response = try? await session.respond(to: prompt, options: options) {
                return response.content
            }
        }
        #endif
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
                                  onUpdate: @escaping (String) -> Void) async -> String {
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
        // Salehman streaming — engine preference: MLX standalone → custom Ollama
        // model → Apple Intelligence with persona. No further fallback.
        if salehmanAllowed {
            // 1. Truly-standalone on-device MLX engine. Streams tokens natively.
            if await MLXSalehmanEngine.shared.isReady,
               let reply = await MLXSalehmanEngine.shared.generateStream(prompt: prompt,
                                                                          maxTokens: maxTokens ?? 512,
                                                                          onUpdate: onUpdate) {
                return reply
            }
            if let reply = await OllamaClient.chatStream(prompt: prompt, system: SalehmanPersona.systemPrompt, onUpdate: onUpdate) {
                return reply
            }
            #if canImport(FoundationModels)
            if isActive {
                let session = LanguageModelSession(instructions: SalehmanPersona.systemPrompt)
                let options = GenerationOptions(maximumResponseTokens: maxTokens)
                var last = ""
                do {
                    let stream = session.streamResponse(to: prompt, options: options)
                    for try await snapshot in stream {
                        last = snapshot.content
                        onUpdate(last)
                    }
                    if !last.isEmpty { return last }
                } catch {
                    if !last.isEmpty { return last }
                }
            }
            #endif
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
        // Local tier — same fall-back-and-order rules as `generate`.
        if isLocalPref {
            if ollamaFirst,
               let reply = await OllamaClient.chatStream(prompt: prompt, system: Self.ollamaChatSystem, onUpdate: onUpdate) {
                return reply
            }
            #if canImport(FoundationModels)
            if isActive {
                let session = LanguageModelSession()
                let options = GenerationOptions(maximumResponseTokens: maxTokens)
                var last = ""
                do {
                    let stream = session.streamResponse(to: prompt, options: options)
                    for try await snapshot in stream {
                        last = snapshot.content
                        onUpdate(last)
                    }
                    return last
                } catch {
                    if !last.isEmpty { return last }
                    // Fall through to Ollama on a clean failure (don't trap the user).
                }
            }
            #endif
            if !ollamaFirst,
               let reply = await OllamaClient.chatStream(prompt: prompt, system: Self.ollamaChatSystem, onUpdate: onUpdate) {
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
    /// tool-enabled `ChatSession` when Apple Intelligence is the active brain;
    /// otherwise falls back to Ollama qwen-coder *without* tools.
    static func chat(_ message: String) async -> String {
        if isFreeAutoMode { return await generateFreeAuto(message) }
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
            if let reply = await GroqClient.shared.chat(prompt: message,
                                                        system: Self.cloudSystemPrompt,
                                                        model: AppSettings.groqModelCurrent) {
                return reply
            }
            return offMessage
        }
        if mistralAllowed {
            if let reply = await MistralClient.shared.chat(prompt: message,
                                                           system: Self.cloudSystemPrompt,
                                                           model: AppSettings.mistralModelCurrent) {
                return reply
            }
            return offMessage
        }
        if cerebrasAllowed {
            if let reply = await CerebrasClient.shared.chat(prompt: message,
                                                            system: Self.cloudSystemPrompt,
                                                            model: AppSettings.cerebrasModelCurrent) {
                return reply
            }
            return offMessage
        }
        if codexAllowed {
            if let reply = await OpenAIClient.chat(prompt: message,
                                                   system: Self.cloudSystemPrompt,
                                                   model: AppSettings.openAIModelCurrent) {
                return reply
            }
            return offMessage
        }
        if openRouterAllowed {
            if let reply = await OpenRouterClient.shared.chat(prompt: message,
                                                              system: Self.cloudSystemPrompt,
                                                              model: AppSettings.openRouterModelCurrent) {
                return reply
            }
            return offMessage
        }
        if copilotAllowed {
            if let reply = await CopilotClient.chat(prompt: message, system: Self.cloudSystemPrompt) {
                return reply
            }
            return offMessage
        }
        // Salehman — the user's own assistant identity. Engine preference:
        //   1. MLX-Swift on-device — TRULY standalone (no Ollama, no Apple).
        //   2. Custom Ollama model if the user pulled one (explicit choice).
        //   3. Apple Intelligence with the Salehman persona (zero install).
        // No further fallback (no qwen, no Apple-without-persona, no cloud).
        if salehmanAllowed {
            // 1. Truly-standalone engine — bypasses Ollama and Apple entirely.
            //    Tools (terminal, web) aren't wired through MLX yet — when the
            //    standalone engine is the active one, the model answers from its
            //    weights only. Ollama/Apple still get tools when they're used.
            if await MLXSalehmanEngine.shared.isReady,
               let reply = await MLXSalehmanEngine.shared.generate(prompt: message) {
                return reply
            }
            if let reply = await ollamaReply(message, systemPrompt: SalehmanPersona.systemPrompt) {
                return reply
            }
            #if canImport(FoundationModels)
            if isActive {
                let session = LanguageModelSession(
                    tools: ToolPolicy.activeTools(),
                    instructions: SalehmanPersona.instructions(toolMenu: ToolPolicy.instructionsToolMenu())
                )
                if let response = try? await session.respond(to: message) {
                    return response.content
                }
            }
            #endif
            return offMessage
        }
        // Unsloth Studio (or any local OpenAI-compatible server) — explicit
        // pin. No tool loop yet: the Studio server speaks plain chat, so it
        // answers from its own knowledge for now. (Future: route the function-
        // calling tools through Studio's OpenAI-compatible `tools` field.)
        if unslothStudioAllowed {
            if let reply = await UnslothStudio.chat(prompt: message, system: Self.cloudSystemPrompt) {
                return reply
            }
            return offMessage
        }
        // Local tier (pinned-first). BOTH brains can now run the terminal: Apple
        // via the tool-enabled ChatSession, Ollama via `ollamaReply`'s tool loop.
        if isLocalPref {
            if ollamaFirst {
                if let reply = await ollamaReply(message) { return reply }
                if isActive { return await ChatSession.shared.respond(to: message) }
                return offMessage
            }
            if isActive { return await ChatSession.shared.respond(to: message) }
            if let reply = await ollamaReply(message) { return reply }
            return offMessage
        }
        return offMessage
    }


    /// Start a fresh conversation (clears memory).
    static func resetChat() async {
        await ChatSession.shared.reset()
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

/// Holds a persistent Foundation Models session so the assistant remembers
/// the conversation across turns. Isolated in an actor for safe concurrent use.
actor ChatSession {
    static let shared = ChatSession()

    /// Persona + behaviour rules. The live tool menu is appended at session-
    /// build time (see `currentInstructions()`) so disabled tools — e.g. web
    /// access switched off in Settings — are never advertised to the model.
    private static let baseInstructions = """
    You are Salehman AI, a helpful, concise, and friendly assistant created by Saleh.
    Lead with the answer first, then add only the reasoning or caveats that actually help. Skip filler like "Certainly!" or "As an AI…". Use markdown only when it adds clarity (lists for 3+ items, fenced code blocks for code); short answers stay prose.
    LANGUAGE (critical): reply in the SAME language as the user's latest message — English in, English out; Arabic in, Arabic out. Never switch languages on your own, and never default to Arabic just because the Mac's region is Saudi.

    IMPORTANT — answering vs. coding:
    • For ANY question about this Mac or its current state (macOS version, files,
      disk space, settings, running apps, etc.), you MUST call the
      run_terminal_command tool to get the REAL answer, then report it in plain
      words. Do NOT write code for the user to run, and do NOT guess.
    • Only write code when the user EXPLICITLY asks you to write or fix code.
    When you do write code: make it correct, complete, idiomatic, and modern
    (Swift/SwiftUI where relevant); handle errors and edge cases; add brief usage
    notes; never leave TODO placeholders; and show it in fenced code blocks.

    You can control the user's Mac terminal using the run_terminal_command tool.
    The computer runs macOS (Apple Silicon) with the zsh shell — NOT Linux.
    Always use macOS-native commands. Do NOT use Linux-only tools like systemctl,
    apt, gsettings, or xdg-open. Useful macOS equivalents:
      • Change wallpaper: osascript -e 'tell application "System Events" to set picture of every desktop to "/full/path/to/image.jpg"'
      • Open an app: open -a "Safari"   • Open a file/URL: open <path-or-url>
      • Read a setting: defaults read <domain> <key>
      • System info: sw_vers, system_profiler SPHardwareDataType
      • Notifications: osascript -e 'display notification "text" with title "Salehman AI"'
      • Volume: osascript -e 'set volume output volume 50'

    When the user asks you to do something on their computer, call
    run_terminal_command with the correct macOS command, then explain the result
    in plain language. If a command fails because it doesn't exist, figure out the
    correct macOS equivalent and try again instead of giving up. Never run
    destructive commands. After running a command, briefly summarize what happened.
    To run tests, use run_terminal_command with `xcodebuild test -scheme <name>`.
    """

    /// Persona + the live tool menu derived from `ToolPolicy`. Rebuilt every
    /// time a session is created so toggling web access (or any other gated
    /// tool) only requires starting a new chat.
    private static func currentInstructions() -> String {
        baseInstructions + "\n\nTools available to you right now:\n" + ToolPolicy.instructionsToolMenu()
    }

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    func reset() {
        #if canImport(FoundationModels)
        session = nil
        #endif
    }

    func respond(to message: String) async -> String {
        // Belt-and-suspenders: in the current routing `LocalLLM.chat` only
        // calls this when both `isEnabledByUser` and `.available` hold true,
        // so neither guard ever fires. They stay as a defensive boundary in
        // case a future caller addresses `ChatSession.shared` directly.
        guard LocalLLM.isEnabledByUser else { return LocalLLM.offMessage }
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else {
            return "[Apple Intelligence is not available — \(LocalLLM.statusNote). Enable it in System Settings → Apple Intelligence & Siri.]"
        }
        if session == nil {
            session = LanguageModelSession(tools: ToolPolicy.activeTools(),
                                           instructions: Self.currentInstructions())
        }
        guard let session else { return "[Could not start a chat session.]" }
        do {
            let response = try await session.respond(to: message)
            return response.content
        } catch {
            let firstError = error
            // A fresh session can recover from a one-off context/length overflow —
            // rebuild and retry ONCE. If the retry ALSO throws, this is a
            // persistent failure (not a transient overflow); surface both causes
            // instead of masking the retry error with `try?`.
            self.session = LanguageModelSession(tools: ToolPolicy.activeTools(),
                                                instructions: Self.currentInstructions())
            do {
                if let retry = try await self.session?.respond(to: message) {
                    return retry.content
                }
                return "[The on-device model couldn't complete that request: \(firstError.localizedDescription)]"
            } catch {
                return "[The on-device model couldn't complete that request, even after a fresh session. First error: \(firstError.localizedDescription). Retry error: \(error.localizedDescription)]"
            }
        }
        #else
        return "[Foundation Models SDK not present on this system.]"
        #endif
    }
}
