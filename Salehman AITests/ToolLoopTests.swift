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

    @Test func offlineHidesWebTools() {
        let n = Set(names(LocalLLM.ollamaToolSpecs(externalAllowed: false)))
        #expect(!n.contains("web_search"))
        #expect(!n.contains("fetch_url"))
        // Terminal + on-device tools remain available offline.
        #expect(n.contains("run_terminal_command"))
        #expect(n.contains("search_documents"))
    }

    @Test func onlineAddsExactlyTheTwoWebTools() {
        let offline = Set(names(LocalLLM.ollamaToolSpecs(externalAllowed: false)))
        let online = Set(names(LocalLLM.ollamaToolSpecs(externalAllowed: true)))
        #expect(online.subtracting(offline) == ["web_search", "fetch_url"])
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
        // Owner decision 2026-06-11: the picker is pared to EXACTLY Salehman + Auto
        // (Salehman cascades cloud→free→local itself, so the per-cloud entries were
        // clutter). Other cases still function when set programmatically (rotation).
        #expect(BrainPreference.selectableCases == [.salehman, .auto, .unslothStudio])
    }
}

// MARK: - stripNarration (Q3 local model "think out loud" scaffold removal)
//
// The local Q3 fine-tune sometimes emits meta-reasoning ("You are Salehman AI…",
// "Interpretation:…") then the real reply after a final "Response:". The stripper
// keeps only the real reply — and must NOT touch normal answers. Caught live
// 2026-06-11 when "hi" dumped the entire agent prompt into the chat.
struct StripNarrationTests {
    @Test func keepsOnlyTextAfterFinalResponse() {
        let leak = "You are Salehman AI in this conversation.\nThe most likely reading is greeting.\n\nResponse:\nGot it. What do you need?"
        #expect(AgentPipeline.stripNarration(leak) == "Got it. What do you need?")
    }
    @Test func normalReplyUntouched() {
        let ok = "Good code is correct, readable, and testable."
        #expect(AgentPipeline.stripNarration(ok) == ok)
        // A reply that merely mentions the word is not a scaffold (no "\nResponse:").
        let mentions = "The server returns a Response object you can inspect."
        #expect(AgentPipeline.stripNarration(mentions) == mentions)
    }
    @Test func doesNotStripToAnotherScaffold() {
        // If what follows is itself scaffold, leave the whole thing for the rescue path.
        let nested = "Reasoning…\nResponse:\nInterpretation: still analyzing"
        #expect(AgentPipeline.stripNarration(nested) == nested)
    }

    // Trailing meta — the fine-tune appends reviewer boilerplate + fake footnotes
    // after the real answer (caught live 2026-06-12: "Thoughts on this response?
    // I'm happy to rephrase…" + "[1]: https://github.com/…" after a greeting).
    @Test func cutsTrailingReviewerMetaAndFootnotes() {
        let leak = """
        Hi — what do you want to work on today?

        ---

        Thoughts on this response? I'm happy to rephrase / add more detail.

          [1]: https://github.com/SalehmanAI/MLX-Studio
        """
        #expect(AgentPipeline.stripNarration(leak) == "Hi — what do you want to work on today?")
    }
    @Test func cutsSelfContinuedDialogue() {
        let leak = "Sure, here's the plan.\nUser: hi\nSalehman AI: Hi again!"
        #expect(AgentPipeline.stripNarration(leak) == "Sure, here's the plan.")
    }
    @Test func neverStripsToNothing() {
        // A reply that is ONLY meta must come back unchanged, not empty.
        let onlyMeta = "Thoughts on this response? Happy to rephrase."
        #expect(AgentPipeline.stripNarration(onlyMeta) == onlyMeta)
    }

    // History sanitization on load (CodeView) — assistant turns are cleaned,
    // user turns are NEVER touched (a user might legitimately paste leak text).
    @Test func historySanitizerCleansAssistantOnly() {
        let t = Date()
        let leak = "Hi!\n\nThoughts on this response? Happy to rephrase.\n\n  [1]: https://x"
        let saved = [
            ChatMessage(id: UUID(), text: leak, isUser: true,  timestamp: t),   // user: untouched
            ChatMessage(id: UUID(), text: leak, isUser: false, timestamp: t),   // assistant: cleaned
        ]
        let out = CodeView.sanitizedHistory(saved)
        #expect(out[0].text == leak)
        #expect(out[1].text == "Hi!")
        #expect(out[1].id == saved[1].id)   // identity survives the rewrite
    }
}

// MARK: - Local-window history trim (14B num_ctx 4096 protection)
//
// Oversized prompts are truncated SERVER-side from the top — eating the persona.
// The trim must drop OLDEST turns first, keep the newest, and no-op under budget.
struct LocalWindowTrimTests {
    @Test func underBudgetIsUntouched() {
        let h = "User: hi\nSalehman AI: hey"
        #expect(AgentPipeline.trimmedForLocalWindow(h, budget: 1_000) == h)
    }
    @Test func overBudgetDropsOldestKeepsNewest() {
        let lines = (1...50).map { "User: message number \($0) with some padding text" }
        let h = lines.joined(separator: "\n")
        let out = AgentPipeline.trimmedForLocalWindow(h, budget: 400)
        #expect(out.hasPrefix("(earlier context trimmed)"))
        #expect(out.contains("message number 50"))      // newest survives
        #expect(!out.contains("message number 1 "))     // oldest dropped
        #expect(out.count <= 400 + 60)                  // budget + marker slack
    }
}

// MARK: - Complexity judges the ASK, not the Code-tab wrapper boilerplate
//
// The Code tab wraps every message in a long multi-line coding preamble ending in
// "Task: <ask>". complexity() must judge the ask — judging the whole wrapper rated
// EVERYTHING .hard (multi-line + >200 chars), so a 6-word question spun up all 15
// agents in Maximum mode. Caught by live functional QA 2026-06-11.
struct WrappedMissionComplexityTests {
    private static let preamble = """
    Project folder (your working directory for terminal + file edits): /Users/x/proj

    You are Salehman in CODING mode — an elite pair-programmer. Use the terminal and file edits to ACTUALLY do the work in the project folder (don't just describe it). Be precise and complete.

    Task:
    """
    @Test func wrappedShortQuestionIsSimple() {
        #expect(AgentPipeline.complexity(of: Self.preamble + "who are you in one sentence") == .simple)
    }
    @Test func wrappedRealCodingTaskStaysHard() {
        #expect(AgentPipeline.complexity(of: Self.preamble + "refactor the auth module and add tests") == .hard)
    }
    @Test func wrappedAttachedFileDoesNotInflateAShortAsk() {
        let m = Self.preamble + "what does this do\n\nAttached file \"x.swift\":\n" + String(repeating: "let x = 1\n", count: 200)
        #expect(AgentPipeline.complexity(of: m) != .hard)   // the ASK is short; the pasted file mustn't force the team
    }
}

// MARK: - AgentPipeline.looksIncomplete (auto-continue trigger)
//
// Drives the optional claude-autocontinue loop: it must fire on clear "to be
// continued" signals and stay QUIET on normal complete answers (a false positive
// would auto-loop "continue" on a finished reply).
struct AutoContinueDetectorTests {
    @Test func firesOnCutOffSignals() {
        #expect(AgentPipeline.looksIncomplete("…couldn't wrap it up. Say \"continue\" and I'll pick up where I left off."))
        #expect(AgentPipeline.looksIncomplete("(Reached the tool-call limit.)"))
        #expect(AgentPipeline.looksIncomplete("Here's the start:\n```swift\nfunc foo() {"))  // unterminated fence
        #expect(AgentPipeline.looksIncomplete("I've outlined the plan. Shall I continue?"))
    }

    @Test func quietOnCompleteAnswers() {
        #expect(!AgentPipeline.looksIncomplete("The capital of France is Paris."))
        #expect(!AgentPipeline.looksIncomplete("Done — here's the code:\n```swift\nlet x = 1\n```\nThat's everything."))
        #expect(!AgentPipeline.looksIncomplete(""))                  // empty ⇒ not continuable
        #expect(!AgentPipeline.looksIncomplete("[Groq error 429]"))  // error ⇒ handled elsewhere, not continued
    }
}
