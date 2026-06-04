import Foundation

// MARK: - Cloud brain instances
//
// Each of the three providers below speaks the OpenAI `/v1/chat/completions`
// wire format, so they're all thin configurations of `OpenAICompatibleClient`.
// Adding the next OpenAI-compatible provider (Together, Fireworks, DeepInfra,
// Anyscale, etc.) is just another `static let shared = OpenAICompatibleClient(…)`
// here — no new client class, no new parsing code, no new Settings boilerplate.
//
// Adding the *Settings UI row* for a new provider is also nearly free: see
// `SettingsView.cloudBrainSection(...)` which takes any
// `OpenAICompatibleClient` and renders the same SecureField/Save/Clear/Test/
// Picker row stack.

/// Groq — generous free tier, blazing-fast Llama / Mixtral / Gemma. Free
/// tier has rate limits but is enough for personal use. Endpoint matches
/// OpenAI's path exactly.
enum GroqClient {
    nonisolated static let defaultModel = "llama-3.1-70b-versatile"
    nonisolated static let allModels    = [
        "llama-3.1-70b-versatile",
        "llama-3.1-8b-instant",
        "mixtral-8x7b-32768",
        "gemma2-9b-it",
    ]

    nonisolated static let shared = OpenAICompatibleClient(
        displayName:     "Groq",
        baseURL:         "https://api.groq.com/openai/v1",
        defaultModel:    defaultModel,
        allModels:       allModels,
        keychainAccount: .groqAPIKey,
        consoleURL:      "https://console.groq.com/keys"
    )
}

/// Mistral La Plateforme — French/EU-hosted, free tier on `mistral-small`
/// and `mistral-large`. Useful when EU data residency matters.
enum MistralClient {
    nonisolated static let defaultModel = "mistral-small-latest"
    nonisolated static let allModels    = [
        "mistral-small-latest",
        "mistral-large-latest",
        "codestral-latest",
    ]

    nonisolated static let shared = OpenAICompatibleClient(
        displayName:     "Mistral",
        baseURL:         "https://api.mistral.ai/v1",
        defaultModel:    defaultModel,
        allModels:       allModels,
        keychainAccount: .mistralAPIKey,
        consoleURL:      "https://console.mistral.ai/api-keys"
    )
}

/// Cerebras Inference — purpose-built silicon, free tier on Llama 3.1 8B/70B
/// at multi-thousand tokens/sec. Same OpenAI shape, faster wire.
enum CerebrasClient {
    nonisolated static let defaultModel = "llama3.1-8b"
    nonisolated static let allModels    = [
        "llama3.1-8b",
        "llama-3.3-70b",
    ]

    nonisolated static let shared = OpenAICompatibleClient(
        displayName:     "Cerebras",
        baseURL:         "https://api.cerebras.ai/v1",
        defaultModel:    defaultModel,
        allModels:       allModels,
        keychainAccount: .cerebrasAPIKey,
        consoleURL:      "https://cloud.cerebras.ai/platform/keys"
    )
}
