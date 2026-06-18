import Testing
@testable import Salehman_AI

// MARK: - AgentPipeline.effectiveCap — OOM-prevention regression guard
//
// On the local Ollama coder, multi-agent fan-out CRASHED a 16 GB Mac (shared
// RAM/VRAM exhaustion → WindowServer freeze). The pipeline forces cap=1 for
// `.ollamaCoder` regardless of the MemoryManager's base cap; this suite locks
// the invariant in place so a future refactor removing that branch fails
// loudly here rather than during the next 14 B-model fan-out run.

struct AgentPipelineConcurrencyTests {

    @Test func ollamaForcesSerialExecutionRegardlessOfBaseCap() {
        // Sweep across a range of base caps — a single-value assertion would
        // pass even if the .ollamaCoder branch were removed (because at
        // baseCap=1 the result would coincidentally still be 1). The sweep
        // verifies the cap is forced to 1 *specifically* for .ollamaCoder.
        for baseCap in [1, 2, 4, 8, 16] {
            #expect(AgentPipeline.effectiveCap(brain: .ollamaCoder, baseCap: baseCap) == 1,
                    "Ollama coder must run serial — baseCap=\(baseCap)")
        }
    }

    @Test func nonSerialBrainsUseTheBaseCap() {
        // After the app went local-only, every real brain is a serial local
        // model; `.none` (no brain reachable) is the only non-serial case, so it
        // is the one that honors the memory-derived base cap.
        for (baseCap, expected) in [(4, 4), (6, 6), (8, 8), (2, 2)] {
            #expect(AgentPipeline.effectiveCap(brain: .none, baseCap: baseCap) == expected,
                    ".none must honor baseCap=\(baseCap)")
        }
    }

    @Test func capIsFlooredAtOne() {
        // A degenerate baseCap (0 / negative from a misconfigured
        // MemoryManager) must not produce cap=0 — that would create an empty
        // `stride(by:)` batch list and hang the pipeline silently.
        #expect(AgentPipeline.effectiveCap(brain: .none, baseCap: 0)  == 1)
        #expect(AgentPipeline.effectiveCap(brain: .none, baseCap: -3) == 1)
    }
}
