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
        #expect(AgentPipeline.effectiveCap(brain: .cerebras, baseCap: 8) == 8)
        #expect(AgentPipeline.effectiveCap(brain: .ensemble, baseCap: 4) == 4)
    }

    @Test func baseCapFlooredAtOne() {
        #expect(AgentPipeline.effectiveCap(brain: .cerebras, baseCap: 0) == 1)
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
        // 2026-06-18: + Uncensored (local abliterated ~3B, web-search capable) — free,
        // on-device, so it stays out of the paid set above.
        #expect(BrainPreference.selectableCases == [.salehman, .auto, .unslothStudio, .uncensored])
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

// MARK: - AgentPipeline.isErrorReply (direct unit tests)
//
// `SalehmanLeaderTests.FinalizeErrorBypassTests` tests the guard via
// `SalehmanLeader.finalize`, but that path falls through to "return draft" any
// time the engine is unreachable — which is always in CI. These tests hit the
// pure predicate directly so the assertion is unambiguous: the guard fires
// because `isErrorReply` returns true, NOT because the engine produced "".

struct IsErrorReplyTests {

    @Test func emptyStringIsAnError() {
        #expect(AgentPipeline.isErrorReply(""))
        #expect(AgentPipeline.isErrorReply("   "))
    }

    @Test func bracketedProviderErrorIsAnError() {
        // The "[<Provider> error <STATUS>: …]" shape produced by every
        // OpenAI-compatible client on a non-2xx response.
        #expect(AgentPipeline.isErrorReply("[Groq error 429: rate limit exceeded]"))
        #expect(AgentPipeline.isErrorReply("[Mistral error 401: unauthorized]"))
        #expect(AgentPipeline.isErrorReply("[OpenRouter error 503: service unavailable]"))
    }

    @Test func requestFailedIsAnError() {
        // Transport failure shape "[<Provider> request failed (HTTP <STATUS>). …]"
        #expect(AgentPipeline.isErrorReply("[Mistral request failed (HTTP 503). Retry in a moment.]"))
        #expect(AgentPipeline.isErrorReply("[Groq request failed (HTTP 408). Retry in a moment.]"))
    }

    @Test func onDeviceCouldntCompleteIsAnError() {
        // "[The on-device model couldn't complete …]" — covered by
        // LocalLLM.freeAnswerErrorMarkers; isErrorReply now matches it too.
        #expect(AgentPipeline.isErrorReply("[The on-device model couldn't complete the request]"))
        #expect(AgentPipeline.isErrorReply("[The on-device model couldn't complete the task: timeout]"))
    }

    @Test func realAnswersAreNotErrors() {
        #expect(!AgentPipeline.isErrorReply("The capital of France is Paris."))
        #expect(!AgentPipeline.isErrorReply("Here's a fix for your bug."))
        // A real answer that contains the word "error" but isn't bracketed.
        #expect(!AgentPipeline.isErrorReply("There was an error in your logic — see line 4."))
        // Bracketed text that isn't an error sentinel.
        #expect(!AgentPipeline.isErrorReply("[OK] The server is running."))
        #expect(!AgentPipeline.isErrorReply("[DONE] All tests passed."))
    }
}

// MARK: - withConversationContext (mission + rolling history wrapper)
//
// Every AgentPipeline.run call uses this to inject conversation context into
// the single-string mission that gets handed to the local brain. A bug here
// either drops the history (model sees each turn in isolation) or garbles
// the mission/history ordering (model "answers" the history instead of the ask).
struct WithConversationContextTests {

    @Test func emptyHistoryReturnsMissionUnchanged() {
        let m = AgentPipeline.withConversationContext("What is 2+2?", history: "")
        #expect(m == "What is 2+2?")
    }

    @Test func whitespaceHistoryReturnsMissionUnchanged() {
        let m = AgentPipeline.withConversationContext("tell me more", history: "   \n\t  ")
        #expect(m == "tell me more")
    }

    @Test func nonEmptyHistoryWrapsInContextAndMissionLabels() {
        let m = AgentPipeline.withConversationContext("follow-up", history: "User: hi\nAI: hello")
        #expect(m.contains("Conversation so far"))
        #expect(m.contains("New message from the user"))
        #expect(m.contains("follow-up"))
        #expect(m.contains("User: hi\nAI: hello"))
    }

    @Test func historyAppearsBeforeMissionInOutput() {
        let m = AgentPipeline.withConversationContext("the actual ask", history: "User: prior turn")
        let historyRange  = m.range(of: "User: prior turn")!
        let missionRange  = m.range(of: "the actual ask")!
        #expect(historyRange.lowerBound < missionRange.lowerBound,
                "history must appear before the new mission in the wrapped string")
    }

    @Test func hugeHistoryIsTrimmmedForLocalBrain() {
        // SalehmanEngine.hasAnyCloud is hardcoded false → diet always applies.
        // A history larger than localHistoryCharBudget (9000) must be trimmed.
        let bigHistory = String(repeating: "User: padding turn\n", count: 600)  // ~12k chars
        let m = AgentPipeline.withConversationContext("ask", history: bigHistory)
        #expect(m.contains("(earlier context trimmed)"),
                "over-budget history must carry the trim marker")
    }
}

// MARK: - isSerialLocalBrain (OOM-prevention gate)
//
// `isSerialLocalBrain` is the canonical list of brains that run SERIALLY —
// any brain missing from this list would silently fan out concurrent Ollama
// calls and risk OOM-crashing WindowServer. Adding `.vllm` or `.unslothStudio`
// requires them to appear here; this test catches the omission before it ships.
struct IsSerialLocalBrainTests {

    @Test func serialBrainsAreExactlyTheFourLocalModels() {
        let serial: [LocalLLM.Brain] = [.ollamaCoder, .salehman, .unslothStudio, .vllm]
        for b in serial {
            #expect(AgentPipeline.isSerialLocalBrain(b), "\(b) must be serial")
        }
    }

    @Test func cloudAndEnsembleBrainsAreNotSerial() {
        let nonSerial: [LocalLLM.Brain] = [.groq, .gemini, .cerebras, .mistral, .ensemble, .freeAuto, .freeCoding, .claudeHaiku, .none]
        for b in nonSerial {
            #expect(!AgentPipeline.isSerialLocalBrain(b), "\(b) must not be serial")
        }
    }

    @Test func effectiveCapMirrosIsSerialLocalBrain() {
        // Sanity guard: effectiveCap must force serial (cap==1) for every brain
        // that isSerialLocalBrain returns true for — the two must agree.
        let serial: [LocalLLM.Brain] = [.ollamaCoder, .salehman, .unslothStudio, .vllm]
        for b in serial {
            #expect(AgentPipeline.effectiveCap(brain: b, baseCap: 8) == 1,
                    "\(b) effectiveCap must be 1 even with baseCap 8")
        }
    }
}

// MARK: - buildPrompt (per-agent prompt assembly)
//
// `buildPrompt` wires every agent's identity (name, role), user request,
// conversation context, and length rule into the single string that is sent
// to the LLM. A bug here affects every agent in the pipeline — wrong spec.name
// would make the model answer as a different persona; missing history means the
// model answers blind; wrong length rule (full vs terse) floods the chat with
// long parallel answers or truncates a full-answer agent mid-thought.
struct BuildPromptTests {

    private static let terseSpec = AgentSpec(
        name: "Test Analyst", icon: "star",
        role: "analyse the request for correctness", full: false
    )
    private static let fullSpec = AgentSpec(
        name: "Summarizer", icon: "doc",
        role: "write a complete summary", full: true
    )

    @Test func containsSpecNameAndRole() {
        let p = AgentPipeline.buildPrompt(spec: Self.terseSpec, mission: "Q", history: "", context: "")
        #expect(p.contains("Test Analyst"))
        #expect(p.contains("analyse the request for correctness"))
    }

    @Test func containsMission() {
        let p = AgentPipeline.buildPrompt(spec: Self.terseSpec, mission: "What is 42?", history: "", context: "")
        #expect(p.contains("What is 42?"))
    }

    @Test func emptyHistoryProducesNoConversationHeader() {
        let p = AgentPipeline.buildPrompt(spec: Self.terseSpec, mission: "Q", history: "", context: "")
        #expect(!p.contains("Recent conversation:"))
    }

    @Test func nonEmptyHistoryAppearsUnderRecentConversation() {
        let p = AgentPipeline.buildPrompt(spec: Self.terseSpec, mission: "Q",
                                          history: "User: hi\nAI: hey", context: "")
        #expect(p.contains("Recent conversation:"))
        #expect(p.contains("User: hi\nAI: hey"))
    }

    @Test func nonEmptyContextAppearsInOutput() {
        let p = AgentPipeline.buildPrompt(spec: Self.terseSpec, mission: "Q", history: "",
                                          context: "File context: foo.swift")
        #expect(p.contains("File context: foo.swift"))
    }

    @Test func fullSpecGetsCompleteResponseRule() {
        let p = AgentPipeline.buildPrompt(spec: Self.fullSpec, mission: "Q", history: "", context: "")
        #expect(p.contains("Write a complete, well-structured response."))
        #expect(!p.contains("Be concise:"))
    }

    @Test func terseSpecGetsConciseRule() {
        let p = AgentPipeline.buildPrompt(spec: Self.terseSpec, mission: "Q", history: "", context: "")
        #expect(p.contains("Be concise:"))
        #expect(!p.contains("Write a complete, well-structured response."))
    }
}
