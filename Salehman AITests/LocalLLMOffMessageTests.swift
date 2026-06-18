import Testing
import Foundation
@testable import Salehman_AI

// MARK: - offMessage sentinel contract
//
// Three call sites rely on `LocalLLM.offMessage` as a deterministic equality
// marker — meaning the value MUST be a `static let`, not a computed `var`
// whose result depends on settings:
//   * `LocalLLM.synthesize` does `refined == offMessage ? draft : refined`.
//   * `SettingsView`'s test-connection path does `reply == LocalLLM.offMessage`.
//   * `AgentPipeline.run` short-circuits with `return LocalLLM.offMessage` when
//     `currentBrain() == .none`, expecting the caller to recognize the
//     sentinel downstream.
//
// A previous version made this property context-aware (deterministic-per-
// preference). That silently breaks all three call sites the moment the user
// toggles `brainPreference` between the call that returned the value and the
// call that compares it. These tests pin the contract: the sentinel is
// stable across reads regardless of any preference toggle, AND it's distinct
// from the context-aware UI-facing message.

struct OffMessageSentinelTests {

    /// Sentinel reads MUST be identical no matter how many times we call —
    /// the only way to fail this in practice is to make `offMessage` a
    /// computed property again.
    @Test func sentinelIsStableAcrossReads() {
        let a = LocalLLM.offMessage
        let b = LocalLLM.offMessage
        let c = LocalLLM.offMessage
        #expect(a == b)
        #expect(b == c)
    }

    /// The sentinel does NOT vary with `brainPreference`. We toggle the
    /// preference between reads and assert the sentinel doesn't move. If
    /// someone reverts `offMessage` to a computed-per-preference property,
    /// THIS test trips loudly.
    @Test func sentinelIsInvariantAcrossPreferenceChanges() {
        // Cross-suite serialization — see BrainPreferenceTestLock.swift.
        BrainPreferenceTestLock.lock.lock()
        defer { BrainPreferenceTestLock.lock.unlock() }

        let key = AppSettings.Keys.brainPreference
        let prior = UserDefaults.standard.string(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else         { UserDefaults.standard.removeObject(forKey: key) }
        }

        // Take a baseline read under the current preference.
        let baseline = LocalLLM.offMessage

        // Now flip through every preference and confirm the sentinel never
        // changes. We don't care which order — we just care that *none* of
        // them yields a different value.
        for pref in BrainPreference.allCases {
            UserDefaults.standard.set(pref.rawValue, forKey: key)
            let now = LocalLLM.offMessage
            #expect(now == baseline,
                    "offMessage shifted to \"\(now.prefix(40))…\" when preference flipped to \(pref.rawValue)")
        }
    }

    /// The user-facing message *is* allowed to vary by preference — it's a
    /// computed property by design. This test sanity-checks that the two
    /// surfaces are actually separated; if they collapse back into one
    /// value, the split is meaningless.
    @Test func unavailableMessageIsAllowedToDifferFromSentinel() {
        // Cross-suite serialization — see BrainPreferenceTestLock.swift.
        BrainPreferenceTestLock.lock.lock()
        defer { BrainPreferenceTestLock.lock.unlock() }

        let key = AppSettings.Keys.brainPreference
        let prior = UserDefaults.standard.string(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else         { UserDefaults.standard.removeObject(forKey: key) }
        }

        // Pin a non-default preference so `unavailableMessage` produces its
        // pinned-brain remedy text — which should NOT equal the generic
        // sentinel "no model is reachable…" line.
        UserDefaults.standard.set(BrainPreference.salehman.rawValue, forKey: key)
        #expect(LocalLLM.unavailableMessage != LocalLLM.offMessage,
                "context-aware message collapsed back into sentinel — split is meaningless")
    }

    /// Both surfaces should produce non-empty strings (defends against
    /// someone setting one to "" while refactoring).
    @Test func bothSurfacesAreNonEmpty() {
        #expect(!LocalLLM.offMessage.isEmpty)
        #expect(!LocalLLM.unavailableMessage.isEmpty)
    }
}
