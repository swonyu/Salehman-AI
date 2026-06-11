import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Chat transcript pure logic — exporter format
//
// `ChatExporter.markdown` is `nonisolated` and pure on its inputs. Dates
// render locale-formatted, so these tests pin STRUCTURE (heading rule,
// attachment lines, stats footer) — never exact date strings.

struct ChatExporterFormatTests {

    private func msg(_ text: String, user: Bool, at t: TimeInterval = 1_000,
                     image: String? = nil, duration: Double? = nil) -> ChatMessage {
        ChatMessage(id: UUID(), text: text, isUser: user,
                    timestamp: Date(timeIntervalSince1970: t),
                    imagePath: image, duration: duration)
    }

    @Test func headingUsesFirstUserLineLikeHistorySheet() {
        let md = ChatExporter.markdown([
            msg("Plan my week\nwith details", user: true),
            msg("Sure — here's a plan.", user: false),
        ])
        #expect(md.hasPrefix("# Plan my week\n"))
    }

    @Test func attachmentsAppearByFilename() {
        let md = ChatExporter.markdown([
            msg("look at this", user: true, image: "/tmp/shots/screen 1.png"),
        ])
        #expect(md.contains("📎 `screen 1.png`"))
    }

    @Test func footerCountsMessagesWordsAndAvgReply() {
        let md = ChatExporter.markdown([
            msg("one two three", user: true, at: 100),
            msg("four five", user: false, at: 200, duration: 1.0),
            msg("six seven", user: false, at: 300, duration: 3.0),
        ])
        #expect(md.hasSuffix("_3 messages · 7 words · avg reply 2.0s_\n"))
    }

    @Test func noDurationsMeansNoAvgReplySegment() {
        let md = ChatExporter.markdown([msg("hi there", user: true)])
        #expect(md.hasSuffix("_1 message · 2 words_\n"))   // singular, no "1 messages"
        #expect(!md.contains("avg reply"))
        #expect(!md.contains(" – "))   // no "X – X" range for a single message
    }

    @Test func emptyConversationStaysWellFormed() {
        let md = ChatExporter.markdown([])
        #expect(md.hasPrefix("# Conversation\n"))
        #expect(md.hasSuffix("_0 messages · 0 words_\n"))
    }

    @Test func dateRangeLineAppearsForNonEmpty() {
        let md = ChatExporter.markdown([msg("a", user: true, at: 100),
                                        msg("b", user: false, at: 999_999)])
        let lines = md.components(separatedBy: "\n")
        // Line 0 = "# …", line 1 = "", line 2 = "_<start> – <end>_".
        #expect(lines.count > 2 && lines[2].hasPrefix("_") && lines[2].contains(" – "))
    }
}

// MARK: - /stats summarizer

struct ChatStatsTests {

    private func msg(_ text: String, user: Bool, at t: TimeInterval = 1_000,
                     duration: Double? = nil) -> ChatMessage {
        ChatMessage(id: UUID(), text: text, isUser: user,
                    timestamp: Date(timeIntervalSince1970: t), duration: duration)
    }

    @Test func summarizeCountsSidesWordsAvgAndSpan() {
        let s = ChatStats.summarize([
            msg("one two", user: true, at: 0),
            msg("three four five", user: false, at: 60, duration: 2.0),
            msg("six", user: true, at: 120),
            msg("seven eight", user: false, at: 300, duration: 4.0),
        ])
        #expect(s.messages == 4 && s.yours == 2 && s.replies == 2)
        #expect(s.words == 8)
        #expect(s.avgReplySeconds == 3.0)
        #expect(s.spanSeconds == 300)
    }

    @Test func noDurationsAndSingleMessageGiveNils() {
        let s = ChatStats.summarize([msg("hello", user: true)])
        #expect(s.avgReplySeconds == nil)
        #expect(s.spanSeconds == nil)
    }

    @Test func humanizerBoundaries() {
        #expect(ChatStats.human(59) == "59s")
        #expect(ChatStats.human(60) == "1m")
        #expect(ChatStats.human(3_600) == "1h")
        #expect(ChatStats.human(5_400) == "1h 30m")
        #expect(ChatStats.human(86_400) == "1d")
        #expect(ChatStats.human(90_000) == "1d 1h")
    }

    @Test func blurbPinsExactFormat() {
        let s = ChatStats.summarize([
            msg("one two", user: true, at: 0),
            msg("three", user: false, at: 90, duration: 1.5),
        ])
        #expect(s.blurb == "2 messages — 1 yours, 1 reply\n3 words · avg reply 1.5s · spans 1m")
    }

    @Test func emptyConversationBlurbIsCalm() {
        #expect(ChatStats.summarize([]).blurb == "0 messages — 0 yours, 0 replies\n0 words")
    }
}

// MARK: - Pinned messages

struct ChatPinTests {

    private func msg(_ text: String, user: Bool = true, pinned: Bool? = nil) -> ChatMessage {
        ChatMessage(id: UUID(), text: text, isUser: user,
                    timestamp: Date(timeIntervalSince1970: 0), pinned: pinned)
    }

    /// Pre-pin history must decode unchanged — this is WHY the field is
    /// `Bool?` and not a defaulted `Bool` (synthesized Codable would throw
    /// keyNotFound on every archived conversation).
    @Test func legacyJSONWithoutPinnedKeyDecodes() throws {
        let legacy = #"[{"id":"00000000-0000-0000-0000-000000000001","text":"hi","isUser":true,"timestamp":0}]"#
        let msgs = try JSONDecoder().decode([ChatMessage].self, from: Data(legacy.utf8))
        #expect(msgs.count == 1 && msgs[0].pinned == nil)
    }

    @Test func pinnedRoundTripsThroughCoding() throws {
        let original = [msg("keep this", pinned: true), msg("normal")]
        let decoded = try JSONDecoder().decode([ChatMessage].self,
                                               from: JSONEncoder().encode(original))
        #expect(decoded[0].pinned == true)
        #expect(decoded[1].pinned == nil)
    }

    @Test func togglingPinFlipsThenClearsToAbsent() {
        let a = msg("a"), b = msg("b")
        let once = ChatViewModel.togglingPin(in: [a, b], id: b.id)
        #expect(once[1].pinned == true && once[0].pinned == nil)
        let twice = ChatViewModel.togglingPin(in: once, id: b.id)
        #expect(twice[1].pinned == nil)   // back to ABSENT, not false
    }

    @Test func togglingPinUnknownIdIsNoOp() {
        let list = [msg("a")]
        #expect(ChatViewModel.togglingPin(in: list, id: UUID()) == list)
    }

    @Test func pinPreviewTrimsToFirstLineAndWidth() {
        #expect(ContentView.pinPreview("short line") == "short line")
        #expect(ContentView.pinPreview("first\nsecond") == "first")
        let p = ContentView.pinPreview(String(repeating: "word ", count: 20))
        #expect(p.hasSuffix("…") && p.count <= 41)
    }
}

// MARK: - History sheet title filter

struct ChatHistoryFilterTests {

    private func arc(_ title: String) -> ChatStore.ArchivedChat {
        ChatStore.ArchivedChat(id: URL(fileURLWithPath: "/tmp/\(UUID()).json"),
                               title: title, date: Date(timeIntervalSince1970: 0),
                               messageCount: 1)
    }

    @Test func blankQueryReturnsEverything() {
        let all = [arc("Plan my week"), arc("Fix the build")]
        #expect(ChatHistoryView.filtered(all, query: "").count == 2)
        #expect(ChatHistoryView.filtered(all, query: "   ").count == 2)
    }

    @Test func matchesCaseAndDiacriticInsensitively() {
        let all = [arc("Café notes"), arc("Fix the build")]
        #expect(ChatHistoryView.filtered(all, query: "cafe").map(\.title) == ["Café notes"])
        #expect(ChatHistoryView.filtered(all, query: "BUILD").map(\.title) == ["Fix the build"])
    }

    @Test func noMatchIsEmptyNotEverything() {
        #expect(ChatHistoryView.filtered([arc("Plan my week")], query: "zzz").isEmpty)
    }
}

// MARK: - Composer length readout

struct ComposerCountTests {

    @Test func quietBelowTheFloor() {
        #expect(ContentView.composerCount("just a short draft") == nil)
        #expect(ContentView.composerCount("") == nil)
    }

    @Test func labelsAtTheFloorWithoutWarning() {
        let draft = Array(repeating: "w", count: 120).joined(separator: " ")
        let c = ContentView.composerCount(draft)
        #expect(c?.label == "120 words" && c?.warn == false)
    }

    @Test func warnsAtTheBudget() {
        let draft = Array(repeating: "w", count: 2_000).joined(separator: "\n")
        let c = ContentView.composerCount(draft)
        #expect(c?.label == "2000 words" && c?.warn == true)
    }
}
