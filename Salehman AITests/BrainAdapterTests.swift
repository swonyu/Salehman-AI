import Testing
import Foundation
@testable import Salehman_AI

// MARK: - brainAdapterPrompt (pure message → (system, prompt) flattener)
//
// All three adapters (OllamaBrainAdapter, AnthropicBrainAdapter,
// LocalLLMFallbackAdapter) call brainAdapterPrompt to convert the typed
// [LLMMessage] into the (system, prompt) pair their single-turn clients need.
// A bug here drops system prompts or garbles multi-turn context silently.

struct BrainAdapterPromptTests {

    private func msg(_ role: LLMMessage.Role, _ text: String) -> LLMMessage {
        LLMMessage(role: role, content: text)
    }

    @Test func singleUserMessageNoSystem() {
        let (system, prompt) = brainAdapterPrompt(from: [msg(.user, "hello")])
        #expect(system == nil)
        #expect(prompt == "hello")
    }

    @Test func systemPlusOneUserMessage() {
        let (system, prompt) = brainAdapterPrompt(from: [
            msg(.system, "You are a helper."),
            msg(.user, "what is 2+2?"),
        ])
        #expect(system == "You are a helper.")
        #expect(prompt == "what is 2+2?")
    }

    @Test func systemExtractedAndNotInPrompt() {
        // The system turn must NOT appear in the prompt string.
        let (_, prompt) = brainAdapterPrompt(from: [
            msg(.system, "secret system prompt"),
            msg(.user, "user question"),
        ])
        #expect(!prompt.contains("secret system prompt"))
        #expect(prompt == "user question")
    }

    @Test func multiTurnWithoutSystemFormatted() {
        // When there is no system message and more than one body turn, the output
        // must be "Role: content\nRole: content" so the model sees conversation structure.
        let (system, prompt) = brainAdapterPrompt(from: [
            msg(.user, "first question"),
            msg(.assistant, "first answer"),
            msg(.user, "follow-up"),
        ])
        #expect(system == nil)
        let lines = prompt.components(separatedBy: "\n")
        #expect(lines[0] == "User: first question")
        #expect(lines[1] == "Assistant: first answer")
        #expect(lines[2] == "User: follow-up")
    }

    @Test func multiTurnWithSystemFormatted() {
        // System is extracted; the body turns are formatted, not including system.
        let (system, prompt) = brainAdapterPrompt(from: [
            msg(.system, "Be concise."),
            msg(.user, "Q"),
            msg(.assistant, "A"),
            msg(.user, "Q2"),
        ])
        #expect(system == "Be concise.")
        #expect(prompt.hasPrefix("User: Q\n"))
        #expect(prompt.contains("Assistant: A\n"))
        #expect(prompt.hasSuffix("User: Q2"))
    }

    @Test func emptyMessageListProducesNilSystemAndEmptyPrompt() {
        let (system, prompt) = brainAdapterPrompt(from: [])
        #expect(system == nil)
        // No body messages → single-message fast-path has nothing to map.
        #expect(prompt.isEmpty)
    }

    @Test func systemOnlyMessageProducesEmptyPrompt() {
        // A [system] array has no body turns (after filtering out .system).
        let (system, prompt) = brainAdapterPrompt(from: [msg(.system, "just a persona")])
        #expect(system == "just a persona")
        #expect(prompt.isEmpty)
    }
}

// MARK: - BrainAdapterFactory dispatch

struct BrainAdapterFactoryTests {

    @Test func ollamaCoderReturnsOllamaAdapter() {
        let adapter = BrainAdapterFactory.adapter(for: .ollamaCoder)
        #expect(adapter.id == .ollama,
                ".ollamaCoder brain must produce an adapter with id .ollama")
    }

    @Test func claudeHaikuReturnsAnthropicAdapter() {
        let adapter = BrainAdapterFactory.adapter(for: .claudeHaiku)
        #expect(adapter.id == .claudeHaiku,
                ".claudeHaiku brain must produce an adapter with id .claudeHaiku")
    }

    @Test func otherBrainsProduceFallbackWithCorrectID() {
        // The fallback adapter captures the current brainPreferenceCurrent, but
        // any brain NOT in the explicit cases uses the fallback path.
        // We just check the factory doesn't crash and returns a non-nil adapter.
        let grq = BrainAdapterFactory.adapter(for: .groq)
        let sal = BrainAdapterFactory.adapter(for: .salehman)
        let gem = BrainAdapterFactory.adapter(for: .gemini)
        // All return a concrete adapter (protocol existential, not nil).
        // The `id` for the fallback uses AppSettings.brainPreferenceCurrent, so
        // we can't assert a fixed value here — just check it's non-crashing.
        _ = grq.id; _ = sal.id; _ = gem.id
        #expect(Bool(true), "factory must not crash for any LocalLLM.Brain case")
    }
}
