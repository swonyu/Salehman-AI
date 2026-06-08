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
    // gpt-oss-120b:free is the default — the strongest *reliably-available* free
    // model. The genuinely frontier free brains below (Kimi K2.6 ~1T, Nemotron-
    // Ultra-550B) are smarter but heavily rate-limited, so they're opt-in in the
    // picker rather than the everyday default.
    nonisolated static let defaultModel = "openai/gpt-oss-120b:free"
    nonisolated static let allModels    = [
        // Refreshed 2026-06-08 against the live `:free` catalog (GET /v1/models).
        // DeepSeek's own `:free` variants are GONE (all DeepSeek models are paid
        // now) — but these free models rival/exceed DeepSeek's 671B. Ordered
        // lightest→heaviest; the heavy ones 429 often, so the app falls through.
        "openai/gpt-oss-20b:free",
        "qwen/qwen3-next-80b-a3b-instruct:free",
        "openai/gpt-oss-120b:free",
        "nvidia/nemotron-3-super-120b-a12b:free",
        "nousresearch/hermes-3-llama-3.1-405b:free",       // 405B, free
        "nvidia/nemotron-3-ultra-550b-a55b:free",          // 550B, free
        "moonshotai/kimi-k2.6:free",                       // ~1T MoE — best free, rivals DeepSeek 671B
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

/// DeepSeek — pay-as-you-go but extremely cheap, and one of the strongest open
/// models at coding and reasoning. OpenAI-compatible (`/v1/chat/completions`),
/// so like the others it's just a config of `OpenAICompatibleClient` — which
/// means it gets terminal tool-calling automatically. `deepseek-chat` (V3) is
/// the general/coding default; `deepseek-reasoner` (R1) trades latency for
/// deeper step-by-step reasoning on hard problems.
enum DeepSeekClient {
    nonisolated static let defaultModel = "deepseek-chat"
    nonisolated static let allModels    = [
        "deepseek-chat",       // V3 — fast, excellent general + coding
        "deepseek-reasoner",   // R1 — deeper reasoning, slower
    ]

    nonisolated static let shared = OpenAICompatibleClient(
        displayName:     "DeepSeek",
        baseURL:         "https://api.deepseek.com/v1",
        defaultModel:    defaultModel,
        allModels:       allModels,
        keychainAccount: .deepSeekAPIKey,
        consoleURL:      "https://platform.deepseek.com/api_keys"
    )
}

/// NVIDIA NIM (`integrate.api.nvidia.com`) — NVIDIA's OpenAI-compatible inference
/// endpoint, with a **free tier** (free credits from build.nvidia.com). This is
/// the app's route to **REAL DeepSeek for free**: DeepSeek's own API and
/// OpenRouter both charge for every DeepSeek model, but NVIDIA hosts the actual
/// `deepseek-ai/deepseek-v4-*` weights at $0 on the free tier. Verified live
/// against `GET /v1/models` (2026-06-08): `deepseek-v4-flash`, `deepseek-v4-pro`,
/// `deepseek-coder-6.7b-instruct`. Like every other provider here it's just a
/// config of `OpenAICompatibleClient`, so it gets terminal tool-calling for free.
/// (Note: DeepSeek V3/R1 are last-gen and no longer offered free anywhere; V4
/// supersedes both — for an *unlimited* R1, run a local `deepseek-r1` distill.)
enum NvidiaClient {
    nonisolated static let defaultModel = "deepseek-ai/deepseek-v4-flash"
    nonisolated static let allModels    = [
        "deepseek-ai/deepseek-v4-flash",          // fast, free — the everyday DeepSeek
        "deepseek-ai/deepseek-v4-pro",            // deeper, free tier
        "deepseek-ai/deepseek-coder-6.7b-instruct",
    ]

    nonisolated static let shared = OpenAICompatibleClient(
        displayName:     "NVIDIA",
        baseURL:         "https://integrate.api.nvidia.com/v1",
        defaultModel:    defaultModel,
        allModels:       allModels,
        keychainAccount: .nvidiaAPIKey,
        consoleURL:      "https://build.nvidia.com"
    )
}
