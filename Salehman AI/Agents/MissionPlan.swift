import Foundation

/// Lightweight Mission Plan based on Phase 1 design.
struct MissionPlan {
    let mission: String
    let successCriteria: [String]
    let keyRisks: [String]

    init(mission: String,
         successCriteria: [String] = [],
         keyRisks: [String] = []) {
        self.mission = mission
        self.successCriteria = successCriteria
        self.keyRisks = keyRisks
    }
}
