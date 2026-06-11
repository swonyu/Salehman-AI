import Testing
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
