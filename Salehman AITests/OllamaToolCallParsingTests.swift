import Testing
import Foundation
@testable import Salehman_AI

// Pins the behavior of `OllamaClient.parseChatResponse` — the parser that turns
// an Ollama `/api/chat` response into our `(text, [ToolCall])` tuple. This is
// the gnarly part of the Ollama tool-calling loop (terminal/web tools on the
// local brain), and it has to handle BOTH shapes Ollama emits for tool-call
// arguments: an object (recent versions) and a JSON-encoded string (older).
// Without coverage, a future Ollama upgrade could silently break tool execution.
struct OllamaToolCallParsingTests {

    @Test func returnsNilWhenNoMessage() {
        let json: [String: Any] = ["error": "model not loaded"]
        #expect(OllamaClient.parseChatResponse(json) == nil)
    }

    @Test func textOnlyResponseHasNoToolCalls() {
        let json: [String: Any] = ["message": ["content": "  hello world  "]]
        let parsed = OllamaClient.parseChatResponse(json)
        #expect(parsed?.text == "hello world")        // trimmed
        #expect(parsed?.toolCalls.isEmpty == true)
    }

    /// Recent Ollama: `arguments` is a JSON object.
    @Test func parsesObjectArguments() {
        let json: [String: Any] = [
            "message": [
                "content": "",
                "tool_calls": [
                    ["function": [
                        "name": "run_terminal_command",
                        "arguments": ["command": "ls -la ~/Downloads"],
                    ]]
                ],
            ]
        ]
        let parsed = OllamaClient.parseChatResponse(json)
        #expect(parsed?.toolCalls.count == 1)
        #expect(parsed?.toolCalls.first?.name == "run_terminal_command")
        #expect(parsed?.toolCalls.first?.arguments["command"] == "ls -la ~/Downloads")
    }

    /// Older Ollama: `arguments` is a JSON-encoded *string* — we must decode it
    /// or the tool call silently runs with empty args.
    @Test func parsesStringArgumentsFromOlderOllama() {
        let json: [String: Any] = [
            "message": [
                "content": "",
                "tool_calls": [
                    ["function": [
                        "name": "web_search",
                        "arguments": "{\"query\":\"swift 6 isolation\"}",
                    ]]
                ],
            ]
        ]
        let parsed = OllamaClient.parseChatResponse(json)
        #expect(parsed?.toolCalls.count == 1)
        #expect(parsed?.toolCalls.first?.name == "web_search")
        #expect(parsed?.toolCalls.first?.arguments["query"] == "swift 6 isolation")
    }

    /// A malformed call (missing `name`) is skipped — the rest of the batch
    /// still executes. Defends against a single bad entry killing the round.
    @Test func malformedToolCallIsSkippedRestStillRuns() {
        let json: [String: Any] = [
            "message": [
                "content": "",
                "tool_calls": [
                    ["function": ["arguments": ["x": 1]]],                       // no name
                    ["function": ["name": "fetch_url",
                                  "arguments": ["url": "https://example.com"]]],
                ],
            ]
        ]
        let parsed = OllamaClient.parseChatResponse(json)
        #expect(parsed?.toolCalls.count == 1)
        #expect(parsed?.toolCalls.first?.name == "fetch_url")
        #expect(parsed?.toolCalls.first?.arguments["url"] == "https://example.com")
    }
}
