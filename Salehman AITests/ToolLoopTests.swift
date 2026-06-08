import Testing
import Foundation
@testable import Salehman_AI

// Wave 2 of the audit-driven hardening: pins three pure decision functions that
// were extracted as testability seams. All are `nonisolated static` + side-
// effect-free, so they run safely in parallel with the rest of the suite.

// MARK: - Ollama tool-spec gating (SECURITY)
//
// The local qwen brain must never even be SHOWN the web tools while external
// access is off (web disabled OR Offline mode). Gating the spec list — not just
// the executor — is the real control: a model can only call what it's handed.
struct OllamaToolSpecsTests {
    private func names(_ specs: [[String: Any]]) -> [String] {
        specs.compactMap { ($0["function"] as? [String: Any])?["name"] as? String }
    }

    @Test func offlineExposesOnlyTerminal() {
        let n = names(LocalLLM.ollamaToolSpecs(externalAllowed: false))
        #expect(n == ["run_terminal_command"])
        #expect(!n.contains("web_search"))
        #expect(!n.contains("fetch_url"))
    }

    @Test func onlineExposesTerminalPlusWeb() {
        let n = names(LocalLLM.ollamaToolSpecs(externalAllowed: true))
        #expect(n.contains("run_terminal_command"))
        #expect(n.contains("web_search"))
        #expect(n.contains("fetch_url"))
        #expect(n.count == 3)
    }
}

// MARK: - FreeAuto cooldown window boundary (pins the extracted `isStillCooling`
// seam specifically — distinct from the existing FreeAutoCooldownTests).
//
// A free brain that just failed is skipped for `window` seconds. Pins the 120 s
// boundary (strict `<`) and that a brain with no recorded failure never cools.
struct CooldownWindowSeamTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func withinWindowStillCools() {
        #expect(LocalLLM.isStillCooling(failedAt: t0, now: t0.addingTimeInterval(119), window: 120))
    }

    @Test func atOrPastBoundaryRetries() {
        // Strict `<`, so exactly `window` seconds later is NOT cooling.
        #expect(!LocalLLM.isStillCooling(failedAt: t0, now: t0.addingTimeInterval(120), window: 120))
        #expect(!LocalLLM.isStillCooling(failedAt: t0, now: t0.addingTimeInterval(121), window: 120))
    }

    @Test func noRecordedFailureNeverCools() {
        #expect(!LocalLLM.isStillCooling(failedAt: nil, now: t0))
    }
}

// MARK: - AgentPipeline OOM-prevention concurrency cap
//
// Guards the exact rule that prevents a 16 GB Mac from OOM-crashing WindowServer:
// the local Ollama coder runs agents SERIALLY (cap 1) regardless of the memory-
// derived base cap. A refactor dropping this would silently re-introduce a hard
// crash with no failing test — until now.
struct AgentPipelineCapTests {
    @Test func ollamaForcesSerial() {
        #expect(AgentPipeline.effectiveCap(brain: .ollamaCoder, baseCap: 8) == 1)
        #expect(AgentPipeline.effectiveCap(brain: .ollamaCoder, baseCap: 1) == 1)
    }

    @Test func otherBrainsUseBaseCap() {
        #expect(AgentPipeline.effectiveCap(brain: .deepSeek, baseCap: 8) == 8)
        #expect(AgentPipeline.effectiveCap(brain: .ensemble, baseCap: 4) == 4)
    }

    @Test func baseCapFlooredAtOne() {
        #expect(AgentPipeline.effectiveCap(brain: .deepSeek, baseCap: 0) == 1)
    }
}

// MARK: - Paid-brain hiding (owner request: "hide every paid api")
//
// Pins which brains count as paid and that the Brain picker's `selectableCases`
// excludes exactly those — so a future enum addition can't silently leak a paid
// provider back into the UI.
struct PaidBrainHidingTests {
    @Test func paidSetIsExactlyTheFourCloudPaidProviders() {
        let paid = BrainPreference.allCases.filter { $0.isPaid }
        #expect(Set(paid) == Set([.claudeHaiku, .grok, .codex, .copilot]))
    }

    @Test func selectableCasesExcludeAllPaid() {
        #expect(!BrainPreference.selectableCases.contains { $0.isPaid })
        // Free + local + orchestration modes survive.
        #expect(BrainPreference.selectableCases.contains(.auto))
        #expect(BrainPreference.selectableCases.contains(.salehman))
        #expect(BrainPreference.selectableCases.contains(.gemini))
        #expect(BrainPreference.selectableCases.contains(.freeAuto))
    }
}
