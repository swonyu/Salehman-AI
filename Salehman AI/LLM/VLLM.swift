import Foundation

/// The `.vllm` brain — a thin wrapper that builds an unauthenticated
/// `OpenAICompatibleClient` from the user's vLLM endpoint URL + model name in
/// `AppSettings`. [vLLM](https://github.com/vllm-project/vllm) is a
/// high-throughput inference/serving engine that exposes an **OpenAI-compatible**
/// API — `vllm serve <model>` serves `/v1/chat/completions` on
/// `http://localhost:8000/v1` by default — so it drops into the same client the
/// Unsloth Studio brain uses.
///
/// Mirrors `UnslothStudio` exactly (static namespace, read settings at call time
/// so edits take effect immediately) with one difference: vLLM's OpenAI server
/// needs **no API key**, so the client is always unauthenticated.
///
/// **Privacy guard — `isLocalLoopback`:** the user types an arbitrary URL, so
/// only loopback hosts (`localhost` / `127.0.0.1` / `::1`) keep the prompt on
/// this Mac; `LocalLLM.generateOnDevice` uses vLLM for the on-device-only path
/// only when this is true. A non-loopback endpoint is still pinnable as a normal
/// brain — it just doesn't qualify for the Knowledge vault's on-device path.
enum VLLM {

    // MARK: - Configuration probes

    /// True iff the user has entered any endpoint URL at all (loopback or not).
    static var isConfigured: Bool {
        !AppSettings.vllmEndpointCurrent.isEmpty
    }

    /// True iff the configured endpoint's host is a loopback name.
    static var isLocalLoopback: Bool {
        let raw = AppSettings.vllmEndpointCurrent
        guard !raw.isEmpty, let host = URL(string: raw)?.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    // MARK: - Client builder

    /// Build a fresh `OpenAICompatibleClient` from current settings, or `nil`
    /// when no endpoint is set. Always unauthenticated — vLLM's OpenAI server
    /// is keyless by default.
    static func client() -> OpenAICompatibleClient? {
        let endpoint = AppSettings.vllmEndpointCurrent
        guard !endpoint.isEmpty else { return nil }
        let model = AppSettings.vllmModelCurrent
        return OpenAICompatibleClient(
            displayName: "vLLM",
            baseURL: endpoint,
            defaultModel: model,
            allModels: [model],
            keychainAccount: nil,        // local server — no key
            consoleURL: "https://docs.vllm.ai/",
            requiresKey: false
        )
    }

    // MARK: - Brain surface (mirrors the cloud-client APIs `LocalLLM` calls)

    static func chat(prompt: String, system: String? = nil) async -> String? {
        await client()?.chat(prompt: prompt, system: system)
    }

    static func chatStream(prompt: String,
                           system: String? = nil,
                           onUpdate: @escaping (String) -> Void) async -> String? {
        await client()?.chatStream(prompt: prompt, system: system, onUpdate: onUpdate)
    }

    /// Settings-page health check. `nil` on success, a human-readable reason on failure.
    static func testConnection() async -> String? {
        guard isConfigured else {
            return "No vLLM endpoint set. Enter a URL (e.g. http://localhost:8000/v1) and try again."
        }
        guard let c = client() else {
            return "Couldn't build a client from that endpoint URL — check the format."
        }
        return await c.testConnection()
    }
}
