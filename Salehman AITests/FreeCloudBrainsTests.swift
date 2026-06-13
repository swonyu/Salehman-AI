import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Default model IDs
//
// Same guard pattern as `GrokModelIDTests`: if a typo or rename slips into
// any client's `defaultModel`, the runtime call to that provider silently
// 404s and looks like a network bug. Pinning each ID here trips CI before a
// user notices.

struct GeminiModelIDTests {
    @Test func defaultModelIsFlash() {
        // Free tier's headline model in Google AI Studio.
        #expect(GeminiClient.defaultModel == "gemini-2.0-flash")
    }
    @Test func proModelMatchesPublicID() {
        #expect(GeminiClient.proModel == "gemini-1.5-pro")
    }
    @Test func allModelsAreLowercaseDashed() {
        for m in GeminiClient.allModels {
            #expect(m == m.lowercased(),
                    "Gemini IDs must be lowercase, got \(m)")
            #expect(m.hasPrefix("gemini-"),
                    "Gemini IDs must start with `gemini-`, got \(m)")
        }
    }
    @Test func allModelsContainsDefault() {
        #expect(GeminiClient.allModels.contains(GeminiClient.defaultModel))
    }
}

struct GroqModelIDTests {
    @Test func defaultIsLlama70B() {
        // `llama-3.3-70b-versatile` is the current "Llama 70B Versatile" on
        // Groq; the predecessor `llama-3.1-70b-versatile` was decommissioned
        // (HTTP 400 "model not found") around 2026-06. Intent of the test is
        // unchanged — "default is the 70B versatile model" — only the exact
        // ID rolled forward.
        #expect(GroqClient.defaultModel == "llama-3.3-70b-versatile")
    }
    @Test func allModelsContainsDefault() {
        #expect(GroqClient.allModels.contains(GroqClient.defaultModel))
    }
    @Test func clientEndpointMatchesGroqDocs() {
        #expect(GroqClient.shared.baseURL == "https://api.groq.com/openai/v1")
        #expect(GroqClient.shared.displayName == "Groq")
    }
}

struct MistralModelIDTests {
    @Test func defaultIsSmallLatest() {
        // `mistral-small-latest` rolls automatically; the test is asserting
        // the alias, not the underlying version.
        #expect(MistralClient.defaultModel == "mistral-small-latest")
    }
    @Test func allModelsContainsDefault() {
        #expect(MistralClient.allModels.contains(MistralClient.defaultModel))
    }
    @Test func clientEndpointMatchesMistralDocs() {
        #expect(MistralClient.shared.baseURL == "https://api.mistral.ai/v1")
    }
}

struct CerebrasModelIDTests {
    @Test func defaultIsCurrentlyServedModel() {
        // Cerebras retired the Llama 3.1 family from public inference; the old
        // `llama3.1-8b` / `llama-3.3-70b` IDs both return 404 now. Live `GET
        // /v1/models` exposes only `gpt-oss-120b` and `zai-glm-4.7` — see the
        // comment on `CerebrasClient` in `CloudBrains.swift`. This test now
        // asserts the *current* default; rename + assertion will need rolling
        // again the next time the provider's offering shifts.
        #expect(CerebrasClient.defaultModel == "gpt-oss-120b")
    }
    @Test func allModelsContainsDefault() {
        #expect(CerebrasClient.allModels.contains(CerebrasClient.defaultModel))
    }
    @Test func clientEndpointMatchesCerebrasDocs() {
        #expect(CerebrasClient.shared.baseURL == "https://api.cerebras.ai/v1")
    }
}

// MARK: - NVIDIA NIM model IDs
//
// NvidiaClient speaks the NVIDIA NIM OpenAI-compatible endpoint. Pinning the
// model IDs here catches any future renaming before it silently 404s at runtime.
// NOTE: NvidiaClient is NOT in CloudProvider and has no brain-routing slot —
// the key is stored in Keychain but only feeds the SalehmanEngine cloud-optional
// path (vLLM / Unsloth fallback; the NIM path is forward-looking). Tests in
// SettingsBrainReadyTests pin that `nvidia=true` has no routing effect.

struct NvidiaModelIDTests {
    @Test func defaultModelIsDeepSeekV4Flash() {
        // The free-tier everyday model on NVIDIA NIM.
        #expect(NvidiaClient.defaultModel == "deepseek-ai/deepseek-v4-flash")
    }
    @Test func allModelsContainsDefault() {
        #expect(NvidiaClient.allModels.contains(NvidiaClient.defaultModel))
    }
    @Test func endpointAndDisplayNameMatchNvidiaDocs() {
        #expect(NvidiaClient.shared.baseURL == "https://integrate.api.nvidia.com/v1")
        #expect(NvidiaClient.shared.displayName == "NVIDIA")
    }
    @Test func keychainAccountStringIsStable() {
        // Renaming this loses every saved NVIDIA key silently.
        #expect(KeychainStore.Account.nvidiaAPIKey.rawValue == "nvidia-api-key")
    }
}

// MARK: - Keychain account contracts
//
// Each provider gets its own Keychain slot. Renaming any of these silently
// loses every existing user's saved key.

struct CloudKeychainAccountTests {
    @Test func eachProviderHasUniqueAccountString() {
        let names = Set([
            KeychainStore.Account.grokAPIKey.rawValue,
            KeychainStore.Account.geminiAPIKey.rawValue,
            KeychainStore.Account.groqAPIKey.rawValue,
            KeychainStore.Account.mistralAPIKey.rawValue,
            KeychainStore.Account.cerebrasAPIKey.rawValue,
            KeychainStore.Account.nvidiaAPIKey.rawValue,
        ])
        #expect(names.count == 6,
                "Each Keychain account string must be distinct — collisions overwrite keys")
    }
    @Test func accountStringsMatchExpectedSchema() {
        // Schema: lowercase-with-dashes ending in -api-key.
        for raw in [
            KeychainStore.Account.grokAPIKey.rawValue,
            KeychainStore.Account.geminiAPIKey.rawValue,
            KeychainStore.Account.groqAPIKey.rawValue,
            KeychainStore.Account.mistralAPIKey.rawValue,
            KeychainStore.Account.cerebrasAPIKey.rawValue,
            KeychainStore.Account.nvidiaAPIKey.rawValue,
        ] {
            #expect(raw.hasSuffix("-api-key"), "\(raw) must end with -api-key")
            #expect(raw == raw.lowercased(), "\(raw) must be lowercase")
        }
    }
}

// MARK: - BrainPreference surface

struct CloudBrainPreferenceTests {
    @Test func allFourCloudCasesAreListed() {
        let cases = Set(BrainPreference.allCases.map(\.rawValue))
        #expect(cases.contains("gemini"))
        #expect(cases.contains("groq"))
        #expect(cases.contains("mistral"))
        #expect(cases.contains("cerebras"))
    }
    @Test func eachCloudCaseHasNonEmptyDisplay() {
        for c in [BrainPreference.gemini, .groq, .mistral, .cerebras] {
            #expect(!c.title.isEmpty)
            #expect(!c.subtitle.isEmpty)
            #expect(!c.icon.isEmpty)
        }
    }
}

// MARK: - lacksCloudKey + isAvailable logic guards
//
// The two properties drive the "add a cloud key" UX banner and the outcome
// success-rating. The full Keychain layer can't be exercised in tests (no
// entitlements), but we can pin the routing LOGIC: which roster each mode
// consults, and which modes are exempt from the banner.

struct LacksCloudKeyLogicTests {

    @Test func salehmanAlwaysReturnsFalse() {
        // Salehman is on-device only — no cloud key is needed or used.
        // The banner would be wrong and alarming for this mode.
        let prior = UserDefaults.standard.string(forKey: AppSettings.Keys.brainPreference)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: AppSettings.Keys.brainPreference) }
            else         { UserDefaults.standard.removeObject(forKey: AppSettings.Keys.brainPreference) }
        }
        UserDefaults.standard.set(BrainPreference.salehman.rawValue,
                                   forKey: AppSettings.Keys.brainPreference)
        #expect(!LocalLLM.lacksCloudKey, ".salehman must never trigger the banner")
    }

    @Test func freeTierContainsOnlyFreeProviders() {
        // The banner fires when none of freeTier are configured. If a paid
        // brain slips into freeTier, freeAuto could silently spend money AND
        // the banner would be suppressed (masking the actual lack of a free key).
        let paidBrains: [CloudProvider] = [.anthropic, .grok, .openAI, .copilot]
        for paid in paidBrains {
            #expect(!CloudProvider.freeTier.contains(paid),
                    "\(paid.rawValue) is a paid brain and must not appear in freeTier")
        }
        // The five cost-free providers must all be present.
        for expected in [CloudProvider.groq, .cerebras, .gemini, .mistral, .openRouter] {
            #expect(CloudProvider.freeTier.contains(expected),
                    "\(expected.rawValue) must be in freeTier — it's the free-auto roster")
        }
    }

    @Test func codingRaceContainsOnlyFreeCoders() {
        // freeCoding banner logic uses codingRace. Same guard: paid brains
        // must not appear (no silent spend), and all four coders must be listed.
        let paidBrains: [CloudProvider] = [.anthropic, .grok, .openAI, .copilot]
        for paid in paidBrains {
            #expect(!CloudProvider.codingRace.contains(paid),
                    "\(paid.rawValue) must not be in codingRace")
        }
        for expected in [CloudProvider.openRouter, .groq, .cerebras, .mistral] {
            #expect(CloudProvider.codingRace.contains(expected),
                    "\(expected.rawValue) must be in codingRace")
        }
    }

    @Test func isAvailableReturnsFalseWhenNoCloudConfigured() {
        // Without real Keychain entries, configuredNow() returns an empty Set,
        // so isAvailable must return false. This is the correct "no brain" state.
        // (The pipeline falls back to offMessage when isAvailable is false AND
        // the answer is empty — this test verifies the no-key case, not the
        // Ollama case which is async.)
        //
        // If this test runs on a machine that has any cloud key saved, it will
        // return true (correctly). Either outcome is acceptable — this test is
        // primarily a structural guard to confirm CloudProvider.configuredNow()
        // is what drives the value, not a hard-coded false.
        let result = LocalLLM.isAvailable
        let expected = !CloudProvider.configuredNow().isEmpty
        #expect(result == expected,
                "isAvailable must mirror !CloudProvider.configuredNow().isEmpty")
    }
}

// MARK: - AppSettings.*ModelCurrent fallback

struct CloudModelCurrentFallbackTests {

    private func withTransientUserDefault<T>(_ key: String, value: String?,
                                             _ body: () -> T) -> T {
        let prior = UserDefaults.standard.string(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else         { UserDefaults.standard.removeObject(forKey: key) }
        }
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else         { UserDefaults.standard.removeObject(forKey: key) }
        return body()
    }

    @Test func unknownGeminiFallsBackToDefault() {
        let v = withTransientUserDefault(AppSettings.Keys.geminiModel, value: "future-model") {
            AppSettings.geminiModelCurrent
        }
        #expect(v == GeminiClient.defaultModel)
    }
    @Test func unknownGroqFallsBackToDefault() {
        let v = withTransientUserDefault(AppSettings.Keys.groqModel, value: "future-model") {
            AppSettings.groqModelCurrent
        }
        #expect(v == GroqClient.defaultModel)
    }
    @Test func unknownMistralFallsBackToDefault() {
        let v = withTransientUserDefault(AppSettings.Keys.mistralModel, value: "future-model") {
            AppSettings.mistralModelCurrent
        }
        #expect(v == MistralClient.defaultModel)
    }
    @Test func unknownCerebrasFallsBackToDefault() {
        let v = withTransientUserDefault(AppSettings.Keys.cerebrasModel, value: "future-model") {
            AppSettings.cerebrasModelCurrent
        }
        #expect(v == CerebrasClient.defaultModel)
    }
}
