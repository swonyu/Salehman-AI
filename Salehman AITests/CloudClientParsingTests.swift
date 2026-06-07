import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Cloud-client pure parsing/building functions
//
// `makeBody`, `extractContent`, and `decodeDelta` in the three Chat-B cloud
// clients (Grok, Gemini, OpenAICompatible→Groq/Mistral/Cerebras/OpenAI) turn
// structured data into HTTP request bodies and parse responses back. A wrong
// shape silently 404s (bad body) or returns an empty reply (bad parse) — both
// look like "the brain is broken" with no clue why. These functions are pure
// (no network, no Keychain), so they're cheap to lock down here.
//
// The error-path decoders (`errorText`) are covered separately in
// CloudErrorDecoderTests.swift; these cover the happy path.

// MARK: - Grok request body + parsers

struct GrokParsingTests {

    @Test func makeBodyIncludesSystemWhenProvided() {
        let body = GrokClient.makeBody(model: "grok-4", prompt: "hi", system: "be terse", stream: false)
        #expect(body["model"] as? String == "grok-4")
        #expect(body["stream"] as? Bool == false)
        let messages = body["messages"] as? [[String: String]]
        #expect(messages?.count == 2)
        #expect(messages?.first?["role"] == "system")
        #expect(messages?.first?["content"] == "be terse")
        #expect(messages?.last?["role"] == "user")
        #expect(messages?.last?["content"] == "hi")
    }

    @Test func makeBodyOmitsSystemWhenNilOrEmpty() {
        for sys in [nil, ""] as [String?] {
            let body = GrokClient.makeBody(model: "grok-4", prompt: "hi", system: sys, stream: true)
            let messages = body["messages"] as? [[String: String]]
            #expect(messages?.count == 1, "empty/nil system must not add a system message")
            #expect(messages?.first?["role"] == "user")
            #expect(body["stream"] as? Bool == true)
        }
    }

    @Test func extractContentReturnsTrimmedText() {
        let json = #"{"choices":[{"message":{"content":"  hello  "}}]}"#.data(using: .utf8)!
        #expect(GrokClient.extractContent(json) == "hello")
    }

    @Test func extractContentReturnsEmptyForEmptyContent() {
        // Empty (or whitespace-only) content trims to "" — the caller treats
        // "" as nil, but the parser's job is just to extract+trim.
        let json = #"{"choices":[{"message":{"content":"   "}}]}"#.data(using: .utf8)!
        #expect(GrokClient.extractContent(json) == "")
    }

    @Test func extractContentReturnsNilForMalformed() {
        for bad in [
            #"{"choices":[]}"#,                                  // no first choice
            #"{"choices":[{"message":{}}]}"#,                    // no content
            #"{"nonsense":true}"#,                               // wrong shape
            #"not json at all"#,
        ] {
            #expect(GrokClient.extractContent(bad.data(using: .utf8)!) == nil,
                    "malformed `\(bad)` should yield nil")
        }
    }

    @Test func decodeDeltaPreservesContentVerbatim_noTrim() {
        // CRITICAL: streamed deltas must NOT be trimmed. If they were, the
        // space in " world" would be stripped and "hello"+" world" would
        // render as "helloworld". This test exists to make a future
        // "let's trim the delta" change fail loudly.
        let delta = #"{"choices":[{"delta":{"content":" world"}}]}"#
        #expect(GrokClient.decodeDelta(delta) == " world")

        let trailing = #"{"choices":[{"delta":{"content":"hello "}}]}"#
        #expect(GrokClient.decodeDelta(trailing) == "hello ")
    }

    @Test func decodeDeltaReturnsNilForMissingDelta() {
        #expect(GrokClient.decodeDelta(#"{"choices":[{}]}"#) == nil)
        #expect(GrokClient.decodeDelta("garbage") == nil)
    }
}

// MARK: - OpenAI-compatible request body + parsers (Groq / Mistral / Cerebras / OpenAI)
//
// Shared by four providers — one regression here breaks all of them. We drive
// the static functions directly (they don't depend on an instance).

struct OpenAICompatibleParsingTests {

    @Test func makeBodyShapeMatchesOpenAISpec() {
        let body = OpenAICompatibleClient.makeBody(model: "llama-3.1-70b-versatile",
                                                   prompt: "hi", system: "sys", stream: true)
        #expect(body["model"] as? String == "llama-3.1-70b-versatile")
        #expect(body["stream"] as? Bool == true)
        let messages = body["messages"] as? [[String: String]]
        #expect(messages?.count == 2)
        #expect(messages?.first?["role"] == "system")
        #expect(messages?.last?["content"] == "hi")
    }

    @Test func makeBodyOmitsEmptySystem() {
        let body = OpenAICompatibleClient.makeBody(model: "m", prompt: "hi", system: "", stream: false)
        #expect((body["messages"] as? [[String: String]])?.count == 1)
    }

    @Test func extractContentTrims() {
        let json = #"{"choices":[{"message":{"content":"\n  hi \n"}}]}"#.data(using: .utf8)!
        #expect(OpenAICompatibleClient.extractContent(json) == "hi")
    }

    @Test func extractContentNilForMalformed() {
        #expect(OpenAICompatibleClient.extractContent(#"{}"#.data(using: .utf8)!) == nil)
    }

    @Test func decodeDeltaPreservesSpaces_noTrim() {
        #expect(OpenAICompatibleClient.decodeDelta(#"{"choices":[{"delta":{"content":" tok"}}]}"#) == " tok")
        #expect(OpenAICompatibleClient.decodeDelta(#"{"choices":[{"delta":{"content":""}}]}"#) == "")
        #expect(OpenAICompatibleClient.decodeDelta(#"{"choices":[{"delta":{}}]}"#) == nil)
    }

    // The local-server brains (vLLM / Unsloth Studio) take a hand-typed base
    // URL. A trailing slash used to produce `…/v1//chat/completions`, which
    // strict routers 404. The builder must collapse trailing slashes.
    @Test func chatCompletionsURLToleratesTrailingSlash() {
        let want = "http://localhost:8000/v1/chat/completions"
        #expect(OpenAICompatibleClient.chatCompletionsURL("http://localhost:8000/v1")?.absoluteString == want)
        #expect(OpenAICompatibleClient.chatCompletionsURL("http://localhost:8000/v1/")?.absoluteString == want)
        #expect(OpenAICompatibleClient.chatCompletionsURL("http://localhost:8000/v1///")?.absoluteString == want)
        // Surrounding whitespace (easy to paste) is trimmed too.
        #expect(OpenAICompatibleClient.chatCompletionsURL("  http://localhost:8000/v1  ")?.absoluteString == want)
    }

    // `chat()` returns a non-nil "[<name> error STATUS: …]" string for any
    // non-200, so `testConnection` must treat that as failure — otherwise the
    // Settings "Test" button goes green on a bad key / wrong URL.
    @Test func isErrorReplyDetectsFailuresButNotRealText() {
        #expect(OpenAICompatibleClient.isErrorReply(nil, displayName: "vLLM"))                       // transport failure
        #expect(OpenAICompatibleClient.isErrorReply("[vLLM error 401: bad key]", displayName: "vLLM"))
        #expect(OpenAICompatibleClient.isErrorReply("[vLLM request failed (HTTP 404).]", displayName: "vLLM"))
        // A genuine reply (even one mentioning another brain's name) is success.
        #expect(!OpenAICompatibleClient.isErrorReply("pong", displayName: "vLLM"))
        #expect(!OpenAICompatibleClient.isErrorReply("[Groq error 401: …]", displayName: "vLLM")) // name must match
    }
}

// MARK: - OpenAI-compatible tool-call parsing (run-the-terminal path)
//
// `parseToolResponse` is what lets ANY OpenAI-compatible brain (Groq, Mistral,
// Cerebras, OpenRouter, OpenAI, Unsloth Studio, vLLM) actually run terminal
// commands: it pulls the model's requested function calls out of a
// `/chat/completions` response. A wrong shape here means the brain "describes"
// a command but never runs it — the exact bug this feature fixes. Pure (no
// network), so cheap to lock down.

struct OpenAICompatibleToolCallParsingTests {

    @Test func parsesArgumentsAsJSONString_realOpenAIShape() {
        // Real OpenAI sends `function.arguments` as a JSON *string*.
        let json = #"""
        {"choices":[{"message":{"content":null,"tool_calls":[
          {"id":"call_abc","type":"function",
           "function":{"name":"run_terminal_command","arguments":"{\"command\":\"ls -la ~\"}"}}
        ]}}]}
        """#.data(using: .utf8)!
        let dict = try! JSONSerialization.jsonObject(with: json) as! [String: Any]
        let parsed = OpenAICompatibleClient.parseToolResponse(dict)
        #expect(parsed?.text == "")                       // null content → ""
        #expect(parsed?.toolCalls.count == 1)
        #expect(parsed?.toolCalls.first?.id == "call_abc")
        #expect(parsed?.toolCalls.first?.name == "run_terminal_command")
        #expect(parsed?.toolCalls.first?.arguments["command"] == "ls -la ~")
    }

    @Test func parsesArgumentsAsRawObject_compatServerShape() {
        // Some OpenAI-compatible servers send `arguments` as a raw object.
        let json = #"""
        {"choices":[{"message":{"content":"","tool_calls":[
          {"id":"c1","function":{"name":"web_search","arguments":{"query":"swift 6"}}}
        ]}}]}
        """#.data(using: .utf8)!
        let dict = try! JSONSerialization.jsonObject(with: json) as! [String: Any]
        let parsed = OpenAICompatibleClient.parseToolResponse(dict)
        #expect(parsed?.toolCalls.first?.name == "web_search")
        #expect(parsed?.toolCalls.first?.arguments["query"] == "swift 6")
    }

    @Test func synthesizesIdWhenServerOmitsIt() {
        // Missing `id` must not drop the call — we synthesize a stable fallback
        // so the matching `tool` result message can still reference it.
        let json = #"""
        {"choices":[{"message":{"tool_calls":[
          {"function":{"name":"run_terminal_command","arguments":"{\"command\":\"pwd\"}"}}
        ]}}]}
        """#.data(using: .utf8)!
        let dict = try! JSONSerialization.jsonObject(with: json) as! [String: Any]
        let parsed = OpenAICompatibleClient.parseToolResponse(dict)
        #expect(parsed?.toolCalls.first?.id == "call_0")
        #expect(parsed?.toolCalls.first?.arguments["command"] == "pwd")
    }

    @Test func plainAnswerHasNoToolCalls() {
        let json = #"{"choices":[{"message":{"content":"  just text  "}}]}"#.data(using: .utf8)!
        let dict = try! JSONSerialization.jsonObject(with: json) as! [String: Any]
        let parsed = OpenAICompatibleClient.parseToolResponse(dict)
        #expect(parsed?.text == "just text")              // trimmed
        #expect(parsed?.toolCalls.isEmpty == true)
    }

    @Test func nilForMalformedResponse() {
        for bad in [#"{"choices":[]}"#, #"{}"#, #"garbage"#] {
            let obj = (try? JSONSerialization.jsonObject(with: bad.data(using: .utf8)!)) as? [String: Any]
            // A non-object body ("garbage") isn't a dict at all; the others are
            // dicts that fail the choices/message guard → nil.
            if let obj { #expect(OpenAICompatibleClient.parseToolResponse(obj) == nil, "`\(bad)` should yield nil") }
        }
    }
}

// MARK: - Gemini request body + parsers (Google's non-OpenAI shape)

struct GeminiParsingTests {

    @Test func makeBodyUsesContentsArrayWithUserRole() {
        let body = GeminiClient.makeBody(prompt: "hi", system: nil)
        let contents = body["contents"] as? [[String: Any]]
        #expect(contents?.count == 1)
        #expect(contents?.first?["role"] as? String == "user")
        let parts = contents?.first?["parts"] as? [[String: String]]
        #expect(parts?.first?["text"] == "hi")
        // No systemInstruction when system is nil.
        #expect(body["systemInstruction"] == nil)
    }

    @Test func makeBodyNestsSystemInstructionWhenProvided() {
        let body = GeminiClient.makeBody(prompt: "hi", system: "be terse")
        let sys = body["systemInstruction"] as? [String: Any]
        let parts = sys?["parts"] as? [[String: String]]
        #expect(parts?.first?["text"] == "be terse")
    }

    @Test func makeBodyOmitsEmptySystemInstruction() {
        let body = GeminiClient.makeBody(prompt: "hi", system: "")
        #expect(body["systemInstruction"] == nil)
    }

    @Test func extractContentReadsCandidatesPartsText() {
        let json = #"{"candidates":[{"content":{"parts":[{"text":"hello"}]}}]}"#.data(using: .utf8)!
        #expect(GeminiClient.extractContent(json) == "hello")
    }

    @Test func extractContentConcatenatesMultipleParts() {
        // Gemini can return multiple parts; we join them in order.
        let json = #"{"candidates":[{"content":{"parts":[{"text":"foo"},{"text":"bar"}]}}]}"#.data(using: .utf8)!
        #expect(GeminiClient.extractContent(json) == "foobar")
    }

    @Test func extractContentNilForMalformed() {
        #expect(GeminiClient.extractContent(#"{"candidates":[]}"#.data(using: .utf8)!) == nil)
        #expect(GeminiClient.extractContent(#"garbage"#.data(using: .utf8)!) == nil)
    }

    @Test func streamingDeltaDelegatesToExtractContent() {
        let chunk = #"{"candidates":[{"content":{"parts":[{"text":"chunk"}]}}]}"#
        #expect(GeminiClient.extractStreamingDelta(chunk) == "chunk")
        #expect(GeminiClient.extractStreamingDelta("not json") == nil)
    }
}
