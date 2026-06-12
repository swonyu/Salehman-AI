import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Brain routing plan (the R1 seam — BrainRouting.swift)
//
// The routing PLAN (gating, roster membership, order, offline rules) is pure
// over a `BrainRouteConfig` snapshot; `LocalLLM`'s ladders only execute it.
// These tests pin the plan hermetically — no keys, no network, no UI.
// House invariants pinned here:
//   · every preference dispatches to exactly ONE target, no fallthrough;
//   · `.auto`/`.ollama` never dispatch to a cloud adapter (local-first);
//   · Offline Mode hard-gates the ten cloud pins and empties every cloud
//     roster (the Offline-leak fix this seam enforces);
//   · `.freeAuto` may only race FREE providers — never paid keys.

@MainActor
struct BrainRoutingDispatchTests {

    private static let cloudPins: [BrainPreference] = [
        .claudeHaiku, .grok, .gemini, .groq, .mistral, .cerebras,
        .codex, .copilot, .openRouter,
    ]

    private static func config(
        _ tweak: (inout BrainRouteConfig) -> Void = { _ in }
    ) -> BrainRouteConfig {
        var c = BrainRouteConfig(pref: .auto)
        tweak(&c)
        return c
    }

    @Test
    func pinnedBrainPreferenceDispatchesToExactlyOneAdapterNoFallthrough() {
        // Every cloud pin → exactly its own provider, online.
        for pin in Self.cloudPins {
            let d = BrainRouting.dispatch(pref: pin, offlineOnly: false)
            guard case .cloud(let p) = d else {
                Issue.record("\(pin) should dispatch to a cloud provider, got \(d)")
                continue
            }
            #expect(p.pin == pin)
        }
        // The non-cloud pins each map to their own dedicated target.
        #expect(BrainRouting.dispatch(pref: .salehman, offlineOnly: false) == .salehman)
        #expect(BrainRouting.dispatch(pref: .unslothStudio, offlineOnly: false) == .unslothStudio)
        #expect(BrainRouting.dispatch(pref: .vllm, offlineOnly: false) == .vllm)
        // Orchestration modes are first-class (the old Settings "ensemble
        // falsely Not working" bug came from them falling through the gates).
        for mode in [BrainPreference.freeAuto, .freeCoding, .cloudCoding, .ensemble] {
            #expect(BrainRouting.dispatch(pref: mode, offlineOnly: false) == .mode(mode))
        }
        // The provider↔pin maps are a bijection over the ten cloud providers.
        for p in CloudProvider.allCases {
            #expect(CloudProvider.provider(for: p.pin) == p)
        }
    }

    @Test
    func autoAndLocalPinsNeverInvokeAnyCloudAdapterLocalFirstInvariant() {
        // Dispatch: `.auto`/`.ollama` go to the local tier — online or not.
        for offline in [false, true] {
            #expect(BrainRouting.dispatch(pref: .auto, offlineOnly: offline) == .localTier)
            #expect(BrainRouting.dispatch(pref: .ollama, offlineOnly: offline) == .localTier)
        }
        // Reachability: every cloud key on the planet must not light `.auto`
        // when the local floor is down (.auto never silently spends).
        let allKeys = Self.config {
            $0.pref = .auto
            $0.configured = Set(CloudProvider.allCases)
            $0.unslothConfigured = true; $0.vllmConfigured = true
            $0.salehmanCloudReady = true
        }
        #expect(BrainRouting.reachableBrain(allKeys) == LocalLLM.Brain.none)
        var ollamaPin = allKeys; ollamaPin.pref = .ollama
        #expect(BrainRouting.reachableBrain(ollamaPin) == LocalLLM.Brain.none)
        // And the local floor alone lights both.
        let floor = Self.config { $0.pref = .auto; $0.ollamaReady = true }
        #expect(BrainRouting.reachableBrain(floor) == .ollamaCoder)
    }

    @Test
    func offlineModeForcesCloudPrefsToNoneAndExcludesThemFromEnsembleAndFreeAuto() {
        // Reachability: each of the ten cloud pins reads .none offline, even
        // with its key saved.
        for pin in Self.cloudPins {
            let c = Self.config {
                $0.pref = pin
                $0.offlineOnly = true
                $0.configured = Set(CloudProvider.allCases)
            }
            #expect(BrainRouting.reachableBrain(c) == LocalLLM.Brain.none,
                    "\(pin) must be unreachable offline")
        }
        // Dispatch: cloud pins are hard-gated (the Offline-leak fix — the old
        // generate/streaming/chat cascades never enforced this contract).
        for pin in Self.cloudPins {
            #expect(BrainRouting.dispatch(pref: pin, offlineOnly: true) == .unavailable)
        }
        // Every cloud roster empties offline: ensemble and the free/coding
        // pools run local-only, attempting zero cloud calls.
        let offline = Self.config {
            $0.offlineOnly = true
            $0.configured = Set(CloudProvider.allCases)
        }
        #expect(BrainRouting.ensembleCloudRoster(offline).isEmpty)
        #expect(BrainRouting.freeAutoRoster(offline).isEmpty)
        #expect(BrainRouting.freeAutoToolRoster(offline).isEmpty)
        #expect(BrainRouting.codingRaceRoster(offline).isEmpty)
        #expect(BrainRouting.coderLoopRoster(offline).isEmpty)
        // Local pins and the orchestration modes stay reachable offline when
        // the local floor stands (they gate their own cloud rosters).
        let localOffline = Self.config {
            $0.pref = .freeAuto; $0.offlineOnly = true; $0.ollamaReady = true
        }
        #expect(BrainRouting.reachableBrain(localOffline) == .freeAuto)
        // Cloud Coding is cloud-ONLY: offline → .none even with every key.
        var cloudCoding = offline; cloudCoding.pref = .cloudCoding
        #expect(BrainRouting.reachableBrain(cloudCoding) == LocalLLM.Brain.none)
    }

    @Test
    func freeAutoIncludesOnlyFreeProvidersNeverPaidClients() {
        // With EVERYTHING configured, the freeAuto roster is exactly the free
        // tier, in the canonical race order — no paid provider ever appears.
        let everything = Self.config { $0.configured = Set(CloudProvider.allCases) }
        let roster = BrainRouting.freeAutoRoster(everything)
        #expect(roster == CloudProvider.freeTier)
        #expect(roster.allSatisfy { $0.isFree })
        for paid in [CloudProvider.anthropic, .grok, .openAI, .copilot] {
            #expect(!roster.contains(paid))
        }
        // The tool-loop variant additionally drops Gemini (free, but no
        // OpenAI-compat tool loop).
        let tools = BrainRouting.freeAutoToolRoster(everything)
        #expect(tools == CloudProvider.freeToolCapable)
        #expect(!tools.contains(.gemini))
        // Membership follows the configured set exactly.
        let groqOnly = Self.config { $0.configured = [.groq, .anthropic] }
        #expect(BrainRouting.freeAutoRoster(groqOnly) == [.groq])
    }

    @Test
    func rosterMembershipMatchesTheDocumentedSets() {
        let everything = Self.config { $0.configured = Set(CloudProvider.allCases) }
        // Ensemble: the nine chat brains. (The historical DeepSeek
        // counted-but-not-rostered drift dissolved with the provider's
        // removal on 2026-06-12.)
        let ensemble = BrainRouting.ensembleCloudRoster(everything)
        #expect(ensemble == CloudProvider.ensembleRoster)
        // The coding pools: race order and sequential-loop order are distinct,
        // deliberately (race = parallel anyway; the loop is quality+speed) —
        // but their MEMBERSHIP is identical.
        #expect(BrainRouting.codingRaceRoster(everything) == CloudProvider.codingRace)
        #expect(BrainRouting.coderLoopRoster(everything) == CloudProvider.coderLoop)
        #expect(Set(CloudProvider.codingRace) == Set(CloudProvider.coderLoop))
        // anyBrainReachable: local floor or any single key.
        #expect(!BrainRouting.anyBrainReachable(Self.config()))
        #expect(BrainRouting.anyBrainReachable(Self.config { $0.ollamaReady = true }))
        #expect(BrainRouting.anyBrainReachable(Self.config { $0.configured = [.cerebras] }))
        // Salehman: cloud-first; endpoint engines and any chain key light it,
        // nothing at all reads .none.
        let salehmanCloud = Self.config { $0.pref = .salehman; $0.salehmanCloudReady = true }
        #expect(BrainRouting.reachableBrain(salehmanCloud) == .salehman)
        let salehmanNothing = Self.config { $0.pref = .salehman }
        #expect(BrainRouting.reachableBrain(salehmanNothing) == LocalLLM.Brain.none)
    }
}
