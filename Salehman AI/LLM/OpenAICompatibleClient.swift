import Foundation

/// Generic HTTP client for the OpenAI `/v1/chat/completions` wire format.
///
/// Many cloud providers (Groq, Mistral, Cerebras, xAI Grok, Together, Fireworks…)
/// speak the same JSON shape: `{model, messages:[{role,content}], stream}` →
/// `{choices:[{message:{content}}]}` (or SSE chunks `{choices:[{delta:{content}}]}`).
/// This struct parameterizes the few things that *do* differ — base URL,
/// default model, Keychain account, display label — so each new provider is
/// a ~30-line config file instead of a copy-paste of `GrokClient`.
///
/// **Privacy**: every call here ships the prompt + system message to a third
/// party. `LocalLLM`'s fallback chain only routes here when the user has
/// explicitly pinned a cloud brain — `.auto` stays strictly local-first.
///
/// **Secrets**: the API key is read from Keychain at call time. The literal
/// string only exists in memory as (1) the `Data` parameter in `KeychainStore.write`
/// when the user types it, and (2) the `Authorization: Bearer …` header bytes
/// on the outbound request.
struct OpenAICompatibleClient: Sendable {

    // MARK: - Configuration

    /// Identity label used in headers / logs / UI ("Groq", "Mistral", …).
    let displayName: String

    /// API root, e.g. `https://api.groq.com/openai/v1`. The client appends
    /// `/chat/completions` itself.
    let baseURL: String

    /// Model the caller picks when they don't specify one.
    let defaultModel: String

    /// All models the picker offers. Order matters — first is the "lightest"
    /// option, last is "heaviest".
    let allModels: [String]

    /// Keychain slot where this provider's API key lives. Each provider gets
    /// its own account name so users can stack multiple cloud brains without
    /// the keys colliding. **Optional** so the same client can drive
    /// unauthenticated local OpenAI-compatible servers (Unsloth Studio,
    /// `mlx_lm.server`, llama.cpp, LM Studio, …) where no Bearer header is
    /// needed; in that case set `requiresKey: false`.
    let keychainAccount: KeychainStore.Account?

    /// Where the user obtains a key — surfaced in the Settings UI's
    /// helper text ("Get one at console.groq.com / mistral.ai / …").
    let consoleURL: String

    /// When `false`, the endpoint is unauthenticated (e.g., a local Unsloth
    /// Studio server on `localhost:8000`). The `Authorization` header is
    /// omitted, no Keychain read is attempted, and `hasKey()` returns true so
    /// reachability gating in `LocalLLM` depends only on whether the URL is set.
    /// Defaults to `true` so every existing cloud caller is unaffected.
    /// `var` (not `let`) so it stays in the synthesized memberwise initializer —
    /// a `let` with a default is excluded, which made `requiresKey: false`
    /// (the documented usage above) fail to compile for local servers.
    var requiresKey: Bool = true

    /// Optional `prompt_cache_key` for OpenAI's automatic prompt caching — groups
    /// requests that share a prefix so they hit the same cache (higher hit rate +
    /// lower latency). Set ONLY for the real OpenAI provider; other OpenAI-compatible
    /// servers may reject an unknown field, so it stays nil for them. Harmless no-op
    /// below the per-model cache floor (~1024 tokens).
    var promptCacheKey: String? = nil

    // MARK: - Reachability

    /// True iff this brain is considered "configured." For authenticated
    /// providers, that means a key is in Keychain. For unauthenticated local
    /// servers (`requiresKey == false`), we always return true — the URL is
    /// what gates reachability, and the caller validates it before constructing
    /// the client. Synchronous — no HTTP probe so `BrainStatus` polling stays
    /// sub-millisecond.
    func hasKey() -> Bool {
        if !requiresKey { return true }
        guard let account = keychainAccount else { return false }
        return KeychainStore.has(account)
    }

    // MARK: - Chat (non-streaming)

    /// Send a single user prompt + optional system message. Returns the
    /// assistant's reply, or `nil` if the key is missing / the call fails /
    /// the response is empty. Same contract as `GrokClient.chat` /
    /// `OllamaClient.chat` so `LocalLLM` can treat all cloud brains uniformly.
    func chat(prompt: String, system: String? = nil, model: String? = nil) async -> String? {
        var bearer: String? = nil
        if requiresKey {
            guard let account = keychainAccount, let key = KeychainStore.read(account) else { return nil }
            bearer = key
        }
        guard let url = URL(string: "\(baseURL)/chat/completions") else { return nil }

        var body = Self.makeBody(model: model ?? defaultModel,
                                 prompt: prompt, system: system, stream: false)
        if let promptCacheKey { body["prompt_cache_key"] = promptCacheKey }
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        req.httpBody = payload
        req.timeoutInterval = 120

        // `nil` only when we couldn't reach the server. For HTTP responses we
        // always return a non-nil String — either the assistant's reply or a
        // `[<Provider> error STATUS: MSG]` diagnostic, so the user sees the
        // real failure mode instead of the generic offMessage sentinel.
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 { return errorText(data: data, status: status) }
        guard let text = Self.extractContent(data) else { return nil }
        return text.isEmpty ? nil : text
    }

    // MARK: - Chat (streaming)

    /// Streaming variant. Invokes `onUpdate` with the cumulative text after
    /// every delta. xAI/Groq/Mistral/Cerebras all emit OpenAI-style SSE:
    /// `data: {"choices":[{"delta":{"content":"…"}}]}` lines, terminated by
    /// `data: [DONE]`.
    func chatStream(prompt: String,
                    system: String? = nil,
                    model: String? = nil,
                    onUpdate: @escaping (String) -> Void) async -> String? {
        var bearer: String? = nil
        if requiresKey {
            guard let account = keychainAccount, let key = KeychainStore.read(account) else { return nil }
            bearer = key
        }
        guard let url = URL(string: "\(baseURL)/chat/completions") else { return nil }

        var body = Self.makeBody(model: model ?? defaultModel,
                                 prompt: prompt, system: system, stream: true)
        if let promptCacheKey { body["prompt_cache_key"] = promptCacheKey }
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        req.httpBody = payload
        req.timeoutInterval = 600

        guard let (bytes, resp) = try? await URLSession.shared.bytes(for: req) else { return nil }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            // Non-200 means the server sent an error JSON, not an SSE stream.
            var raw = Data()
            do { for try await byte in bytes { raw.append(byte) } } catch {}
            return errorText(data: raw, status: status)
        }

        var accumulated = ""
        do {
            for try await rawLine in bytes.lines {
                // Single `data:` line per chunk — same parsing as GrokClient.
                guard rawLine.hasPrefix("data:") else { continue }
                let payload = rawLine
                    .dropFirst("data:".count)
                    .trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" { break }
                if let chunk = Self.decodeDelta(payload), !chunk.isEmpty {
                    accumulated += chunk
                    onUpdate(accumulated)
                }
            }
        } catch {
            // Surface whatever we've accumulated on a mid-stream blip.
        }
        return accumulated.isEmpty ? nil : accumulated
    }

    // MARK: - Test connection

    /// Tap the live endpoint with a one-token prompt. Returns nil on success
    /// or a human-readable reason on failure (surfaced in Settings).
    func testConnection() async -> String? {
        if requiresKey {
            guard let account = keychainAccount, KeychainStore.read(account) != nil else {
                return "No \(displayName) API key saved. Paste one and tap Save."
            }
        }
        if await chat(prompt: "ping", system: nil, model: defaultModel) == nil {
            return requiresKey
                ? "Couldn't reach \(displayName). Check the key + your network."
                : "Couldn't reach \(displayName) at \(baseURL). Is the server running?"
        }
        return nil
    }

    // MARK: - Error formatting

    /// Pull a human-readable diagnostic out of a non-200 response body. All
    /// OpenAI-compatible providers we ship to (Groq, Mistral, Cerebras,
    /// OpenAI itself) follow the same error shape: `{"error":{"message":"...","type":"..."}}`.
    /// We include `displayName` so the chat reply tells you *which* cloud
    /// brain failed — important when multiple are configured.
    // Visibility note: relaxed from `private` to internal so the test
    // bundle can exercise the decoder directly. No production code path
    // calls this from outside `OpenAICompatibleClient` — it stays
    // effectively private by convention.
    func errorText(data: Data, status: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let err = json["error"] as? [String: Any], let msg = err["message"] as? String {
                return "[\(displayName) error \(status): \(msg)]"
            }
            if let msg = json["error"] as? String {
                return "[\(displayName) error \(status): \(msg)]"
            }
        }
        return "[\(displayName) request failed (HTTP \(status)). Check the key + your network.]"
    }

    // MARK: - Internals (shared decode logic)

    // Internal for test access (see `errorText` visibility note).
    static func makeBody(model: String,
                                 prompt: String,
                                 system: String?,
                                 stream: Bool) -> [String: Any] {
        var messages: [[String: String]] = []
        if let system, !system.isEmpty {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": prompt])
        return [
            "model":    model,
            "messages": messages,
            "stream":   stream,
        ]
    }

    // Internal for test access (see `errorText` visibility note). Shared by
    // Groq / Mistral / Cerebras / OpenAI, so one regression here breaks four
    // providers — worth direct coverage.
    static func extractContent(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns the delta content **verbatim** — must NOT trim, or words get
    /// joined across streamed chunk boundaries. Internal for test access.
    static func decodeDelta(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String else { return nil }
        return content
    }
}
