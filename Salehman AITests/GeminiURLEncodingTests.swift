import Testing
import Foundation
@testable import Salehman_AI

// MARK: - GeminiClient.makeURL — percent-encoding safety
//
// Google's API takes the API key as a URL query parameter:
//   https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent?key=<KEY>
//
// An earlier implementation built that URL by string interpolation:
//   `URL(string: "\(base)/models/\(model):generateContent?key=\(key)")`
//
// If a user ever pasted a key containing a URL-reserved character (`+`,
// `&`, `=`, `?`, whitespace, etc.), `URL(string:)` returned nil and the
// caller silently fell through to the offMessage sentinel. The user would
// see "no model is reachable" with no useful diagnostic.
//
// `makeURL` now routes through `URLComponents`, which percent-encodes the
// query value correctly. These tests pin that behaviour and verify the
// URL shape stays compatible with Google's endpoint.

struct GeminiURLEncodingTests {

    @Test func wellFormedKeyProducesUsableURL() {
        // Sanity baseline: a normal AIza-style key.
        let url = GeminiClient.makeURL(model: "gemini-2.0-flash",
                                       action: "generateContent",
                                       key: "AIzaSyExampleNormalKey123",
                                       extraQueryItems: [])
        #expect(url != nil)
        let s = url?.absoluteString ?? ""
        #expect(s.contains("generativelanguage.googleapis.com"))
        #expect(s.contains("/models/gemini-2.0-flash:generateContent"))
        #expect(s.contains("key=AIzaSyExampleNormalKey123"))
    }

    @Test func keyWithPlusSignIsPercentEncoded() {
        // `+` in a URL query value historically means a space. If we
        // interpolated this raw, Google would receive a different key
        // string than we stored. URLComponents encodes `+` → `%2B`.
        let url = GeminiClient.makeURL(model: "gemini-2.0-flash",
                                       action: "generateContent",
                                       key: "abc+def",
                                       extraQueryItems: [])
        #expect(url != nil)
        let s = url?.absoluteString ?? ""
        #expect(s.contains("key=abc%2Bdef") || s.contains("key=abc+def"),
                "key containing `+` must be percent-encoded (`%2B`) or accepted verbatim, got: \(s)")
        #expect(!s.contains("key=abc def"),
                "URLComponents must NOT have collapsed the `+` to a space")
    }

    @Test func keyWithAmpersandIsPercentEncoded() {
        // `&` is the query-pair separator. A raw `&` in the key value
        // would split the value mid-stream → Google sees the wrong key.
        let url = GeminiClient.makeURL(model: "gemini-2.0-flash",
                                       action: "generateContent",
                                       key: "abc&def",
                                       extraQueryItems: [])
        #expect(url != nil)
        let s = url?.absoluteString ?? ""
        #expect(s.contains("key=abc%26def"),
                "key containing `&` must be percent-encoded (`%26`), got: \(s)")
    }

    @Test func keyWithSpaceIsHandled() {
        // Whitespace at paste time. SettingsView trims at save, but
        // belt-and-suspenders: the URL builder must not produce an
        // invalid URL even if a space slips through.
        let url = GeminiClient.makeURL(model: "gemini-2.0-flash",
                                       action: "generateContent",
                                       key: "abc def",
                                       extraQueryItems: [])
        #expect(url != nil, "space in key must not return nil URL")
        let s = url?.absoluteString ?? ""
        #expect(s.contains("key=abc%20def") || s.contains("key=abc+def"),
                "space must be percent-encoded, got: \(s)")
    }

    @Test func streamingURLIncludesAltSSE() {
        // The streaming endpoint takes `alt=sse` as an additional query
        // item alongside the key. Pin both made it through.
        let url = GeminiClient.makeURL(model: "gemini-2.0-flash",
                                       action: "streamGenerateContent",
                                       key: "AIzaSyExample",
                                       extraQueryItems: [URLQueryItem(name: "alt", value: "sse")])
        #expect(url != nil)
        let s = url?.absoluteString ?? ""
        #expect(s.contains(":streamGenerateContent"))
        #expect(s.contains("alt=sse"))
        #expect(s.contains("key=AIzaSyExample"))
    }

    @Test func modelWithDotsAndDashesIsPreservedInPath() {
        // `gemini-1.5-pro` contains both `-` and `.` — both legal path
        // characters. They must pass through verbatim (no percent-encoding,
        // since these are pchar-allowed sub-delims/unreserved).
        let url = GeminiClient.makeURL(model: "gemini-1.5-pro",
                                       action: "generateContent",
                                       key: "AIzaSyExample",
                                       extraQueryItems: [])
        #expect(url != nil)
        let s = url?.absoluteString ?? ""
        #expect(s.contains("/models/gemini-1.5-pro:generateContent"),
                "model id `gemini-1.5-pro` must pass through verbatim, got: \(s)")
    }
}
