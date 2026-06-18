import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Transcriber.canHandle — extension allowlist
//
// `canHandle` is the gatekeeper that decides whether a file URL is worth
// sending to the on-device Speech engine. An wrong extension set (e.g., a
// merged or mistyped string constant) would cause silent misrouting: audio
// files rejected, non-audio files accepted, or both.

struct TranscriberCanHandleTests {

    @Test func audioExtensionsReturnTrue() {
        let audio = ["m4a", "mp3", "wav", "aiff", "aif", "caf", "aac", "flac"]
        for ext in audio {
            #expect(Transcriber.canHandle(ext), "\(ext) must be handled")
        }
    }

    @Test func videoExtensionsReturnTrue() {
        let video = ["mp4", "mov", "m4v", "avi", "mkv"]
        for ext in video {
            #expect(Transcriber.canHandle(ext), "\(ext) must be handled")
        }
    }

    @Test func unknownExtensionsReturnFalse() {
        let unknown = ["pdf", "txt", "jpg", "png", "swift", "zip", ""]
        for ext in unknown {
            #expect(!Transcriber.canHandle(ext), "'\(ext)' must NOT be handled")
        }
    }

    @Test func audioAndVideoSetsAreMutuallyExclusive() {
        // No extension should appear in both sets — if it does, the routing
        // logic that uses these sets for branching (audio→Speech vs video→AVAsset)
        // would make an arbitrary choice.
        let overlap = Transcriber.audioExts.intersection(Transcriber.videoExts)
        #expect(overlap.isEmpty,
                "audioExts and videoExts must not overlap, found: \(overlap)")
    }
}

// MARK: - MediaTranscribe.detect — source classification
//
// `detect` is the entry point for all media pastes. It must:
//   1. Return `.youtube` for every YouTube URL variant.
//   2. Return `.remoteMedia` for direct media URLs (http/https + known extension).
//   3. Return `nil` for ordinary chat text (spaces), empty strings, very long strings.
//   4. Return `nil` for non-media URLs (no recognized extension).
//
// The local-file path is NOT tested because `detect` calls `FileManager.fileExists`
// and no such file would exist in the test environment — so that branch always
// returns nil in CI, which is expected.

struct MediaDetectTests {

    // MARK: YouTube detection

    // Helper: test that detect() returns a .youtube case.
    private func isYouTube(_ raw: String) -> Bool {
        if case .youtube? = MediaTranscribe.detect(raw) { return true }
        return false
    }
    // Helper: test that detect() returns a .remoteMedia case.
    private func isRemoteMedia(_ raw: String) -> Bool {
        if case .remoteMedia? = MediaTranscribe.detect(raw) { return true }
        return false
    }

    @Test func detectsYouTubeWatchURL() {
        #expect(isYouTube("https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                "youtube.com/watch must be detected as .youtube")
    }

    @Test func detectsYouTuBeShortURL() {
        #expect(isYouTube("https://youtu.be/dQw4w9WgXcQ"),
                "youtu.be/ must be detected as .youtube")
    }

    @Test func detectsYouTubeShortsURL() {
        #expect(isYouTube("https://www.youtube.com/shorts/abc123"),
                "youtube.com/shorts must be detected as .youtube")
    }

    @Test func detectsMobileYouTubeURL() {
        #expect(isYouTube("https://m.youtube.com/watch?v=abc123"),
                "m.youtube.com/watch must be detected as .youtube")
    }

    // MARK: Remote media URL detection

    @Test func detectsDirectMP3URL() {
        #expect(isRemoteMedia("https://cdn.example.com/episode.mp3"),
                "direct .mp3 URL must be detected as .remoteMedia")
    }

    @Test func detectsDirectMP4URL() {
        #expect(isRemoteMedia("https://cdn.example.com/clip.mp4"),
                "direct .mp4 URL must be detected as .remoteMedia")
    }

    @Test func nonMediaURLReturnsNil() {
        // A plain HTTPS URL with no recognized media extension is not transcribable.
        #expect(MediaTranscribe.detect("https://example.com") == nil,
                "URL without media extension must return nil")
        #expect(MediaTranscribe.detect("https://example.com/page.html") == nil,
                ".html URL must return nil")
    }

    // MARK: Plain text / edge cases → nil

    @Test func plainTextWithSpacesReturnsNil() {
        // The guard `!t.contains(" ")` immediately rejects ordinary sentences.
        #expect(MediaTranscribe.detect("Please transcribe this audio file") == nil)
        #expect(MediaTranscribe.detect("  ") == nil)
    }

    @Test func emptyStringReturnsNil() {
        #expect(MediaTranscribe.detect("") == nil)
    }

    @Test func veryLongStringReturnsNil() {
        // Strings > 2048 chars are rejected before any URL check.
        let long = String(repeating: "a", count: 2049)
        #expect(MediaTranscribe.detect(long) == nil,
                "strings > 2048 chars must return nil immediately")
    }

    @Test func borderLengthStringsAreHandledCorrectly() {
        // 2048 chars is the upper limit — below is acceptable, at-or-above is rejected.
        let at2048 = String(repeating: "a", count: 2048)
        // At exactly 2048: t.count < 2048 is false → nil.
        #expect(MediaTranscribe.detect(at2048) == nil,
                "string of exactly 2048 chars must be rejected (strict less-than)")
        // 2047 chars: passes the length guard, but is not a recognizable URL → also nil.
        let below2048 = String(repeating: "a", count: 2047)
        #expect(MediaTranscribe.detect(below2048) == nil,
                "2047-char non-URL must still return nil (fails URL parsing)")
    }
}
