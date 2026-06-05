import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Cloud-brain error-body decoders
//
// Every cloud client (Grok, Gemini, OpenAICompatibleClient-backed Groq/
// Mistral/Cerebras/OpenAI) now surfaces non-200 responses as a
// `[Provider error STATUS: MSG]` string instead of swallowing them into
// `nil`. The decoders that produce those strings live in private methods
// — these tests pin their *contract*:
//
//   1. They never crash, even on garbage input (empty Data, plaintext,
//      truncated JSON, JSON with unexpected shape).
//   2. They produce a non-empty, status-prefixed diagnostic.
//   3. When the canonical error shape IS present, they extract the
//      provider's verbatim message.
//
// All three decoders are read-only pure functions over `(Data, Int)`, so
// these tests are fast and deterministic — no network, no mocking.

// MARK: - Helpers

private func data(_ json: String) -> Data { Data(json.utf8) }

private let emptyBody = Data()
private let plaintextBody = Data("just some plain text, not JSON".utf8)
private let truncatedJSONBody = Data(#"{"error":{"messa"#.utf8)

// MARK: - GrokClient.errorText

struct GrokErrorDecoderTests {

    @Test func extractsCanonicalErrorMessage() {
        // xAI mirrors OpenAI's error shape: {error:{message,type,code}}.
        let body = data(#"{"error":{"message":"The model `grok-4-heavy-4.3` does not exist","type":"invalid_request_error","code":"model_not_found"}}"#)
        let result = GrokClient.errorText(data: body, status: 404)
        #expect(result.hasPrefix("[Grok error 404:"))
        #expect(result.contains("grok-4-heavy-4.3"))
    }

    @Test func handlesPlainStringError() {
        // Some misconfigured proxies return `{"error":"plain string"}`.
        // The decoder accepts this shape too.
        let body = data(#"{"error":"plain string error from upstream proxy"}"#)
        let result = GrokClient.errorText(data: body, status: 502)
        #expect(result.contains("plain string error from upstream proxy"))
        #expect(result.contains("502"))
    }

    @Test func fallsBackOnEmptyBody() {
        // Empty body (server gave us nothing). Must still produce a
        // useful, status-prefixed message — not crash, not return "".
        let result = GrokClient.errorText(data: emptyBody, status: 500)
        #expect(!result.isEmpty)
        #expect(result.contains("500"))
    }

    @Test func fallsBackOnPlaintextBody() {
        // Plaintext (e.g. an HTML error page from a CDN).
        let result = GrokClient.errorText(data: plaintextBody, status: 503)
        #expect(!result.isEmpty)
        #expect(result.contains("503"))
    }

    @Test func fallsBackOnTruncatedJSON() {
        // Mid-stream cut. JSONSerialization returns nil → fallback fires.
        let result = GrokClient.errorText(data: truncatedJSONBody, status: 502)
        #expect(!result.isEmpty)
        #expect(result.contains("502"))
    }

    @Test func surfacesProviderName() {
        // The "Grok" string in the output is what lets the user identify
        // which cloud brain failed — important when multiple are
        // configured. Pin it explicitly.
        let body = data(#"{"error":{"message":"any"}}"#)
        let result = GrokClient.errorText(data: body, status: 400)
        #expect(result.contains("Grok"))
    }
}

// MARK: - GeminiClient.errorText

struct GeminiErrorDecoderTests {

    @Test func extractsCanonicalErrorMessage() {
        // Google's shape: {error:{code, message, status}}.
        let body = data(#"{"error":{"code":429,"message":"You exceeded your current quota","status":"RESOURCE_EXHAUSTED"}}"#)
        let result = GeminiClient.errorText(data: body, status: 429)
        #expect(result.hasPrefix("[Gemini error 429:"))
        #expect(result.contains("quota"))
    }

    @Test func fallsBackToStatusEnumWhenMessageMissing() {
        // Some Google responses include only the `status` enum without a
        // human message (rare but happens). The decoder prefers `message`,
        // falls back to the enum — both are diagnostic.
        let body = data(#"{"error":{"code":403,"status":"PERMISSION_DENIED"}}"#)
        let result = GeminiClient.errorText(data: body, status: 403)
        #expect(result.hasPrefix("[Gemini error 403:"))
        #expect(result.contains("PERMISSION_DENIED"))
    }

    @Test func fallsBackOnEmptyBody() {
        let result = GeminiClient.errorText(data: emptyBody, status: 500)
        #expect(!result.isEmpty)
        #expect(result.contains("500"))
    }

    @Test func fallsBackOnPlaintextBody() {
        let result = GeminiClient.errorText(data: plaintextBody, status: 503)
        #expect(!result.isEmpty)
        #expect(result.contains("503"))
    }

    @Test func surfacesProviderName() {
        let body = data(#"{"error":{"message":"any"}}"#)
        let result = GeminiClient.errorText(data: body, status: 400)
        #expect(result.contains("Gemini"))
    }
}

// MARK: - OpenAICompatibleClient.errorText
//
// One decoder shared by Groq, Mistral, Cerebras, and OpenAI. The
// `displayName` field is what differentiates the output per provider —
// these tests run against the Groq config but the logic is identical
// for the other three.

struct OpenAICompatibleErrorDecoderTests {

    private let client = GroqClient.shared

    @Test func extractsCanonicalErrorMessage() {
        let body = data(#"{"error":{"message":"Invalid API key","type":"authentication_error"}}"#)
        let result = client.errorText(data: body, status: 401)
        #expect(result.hasPrefix("[Groq error 401:"))
        #expect(result.contains("Invalid API key"))
    }

    @Test func handlesPlainStringError() {
        let body = data(#"{"error":"plain string upstream error"}"#)
        let result = client.errorText(data: body, status: 502)
        #expect(result.contains("plain string upstream error"))
        #expect(result.contains("502"))
    }

    @Test func fallsBackOnEmptyBody() {
        let result = client.errorText(data: emptyBody, status: 500)
        #expect(!result.isEmpty)
        #expect(result.contains("500"))
        // Falls back to "Groq request failed…" specifically, not a
        // generic "request failed" — verifies the displayName interpolation
        // works on the fallback path too.
        #expect(result.contains("Groq"))
    }

    @Test func fallsBackOnPlaintextBody() {
        let result = client.errorText(data: plaintextBody, status: 503)
        #expect(!result.isEmpty)
        #expect(result.contains("503"))
    }

    @Test func eachProviderUsesItsOwnDisplayName() {
        // The shared decoder must produce provider-specific output. If
        // someone hardcodes "Groq" or "OpenAI" in the format string, the
        // other providers' replies would all say the wrong thing.
        let body = data(#"{"error":{"message":"any"}}"#)
        #expect(GroqClient.shared.errorText(data: body, status: 400).contains("Groq"))
        #expect(MistralClient.shared.errorText(data: body, status: 400).contains("Mistral"))
        #expect(CerebrasClient.shared.errorText(data: body, status: 400).contains("Cerebras"))
    }
}
