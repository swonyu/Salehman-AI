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
    /// the keys colliding.
    let keychainAccount: KeychainStore.Account

    /// Where the user obtains a key — surfaced in the Settings UI's
    /// helper text ("Get one at console.groq.com / mistral.ai / …").
    let consoleURL: String

    // MARK: - Reachability

    /// True iff the user has stored a key for this provider. Synchronous —
    /// no HTTP probe so `BrainStatus` polling stays sub-millisecond.
    func hasKey() -> Bool {
        KeychainStore.has(keychainAccount)
    }

    // MARK: - Chat (non-streaming)

    /// Send a single user prompt + optional system message. Returns the
    /// assistant's reply, or `nil` if the key is missing / the call fails /
    /// the response is empty. Same contract as `GrokClient.chat` /
    /// `OllamaClient.chat` so `LocalLLM` can treat all cloud brains uniformly.
    func chat(prompt: String, system: String? = nil, model: String? = nil) async -> String? {
        guard let key = KeychainStore.read(keychainAccount) else { return nil }
        guard let url = URL(string: "\(baseURL)/chat/completions") else { return nil }

        let body = Self.makeBody(model: model ?? defaultModel,
                                 prompt: prompt, system: system, stream: false)
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = payload
        req.timeoutInterval = 120

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse).map({ $0.statusCode == 200 }) == true,
              let text = Self.extractContent(data) else { return nil }
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
        guard let key = KeychainStore.read(keychainAccount) else { return nil }
        guard let url = URL(string: "\(baseURL)/chat/completions") else { return nil }

        let body = Self.makeBody(model: model ?? defaultModel,
                                 prompt: prompt, system: system, stream: true)
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = payload
        req.timeoutInterval = 600

        guard let (bytes, resp) = try? await URLSession.shared.bytes(for: req),
              (resp as? HTTPURLResponse).map({ $0.statusCode == 200 }) == true else { return nil }

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
        guard KeychainStore.read(keychainAccount) != nil else {
            return "No \(displayName) API key saved. Paste one and tap Save."
        }
        if await chat(prompt: "ping", system: nil, model: defaultModel) == nil {
            return "Couldn't reach \(displayName). Check the key + your network."
        }
        return nil
    }

    // MARK: - Internals (shared decode logic)

    private static func makeBody(model: String,
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

    private static func extractContent(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeDelta(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String else { return nil }
        return content
    }
}
