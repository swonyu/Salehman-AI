import Testing
import Foundation
@testable import Salehman_AI

// MARK: - 14B readiness — per-model knobs, context diet, tool-round notes
//
// Written for the 9 GB `salehman` fine-tune landing on this Mac: the knobs that
// keep it warm, the budgets that keep its 4096-token context from silently
// evicting the persona, and the progress note that keeps slow tool rounds
// visible. (`effectiveCap` / `isTrivialMission` are already pinned by
// ToolLoopTests / AgentPipelineConcurrencyTests / TrivialMissionTests.)
//
// `.serialized` + save/restore: `tunedKnobs…` mutate the global UserDefaults
// key `Keys.customModel`. This file is the SOLE test mutator of that key
// (verified 2026-06-11) — don't write it from another suite without
// serializing against this one.

@Suite(.serialized)
struct FourteenBReadinessTests {

    /// Run `body` with the custom-model-name key saved and restored.
    private func withSavedModelKey(_ body: () -> Void) {
        let key = AppSettings.Keys.customModel
        let prior = UserDefaults.standard.object(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        body()
    }

    // MARK: Generation.tuned(for:) — the user's own model stays warm

    @Test func tunedKnobsKeepTheUsersOwnModelWarm() {
        withSavedModelKey {
            UserDefaults.standard.set("salehman14b", forKey: AppSettings.Keys.customModel)
            let gen = OllamaClient.Generation.tuned(for: "salehman14b")
            // 5-minute keep-alive: re-paying the ~9 GB load mid-conversation is
            // the single worst local latency hit. 4096 ctx matches its Modelfile.
            #expect(gen.keepAlive == "5m")
            #expect(gen.numCtx == 4096)
        }
    }

    @Test func tunedKnobsStayRAMLeanForOtherModels() {
        withSavedModelKey {
            UserDefaults.standard.set("salehman14b", forKey: AppSettings.Keys.customModel)
            let gen = OllamaClient.Generation.tuned(for: "qwen2.5-coder:7b")
            // Small models keep the laptop-friendly defaults — evict fast, small KV.
            #expect(gen.keepAlive == "30s")
            #expect(gen.numCtx == OllamaClient.defaultNumCtx)
        }
    }

    @Test func tunedKnobsFollowTheDefaultModelName() {
        withSavedModelKey {
            // Key unset → customModelNameCurrent defaults to "salehman" — the
            // name the fine-tune ships under (`ollama create salehman …`).
            UserDefaults.standard.removeObject(forKey: AppSettings.Keys.customModel)
            #expect(OllamaClient.Generation.tuned(for: "salehman").keepAlive == "5m")
            #expect(OllamaClient.Generation.tuned(for: "anything-else").keepAlive == "30s")
        }
    }

    // MARK: recentTail — local context diet keeps the most-recent turns

    @Test func recentTailKeepsShortTextWhole() {
        #expect(AgentPipeline.recentTail("User: hi\nAI: hello", maxChars: 100) == "User: hi\nAI: hello")
        #expect(AgentPipeline.recentTail("", maxChars: 100) == "")
    }

    @Test func recentTailKeepsTheNewestTurnsAndCutsAtALineBoundary() {
        let turns = (1...50).map { "User: message number \($0)" }.joined(separator: "\n")
        let tail = AgentPipeline.recentTail(turns, maxChars: 200)
        #expect(tail.count <= 200)
        // Newest turn survives; the cut never starts mid-line.
        #expect(tail.hasSuffix("User: message number 50"))
        #expect(tail.hasPrefix("User: "))
    }

    @Test func recentTailNeverReturnsEmptyForAGiantSingleLine() {
        let oneLine = String(repeating: "x", count: 10_000)
        let tail = AgentPipeline.recentTail(oneLine, maxChars: 500)
        #expect(tail.count == 500)   // raw char cut, not ""
    }

    // MARK: noteToolRound — slow tool rounds show life on the running step

    @MainActor
    @Test func noteToolRoundAnnotatesTheRunningStepIdempotently() {
        let progress = MissionProgress.shared
        defer { progress.clear() }
        let specs = [
            AgentSpec(name: "Reasoning Strategist", icon: "brain.head.profile",
                      role: "test", usesTools: true, phase: 0),
            AgentSpec(name: "Final Output Quality Owner", icon: "checkmark.seal.fill",
                      role: "test", full: true, isFinal: true, phase: 1),
        ]
        progress.begin(specs)
        progress.setRunning(0)

        progress.noteToolRound(2, of: 8)
        #expect(progress.steps[0].adapted == "Reasoning Strategist · tool round 2/8")

        // Re-noting REPLACES the suffix (no "round 2/8 · tool round 3/8" stacking),
        // and an adapted title set by adaptTitles survives as the base.
        progress.noteToolRound(3, of: 8)
        #expect(progress.steps[0].adapted == "Reasoning Strategist · tool round 3/8")

        // The non-running step is untouched; no-run/no-steps is a safe no-op.
        #expect(progress.steps[1].adapted == nil)
        progress.clear()
        progress.noteToolRound(1, of: 8)   // must not crash on empty steps
        #expect(progress.steps.isEmpty)
    }
}
