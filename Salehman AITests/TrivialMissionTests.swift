import Testing
import Foundation
@testable import Salehman_AI

// MARK: - AgentPipeline.isTrivialMission
//
// Guards the "casual chat → single agent" short-circuit. The function MUST stay
// conservative: a false positive (real task classified trivial) silently
// degrades a serious request to one agent, which is worse than the slowness it
// fixes. So the "real task" cases below matter more than the greeting cases.

struct TrivialMissionTests {

    // MARK: should short-circuit (trivial)

    @Test func greetingsAreTrivial() {
        for g in ["hello", "Hi", "hey!", "thanks", "ok", "Cool.", "how are you",
                  "what's up", "good morning", "test", "ping"] {
            #expect(AgentPipeline.isTrivialMission(g), "\"\(g)\" should be trivial")
        }
    }

    @Test func oneOrTwoPlainWordsAreTrivial() {
        #expect(AgentPipeline.isTrivialMission("yo"))
        #expect(AgentPipeline.isTrivialMission("nice job"))
    }

    // MARK: should NOT short-circuit (real tasks — the important direction)

    @Test func questionsAreNeverTrivial() {
        #expect(!AgentPipeline.isTrivialMission("what macOS version am I running?"))
        #expect(!AgentPipeline.isTrivialMission("hi?"))   // even a tiny question
    }

    @Test func imperativesWithThreePlusWordsAreNotTrivial() {
        #expect(!AgentPipeline.isTrivialMission("fix the bug"))
        #expect(!AgentPipeline.isTrivialMission("list my desktop files"))
        #expect(!AgentPipeline.isTrivialMission("change my wallpaper now"))
    }

    @Test func longOrMultilineInputIsNotTrivial() {
        #expect(!AgentPipeline.isTrivialMission(String(repeating: "a", count: 41)))
        #expect(!AgentPipeline.isTrivialMission("hello\nactually write me a function"))
    }

    @Test func codeOrDigitShapedShortInputIsNotTrivial() {
        #expect(!AgentPipeline.isTrivialMission("ls()"))      // code punctuation
        #expect(!AgentPipeline.isTrivialMission("buy 100"))   // has a digit
        #expect(!AgentPipeline.isTrivialMission("x = 1"))     // assignment
    }

    @Test func emptyOrWhitespaceIsNotTrivial() {
        // Empty input shouldn't even reach here, but guard it: not "trivial"
        // (the caller handles empty separately).
        #expect(!AgentPipeline.isTrivialMission(""))
        #expect(!AgentPipeline.isTrivialMission("    "))
    }
}

// MARK: - AgentPipeline.complexity — only .hard unlocks the 15-agent team
//
// The whole point of this layer: "who are u" must NOT spin up 15 agents, and
// only genuinely hard work should. The .hard direction is the safety-critical
// one — if a hard task is misjudged .simple it silently gets one agent.

struct MissionComplexityTests {

    @Test func greetingsAndShortQuestionsAreSimple() {
        for m in ["hello", "thanks", "who are u", "what's the weather",
                  "who made you", "what can you do"] {
            #expect(AgentPipeline.complexity(of: m) == .simple, "\"\(m)\" should be .simple")
        }
    }

    @Test func normalOneLineRequestsAreModerate() {
        // 7+ words, single sentence, no hard signal → reason+final weight.
        // (≤6 words is intentionally .simple, so these are deliberately longer.)
        #expect(AgentPipeline.complexity(of: "list the files on my desktop please") == .moderate)
        #expect(AgentPipeline.complexity(of: "tell me the current time in tokyo right now") == .moderate)
    }

    @Test func engineeringTasksAreHard() {
        for m in [
            "build me a SwiftUI login screen with validation",
            "refactor the networking layer to use async/await",
            "debug why the app crashes on launch",
            "analyze this codebase for memory leaks",
            "write a function that parses CSV",
        ] {
            #expect(AgentPipeline.complexity(of: m) == .hard, "\"\(m)\" should be .hard")
        }
    }

    @Test func codeOrMultilineOrLongInputIsHard() {
        #expect(AgentPipeline.complexity(of: "fix this: ```let x = {}```") == .hard)   // code fence
        #expect(AgentPipeline.complexity(of: "do this\nand also that") == .hard)        // multi-line
        #expect(AgentPipeline.complexity(of: String(repeating: "word ", count: 40)) == .hard) // long
    }

    @Test func multiSentenceRequestIsHard() {
        #expect(AgentPipeline.complexity(of: "I need a plan. Cover edge cases too.") == .hard)
    }
}
