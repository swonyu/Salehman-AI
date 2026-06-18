import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Settings brain-readiness (the extracted pure seam)
//
// `SettingsView.brainReady` is now a thin caller over `BrainReadiness.ready`
// (SettingsBrainReadiness.swift) fed by the view's cached key flags — the
// CODEBASE_REVIEW HIGH perf fix (no more live Keychain reads per grid cell
// per body recompute). These tests pin the readiness rules hermetically:
// no Keychain, no network, no UI.
//
// Local-only build (2026-06-18): all cloud providers + composite modes were
// removed, so `BrainReadiness` carries only local engine/endpoint signals and
// `ready(_:)` classifies just the six local brains. House invariants pinned:
//   · `.auto` / `.ollama` need the local coder floor (Ollama up + a coder pulled);
//     a configured local endpoint must NOT light them.
//   · `.salehman` is local-first: a local endpoint (vLLM / Unsloth) OR the user's
//     own named Ollama model (server up) lights its floor.
//   · `.uncensored` needs Ollama up AND the abliterated model pulled.
//   · A superseded active-brain probe never publishes its verdict.

@MainActor
struct SettingsBrainReadyTests {

    /// All-false baseline; tweak the flags each case cares about.
    private static func flags(
        _ tweak: (inout BrainReadiness) -> Void = { _ in }
    ) -> BrainReadiness {
        var f = BrainReadiness()
        tweak(&f)
        return f
    }

    /// Every endpoint/name signal ON, both local-coder signals OFF — the probe
    /// for "does the local-coder floor (`.auto`/`.ollama`) ignore the endpoint
    /// engines and the custom-model name."
    private static var endpointsButNoCoderFloor: BrainReadiness {
        flags {
            $0.unslothConfigured = true; $0.vllmConfigured = true
            $0.customModelNamed = true   // name alone, no ollamaUp/hasCoder
        }
    }

    @Test
    func autoAndOllamaRequireTheLocalCoderFloor() {
        // The floor needs BOTH halves: server up AND a coder model pulled.
        #expect(!Self.flags { $0.ollamaUp = true }.ready(.auto))
        #expect(!Self.flags { $0.hasCoder = true }.ready(.auto))
        let floor = Self.flags { $0.ollamaUp = true; $0.hasCoder = true }
        #expect(floor.ready(.auto))
        #expect(floor.ready(.ollama))
        // Local-coder invariant: a configured endpoint engine or a named custom
        // model (the Salehman floor) must NOT light `.auto` / `.ollama` — those
        // are the pure local-coder floor only.
        #expect(!Self.endpointsButNoCoderFloor.ready(.auto))
        #expect(!Self.endpointsButNoCoderFloor.ready(.ollama))
    }

    @Test
    func salehmanIsLocalFirstAndItsFloorNeedsANamedModel() {
        // Ollama up but customModelName blank and no local endpoint → NOT ready.
        #expect(!Self.flags { $0.ollamaUp = true }.ready(.salehman))
        // Name + server → the local floor stands.
        #expect(Self.flags { $0.ollamaUp = true; $0.customModelNamed = true }
            .ready(.salehman))
        // A name with the server DOWN is not a floor.
        #expect(!Self.flags { $0.customModelNamed = true }.ready(.salehman))
        // Endpoint engines DO light it (the local resolution order).
        #expect(Self.flags { $0.vllmConfigured = true }.ready(.salehman))
        #expect(Self.flags { $0.unslothConfigured = true }.ready(.salehman))
    }

    @Test
    func endpointAndUncensoredPinsLightExactlyTheirOwnBrain() {
        // Endpoint engines light exactly their own pin.
        #expect(Self.flags { $0.unslothConfigured = true }.ready(.unslothStudio))
        #expect(Self.flags { $0.vllmConfigured = true }.ready(.vllm))
        #expect(!Self.flags { $0.unslothConfigured = true }.ready(.vllm))
        #expect(!Self.flags { $0.vllmConfigured = true }.ready(.unslothStudio))
        // Uncensored is local-only: Ollama up AND the abliterated model pulled.
        #expect(!Self.flags { $0.ollamaUp = true }.ready(.uncensored))
        #expect(!Self.flags { $0.hasUncensored = true }.ready(.uncensored))
        #expect(Self.flags { $0.ollamaUp = true; $0.hasUncensored = true }
            .ready(.uncensored))
    }

    @Test
    func supersededProbeRunNeverPublishesItsVerdictAndSpinnerClearsAtZeroInFlight() {
        var probe = ActiveBrainProbe()
        #expect(!probe.testing && probe.working == nil)

        // The local→endpoint switch bug the counter was built for: a single
        // superseded run must clear the spinner on exit (no successor will),
        // and must NOT publish its stale verdict.
        probe.begin()
        #expect(probe.testing && probe.working == nil)
        probe.finish(verdict: true, superseded: true)
        #expect(!probe.testing)
        #expect(probe.working == nil)

        // Overlap: run 1 still flying while run 2 lands with a verdict —
        // spinner must stay on (any run live), verdict publishes.
        probe.begin()                                  // run 1
        probe.begin()                                  // run 2
        probe.finish(verdict: true, superseded: false) // run 2 lands first
        #expect(probe.testing)                         // run 1 still in flight
        #expect(probe.working == true)
        probe.finish(verdict: false, superseded: true) // run 1 was superseded
        #expect(!probe.testing)                        // last flight clears it
        #expect(probe.working == true)                 // stale verdict ignored

        // Brain switched with no auto-test: shown verdict belongs to the old
        // brain and must clear.
        probe.invalidate()
        #expect(probe.working == nil)
    }

    @Test
    func pingVerdictRejectsEmptyAndOffMessageReplies() {
        let off = "[offline]"
        #expect(!BrainPing.verdict(reply: "", offMessage: off))
        #expect(!BrainPing.verdict(reply: "  \n ", offMessage: off))
        #expect(!BrainPing.verdict(reply: off, offMessage: off))
        #expect(BrainPing.verdict(reply: "pong", offMessage: off))
        // A real reply that merely MENTIONS the sentinel mid-text still counts
        // (the sentinel rule is full-string equality, not contains).
        #expect(BrainPing.verdict(reply: "not \(off)", offMessage: off))
    }
}
