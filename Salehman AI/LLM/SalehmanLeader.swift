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
/// - **No Apple Intelligence:** the Salehman engine chain here is MLX → custom
///   Ollama model only. Salehman is its own thing; it does not borrow Apple's
///   on-device model and must never present itself as such.
enum SalehmanLeader {

    /// Whether the final Salehman pass should run for the current turn.
    static var isLeading: Bool {
        guard AppSettings.salehmanLeaderEnabled else { return false }
        // Don't double-pass when the user already pinned Salehman as the brain.
        let pref = UserDefaults.standard.string(forKey: AppSettings.Keys.brainPreference)
        return pref != BrainPreference.salehman.rawValue
    }

    /// Run `draft` (whatever brain produced it) through Salehman and return its
    /// final answer. Returns `draft` unchanged when leading is off, the draft is
    /// unusable, or Salehman is unreachable.
    static func finalize(userPrompt: String, draft: String) async -> String {
        guard isLeading else { return draft }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, draft != LocalLLM.offMessage else { return draft }

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
        model, or that any review happened.
        """

        if let final = await salehmanGenerate(leaderPrompt) {
            let f = final.trimmingCharacters(in: .whitespacesAndNewlines)
            if !f.isEmpty, final != LocalLLM.offMessage { return final }
        }
        // Salehman unreachable → the original draft still stands.
        return draft
    }

    /// Runs ONLY the Salehman engine chain: standalone on-device MLX → the user's
    /// custom Ollama model with the Salehman persona. Deliberately omits Apple
    /// Intelligence. Returns nil when no Salehman engine is reachable.
    private static func salehmanGenerate(_ prompt: String) async -> String? {
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
