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
// NOTE: the original disabled stubs named a pre-cloud-first model (`.auto`
// included Apple Intelligence back then). Bodies below pin TODAY's rules;
// names updated to match. House invariants pinned here:
//   · `.auto` is local-only — cloud keys must NEVER light it.
//   · `.freeAuto` never spends — paid-only keys must not light it.
//   · `.salehman` is cloud-first; its local floor needs a NAMED custom model.
//   · A superseded active-brain probe never publishes its verdict.
//   · The anthropic key subtitle never echoes secret bytes.

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

    /// Every cloud/key/endpoint signal ON, both local signals OFF — the probe
    /// for "does a local-only mode ignore the entire cloud side."
    private static var everythingButLocal: BrainReadiness {
        flags {
            $0.unslothConfigured = true; $0.vllmConfigured = true
            $0.anthropic = true; $0.grok = true; $0.gemini = true
            $0.groq = true; $0.mistral = true; $0.cerebras = true
            $0.deepSeek = true; $0.openAI = true; $0.copilot = true
            $0.openRouter = true; $0.nvidia = true
            $0.customModelNamed = true   // name alone, no ollamaUp
        }
    }

    @Test
    func autoAndOllamaRequireTheLocalCoderFloorAndIgnoreCloudKeys() {
        // The floor needs BOTH halves: server up AND a coder model pulled.
        #expect(!Self.flags { $0.ollamaUp = true }.ready(.auto))
        #expect(!Self.flags { $0.hasCoder = true }.ready(.auto))
        let floor = Self.flags { $0.ollamaUp = true; $0.hasCoder = true }
        #expect(floor.ready(.auto))
        #expect(floor.ready(.ollama))
        // Local-first invariant: every cloud signal ON must not light `.auto`
        // or `.ollama` (.auto never silently reaches for a cloud brain).
        #expect(!Self.everythingButLocal.ready(.auto))
        #expect(!Self.everythingButLocal.ready(.ollama))
    }

    @Test
    func freeAutoLightsForFreeKeysOrLocalFloorNeverForPaidOnlyKeys() {
        #expect(!BrainReadiness().ready(.freeAuto))
        // Paid-only / non-free signals all ON: anthropic, grok, openAI,
        // copilot, nvidia, deepSeek (deepSeek belongs to the CODING pools,
        // not freeAuto) and the endpoint engines. None may light freeAuto —
        // this mode promises to never spend.
        let paidOnly = Self.flags {
            $0.anthropic = true; $0.grok = true; $0.openAI = true
            $0.copilot = true; $0.nvidia = true; $0.deepSeek = true
            $0.unslothConfigured = true; $0.vllmConfigured = true
        }
        #expect(!paidOnly.ready(.freeAuto))
        // Each FREE key alone lights it; so does the local floor alone.
        #expect(Self.flags { $0.groq = true }.ready(.freeAuto))
        #expect(Self.flags { $0.gemini = true }.ready(.freeAuto))
        #expect(Self.flags { $0.cerebras = true }.ready(.freeAuto))
        #expect(Self.flags { $0.mistral = true }.ready(.freeAuto))
        #expect(Self.flags { $0.openRouter = true }.ready(.freeAuto))
        #expect(Self.flags { $0.ollamaUp = true; $0.hasCoder = true }.ready(.freeAuto))
    }

    @Test
    func salehmanIsCloudFirstAndItsLocalFloorNeedsANamedModel() {
        // The original stub's case: Ollama up but customModelName blank and
        // no cloud anywhere → NOT ready (nothing would actually answer).
        #expect(!Self.flags { $0.ollamaUp = true }.ready(.salehman))
        // Name + server → the local floor stands.
        #expect(Self.flags { $0.ollamaUp = true; $0.customModelNamed = true }
            .ready(.salehman))
        // A name with the server DOWN is not a floor.
        #expect(!Self.flags { $0.customModelNamed = true }.ready(.salehman))
        // Cloud-first: ANY single cloud signal lights it with zero local —
        // including endpoint engines and every chain key.
        #expect(Self.flags { $0.gemini = true }.ready(.salehman))
        #expect(Self.flags { $0.nvidia = true }.ready(.salehman))
        #expect(Self.flags { $0.vllmConfigured = true }.ready(.salehman))
        #expect(Self.flags { $0.unslothConfigured = true }.ready(.salehman))
        #expect(Self.flags { $0.anthropic = true }.ready(.salehman))
    }

    @Test
    func codingPoolsAndEnsembleMatchTheirDocumentedSets() {
        // cloudCoding is cloud-ONLY: the local floor must not light it.
        #expect(!Self.flags { $0.ollamaUp = true; $0.hasCoder = true }
            .ready(.cloudCoding))
        #expect(Self.flags { $0.deepSeek = true }.ready(.cloudCoding))
        #expect(!Self.flags { $0.gemini = true }.ready(.cloudCoding))
        // freeCoding = freeAuto's coding pool + deepSeek + the local floor.
        #expect(Self.flags { $0.deepSeek = true }.ready(.freeCoding))
        #expect(Self.flags { $0.ollamaUp = true; $0.hasCoder = true }
            .ready(.freeCoding))
        #expect(!Self.flags { $0.gemini = true }.ready(.freeCoding))
        // Ensemble: any keyed chat cloud or the local floor — but deepSeek /
        // nvidia / endpoint engines were never in its set (preserved rule).
        #expect(Self.flags { $0.anthropic = true }.ready(.ensemble))
        #expect(Self.flags { $0.copilot = true }.ready(.ensemble))
        #expect(!Self.flags { $0.deepSeek = true }.ready(.ensemble))
        #expect(!Self.flags { $0.nvidia = true }.ready(.ensemble))
        #expect(!Self.flags { $0.vllmConfigured = true }.ready(.ensemble))
        // Endpoint engines light exactly their own pin.
        #expect(Self.flags { $0.unslothConfigured = true }.ready(.unslothStudio))
        #expect(Self.flags { $0.vllmConfigured = true }.ready(.vllm))
        #expect(!Self.flags { $0.unslothConfigured = true }.ready(.vllm))
    }

    @Test
    func supersededProbeRunNeverPublishesItsVerdictAndSpinnerClearsAtZeroInFlight() {
        var probe = ActiveBrainProbe()
        #expect(!probe.testing && probe.working == nil)

        // The local→cloud switch bug the counter was built for: a single
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
    func pingVerdictRejectsEmptyOffMessageAndHaikuErrorReplies() {
        let off = "[offline]"
        #expect(!BrainPing.verdict(reply: "", offMessage: off))
        #expect(!BrainPing.verdict(reply: "  \n ", offMessage: off))
        #expect(!BrainPing.verdict(reply: off, offMessage: off))
        #expect(!BrainPing.verdict(reply: "  [Claude Haiku error: 401]",
                                   offMessage: off))
        #expect(BrainPing.verdict(reply: "pong", offMessage: off))
        // A real reply that merely MENTIONS the sentinel mid-text still counts
        // (the sentinel rule is full-string equality, not contains).
        #expect(BrainPing.verdict(reply: "not \(off)", offMessage: off))
    }

    @Test
    func anthropicSubtitleMasksNonSkAntKeysAndNeverLeaksSecretBytes() {
        // Wrong-service key: every character past "sk-" is secret material —
        // none of it may appear in the subtitle, and the row flags orange.
        let foreign = "xoxb-SECRETBYTES-9f8e7d6c5b4a"
        let masked = AnthropicKeyPresentation.subtitle(savedKey: foreign)
        #expect(!masked.contains("xoxb"))
        #expect(!masked.contains("SECRETBYTES"))
        #expect(!masked.contains("9f8e7d6c5b4a"))
        #expect(masked.contains("sk-…"))
        #expect(AnthropicKeyPresentation.flagsWrongService(savedKey: foreign))

        // Real Anthropic key: exactly the 12-char family prefix shows, the
        // secret tail never does.
        let real = "sk-ant-api03-TAILSECRETTAILSECRET"
        let shown = AnthropicKeyPresentation.subtitle(savedKey: real)
        #expect(shown.contains("sk-ant-api03"))
        #expect(!shown.contains("TAILSECRET"))
        #expect(!AnthropicKeyPresentation.flagsWrongService(savedKey: real))

        // No key saved: the "not configured" hint, no warning tint.
        #expect(AnthropicKeyPresentation.subtitle(savedKey: nil)
            == AnthropicKeyPresentation.notConfigured)
        #expect(!AnthropicKeyPresentation.flagsWrongService(savedKey: nil))
    }
}
