import Foundation

// MARK: - StockSageScreenAnalysis
//
// Reworked from the package's `ScreenAnalysisEngine` + `MultiTurnVisionConversation`.
// The package versions were **fabricated**: `analyzeCurrentScreen()` returned a
// hardcoded "Detected chart with upward trend in banking sector" without capturing
// anything, and the conversation returned canned market claims ("potential
// breakout pattern", "risk looks elevated") about images it never saw — actively
// misleading financial commentary.
//
// This version does it for real, reusing the app's existing infrastructure:
//   * screen capture via `AttachmentLoader.captureNow()` (the same path the chat's
//     "Send last screenshot" uses),
//   * on-device vision via `OllamaClient.vision(imageData:question:)` (qwen2.5vl).
// If the vision model isn't available it says so honestly — it never invents an
// analysis.
@MainActor
final class StockSageScreenAnalysis {
    static let shared = StockSageScreenAnalysis()
    private init() {}

    /// Rolling conversation context so follow-up questions stay grounded in the
    /// last real analysis. Capped so it can't grow without bound.
    private var history: [String] = []
    private let maxHistory = 12

    /// Capture the screen now and analyze it with the on-device vision model.
    /// `focus` lets the caller steer the question (e.g. "the chart in the top
    /// right"). Returns honest text on every failure path — never a fabrication.
    func analyzeCurrentScreen(focus: String? = nil) async -> String {
        guard let url = AttachmentLoader.captureNow() ?? AttachmentLoader.lastScreenshot(),
              let data = try? Data(contentsOf: url) else {
            return "Couldn't capture the screen (screen-recording permission may be off in System Settings → Privacy & Security → Screen Recording)."
        }
        let focusPrefix = focus.map { "Focus on \($0). " } ?? ""
        let question = focusPrefix
            + "Describe what's on this screen. If it contains a financial chart, "
            + "report only what is actually visible — trend direction, axis labels, "
            + "and any legible numbers. Do not speculate about future prices."

        guard let seen = await OllamaClient.vision(imageData: data, question: question) else {
            return "The on-device vision model (qwen2.5vl) isn't available. Start Ollama with qwen2.5vl pulled to analyze the screen."
        }
        remember("Screen: \(seen.prefix(400))")
        return seen
    }

    /// Ask a follow-up about the most recently analyzed screen. Routes through
    /// `LocalLLM` with the real prior-analysis context — no canned answers.
    func followUp(_ userMessage: String) async -> String {
        guard !history.isEmpty else {
            return "No screen has been analyzed yet — run a screen analysis first."
        }
        if await LocalLLM.currentBrain() == .none {
            return "No model is reachable to answer a follow-up. Turn on a brain in Settings → Brain."
        }
        let context = history.suffix(maxHistory).joined(separator: "\n")
        let prompt = """
        You are answering a follow-up about a screen the user already showed you.
        Use ONLY the prior on-device analysis below — do not invent chart details
        or market predictions.

        Prior analysis:
        \(context)

        Follow-up question: \(userMessage)
        """
        remember("User: \(userMessage)")
        // This class advertises "on-device" four times in its doc + status strings,
        // so the follow-up must stay local even when the user pinned a cloud brain.
        // `generateOnDevice` runs only the local Ollama brain; on nil we say
        // so honestly rather than silently route to a cloud brain.
        let rawReply = await LocalLLM.generateOnDevice(prompt, maxTokens: 400)
                ?? "The on-device model isn't available right now to write a follow-up. Start Ollama (an on-device model), then ask again."
        let reply = AgentPipeline.stripNarration(rawReply)
        remember("Assistant: \(reply.prefix(400))")
        return reply
    }

    func reset() { history.removeAll() }

    private func remember(_ line: String) {
        history.append(line)
        if history.count > maxHistory { history.removeFirst(history.count - maxHistory) }
    }
}
