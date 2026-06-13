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

    @Test func grok3ModelsAreAvailable() {
        // grok-3 and grok-3-mini are the accessible alternatives to grok-4
        // (cheaper, smaller). Pinning them so a rename in the picker doesn't
        // silently drop the user back to grok-4 with no warning.
        #expect(GrokClient.grok3Model == "grok-3")
        #expect(GrokClient.grok3MiniModel == "grok-3-mini")
    }

    @Test func allModelsContainsTheAccessibleCatalog() {
        // `allModels` drives both the Settings picker and
        // `AppSettings.grokModelCurrent`'s validation. If a value disappears
        // from this list, stored preferences silently fall back to default.
        #expect(GrokClient.allModels.contains("grok-4"))
        #expect(GrokClient.allModels.contains("grok-3"))
        #expect(GrokClient.allModels.contains("grok-3-mini"))
        // `grok-build-0.1` is confirmed available to this team (seen in the
        // user's xAI console). Included as a probe — see GrokClient.buildModel.
        #expect(GrokClient.allModels.contains("grok-build-0.1"))
        // `count >= 3` (not `== 3`) so the list can grow without re-litigating
        // the test. Specific exclusions are enforced separately below.
        #expect(GrokClient.allModels.count >= 3)
    }

    @Test func heavyVariantsAreReservedButNotUserVisible() {
        // xAI's `/v1/chat/completions` API does NOT currently expose either
        // `grok-4-heavy` or `grok-4-heavy-4.3` — they're grok.com-only
        // "Think Harder" modes. Picking either 404s with "The model … does
        // not exist or your team does not have access to it". The constants
        // stay defined for forward compatibility, but they must NOT appear
        // in `allModels` (the Settings picker) until xAI ships API access.
        // This guard trips loudly if someone re-adds either without
        // checking xAI's current catalog.
        #expect(GrokClient.heavyModel == "grok-4-heavy")
        #expect(GrokClient.heavy43Model == "grok-4-heavy-4.3")
        #expect(!GrokClient.allModels.contains("grok-4-heavy"),
                "grok-4-heavy is not API-accessible — keep it out of allModels until xAI ships it")
        #expect(!GrokClient.allModels.contains("grok-4-heavy-4.3"),
                "grok-4-heavy-4.3 is not API-accessible — keep it out of allModels until xAI ships it")
    }

    @Test func modelStringsAreLowercaseAndDashed() {
        // xAI's API rejects mixed-case or underscored model IDs. Belt-and-
        // suspenders check so a "Grok-4" or "grok_4" never ships. Dots
        // (e.g. `grok-4-heavy-4.3`) are tolerated — the API does accept
        // them when they're part of a real model tag.
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

// MARK: - GrokClient.shared (OpenAICompatibleClient) configuration

struct GrokSharedClientTests {

    @Test func sharedClientHasCorrectBaseURL() {
        // xAI's Chat Completions endpoint is at api.x.ai/v1. If this changes,
        // every GrokClient.shared tool-loop call (terminal / web) will 404.
        #expect(GrokClient.shared.baseURL == "https://api.x.ai/v1")
    }

    @Test func sharedClientDefaultModelMatchesGrokClient() {
        #expect(GrokClient.shared.defaultModel == GrokClient.defaultModel)
    }

    @Test func sharedClientAllModelsMatchGrokClient() {
        #expect(GrokClient.shared.allModels == GrokClient.allModels)
    }

    @Test func sharedClientKeychainAccountIsGrokKey() {
        // `shared` must read from the same Keychain slot as `GrokClient.chat` —
        // mismatching accounts would make the tool loop prompt for a key even
        // when the user already saved one via Settings.
        #expect(GrokClient.shared.keychainAccount == .grokAPIKey)
    }

    @Test func compatClientReturnsSharedForGrok() {
        // BrainRouting.compatClient drives the entire OpenAI-compat tool loop.
        // `.grok` must no longer return nil — it must return GrokClient.shared
        // so pinned-Grok turns can call terminal / web tools.
        let client = CloudProvider.grok.compatClient
        #expect(client != nil, "CloudProvider.grok.compatClient must not be nil after EOV fix")
        #expect(client?.baseURL == GrokClient.shared.baseURL)
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
