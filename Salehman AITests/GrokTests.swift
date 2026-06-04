import Testing
import Foundation
@testable import Salehman_AI

// MARK: - GrokClient model-ID guards
//
// These exist for one reason: if someone (or a careless rename tool) mutates
// the default model strings to something xAI's API doesn't accept, every
// runtime Grok call will silently 404 and look like a network bug. Pinning
// the canonical strings in tests means a typo trips CI before a user notices.

struct GrokModelIDTests {

    @Test func defaultModelMatchesXAICatalog() {
        // Real xAI API model IDs use lower-case + dashes. The default must be
        // a model `console.x.ai` lists. If xAI ever renames `grok-4`, this
        // test fails on purpose — update both the constant and this assertion
        // together.
        #expect(GrokClient.defaultModel == "grok-4")
    }

    @Test func heavyModelMatchesXAICatalog() {
        #expect(GrokClient.heavyModel == "grok-4-heavy")
    }

    @Test func allModelsContainsTheDefaults() {
        // `allModels` drives both the Settings picker and
        // `AppSettings.grokModelCurrent`'s validation. If a value disappears
        // from this list, stored preferences silently fall back to default.
        #expect(GrokClient.allModels.contains("grok-4"))
        #expect(GrokClient.allModels.contains("grok-4-heavy"))
        #expect(GrokClient.allModels.count == 2)
    }

    @Test func modelStringsAreLowercaseAndDashed() {
        // xAI's API rejects mixed-case or underscored model IDs. Belt-and-
        // suspenders check so a "Grok-4" or "grok_4" never ships.
        for model in GrokClient.allModels {
            #expect(model == model.lowercased(),
                    "Grok model IDs must be lowercase, got \(model)")
            #expect(!model.contains("_"),
                    "Grok model IDs must use dashes not underscores, got \(model)")
            #expect(model.hasPrefix("grok-"),
                    "Grok model IDs must start with `grok-`, got \(model)")
        }
    }
}

// MARK: - KeychainStore round-trip
//
// We don't exercise the actual macOS Keychain in tests (the test bundle
// doesn't have the right entitlements and the system Keychain UI prompt
// would block CI). These are pure-logic guards on the `Account` enum +
// account-string contract.

struct KeychainStoreContractTests {

    @Test func grokAccountUsesExpectedString() {
        // The string changes are part of the schema — if someone renames the
        // account, every existing user's saved key disappears (the new
        // account name finds nothing). Pinning the string here catches that
        // before users notice.
        #expect(KeychainStore.Account.grokAPIKey.rawValue == "grok-api-key")
    }
}

// MARK: - BrainPreference enum surface

struct BrainPreferenceGrokTests {

    @Test func grokIsListedInAllCases() {
        // The Settings picker is a `ForEach(BrainPreference.allCases)`. If
        // `.grok` ever drops out of allCases, the row silently disappears
        // and users have no way to pick it. This guards the visibility.
        #expect(BrainPreference.allCases.contains(.grok))
    }

    @Test func grokHasNonEmptyTitleSubtitleIcon() {
        let g = BrainPreference.grok
        #expect(!g.title.isEmpty)
        #expect(!g.subtitle.isEmpty)
        #expect(!g.icon.isEmpty)
    }

    @Test func grokRawValueIsStable() {
        // The raw value is persisted in UserDefaults under `set_brainPreference`.
        // Renaming it would silently demote saved preferences back to `.auto`.
        #expect(BrainPreference.grok.rawValue == "grok")
    }
}

// MARK: - AppSettings.grokModelCurrent fallback

struct GrokModelCurrentTests {

    @Test func unknownStoredModelFallsBackToDefault() {
        // Simulate a stale or typoed UserDefaults value. The fallback path
        // must return `GrokClient.defaultModel`, not crash and not return
        // the garbage string (which would 404 on the next API call).
        let key = AppSettings.Keys.grokModel
        let prior = UserDefaults.standard.string(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else         { UserDefaults.standard.removeObject(forKey: key) }
        }

        UserDefaults.standard.set("grok-from-the-future-v99", forKey: key)
        #expect(AppSettings.grokModelCurrent == GrokClient.defaultModel)
    }

    @Test func emptyStoredModelFallsBackToDefault() {
        let key = AppSettings.Keys.grokModel
        let prior = UserDefaults.standard.string(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else         { UserDefaults.standard.removeObject(forKey: key) }
        }

        UserDefaults.standard.removeObject(forKey: key)
        #expect(AppSettings.grokModelCurrent == GrokClient.defaultModel)
    }
}
