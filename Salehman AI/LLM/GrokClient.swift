import Foundation

/// HTTP client for xAI's Grok API (https://api.x.ai). The wire format is
/// OpenAI-compatible: POST `/v1/chat/completions` with a Bearer token and a
/// `messages` array, response shape is `{choices:[{message:{content:String}}]}`.
///
/// Why mirror `OllamaClient`'s public surface (`chat(prompt:system:model:)` +
/// `chatStream(...)`): `LocalLLM` already has a fallback chain that calls
/// those signatures; making Grok callable through the same shape means the
/// brain-selection logic doesn't need a third code path.
///
/// **Privacy**: every call here ships the prompt + system message to xAI's
/// servers. The `LocalLLM` fallback chain only reaches this client when the
/// user has explicitly set `BrainPreference.grok` — `auto` never falls
/// through to Grok by design.
///
/// **Secrets**: the API key is fetched from `KeychainStore` at call time.
/// This file never sees, logs, or stores the literal key string except as
/// the `Authorization` header bytes on the outbound request.
enum GrokClient {

    /// Default model IDs. The two visible "tiers" in the Settings picker —
    /// real xAI catalog strings, lower-case with dashes as the API expects.
    nonisolated static let defaultModel = "grok-4"
    nonisolated static let heavyModel   = "grok-4-heavy"

    nonisolated static let allModels: [String] = [defaultModel, heavyModel]

    nonisolated private static let base = "https://api.x.ai/v1"

    // MARK: - Reachability

    /// True iff the user has stored a Grok key. This is a cheap proxy for
    /// "Grok is configured" — we don't probe the network to avoid making
    /// `BrainStatus` polling burn an HTTP request every 10s.
    nonisolated static func hasKey() -> Bool {
        KeychainStore.has(.grokAPIKey)
    }

    // MARK: - Chat (non-streaming)

    /// Sends a single user prompt + optional system message and returns the
    /// assistant's reply. Returns nil when:
    ///   * no API key is stored,
    ///   * the network call fails or times out,
    ///   * the server returns a non-2xx status,
    ///   * the response JSON doesn't contain a non-empty `choices[0].message.content`.
    /// Callers (i.e. `LocalLLM.chat`) treat nil as "fall through to the next
    /// brain or surface the off-message" — same contract as `OllamaClient.chat`.
    nonisolated static func chat(prompt: String,
                                 system: String? = nil,
                                 model: String = defaultModel) async -> String? {
        guard let key = KeychainStore.read(.grokAPIKey) else { return nil }
        guard let url = URL(string: "\(base)/chat/completions") else { return nil }

        let body = makeBody(model: model, prompt: prompt, system: system, stream: false)
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = payload
        req.timeoutInterval = 120

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse).map({ $0.statusCode == 200 }) == true,
              let text = extractContent(data) else { return nil }
        return text.isEmpty ? nil : text
    }

    // MARK: - Chat (streaming via SSE)

    /// Same as `chat`, but invokes `onUpdate` with the cumulative content
    /// every time a new delta arrives. xAI streams Server-Sent Events in
    /// OpenAI's chunked format: `data: {"choices":[{"delta":{"content":"..."}}]}`
    /// terminated by `data: [DONE]`.
    nonisolated static func chatStream(prompt: String,
                                       system: String? = nil,
                                       model: String = defaultModel,
                                       onUpdate: @escaping (String) -> Void) async -> String? {
        guard let key = KeychainStore.read(.grokAPIKey) else { return nil }
        guard let url = URL(string: "\(base)/chat/completions") else { return nil }

        let body = makeBody(model: model, prompt: prompt, system: system, stream: true)
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
                // SSE format: each event is one or more `data:` lines, then a
                // blank line. xAI/OpenAI use a single `data:` line per chunk,
                // so we can parse line-by-line without buffering events.
                guard rawLine.hasPrefix("data:") else { continue }
                let payload = rawLine
                    .dropFirst("data:".count)
                    .trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" { break }
                if let chunk = decodeDelta(payload), !chunk.isEmpty {
                    accumulated += chunk
                    onUpdate(accumulated)
                }
            }
        } catch {
            // Surface whatever we accumulated so the UI doesn't lose state on
            // a mid-stream network blip.
        }
        return accumulated.isEmpty ? nil : accumulated
    }

    // MARK: - Test connection

    /// Hits the same endpoint with a one-token prompt to verify the key works.
    /// Returns nil on success, or a human-readable error reason on failure —
    /// the Settings "Test connection" button surfaces this directly.
    nonisolated static func testConnection() async -> String? {
        guard KeychainStore.read(.grokAPIKey) != nil else {
            return "No API key saved. Paste your key and tap Save first."
        }
        if await chat(prompt: "ping", system: nil, model: defaultModel) == nil {
            return "Couldn't reach xAI with the saved key. Check the key + your network."
        }
        return nil   // nil means "all good"
    }

    // MARK: - Internals

    /// Build the OpenAI-compatible request body. xAI accepts the standard
    /// `messages` array; we add a `system` role only when one was provided
    /// so empty turns don't waste tokens on an empty system message.
    nonisolated private static func makeBody(model: String,
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

    /// Pull `choices[0].message.content` out of a non-streaming response.
    nonisolated private static func extractContent(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Pull `choices[0].delta.content` out of a streaming chunk.
    nonisolated private static func decodeDelta(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String else { return nil }
        return content
    }
}
