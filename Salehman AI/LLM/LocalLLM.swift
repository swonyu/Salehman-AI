import Foundation
import OSLog

/// Brain routing for Salehman AI. Salehman runs CLOUD-FIRST (free DeepSeek V4 via
/// NVIDIA → free frontier/120B tiers) with a LOCAL floor
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
    /// True when *some* cloud brain can answer. Used by the pipeline to rate an
    /// outcome — if any of the 9 providers has a key, we can reach a brain.
    /// (Ollama availability requires an async HTTP probe so it can't be checked
    /// here; the pipeline only calls this after already getting a non-empty
    /// answer, which implies a brain was reachable.)
    nonisolated static var isAvailable: Bool {
        !CloudProvider.configuredNow().isEmpty
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
        "No model is reachable right now. Make sure the salehman model is pulled: `ollama pull salehman`."

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
            return "No model is reachable right now. Start Ollama with `ollama serve` and make sure a model is pulled."
        case .ollama:
            return "Ollama qwen-coder is your selected brain, but the Ollama server isn't reachable. Start it with `ollama serve` (with qwen2.5-coder pulled), or switch to Auto in Settings."
        case .copilot:
            return "GitHub Copilot is your selected brain, but you're not signed in. Sign in under Settings → GitHub Copilot, or switch brains."
        case .ensemble:
            return "\"All Brains at Once\" is selected, but none are reachable. Start Ollama, or add at least one cloud API key in Settings."
        case .freeAuto:
            return "\"Free · Auto\" is selected, but no free brain is reachable. Add a free key (Groq / Gemini / Cerebras / OpenRouter) in Settings, or start Ollama."
        case .freeCoding:
            return "\"FreeCoding\" is selected, but no coder brain is reachable. Add a key (OpenRouter / Groq / Cerebras / Mistral) in Settings, or start Ollama with qwen2.5-coder."
        case .cloudCoding:
            return AppSettings.isOfflineOnly
                ? "\"Cloud Coding\" is cloud-only, but Offline Mode is on. Turn Offline Mode off in Settings, or pick the local Ollama brain."
                : "\"Cloud Coding\" is selected, but no cloud coder key is saved. Add a key for Cerebras / Groq / OpenRouter / Mistral in Settings — it's cloud-only, so there's no local fallback."
        case .claudeHaiku, .grok, .gemini, .groq, .mistral, .cerebras, .codex, .openRouter:
            return "\(pref.title) is your selected brain, but no API key is saved. Add one in Settings, or switch to another brain."
        case .salehman:
            return "Salehman model isn't responding. Make sure it's pulled: `ollama pull \(AppSettings.customModelNameCurrent)`."
        case .unslothStudio:
            return "Unsloth Studio is your selected brain, but its endpoint isn't reachable. Set the URL in Settings → Unsloth Studio (e.g. http://localhost:8000/v1) and make sure the server is running."
        case .vllm:
            return "vLLM is your selected brain, but its endpoint isn't reachable. Set the URL in Settings → vLLM (e.g. http://localhost:8000/v1) and make sure `vllm serve` is running."
        case .uncensored:
            return "The Uncensored brain needs its model pulled. Run `ollama pull \(OllamaClient.uncensoredModel)` (and `ollama serve`), or switch to another brain."
        }
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
        case .salehman:
            return false   // local-only by design; no cloud key needed or used
        case .freeAuto:
            // Show the banner when none of the free-tier providers (Groq, Cerebras,
            // Gemini, Mistral, OpenRouter) are configured. freeAuto has an Ollama
            // backstop, so this is informational — "you're on the slow path".
            return !CloudProvider.freeTier.contains { $0.isConfiguredNow }
        case .freeCoding:
            // The free coding loop runs OpenRouter/Groq/Cerebras/Mistral.
            return !CloudProvider.codingRace.contains { $0.isConfiguredNow }
        case .cloudCoding:
            // Cloud Coding uses its OWN curated coder roster (Cerebras/Groq/
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
        "No cloud key — replies may be unavailable. Add a key in Settings → Brain for the selected brain."

    /// Identifies which brain handled (or would handle) a request. Used by the
    /// UI to label the current state honestly.
    nonisolated enum Brain: Equatable {
        case ollamaCoder
        case salehman                                // Salehman — cloud-first, local floor
        case unslothStudio                           // local OpenAI-compat server (Unsloth Studio / mlx_lm.server / LM Studio)
        case vllm                                    // local OpenAI-compat server served by vLLM
        case uncensored                              // local Ollama, abliterated ~3B; web-search capable
        case claudeHaiku, grok                       // cloud, pre-existing
        case gemini, groq, mistral, cerebras         // cloud, free-tier
        case codex, copilot                          // cloud, OpenAI + GitHub Copilot
        case openRouter                              // cloud aggregator (free models)
        case ensemble                                // all reachable brains in parallel
        case freeAuto                                // free brains raced; first valid wins; local backstop
        case freeCoding                              // free coders raced, tool-capable, coding-focused
        case cloudCoding                             // CLOUD-ONLY best coders, tool-capable (no local, no lag)
        case none
    }

    /// Best brain available right now, honoring the user's `BrainPreference`:
    ///   * `.ollama` → return Ollama qwen-coder if reachable, else `.none`.
    ///   * `.auto`   → local-first: Ollama qwen-coder when the server is up.
    /// Returning `.none` short-circuits the pipeline with the canonical
    /// "no brain reachable" message instead of silently using the other side.
    static func currentBrain() async -> Brain {
        // The reachability RULES (offline hard-gate on cloud pins, per-pin key
        // checks, roster membership, the .auto local-first invariant) live in
        // `BrainRouting.reachableBrain` — pure, pinned by
        // BrainRoutingDispatchTests. `BrainRouteConfig.live()` keeps the old
        // per-preference probe laziness (no Ollama HTTP probe for a pinned
        // cloud brain — BrainStatus polls this every 10s).
        let config = await BrainRouteConfig.live()
        return BrainRouting.reachableBrain(config)
    }

    /// True iff at least one brain (local or any keyed cloud) can answer.
    /// Used by ensemble mode to decide between fanning out and the off-message.
    nonisolated static func anyBrainReachable() async -> Bool {
        if await ollamaReady() { return true }
        return !CloudProvider.configuredNow().isEmpty
    }

    /// True when the user picked the "All Brains at Once" preference.
    nonisolated static var isEnsembleMode: Bool { AppSettings.brainPreferenceCurrent == .ensemble }

    // MARK: - Free · Auto (parallel race, never blocked)

    /// True when the user picked the "Free · Auto" preference.
    nonisolated static var isFreeAutoMode: Bool { AppSettings.brainPreferenceCurrent == .freeAuto }

    /// True when the user picked the "FreeCoding" preference — a coding-focused,
    /// tool-capable loop over the free coder brains.
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
        // Membership, order, and the Offline-Mode gate come from BrainRouting
        // (offline → empty roster, so only the local backstop below remains —
        // the stronger constraint). Execution stays here: each free brain runs
        // its plain `chat` on the user-selected model; Gemini is the one free
        // brain without the shared OpenAI-compat client.
        var roster: [(name: String, run: Thunk)] = []
        for p in BrainRouting.freeAutoRoster(routeConfigNow()) {
            guard let model = p.selectedModel else { continue }
            if p == .gemini {
                roster.append((p.rawValue, { await GeminiClient.chat(prompt: prompt, system: sys, model: model) }))
            } else if let client = p.compatClient {
                roster.append((p.rawValue, { await client.chat(prompt: prompt, system: sys, model: model) }))
            }
        }

        // Skip brains that failed within the cooldown window — don't waste a
        // round-trip on a known-bad key; they auto-retry once the window lapses.
        let cooling = await FreeAutoCooldown.shared.cooling(roster.map { $0.name }, now: now)
        let active = roster.filter { !cooling.contains($0.name) }

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
        //    Tool-capable via `chatOpenAICompatWithTools`. Membership/order +
        //    the Offline-Mode skip (the stronger constraint) come from
        //    BrainRouting; Gemini is excluded there (free, but no compat tools).
        for p in BrainRouting.freeAutoToolRoster(routeConfigNow()) {
            guard let client = p.compatClient, let model = p.selectedModel else { continue }
            if let reply = await chatOpenAICompatWithTools(client: client,
                                                          model: model,
                                                          message: message) {
                return reply
            }
        }
        // 3) Nothing tool-capable worked → the original fast race (no tools).
        return await generateFreeAuto(message)
    }

    // MARK: - FreeCoding (the free coding loop)

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
    /// usable reply wins; local Ollama coder backstop. Used by
    /// direct callers; the chat pipeline uses the tool-capable `freeCodingReply`.
    static func generateFreeCoding(_ prompt: String) async -> String {
        let sigState = signposter.beginInterval("freeCoding")
        defer { signposter.endInterval("freeCoding", sigState) }
        let sys = applyUnrestricted(freeCodingSystem)
        let now = Date()

        typealias Thunk = @Sendable () async -> String?
        // Membership, order, and the
        // Offline-Mode gate come from BrainRouting; each entry races its
        // strongest CODING model via `freeCoderModel`.
        var roster: [(name: String, run: Thunk)] = []
        for p in BrainRouting.codingRaceRoster(routeConfigNow()) {
            guard let client = p.compatClient, let models = p.coderModels else { continue }
            let model = freeCoderModel(models.all, default: models.def)
            roster.append((p.rawValue, { await client.chat(prompt: prompt, system: sys, model: model) }))
        }

        let cooling = await FreeAutoCooldown.shared.cooling(roster.map { $0.name }, now: now)
        let active = roster.filter { !cooling.contains($0.name) }

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
    /// free cloud coders → local Ollama
    /// coder, then a plain `generateFreeCoding` race so
    /// it never dead-ends. Same approval gate + blocked-command floor as always.
    static func freeCodingReply(_ message: String) async -> String {
        let sys = applyUnrestricted(freeCodingSystem)
        // CLOUD CODERS FIRST — the fast, no-lag path. They run on someone else's
        // GPUs (ZERO local RAM, so they never thrash a MacBook) and are ~10× faster
        // than a multi-GB local model — AND smarter than a local 7B. Order balances
        // smarts + speed: Cerebras / Groq
        // (blazing ~2000 tok/s, strong gpt-oss-120b) → OpenRouter → Mistral. Each
        // runs the tool loop so it can build / run / test. Skipped under Offline Mode.
        for p in BrainRouting.coderLoopRoster(routeConfigNow()) {
            guard let client = p.compatClient, let models = p.coderModels else { continue }
            let model = freeCoderModel(models.all, default: models.def)
            if let reply = await chatOpenAICompatWithTools(client: client, model: model,
                                                          message: message, systemPrompt: sys) {
                return reply
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

    /// Sync snapshot of the routing inputs the roster builders need (pins +
    /// offline + the ten key checks). The async probes (Ollama/MLX) stay out —
    /// roster membership never consults them.
    nonisolated private static func routeConfigNow() -> BrainRouteConfig {
        BrainRouteConfig(pref: AppSettings.brainPreferenceCurrent,
                         offlineOnly: AppSettings.isOfflineOnly,
                         configured: CloudProvider.configuredNow())
    }

    /// True iff any cloud coder is configured AND we're not offline — i.e. Cloud
    /// Coding can actually answer. No local fallback, so this is the honest gate.
    /// (The coder roster itself — membership + order — lives in
    /// `CloudProvider.coderLoop`, shared with freeCodingReply / cloudCoding.)
    nonisolated static func cloudCodingReachable() -> Bool {
        guard !AppSettings.isOfflineOnly else { return false }
        return CloudProvider.coderLoop.contains { $0.isConfiguredNow }
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
        for p in BrainRouting.coderLoopRoster(routeConfigNow()) {
            guard let client = p.compatClient, let models = p.coderModels else { continue }
            let model = freeCoderModel(models.all, default: models.def)
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
        for p in BrainRouting.coderLoopRoster(routeConfigNow()) {
            guard let client = p.compatClient, let models = p.coderModels else { continue }
            let model = freeCoderModel(models.all, default: models.def)
            if let reply = await chatOpenAICompatWithTools(client: client, model: model,
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
    nonisolated static func ollamaReady() async -> Bool {
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
        case .uncensored:        return "Local · Uncensored · \(OllamaClient.uncensoredModel)"
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
        case .freeCoding:        return "FreeCoding · free coders · runs the terminal"
        case .cloudCoding:       return "Cloud Coding · best cloud coders · no local, no lag"
        case .none:
            // Name the pinned-but-down brain so the header matches the chat message.
            switch AppSettings.brainPreferenceCurrent {
            case .ollama:  return "Ollama selected · not running"
            case .copilot: return "Copilot selected · sign in needed"
            case .salehman:
                // Local-only: MLX (on-device) → Ollama. Ollama auto-starts on launch;
                // the only fix when this fires is pulling the model.
                return "Salehman: pull the model — `ollama pull \(AppSettings.customModelNameCurrent)`"
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
            case .uncensored:
                return "Uncensored: pull the model — `ollama pull \(OllamaClient.uncensoredModel)`"
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
        // Cloud membership + the Offline-Mode gate (ensemble runs LOCAL-only
        // offline) come from BrainRouting.ensembleCloudRoster. Labels/calls
        // stay per-provider here.
        for p in BrainRouting.ensembleCloudRoster(routeConfigNow()) {
            switch p {
            case .anthropic:
                roster.append(("Claude Haiku", { await AnthropicClient.chat(prompt: prompt, system: sys) }))
            case .grok:
                let model = AppSettings.grokModelCurrent
                roster.append(("xAI \(model)", { await GrokClient.chat(prompt: prompt, system: sys, model: model) }))
            case .gemini:
                let model = AppSettings.geminiModelCurrent
                roster.append(("Google \(model)", { await GeminiClient.chat(prompt: prompt, system: sys, model: model) }))
            case .openAI:
                let model = AppSettings.openAIModelCurrent
                roster.append(("OpenAI \(model)", { await OpenAIClient.chat(prompt: prompt, system: sys, model: model) }))
            case .copilot:
                roster.append(("GitHub Copilot", { await CopilotClient.chat(prompt: prompt, system: sys) }))
            case .groq, .mistral, .cerebras, .openRouter:
                if let client = p.compatClient, let model = p.selectedModel {
                    roster.append(("\(p.rawValue) \(model)", { await client.chat(prompt: prompt, system: sys, model: model) }))
                }
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

    TOOLS: In this mode you have no local tools or web access. If a task needs \
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

    /// `read_grok_session` — live snapshot of the latest Grok terminal-bridge session.
    /// No parameters; reads ~/grok_sessions/*.log (newest file). On-device, read-only.
    nonisolated(unsafe) static let readGrokSessionSpec: [String: Any] = [
        "type": "function",
        "function": [
            "name": "read_grok_session",
            "description": "Read the latest Grok terminal-bridge session log and return a snapshot: what task Grok is working on, which turn it's on, how long it's been running, and the last few commands it ran with their outputs. Use when the user asks what Grok is doing, how it's progressing, or whether it finished. No arguments needed.",
            "parameters": [
                "type": "object",
                "properties": [:] as [String: Any],
                "required": [] as [String],
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
            rememberFactSpec, packRepositorySpec, readGrokSessionSpec,
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
    /// falls through to the terminal / web / unknown branches. `@MainActor` (also the
    /// project's default isolation) because `ScratchpadStore` is — the tool loops are
    /// `@MainActor` too, so they call it directly. All four tools are non-destructive writes to the
    /// user's own local stores, so (like the prior FM tools) they need no approval
    /// card — only the terminal does.
    @MainActor
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
        case "read_grok_session":
            return GrokWatchTool.readLatestSession()
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
            "read_grok_session",
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
    static func chatOllamaWithTools(_ message: String, systemPrompt: String? = nil,
                                    modelOverride: String? = nil) async -> String? {
        // `modelOverride` pins a specific tag (the Uncensored brain forces its
        // abliterated ~3B) instead of the pref-based active chat model.
        let model: String
        if let modelOverride { model = modelOverride }
        else if let active = await OllamaClient.activeChatModel() { model = active }
        else { return nil }
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
        // Per-model knobs: the user's own 14B stays warm 5 min (re-paying its
        // ~9 GB load mid-conversation is the single worst local latency hit);
        // smaller models keep the RAM-lean 30 s eviction. num_ctx floors at
        // 4096 regardless — tool transcripts (persona + specs + results) are
        // fat, and `tuned`'s 2048 default would truncate them for small models.
        let gen = OllamaClient.Generation.tuned(for: model)
        // Build the /api/chat body locally and serialize to Data (Sendable) so the
        // non-Sendable [[String:Any]] never crosses into the nonisolated client.
        // `num_predict` bounds each turn (a tool-round answer or a chain step):
        // unbounded on a ~25 tok/s local 14B means a rambling turn can hold the
        // serial slot for minutes. 2048 is roomy for a full code answer.
        func bodyData(includeTools: Bool) -> Data? {
            var body: [String: Any] = ["model": model, "messages": messages,
                                       "stream": false, "keep_alive": gen.keepAlive,
                                       "options": ["num_ctx": max(gen.numCtx, 4096),
                                                   "num_predict": toolTurnTokenCap]]
            if includeTools { body["tools"] = toolSpecs }
            return try? JSONSerialization.data(withJSONObject: body)
        }

        // Headroom for multi-step tasks (was 5 — too low; coding/tool chains
        // routinely needed more and hit the cap, surfacing "(Reached the tool-call
        // limit.)" to the user). We also remember the model's most recent prose so a
        // cap-out returns real content instead of that bare message.
        let maxRounds = 8
        var lastAssistantText = ""
        for round in 0..<maxRounds {
            // Stop pressed mid-mission (CodeView/chat cancels the task): abort
            // BETWEEN rounds so a dead mission can't hold the serial 14B slot
            // for minutes finishing rounds nobody wants. Mid-request cancels
            // already surface as a nil chatTurn (URLSession is cancellation-aware).
            if Task.isCancelled { return lastAssistantText.isEmpty ? nil : lastAssistantText }
            // A round on the 14B can take 30–90 s — show life on the running
            // team step ("· tool round N/8"). No-op outside team missions.
            await MainActor.run { MissionProgress.shared.noteToolRound(round + 1, of: maxRounds) }
            guard let data = bodyData(includeTools: true),
                  let turn = await OllamaClient.chatTurn(bodyData: data) else {
                return lastAssistantText.isEmpty ? nil : lastAssistantText
            }
            // Strip reasoning-model think blocks before storing in context:
            // they waste tokens in every subsequent round without adding value.
            let turnText = AgentPipeline.stripNarration(turn.text)
            if !turnText.isEmpty { lastAssistantText = turnText }
            var toolCalls = turn.toolCalls
            if toolCalls.isEmpty, let recovered = Self.parseTextAsToolCall(turnText) {
                toolCalls = [OllamaClient.ToolCall(name: recovered.name, arguments: recovered.arguments)]
            }
            if toolCalls.isEmpty {
                return turnText.isEmpty ? (lastAssistantText.isEmpty ? nil : lastAssistantText) : turnText
            }
            // Record the assistant's tool-call turn, then run each call and append
            // its result as a `tool` message so the model can chain / summarize.
            var assistantMsg: [String: Any] = ["role": "assistant", "content": turnText]
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
        // Skipped when cancelled: a dead mission doesn't pay the wrap-up generate.
        if Task.isCancelled { return lastAssistantText.isEmpty ? nil : lastAssistantText }
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

    /// Per-turn output bound shared by both tool loops (Ollama `num_predict`,
    /// OpenAI-compat `max_tokens`). Without it a local server generates until
    /// its context runs out — minutes per turn on a ~25 tok/s 14B. 2048 fits a
    /// complete code answer while keeping the worst-case turn bounded.
    nonisolated static let toolTurnTokenCap = 2048

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
        // `max_tokens` mirrors the Ollama loop's `num_predict` bound: an absent
        // cap makes vLLM/Studio generate to their max_model_len — minutes per
        // turn on a slow local server.
        func bodyData(includeTools: Bool) -> Data? {
            var body: [String: Any] = ["model": model, "messages": messages, "stream": false,
                                       "max_tokens": toolTurnTokenCap]
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
        for round in 0..<maxRounds {
            // Same Stop-pressed abort as the Ollama loop: bail between rounds.
            if Task.isCancelled { return lastAssistantText.isEmpty ? nil : lastAssistantText }
            // Same round-progress note as the Ollama loop — a local Unsloth
            // Studio / vLLM server can be just as slow per round as Ollama.
            await MainActor.run { MissionProgress.shared.noteToolRound(round + 1, of: maxRounds) }
            guard let data = bodyData(includeTools: true),
                  let turn = await client.chatTurnWithTools(bodyData: data) else {
                return lastAssistantText.isEmpty ? nil : lastAssistantText
            }
            // Strip reasoning-model think blocks before recording into context — same
            // rationale as chatOllamaWithTools: keeps every round lean.
            let turnText = AgentPipeline.stripNarration(turn.text)
            if !turnText.isEmpty { lastAssistantText = turnText }
            var toolCalls = turn.toolCalls
            if toolCalls.isEmpty, let recovered = Self.parseTextAsToolCall(turnText) {
                toolCalls = [OpenAICompatibleClient.ToolCall(id: "recovered_0", name: recovered.name, arguments: recovered.arguments)]
            }
            if toolCalls.isEmpty {
                return turnText.isEmpty ? (lastAssistantText.isEmpty ? nil : lastAssistantText) : turnText
            }
            // Echo the assistant's tool-call turn verbatim — OpenAI requires the
            // assistant message carry the `tool_calls` array so the following
            // `tool` results can be matched back by id. `content` is null (not "")
            // when the model only called tools, which strict servers require.
            var assistantMsg: [String: Any] = [
                "role": "assistant",
                "content": turnText.isEmpty ? NSNull() : turnText,
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
        // Skipped when cancelled: a dead mission doesn't pay the wrap-up generate.
        if Task.isCancelled { return lastAssistantText.isEmpty ? nil : lastAssistantText }
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
    static func ollamaReply(_ message: String, systemPrompt: String? = nil,
                            modelOverride: String? = nil) async -> String? {
        if let withTools = await chatOllamaWithTools(message, systemPrompt: systemPrompt,
                                                     modelOverride: modelOverride) { return withTools }
        return await OllamaClient.chat(prompt: message, system: systemPrompt ?? ollamaChatSystem,
                                       model: modelOverride)
    }

    // The per-brain pin gates ("each cloud brain is only tried when the user
    // explicitly pins it — we never silently spend on a cloud API") moved to
    // `BrainRouting.dispatch`: one switch, one source of truth, pinned by
    // BrainRoutingDispatchTests. The ladders below consume the dispatch.

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
        // The pinned target comes from BrainRouting.dispatch — ONE source of
        // truth for gating (the old cascade of pin-gates was a single-dispatch
        // ladder in disguise). Notable rules enforced there:
        //   • the orchestration modes are first-class (direct callers — the
        //     Settings health-check, StockSage briefings, title generation —
        //     reach the model layer through here; this fixed the old falsely-
        //     "Not working" ensemble probe bug);
        //   • Offline Mode hard-gates the ten cloud pins → `.unavailable`
        //     (the Offline-leak fix: `currentBrain` always documented this
        //     contract, but this cascade never enforced it).
        switch BrainRouting.dispatch(pref: pref, offlineOnly: AppSettings.isOfflineOnly) {
        case .mode(.freeAuto):    return await generateFreeAuto(prompt)
        case .mode(.freeCoding):  return await generateFreeCoding(prompt)
        case .mode(.cloudCoding): return await generateCloudCoding(prompt)
        case .mode(.ensemble):    return await generateEnsemble(prompt)
        case .mode:               return offMessage   // unreachable: dispatch emits only the 4 modes
        case .cloud(let p):
            // Pinned cloud brain — strict, no silent fallback (nil reply →
            // sentinel, exactly like the old fall-through-to-nothing).
            if let reply = await cloudOneShot(p, prompt: prompt, rawPrompt: rawPrompt,
                                              cachePrefix: cachePrefix) { return reply }
            return offMessage
        case .salehman:
            // Salehman — LOCAL-FIRST: MLX (on-device) → Ollama (custom model).
            // No external cloud. Mirrors SalehmanEngine exactly.
            if let reply = await SalehmanEngine.generate(prompt: prompt, maxTokens: maxTokens) {
                return reply
            }
            return offMessage
        case .unslothStudio:
            // Unsloth Studio (or any local OpenAI-compatible server) — explicit pin,
            // no silent fallback. The endpoint URL is the only configuration.
            if let reply = await UnslothStudio.chat(prompt: prompt) { return reply }
            return offMessage
        case .vllm:
            // vLLM — explicit pin, no silent fallback (same discipline as Unsloth Studio).
            if let reply = await VLLM.chat(prompt: prompt) { return reply }
            return offMessage
        case .localTier:
            // Local tier (Ollama): free & on-device.
            if let reply = await OllamaClient.chat(prompt: prompt, system: Self.ollamaChatSystem) { return reply }
            return offMessage
        case .uncensoredLocal:
            // Uncensored local tier — forces the abliterated ~3B model.
            if let reply = await OllamaClient.chat(prompt: prompt, system: Self.ollamaChatSystem,
                                                   model: OllamaClient.uncensoredModel) { return reply }
            return offMessage
        case .unavailable:
            // Offline Mode + a pinned cloud brain: nothing may leave the Mac.
            return offMessage
        }
    }

    /// One pinned cloud brain's `generate` execution: plain chat on the
    /// user-selected model. Claude receives the un-folded prompt + cachePrefix
    /// (its client caches the prefix as a `cache_control` block); every other
    /// brain gets the folded prompt. Gating/membership come from BrainRouting.
    private static func cloudOneShot(_ p: CloudProvider, prompt: String,
                                     rawPrompt: String, cachePrefix: String?) async -> String? {
        switch p {
        case .anthropic:  return await AnthropicClient.chat(prompt: rawPrompt, cachePrefix: cachePrefix)
        case .copilot:    return await CopilotClient.chat(prompt: prompt)
        case .grok:       return await GrokClient.chat(prompt: prompt, model: AppSettings.grokModelCurrent)
        case .gemini:     return await GeminiClient.chat(prompt: prompt, model: AppSettings.geminiModelCurrent)
        case .openAI:     return await OpenAIClient.chat(prompt: prompt, model: AppSettings.openAIModelCurrent)
        case .groq:       return await GroqClient.shared.chat(prompt: prompt, model: AppSettings.groqModelCurrent)
        case .mistral:    return await MistralClient.shared.chat(prompt: prompt, model: AppSettings.mistralModelCurrent)
        case .cerebras:   return await CerebrasClient.shared.chat(prompt: prompt, model: AppSettings.cerebrasModelCurrent)
        case .openRouter: return await OpenRouterClient.shared.chat(prompt: prompt, model: AppSettings.openRouterModelCurrent)
        }
    }

    /// **On-device-only** one-shot generation. Runs EXCLUSIVELY the local tier
    /// (Ollama), ignoring the user's pinned brain — so a pinned cloud brain can
    /// never cause privacy-sensitive content to leave the Mac. This is the entry
    /// point for features that PROMISE privacy (the Knowledge vault's "on this
    /// Mac" summary/Q&A). Returns `nil` when no on-device model is available, so
    /// the caller can say so honestly rather than silently falling back to cloud.
    static func generateOnDevice(_ prompt: String, maxTokens: Int? = nil) async -> String? {
        // Forward the caller's token budget — dropping it let a 110-token "terse
        // note" run unbounded on the local 14B (~15 tok/s ⇒ a minute of ramble).
        if let reply = await OllamaClient.chat(prompt: prompt, system: Self.ollamaChatSystem,
                                               maxTokens: maxTokens) { return reply }
        // Unsloth Studio (or any local OpenAI-compat server) qualifies as
        // on-device ONLY when its endpoint is a loopback URL — see
        // `UnslothStudio.isLocalLoopback`. A user-typed public URL would NOT
        // satisfy the privacy promise, so we don't route here in that case.
        if UnslothStudio.isLocalLoopback, let reply = await UnslothStudio.chat(prompt: prompt) { return reply }
        // vLLM: same loopback guard — only qualifies as on-device when the
        // configured endpoint is localhost/127.0.0.1/::1 (see VLLM.isLocalLoopback).
        if VLLM.isLocalLoopback, let reply = await VLLM.chat(prompt: prompt) { return reply }
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
        // Same single-dispatch plan as `generate` (BrainRouting.dispatch) —
        // including the Offline-Mode hard-gate on cloud pins. The orchestration
        // modes can't token-stream (they join N replies into one document), so
        // each delivers its combined answer in a single `onUpdate`.
        //
        // On any failure exit we return the sentinel so equality-check callers
        // (`synthesize`, etc.) still fire, but we DO NOT push it into
        // `onUpdate` — that would paint the streaming UI with the sentinel
        // even while another agent (e.g. the non-streaming `LocalLLM.chat`
        // path used by the Reasoning Strategist) is happily producing a real
        // reply. The display layer transforms the sentinel into the
        // context-aware `unavailableMessage` at render time.
        switch BrainRouting.dispatch(pref: pref, offlineOnly: AppSettings.isOfflineOnly) {
        case .mode(.freeAuto):
            // Race the free brains; deliver the single winning answer in one
            // update (the race joins to one reply — there's nothing to stream).
            let answer = await generateFreeAuto(prompt)
            onUpdate(answer)
            return answer
        case .mode(.freeCoding):
            let answer = await generateFreeCoding(prompt)
            onUpdate(answer)
            return answer
        case .mode(.cloudCoding):
            let answer = await generateCloudCoding(prompt)
            onUpdate(answer)
            return answer
        case .mode(.ensemble):
            let combined = await generateEnsemble(prompt)
            onUpdate(combined)
            return combined
        case .mode:
            return offMessage   // unreachable: dispatch emits only the 4 modes
        case .cloud(let p):
            if let reply = await cloudStream(p, prompt: prompt, rawPrompt: rawPrompt,
                                             cachePrefix: cachePrefix, onUpdate: onUpdate) { return reply }
            return offMessage
        case .salehman:
            // Salehman streaming — CLOUD-FIRST via the shared engine (streams from the
            // cloud brain; falls back to local MLX/Ollama streaming when offline).
            if let reply = await SalehmanEngine.generateStream(prompt: prompt,
                                                               maxTokens: maxTokens,
                                                               onUpdate: onUpdate) {
                return reply
            }
            return offMessage
        case .unslothStudio:
            // Explicit pin; stream first, then the same brain's non-streaming
            // chat before declaring it dead (same discipline as the SSE paths).
            if let r = await UnslothStudio.chatStream(prompt: prompt, onUpdate: onUpdate) { return r }
            if let r = await UnslothStudio.chat(prompt: prompt) { return r }
            return offMessage
        case .vllm:
            if let r = await VLLM.chatStream(prompt: prompt, onUpdate: onUpdate) { return r }
            if let r = await VLLM.chat(prompt: prompt) { return r }
            return offMessage
        case .localTier:
            // Local tier — Ollama streaming.
            if let reply = await OllamaClient.chatStream(prompt: prompt, system: Self.ollamaChatSystem, onUpdate: onUpdate) {
                return reply
            }
            return offMessage
        case .uncensoredLocal:
            // Uncensored local tier — streams the abliterated ~3B model.
            if let reply = await OllamaClient.chatStream(prompt: prompt, system: Self.ollamaChatSystem,
                                                         model: OllamaClient.uncensoredModel, onUpdate: onUpdate) {
                return reply
            }
            return offMessage
        case .unavailable:
            // Offline Mode + a pinned cloud brain: nothing may leave the Mac.
            return offMessage
        }
    }

    /// One pinned cloud brain's streaming execution: the brain's SSE
    /// `chatStream` first, then the SAME brain's non-streaming `chat` before
    /// declaring it dead — one bad SSE chunk doesn't make a working brain look
    /// unreachable. Claude keeps its raw-prompt + cachePrefix handling.
    private static func cloudStream(_ p: CloudProvider, prompt: String, rawPrompt: String,
                                    cachePrefix: String?,
                                    onUpdate: @escaping @Sendable (String) -> Void) async -> String? {
        switch p {
        case .anthropic:
            if let r = await AnthropicClient.chatStream(prompt: rawPrompt, cachePrefix: cachePrefix, onUpdate: onUpdate) { return r }
            return await AnthropicClient.chat(prompt: rawPrompt, cachePrefix: cachePrefix)
        case .copilot:
            if let r = await CopilotClient.chatStream(prompt: prompt, onUpdate: onUpdate) { return r }
            return await CopilotClient.chat(prompt: prompt)
        case .grok:
            let m = AppSettings.grokModelCurrent
            if let r = await GrokClient.chatStream(prompt: prompt, model: m, onUpdate: onUpdate) { return r }
            return await GrokClient.chat(prompt: prompt, model: m)
        case .gemini:
            let m = AppSettings.geminiModelCurrent
            if let r = await GeminiClient.chatStream(prompt: prompt, model: m, onUpdate: onUpdate) { return r }
            return await GeminiClient.chat(prompt: prompt, model: m)
        case .openAI:
            let m = AppSettings.openAIModelCurrent
            if let r = await OpenAIClient.chatStream(prompt: prompt, model: m, onUpdate: onUpdate) { return r }
            return await OpenAIClient.chat(prompt: prompt, model: m)
        case .groq:
            let m = AppSettings.groqModelCurrent
            if let r = await GroqClient.shared.chatStream(prompt: prompt, model: m, onUpdate: onUpdate) { return r }
            return await GroqClient.shared.chat(prompt: prompt, model: m)
        case .mistral:
            let m = AppSettings.mistralModelCurrent
            if let r = await MistralClient.shared.chatStream(prompt: prompt, model: m, onUpdate: onUpdate) { return r }
            return await MistralClient.shared.chat(prompt: prompt, model: m)
        case .cerebras:
            let m = AppSettings.cerebrasModelCurrent
            if let r = await CerebrasClient.shared.chatStream(prompt: prompt, model: m, onUpdate: onUpdate) { return r }
            return await CerebrasClient.shared.chat(prompt: prompt, model: m)
        case .openRouter:
            let m = AppSettings.openRouterModelCurrent
            if let r = await OpenRouterClient.shared.chatStream(prompt: prompt, model: m, onUpdate: onUpdate) { return r }
            return await OpenRouterClient.shared.chat(prompt: prompt, model: m)
        }
    }

    /// Multi-turn chat that remembers prior messages. Routes through the
    /// tool-enabled Ollama/cloud loop;
    /// otherwise falls back to Ollama qwen-coder *without* tools.
    static func chat(_ message: String) async -> String {
        // Same single-dispatch plan (BrainRouting.dispatch), including the
        // Offline-Mode hard-gate on cloud pins. Chat-shape specifics live in
        // `cloudConversational`: the OpenAI-compatible brains run the TOOL
        // loop first (so a pinned cloud brain can drive the terminal), the
        // bespoke clients run plain chat.
        switch BrainRouting.dispatch(pref: pref, offlineOnly: AppSettings.isOfflineOnly) {
        case .mode(.freeAuto):    return await generateFreeAuto(message)
        case .mode(.freeCoding):  return await freeCodingReply(message)
        case .mode(.cloudCoding): return await cloudCodingReply(message)
        case .mode(.ensemble):    return await generateEnsemble(message)
        case .mode:               return offMessage   // unreachable: dispatch emits only the 4 modes
        case .cloud(let p):
            if let reply = await cloudConversational(p, message: message) { return reply }
            return offMessage
        case .salehman:
            // Salehman — CLOUD-FIRST via the shared engine, WITH tools: each cloud
            // brain can run the terminal / web through the OpenAI `tools` field, and
            // the local MLX/Ollama floor keeps tools too (`ollamaReply`). Exactly the
            // engine the leader uses. No further fallback.
            if let reply = await SalehmanEngine.generateWithTools(message: message, userPrompt: message) {
                return reply
            }
            return offMessage
        case .unslothStudio:
            // Explicit pin. Tool-calling first via its OpenAI-compatible `tools`
            // field, so the Studio model can run the terminal; plain chat if the
            // server doesn't support tools or the tool turn errors out.
            if let reply = await UnslothStudio.chatWithTools(message) { return reply }
            if let reply = await UnslothStudio.chat(prompt: message, system: Self.cloudSystemPrompt) { return reply }
            return offMessage
        case .vllm:
            if let reply = await VLLM.chatWithTools(message) { return reply }
            if let reply = await VLLM.chat(prompt: message, system: Self.cloudSystemPrompt) { return reply }
            return offMessage
        case .localTier:
            // Local tier — Ollama runs the terminal via `ollamaReply`'s tool loop.
            if let reply = await ollamaReply(message) { return reply }
            return offMessage
        case .uncensoredLocal:
            // Uncensored local tier — same tool loop (web_search/fetch_url when
            // web access is on & not Offline), pinned to the abliterated ~3B model.
            if let reply = await ollamaReply(message, modelOverride: OllamaClient.uncensoredModel) { return reply }
            return offMessage
        case .unavailable:
            // Offline Mode + a pinned cloud brain: nothing may leave the Mac.
            return offMessage
        }
    }

    /// One pinned cloud brain's conversational execution. Six OpenAI-compatible
    /// brains (including Grok — xAI's API is fully wire-compatible) try the
    /// tool loop first (terminal / web), then fall back to plain chat.
    /// Claude / Gemini / Copilot are plain chat only (bespoke wire formats).
    private static func cloudConversational(_ p: CloudProvider, message: String) async -> String? {
        switch p {
        case .anthropic:
            // Claude Haiku (cloud), single-turn, no local tools.
            return await AnthropicClient.chat(prompt: message, system: Self.cloudSystemPrompt)
        case .gemini:
            return await GeminiClient.chat(prompt: message,
                                           system: Self.cloudSystemPrompt,
                                           model: AppSettings.geminiModelCurrent)
        case .copilot:
            return await CopilotClient.chat(prompt: message, system: Self.cloudSystemPrompt)
        case .grok, .groq, .mistral, .cerebras, .openAI, .openRouter:
            guard let client = p.compatClient, let m = p.selectedModel else { return nil }
            if let reply = await chatOpenAICompatWithTools(client: client, model: m, message: message) { return reply }
            return await client.chat(prompt: message, system: Self.cloudSystemPrompt, model: m)
        }
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

