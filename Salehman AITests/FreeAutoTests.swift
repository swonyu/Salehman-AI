import Testing
import Foundation
@testable import Salehman_AI

// MARK: - LocalLLM.isUsableFreeAnswer
//
// `generateFreeAuto` races every configured free brain in parallel and returns
// the first reply that survives `isUsableFreeAnswer`. That filter is therefore
// the linchpin of the whole feature — if it accepts an error string, a brain
// that 429s instantly "wins" the race and the user sees the error as their
// answer instead of waiting for a healthy sibling. These tests pin the contract
// so a refactor of the filter (or of the cloud clients' error-string format)
// can't silently break the "never blocked" guarantee.

struct FreeAutoAnswerFilterTests {

    // MARK: rejections

    @Test func rejectsEmptyString() {
        #expect(!LocalLLM.isUsableFreeAnswer(""))
    }

    @Test func rejectsWhitespaceOnly() {
        #expect(!LocalLLM.isUsableFreeAnswer("   \n\t  "))
    }

    @Test func rejectsRateLimitError() {
        // Format produced by `OpenAICompatibleClient` for non-2xx — see the
        // `errorText` path. Groq / Cerebras / Mistral / OpenAI / OpenRouter all
        // share this shape, so one rejection covers all of them.
        #expect(!LocalLLM.isUsableFreeAnswer("[Groq error 429: rate limit exceeded]"))
        #expect(!LocalLLM.isUsableFreeAnswer("[OpenRouter error 429: Provider returned error]"))
        #expect(!LocalLLM.isUsableFreeAnswer("[Cerebras error 404: model not found]"))
    }

    @Test func rejectsGeminiErrorFormat() {
        // Gemini's client uses its own non-OpenAI shape. Worth pinning its
        // error string explicitly because if the format ever drifts the
        // filter would silently start accepting it.
        #expect(!LocalLLM.isUsableFreeAnswer("[Gemini error 400: API key not valid]"))
    }

    @Test func rejectsTransportFailureFormat() {
        // REGRESSION GUARD (2026-06-05): the OTHER error shape — "[X request
        // failed (HTTP NNN). …]" — contains NO "error" keyword. The original
        // filter only matched "error", so this form (e.g. Mistral on a 401)
        // slipped through, WON the race, and was shown to the user as the
        // answer. Pin every real client failure format.
        #expect(!LocalLLM.isUsableFreeAnswer("[Mistral request failed (HTTP 401). Check the key + your network.]"))
        #expect(!LocalLLM.isUsableFreeAnswer("[Grok request failed (HTTP 500). Check Settings → Brain → xAI Grok.]"))
        #expect(!LocalLLM.isUsableFreeAnswer("[Gemini request failed (HTTP 403). Check Settings → Brain → Google Gemini.]"))
        #expect(!LocalLLM.isUsableFreeAnswer("[The on-device model couldn't complete that request: timeout]"))
    }

    @Test func errorDetectionIsCaseInsensitive() {
        // `[Provider Error ...]` and `[Provider ERROR ...]` must also lose.
        #expect(!LocalLLM.isUsableFreeAnswer("[Groq Error 500: internal]"))
        #expect(!LocalLLM.isUsableFreeAnswer("[Groq ERROR 503: upstream]"))
    }

    // MARK: acceptances

    @Test func acceptsRealAnswer() {
        // The kind of thing Groq actually replied with during live testing.
        #expect(LocalLLM.isUsableFreeAnswer("Hi, how can I assist you today?"))
    }

    @Test func acceptsMultilineMarkdown() {
        #expect(LocalLLM.isUsableFreeAnswer("Sure — here's how:\n\n1. Step one\n2. Step two"))
    }

    @Test func acceptsAnswerThatMentionsErrorWordWithoutBracketPrefix() {
        // A real prose answer can mention "error" without being one. The filter
        // requires BOTH the leading `[` AND the word "error" — neither alone
        // disqualifies a reply.
        #expect(LocalLLM.isUsableFreeAnswer("If you hit a 429 error, the next brain takes over."))
    }

    @Test func acceptsBracketPrefixWithoutErrorKeyword() {
        // An answer can start with `[` (e.g. a markdown link, a code snippet,
        // a list) — only the combination with "error" disqualifies.
        #expect(LocalLLM.isUsableFreeAnswer("[See the docs](https://example.com) for details."))
    }
}

// MARK: - BrainPreference.freeAuto surface
//
// Same regression-guard pattern as `EnsembleRoutingTests` and
// `OpenRouterPreferenceTests`: pin the predicate that the four routing
// branches in `generate / generateStreaming / chat` and the top of
// `AgentPipeline.run` all hinge on. Network-free; runs in milliseconds.

struct FreeAutoRoutingTests {

    @Test func isFreeAutoModeTracksThePreference() {
        // Cross-suite serialization — see BrainPreferenceTestLock.swift.
        BrainPreferenceTestLock.lock.lock()
        defer { BrainPreferenceTestLock.lock.unlock() }

        let key = AppSettings.Keys.brainPreference
        let prior = UserDefaults.standard.string(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else         { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.set(BrainPreference.freeAuto.rawValue, forKey: key)
        #expect(LocalLLM.isFreeAutoMode)
        UserDefaults.standard.set(BrainPreference.auto.rawValue, forKey: key)
        #expect(!LocalLLM.isFreeAutoMode)
    }

    @Test func freeAutoIsListedAndStable() {
        // Renaming the rawValue silently breaks every persisted user preference.
        #expect(BrainPreference.allCases.contains(.freeAuto))
        #expect(BrainPreference.freeAuto.rawValue == "freeAuto")
        #expect(!BrainPreference.freeAuto.title.isEmpty)
        #expect(!BrainPreference.freeAuto.subtitle.isEmpty)
        #expect(!BrainPreference.freeAuto.icon.isEmpty)
    }
}
