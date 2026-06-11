import Testing
import Foundation
@testable import Salehman_AI

// MARK: - ToolPolicy gate (SECURITY-CRITICAL)
//
// `ToolPolicy` decides whether the assistant gets EXTERNAL/network tools
// (web_search, fetch_url) on top of the always-on local core. It's the gate
// that keeps a local-first session from silently reaching the network, so it
// must behave exactly. These tests pin: (1) the `override` pin wins; (2) with
// no override, the policy follows the user's web-access setting. (The
// model-facing "web tools never offered when off" property is pinned against
// the live tool list in OllamaToolGateTests via `ollamaToolNames`.)
//
// The suite is `.serialized`: it mutates the process-globals `ToolPolicy.override`
// and the `webAccess` UserDefaults key, and Swift Testing runs tests in parallel —
// two of these racing one global would flake. No other suite touches these
// globals, so cross-suite parallelism stays safe. We avoid `==` on the
// `ToolPolicy` enum itself (its Equatable conformance is main-actor-isolated under
// `-default-isolation=MainActor`) and assert through the `nonisolated` surface
// (`isExternalAllowed`).

@Suite(.serialized)
struct ToolPolicyTests {

    /// Run `body` with `ToolPolicy.override` + every UserDefaults key the gate
    /// consults saved & restored. The gate currently reads two keys:
    /// `Keys.webAccess` (the original input) AND `Keys.offlineOnly` (added by
    /// the Offline-mode feature — forces `isExternalAllowed` to false
    /// regardless of override). A persisted `offlineOnly = true` from a prior
    /// run / Settings interaction would otherwise silently sink any
    /// "expected true" assertion. We explicitly set `offlineOnly = false` for
    /// the duration of the test so the override and webAccess paths can be
    /// asserted in isolation.
    private func withCleanPolicy(_ body: () -> Void) {
        // Cross-suite lock: WebToolsOfflineGateTests mutates these same globals in parallel.
        ToolPolicyTestLock.lock.lock()
        defer { ToolPolicyTestLock.lock.unlock() }   // LIFO: unlocks AFTER the restore defer
        let priorOverride = ToolPolicy.override
        let webKey = AppSettings.Keys.webAccess
        let offlineKey = AppSettings.Keys.offlineOnly
        let priorWeb     = UserDefaults.standard.object(forKey: webKey)
        let priorOffline = UserDefaults.standard.object(forKey: offlineKey)
        UserDefaults.standard.set(false, forKey: offlineKey)
        defer {
            ToolPolicy.override = priorOverride
            if let priorWeb     { UserDefaults.standard.set(priorWeb,     forKey: webKey) }
            else                { UserDefaults.standard.removeObject(forKey: webKey) }
            if let priorOffline { UserDefaults.standard.set(priorOffline, forKey: offlineKey) }
            else                { UserDefaults.standard.removeObject(forKey: offlineKey) }
        }
        body()
    }

    @Test func overridePinsTheGate() {
        withCleanPolicy {
            ToolPolicy.override = .localOnly
            #expect(ToolPolicy.isExternalAllowed == false)

            ToolPolicy.override = .allowExternalTools
            #expect(ToolPolicy.isExternalAllowed == true)
        }
    }

    @Test func withoutOverrideTheGateFollowsTheWebAccessSetting() {
        withCleanPolicy {
            ToolPolicy.override = nil
            UserDefaults.standard.set(false, forKey: AppSettings.Keys.webAccess)
            #expect(ToolPolicy.isExternalAllowed == false)

            UserDefaults.standard.set(true, forKey: AppSettings.Keys.webAccess)
            #expect(ToolPolicy.isExternalAllowed == true)
        }
    }

}
