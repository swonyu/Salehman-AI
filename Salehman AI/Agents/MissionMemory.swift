import Foundation

// MARK: - Outcome
struct Outcome {
    let successRating: Double

    init(successRating: Double = 0.0) {
        self.successRating = successRating
    }
}

// MARK: - MissionMemory
struct MissionMemory {
    let missionPlan: MissionPlan
    private(set) var agentOutputs: [(name: String, output: String)] = []
    private(set) var toolResults: [(tool: String, summary: String)] = []
    private(set) var outcome: Outcome?
    
    init(missionPlan: MissionPlan) {
        self.missionPlan = missionPlan
    }
    
    mutating func recordAgentOutput(name: String, output: String) {
        agentOutputs.append((name: name, output: output))
    }
    
    mutating func recordToolResult(tool: String, summary: String) {
        toolResults.append((tool: tool, summary: summary))
    }
    
    /// Record the final outcome of the mission
    mutating func recordOutcome(_ outcome: Outcome) {
        self.outcome = outcome
    }
    
    func buildContext(for agentName: String, maxPerOutput: Int = 800) -> String {
        var context = """
        === Mission ===
        \(missionPlan.mission)
        
        === Success Criteria ===
        \(missionPlan.successCriteria.joined(separator: "\n"))
        
        === Key Risks ===
        \(missionPlan.keyRisks.joined(separator: "\n"))
        """
        
        if !toolResults.isEmpty {
            context += "\n\n=== Tool Results ==="
            for r in toolResults {
                context += "\n[\(r.tool)]: \(r.summary)"
            }
        }
        
        let others = agentOutputs.filter { $0.name != agentName }
        if !others.isEmpty {
            context += "\n\n=== Previous Agent Outputs ==="
            for o in others {
                context += "\n\n[\(o.name)]:\n\(String(o.output.prefix(maxPerOutput)))"
            }
        }
        return context
    }
}
