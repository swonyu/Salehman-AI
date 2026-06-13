import Foundation

/// Effort — one knob for *how hard Salehman thinks* before answering.
///
/// Mirrors the "reasoning effort + workflows" idea from agent harnesses: higher
/// effort spends more compute for a better answer, using the SAME brain. It does
/// that with two existing Core-Intelligence primitives:
///   * self-critique rounds  (`SelfCritique.refine`) — draft → critique → rewrite
///   * candidate fan-out + judge — generate N drafts, keep the best (the local
///     analogue of a multi-agent "workflow")
///
/// The generator is injected (a `Sendable` async closure) so this is:
///   * brain-agnostic (works with any `generate` — local MLX, Ollama, or cloud), and
///   * unit-testable without a live model (pass a scripted generator).
enum Effort: String, CaseIterable, Identifiable, Sendable {
    case instant      // single pass, no critique — fastest
    case balanced     // one self-critique round (the sensible default)
    case high         // multiple self-critique rounds
    case ultra        // several drafts, each critiqued, best one judged & kept

    nonisolated var id: String { rawValue }

    /// Self-critique (critique→rewrite) rounds applied to each candidate draft.
    nonisolated var critiqueRounds: Int {
        switch self {
        case .instant:  return 0
        case .balanced: return 1
        case .high:     return 3
        case .ultra:    return 2
        }
    }

    /// Critique rounds for the refine-only path (pinned-.salehman draft, no fan-out).
    /// Capped at `.high` so the dial stays monotonic — `.ultra`'s fan-out/judge pass
    /// isn't available when we're refining an existing tool-built draft.
    nonisolated var refineRounds: Int {
        switch self {
        case .instant:  return 0
        case .balanced: return 1
        case .high:     return 3
        case .ultra:    return 3
        }
    }

    /// Call count for the refine-only path: critique + conditional rewrite per round.
    nonisolated var approxRefineCalls: Int { refineRounds * 2 }

    /// Independent candidate drafts to generate. Only `.ultra` fans out; the
    /// best is chosen by a judge pass.
    nonisolated var candidates: Int {
        switch self {
        case .instant, .balanced, .high: return 1
        case .ultra:                     return 3
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .instant:  return "Instant"
        case .balanced: return "Balanced"
        case .high:     return "High"
        case .ultra:    return "Ultra"
        }
    }

    /// Short one-liner for the Settings picker.
    nonisolated var subtitle: String {
        switch self {
        case .instant:  return "One pass — fastest"
        case .balanced: return "One self-critique round"
        case .high:     return "Several self-critique rounds"
        case .ultra:    return "Multiple drafts, judged — best kept"
        }
    }

    /// Rough relative cost (model calls) — handy for UI hints / telemetry.
    nonisolated var approxModelCalls: Int {
        // per candidate: 1 draft + 2 calls (critique+rewrite) per round; +1 judge if fan-out
        let perCandidate = 1 + critiqueRounds * 2
        return candidates * perCandidate + (candidates > 1 ? 1 : 0)
    }
}

extension Effort {
    /// The outcome of an effort run.
    struct Result: Sendable {
        let answer: String
        let candidatesTried: Int
        let critiqueRounds: Int

        nonisolated init(answer: String, candidatesTried: Int, critiqueRounds: Int) {
            self.answer = answer
            self.candidatesTried = candidatesTried
            self.critiqueRounds = critiqueRounds
        }
    }

    /// Produce an answer to `question` at this effort level.
    /// - generate: async text generator (a model call), injected for testability.
    nonisolated func respond(
        to question: String,
        generate: @Sendable @escaping (String) async -> String
    ) async -> Result {
        let wanted = max(1, candidates)

        // 1. Generate candidate drafts and self-critique each.
        // When multiple candidates are requested (ultra), run them in parallel:
        // each candidate's draft + critique rounds are independent, so they
        // can race. On cloud brains this cuts wall-clock by ~wanted×; on a
        // local Ollama server the requests queue inside Ollama and behaviour
        // is equivalent to sequential. Output ordering is stabilized by
        // tagging each task with its index and sorting before the judge sees
        // the list — `candidates[n-1]` selection stays deterministic.
        let refined: [String]
        if wanted == 1 {
            let draft = await generate(question)
            let outcome = await SelfCritique.refine(
                question: question, draft: draft,
                maxRounds: critiqueRounds, generate: generate)
            let ans = outcome.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            refined = ans.isEmpty ? [] : [ans]
        } else {
            refined = await withTaskGroup(of: (Int, String?).self) { group in
                for i in 0..<wanted {
                    group.addTask {
                        let draft = await generate(question)
                        let outcome = await SelfCritique.refine(
                            question: question, draft: draft,
                            maxRounds: critiqueRounds, generate: generate)
                        let ans = outcome.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        return (i, ans.isEmpty ? nil : ans)
                    }
                }
                var pairs: [(Int, String)] = []
                for await (i, r) in group {
                    if let r { pairs.append((i, r)) }
                }
                return pairs.sorted { $0.0 < $1.0 }.map { $0.1 }
            }
        }

        guard !refined.isEmpty else {
            return Result(answer: "", candidatesTried: wanted, critiqueRounds: critiqueRounds)
        }

        // 2. One candidate → return it. Many → judge-pick the best.
        let best = refined.count == 1
            ? refined[0]
            : await Effort.judge(question: question, candidates: refined, generate: generate)

        return Result(answer: best, candidatesTried: refined.count, critiqueRounds: critiqueRounds)
    }

    /// Ask the model to pick the single best candidate. Falls back to the first
    /// candidate when the judge's choice can't be parsed (never returns empty).
    nonisolated static func judge(
        question: String,
        candidates: [String],
        generate: @Sendable (String) async -> String
    ) async -> String {
        guard candidates.count > 1 else { return candidates.first ?? "" }

        var prompt = """
        You are selecting the single best answer to a user's question. Judge for \
        correctness, helpfulness, and clarity.

        Question:
        \(question)


        """
        for (i, c) in candidates.enumerated() {
            prompt += "Answer #\(i + 1):\n\(c)\n\n"
        }
        prompt += "Reply with ONLY the number of the best answer (for example: 2)."

        // Strip reasoning-model think blocks before scanning for a digit:
        // a verdict like "<think>Answer 1 has 3 flaws</think>2" would otherwise
        // return 1 (wrong) because firstInt finds the first digit in the whole string.
        let verdict = AgentPipeline.stripNarration(await generate(prompt))
        if let n = firstInt(in: verdict), n >= 1, n <= candidates.count {
            return candidates[n - 1]
        }
        return candidates[0]
    }

    /// First base-10 integer found anywhere in `s`, or nil.
    nonisolated static func firstInt(in s: String) -> Int? {
        let afterNonDigits = s.drop(while: { !$0.isNumber })
        let digits = afterNonDigits.prefix(while: { $0.isNumber })
        return Int(digits)
    }
}

extension SalehmanEngine {
    /// Generate a reply at the given effort level using the real Salehman brain.
    /// Returns `nil` only when no brain is reachable (same contract as
    /// `generate`): with no brain, every injected call yields "" → the effort
    /// run produces an empty answer → we surface `nil` instead of a blank reply.
    static func respond(to question: String, effort: Effort) async -> String? {
        let result = await effort.respond(to: question) { prompt in
            await generate(prompt: prompt, userPrompt: question) ?? ""
        }
        return result.answer.isEmpty ? nil : result.answer
    }
}
