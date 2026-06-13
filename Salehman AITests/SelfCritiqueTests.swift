import Testing
import Foundation
@testable import Salehman_AI

@Suite struct SelfCritiqueTests {

    /// A scripted generator: returns canned outputs in order so the loop can be
    /// driven deterministically without a live model. An actor because it is
    /// captured by the @Sendable async closure SelfCritique.refine expects.
    actor Script {
        private var responses: [String]
        private(set) var prompts: [String] = []
        init(_ responses: [String]) { self.responses = responses }
        func next(_ prompt: String) -> String {
            prompts.append(prompt)
            return responses.isEmpty ? "" : responses.removeFirst()
        }
    }

    @Test func stopsImmediatelyWhenCriticApproves() async {
        let script = Script(["NO_ISSUES"])
        let out = await SelfCritique.refine(
            question: "What is 2+2?",
            draft: "4",
            maxRounds: 3,
            generate: { await script.next($0) }
        )
        #expect(out.answer == "4")
        #expect(out.rounds == 1)
        #expect(out.converged == true)
        #expect(out.critiques == ["NO_ISSUES"])
    }

    @Test func refinesThenConverges() async {
        // Round 1: critique finds a flaw -> rewrite. Round 2: critic approves.
        let script = Script(["The answer omits the carry.", "4 (with carry shown)", "NO_ISSUES"])
        let out = await SelfCritique.refine(
            question: "Add 2+2 and show work.",
            draft: "4",
            maxRounds: 3,
            generate: { await script.next($0) }
        )
        #expect(out.answer == "4 (with carry shown)")
        #expect(out.rounds == 2)
        #expect(out.converged == true)
    }

    @Test func stopsAtMaxRoundsWithoutConverging() async {
        // Critic never approves; loop must cap at maxRounds and return last rewrite.
        let script = Script(["flaw A", "draft v2", "flaw B", "draft v3", "flaw C", "draft v4"])
        let out = await SelfCritique.refine(
            question: "Q",
            draft: "draft v1",
            maxRounds: 2,
            generate: { await script.next($0) }
        )
        #expect(out.rounds == 2)
        #expect(out.converged == false)
        #expect(out.answer == "draft v3")   // two rewrites applied
        #expect(out.critiques.count == 2)
    }

    @Test func emptyDraftReturnsImmediately() async {
        let script = Script(["should not be called"])
        let out = await SelfCritique.refine(
            question: "Q",
            draft: "   ",
            maxRounds: 3,
            generate: { await script.next($0) }
        )
        #expect(out.rounds == 0)
        #expect(out.converged == false)
        let calls = await script.prompts.count
        #expect(calls == 0)
    }

    @Test func blankRewriteKeepsPriorAnswer() async {
        // Critic finds a flaw but the rewrite comes back empty -> keep the draft.
        let script = Script(["flaw", "   ", "NO_ISSUES"])
        let out = await SelfCritique.refine(
            question: "Q",
            draft: "good enough",
            maxRounds: 3,
            generate: { await script.next($0) }
        )
        #expect(out.answer == "good enough")
        #expect(out.converged == true)
    }

    @Test func approvalTokenDetectedInsideProse() {
        #expect(SelfCritique.isApproved("Honestly I find NO_ISSUES here.") == true)
        #expect(SelfCritique.isApproved("no_issues") == true)   // case-insensitive
        #expect(SelfCritique.isApproved("") == true)            // empty = nothing to fix
        #expect(SelfCritique.isApproved("This is wrong.") == false)
    }

    @Test func thinkBlockContainingTokenDoesNotFalseApprove() {
        // A reasoning model might debate the token inside <think>:
        //   <think>Should I say NO_ISSUES? No, there are real problems.</think>Issue 1: …
        // Without stripping: contains("NO_ISSUES") == true → wrong, draft approved early.
        // With stripping (EOU fix): think block removed → "Issue 1: …" → correctly NOT approved.
        let falseApproval = "<think>Should I say NO_ISSUES? No, there are real problems.</think>Issue 1: The draft lacks detail."
        #expect(SelfCritique.isApproved(falseApproval) == false)
    }

    @Test func thinkBlockFollowedByTokenCorrectlyApproves() {
        // A reasoning model that genuinely approves might emit:
        //   <think>Reviewing the draft… it looks good.</think>NO_ISSUES
        // After stripping: "NO_ISSUES" → correctly approved.
        let correctApproval = "<think>Reviewing the draft… it looks good to me.</think>NO_ISSUES"
        #expect(SelfCritique.isApproved(correctApproval) == true)
    }
}
