import Foundation

/// SelfCritique -- a self-correction pass for Salehman AI's Core Intelligence.
///
/// Given a question and a draft answer, it asks the model to critique its own
/// draft for substantive flaws, then rewrite to fix them, looping until the
/// critic reports no issues or `maxRounds` is reached. This is the first
/// primitive of the Core Intelligence layer: ruthless self-correction applied
/// to any generated answer.
///
/// `generate` is injected (a Sendable async closure) so this is:
///   * testable without a live model (pass a scripted generator), and
///   * pinnable by the caller to the on-device tier (LocalLLM.generateOnDevice)
///     or the full router (LocalLLM.generate).
///
/// All members are nonisolated so the loop can run off the main actor (e.g.
/// from AgentPipeline's task group). The project builds with
/// -default-isolation=MainActor, so without these annotations every static here
/// would be implicitly main-actor isolated.
enum SelfCritique {

    /// Outcome of a refine pass.
    struct Outcome: Sendable {
        let answer: String        // best answer after refinement
        let rounds: Int           // critique->rewrite cycles actually run
        let critiques: [String]   // each round's critique text (transparency/debug)
        let converged: Bool       // true iff the loop stopped because the critic approved

        nonisolated init(answer: String, rounds: Int, critiques: [String], converged: Bool) {
            self.answer = answer
            self.rounds = rounds
            self.critiques = critiques
            self.converged = converged
        }
    }

    /// Sentinel the critic emits when the draft needs no changes.
    nonisolated(unsafe) static let approvedToken = "NO_ISSUES"

    /// Run the self-critique loop.
    /// - Parameters:
    ///   - question: the original user question/task.
    ///   - draft: the first-pass answer to improve.
    ///   - maxRounds: hard cap on critique->rewrite cycles (clamped to >= 0).
    ///   - generate: async text generator (model call), injected for testability.
    nonisolated static func refine(
        question: String,
        draft: String,
        maxRounds: Int = 2,
        generate: @Sendable (String) async -> String
    ) async -> Outcome {
        var current = draft
        var critiques: [String] = []

        let rounds = max(0, maxRounds)
        if rounds == 0 || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Outcome(answer: current, rounds: 0, critiques: critiques, converged: false)
        }

        for round in 1...rounds {
            let critique = await generate(critiquePrompt(question: question, answer: current))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            critiques.append(critique)

            if isApproved(critique) {
                return Outcome(answer: current, rounds: round, critiques: critiques, converged: true)
            }

            let rewritten = await generate(rewritePrompt(question: question, answer: current, critique: critique))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !rewritten.isEmpty {
                current = rewritten
            }
        }

        return Outcome(answer: current, rounds: rounds, critiques: critiques, converged: false)
    }

    /// True when the critique signals the answer is good enough. Accepts the
    /// sentinel anywhere in the (case-insensitive) text -- small models tend to
    /// wrap it in prose ("I find NO_ISSUES here.") -- and treats an empty
    /// critique as "nothing to fix".
    nonisolated static func isApproved(_ critique: String) -> Bool {
        let trimmed = critique.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return trimmed.uppercased().contains(approvedToken)
    }

    nonisolated static func critiquePrompt(question: String, answer: String) -> String {
        """
        You are a ruthless critic. Find every substantive flaw in the ANSWER as a response to the QUESTION: factual errors, missing steps, weak reasoning, unsupported claims, ambiguity, or anything that makes it less useful. Be specific and terse; list only real problems.
        If the answer has no substantive problems, reply with exactly: \(approvedToken)

        QUESTION:
        \(question)

        ANSWER:
        \(answer)
        """
    }

    nonisolated static func rewritePrompt(question: String, answer: String, critique: String) -> String {
        """
        Rewrite the ANSWER so it fully addresses the QUESTION and fixes every issue in the CRITIQUE. Keep what was correct; repair what was flawed. Output ONLY the improved answer -- no preamble, no commentary, no mention of the critique.

        QUESTION:
        \(question)

        ANSWER:
        \(answer)

        CRITIQUE:
        \(critique)
        """
    }
}
