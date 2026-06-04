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
        // Llama-3.1-70b is what `console.groq.com` calls "Llama 3.1 70B Versatile".
        #expect(GroqClient.defaultModel == "llama-3.1-70b-versatile")
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
    @Test func defaultIsLlama3_1_8B() {
        #expect(CerebrasClient.defaultModel == "llama3.1-8b")
    }
    @Test func allModelsContainsDefault() {
        #expect(CerebrasClient.allModels.contains(CerebrasClient.defaultModel))
    }
    @Test func clientEndpointMatchesCerebrasDocs() {
        #expect(CerebrasClient.shared.baseURL == "https://api.cerebras.ai/v1")
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
        ])
        #expect(names.count == 5,
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
