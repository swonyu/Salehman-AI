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
        #expect(md.hasSuffix("_1 messages · 2 words_\n"))
        #expect(!md.contains("avg reply"))
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
