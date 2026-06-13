import Testing
import Foundation
@testable import Salehman_AI

// MARK: - AgentPipeline pure-function coverage
//
// These six static helpers are used by the multi-agent pipeline at runtime:
//
//   isErrorReply      — gates the rescue-with-working-brain retry logic
//   looksIncomplete   — drives the optional auto-continue loop
//   trimmedForLocal…  — context budget for 4096-ctx local models
//   recentTail        — most-recent suffix cut at a turn boundary
//   isSerialLocalBrain— OOM-prevention gate (forces serial cap=1)
//   buildPrompt       — per-agent prompt assembly
//
// All are `nonisolated static`, pure, and require no model calls — ideal for
// deterministic unit tests. None had prior coverage.

// MARK: - AgentPipeline.isErrorReply
//
// DISTINCT from OpenAICompatibleClient.isErrorReply (which is tested in
// CloudClientParsingTests). This one is the PIPELINE-level gate:
// it fires on empty replies, the model-offline sentinel, and the three
// bracketed diagnostic shapes emitted by every cloud client on failure.
// A false negative shows garbled text; a false positive silently discards
// a real answer.

struct AgentPipelineIsErrorReplyTests {

    @Test func emptyStringIsError() {
        #expect(AgentPipeline.isErrorReply(""))
    }

    @Test func whitespaceOnlyIsError() {
        // isErrorReply trims first; whitespace-only collapses to empty.
        #expect(AgentPipeline.isErrorReply("   \n  "),
                "whitespace-only reply must be treated as an error (trimmed empty)")
    }

    @Test func offMessageIsError() {
        // LocalLLM.offMessage is the canonical "no brain reachable" sentinel.
        #expect(AgentPipeline.isErrorReply(LocalLLM.offMessage))
    }

    @Test func normalAnswerIsNotError() {
        #expect(!AgentPipeline.isErrorReply("The capital of France is Paris."))
        #expect(!AgentPipeline.isErrorReply("Here is the Swift code you asked for."))
    }

    @Test func mentioningErrorMidSentenceIsNotError() {
        // The guard `t.hasPrefix("[")` ensures only bracketed diagnostics are caught.
        #expect(!AgentPipeline.isErrorReply("There was an error in your code; here is the fix."))
    }

    @Test func bracketedErrorWithStatusCode() {
        // Matches: starts with `[`, contains " error " + at least one digit.
        #expect(AgentPipeline.isErrorReply("[Grok error 500: Internal Server Error]"))
    }

    @Test func bracketedRequestFailed() {
        // Matches the "request failed (HTTP …)" diagnostic shape.
        #expect(AgentPipeline.isErrorReply("[Grok request failed (HTTP 401)]"))
    }

    @Test func bracketedCouldntComplete() {
        // Matches the on-device generation-failure shape.
        #expect(AgentPipeline.isErrorReply("[The on-device model couldn't complete the request]"))
    }

    @Test func bracketedButHarmlessNoteIsNotError() {
        // Starts with `[` but matches none of the three error patterns.
        #expect(!AgentPipeline.isErrorReply("[Note: this is just an observation]"))
    }
}

// MARK: - AgentPipeline.looksIncomplete
//
// Drives the auto-continue loop. CONSERVATIVE: only clear "to be continued"
// signals fire it. A false positive (continuing a finished answer) is worse
// than a false negative (not offering to continue a partial one).

struct AgentPipelineLooksIncompleteTests {

    @Test func emptyReplyIsFalse() {
        #expect(!AgentPipeline.looksIncomplete(""))
    }

    @Test func errorReplyIsFalse() {
        // Error text is never "incomplete" — looksIncomplete defers to isErrorReply.
        #expect(!AgentPipeline.looksIncomplete(LocalLLM.offMessage))
        #expect(!AgentPipeline.looksIncomplete("[vLLM error 503: unavailable]"))
    }

    @Test func completeAnswerIsFalse() {
        #expect(!AgentPipeline.looksIncomplete(
            "The capital of France is Paris. That's everything you asked for."))
    }

    @Test func toolCallLimitMessageIsTrue() {
        // The pipeline emits this exact phrasing when it hits its tool-call budget.
        #expect(AgentPipeline.looksIncomplete(
            "I reached the tool-call limit. Say \"continue\" to keep going."))
    }

    @Test func unclosedCodeFenceIsTrue() {
        // Odd ``` count = unclosed fence = the model was cut off mid-block.
        let reply = "Here is the code:\n```swift\nlet x = 1"
        #expect(AgentPipeline.looksIncomplete(reply),
                "reply with unclosed code fence must look incomplete")
    }

    @Test func closedCodeFenceIsFalse() {
        // Even ``` count = all fences closed = complete code block.
        let reply = "Here is the code:\n```swift\nlet x = 1\n```"
        #expect(!AgentPipeline.looksIncomplete(reply),
                "reply with matching code fences must NOT look incomplete")
    }

    @Test func shouldIContinueTailTriggerIsTrue() {
        // The offer phrase appears within the last 140 chars of the reply.
        let reply = "I've analyzed the first half of the requirements. Should I continue?"
        #expect(AgentPipeline.looksIncomplete(reply))
    }

    @Test func wordContinueInBodyDoesNotTrigger() {
        // "continue" alone is not in the offers list — only phrase forms fire.
        let reply = "You should continue developing this feature as planned."
        #expect(!AgentPipeline.looksIncomplete(reply))
    }
}

// MARK: - AgentPipeline.trimmedForLocalWindow
//
// Keeps the rolling history under the local-model context budget (4096 ctx)
// by dropping OLDEST lines first. Stops when lines.count == 2 (minimum) even
// if still over budget. The "(earlier context trimmed)" prefix flags the loss.

struct AgentPipelineTrimmedWindowTests {

    @Test func shortHistoryReturnedAsIs() {
        let h = "User: hi\nAssistant: hey"
        let result = AgentPipeline.trimmedForLocalWindow(h, budget: 500)
        #expect(result == h, "history within budget must be returned verbatim")
    }

    @Test func longHistoryPrependsTrimmedMarker() {
        let h = "User: hello\nAssistant: hi\nUser: how are you\nAssistant: great"
        let result = AgentPipeline.trimmedForLocalWindow(h, budget: 5)
        #expect(result.hasPrefix("(earlier context trimmed)\n"),
                "trimmed history must start with the trim-marker prefix")
        #expect(!result.contains("User: hello"),
                "oldest turn must be dropped when trimming fires")
    }

    @Test func mostRecentTurnsArePreserved() {
        let h = "User: old\nAssistant: old response\nUser: new message\nAssistant: new response"
        let result = AgentPipeline.trimmedForLocalWindow(h, budget: 5)
        // The while loop stops at lines.count == 2, so the last two lines survive.
        #expect(result.contains("new response"),
                "most-recent content must survive trimming")
    }

    @Test func twoLineMinimumIsRespected() {
        // Even with budget=5 and a two-line history that's far over budget,
        // the while condition `lines.count > 2` prevents removing either line.
        let h = "User: hello world today\nAssistant: hello back"
        let result = AgentPipeline.trimmedForLocalWindow(h, budget: 5)
        #expect(result.hasPrefix("(earlier context trimmed)\n"))
        let body = result.replacingOccurrences(of: "(earlier context trimmed)\n", with: "")
        let lines = body.components(separatedBy: "\n")
        #expect(lines.count == 2, "both lines must survive — two-line minimum is absolute")
    }
}

// MARK: - AgentPipeline.recentTail
//
// Most-recent suffix of a transcript, cut at a turn boundary (first `\n` found
// inside the suffix window) so no turn is sliced mid-thought. Falls back to a
// raw char cut when the suffix contains no newline — never returns empty.

struct AgentPipelineRecentTailTests {

    @Test func shortTextReturnedAsIs() {
        let text = "User: hi\nAssistant: hello"
        let result = AgentPipeline.recentTail(text, maxChars: 500)
        #expect(result == text, "text within budget must be returned unchanged")
    }

    @Test func longTextCutsAtFirstNewlineInSuffix() {
        // "AAAAAA\n" + 18×B = 25 chars. budget=20.
        // suffix(20) = "A\n" + 18×B  — first newline at position 1 inside the suffix.
        // Everything after it: 18×B.
        let text = "AAAAAA\n" + String(repeating: "B", count: 18)
        let result = AgentPipeline.recentTail(text, maxChars: 20)
        #expect(result == String(repeating: "B", count: 18),
                "result must be everything after the first newline in the suffix window")
        #expect(!result.contains("A"), "content before the line boundary must not appear")
    }

    @Test func longTextWithNoNewlineIsRawCharCut() {
        // A text with no newlines falls back to raw suffix(maxChars).
        let text = String(repeating: "X", count: 30)
        let result = AgentPipeline.recentTail(text, maxChars: 10)
        #expect(result == String(repeating: "X", count: 10),
                "no newline → raw char cut of exactly maxChars from the end")
    }

    @Test func newlineAtEndOfSuffixFallsBackToRawTail() {
        // If cut (everything after the newline) is empty, the function returns
        // the raw tail rather than an empty string.
        // Build: 17 A's + "\n" = 18 chars. budget=15.
        // suffix(15) = "AA…A\n" (14 A's + newline = 15 chars)
        // after newline: "" → empty → return tail (14 A's + "\n")
        let text = String(repeating: "A", count: 17) + "\n"
        let result = AgentPipeline.recentTail(text, maxChars: 15)
        #expect(!result.isEmpty, "must fall back to raw tail, never empty")
        #expect(result.count == 15)
    }
}

// MARK: - AgentPipeline.isSerialLocalBrain
//
// The OOM-prevention predicate. `true` → effectiveCap forces serial (cap=1).
// Missing a serial brain here would silently fan N requests into a shared-RAM
// server and risk crashing WindowServer on Apple Silicon.

struct AgentPipelineIsSerialLocalBrainTests {

    @Test func serialBrainsReturnTrue() {
        let serial: [LocalLLM.Brain] = [.ollamaCoder, .salehman, .unslothStudio, .vllm]
        for brain in serial {
            #expect(AgentPipeline.isSerialLocalBrain(brain),
                    "\(brain) must be serial — shared-RAM server cannot handle parallel requests")
        }
    }

    @Test func cloudBrainsReturnFalse() {
        let cloud: [LocalLLM.Brain] = [.cerebras, .gemini, .grok, .groq, .claudeHaiku,
                                       .codex, .copilot, .openRouter, .mistral]
        for brain in cloud {
            #expect(!AgentPipeline.isSerialLocalBrain(brain),
                    "\(brain) is a cloud brain and must NOT be classified as serial")
        }
    }

    @Test func orchestrationModesReturnFalse() {
        // ensemble, freeAuto, freeCoding, cloudCoding, none are pipeline modes,
        // not single-instance local servers.
        let modes: [LocalLLM.Brain] = [.ensemble, .freeAuto, .freeCoding, .cloudCoding, .none]
        for brain in modes {
            #expect(!AgentPipeline.isSerialLocalBrain(brain),
                    "\(brain) is an orchestration mode — must not be serial")
        }
    }
}

// MARK: - AgentPipeline.buildPrompt
//
// Assembles the per-agent prompt. The language-mirror rule, conciseness vs.
// full-response toggle, and history/context inclusion all live here — subtle
// drifts break agent coherence or blow the local context window.

struct AgentPipelineBuildPromptTests {

    private func makeSpec(name: String, role: String, full: Bool = false) -> AgentSpec {
        AgentSpec(name: name, icon: "🤖", role: role, full: full)
    }

    @Test func promptContainsAgentNameAndRole() {
        let spec = makeSpec(name: "Code Quality Guardian", role: "review code for safety issues")
        let p = AgentPipeline.buildPrompt(spec: spec, mission: "Fix the bug", history: "", context: "")
        #expect(p.contains("Code Quality Guardian"))
        #expect(p.contains("review code for safety issues"))
    }

    @Test func promptContainsMission() {
        let spec = makeSpec(name: "Analyst", role: "analyse")
        let p = AgentPipeline.buildPrompt(spec: spec, mission: "Summarize the quarterly results", history: "", context: "")
        #expect(p.contains("Summarize the quarterly results"))
    }

    @Test func fullFalseProducesConciseInstruction() {
        let spec = makeSpec(name: "A", role: "r", full: false)
        let p = AgentPipeline.buildPrompt(spec: spec, mission: "q", history: "", context: "")
        #expect(p.contains("Be concise"),
                "full=false must include the conciseness instruction")
        #expect(!p.contains("Write a complete, well-structured"),
                "full=false must NOT include the full-response instruction")
    }

    @Test func fullTrueProducesCompleteResponseInstruction() {
        let spec = makeSpec(name: "A", role: "r", full: true)
        let p = AgentPipeline.buildPrompt(spec: spec, mission: "q", history: "", context: "")
        #expect(p.contains("Write a complete, well-structured response."),
                "full=true must include the complete-response instruction")
    }

    @Test func historyAppearsWhenNonEmpty() {
        let spec = makeSpec(name: "A", role: "r")
        let p = AgentPipeline.buildPrompt(spec: spec, mission: "q",
                                          history: "User: previous question",
                                          context: "")
        #expect(p.contains("Recent conversation:"))
        #expect(p.contains("User: previous question"))
    }

    @Test func emptyHistoryOmitsHistorySection() {
        let spec = makeSpec(name: "A", role: "r")
        let p = AgentPipeline.buildPrompt(spec: spec, mission: "q", history: "", context: "")
        #expect(!p.contains("Recent conversation:"),
                "empty history must not produce a history section")
    }

    @Test func contextStringIsIncludedWhenNonEmpty() {
        let spec = makeSpec(name: "A", role: "r")
        let p = AgentPipeline.buildPrompt(spec: spec, mission: "q", history: "",
                                          context: "Prior agents found: 3 results")
        #expect(p.contains("Prior agents found: 3 results"))
    }

    @Test func promptContainsLanguageMirrorInstruction() {
        // The language-mirror rule is a hard invariant — without it, the agent
        // answers in English regardless of the user's language.
        let spec = makeSpec(name: "A", role: "r")
        let p = AgentPipeline.buildPrompt(spec: spec, mission: "q", history: "", context: "")
        #expect(p.contains("SAME language") || p.contains("same language"),
                "language-mirror instruction must be present in every agent prompt")
    }
}
