import Testing
import Foundation
import SwiftUI   // search-highlight tests inspect the .backgroundColor attribute
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
        // approxTokens = Int(3 * 1.3 rounded) = 4; longestReplyWords = 1 ("three")
        #expect(s.blurb == "2 messages — 1 yours, 1 reply\n3 words · ~4 tok · longest: 1w · avg reply 1.5s · spans 1m")
    }

    @Test func emptyConversationBlurbIsCalm() {
        // approxTokens = 0; longestReplyWords = nil (no replies) → no "longest:" segment
        #expect(ChatStats.summarize([]).blurb == "0 messages — 0 yours, 0 replies\n0 words · ~0 tok")
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

// MARK: - Transcript cadence (separators + grouping)

struct TranscriptCadenceTests {

    private let cal = Calendar.current
    /// Calendar-built dates (not raw epochs) so day boundaries hold in any zone.
    private func at(_ h: Int, _ m: Int = 0, day: Int = 11) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: day, hour: h, minute: m))!
    }
    private func msg(_ d: Date, user: Bool = true) -> ChatMessage {
        ChatMessage(id: UUID(), text: "x", isUser: user, timestamp: d)
    }

    @Test func separatorAfter30MinGapOrDayChange() {
        let a = msg(at(12, 0))
        #expect(ContentView.needsSeparator(prev: nil, curr: a) == false)
        #expect(ContentView.needsSeparator(prev: a, curr: msg(at(12, 29))) == false)
        #expect(ContentView.needsSeparator(prev: a, curr: msg(at(12, 31))) == true)
        #expect(ContentView.needsSeparator(prev: a, curr: msg(at(12, 0, day: 12))) == true)
    }

    @Test func groupBreaksOnSenderFlipOr5MinGap() {
        let list = [msg(at(12, 0), user: true),
                    msg(at(12, 1), user: true),
                    msg(at(12, 2), user: false),
                    msg(at(12, 10), user: false)]
        #expect(ContentView.isFirstInGroup(idx: 0, list: list))
        #expect(!ContentView.isFirstInGroup(idx: 1, list: list))   // same sender, 1 min
        #expect(ContentView.isFirstInGroup(idx: 2, list: list))    // sender flip
        #expect(ContentView.isFirstInGroup(idx: 3, list: list))    // 8 min > 5 min
    }
}

// MARK: - /connect server-URL normalizer

struct ConnectURLTests {

    @Test func addsSchemeAndV1() {
        #expect(ContentView.normalizedServerURL("abc-def.trycloudflare.com")
                == "https://abc-def.trycloudflare.com/v1")
    }

    @Test func stripsTrailingSlashesAndKeepsExistingV1() {
        #expect(ContentView.normalizedServerURL("https://x.trycloudflare.com/")
                == "https://x.trycloudflare.com/v1")
        #expect(ContentView.normalizedServerURL("http://localhost:11434/v1")
                == "http://localhost:11434/v1")
    }

    @Test func rejectsJunk() {
        #expect(ContentView.normalizedServerURL("") == nil)
        #expect(ContentView.normalizedServerURL("   ") == nil)
        #expect(ContentView.normalizedServerURL("not a url") == nil)
        #expect(ContentView.normalizedServerURL("ftp://x.com") == nil)
    }
}

// MARK: - Quote-block split (user rows)

struct QuoteSplitTests {

    @Test func plainTextHasNoQuote() {
        #expect(MessageBubble.splitLeadingQuote("just text") == nil)
        #expect(MessageBubble.splitLeadingQuote("mid > quote") == nil)
    }

    @Test func quoteThenBodySplits() {
        let s = MessageBubble.splitLeadingQuote("> a\n> b\n\nreply text")
        #expect(s?.quote == "a\nb")
        #expect(s?.body == "reply text")
    }

    @Test func bareAngleAndQuoteOnlyWork() {
        let tight = MessageBubble.splitLeadingQuote(">tight\nbody")
        #expect(tight?.quote == "tight" && tight?.body == "body")
        let only = MessageBubble.splitLeadingQuote("> alone")
        #expect(only?.quote == "alone" && only?.body == "")
    }
}

// MARK: - Export filename

struct ChatExportFilenameTests {

    private func msg(_ text: String, at t: TimeInterval) -> ChatMessage {
        ChatMessage(id: UUID(), text: text, isUser: true,
                    timestamp: Date(timeIntervalSince1970: t))
    }

    @Test func usesTitleAndLastActivityDate() {
        // 86_400s after the 1970 epoch = Jan 2 1970 in UTC-anchored zones;
        // assert the stable parts (title + .md), not the zone-dependent day.
        let name = ChatExporter.exportFilename(for: [msg("Plan my week", at: 0),
                                                     msg("more", at: 86_400)])
        #expect(name.hasPrefix("Plan my week — 19"))
        #expect(name.hasSuffix(".md"))
    }

    @Test func scrubsFilesystemHostileCharacters() {
        let name = ChatExporter.exportFilename(for: [msg("a/b:c*d?e\"f", at: 0)])
        #expect(!name.contains("/") && !name.contains(":") && !name.contains("*")
                && !name.contains("?") && !name.contains("\""))
        #expect(name.hasPrefix("abcdef — "))
    }

    @Test func emptyOrAllScrubbedTitleFallsBack() {
        let name = ChatExporter.exportFilename(for: [msg("///", at: 0)])
        #expect(name.hasPrefix("Conversation — "))
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

// MARK: - Archive preview snippet

struct ArchivePreviewTests {

    private func msg(_ text: String, isUser: Bool) -> ChatMessage {
        ChatMessage(id: UUID(), text: text, isUser: isUser,
                    timestamp: Date(timeIntervalSince1970: 0))
    }

    @Test func emptyMessagesYieldsEmpty() {
        #expect(ChatStore.archivePreview(for: []) == "")
    }

    @Test func noAssistantReplyYieldsEmpty() {
        #expect(ChatStore.archivePreview(for: [msg("Hello", isUser: true)]) == "")
    }

    @Test func firstAssistantFirstLine() {
        let msgs = [msg("Hi", isUser: true),
                    msg("Hello! How can I help?\nMore text.", isUser: false)]
        #expect(ChatStore.archivePreview(for: msgs) == "Hello! How can I help?")
    }

    @Test func skipsBlankFirstLine() {
        let msgs = [msg("Hi", isUser: true),
                    msg("\nActual content.", isUser: false)]
        #expect(ChatStore.archivePreview(for: msgs) == "Actual content.")
    }

    @Test func truncatesLongLine() {
        let long = String(repeating: "word ", count: 40)   // 200 chars
        let msgs = [msg("Hi", isUser: true), msg(long, isUser: false)]
        let preview = ChatStore.archivePreview(for: msgs)
        #expect(preview.count <= 90)
        #expect(!preview.isEmpty)
    }

    @Test func firstAssistantPickedWhenManyMessages() {
        // Only the FIRST assistant message should be used, even if there are more.
        let msgs = [msg("Hi", isUser: true),
                    msg("First reply.", isUser: false),
                    msg("Follow-up", isUser: true),
                    msg("Second reply.", isUser: false)]
        #expect(ChatStore.archivePreview(for: msgs) == "First reply.")
    }
}

// MARK: - Composer length readout

struct ComposerCountTests {

    @Test func quietBelowTheFloor() {
        #expect(ContentView.composerCount("just a short draft") == nil)
        #expect(ContentView.composerCount("") == nil)
    }

    @Test func labelsAtTheFloorWithoutWarning() {
        // 120 words × 1.3 = 156 tokens (rounded)
        let draft = Array(repeating: "w", count: 120).joined(separator: " ")
        let c = ContentView.composerCount(draft)
        #expect(c?.label == "~156 tok" && c?.warn == false)
    }

    @Test func warnsAtTheBudget() {
        // 2000 words × 1.3 = 2600 tokens
        let draft = Array(repeating: "w", count: 2_000).joined(separator: "\n")
        let c = ContentView.composerCount(draft)
        #expect(c?.label == "~2600 tok" && c?.warn == true)
    }

    @Test func tokenLabelRoundsCorrectly() {
        // 100 words × 1.3 = 130.0 — even; 77 words × 1.3 = 100.1 → 100 tok
        let c100 = ContentView.composerCount(
            Array(repeating: "w", count: 100).joined(separator: " "), floor: 1)
        #expect(c100?.label == "~130 tok")
        let c77 = ContentView.composerCount(
            Array(repeating: "w", count: 77).joined(separator: " "), floor: 1)
        #expect(c77?.label == "~100 tok")
    }
}

// MARK: - Find-in-conversation: occurrence counting + caption

struct ChatSearchTests {

    private func msg(_ text: String) -> ChatMessage {
        ChatMessage(id: UUID(), text: text, isUser: false,
                    timestamp: Date(timeIntervalSince1970: 0))
    }

    @Test func occurrencesAreCaseInsensitiveAndNonOverlapping() {
        #expect(ChatSearch.occurrences(of: "the", in: "The theory of the THE") == 4)
        #expect(ChatSearch.occurrences(of: "aa", in: "aaaa") == 2)   // non-overlapping
        #expect(ChatSearch.occurrences(of: "x", in: "no match here") == 0)
    }

    @Test func blankQueryCountsNothing() {
        #expect(ChatSearch.occurrences(of: "", in: "anything") == 0)
        #expect(ChatSearch.occurrences(of: "   ", in: "anything") == 0)
    }

    @Test func totalMatchesSumAcrossMessagesAndMessageCount() {
        let msgs = [msg("alpha alpha"), msg("ALPHA beta"), msg("gamma")]
        #expect(ChatSearch.totalMatches(of: "alpha", in: msgs) == 3)
        #expect(ChatSearch.matchingMessageCount(of: "alpha", in: msgs) == 2)
    }

    @Test func labelCollapsesWhenOneMatchPerMessage() {
        // 2 matches across 2 messages → no "in N messages" tail.
        let msgs = [msg("alpha"), msg("alpha beta")]
        #expect(ChatSearch.matchLabel(of: "alpha", in: msgs) == "2 matches")
    }

    @Test func labelShowsSpanWhenMatchesExceedMessages() {
        let msgs = [msg("alpha alpha alpha"), msg("alpha")]   // 4 matches, 2 messages
        #expect(ChatSearch.matchLabel(of: "alpha", in: msgs) == "4 matches in 2 messages")
    }

    @Test func labelSingularGrammarAndNoMatches() {
        #expect(ChatSearch.matchLabel(of: "alpha", in: [msg("alpha beta gamma")]) == "1 match")
        #expect(ChatSearch.matchLabel(of: "zzz", in: [msg("nothing here")]) == "No matches")
    }
}

// MARK: - Find-in-conversation: highlight attribute overlay

// @MainActor: MarkdownText.highlighted(_:query:) is main-actor-isolated (View type).
@MainActor
struct MarkdownHighlightTests {

    /// The matched substrings, lowercased, in document order.
    private func marked(_ s: AttributedString) -> [String] {
        s.runs.filter { $0.backgroundColor != nil }
            .map { String(s[$0.range].characters).lowercased() }
    }

    @Test func preservesCharactersAndMarksEveryMatch() {
        let out = MarkdownText.highlighted(AttributedString("find the word find"), query: "find")
        #expect(String(out.characters) == "find the word find")   // text untouched
        #expect(marked(out) == ["find", "find"])
    }

    @Test func matchIsCaseInsensitive() {
        let out = MarkdownText.highlighted(AttributedString("Swift swift SWIFT"), query: "swift")
        #expect(marked(out).count == 3)
    }

    @Test func blankQueryLeavesEverythingUnhighlighted() {
        let out = MarkdownText.highlighted(AttributedString("nothing to mark"), query: "  ")
        #expect(out.runs.allSatisfy { $0.backgroundColor == nil })
    }

    @Test func noMatchLeavesEverythingUnhighlighted() {
        let out = MarkdownText.highlighted(AttributedString("alpha beta"), query: "zzz")
        #expect(out.runs.allSatisfy { $0.backgroundColor == nil })
    }
}

// MARK: - TrainingExporter.jsonl — rating-filtered export contract
//
// `jsonl(from:ratedOnly:)` is pure on its inputs; tests verify the pair-
// extraction, quality guard, and `ratedOnly` filter in isolation.

struct TrainingExporterTests {

    private func pair(user: String, assistant: String,
                      rating: Bool? = nil) -> [ChatMessage] {
        let a = ChatMessage(id: UUID(), text: user, isUser: true, timestamp: .now)
        var b = ChatMessage(id: UUID(), text: assistant, isUser: false, timestamp: .now)
        b.rating = rating
        return [a, b]
    }

    @Test func validPairBecomesOneExample() {
        let msgs = pair(user: "Tell me about Swift concurrency.",
                        assistant: "Swift concurrency uses async/await to structure asynchronous code.")
        let (_, stats) = TrainingExporter.jsonl(from: msgs)
        #expect(stats.examples == 1)
        #expect(stats.skipped == 0)
    }

    @Test func shortPairIsSkipped() {
        let msgs = pair(user: "Hi", assistant: "Hello")
        let (_, stats) = TrainingExporter.jsonl(from: msgs)
        #expect(stats.examples == 0)
        #expect(stats.skipped == 1)
    }

    @Test func emptyConversationHasNoExamples() {
        let (content, stats) = TrainingExporter.jsonl(from: [])
        #expect(stats.examples == 0)
        #expect(content.isEmpty)
    }

    @Test func ratedOnlySkipsUnratedPairs() {
        let rated = pair(user: "Explain async/await in Swift clearly please.",
                         assistant: "Async/await lets you write asynchronous code that reads like synchronous code.",
                         rating: true)
        let unrated = pair(user: "What is a Swift protocol and how does it work?",
                           assistant: "A Swift protocol defines a blueprint of methods, properties, and requirements.",
                           rating: nil)
        let (_, stats) = TrainingExporter.jsonl(from: rated + unrated, ratedOnly: true)
        #expect(stats.examples == 1)
        // The unrated pair is counted as skipped.
        #expect(stats.skipped == 1)
    }

    @Test func ratedOnlySkipsThumbsDownPairs() {
        let downvoted = pair(user: "Please write me a poem about coding.",
                             assistant: "In circuits deep and logic gates abound, A coder's world is beautifully profound.",
                             rating: false)
        let (_, stats) = TrainingExporter.jsonl(from: downvoted, ratedOnly: true)
        #expect(stats.examples == 0)
    }

    @Test func defaultExportIncludesUnratedPairs() {
        let unrated = pair(user: "Tell me about Swift protocols and generics.",
                           assistant: "Swift protocols define contracts; generics let you write reusable parameterized code.",
                           rating: nil)
        let (_, stats) = TrainingExporter.jsonl(from: unrated, ratedOnly: false)
        #expect(stats.examples == 1)
    }

    @Test func outputIsValidJSONL() throws {
        let msgs = pair(user: "How does SwiftUI differ from UIKit in Swift development?",
                        assistant: "SwiftUI is a declarative framework while UIKit is imperative; both target Apple platforms.",
                        rating: true)
        let (content, stats) = TrainingExporter.jsonl(from: msgs)
        guard stats.examples > 0 else { return }
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            let data = Data(line.utf8)
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }
}
