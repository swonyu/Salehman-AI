import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Chat composer pure logic — slash matcher + greeting buckets
//
// Both functions are `nonisolated static` and pure on their inputs, so these
// tests are hermetic: no clock faking, no MainActor, no shared state. The
// matcher rule ("menu only while the FIRST token is typed") is the contract
// the composer's ↵-pick relies on — a regression here silently turns prose
// starting with "/" into command execution.

struct ChatSlashMatcherTests {

    private let fixtures: [ChatSlashCommand] = [
        .init(id: "copy",     icon: "doc",  blurb: "", kind: .action("copy")),
        .init(id: "continue", icon: "doc",  blurb: "", kind: .template("Continue.")),
        .init(id: "clear",    icon: "doc",  blurb: "", kind: .action("clear")),
        .init(id: "voice",    icon: "doc",  blurb: "", kind: .action("voice")),
    ]

    @Test func bareSlashMatchesEverything() {
        #expect(ChatSlashCommand.matches(for: "/", in: fixtures).count == fixtures.count)
    }

    @Test func prefixNarrowsToMatchingCommands() {
        let m = ChatSlashCommand.matches(for: "/co", in: fixtures).map(\.id)
        #expect(m == ["copy", "continue"])
    }

    @Test func matchingIsCaseInsensitive() {
        #expect(ChatSlashCommand.matches(for: "/COp", in: fixtures).map(\.id) == ["copy"])
    }

    @Test func unknownPrefixMatchesNothing() {
        #expect(ChatSlashCommand.matches(for: "/x", in: fixtures).isEmpty)
    }

    @Test func plainProseNeverTriggers() {
        #expect(ChatSlashCommand.matches(for: "hello", in: fixtures).isEmpty)
        #expect(ChatSlashCommand.matches(for: "see /copy for details", in: fixtures).isEmpty)
        #expect(ChatSlashCommand.matches(for: "", in: fixtures).isEmpty)
    }

    @Test func spaceOrNewlineClosesTheMenu() {
        // Once the first token is complete the input is a message, not a command.
        #expect(ChatSlashCommand.matches(for: "/copy this chat", in: fixtures).isEmpty)
        #expect(ChatSlashCommand.matches(for: "/copy\n", in: fixtures).isEmpty)
    }
}

struct ChatSlashSlugTests {

    @Test func spacesBecomeDashesAndCaseDrops() {
        #expect(ChatSlashCommand.slug("Fix my Code") == "fix-my-code")
    }

    @Test func symbolsAreDropped() {
        #expect(ChatSlashCommand.slug("Fix my Code!") == "fix-my-code")
        #expect(ChatSlashCommand.slug("Re: plan (v2)") == "re-plan-v2")
    }

    @Test func symbolOnlyTitlesAreUnusable() {
        #expect(ChatSlashCommand.slug("!!!") == "")
    }

    @Test func numbersSurvive() {
        #expect(ChatSlashCommand.slug("Q4 2026 review") == "q4-2026-review")
    }
}

struct ChatQuoteTests {

    @Test func everyLineGetsAPrefix() {
        #expect(ContentView.quoted("one\ntwo") == "> one\n> two")
    }

    @Test func blankLinesStayInTheBlock() {
        // A bare ">" on blank lines keeps multi-paragraph quotes one block.
        #expect(ContentView.quoted("a\n\nb") == "> a\n> \n> b")
    }

    @Test func singleLine() {
        #expect(ContentView.quoted("hello") == "> hello")
    }
}

// MARK: - extractForEdit — transcript truncation for edit-and-resend
//
// `@MainActor` + `.serialized`: ChatViewModel is MainActor; each case builds
// its own VM so there's no shared state, but serialization keeps any future
// shared-singleton drift (MissionProgress etc.) from racing.

@MainActor
@Suite(.serialized)
struct ChatExtractForEditTests {

    private func vm(_ texts: [(String, Bool)]) -> ChatViewModel {
        let m = ChatViewModel()
        m.messages = texts.map { ChatMessage(id: UUID(), text: $0.0, isUser: $0.1, timestamp: .now) }
        return m
    }

    @Test func truncatesFromTheEditedTurnAndReturnsItsText() {
        let m = vm([("first", true), ("reply 1", false), ("second", true), ("reply 2", false)])
        let edited = m.messages[2]
        #expect(m.extractForEdit(edited) == "second")
        #expect(m.messages.map(\.text) == ["first", "reply 1"])
    }

    @Test func assistantMessagesAreNotEditable() {
        let m = vm([("q", true), ("a", false)])
        #expect(m.extractForEdit(m.messages[1]) == nil)
        #expect(m.messages.count == 2)
    }

    @Test func attachmentLinesAreStripped() {
        let m = vm([("look at this\n📎 report.pdf", true)])
        #expect(m.extractForEdit(m.messages[0]) == "look at this")
        #expect(m.messages.isEmpty)
    }

    @Test func attachmentOnlyTurnIsNotEditable() {
        let m = vm([("📎 report.pdf", true)])
        #expect(m.extractForEdit(m.messages[0]) == nil)
        #expect(m.messages.count == 1)
    }

    @Test func midRunEditsAreRefused() {
        let m = vm([("q", true)])
        m.isRunning = true
        #expect(m.extractForEdit(m.messages[0]) == nil)
        m.isRunning = false
    }
}

struct ChatArchiveTitleTests {

    private func msg(_ text: String, user: Bool) -> ChatMessage {
        ChatMessage(id: UUID(), text: text, isUser: user, timestamp: .now)
    }

    @Test func firstUserLineBecomesTheTitle() {
        let msgs = [msg("Fix my Wi-Fi\nplease", user: true), msg("On it.", user: false)]
        #expect(ChatStore.archiveTitle(for: msgs) == "Fix my Wi-Fi")
    }

    @Test func assistantFirstConversationsSkipToTheUser() {
        let msgs = [msg("Welcome!", user: false), msg("hello", user: true)]
        #expect(ChatStore.archiveTitle(for: msgs) == "hello")
    }

    @Test func longTitlesAreClipped() {
        let long = String(repeating: "a", count: 100)
        #expect(ChatStore.archiveTitle(for: [msg(long, user: true)]).count == 60)
    }

    @Test func noUserMessageFallsBack() {
        #expect(ChatStore.archiveTitle(for: [msg("hi", user: false)]) == "Conversation")
        #expect(ChatStore.archiveTitle(for: []) == "Conversation")
    }
}

// MARK: - Attachment.merged — the multi-attachment collapse contract
//
// The send pipeline stays single-attachment by design; the composer merges.
// What MUST hold: singles pass through untouched (vision path depends on
// fileURL/isImage), multi-merges carry every file's name + content.

struct AttachmentMergeTests {

    @Test func emptyListMergesToNil() {
        #expect(Attachment.merged([]) == nil)
    }

    @Test func singlePassesThroughWithVisionFieldsIntact() {
        let one = Attachment(name: "shot.png", kind: "image", icon: "photo",
                             extractedText: "a screenshot",
                             fileURL: URL(fileURLWithPath: "/tmp/shot.png"), isImage: true)
        let merged = Attachment.merged([one])
        #expect(merged?.id == one.id)
        #expect(merged?.isImage == true)
        #expect(merged?.fileURL != nil)
    }

    @Test func multiMergeCarriesEveryNameAndBody() {
        let a = Attachment(name: "a.txt", kind: "file", icon: "doc.text", extractedText: "alpha")
        let b = Attachment(name: "b.pdf", kind: "PDF", icon: "doc.richtext", extractedText: "bravo")
        let merged = Attachment.merged([a, b])
        #expect(merged?.name == "a.txt, b.pdf")
        #expect(merged?.kind == "files")
        #expect(merged?.extractedText.contains("alpha") == true)
        #expect(merged?.extractedText.contains("bravo") == true)
        #expect(merged?.extractedText.contains("a.txt") == true)
        // Text-only by design: a merged attachment must never claim vision.
        #expect(merged?.isImage == false)
        #expect(merged?.fileURL == nil)
    }
}

struct ChatGreetingBucketTests {

    @Test(arguments: [
        (5, "Good morning, Saleh"), (11, "Good morning, Saleh"),
        (12, "Good afternoon, Saleh"), (16, "Good afternoon, Saleh"),
        (17, "Good evening, Saleh"), (21, "Good evening, Saleh"),
        (22, "Working late, Saleh?"), (4, "Working late, Saleh?"),
        (0, "Working late, Saleh?"),
    ])
    func bucketBoundaries(hour: Int, expected: String) {
        #expect(ContentView.greeting(hour: hour) == expected)
    }
}
