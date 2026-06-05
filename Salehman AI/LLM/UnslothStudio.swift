import Foundation

/// The `.unslothStudio` brain — a thin wrapper that builds an unauthenticated
/// `OpenAICompatibleClient` from the user's endpoint URL + model name in
/// `AppSettings`. Designed for **Unsloth Studio** (its docs serve an OpenAI-
/// compatible API on `http://localhost:8000/v1`) but works for any local
/// OpenAI-compatible server: `mlx_lm.server` (`:8080/v1`), LM Studio,
/// llama.cpp's server, vLLM, Together's local mode, etc.
///
/// **Why a static namespace instead of a struct singleton:** the endpoint can
/// be edited in Settings at any moment. Reading it at call time (nonisolated)
/// means changes take effect immediately, with no observer wiring and no
/// actor hop from `LocalLLM`'s static brain gates.
///
/// **Privacy guard — `isLocalLoopback`:** since the user types an arbitrary
/// URL, they could accidentally point this at a public server. Only loopback
/// URLs (`localhost` / `127.0.0.1` / `::1`) keep the prompt on this Mac, so
/// `LocalLLM.generateOnDevice` uses Studio ONLY when `isLocalLoopback` is
/// true. A non-loopback endpoint is still pinnable as a regular brain — it
/// just doesn't qualify for the on-device-only privacy path the Knowledge
/// vault uses.
enum UnslothStudio {

    // MARK: - Configuration probes

    /// True iff the user has entered any endpoint URL at all (loopback or not).
    /// Used by `BrainStatus` and the chat-brain gate.
    static var isConfigured: Bool {
        !AppSettings.unslothStudioEndpointCurrent.isEmpty
    }

    /// True iff the configured endpoint's host is a **loopback** name —
    /// `localhost`, `127.0.0.1`, or `::1`. Only when this is true is the
    /// Studio brain treated as on-device for the privacy-preserving
    /// `generateOnDevice` path.
    static var isLocalLoopback: Bool {
        let raw = AppSettings.unslothStudioEndpointCurrent
        guard !raw.isEmpty, let host = URL(string: raw)?.host?.lowercased() else { return false }
        // `URL.host` strips the brackets around IPv6 literals, so `[::1]`
        // arrives here as `::1` — match both spellings just to be safe.
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    // MARK: - Client builder

    /// Build a fresh `OpenAICompatibleClient` from current settings. Returns
    /// `nil` when no endpoint is set — every callable surface gates on
    /// `isConfigured` first, so callers can `if let`-unwrap safely.
    static func client() -> OpenAICompatibleClient? {
        let endpoint = AppSettings.unslothStudioEndpointCurrent
        guard !endpoint.isEmpty else { return nil }
        let model = AppSettings.unslothStudioModelCurrent
        // If the user saved an API key in Settings → Unsloth Studio, wire the
        // client to send it as `Authorization: Bearer …`. Unsloth's hosted
        // endpoints (e.g. the `:8888` Anthropic-compat) and any auth-fronted
        // local server return HTTP 401 without it. With no saved key the
        // client stays unauthenticated, preserving the original "local server,
        // no key needed" path for `mlx_lm.server` / vanilla LM Studio / etc.
        let hasSavedKey = KeychainStore.read(.unslothStudioAPIKey) != nil
        return OpenAICompatibleClient(
            displayName: "Unsloth Studio",
            baseURL: endpoint,
            defaultModel: model,
            allModels: [model],
            keychainAccount: hasSavedKey ? .unslothStudioAPIKey : nil,
            consoleURL: "https://docs.unsloth.ai/",
            requiresKey: hasSavedKey
        )
    }

    // MARK: - Brain surface (mirrors the cloud-client APIs `LocalLLM` calls)

    /// Non-streaming chat. Mirrors `OllamaClient.chat(prompt:system:)` so
    /// `LocalLLM` can drop it in.
    static func chat(prompt: String, system: String? = nil) async -> String? {
        await client()?.chat(prompt: prompt, system: system)
    }

    /// Streaming chat. Same shape as the other `OpenAICompatibleClient`
    /// streaming entry points so `LocalLLM.generateStreaming` can use it.
    static func chatStream(prompt: String,
                           system: String? = nil,
                           onUpdate: @escaping (String) -> Void) async -> String? {
        await client()?.chatStream(prompt: prompt, system: system, onUpdate: onUpdate)
    }

    /// Settings-page health check. Returns `nil` on success, a human-readable
    /// reason on failure.
    static func testConnection() async -> String? {
        guard isConfigured else {
            return "No Unsloth Studio endpoint set. Enter a URL (e.g. http://localhost:8000/v1) and try again."
        }
        guard let c = client() else {
            return "Couldn't build a client from that endpoint URL — check the format."
        }
        return await c.testConnection()
    }
}
