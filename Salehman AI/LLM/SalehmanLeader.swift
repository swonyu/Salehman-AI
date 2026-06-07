import Foundation

/// **Salehman as the leader brain.**
///
/// When enabled, every other brain's answer is handed to the Salehman model for
/// one final pass, so Salehman owns the last word regardless of which brain
/// drafted the reply. This is the single place that turns "many models" into
/// "one leader speaks." Wired into `AgentPipeline.run`, which every user-facing
/// reply funnels through.
///
/// Design rules:
/// - **Self-disabling:** a no-op when the setting is off, when the user already
///   pinned `.salehman` (no point re-passing), or when the draft is an error/off
///   message.
/// - **Graceful:** if the Salehman engine isn't reachable it returns the draft
///   UNCHANGED — it never blanks out a reply just because Salehman is offline.
/// - **Cloud-capable:** the engine chain prefers a configured remote endpoint
///   (cloud vLLM / Unsloth Studio) so Salehman can lead on a strong hosted model,
///   then falls back to standalone MLX, then the local Ollama model.
/// - **No Apple Intelligence:** Salehman is its own thing; it never borrows
///   Apple's on-device model and must never present itself as such.
enum SalehmanLeader {

    /// Whether the final Salehman pass should run for the current turn.
    static var isLeading: Bool {
        guard AppSettings.salehmanLeaderEnabled else { return false }
        let pref = UserDefaults.standard.string(forKey: AppSettings.Keys.brainPreference)
        // Don't double-pass when the user already pinned Salehman as the brain.
        if pref == BrainPreference.salehman.rawValue { return false }
        // Step aside for the dedicated coding modes — a small leader shouldn't
        // rewrite (and risk breaking) the coder loop's tool-built output.
        if pref == BrainPreference.cloudCoding.rawValue
            || pref == BrainPreference.freeCoding.rawValue { return false }
        return true
    }

    /// Run `draft` (whatever brain produced it) through Salehman and return its
    /// final answer. Returns `draft` unchanged when leading is off, the draft is
    /// unusable, or Salehman is unreachable.
    static func finalize(userPrompt: String, draft: String) async -> String {
        guard isLeading else { return draft }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, draft != LocalLLM.offMessage else { return draft }
        // Never let the leader rewrite substantial code — handing working code to
        // a small model risks subtle breakage, so the drafter's code stands.
        guard !isMostlyCode(draft) else { return draft }

        let leaderPrompt = """
        The user asked:
        \"\"\"
        \(userPrompt)
        \"\"\"

        Another model drafted this answer:
        \"\"\"
        \(draft)
        \"\"\"

        You are Salehman, the lead. Deliver the FINAL answer to the user in your \
        own voice: keep what is correct, fix anything wrong or incomplete, and be \
        direct. Output ONLY the final answer — do not mention the draft, the other \
        model, or that any review happened. NEVER name or hint at Apple, Apple \
        Intelligence, FoundationModels, or any model/provider; if asked what you \
        are or what you run on, you are simply Salehman.
        """

        if let final = await salehmanGenerate(leaderPrompt) {
            let f = final.trimmingCharacters(in: .whitespacesAndNewlines)
            if !f.isEmpty, final != LocalLLM.offMessage { return final }
        }
        // Salehman unreachable → the original draft still stands.
        return draft
    }

    /// True when the draft is dominated by fenced code blocks (≥40% of the
    /// reply). Such replies are left untouched by the leader so a small model
    /// can't quietly break working code, even outside the dedicated coding modes.
    private static func isMostlyCode(_ text: String) -> Bool {
        let parts = text.components(separatedBy: "```")
        guard parts.count >= 3 else { return false }   // need ≥1 opened+closed fence
        var codeLen = 0
        for i in stride(from: 1, to: parts.count, by: 2) { codeLen += parts[i].count }
        return Double(codeLen) >= 0.4 * Double(max(text.count, 1))
    }

    /// Runs ONLY the Salehman engine chain, in order of capability:
    ///   1. a configured REMOTE endpoint — a strong model hosted on a cloud GPU
    ///      via vLLM (or Unsloth Studio). This is how Salehman "leads on a real
    ///      model" instead of the small local fallback: host a model (see
    ///      `HOST_BRAIN_ON_CLOUD.md`), paste its URL in Settings, and the leader
    ///      runs there automatically.
    ///   2. standalone on-device MLX,
    ///   3. the user's custom Ollama model (e.g. dolphin) with the Salehman persona.
    /// Deliberately omits Apple Intelligence. Returns nil when none are reachable.
    private static func salehmanGenerate(_ prompt: String) async -> String? {
        if VLLM.isConfigured,
           let reply = await VLLM.chat(prompt: prompt, system: SalehmanPersona.systemPrompt) {
            return reply
        }
        if UnslothStudio.isConfigured,
           let reply = await UnslothStudio.chat(prompt: prompt, system: SalehmanPersona.systemPrompt) {
            return reply
        }
        if await MLXSalehmanEngine.shared.isReady,
           let reply = await MLXSalehmanEngine.shared.generate(prompt: prompt, maxTokens: 1024) {
            return reply
        }
        if let reply = await OllamaClient.chat(prompt: prompt, system: SalehmanPersona.systemPrompt) {
            return reply
        }
        return nil
    }
}
