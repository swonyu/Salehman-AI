import Foundation

/// Calls Anthropic's Messages API (cloud) for Claude Haiku 4.5 — the optional
/// third "brain" alongside local Ollama. Cloud inference
/// means ~zero local RAM (it can't freeze the Mac), but it needs the user's API
/// key (entered in Settings) and sends prompts off-device to Anthropic.
///
/// Direct REST via URLSession — there is no official Anthropic Swift SDK, so this
/// mirrors how `OllamaClient` talks to the local server.
enum AnthropicClient {
    /// Canonical alias for Claude Haiku 4.5 (full ID: claude-haiku-4-5-20251001).
    static let model = "claude-haiku-4-5"
    private static let endpoint = "https://api.anthropic.com/v1/messages"
    private static let apiVersion = "2023-06-01"
    static let maxTokens = 1024

    /// True once the user has stored an Anthropic API key (in the Keychain, like
    /// every other cloud brain). Sync — no HTTP probe.
    nonisolated static var isConfigured: Bool { KeychainStore.has(.anthropicAPIKey) }

    private static func makeRequest(stream: Bool, prompt: String, system: String?,
                                    cachePrefix: String?) -> URLRequest? {
        let key = (KeychainStore.read(.anthropicAPIKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, let url = URL(string: endpoint) else { return nil }

        // When a large STABLE prefix (e.g. the conversation history) is supplied,
        // send it as its own content block marked `cache_control: ephemeral`.
        // Anthropic then caches that prefix, so the next turns of a long
        // conversation re-use it (~90% cheaper on those tokens + lower latency).
        // Below the per-model minimum (~2048 tokens for Haiku) it's a free no-op.
        let userContent: Any
        if let cachePrefix, !cachePrefix.isEmpty {
            userContent = [
                ["type": "text", "text": cachePrefix, "cache_control": ["type": "ephemeral"]],
                ["type": "text", "text": prompt],
            ]
        } else {
            userContent = prompt
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [["role": "user", "content": userContent]],
            "stream": stream,
        ]
        if let system, !system.isEmpty {
            // Cache the (stable) system prefix. Only caches above ~4096 tokens on
            // Haiku — harmless and free otherwise.
            body["system"] = [["type": "text", "text": system,
                               "cache_control": ["type": "ephemeral"]]]
        }
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        req.httpBody = payload
        req.timeoutInterval = stream ? 600 : 120
        return req
    }

    /// Non-streaming completion. Returns nil only on a network/parse failure so
    /// callers can degrade; a non-200 from the API comes back as a readable
    /// error string (so the user sees "invalid API key" rather than silence).
    static func chat(prompt: String, system: String? = nil, cachePrefix: String? = nil) async -> String? {
        guard let req = makeRequest(stream: false, prompt: prompt, system: system, cachePrefix: cachePrefix) else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        guard http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            return errorText(data: data, status: http.statusCode)
        }
        let text = content.compactMap { block -> String? in
            (block["type"] as? String) == "text" ? block["text"] as? String : nil
        }.joined()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Streaming completion via SSE. `onUpdate` receives the cumulative text.
    /// Returns the final text, or nil if the request couldn't start.
    static func chatStream(prompt: String, system: String? = nil, cachePrefix: String? = nil,
                           onUpdate: @escaping (String) -> Void) async -> String? {
        guard let req = makeRequest(stream: true, prompt: prompt, system: system, cachePrefix: cachePrefix) else { return nil }
        guard let (bytes, resp) = try? await URLSession.shared.bytes(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        var accumulated = ""
        do {
            for try await line in bytes.lines {
                // SSE: payload lines are `data: {json}`; `event:` lines are ignored.
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                guard let d = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                      let type = json["type"] as? String else { continue }
                if type == "content_block_delta",
                   let delta = json["delta"] as? [String: Any],
                   (delta["type"] as? String) == "text_delta",
                   let chunk = delta["text"] as? String, !chunk.isEmpty {
                    accumulated += chunk
                    onUpdate(accumulated)
                } else if type == "message_stop" {
                    break
                }
            }
        } catch {
            // Network/stream error — fall through with whatever arrived.
        }
        let trimmed = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Pull a human-readable message out of a non-200 error body.
    private static func errorText(data: Data, status: Int) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = json["error"] as? [String: Any], let msg = err["message"] as? String {
            return "[Claude Haiku error \(status): \(msg)]"
        }
        return "[Claude Haiku request failed (HTTP \(status)). Check your Anthropic API key in Settings.]"
    }
}
