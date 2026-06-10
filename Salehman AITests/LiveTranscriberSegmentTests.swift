import Testing
import Foundation
@testable import Salehman_AI

// MARK: - LiveTranscriber recycle / segment / partial surface
//
// The real recycle / segment-increment / 0.11s-throttle / stale-drop contracts
// live behind PRIVATE state driven by a live ScreenCaptureKit + Speech stream.
// Without an injectable recognition seam they can't be exercised in a unit test —
// and calling start()/toggle() would fire real Screen-Recording + Speech (TCC)
// permission prompts and leave the shared singleton mid-capture. So those cases
// are honestly `.disabled` until a seam exists (matching BrainRoutingDispatch /
// PersistenceRoundTrip / SettingsBrainReady), rather than shipped as green
// tautologies like `#expect(!isRunning || isRunning)` (see the 2026-06-06 review).
// One safe, falsifiable contract is kept active.

struct LiveTranscriberSegmentTests {

    @Test @MainActor
    func stopIsSafeAndLeavesTranscriberIdle() {
        // stop() is the only capture-control call safe to make without ever
        // starting (no TCC), and "after stop the transcriber is not running" is a
        // real, falsifiable contract. Calling it twice also pins idempotence.
        let t = LiveTranscriber.shared
        t.stop()
        #expect(t.isRunning == false)
        t.stop()
        #expect(t.isRunning == false)
    }

    @Test(.disabled("needs an injectable recognition seam to feed .isFinal/partial without real capture"))
    func afterCommitRecsRepopulatedWhileCapturingRemainsTrue() {}

    @Test(.disabled("needs an injectable recognition seam to drive two .isFinal callbacks"))
    func feedingTwoFinalResultsProducesTwoSegments() {}

    // Now testable: the partial-selection logic was extracted into the pure static
    // `LiveTranscriber.longestPartial(_:)`, so we can exercise it without a live stream.
    @Test func bestPartialReturnsLongestOfMultiplePartials() {
        // The stronger (longest) hypothesis across recognizers wins.
        #expect(LiveTranscriber.longestPartial(["hi", "hello there", "hey"]) == "hello there")
        // Single recognizer → itself; none → empty.
        #expect(LiveTranscriber.longestPartial(["only one"]) == "only one")
        #expect(LiveTranscriber.longestPartial([]) == "")
        // Empty strings don't beat real text.
        #expect(LiveTranscriber.longestPartial(["", "x", ""]) == "x")
    }

    @Test(.disabled("needs a seam; start() would trigger real Screen-Recording/Speech TCC"))
    func staleRecognitionCallbackFromPriorSegmentIsIgnored() {}

    // Now testable: the 0.11s ≈ 9 Hz throttle gate was extracted into the pure static
    // `LiveTranscriber.shouldPublishPartial(...)`, so we can assert it without a live stream.
    @Test func publishPartialThrottlesToApprox9Hz() {
        let interval = 0.11   // ~9 Hz
        // Too soon since last publish → suppressed, even though the text changed.
        #expect(LiveTranscriber.shouldPublishPartial(
            text: "new", lastPublished: "old", now: 1.05, lastPublishAt: 1.0,
            minInterval: interval) == false)
        // Enough time elapsed AND text changed → publish.
        #expect(LiveTranscriber.shouldPublishPartial(
            text: "new", lastPublished: "old", now: 1.20, lastPublishAt: 1.0,
            minInterval: interval) == true)
        // Same text never republishes, no matter how much time passed.
        #expect(LiveTranscriber.shouldPublishPartial(
            text: "same", lastPublished: "same", now: 99.0, lastPublishAt: 1.0,
            minInterval: interval) == false)
        // Exactly at the boundary counts as elapsed (>=).
        #expect(LiveTranscriber.shouldPublishPartial(
            text: "new", lastPublished: "old", now: 1.0 + interval, lastPublishAt: 1.0,
            minInterval: interval) == true)
    }
}
