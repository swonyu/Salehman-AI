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

    @Test(.disabled("needs an injectable recognition seam to inject competing partials"))
    func bestPartialReturnsLongestOfMultiplePartials() {}

    @Test(.disabled("needs a seam; start() would trigger real Screen-Recording/Speech TCC"))
    func staleRecognitionCallbackFromPriorSegmentIsIgnored() {}

    @Test(.disabled("needs an injectable recognition seam to assert the 0.11s publish throttle"))
    func publishPartialThrottlesToApprox9Hz() {}
}
