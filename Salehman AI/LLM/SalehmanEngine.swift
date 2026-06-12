import Foundation

/// **The one Salehman brain engine — ON-DEVICE ONLY.**
///
/// Shared by both the `.salehman` brain (primary generation in `LocalLLM`) and
/// the `SalehmanLeader` final pass.
///
/// Resolution order (first that answers wins):
///   1. **On-device MLX**, if loaded;
///   2. **Ollama** (`salehman` custom model) — always available.
///
/// No external servers are contacted. Everything stays on this Mac.
enum SalehmanEngine {

    // MARK: - Reachability

    /// Always false — no external endpoints are configured for this engine.
    /// Kept so call sites (LocalLLM label, BrainRouting, AgentPipeline) compile
    /// unchanged; they fall through to the mlxReady / ollamaHasCustomModel probes.
    nonisolated static var hasAnyCloud: Bool { false }

    // MARK: - Non-streaming

    static func generate(prompt: String,
                         userPrompt: String? = nil,
                         maxTokens: Int? = nil) async -> String? {
        if await MLXSalehmanEngine.shared.isReady,
           let r = await MLXSalehmanEngine.shared.generate(prompt: prompt,
                                                           maxTokens: maxTokens ?? 1024) { return r }
        if let r = await OllamaClient.chat(prompt: prompt,
                                           system: SalehmanPersona.activeSystemPrompt) { return r }
        return nil
    }

    // MARK: - Streaming

    static func generateStream(prompt: String,
                               userPrompt: String? = nil,
                               maxTokens: Int? = nil,
                               onUpdate: @escaping @Sendable (String) -> Void) async -> String? {
        if await MLXSalehmanEngine.shared.isReady,
           let r = await MLXSalehmanEngine.shared.generateStream(prompt: prompt,
                                                                 maxTokens: maxTokens ?? 1024,
                                                                 onUpdate: onUpdate) { return r }
        if let r = await OllamaClient.chatStream(prompt: prompt,
                                                 system: SalehmanPersona.activeSystemPrompt,
                                                 onUpdate: onUpdate) { return r }
        return nil
    }

    // MARK: - Tool-calling (agentic chat path)

    static func generateWithTools(message: String, userPrompt: String? = nil) async -> String? {
        if await MLXSalehmanEngine.shared.isReady,
           let r = await MLXSalehmanEngine.shared.generate(prompt: message) { return r }
        if let r = await LocalLLM.ollamaReply(message,
                                              systemPrompt: SalehmanPersona.activeSystemPrompt) { return r }
        return nil
    }
}
