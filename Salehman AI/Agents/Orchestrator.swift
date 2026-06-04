import Foundation

/// Main orchestrator for Salehman AI.
///
/// Runs a real two-agent pipeline on the on-device model:
///   1. Reasoning Strategist — understands the request, reasons, and (when
///      needed) controls the Mac via the run_terminal_command tool. Keeps
///      conversation memory across turns.
///   2. Result Synthesis Lead — turns that working draft into a clear, friendly
///      final answer without losing any facts or results.
enum Orchestrator {

    static func run(mission: String) async {
        let result = await runAndReturnResult(mission: mission)
        print(result.output)
    }

    static func runAndReturnResult(mission: String) async -> (output: String, successRating: Double) {
        let answer = await AgentPipeline.run(mission: mission)
        let rating = AgentPipeline.lastOutcome?.successRating ?? (LocalLLM.isAvailable ? 1.0 : 0.0)
        return (output: answer, successRating: rating)
    }

    /// Clears the conversation memory (call when starting a new chat).
    static func reset() async {
        await LocalLLM.resetChat()
        await ConversationStore.shared.reset()
        await MainActor.run { MissionProgress.shared.clear() }
    }
}
