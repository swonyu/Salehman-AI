import Testing
import Foundation
@testable import Salehman_AI

// MARK: - LocalLLM.formatEnsemble
//
// The ensemble fan-out itself (generateEnsemble) hits live brains, so it's not
// a pure unit test. But the *formatter* — which turns per-brain answers into the
// combined markdown the user sees — is pure and worth pinning: it must label
// every brain, render missing replies honestly (not silently drop them), and
// count "answered" correctly.

struct EnsembleFormatTests {

    private func ans(_ label: String, _ text: String?) -> LocalLLM.EnsembleAnswer {
        LocalLLM.EnsembleAnswer(label: label, text: text)
    }

    @Test func eachBrainGetsItsOwnLabeledSection() {
        let out = LocalLLM.formatEnsemble([
            ans("Apple Intelligence", "Hi from Apple."),
            ans("xAI grok-build-0.1", "Hi from Grok."),
        ])
        #expect(out.contains("### Apple Intelligence"))
        #expect(out.contains("Hi from Apple."))
        #expect(out.contains("### xAI grok-build-0.1"))
        #expect(out.contains("Hi from Grok."))
    }

    @Test func missingReplyIsShownNotDropped() {
        // A nil/empty reply must render as a visible "(no response)" — never be
        // silently omitted, or the user can't tell a brain failed vs wasn't run.
        let out = LocalLLM.formatEnsemble([
            ans("Apple Intelligence", "ok"),
            ans("Claude Haiku", nil),
            ans("Groq", ""),
        ])
        #expect(out.contains("### Claude Haiku"))
        #expect(out.contains("### Groq"))
        #expect(out.contains("_(no response)_"))
    }

    @Test func answeredCountReflectsNonEmptyReplies() {
        // 2 of 3 produced text.
        let out = LocalLLM.formatEnsemble([
            ans("A", "x"), ans("B", nil), ans("C", "y"),
        ])
        #expect(out.contains("2/3 answered"))
    }

    @Test func errorStringsCountAsAnsweredAndAreShownVerbatim() {
        // Cloud clients return a `[Provider error …]` string for HTTP errors;
        // that IS a (non-empty) response and must surface verbatim so the user
        // sees the real failure alongside the brains that worked.
        let out = LocalLLM.formatEnsemble([
            ans("xAI grok-build-0.1", "[Grok error 404: model not found]"),
            ans("Apple Intelligence", "real answer"),
        ])
        #expect(out.contains("[Grok error 404: model not found]"))
        #expect(out.contains("2/2 answered"))   // an error string still counts as "responded"
    }

    @Test func headerPresentEvenForSingleBrain() {
        let out = LocalLLM.formatEnsemble([ans("Apple Intelligence", "hello")])
        #expect(out.contains("All brains"))
        #expect(out.contains("1/1 answered"))
    }
}

// MARK: - BrainPreference.ensemble surface

struct EnsemblePreferenceTests {
    @Test func ensembleIsListedAndStable() {
        #expect(BrainPreference.allCases.contains(.ensemble))
        #expect(BrainPreference.ensemble.rawValue == "ensemble")
        #expect(!BrainPreference.ensemble.title.isEmpty)
        #expect(!BrainPreference.ensemble.subtitle.isEmpty)
        #expect(!BrainPreference.ensemble.icon.isEmpty)
    }
}

// MARK: - Ensemble routing predicate
//
// Regression guard for the "Is All Brains at Once working? → Not working" false
// negative: ensemble used to be wired ONLY in AgentPipeline, so direct callers
// (the Settings probe, StockSage, title-gen) hit `LocalLLM.generate/chat`, fell
// through every single-brain gate, and got `offMessage`. The fix makes ensemble
// a first-class branch in those methods, gated on `isEnsembleMode`. These tests
// pin that predicate (network-free) so the branches can't silently break.

struct EnsembleRoutingTests {

    // NOTE: the `isEnsembleMode`-via-UserDefaults predicate test used to live here,
    // but `FreeAutoRoutingTests.isFreeAutoModeTracksThePreference` mutates the SAME
    // global `Keys.brainPreference` key, and Swift Testing runs tests in parallel —
    // two writers of one global race each other and flake. The freeAuto suite keeps
    // that single mutator (race-free as the sole writer); the `isEnsembleMode`
    // predicate (`pref == .ensemble`) is trivial and already enforced by the build's
    // exhaustive switches + `EnsemblePreferenceTests`. Don't re-add a brainPreference
    // mutator here without serializing it against the freeAuto one.

    @Test func realEnsembleAnswerNeverCollidesWithOffSentinel() {
        // The Settings/streaming layers detect "no brain" via `reply == offMessage`.
        // A formatted ensemble answer (≥1 brain responded) must never equal that
        // sentinel, or a working ensemble would be misread as off.
        let out = LocalLLM.formatEnsemble([
            LocalLLM.EnsembleAnswer(label: "Apple Intelligence", text: "hello"),
        ])
        #expect(out != LocalLLM.offMessage)
    }
}
