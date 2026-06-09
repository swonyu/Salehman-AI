import Foundation

/// **The one Salehman brain engine — CLOUD-FIRST.**
///
/// This is the single definition of "what engine *is* Salehman," shared by BOTH
/// the `.salehman` brain (primary generation in `LocalLLM`) and the
/// `SalehmanLeader` final pass — so "Salehman as your brain" and "Salehman as the
/// leader" can never drift apart.
///
/// Salehman runs on the cloud whenever possible and only falls back to your Mac
/// when offline:
///   1. **your own hosted model** (vLLM / Unsloth Studio), if configured — your
///      weights win, because you deliberately stood them up;
///   2. **REAL DeepSeek V4 — FREE via NVIDIA** (`integrate.api.nvidia.com`), since
///      DeepSeek's own API + OpenRouter are paid-only;
///   3. **free frontier** (Kimi K2.6 ~1T, Nemotron-Ultra-550B) + the **free 120B**
///      tier (Cerebras / Groq / Mistral / OpenRouter) — five stacked free quotas;
///   4. **DeepSeek's paid API** — last-resort backstop (R1/V3 auto-routed);
///   5. the **local floor** — on-device MLX, then Ollama (truly unlimited, ~7B) so
///      Salehman still answers with no internet.
///
/// Each cloud entry runs only when its key is present, and a provider error
/// (401 / 404 / 429 rate-limit) rolls to the next brain — so rate limits stay
/// invisible and the chain self-heals when a free roster rotates. The persona is
/// always the system prompt, so the engine underneath never leaks into Salehman's
/// identity.
enum SalehmanEngine {

    // MARK: - Reachability

    /// True when at least one cloud engine is configured (hosted endpoint or any
    /// chain key). Lets `LocalLLM` mark Salehman "available" even with NO local
    /// model — because he now runs on the cloud first.
    nonisolated static var hasAnyCloud: Bool {
        VLLM.isConfigured || UnslothStudio.isConfigured
            || NvidiaClient.shared.hasKey()   || OpenRouterClient.shared.hasKey()
            || CerebrasClient.shared.hasKey()  || GroqClient.shared.hasKey()
            || MistralClient.shared.hasKey()   || DeepSeekClient.shared.hasKey()
            // Standalone cloud brains the owner may have pinned a key for — now
            // honored by `tryStandaloneClouds`, so they count as "cloud reachable"
            // (previously a Gemini/Claude/Grok/OpenAI-only setup read as "no cloud").
            || GeminiClient.hasKey()           || GrokClient.hasKey()
            || OpenAIClient.hasKey()           || AnthropicClient.isConfigured
    }

    // MARK: - Non-streaming

    /// Cloud-first single-shot generation. `userPrompt` (the user's original
    /// message) drives DeepSeek R1-vs-V3 routing when the chain reaches the paid
    /// backstop; pass it when known, else it falls back to `prompt`. Returns nil
    /// only when nothing — cloud or local — is reachable.
    static func generate(prompt: String,
                         userPrompt: String? = nil,
                         maxTokens: Int? = nil) async -> String? {
        if VLLM.isConfigured,
           let r = await VLLM.chat(prompt: prompt, system: SalehmanPersona.activeSystemPrompt) { return r }
        if UnslothStudio.isConfigured,
           let r = await UnslothStudio.chat(prompt: prompt, system: SalehmanPersona.activeSystemPrompt) { return r }

        for entry in cloudChain(routing: userPrompt ?? prompt) {
            if let r = await tryCloud(entry.client, model: entry.model, prompt: prompt) { return r }
        }
        // Then the owner's OWN standalone cloud keys (Gemini / Grok / OpenAI /
        // Claude) — not in the curated free chain — so ANY configured cloud key
        // makes Salehman work on the cloud, not just the six free coders.
        if let r = await tryStandaloneClouds(prompt: prompt) { return r }

        if await MLXSalehmanEngine.shared.isReady,
           let r = await MLXSalehmanEngine.shared.generate(prompt: prompt, maxTokens: maxTokens ?? 1024) { return r }
        if let r = await OllamaClient.chat(prompt: prompt, system: SalehmanPersona.activeSystemPrompt) { return r }
        return nil
    }

    // MARK: - Streaming

    /// Cloud-first streaming. `onUpdate` receives the cumulative text after each
    /// delta. On a no-key/error entry nothing is emitted (the cloud clients only
    /// call `onUpdate` on real SSE deltas), so the chain rolls on cleanly.
    static func generateStream(prompt: String,
                               userPrompt: String? = nil,
                               maxTokens: Int? = nil,
                               onUpdate: @escaping @Sendable (String) -> Void) async -> String? {
        if VLLM.isConfigured,
           let r = await VLLM.chatStream(prompt: prompt, system: SalehmanPersona.activeSystemPrompt, onUpdate: onUpdate) { return r }
        if UnslothStudio.isConfigured,
           let r = await UnslothStudio.chatStream(prompt: prompt, system: SalehmanPersona.activeSystemPrompt, onUpdate: onUpdate) { return r }

        for entry in cloudChain(routing: userPrompt ?? prompt) {
            if let r = await tryCloudStream(entry.client, model: entry.model, prompt: prompt, onUpdate: onUpdate) { return r }
        }
        // Owner's standalone cloud keys (Gemini / Grok / OpenAI / Claude), streamed.
        if let r = await tryStandaloneCloudsStream(prompt: prompt, onUpdate: onUpdate) { return r }

        if await MLXSalehmanEngine.shared.isReady,
           let r = await MLXSalehmanEngine.shared.generateStream(prompt: prompt, maxTokens: maxTokens ?? 1024, onUpdate: onUpdate) { return r }
        if let r = await OllamaClient.chatStream(prompt: prompt, system: SalehmanPersona.activeSystemPrompt, onUpdate: onUpdate) { return r }
        return nil
    }

    // MARK: - Tool-calling (agentic chat path)

    /// Cloud-first generation that can ALSO run the terminal / web tools, so the
    /// `.salehman` brain keeps its agentic powers when it runs on the cloud. Each
    /// brain tries the OpenAI `tools` field first; a server that rejects tools
    /// falls back to plain chat on the same brain, then the chain rolls on. The
    /// local floor keeps tools too (`ollamaReply`).
    static func generateWithTools(message: String, userPrompt: String? = nil) async -> String? {
        if VLLM.isConfigured,
           let r = await VLLM.chatWithTools(message, systemPrompt: SalehmanPersona.activeSystemPrompt) { return r }
        if UnslothStudio.isConfigured,
           let r = await UnslothStudio.chatWithTools(message, systemPrompt: SalehmanPersona.activeSystemPrompt) { return r }

        for entry in cloudChain(routing: userPrompt ?? message) {
            guard entry.client.hasKey() else { continue }
            let model = entry.model ?? entry.client.defaultModel
            if let r = await LocalLLM.chatOpenAICompatWithTools(client: entry.client,
                                                                model: model,
                                                                message: message,
                                                                systemPrompt: SalehmanPersona.activeSystemPrompt) {
                return r
            }
            // Tools unsupported by this model → plain chat before moving on.
            if let r = await tryCloud(entry.client, model: entry.model, prompt: message) { return r }
        }
        // Owner's standalone cloud keys (plain chat — these clients don't share the
        // OpenAI-compat tool loop; a real answer still beats the local floor).
        if let r = await tryStandaloneClouds(prompt: message) { return r }

        if await MLXSalehmanEngine.shared.isReady,
           let r = await MLXSalehmanEngine.shared.generate(prompt: message) { return r }
        if let r = await LocalLLM.ollamaReply(message, systemPrompt: SalehmanPersona.activeSystemPrompt) { return r }
        return nil
    }

    // MARK: - Self-improvement loop (Salehman ⇄ DeepSeek R1)

    /// **The "gets smarter every answer" loop.** Salehman's answer is handed to a
    /// DeepSeek reasoner (R1-class) which analyzes it and returns concrete fixes;
    /// Salehman then revises, applying the feedback, and returns the polished final.
    ///
    /// Fully graceful: if the critic is unreachable, or says the answer is already
    /// good, or the revision fails, the ORIGINAL answer is returned unchanged — the
    /// loop only ever improves, never blanks out or degrades a working reply.
    /// `rounds` allows >1 critique/revise cycle (default 1; each round is another
    /// ~2 cloud calls). The cloud-first chain inside each call already loops across
    /// the free providers on rate limits, so a 429 never stops the loop.
    static func refine(userPrompt: String, answer: String, rounds: Int = 1) async -> String {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return answer }

        var current = answer
        for _ in 0..<max(1, rounds) {
            // 1 — DeepSeek analyzes Salehman's current answer.
            guard let critique = await deepSeekCritique(userPrompt: userPrompt, answer: current) else {
                break   // no critic reachable → keep what we have
            }
            let c = critique.trimmingCharacters(in: .whitespacesAndNewlines)
            if c.isEmpty || c.uppercased().contains("NO CHANGES NEEDED") {
                break   // DeepSeek is satisfied → done
            }

            // 2 — Salehman revises, listening to DeepSeek's feedback.
            let revisePrompt = """
            The user asked:
            \"\"\"
            \(userPrompt)
            \"\"\"

            Your previous answer was:
            \"\"\"
            \(current)
            \"\"\"

            A senior reviewer (DeepSeek) analyzed it and gave you this feedback:
            \"\"\"
            \(c)
            \"\"\"

            You are Salehman. Apply every VALID point of the feedback and deliver \
            the FINAL, fully revised and corrected answer in your own voice. Keep \
            what was already right; fix what was wrong or missing. Output ONLY the \
            final answer — do not mention the reviewer, the feedback, or that any \
            revision happened. NEVER name or hint at any model or provider; you are \
            simply Salehman.
            """
            guard let revised = await generate(prompt: revisePrompt, userPrompt: userPrompt) else { break }
            let r = revised.trimmingCharacters(in: .whitespacesAndNewlines)
            if !r.isEmpty, revised != LocalLLM.offMessage { current = revised }
        }
        return current
    }

    /// Runs a DeepSeek reasoner as a critic over Salehman's answer, FREE-FIRST:
    /// NVIDIA's free `deepseek-v4-pro` → DeepSeek's paid `deepseek-reasoner` (R1) →
    /// a free frontier reasoner (Nemotron-550B) so the loop still runs at $0 when
    /// no DeepSeek key is set. Returns the feedback text, or nil if no critic is
    /// reachable. Uses a REVIEWER system prompt (not the Salehman persona) so the
    /// critique is adversarial, not self-congratulatory.
    private static func deepSeekCritique(userPrompt: String, answer: String) async -> String? {
        let system = """
        You are DeepSeek, a meticulous, senior reviewer. You will be given a user's \
        question and an assistant's answer. Analyze the answer rigorously for factual \
        errors, faulty reasoning, missing steps, gaps, and missed opportunities. \
        Respond with ONLY a short, concrete, numbered list of the specific changes \
        the assistant should make to improve it. Be direct and specific. If the \
        answer is already correct and complete, respond with exactly: NO CHANGES NEEDED.
        """
        let prompt = """
        User question:
        \"\"\"
        \(userPrompt)
        \"\"\"

        Assistant's answer to review:
        \"\"\"
        \(answer)
        \"\"\"
        """
        // Free-first critic chain. Each entry runs only if its key is present and
        // rolls onward on an error/429 — same discipline as the main chain.
        let critics: [(client: OpenAICompatibleClient, model: String)] = [
            (NvidiaClient.shared,   "deepseek-ai/deepseek-v4-pro"),   // FREE deep DeepSeek
            (DeepSeekClient.shared, "deepseek-reasoner"),             // paid R1
            (OpenRouterClient.shared, "nvidia/nemotron-3-ultra-550b-a55b:free"), // FREE reasoner fallback
        ]
        for critic in critics {
            guard critic.client.hasKey() else { continue }
            guard let reply = await critic.client.chat(prompt: prompt, system: system, model: critic.model) else { continue }
            if OpenAICompatibleClient.isErrorReply(reply, displayName: critic.client.displayName) { continue }
            let t = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return reply }
        }
        return nil
    }

    // MARK: - Chain (single source of truth)

    /// The free-first cloud chain. `routing` (the user's original prompt) only
    /// affects the paid DeepSeek backstop's R1/V3 choice. Model-string overrides
    /// pick each provider's strongest free option; nil uses the provider default.
    static func cloudChain(routing userPrompt: String) -> [(client: OpenAICompatibleClient, model: String?)] {
        [
            (NvidiaClient.shared,     "deepseek-ai/deepseek-v4-flash"),    // REAL DeepSeek V4 — FREE via NVIDIA
            (OpenRouterClient.shared, "moonshotai/kimi-k2.6:free"),              // FREE frontier (~1T MoE)
            (OpenRouterClient.shared, "nvidia/nemotron-3-ultra-550b-a55b:free"), // FREE 550B
            (CerebrasClient.shared,   nil),                        // gpt-oss-120b — FREE, very fast
            (GroqClient.shared,       "openai/gpt-oss-120b"),      // FREE 120B
            (MistralClient.shared,    "mistral-large-latest"),     // FREE tier — another quota bucket
            (OpenRouterClient.shared, "openai/gpt-oss-120b:free"), // FREE 120B safe fallback
            (DeepSeekClient.shared,   deepSeekModel(for: userPrompt)),  // paid API — last-resort backstop
        ]
    }

    /// Call one cloud brain with the Salehman persona. Returns its reply, or nil
    /// when the key is missing OR the provider returned an error body — so a 429
    /// rate-limit / 401 bad-key rolls to the next brain instead of surfacing
    /// "[Groq error 429: …]" *as* Salehman.
    static func tryCloud(_ client: OpenAICompatibleClient,
                         model: String?,
                         prompt: String) async -> String? {
        guard client.hasKey() else { return nil }
        guard let reply = await client.chat(prompt: prompt,
                                            system: SalehmanPersona.activeSystemPrompt,
                                            model: model) else { return nil }
        if OpenAICompatibleClient.isErrorReply(reply, displayName: client.displayName) { return nil }
        return reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reply
    }

    /// Streaming sibling of `tryCloud`. `chatStream` returns its error body
    /// WITHOUT emitting deltas on a non-200, so an error here means nothing was
    /// streamed and we can roll to the next brain safely.
    static func tryCloudStream(_ client: OpenAICompatibleClient,
                               model: String?,
                               prompt: String,
                               onUpdate: @escaping @Sendable (String) -> Void) async -> String? {
        guard client.hasKey() else { return nil }
        guard let reply = await client.chatStream(prompt: prompt,
                                                  system: SalehmanPersona.activeSystemPrompt,
                                                  model: model,
                                                  onUpdate: onUpdate) else { return nil }
        if OpenAICompatibleClient.isErrorReply(reply, displayName: client.displayName) { return nil }
        return reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reply
    }

    /// Try the owner's OWN standalone cloud keys (Gemini / Grok / OpenAI / Claude),
    /// each with the Salehman persona, skipping any that error or return nil. These
    /// are NOT in `cloudChain` (the curated free-coder list with bespoke API shapes),
    /// so without this a user whose only cloud key is one of these would never reach
    /// the cloud on the Salehman brain. Free-tier Gemini first, then the pinned paid
    /// brains — preserves "free-first" since this runs only after the free chain.
    static func tryStandaloneClouds(prompt: String) async -> String? {
        let persona = SalehmanPersona.activeSystemPrompt
        if GeminiClient.hasKey(),
           let r = await GeminiClient.chat(prompt: prompt, system: persona, model: AppSettings.geminiModelCurrent),
           !AgentPipeline.isErrorReply(r) { return r }
        if GrokClient.hasKey(),
           let r = await GrokClient.chat(prompt: prompt, system: persona, model: AppSettings.grokModelCurrent),
           !AgentPipeline.isErrorReply(r) { return r }
        if OpenAIClient.hasKey(),
           let r = await OpenAIClient.chat(prompt: prompt, system: persona, model: AppSettings.openAIModelCurrent),
           !AgentPipeline.isErrorReply(r) { return r }
        if AnthropicClient.isConfigured,
           let r = await AnthropicClient.chat(prompt: prompt, system: persona),
           !AgentPipeline.isErrorReply(r) { return r }
        return nil
    }

    /// Streaming sibling of `tryStandaloneClouds`. Same order + error-skip.
    static func tryStandaloneCloudsStream(prompt: String,
                                          onUpdate: @escaping @Sendable (String) -> Void) async -> String? {
        let persona = SalehmanPersona.activeSystemPrompt
        if GeminiClient.hasKey(),
           let r = await GeminiClient.chatStream(prompt: prompt, system: persona, model: AppSettings.geminiModelCurrent, onUpdate: onUpdate),
           !AgentPipeline.isErrorReply(r) { return r }
        if GrokClient.hasKey(),
           let r = await GrokClient.chatStream(prompt: prompt, system: persona, model: AppSettings.grokModelCurrent, onUpdate: onUpdate),
           !AgentPipeline.isErrorReply(r) { return r }
        if OpenAIClient.hasKey(),
           let r = await OpenAIClient.chatStream(prompt: prompt, system: persona, model: AppSettings.openAIModelCurrent, onUpdate: onUpdate),
           !AgentPipeline.isErrorReply(r) { return r }
        if AnthropicClient.isConfigured,
           let r = await AnthropicClient.chatStream(prompt: prompt, system: persona, onUpdate: onUpdate),
           !AgentPipeline.isErrorReply(r) { return r }
        return nil
    }

    /// Picks which DeepSeek brain finalizes a given prompt when the paid backstop
    /// is reached: **R1 (`deepseek-reasoner`)** for hard, multi-step / math / logic
    /// prompts, the faster **V3 (`deepseek-chat`)** otherwise — both DeepSeek
    /// brains in one. Best-effort heuristic; when in doubt it stays on fast V3.
    static func deepSeekModel(for userPrompt: String) -> String {
        let p = userPrompt.lowercased()
        let reasoningCues = [
            "prove", "proof", "derive", "step by step", "step-by-step", "reason",
            "explain why", "how come", "logic", "puzzle", "riddle", "solve",
            "calculate", "equation", "integral", "derivative", "probability",
            "theorem", "optimi", "complexity", "algorithm", "trade-off",
            "tradeoff", "analy",
        ]
        if reasoningCues.contains(where: p.contains) { return "deepseek-reasoner" }
        if userPrompt.count > 800 { return "deepseek-reasoner" }
        return "deepseek-chat"
    }
}
