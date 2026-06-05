import Foundation

/// The "Codex" brain → OpenAI Chat Completions (cloud).
///
/// OpenAI *is* the canonical OpenAI-compatible endpoint, so this is just a
/// config over the shared `OpenAICompatibleClient` — same pattern as the
/// Groq/Mistral/Cerebras brains. The API key lives in the macOS Keychain
/// (`.openAIAPIKey`); the model is user-pickable in Settings. ~zero local RAM.
enum OpenAIClient {
    nonisolated static let defaultModel = "gpt-4o-mini"
    nonisolated static let allModels: [String] = [defaultModel, "gpt-4o", "gpt-4.1-mini", "o4-mini"]

    nonisolated static let shared = OpenAICompatibleClient(
        displayName: "OpenAI",
        baseURL: "https://api.openai.com/v1",
        defaultModel: defaultModel,
        allModels: allModels,
        keychainAccount: .openAIAPIKey,
        consoleURL: "https://platform.openai.com/api-keys",
        promptCacheKey: "salehman-ai")   // OpenAI-only: improves auto-cache hit routing

    /// True iff the user has stored an OpenAI key. Sync (Keychain only, no HTTP).
    nonisolated static func hasKey() -> Bool { KeychainStore.has(.openAIAPIKey) }

    static func chat(prompt: String, system: String? = nil, model: String? = nil) async -> String? {
        await shared.chat(prompt: prompt, system: system, model: model)
    }

    static func chatStream(prompt: String, system: String? = nil, model: String? = nil,
                           onUpdate: @escaping (String) -> Void) async -> String? {
        await shared.chatStream(prompt: prompt, system: system, model: model, onUpdate: onUpdate)
    }
}
