import Testing
import Foundation
@testable import Salehman_AI

// MARK: - LocalLLM.cloudSystemPrompt
//
// `cloudSystemPrompt` is the shared `system` message every cloud brain's
// single-turn `chat()` ships with: Claude, Grok, Gemini, Groq, Mistral,
// Cerebras, OpenAI, GitHub Copilot — eight providers, one prompt. That
// makes it the single highest-leverage string in the codebase: editing
// it changes the behaviour of every cloud chat reply at once, and a
// well-meaning "let me improve the wording" edit can silently regress
// the constraints in ways that are hard to spot from a single chat
// session against a single brain.
//
// These tests pin the *semantic constraints* (what the prompt must
// convey) without pinning the exact wording (which can evolve). If a
// future edit strips a constraint by accident, the relevant test trips.

struct CloudSystemPromptTests {

    private var prompt: String { LocalLLM.cloudSystemPrompt }

    @Test func isNonEmpty() {
        // The most basic regression: someone deletes the body of the
        // string. Empty system prompts make most cloud models default
        // to their vendor persona, which is the wrong behaviour for
        // *every* call site.
        #expect(!prompt.isEmpty)
        #expect(prompt.count > 40, "cloudSystemPrompt collapsed to \(prompt.count) chars — likely a regression")
    }

    @Test func identifiesTheAssistantAsSalehmanAI() {
        // Without an identity claim the brain can drift to "I am Claude"
        // / "I am Grok" / etc., breaking the user's mental model of who
        // they're talking to.
        #expect(prompt.contains("Salehman AI"))
    }

    @Test func declaresNoLocalToolAccess() {
        // Critical constraint: when the user pins a cloud brain, the
        // brain CANNOT call run_terminal_command / self_improve / etc.
        // (those are Apple Intelligence FoundationModels tools only).
        // The prompt must say so, otherwise the model promises actions
        // it can't perform.
        let lowered = prompt.lowercased()
        let mentionsAbsenceOfTools =
            lowered.contains("no access") ||
            lowered.contains("don't have access") ||
            lowered.contains("cannot call") ||
            lowered.contains("can't call") ||
            lowered.contains("no local tools") ||
            lowered.contains("local tools")
        #expect(mentionsAbsenceOfTools,
                "cloudSystemPrompt no longer explains tool unavailability — model will promise terminal access it doesn't have")
    }

    @Test func directsTheModelToSuggestCommandsAsText() {
        // When a user asks "what version of macOS am I running" the
        // cloud brain can't run `sw_vers` — the prompt must tell it to
        // suggest the command in text instead of pretending to run it.
        let lowered = prompt.lowercased()
        #expect(lowered.contains("suggest") || lowered.contains("command"),
                "cloudSystemPrompt no longer instructs the model to *suggest* commands when it can't run them")
    }

    @Test func declaresLanguageMirror() {
        // Arabic users expect Arabic replies. The prompt encodes this
        // by mentioning both languages explicitly. Removing the
        // mention reintroduces English-only replies for Arabic input.
        let lowered = prompt.lowercased()
        #expect(lowered.contains("arabic"))
        #expect(lowered.contains("english"))
    }

    @Test func isASingleParagraphWithNoTemplatingArtifacts() {
        // No `{{placeholder}}` syntax, no `%@`, no `\(variable)` — the
        // prompt is a fixed string. If any of those slip in via a
        // careless refactor, the cloud brain receives literal junk.
        #expect(!prompt.contains("{{"))
        #expect(!prompt.contains("}}"))
        #expect(!prompt.contains("%@"))
        // The line-continuation `\` is fine inside a Swift multi-line
        // string literal — it's stripped before reaching the wire.
        // But if a leftover `\n` or unescaped `\` reaches the JSON
        // body, it'd break the request. Verify the run-time string
        // doesn't contain raw backslashes:
        #expect(!prompt.contains("\\"))
    }
}
