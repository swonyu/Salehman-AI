import Testing
import Foundation
@testable import Salehman_AI

// MARK: - SalehmanPersona — identity + language + safety invariants
//
// `SalehmanPersona.systemPrompt` is the "brand layer" sent to every engine —
// cloud and local. Subtle edits can break core invariants:
//   • Mentioning a provider name ("DeepSeek", "Groq") breaks identity privacy.
//   • Removing the language-mirror rule causes English-only responses to Arabic.
//   • Losing the no-meta-narration directive causes the model to preface answers
//     with reasoning scaffolding ("How should I respond: …").
// These tests trip immediately on any such regression, before it ships.

struct SalehmanPersonaContentTests {

    private let prompt = SalehmanPersona.systemPrompt

    @Test func promptIsNonTrivial() {
        // Guard against accidental deletion or replacement with a stub.
        #expect(prompt.count > 500,
                "systemPrompt collapsed to \(prompt.count) chars — likely a regression")
    }

    @Test func identifiesAsSalehmanCreatedBySaleh() {
        #expect(prompt.contains("Salehman AI"),
                "identity must name 'Salehman AI'")
        #expect(prompt.contains("Saleh"),
                "identity must credit the creator")
    }

    @Test func containsProviderNegationInstruction() {
        // The persona must include a NEVER/do-not-say instruction that names
        // providers as examples. The names appear IN the instruction as a list
        // of what not to say — not as endorsed identities. The key check is
        // that the negation instruction is present and includes the key names.
        #expect(prompt.contains("NEVER name") || prompt.contains("Do not say"),
                "must have a NEVER/do-not-say instruction about provider names")
        // Key providers that must be listed in the negation instruction:
        let listed = ["Groq", "Cerebras", "OpenRouter"]
        for name in listed {
            #expect(prompt.contains(name),
                    "'\(name)' must appear in the do-not-say list so the model knows to suppress it")
        }
    }

    @Test func containsLanguageMirrorRule() {
        // Absence of this rule causes the model to answer in a fixed language
        // (often Arabic given the Mac's locale) regardless of what the user typed.
        #expect(prompt.contains("SAME language") || prompt.contains("same language"),
                "language-mirror rule must be present")
    }

    @Test func containsNoMetaNarrationDirective() {
        // Without this directive, reasoning models prepend "How should I respond"
        // or "Response:" scaffolding that the user sees verbatim.
        #expect(prompt.lowercased().contains("meta-narration") || prompt.lowercased().contains("narration"),
                "no-meta-narration directive must be present")
    }

    @Test func doesNotContainTemplatePlaceholders() {
        // Unfilled placeholders (left by an improperly migrated template) would
        // ship as literal text inside the system prompt.
        #expect(!prompt.contains("{{"),  "Handlebars placeholder found in systemPrompt")
        #expect(!prompt.contains("%@"),  "Objective-C format specifier found in systemPrompt")
        #expect(!prompt.contains("\\("), "Swift interpolation leak found in systemPrompt")
    }

    @Test func promptEndsWithMeaningfulContent() {
        // Guard against truncation — the final reminder line must be present.
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.hasSuffix("show them why.") || trimmed.hasSuffix("show them why"),
                "systemPrompt must end with the final reminder — possible truncation")
    }
}

// MARK: - activeSystemPrompt — unrestricted-mode wiring

struct ActiveSystemPromptTests {

    private func withUnrestricted(_ enabled: Bool, _ body: () -> Void) {
        let key = AppSettings.Keys.unrestrictedTools
        let prior = UserDefaults.standard.object(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else         { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.set(enabled, forKey: key)
        body()
    }

    @Test func equalsBaseWhenUnrestrictedOff() {
        // Normal mode: activeSystemPrompt must be identical to systemPrompt.
        withUnrestricted(false) {
            #expect(SalehmanPersona.activeSystemPrompt == SalehmanPersona.systemPrompt,
                    "normal mode must pass systemPrompt through unchanged")
        }
    }

    @Test func prependsBaseWhenUnrestrictedOn() {
        // Unrestricted mode: the addendum is appended after a newline.
        withUnrestricted(true) {
            let active = SalehmanPersona.activeSystemPrompt
            #expect(active.hasPrefix(SalehmanPersona.systemPrompt),
                    "unrestricted prompt must START with the base systemPrompt")
            #expect(active.count > SalehmanPersona.systemPrompt.count,
                    "unrestricted prompt must be LONGER than base (addendum was appended)")
        }
    }

    @Test func isComputedNotCached() {
        // `activeSystemPrompt` is a computed var. Toggling unrestricted mode
        // between two reads must change the value without an app restart.
        withUnrestricted(false) {
            let off = SalehmanPersona.activeSystemPrompt
            UserDefaults.standard.set(true, forKey: AppSettings.Keys.unrestrictedTools)
            let on = SalehmanPersona.activeSystemPrompt
            #expect(off != on, "activeSystemPrompt must re-evaluate on each access")
        }
    }
}
