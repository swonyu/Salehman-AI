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

// MARK: - ScratchpadStore.addNote — note-saving contract for /note and "Save as Note"
//
// Tests run in an isolated temp directory so the real scratchpad.json is never
// touched. The trim + guard-empty contract is the key invariant: blank strings
// must not reach the store (the plain-text of some replies can be whitespace-only
// after stripping, e.g. a code-only block).

@MainActor
@Suite(.serialized)
struct NoteFromChatTests {

    private func makeStore() -> ScratchpadStore {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("note_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return ScratchpadStore(testingBaseDirectory: tmp)
    }

    @Test func addNoteStoresText() {
        let store = makeStore()
        store.addNote("Hello from the chat")
        #expect(store.notes.first?.text == "Hello from the chat")
    }

    @Test func addNoteTrimsWhitespace() {
        let store = makeStore()
        store.addNote("  hello  \n")
        #expect(store.notes.first?.text == "hello")
    }

    @Test func addNoteIgnoresBlankInput() {
        let store = makeStore()
        store.addNote("   ")
        #expect(store.notes.isEmpty)
    }

    @Test func addNoteIgnoresEmptyInput() {
        let store = makeStore()
        store.addNote("")
        #expect(store.notes.isEmpty)
    }

    @Test func multipleNotesInsertAtFront() {
        let store = makeStore()
        store.addNote("first")
        store.addNote("second")
        #expect(store.notes.first?.text == "second")
        #expect(store.notes.last?.text == "first")
    }

    @Test func moveNoteChangesOrder() {
        let store = makeStore()
        store.addNote("a")
        store.addNote("b")
        store.addNote("c")
        // After inserts: ["c","b","a"]. Move index 0 ("c") to after index 2 → ["b","a","c"]
        store.moveNote(from: IndexSet(integer: 0), to: 3)
        #expect(store.notes.map(\.text) == ["b", "a", "c"])
    }

    @Test func moveTaskChangesOrder() {
        let store = makeStore()
        store.addTask("x")
        store.addTask("y")
        store.addTask("z")
        // After inserts: ["z","y","x"]. Move index 2 ("x") to top (index 0) → ["x","z","y"]
        store.moveTask(from: IndexSet(integer: 2), to: 0)
        #expect(store.tasks.map(\.title) == ["x", "z", "y"])
    }
}

// MARK: - ScratchpadList.markdownList — copy-all export format

struct ScratchpadMarkdownTests {

    private func task(_ title: String, done: Bool = false) -> TaskItem {
        TaskItem(title: title, done: done)
    }
    private func note(_ text: String) -> Note { Note(text: text) }

    @Test func emptyTaskListYieldsEmpty() {
        #expect(ScratchpadList.markdownList(tasks: []) == "")
    }

    @Test func emptyNoteListYieldsEmpty() {
        #expect(ScratchpadList.markdownList(notes: []) == "")
    }

    @Test func openTaskUsesUncheckedBox() {
        let md = ScratchpadList.markdownList(tasks: [task("Buy milk")])
        #expect(md == "- [ ] Buy milk")
    }

    @Test func doneTaskUsesCheckedBox() {
        let md = ScratchpadList.markdownList(tasks: [task("Done thing", done: true)])
        #expect(md == "- [x] Done thing")
    }

    @Test func multipleTasksJoinedByNewline() {
        let md = ScratchpadList.markdownList(tasks: [task("A"), task("B", done: true), task("C")])
        #expect(md == "- [ ] A\n- [x] B\n- [ ] C")
    }

    @Test func singleNoteFormattedAsBullet() {
        let md = ScratchpadList.markdownList(notes: [note("Remember this")])
        #expect(md == "- Remember this")
    }

    @Test func multipleNotesJoinedByNewline() {
        let md = ScratchpadList.markdownList(notes: [note("One"), note("Two")])
        #expect(md == "- One\n- Two")
    }
}

// MARK: - MessageBubble.plainText — markdown stripping contract
//
// `copyPlainText` writes this to the pasteboard for users pasting into
// non-markdown contexts. The contract: common patterns are stripped without
// swallowing content; plain prose passes through unchanged.

struct MessageBubblePlainTextTests {

    @Test func plainProsePassesThrough() {
        #expect(MessageBubble.plainText("Hello world") == "Hello world")
    }

    @Test func stripsAtxHeaders() {
        #expect(MessageBubble.plainText("## Hello World") == "Hello World")
        #expect(MessageBubble.plainText("### Three") == "Three")
    }

    @Test func stripsBold() {
        #expect(MessageBubble.plainText("This is **bold** text") == "This is bold text")
    }

    @Test func stripsItalic() {
        #expect(MessageBubble.plainText("This is *italic* text") == "This is italic text")
    }

    @Test func stripsInlineCode() {
        #expect(MessageBubble.plainText("Use `print()` to debug") == "Use print() to debug")
    }

    @Test func stripsLinksKeepingDisplayText() {
        #expect(MessageBubble.plainText("[Claude](https://claude.ai)") == "Claude")
    }

    @Test func stripsFencedCodeBlockFences() {
        let md = "Here:\n```swift\nlet x = 1\n```\nDone."
        let result = MessageBubble.plainText(md)
        #expect(!result.contains("```"))
        #expect(result.contains("let x = 1"))
        #expect(result.contains("Done."))
    }

    @Test func stripsBlockquoteMarkers() {
        let md = "> This is a quote\n> Second line"
        let result = MessageBubble.plainText(md)
        #expect(!result.contains(">"))
        #expect(result.contains("This is a quote"))
    }

    @Test func stripsUnorderedListMarkers() {
        let md = "Items:\n- Alpha\n- Beta\n- Gamma"
        let result = MessageBubble.plainText(md)
        #expect(!result.contains("- "))
        #expect(result.contains("Alpha"))
    }
}

// MARK: - ChatStats — token estimation and blurb contract
//
// `approxTokens` uses the `words × 1.3` English BPE heuristic. The blurb is
// the string shown in the `/stats` alert; these tests pin its format so a
// refactor doesn't silently truncate useful context-window info.

@MainActor
@Suite(.serialized)
struct ChatStatsTokenTests {

    private func msg(_ text: String, user: Bool,
                     duration: Double? = nil) -> ChatMessage {
        var m = ChatMessage(id: UUID(), text: text, isUser: user, timestamp: .now)
        m.duration = duration
        return m
    }

    @Test func approxTokensIsWordsTimesOnePtThree() {
        // 10 words of prose: expected = Int((10 * 1.3).rounded()) = 13
        let msgs = [msg("one two three four five six seven eight nine ten", user: true)]
        let stats = ChatStats.summarize(msgs)
        #expect(stats.words == 10)
        #expect(stats.approxTokens == 13)
    }

    @Test func approxTokensRoundsHalfUp() {
        // 1 word: Int((1 * 1.3).rounded()) = Int(1.3.rounded()) = 1
        // 3 words: Int((3 * 1.3).rounded()) = Int(3.9.rounded()) = 4
        let one = ChatStats.summarize([msg("hello", user: true)])
        let three = ChatStats.summarize([msg("one two three", user: true)])
        #expect(one.approxTokens == 1)
        #expect(three.approxTokens == 4)
    }

    @Test func zeroWordsGivesZeroTokens() {
        let stats = ChatStats.summarize([])
        #expect(stats.approxTokens == 0)
    }

    @Test func longestReplyWordsPicksMaxAssistantReply() {
        let msgs = [
            msg("hi", user: true),
            msg("short reply", user: false),               // 2 words
            msg("please help me", user: true),
            msg("one two three four five six", user: false), // 6 words
        ]
        let stats = ChatStats.summarize(msgs)
        #expect(stats.longestReplyWords == 6)
    }

    @Test func longestReplyWordsIsNilWhenNoAssistantMessages() {
        let msgs = [msg("just a user message", user: true)]
        let stats = ChatStats.summarize(msgs)
        #expect(stats.longestReplyWords == nil)
    }

    @Test func blurbContainsTokSuffix() {
        let msgs = [msg("ten words long is what this particular sentence has", user: true)]
        let blurb = ChatStats.summarize(msgs).blurb
        #expect(blurb.contains("tok"))
    }

    @Test func blurbContainsLongestWordCountWhenReplyExists() {
        let msgs = [
            msg("hi", user: true),
            msg("three words here", user: false),
        ]
        let blurb = ChatStats.summarize(msgs).blurb
        // longestReplyWords = 3 → "longest: 3w" should appear in the second line
        #expect(blurb.contains("longest: 3w"))
    }

    @Test func blurbOmitsLongestWhenNoReplies() {
        let msgs = [msg("user only", user: true)]
        let blurb = ChatStats.summarize(msgs).blurb
        #expect(!blurb.contains("longest:"))
    }
}

// MARK: - ContentView.recalledMessage — message-recall cycling contract
//
// ↑ in the empty composer cycles backward through user messages (terminal
// history style). The pure helper is tested here; the state machine that
// drives recallIdx is exercised by the UI tests.

struct ChatRecallTests {

    private func msg(_ t: String, user: Bool) -> ChatMessage {
        ChatMessage(id: UUID(), text: t, isUser: user, timestamp: .now)
    }

    @Test func recallsNewestMessageAtIndexZero() {
        let msgs = [msg("first", user: true), msg("reply", user: false), msg("second", user: true)]
        #expect(ContentView.recalledMessage(idx: 0, from: msgs) == "second")
    }

    @Test func recallsOlderMessageAtHigherIndex() {
        let msgs = [msg("first", user: true), msg("reply", user: false), msg("second", user: true)]
        #expect(ContentView.recalledMessage(idx: 1, from: msgs) == "first")
    }

    @Test func outOfRangeReturnsNil() {
        let msgs = [msg("only", user: true)]
        #expect(ContentView.recalledMessage(idx: 1, from: msgs) == nil)
        #expect(ContentView.recalledMessage(idx: -1, from: msgs) == nil)
    }

    @Test func assistantMessagesAreSkipped() {
        let msgs = [msg("u1", user: true), msg("a1", user: false),
                    msg("a2", user: false), msg("u2", user: true)]
        #expect(ContentView.recalledMessage(idx: 0, from: msgs) == "u2")
        #expect(ContentView.recalledMessage(idx: 1, from: msgs) == "u1")
        #expect(ContentView.recalledMessage(idx: 2, from: msgs) == nil)
    }

    @Test func emptyHistoryReturnsNil() {
        #expect(ContentView.recalledMessage(idx: 0, from: []) == nil)
    }
}

// MARK: - ChatStats rating summary — ratedUp/ratedDown counts + blurb format

@MainActor
@Suite(.serialized)
struct ChatStatsRatingTests {

    private func msg(_ text: String, user: Bool, rating: Bool? = nil) -> ChatMessage {
        var m = ChatMessage(id: UUID(), text: text, isUser: user, timestamp: .now)
        m.rating = rating
        return m
    }

    @Test func ratingCountsIgnoreUserMessages() {
        let msgs = [
            msg("my question", user: true, rating: true),   // user — must not count
            msg("great reply", user: false, rating: true),
            msg("bad reply",   user: false, rating: false),
        ]
        let stats = ChatStats.summarize(msgs)
        #expect(stats.ratedUp == 1)
        #expect(stats.ratedDown == 1)
    }

    @Test func noRatingsAreZero() {
        let msgs = [msg("hi", user: true), msg("hello", user: false)]
        let stats = ChatStats.summarize(msgs)
        #expect(stats.ratedUp == 0)
        #expect(stats.ratedDown == 0)
    }

    @Test func blurbIncludesRatingWhenAnyRated() {
        let msgs = [
            msg("user", user: true),
            msg("good", user: false, rating: true),
            msg("bad",  user: false, rating: false),
        ]
        let blurb = ChatStats.summarize(msgs).blurb
        #expect(blurb.contains("1↑"))
        #expect(blurb.contains("1↓"))
    }

    @Test func blurbOmitsRatingChunkWhenNoneRated() {
        let msgs = [msg("user", user: true), msg("reply", user: false)]
        let blurb = ChatStats.summarize(msgs).blurb
        #expect(!blurb.contains("↑"))
        #expect(!blurb.contains("↓"))
    }
}

// MARK: - Chat rating feature — togglingRating contract
//
// `true` = thumbs-up, `false` = thumbs-down, `nil` = unrated.
// Second-click on the same value un-rates (→ nil); clicking the opposite
// switches directly. Both semantics matter for UX correctness.

struct ChatRatingTests {

    private func msg(_ text: String, rating: Bool? = nil) -> ChatMessage {
        var m = ChatMessage(id: UUID(), text: text, isUser: false, timestamp: .now)
        m.rating = rating
        return m
    }

    @Test func nilToThumbsUp() {
        let m = msg("reply", rating: nil)
        let result = ChatViewModel.togglingRating(in: [m], id: m.id, up: true)
        #expect(result.first?.rating == true)
    }

    @Test func nilToThumbsDown() {
        let m = msg("reply", rating: nil)
        let result = ChatViewModel.togglingRating(in: [m], id: m.id, up: false)
        #expect(result.first?.rating == false)
    }

    @Test func thumbsUpAgainUnrates() {
        let m = msg("reply", rating: true)
        let result = ChatViewModel.togglingRating(in: [m], id: m.id, up: true)
        #expect(result.first?.rating == nil)
    }

    @Test func thumbsDownAgainUnrates() {
        let m = msg("reply", rating: false)
        let result = ChatViewModel.togglingRating(in: [m], id: m.id, up: false)
        #expect(result.first?.rating == nil)
    }

    @Test func thumbsUpToThumbsDownSwitches() {
        let m = msg("reply", rating: true)
        let result = ChatViewModel.togglingRating(in: [m], id: m.id, up: false)
        #expect(result.first?.rating == false)
    }

    @Test func thumbsDownToThumbsUpSwitches() {
        let m = msg("reply", rating: false)
        let result = ChatViewModel.togglingRating(in: [m], id: m.id, up: true)
        #expect(result.first?.rating == true)
    }

    @Test func unknownIdIsNoOp() {
        let m = msg("reply", rating: nil)
        let result = ChatViewModel.togglingRating(in: [m], id: UUID(), up: true)
        #expect(result.first?.rating == nil)
    }

    @Test func onlyTargetedMessageChanges() {
        let a = msg("alpha", rating: nil)
        let b = msg("beta",  rating: true)
        let c = msg("gamma", rating: nil)
        let result = ChatViewModel.togglingRating(in: [a, b, c], id: b.id, up: false)
        #expect(result[0].rating == nil)    // a: unchanged
        #expect(result[1].rating == false)  // b: switched
        #expect(result[2].rating == nil)    // c: unchanged
    }
}

// MARK: - Chat pin feature — togglingPin + pinPreview contracts
//
// Both helpers are `nonisolated static`, so tests are hermetic. `togglingPin`
// is the mutation kernel — the VM just wraps it. `pinPreview` is the chip
// label; truncation + newline stripping are the fragile bits.

struct ChatPinOperationTests {

    private func msg(_ text: String, pinned: Bool? = nil) -> ChatMessage {
        var m = ChatMessage(id: UUID(), text: text, isUser: false, timestamp: .now)
        m.pinned = pinned
        return m
    }

    // MARK: togglingPin

    @Test func pinSetsNilToTrue() {
        let m = msg("hello", pinned: nil)
        let result = ChatViewModel.togglingPin(in: [m], id: m.id)
        #expect(result.first?.pinned == true)
    }

    @Test func unpinSetsTrueToNil() {
        let m = msg("hello", pinned: true)
        let result = ChatViewModel.togglingPin(in: [m], id: m.id)
        #expect(result.first?.pinned == nil)
    }

    @Test func unknownIdIsNoOp() {
        let m = msg("hello", pinned: nil)
        let result = ChatViewModel.togglingPin(in: [m], id: UUID())
        #expect(result.first?.pinned == nil)
    }

    @Test func onlyTargetedMessageChanges() {
        let a = msg("alpha", pinned: nil)
        let b = msg("beta",  pinned: true)
        let c = msg("gamma", pinned: nil)
        let result = ChatViewModel.togglingPin(in: [a, b, c], id: b.id)
        #expect(result[0].pinned == nil)   // a: unchanged
        #expect(result[1].pinned == nil)   // b: unpinned
        #expect(result[2].pinned == nil)   // c: unchanged
    }

    // MARK: pinPreview

    @Test func shortTextPassesThrough() {
        #expect(ContentView.pinPreview("Short message") == "Short message")
    }

    @Test func longTextIsTruncatedWithEllipsis() {
        let long = String(repeating: "a", count: 50)
        let result = ContentView.pinPreview(long)
        #expect(result.hasSuffix("…"))
        // prefix(40) + "…" → 41 characters (one Swift scalar for the ellipsis)
        #expect(result.count == 41)
    }

    @Test func exactlyAtMaxPassesThroughWithoutEllipsis() {
        let exact = String(repeating: "x", count: 40)
        let result = ContentView.pinPreview(exact)
        #expect(result == exact)
        #expect(!result.hasSuffix("…"))
    }

    @Test func multilineUsesOnlyFirstLine() {
        let result = ContentView.pinPreview("First line\nSecond line\nThird")
        #expect(result == "First line")
    }

    @Test func customMaxIsRespected() {
        let text = "Hello world this is more than ten characters"
        let result = ContentView.pinPreview(text, max: 10)
        #expect(result.hasSuffix("…"))
        // The prefix(10) may end in a space which is trimmed before "…" is appended.
        #expect(result.count <= 11)
    }

    @Test func blankFirstLineFallsBackToEmpty() {
        let result = ContentView.pinPreview("\nSecond line")
        #expect(result == "")
    }
}

// MARK: - ChatHistoryView.filtered — pure title search contract
//
// `nonisolated static` function added by the linter; tested here because the
// contract it protects (case + diacritic insensitive substring, blank = all)
// is exactly the kind of quiet regression that breaks foreign-language titles.

struct ChatHistoryFilterExtendedTests {

    private func archive(_ title: String) -> ChatStore.ArchivedChat {
        ChatStore.ArchivedChat(id: URL(fileURLWithPath: "/tmp/\(title).json"),
                               title: title, date: .now, messageCount: 1)
    }

    @Test func emptyQueryReturnsAll() {
        let items = [archive("Alpha"), archive("Beta"), archive("Gamma")]
        #expect(ChatHistoryView.filtered(items, query: "").count == 3)
    }

    @Test func whitespaceOnlyQueryIsAlsoAll() {
        let items = [archive("Alpha"), archive("Beta")]
        #expect(ChatHistoryView.filtered(items, query: "   ").count == 2)
    }

    @Test func filterIsCaseInsensitive() {
        let items = [archive("Hello World"), archive("goodbye")]
        #expect(ChatHistoryView.filtered(items, query: "HELLO").map(\.title) == ["Hello World"])
    }

    @Test func filterIsDiacriticInsensitive() {
        let items = [archive("Résumé tips"), archive("Plain title")]
        #expect(ChatHistoryView.filtered(items, query: "resume").map(\.title) == ["Résumé tips"])
    }

    @Test func noMatchReturnsEmpty() {
        let items = [archive("Alpha"), archive("Beta")]
        #expect(ChatHistoryView.filtered(items, query: "zzzz").isEmpty)
    }

    @Test func substrMatchWorksInTheMiddle() {
        let items = [archive("My chat about cats"), archive("dogs")]
        #expect(ChatHistoryView.filtered(items, query: "about").map(\.title) == ["My chat about cats"])
    }
}

// MARK: - ScratchpadStore.pendingTaskCount — badge count contract
//
// The pending count drives the notification badge on the Notes tab corner
// button. It must count only open tasks, ignore completed ones, and stay at
// zero when no tasks exist.

@MainActor
@Suite(.serialized)
struct ScratchpadPendingCountTests {

    private func makeStore() -> ScratchpadStore {
        ScratchpadStore(testingBaseDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString))
    }

    @Test func zeroWhenEmpty() {
        let store = makeStore()
        #expect(store.pendingTaskCount == 0)
    }

    @Test func countsOpenTasks() {
        let store = makeStore()
        store.addTask("buy milk")
        store.addTask("call dentist")
        #expect(store.pendingTaskCount == 2)
    }

    @Test func excludesCompletedTasks() {
        let store = makeStore()
        store.addTask("done task")
        let id = store.tasks.first!.id
        store.toggleTask(id)       // mark done
        #expect(store.tasks.first!.done == true)
        #expect(store.pendingTaskCount == 0)
    }

    @Test func mixedOpenAndDone() {
        let store = makeStore()
        store.addTask("open one")
        store.addTask("open two")
        store.addTask("done one")
        // tasks inserted at index 0, so tasks[0] = "done one"
        store.toggleTask(store.tasks[0].id)
        #expect(store.pendingTaskCount == 2)
    }

    @Test func decreasesAfterToggle() {
        let store = makeStore()
        store.addTask("task A")
        store.addTask("task B")
        #expect(store.pendingTaskCount == 2)
        store.toggleTask(store.tasks[0].id)
        #expect(store.pendingTaskCount == 1)
        store.toggleTask(store.tasks[1].id)
        #expect(store.pendingTaskCount == 0)
    }
}
