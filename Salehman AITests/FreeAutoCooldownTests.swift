import Testing
import Foundation
@testable import Salehman_AI

// MARK: - FreeAutoCooldown — 120s window boundary + clear-on-success
//
// `generateFreeAuto` SKIPS a free brain that failed recently so a wrong/absent
// key doesn't waste a round-trip every prompt. Two properties matter:
//   1. The cooling window is exactly 120s from the last recorded failure.
//   2. A success clears the mark IMMEDIATELY so a self-healed brain isn't
//      penalized for the rest of the window.
// Each test instantiates its own `FreeAutoCooldown` actor — Swift Testing
// parallelizes by default, and using `.shared` would race other tests on the
// same `failedAt` dict.

struct FreeAutoCooldownTests {

    @Test func failureBlocksJustInsideTheWindow() async {
        let cool = LocalLLM.FreeAutoCooldown()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)

        await cool.recordFailure("Groq", now: t0)
        let inside = await cool.cooling(["Groq"], now: t0.addingTimeInterval(119.9))
        #expect(inside == ["Groq"])
    }

    @Test func failureClearsJustOutsideTheWindow() async {
        let cool = LocalLLM.FreeAutoCooldown()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)

        await cool.recordFailure("Groq", now: t0)
        let outside = await cool.cooling(["Groq"], now: t0.addingTimeInterval(120.1))
        #expect(outside.isEmpty)
    }

    @Test func successImmediatelyClearsTheMark() async {
        let cool = LocalLLM.FreeAutoCooldown()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)

        await cool.recordFailure("Mistral", now: t0)
        #expect(await cool.cooling(["Mistral"], now: t0.addingTimeInterval(1)) == ["Mistral"])

        await cool.recordSuccess("Mistral")
        // After a success, the brain rejoins the rotation immediately, even
        // though we're still inside the original 120 s cooling window.
        #expect(await cool.cooling(["Mistral"], now: t0.addingTimeInterval(30)).isEmpty)
    }

    @Test func neverFailedBrainsAreNotCooling() async {
        let cool = LocalLLM.FreeAutoCooldown()
        let now = Date()
        let set = await cool.cooling(["Groq", "Gemini", "Cerebras"], now: now)
        #expect(set.isEmpty)
    }
}
