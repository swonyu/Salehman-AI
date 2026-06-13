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

    /// xAI model IDs offered in the Settings picker. Lower-case + dashes is
    /// what the API accepts. If xAI renames any of these, every request goes
    /// 404 immediately — the unit tests in `GrokTests` pin the strings to
    /// catch that before a user notices.
    ///
    /// **Heavy variants are NOT in `allModels`** — they're reserved constants
    /// for forward compatibility. xAI does not currently expose `grok-4-heavy`
    /// or `grok-4-heavy-4.3` via `/v1/chat/completions` (the "Heavy" mode is
    /// grok.com-only at the time of writing); requests for them 404 with
    /// `"The model … does not exist or your team does not have access to it"`.
    /// When xAI ships API access for either, append the symbol to `allModels`
    /// and the picker will surface it. Until then we ship the *accessible*
    /// catalog: `grok-4` (flagship), `grok-3`, `grok-3-mini` (cheaper).
    nonisolated static let defaultModel  = "grok-4"
    nonisolated static let grok3Model    = "grok-3"
    nonisolated static let grok3MiniModel = "grok-3-mini"
    nonisolated static let buildModel    = "grok-build-0.1"     // fast agentic-coding model
    nonisolated static let heavyModel    = "grok-4-heavy"      // reserved, not user-visible
    nonisolated static let heavy43Model  = "grok-4-heavy-4.3"  // reserved, not user-visible

    // `grok-build-0.1` is confirmed available to this team (it appears in the
    // user's own xAI console). NOTE: the console's "View Code" shows it via the
    // newer **Responses API** (`POST /v1/responses` with `instructions`+`input`),
    // NOT the Chat Completions endpoint this client uses. It's included here as
    // a cheap empirical probe: pin it + hit "Test connection". If it 200s, xAI
    // dual-exposes it on `/v1/chat/completions` and we're done. If it 404s/400s,
    // it's Responses-API-only and needs a dedicated path (tracked in COORDINATION.md).
    nonisolated static let allModels: [String] = [defaultModel, grok3Model, grok3MiniModel, buildModel]

    nonisolated private static let base = "https://api.x.ai/v1"

    /// Shared `OpenAICompatibleClient` instance — exposes Grok to the same
    /// tool-loop path used by Groq / Mistral / Cerebras / OpenAI. xAI's
    /// `/v1/chat/completions` endpoint is fully OpenAI wire-compatible, so
    /// no custom networking code is needed: we just hand the existing client
    /// our base URL and Keychain account. `BrainRouting.compatClient` returns
    /// this so that pinned-Grok conversational turns run terminal / web tools.
    nonisolated static let shared = OpenAICompatibleClient(
        displayName: "xAI Grok",
        baseURL: base,
        defaultModel: defaultModel,
        allModels: allModels,
        keychainAccount: .grokAPIKey,
        consoleURL: "https://console.x.ai"
    )

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
        // Defensive trim (`KeychainStore.read` already trims, but matching
        // `AnthropicClient`'s explicit-trim pattern keeps the cloud clients
        // uniformly hardened against a future Keychain-layer regression).
        let key = (KeychainStore.read(.grokAPIKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        guard let url = URL(string: "\(base)/chat/completions") else { return nil }

        let body = makeBody(model: model, prompt: prompt, system: system, stream: false)
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = payload
        req.timeoutInterval = 120

        // `nil` is reserved for "couldn't reach the server at all" (network
        // gone, DNS failure, etc.). For HTTP responses we always return a
        // non-nil String — either the actual reply or a `[Grok error STATUS:
        // MSG]` so the user sees the real failure (e.g. unknown model, 401
        // bad key, 429 rate limit) instead of the generic offMessage.
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 { return errorText(data: data, status: status) }
        guard let text = extractContent(data) else { return nil }
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
        // Defensive trim (`KeychainStore.read` already trims, but matching
        // `AnthropicClient`'s explicit-trim pattern keeps the cloud clients
        // uniformly hardened against a future Keychain-layer regression).
        let key = (KeychainStore.read(.grokAPIKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
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

        guard let (bytes, resp) = try? await URLSession.shared.bytes(for: req) else { return nil }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            // Non-200 means xAI sent an error JSON, not an SSE stream. Drain
            // the bytes into a Data and produce the same diagnostic shape
            // as the non-streaming path.
            var raw = Data()
            do {
                for try await byte in bytes { raw.append(byte) }
            } catch { /* take whatever we got */ }
            return errorText(data: raw, status: status)
        }

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

    /// Pull a human-readable diagnostic out of a non-200 response body.
    /// xAI mirrors OpenAI's error shape: `{"error":{"message":"...","type":"...","code":"..."}}`.
    /// We surface the message verbatim so a user staring at "model not
    /// found: grok-4-heavy-4.3" knows exactly which Settings field to fix.
    // Visibility note: relaxed from `private` to internal so the test
    // bundle can exercise the decoder directly. No production code path
    // calls this from outside `GrokClient` — it stays effectively private
    // by convention.
    nonisolated static func errorText(data: Data, status: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let err = json["error"] as? [String: Any], let msg = err["message"] as? String {
                return "[Grok error \(status): \(msg)]"
            }
            if let msg = json["error"] as? String {
                return "[Grok error \(status): \(msg)]"
            }
        }
        return "[Grok request failed (HTTP \(status)). Check Settings → Brain → xAI Grok.]"
    }


    /// Build the OpenAI-compatible request body. xAI accepts the standard
    /// `messages` array; we add a `system` role only when one was provided
    /// so empty turns don't waste tokens on an empty system message.
    // Visibility note: internal (not `private`) so the test bundle can verify
    // the request shape directly. No production code calls it from outside
    // `GrokClient` — it stays effectively private by convention. (Same
    // pattern as `errorText`.)
    nonisolated static func makeBody(model: String,
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
    // Internal for test access (see `makeBody` note).
    nonisolated static func extractContent(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Pull `choices[0].delta.content` out of a streaming chunk.
    /// Returns content **verbatim** — deltas must NOT be trimmed, or words
    /// joined across chunk boundaries ("hello" + " world") would collapse.
    // Internal for test access (see `makeBody` note).
    nonisolated static func decodeDelta(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String else { return nil }
        return content
    }
}
