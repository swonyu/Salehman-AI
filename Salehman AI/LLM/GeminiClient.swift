import Foundation

/// HTTP client for Google's Gemini API (Google AI Studio).
///
/// Google's API is *not* OpenAI-compatible — different request shape, different
/// auth mechanism (URL `?key=` param instead of `Authorization: Bearer`), and
/// different SSE event format. So this is its own client, parallel to
/// `OpenAICompatibleClient` / `OllamaClient` / `AnthropicClient`.
///
/// Wire shape (non-streaming):
/// ```
/// POST /v1beta/models/<model>:generateContent?key=<KEY>
/// {
///   "contents":[{ "role":"user", "parts":[{ "text":"..." }] }],
///   "systemInstruction":{ "parts":[{ "text":"..." }] }     // optional
/// }
/// → { "candidates":[{ "content":{ "parts":[{ "text":"..." }] } }] }
/// ```
///
/// Streaming uses `:streamGenerateContent?alt=sse` with the same body and a
/// sequence of `data: {...}` events.
///
/// Free tier on Google AI Studio is the most generous of the cloud brains
/// supported by this app — `gemini-2.0-flash` has a multi-thousand
/// requests/day allowance at the time of writing.
enum GeminiClient {

    /// Default models — keep these strings pinned to the IDs Google
    /// publishes in AI Studio. A rename means a runtime 404; the unit tests
    /// guard against typos.
    nonisolated static let defaultModel = "gemini-2.0-flash"
    nonisolated static let proModel     = "gemini-1.5-pro"
    nonisolated static let allModels: [String] = [defaultModel, proModel, "gemini-1.5-flash"]

    nonisolated private static let base = "https://generativelanguage.googleapis.com/v1beta"

    // MARK: - Reachability

    nonisolated static func hasKey() -> Bool {
        KeychainStore.has(.geminiAPIKey)
    }

    // MARK: - Chat (non-streaming)

    nonisolated static func chat(prompt: String,
                                 system: String? = nil,
                                 model: String = defaultModel) async -> String? {
        guard let key = KeychainStore.read(.geminiAPIKey) else { return nil }
        guard let url = URL(string: "\(base)/models/\(model):generateContent?key=\(key)") else { return nil }

        let body = makeBody(prompt: prompt, system: system)
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload
        req.timeoutInterval = 120

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse).map({ $0.statusCode == 200 }) == true,
              let text = extractContent(data) else { return nil }
        return text.isEmpty ? nil : text
    }

    // MARK: - Chat (streaming)

    nonisolated static func chatStream(prompt: String,
                                       system: String? = nil,
                                       model: String = defaultModel,
                                       onUpdate: @escaping (String) -> Void) async -> String? {
        guard let key = KeychainStore.read(.geminiAPIKey) else { return nil }
        guard let url = URL(string: "\(base)/models/\(model):streamGenerateContent?alt=sse&key=\(key)") else { return nil }

        let body = makeBody(prompt: prompt, system: system)
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.httpBody = payload
        req.timeoutInterval = 600

        guard let (bytes, resp) = try? await URLSession.shared.bytes(for: req),
              (resp as? HTTPURLResponse).map({ $0.statusCode == 200 }) == true else { return nil }

        var accumulated = ""
        do {
            for try await rawLine in bytes.lines {
                guard rawLine.hasPrefix("data:") else { continue }
                let payload = rawLine
                    .dropFirst("data:".count)
                    .trimmingCharacters(in: .whitespaces)
                if payload.isEmpty || payload == "[DONE]" { continue }
                if let chunk = extractStreamingDelta(payload), !chunk.isEmpty {
                    accumulated += chunk
                    onUpdate(accumulated)
                }
            }
        } catch {
            // Surface whatever we have on a mid-stream blip.
        }
        return accumulated.isEmpty ? nil : accumulated
    }

    // MARK: - Test connection

    nonisolated static func testConnection() async -> String? {
        guard KeychainStore.read(.geminiAPIKey) != nil else {
            return "No Gemini API key saved. Paste one and tap Save first."
        }
        if await chat(prompt: "ping", system: nil, model: defaultModel) == nil {
            return "Couldn't reach Google AI with the saved key. Check the key + your network."
        }
        return nil
    }

    // MARK: - Internals

    nonisolated private static func makeBody(prompt: String, system: String?) -> [String: Any] {
        var body: [String: Any] = [
            "contents": [
                [
                    "role":  "user",
                    "parts": [["text": prompt]],
                ]
            ]
        ]
        if let system, !system.isEmpty {
            body["systemInstruction"] = ["parts": [["text": system]]]
        }
        return body
    }

    /// Pull `candidates[0].content.parts[0].text` out of a non-streaming
    /// response. Gemini sometimes returns multiple parts (e.g. when tools
    /// are enabled) — we concatenate them to handle the future case.
    nonisolated private static func extractContent(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { return nil }
        let texts = parts.compactMap { $0["text"] as? String }
        let joined = texts.joined()
        return joined.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Streaming chunks have the same shape as non-streaming responses —
    /// one candidate, one or more parts each with `text`. We extract
    /// whatever text the chunk contains; the caller accumulates.
    nonisolated private static func extractStreamingDelta(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return extractContent(data)
    }
}
