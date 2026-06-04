import Foundation

/// Lightweight Mission Plan based on Phase 1 design.
struct MissionPlan {
    let mission: String
    let successCriteria: [String]
    let keyRisks: [String]
    let recommendedAgents: [String]
    let thinkingMode: String

    init(mission: String,
         successCriteria: [String] = [],
         keyRisks: [String] = [],
         recommendedAgents: [String] = [],
         thinkingMode: String = "deep") {
        
        self.mission = mission
        self.successCriteria = successCriteria
        self.keyRisks = keyRisks
        self.recommendedAgents = recommendedAgents
        self.thinkingMode = thinkingMode
    }
}
