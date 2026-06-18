import Testing
import Foundation
@testable import Salehman_AI

// MARK: - MediaSearch.authenticityBiased — nationality-aware query relevance
//
// Appending a region's native-language term to a query improves authenticity
// (genuinely-regional content is tagged in its own language); the helper must be
// a no-op for queries without a known nationality and must not double-append.

struct MediaSearchQueryTests {
    @Test func appendsNativeTermForKnownNationality() {
        let out = MediaSearch.authenticityBiased("saudi cooking")
        #expect(out.contains("سعودية"))
        #expect(out.hasPrefix("saudi cooking"))   // original query preserved, term appended
    }

    @Test func isIdempotentWhenAlreadyLocalized() {
        let once = MediaSearch.authenticityBiased("korean street food")
        let twice = MediaSearch.authenticityBiased(once)
        #expect(once == twice)                     // doesn't stack the native term twice
    }

    @Test func leavesNonNationalityQueriesUntouched() {
        #expect(MediaSearch.authenticityBiased("sunset over mountains")
                == "sunset over mountains")
    }

    @Test func matchingIsCaseInsensitive() {
        #expect(MediaSearch.authenticityBiased("SAUDI desert").contains("سعودية"))
    }
}

// MARK: - MediaItem — display + playability derivations

struct MediaItemTests {
    @Test func directVideoFileDetection() {
        let mp4 = MediaItem(kind: .video, url: "https://cdn.example.com/clip.mp4")
        let page = MediaItem(kind: .video, url: "https://youtube.com/watch?v=abc")
        let image = MediaItem(kind: .image, url: "https://example.com/photo.mp4") // image kind wins
        #expect(mp4.isDirectVideoFile)
        #expect(!page.isDirectVideoFile)
        #expect(!image.isDirectVideoFile)
    }

    @Test func displayURLPrefersThumbnail() {
        let withThumb = MediaItem(kind: .image, url: "https://full/img.jpg",
                                  thumbnail: "https://proxy/thumb.jpg")
        let noThumb = MediaItem(kind: .image, url: "https://full/only.jpg")
        #expect(withThumb.displayURL == "https://proxy/thumb.jpg")
        #expect(noThumb.displayURL == "https://full/only.jpg")
    }

    @Test func codableRoundTripsThroughChatHistoryShape() throws {
        let item = MediaItem(kind: .video, url: "https://v/clip.mp4",
                             thumbnail: "https://v/poster.jpg", title: "Clip",
                             source: "example.com", width: 1280, height: 720, duration: "3:21")
        let data = try JSONEncoder().encode([item])
        let back = try JSONDecoder().decode([MediaItem].self, from: data)
        #expect(back == [item])
    }
}

// MARK: - MediaCapture — per-turn side-channel buffer

@MainActor
struct MediaCaptureTests {
    @Test func drainReturnsAndClears() {
        let cap = MediaCapture.shared
        cap.reset()
        cap.add([MediaItem(kind: .image, url: "a"), MediaItem(kind: .image, url: "b")])
        let drained = cap.drain()
        #expect(drained.count == 2)
        #expect(cap.drain().isEmpty)               // drained buffer is now empty
    }

    @Test func resetDiscardsPriorTurn() {
        let cap = MediaCapture.shared
        cap.add([MediaItem(kind: .video, url: "stale")])
        cap.reset()
        #expect(cap.drain().isEmpty)
    }
}

// MARK: - Deterministic intent (the fix for weak-3B tool-calling)
//
// The abliterated 3B often leaks a malformed tool call as plain text, so explicit
// media requests are detected + run in code. These pin that subject extraction
// keeps the real query (incl. adult terms + nationality) and that ordinary chat
// is NOT hijacked.

struct MediaIntentTests {
    @Test func bareAdultRequestIsBothKinds() {
        let intent = MediaSearch.detectIntent("i want saudi porn")
        #expect(intent?.kind == .both)
        #expect(intent?.query == "saudi porn")   // "i want" stripped; subject kept
    }

    @Test func picturesRequestIsImagesOnly() {
        let intent = MediaSearch.detectIntent("show me pictures of cats")
        #expect(intent?.kind == .images)
        #expect(intent?.query == "cats")
    }

    @Test func videosRequestIsVideosOnly() {
        let intent = MediaSearch.detectIntent("find videos of riyadh")
        #expect(intent?.kind == .videos)
        #expect(intent?.query == "riyadh")
    }

    @Test func ordinaryRequestIsNotHijacked() {
        // No media type, no adult term → must fall through to the model.
        #expect(MediaSearch.detectIntent("fix the bug in ContentView") == nil)
        #expect(MediaSearch.detectIntent("what's the capital of France?") == nil)
    }

    @Test func stripsThePipelinePreamble() {
        // The agent pipeline wraps the message; only the trailing Request matters.
        let wrapped = "Prior conversation:\nUser: hi\n\nRequest: show me nude photos of x"
        let intent = MediaSearch.detectIntent(wrapped)
        #expect(intent != nil)
        #expect(intent?.query.contains("x") == true)
        #expect(intent?.query.contains("prior") == false)   // preamble excluded
    }

    @Test func cleanedQueryKeepsAdultAndNationality() {
        // The whole point: command words go, the searchable subject stays.
        #expect(MediaSearch.cleanedQuery("show me egyptian porn") == "egyptian porn")
    }

    @Test func arabicAdultQueryIsDetected() {
        // The owner searches in Arabic for authentic results — the detector must
        // fire on Arabic adult terms (سكس = sex), not just English.
        let intent = MediaSearch.detectIntent("سكس سعوديه بالسياره")
        #expect(intent != nil)
        #expect(intent?.kind == .both)            // no صور/فيديو word → images + videos
        #expect(intent?.query.contains("سعوديه") == true)   // subject preserved
    }

    @Test func arabicMediaTypeWordSetsKind() {
        // صور = pictures → images-only; the type word is stripped from the query.
        let intent = MediaSearch.detectIntent("صور سعودية")
        #expect(intent?.kind == .images)
        #expect(intent?.query == "سعودية")
    }
}
