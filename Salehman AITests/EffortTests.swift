import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Effort — orchestration of self-critique + candidate fan-out/judge
//
// Effort.respond is driven by an INJECTED generator, so these tests pin its
// control flow (how many drafts, how many critique rounds, how the judge picks)
// without any live model. A scripted generator records every prompt it sees and
// returns deterministic text, letting us assert on call counts and selection.

struct EffortTests {

    /// A scripted, thread-safe generator: returns `reply(for:)` and counts calls.
    nonisolated final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var prompts: [String] = []
        let reply: @Sendable (String, Int) -> String
        init(reply: @escaping @Sendable (String, Int) -> String) { self.reply = reply }
        func generate(_ p: String) -> String {
            lock.lock(); defer { lock.unlock() }
            let idx = prompts.count
            prompts.append(p)
            return reply(p, idx)
        }
        var count: Int { lock.lock(); defer { lock.unlock() }; return prompts.count }
    }

    // MARK: parameter tables

    @Test func instantHasNoCritiqueAndOneCandidate() {
        #expect(Effort.instant.critiqueRounds == 0)
        #expect(Effort.instant.candidates == 1)
    }

    @Test func ultraFansOutToMultipleCandidates() {
        #expect(Effort.ultra.candidates > 1)
        #expect(Effort.high.critiqueRounds >= Effort.balanced.critiqueRounds)
    }

    @Test func approxModelCallsMonotonicWithEffort() {
        // More effort never costs fewer calls than less effort.
        #expect(Effort.instant.approxModelCalls <= Effort.balanced.approxModelCalls)
        #expect(Effort.balanced.approxModelCalls <= Effort.high.approxModelCalls)
        #expect(Effort.high.approxModelCalls <= Effort.ultra.approxModelCalls)
    }

    // MARK: control flow

    @Test func instantReturnsDraftWithoutCritiquing() async {
        let rec = Recorder { _, _ in "the draft answer" }
        let result = await Effort.instant.respond(to: "q") { rec.generate($0) }
        #expect(result.answer == "the draft answer")
        // instant = exactly one model call (the draft), no critique/rewrite.
        #expect(rec.count == 1)
    }

    @Test func balancedRunsOneCritiqueRoundThatCanRewrite() async {
        // Key off call ORDER, not prompt text (the rewrite prompt itself contains
        // the word "issue"). balanced = 1 candidate, 1 round: draft→critique→rewrite.
        let rec = Recorder { _, idx in
            switch idx {
            case 0:  return "first draft"                 // draft
            case 1:  return "Needs work: be more specific"// critique (non-empty = NOT approved)
            default: return "rewritten better answer"     // rewrite
            }
        }
        let result = await Effort.balanced.respond(to: "q") { rec.generate($0) }
        #expect(rec.count == 3)
        #expect(result.answer == "rewritten better answer")
    }

    @Test func critiqueApprovalStopsEarly() async {
        // An EMPTY critique counts as approved (SelfCritique.isApproved), so no
        // rewrite and no further rounds happen even at .high.
        let rec = Recorder { _, idx in
            idx == 0 ? "already great" : ""    // draft, then an approving (empty) critique
        }
        let result = await Effort.high.respond(to: "q") { rec.generate($0) }
        #expect(result.answer == "already great")
        #expect(rec.count == 2)               // draft + one approving critique
    }

    @Test func ultraFansOutThreeDraftsAndJudgePicksSecond() async {
        // 3 candidates; each draft approved immediately (empty critique); judge → #2.
        // Drafts are produced by generate(question), so their prompt == "q".
        let rec = Recorder { prompt, idx in
            if prompt == "q" { return "candidate-\(idx)" }            // distinct drafts
            if prompt.contains("best answer") { return "pick 2" }     // judge verdict
            return ""                                                 // approve each draft
        }
        let result = await Effort.ultra.respond(to: "q") { rec.generate($0) }
        #expect(result.candidatesTried == 3)
        // drafts land at idx 0,2,4 → "candidate-0/2/4"; judge picks the 2nd → "candidate-2".
        #expect(result.answer == "candidate-2")
    }

    // MARK: judge + reasoning-model think blocks

    @Test func judgeIgnoresThinkBlockBeforeVerdictNumber() async {
        // A reasoning model (QwQ / DeepSeek-R1) might emit:
        //   <think>Answer 1 has 3 issues, but answer 2 is clearly better.</think>2
        // Without stripping: firstInt finds '1' from inside <think> → wrong candidate.
        // With stripping (EOT fix): think block removed → firstInt("2") = 2 → correct.
        let rec = Recorder { prompt, idx in
            if prompt.contains("best answer") {
                return "<think>Answer 1 has 3 issues, but answer 2 is clearly better.</think>2"
            }
            if prompt == "q" { return "candidate-\(idx)" }
            return ""   // empty critique = immediate approval per candidate
        }
        let result = await Effort.ultra.respond(to: "q") { rec.generate($0) }
        // Candidates at indices 0,2,4 → "candidate-0/2/4"; judge picks #2 → "candidate-2".
        #expect(result.answer == "candidate-2")
    }

    @Test func firstIntParsesLooseVerdicts() {
        #expect(Effort.firstInt(in: "2") == 2)
        #expect(Effort.firstInt(in: "The best is #3.") == 3)
        #expect(Effort.firstInt(in: "none") == nil)
    }
}
