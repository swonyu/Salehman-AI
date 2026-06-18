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
