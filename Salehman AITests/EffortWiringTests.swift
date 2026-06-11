import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Effort wiring — the Settings dial actually reaches the answer path
//
// `AppSettings.salehmanEffortCurrent` is the nonisolated accessor
// `SalehmanLeader.finalize` reads on every reply (leader pass at effort for
// other brains; critique-only `refineOwnDraft` for the pinned `.salehman`
// brain). These tests pin the accessor's validate-or-default contract.
//
// `.serialized` + save/restore: the suite mutates the global UserDefaults key
// `Keys.salehmanEffort`, and Swift Testing runs suites in parallel. This file
// is the SOLE mutator of that key (verified 2026-06-11) — do not write it from
// another suite without serializing against this one (see the brainPreference
// lesson in DEVELOPMENT_LOG).

@Suite(.serialized)
struct EffortWiringTests {

    /// Run `body` with the persisted effort key saved and restored, so the
    /// user's real setting survives the test run.
    private func withSavedEffortKey(_ body: () -> Void) {
        let key = AppSettings.Keys.salehmanEffort
        let prior = UserDefaults.standard.object(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        body()
    }

    @Test func defaultsToInstantWhenUnset() {
        withSavedEffortKey {
            UserDefaults.standard.removeObject(forKey: AppSettings.Keys.salehmanEffort)
            // .instant preserves pre-Effort call counts — no surprise quota spend
            // on upgrade. Higher effort levels are opt-in via the Settings dial.
            #expect(AppSettings.salehmanEffortCurrent == .instant)
        }
    }

    @Test func honorsEveryStoredEffortLevel() {
        withSavedEffortKey {
            for effort in Effort.allCases {
                UserDefaults.standard.set(effort.rawValue, forKey: AppSettings.Keys.salehmanEffort)
                #expect(AppSettings.salehmanEffortCurrent == effort)
            }
        }
    }

    @Test func garbageValueFallsBackToInstant() {
        withSavedEffortKey {
            UserDefaults.standard.set("warp-speed-11", forKey: AppSettings.Keys.salehmanEffort)
            #expect(AppSettings.salehmanEffortCurrent == .instant)
        }
    }
}
