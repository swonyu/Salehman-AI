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
/// - **Self-disabling:** a no-op when the Leader setting is off (zero extra
///   passes for ALL brains, including pinned `.salehman`), or when the draft is
///   an error/off message. Pinned `.salehman` with Leader ON: the Effort dial
///   still applies via `refineOwnDraft` — no regeneration, just self-critique.
/// - **Graceful:** if the Salehman engine isn't reachable it returns the draft
///   UNCHANGED — it never blanks out a reply just because Salehman is offline.
/// - **On-device-only pass:** the engine falls through MLX (if loaded) then
///   Ollama (Salehman custom model). The leader only runs when one of these is
///   available; if neither is ready it returns the draft unchanged.
/// - **No Apple Intelligence:** Salehman is its own thing; it never borrows
///   Apple's on-device model and must never present itself as such.
enum SalehmanLeader {

    /// Whether the final Salehman pass should run for the current turn.
    static var isLeading: Bool {
        guard AppSettings.salehmanLeaderEnabled else { return false }
        let pref = AppSettings.brainPreferenceCurrent
        // Don't double-pass when the user already pinned Salehman as the brain.
        if pref == .salehman { return false }
        // (The dedicated cloud/free coding modes the leader used to step aside
        // for were removed in the 2026-06-18 local-only migration.)
        return true
    }

    /// Run `draft` (whatever brain produced it) through Salehman and return its
    /// final answer. Returns `draft` unchanged when the Leader is off (no extra
    /// passes for any brain), the draft is unusable, or Salehman is unreachable.
    ///
    /// **Effort dial** (`AppSettings.salehmanEffortCurrent`) is honored here — the
    /// one chokepoint every reply funnels through (post-tools, post-streaming, so
    /// extra passes can never re-run a tool's side effects):
    /// * other brains' drafts → the leader pass runs at the configured effort
    ///   (candidate fan-out + self-critique + judge). `.instant` = exactly one
    ///   leader call, the pre-Effort behavior.
    /// * pinned `.salehman` → the draft IS Salehman's own answer (possibly built
    ///   with tools); it gets critique-only refinement via `refineOwnDraft` —
    ///   never regenerated, so tool-derived facts survive.
    /// * coding modes → untouched (same step-aside rule as the leader pass).
    static func finalize(userPrompt: String, draft: String) async -> String {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, draft != LocalLLM.offMessage else { return draft }
        // Skip error sentinels (bracketed "[Provider error …]" / "request failed …").
        // offMessage is caught above; this catches all other error shapes so the
        // leader doesn't waste a generate call trying to polish a diagnostic message.
        guard !AgentPipeline.isErrorReply(draft) else { return draft }
        // Never let extra passes rewrite substantial code — handing working code
        // to another pass risks subtle breakage, so the drafter's code stands.
        guard !isMostlyCode(draft) else { return draft }

        // Pinned `.salehman`: no leader re-pass (it would double-pass the same
        // engine) — honor the Effort dial by self-critiquing the existing draft.
        // Uses brainPreferenceCurrent (validate-or-default) so a fresh install with
        // an unset key is correctly identified as pinned .salehman, not routed to
        // the full leader fan-out. Gated on the Leader toggle: OFF means zero extra
        // passes for all brains, consistent with isLeading's guarantee.
        if AppSettings.brainPreferenceCurrent == .salehman {
            guard AppSettings.salehmanLeaderEnabled else { return draft }
            return await refineOwnDraft(userPrompt: userPrompt, draft: draft)
        }

        guard isLeading else { return draft }

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
        model, or that any review happened. NEVER name or hint at DeepSeek, NVIDIA, \
        Groq, or any model/provider; if asked what you are or what you run on, you \
        are simply Salehman.
        """

        // Leader pass at the configured effort. The generator routes through the
        // shared cloud-first engine. At `.instant` this is a single generate call.
        let effort = AppSettings.salehmanEffortCurrent
        let result = await effort.respond(to: leaderPrompt) { prompt in
            await SalehmanEngine.generate(prompt: prompt, userPrompt: userPrompt) ?? ""
        }
        let final = result.answer
        let f = final.trimmingCharacters(in: .whitespacesAndNewlines)
        if !f.isEmpty, final != LocalLLM.offMessage {
            return final
        }
        // Salehman unreachable → the original draft still stands.
        return draft
    }

    /// Effort for the pinned-`.salehman` brain: critique-only refinement of the
    /// draft Salehman already produced. Candidates are deliberately NOT
    /// regenerated — the draft may embed tool results (terminal/web output) that
    /// a fresh generation would lose. `.instant` (0 rounds) returns the draft
    /// untouched with zero extra calls. Uses `refineRounds` (not `critiqueRounds`)
    /// so the dial stays monotonic: `.ultra` caps at `.high`'s depth because fan-out
    /// is unavailable for an existing draft.
    private static func refineOwnDraft(userPrompt: String, draft: String) async -> String {
        let effort = AppSettings.salehmanEffortCurrent
        guard effort.refineRounds > 0 else { return draft }
        let outcome = await SelfCritique.refine(
            question: userPrompt, draft: draft,
            maxRounds: effort.refineRounds
        ) { prompt in
            await SalehmanEngine.generate(prompt: prompt, userPrompt: userPrompt) ?? ""
        }
        let refined = outcome.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !refined.isEmpty, outcome.answer != LocalLLM.offMessage else { return draft }
        return outcome.answer
    }

    /// True when the draft is dominated by fenced code blocks (≥40% of the
    /// reply). Such replies are left untouched by the leader so a small model
    /// can't quietly break working code, even outside the dedicated coding modes.
    /// `internal` (not `private`) so `SalehmanLeaderTests` can pin the threshold.
    static func isMostlyCode(_ text: String) -> Bool {
        let parts = text.components(separatedBy: "```")
        guard parts.count >= 3 else { return false }   // need ≥1 opened+closed fence
        var codeLen = 0
        for i in stride(from: 1, to: parts.count, by: 2) { codeLen += parts[i].count }
        return Double(codeLen) >= 0.4 * Double(max(text.count, 1))
    }
}
