import Testing
import Foundation
@testable import Salehman_AI

// MARK: - MissionMemory.buildContext
//
// `buildContext` assembles the prompt context passed to each agent before it
// generates: mission + success criteria + key risks (always), tool results
// (when non-empty), and prior agent outputs (everyone EXCEPT the requesting
// agent). Three invariants are security/quality-critical:
//   1. The requesting agent's OWN output is excluded (prevents circular reasoning).
//   2. Outputs are truncated at maxPerOutput to keep the agent's context window
//      from filling with another agent's verbosity.
//   3. The tool-results section is omitted entirely when there are none (no
//      empty section header confusing the agent).

struct MissionMemoryTests {

    private func makePlan(mission: String = "Deploy the update",
                          criteria: [String] = ["All tests pass", "No regressions"],
                          risks: [String] = ["DB migration may fail"]) -> MissionPlan {
        MissionPlan(mission: mission,
                    successCriteria: criteria,
                    keyRisks: risks)
    }

    @Test func contextAlwaysContainsMissionCriteriaAndRisks() {
        let plan = makePlan(mission: "Write a haiku",
                            criteria: ["17 syllables total"],
                            risks: ["Off-by-one on line 2"])
        let mem = MissionMemory(missionPlan: plan)
        let ctx = mem.buildContext(for: "Poet")
        #expect(ctx.contains("Write a haiku"))
        #expect(ctx.contains("17 syllables total"))
        #expect(ctx.contains("Off-by-one on line 2"))
    }

    @Test func toolResultsSectionAbsentWhenEmpty() {
        let mem = MissionMemory(missionPlan: makePlan())
        let ctx = mem.buildContext(for: "Analyst")
        #expect(!ctx.contains("Tool Results"),
                "no Tool Results section must appear when toolResults is empty")
    }

    @Test func toolResultsSectionPresentWhenNonEmpty() {
        var mem = MissionMemory(missionPlan: makePlan())
        mem.recordToolResult(tool: "web_search", summary: "Found 3 relevant pages.")
        let ctx = mem.buildContext(for: "Analyst")
        #expect(ctx.contains("Tool Results"))
        #expect(ctx.contains("[web_search]"))
        #expect(ctx.contains("Found 3 relevant pages."))
    }

    @Test func ownOutputIsExcludedFromContext() {
        // The "Code Quality Guardian" is asking for context.
        // Its own output must NOT appear — only the other agents' outputs do.
        var mem = MissionMemory(missionPlan: makePlan())
        mem.recordAgentOutput(name: "Code Quality Guardian", output: "MY OWN OUTPUT")
        mem.recordAgentOutput(name: "Reasoning Strategist",  output: "OTHER OUTPUT")
        let ctx = mem.buildContext(for: "Code Quality Guardian")
        #expect(!ctx.contains("MY OWN OUTPUT"),
                "requesting agent's own output must be excluded from its context")
        #expect(ctx.contains("OTHER OUTPUT"),
                "other agents' outputs must be included")
    }

    @Test func agentOutputsTruncatedAtMaxPerOutput() {
        // An output of 2000 chars should be cut to the first 800 (the default).
        let long = String(repeating: "X", count: 2_000)
        var mem = MissionMemory(missionPlan: makePlan())
        mem.recordAgentOutput(name: "Verbose Agent", output: long)
        let ctx = mem.buildContext(for: "Critic")
        // The 2000-char string must not appear verbatim in the context.
        #expect(!ctx.contains(long),
                "long output must be truncated; full 2000-char string must not appear")
        // But the first 800 chars must be present.
        #expect(ctx.contains(String(repeating: "X", count: 800)))
    }

    @Test func agentOutputsSectionAbsentWhenAllAreOwn() {
        // If the only recorded output belongs to the requesting agent,
        // there are no "others" → Previous Agent Outputs section must be omitted.
        var mem = MissionMemory(missionPlan: makePlan())
        mem.recordAgentOutput(name: "Solo", output: "I did it myself.")
        let ctx = mem.buildContext(for: "Solo")
        #expect(!ctx.contains("Previous Agent Outputs"),
                "section must be absent when all outputs belong to the requesting agent")
    }

    @Test func outcomeDoesNotAffectBuildContext() {
        // `recordOutcome` stores metadata for the Orchestrator; buildContext
        // doesn't include it — if that ever changes it's a design decision,
        // not a silent drift. This test locks the current contract.
        var mem = MissionMemory(missionPlan: makePlan())
        mem.recordOutcome(Outcome(successRating: 0.9))
        let ctx = mem.buildContext(for: "Agent")
        #expect(!ctx.contains("0.9"),
                "outcome rating must not appear in agent context (Orchestrator-only metadata)")
    }
}
