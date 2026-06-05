import Testing
import Foundation
@testable import Salehman_AI

// MARK: - OpenRouter integration guards
//
// OpenRouter's free-model roster ROTATES, so these tests don't claim a given
// `:free` ID is live forever — they pin the *contract*: the config points at
// the right endpoint/Keychain slot, the default is one of the offered models,
// and the free models carry the `:free` suffix that makes them zero-cost.

struct OpenRouterConfigTests {

    @Test func endpointAndAccountAreCorrect() {
        #expect(OpenRouterClient.shared.baseURL == "https://openrouter.ai/api/v1")
        #expect(OpenRouterClient.shared.keychainAccount == .openRouterAPIKey)
        #expect(OpenRouterClient.shared.displayName == "OpenRouter")
    }

    @Test func defaultIsInTheOfferedList() {
        #expect(OpenRouterClient.allModels.contains(OpenRouterClient.defaultModel))
        #expect(!OpenRouterClient.allModels.isEmpty)
    }

    @Test func everyDefaultModelIsAFreeVariant() {
        // The whole point of the OpenRouter integration is *free* access — every
        // shipped default must carry the `:free` suffix, or it would silently
        // bill the user. A paid model sneaking into the list trips this.
        for m in OpenRouterClient.allModels {
            #expect(m.hasSuffix(":free"), "OpenRouter shipped model \(m) must be a `:free` variant")
        }
    }

    @Test func keychainAccountStringIsStable() {
        // Renaming this loses every user's saved key.
        #expect(KeychainStore.Account.openRouterAPIKey.rawValue == "openrouter-api-key")
    }
}

// MARK: - BrainPreference + model fallback

struct OpenRouterPreferenceTests {

    @Test func openRouterIsListedAndStable() {
        #expect(BrainPreference.allCases.contains(.openRouter))
        #expect(BrainPreference.openRouter.rawValue == "openRouter")
        #expect(!BrainPreference.openRouter.title.isEmpty)
        #expect(!BrainPreference.openRouter.subtitle.isEmpty)
        #expect(!BrainPreference.openRouter.icon.isEmpty)
    }

    @Test func unknownStoredModelFallsBackToDefault() {
        let key = AppSettings.Keys.openRouterModel
        let prior = UserDefaults.standard.string(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else         { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.set("some/retired-model:free", forKey: key)
        #expect(AppSettings.openRouterModelCurrent == OpenRouterClient.defaultModel)
    }
}
