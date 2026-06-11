import Testing
import Foundation
@testable import Salehman_AI

/// Pins `AgentFilter.matching` — the agent-grid filter behind the Agents tab's
/// search field. Matches on name OR role, case-insensitively.
struct AgentFilterTests {

    private let team = [
        AgentSpec(name: "Code Quality Guardian", icon: "x", role: "Check the proposed answer for mistakes"),
        AgentSpec(name: "Reasoning Strategist",  icon: "x", role: "Do the actual work: reason through it"),
        AgentSpec(name: "Testing & Reliability", icon: "x", role: "Stress-test the draft for edge cases"),
    ]

    @Test func emptyOrBlankQueryReturnsAll() {
        #expect(AgentFilter.matching(team, query: "").count == team.count)
        #expect(AgentFilter.matching(team, query: "   ").count == team.count)
    }

    @Test func matchesNameCaseInsensitively() {
        #expect(AgentFilter.matching(team, query: "guardian").map(\.name) == ["Code Quality Guardian"])
        #expect(AgentFilter.matching(team, query: "TESTING").map(\.name) == ["Testing & Reliability"])
    }

    @Test func matchesRoleText() {
        #expect(AgentFilter.matching(team, query: "stress").map(\.name) == ["Testing & Reliability"])
        #expect(AgentFilter.matching(team, query: "reason").map(\.name) == ["Reasoning Strategist"])
    }

    @Test func noMatchIsEmpty() {
        #expect(AgentFilter.matching(team, query: "zzz").isEmpty)
    }

    @Test func realShippedPipelineIsNonEmptyAndPassesThroughOnEmptyQuery() {
        let all = AgentDefinitions.pipeline
        #expect(!all.isEmpty)
        #expect(AgentFilter.matching(all, query: "").count == all.count)
    }
}
