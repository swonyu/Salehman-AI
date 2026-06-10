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
        guard let url = makeURL(model: model, action: "generateContent",
                                key: key, extraQueryItems: []) else { return nil }

        let body = makeBody(prompt: prompt, system: system)
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload
        req.timeoutInterval = 120

        // `nil` is reserved for "couldn't reach the server"; HTTP errors come
        // back as `[Gemini error STATUS: MSG]` so the user sees the real
        // reason (e.g. PERMISSION_DENIED, RESOURCE_EXHAUSTED, NOT_FOUND for
        // an unknown model id) instead of the generic offMessage.
        // Retry transient throttle / unavailable responses (429 RESOURCE_EXHAUSTED,
        // 503 service unavailable) with exponential backoff before surfacing the
        // error. `nil` (couldn't reach the server) is NOT retried here — that's the
        // caller's brain-chain to roll past.
        var attempt = 0
        while true {
            guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                guard let text = extractContent(data) else { return nil }
                return text.isEmpty ? nil : text
            }
            if isRetryableStatus(status), attempt < maxRetries {
                let delay = backoffDelay(attempt: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempt += 1
                continue
            }
            return errorText(data: data, status: status)
        }
    }

    // MARK: - Retry policy (pure — unit-tested in GeminiBackoffTests)

    /// Max retry attempts after the first try, for transient 429/503 responses.
    nonisolated static let maxRetries = 3

    /// True for HTTP statuses worth retrying: 429 (rate-limited / RESOURCE_EXHAUSTED)
    /// and 503 (service temporarily unavailable). Everything else surfaces as-is.
    nonisolated static func isRetryableStatus(_ status: Int) -> Bool {
        status == 429 || status == 503
    }

    /// Exponential backoff: base · 2^attempt, capped. attempt 0 → 0.5s, 1 → 1s,
    /// 2 → 2s, … capped at `cap`. Deterministic (no jitter) so it's testable.
    nonisolated static func backoffDelay(attempt: Int, base: Double = 0.5, cap: Double = 8.0) -> Double {
        let raw = base * pow(2.0, Double(max(0, attempt)))
        return min(cap, raw)
    }

    // MARK: - Chat (streaming)

    nonisolated static func chatStream(prompt: String,
                                       system: String? = nil,
                                       model: String = defaultModel,
                                       onUpdate: @escaping (String) -> Void) async -> String? {
        guard let key = KeychainStore.read(.geminiAPIKey) else { return nil }
        guard let url = makeURL(model: model, action: "streamGenerateContent",
                                key: key,
                                extraQueryItems: [URLQueryItem(name: "alt", value: "sse")]) else { return nil }

        let body = makeBody(prompt: prompt, system: system)
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.httpBody = payload
        req.timeoutInterval = 600

        guard let (bytes, resp) = try? await URLSession.shared.bytes(for: req) else { return nil }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            var raw = Data()
            do { for try await byte in bytes { raw.append(byte) } } catch {}
            return errorText(data: raw, status: status)
        }

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

    /// Build the Gemini endpoint URL via `URLComponents` so the key, model,
    /// and any extra query items are correctly percent-encoded. The earlier
    /// implementation interpolated `key` directly into a string template; if
    /// a user ever pasted a key containing `+`, `&`, `?`, whitespace, or
    /// other URL-reserved characters (rare for `AIza…` keys but defensible
    /// at the boundary), `URL(string:)` would silently return nil and the
    /// caller would see a generic "no model is reachable" instead of a
    /// useful diagnostic. URLComponents fixes that at the source.
    ///
    /// The action argument is the per-method tail ("generateContent" or
    /// "streamGenerateContent"); `extraQueryItems` is for sibling params
    /// like `alt=sse` on the streaming endpoint.
    nonisolated static func makeURL(model: String,
                                    action: String,
                                    key: String,
                                    extraQueryItems: [URLQueryItem]) -> URL? {
        // Google's URL puts `:` between the model name and the action verb
        // — that's a sub-delim that `URLComponents.path` accepts directly,
        // no special handling required.
        guard var comps = URLComponents(string: "\(base)/models/\(model):\(action)") else {
            return nil
        }
        comps.queryItems = extraQueryItems + [URLQueryItem(name: "key", value: key)]
        return comps.url
    }


    /// Pull a human-readable diagnostic out of a non-200 response body.
    /// Google's error shape is `{"error":{"code":..., "message":"...", "status":"..."}}`.
    /// We prefer the human `message` and fall back to the `status` enum
    /// (e.g. `NOT_FOUND`, `PERMISSION_DENIED`) if the server didn't include
    /// a message — both are diagnostic.
    // Visibility note: relaxed from `private` to internal so the test
    // bundle can exercise the decoder directly. No production code path
    // calls this from outside `GeminiClient` — it stays effectively private
    // by convention.
    nonisolated static func errorText(data: Data, status: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = json["error"] as? [String: Any] {
            if let msg = err["message"] as? String {
                return "[Gemini error \(status): \(msg)]"
            }
            if let s = err["status"] as? String {
                return "[Gemini error \(status): \(s)]"
            }
        }
        return "[Gemini request failed (HTTP \(status)). Check Settings → Brain → Google Gemini.]"
    }

    // Internal for test access (see `errorText` visibility note above).
    nonisolated static func makeBody(prompt: String, system: String?) -> [String: Any] {
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
    // Internal for test access.
    nonisolated static func extractContent(_ data: Data) -> String? {
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
    // Internal for test access.
    nonisolated static func extractStreamingDelta(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return extractContent(data)
    }
}
