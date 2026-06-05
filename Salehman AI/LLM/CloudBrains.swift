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

/// Groq — generous free tier, blazing-fast Llama / Qwen / gpt-oss. Free
/// tier has rate limits but is enough for personal use. Endpoint matches
/// OpenAI's path exactly.
///
/// ⚠️ Groq's roster rotates: `llama-3.1-70b-versatile`, `mixtral-8x7b-32768`,
/// and `gemma2-9b-it` were all decommissioned (400 / "model not found") — same
/// lesson as OpenRouter below. Authoritative truth is `GET /v1/models`; this
/// list is best-effort, kept in lightest-to-heaviest order for the picker copy.
enum GroqClient {
    nonisolated static let defaultModel = "llama-3.3-70b-versatile"
    nonisolated static let allModels    = [
        "llama-3.1-8b-instant",
        "qwen/qwen3-32b",
        "llama-3.3-70b-versatile",
        "openai/gpt-oss-120b",
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

/// Cerebras Inference — purpose-built silicon, free tier on a small but
/// rotating set of models at multi-thousand tokens/sec. Same OpenAI shape,
/// faster wire.
///
/// ⚠️ Cerebras retired the Llama 3.1 family from public inference; the old
/// `llama3.1-8b` / `llama-3.3-70b` defaults began returning 404 "model not
/// found." Current inventory is just `gpt-oss-120b` and `zai-glm-4.7` —
/// verified via `GET /v1/models`. Re-check periodically.
enum CerebrasClient {
    nonisolated static let defaultModel = "gpt-oss-120b"
    nonisolated static let allModels    = [
        "gpt-oss-120b",
        "zai-glm-4.7",
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

/// OpenRouter — an aggregator that exposes many providers behind ONE
/// OpenAI-compatible endpoint, including a rotating set of **`:free`** models
/// (no credit card on a free account). The `:free` suffix is what makes a model
/// zero-cost.
///
/// ⚠️ OpenRouter's free roster ROTATES — a `:free` ID that works today may be
/// retired or rate-limited later. These defaults are best-effort; if one 404s,
/// the app's error-surfacing shows `[OpenRouter error …]` and the user can pick
/// another from the Settings picker (same lesson as the Grok phantom-model
/// episode — verify via Test connection, don't trust a hardcoded ID forever).
enum OpenRouterClient {
    nonisolated static let defaultModel = "meta-llama/llama-3.3-70b-instruct:free"
    nonisolated static let allModels    = [
        // Refreshed 2026-06-05 against the live `:free` catalog. The previous
        // list still had `deepseek/deepseek-chat:free`, `google/gemma-2-9b-it:free`,
        // and `mistralai/mistral-7b-instruct:free` — all of which 404 now
        // ("No endpoints found"). Keeping the 3.3-70b default because it's the
        // most-asked free model even when it 429s; users can switch in the picker.
        "meta-llama/llama-3.2-3b-instruct:free",
        "openai/gpt-oss-20b:free",
        "qwen/qwen3-coder:free",
        "meta-llama/llama-3.3-70b-instruct:free",
        "openai/gpt-oss-120b:free",
    ]

    nonisolated static let shared = OpenAICompatibleClient(
        displayName:     "OpenRouter",
        baseURL:         "https://openrouter.ai/api/v1",
        defaultModel:    defaultModel,
        allModels:       allModels,
        keychainAccount: .openRouterAPIKey,
        consoleURL:      "https://openrouter.ai/keys"
    )
}
