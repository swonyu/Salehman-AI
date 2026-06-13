import Testing
import Foundation
@testable import Salehman_AI

// MARK: - CodeWorkspace.lineDiff — LCS line-diff invariants
//
// lineDiff is the red/green diff shown in the Code tab after each agent run.
// It uses a bounded LCS (capped at 1500 lines per side) — a regression here
// silently breaks the diff view with no build error. Key invariants:
//
//   • Identical content  → all .same
//   • Added line         → .add at the correct position
//   • Removed line       → .remove at the correct position
//   • Changed line       → .remove then .add (tiebreak in the LCS walk always
//                          emits removes first, giving "red before green")
//   • Accounting:  #same + #add    == new-line count
//                  #same + #remove == old-line count

struct LineDiffTests {

    private func kinds(_ d: [DiffLine]) -> [DiffLine.Kind] { d.map(\.kind) }
    private func texts(_ d: [DiffLine]) -> [String] { d.map(\.text) }

    // MARK: - unchanged

    @Test func identicalSingleLineIsAllSame() {
        let d = CodeWorkspace.lineDiff(old: "hello", new: "hello")
        #expect(kinds(d) == [.same])
        #expect(texts(d) == ["hello"])
    }

    @Test func identicalMultilineIsAllSame() {
        let content = "line1\nline2\nline3"
        let d = CodeWorkspace.lineDiff(old: content, new: content)
        #expect(d.count == 3)
        #expect(kinds(d).allSatisfy { $0 == .same },
                "identical content must produce only .same diff lines")
    }

    // MARK: - add / remove / change

    @Test func addedLineAtEndBecomesDotAdd() {
        let d = CodeWorkspace.lineDiff(old: "a\nb", new: "a\nb\nc")
        #expect(kinds(d) == [.same, .same, .add])
        #expect(texts(d) == ["a", "b", "c"])
    }

    @Test func prependedLineBecomesDotAdd() {
        // "a" is new; "b" and "c" are shared — the LCS walk emits .add("a") first.
        let d = CodeWorkspace.lineDiff(old: "b\nc", new: "a\nb\nc")
        #expect(kinds(d) == [.add, .same, .same])
        #expect(texts(d) == ["a", "b", "c"])
    }

    @Test func removedLineFromMiddleBecomesDotRemove() {
        let d = CodeWorkspace.lineDiff(old: "a\nb\nc", new: "a\nc")
        #expect(kinds(d) == [.same, .remove, .same])
        #expect(texts(d) == ["a", "b", "c"])
    }

    @Test func changedSingleLineIsRemoveThenAdd() {
        // No shared line → empty LCS. The tiebreak (dp[i+1][j] >= dp[i][j+1],
        // both 0) always fires remove first, giving the canonical "red then green".
        let d = CodeWorkspace.lineDiff(old: "old line", new: "new line")
        #expect(kinds(d) == [.remove, .add])
        #expect(texts(d) == ["old line", "new line"])
    }

    // MARK: - accounting invariant

    @Test func sameAddEqualsNewLineCount() {
        let old = "a\nb\nc"
        let new = "a\nb\nc\nd\ne"
        let d = CodeWorkspace.lineDiff(old: old, new: new)
        let sameCount   = d.filter { $0.kind == .same   }.count
        let addCount    = d.filter { $0.kind == .add    }.count
        let removeCount = d.filter { $0.kind == .remove }.count
        let newLineCount = new.components(separatedBy: "\n").count
        let oldLineCount = old.components(separatedBy: "\n").count
        #expect(sameCount + addCount    == newLineCount,
                "#same + #add must equal new-line count")
        #expect(sameCount + removeCount == oldLineCount,
                "#same + #remove must equal old-line count")
    }

    @Test func removeReduceAccountingSymmetrically() {
        // Mirror of the add test — removing 2 lines from the end.
        let old = "a\nb\nc\nd\ne"
        let new = "a\nb\nc"
        let d = CodeWorkspace.lineDiff(old: old, new: new)
        let sameCount   = d.filter { $0.kind == .same   }.count
        let addCount    = d.filter { $0.kind == .add    }.count
        let removeCount = d.filter { $0.kind == .remove }.count
        let newLineCount = new.components(separatedBy: "\n").count
        let oldLineCount = old.components(separatedBy: "\n").count
        #expect(sameCount + addCount    == newLineCount)
        #expect(sameCount + removeCount == oldLineCount)
    }
}

// MARK: - CodeView.sanitizedHistory — old-narration cleaner
//
// sanitizedHistory is applied at history-load time to strip fine-tune scaffold
// ("Thoughts:\n\nResponse:\nActual reply", <think> blocks) from OLD assistant
// messages so the user never sees leaked training artefacts. Key invariants:
//
//   • Empty input                  → empty output
//   • User messages                → never modified (even if they contain markers)
//   • Clean assistant messages     → returned with the same id (no-op path)
//   • Dirty assistant messages     → text replaced; id/timestamp/metadata preserved
//   • Mixed lists                  → user messages and clean messages pass through,
//                                    only dirty assistant messages are cleaned

struct SanitizedHistoryTests {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func userMsg(_ text: String, id: UUID = UUID()) -> ChatMessage {
        ChatMessage(id: id, text: text, isUser: true, timestamp: now)
    }

    private func assistantMsg(_ text: String, id: UUID = UUID(),
                              imagePath: String? = nil,
                              duration: Double? = nil) -> ChatMessage {
        ChatMessage(id: id, text: text, isUser: false, timestamp: now,
                    imagePath: imagePath, duration: duration)
    }

    // MARK: - basic

    @Test func emptyHistoryReturnsEmpty() {
        #expect(CodeView.sanitizedHistory([]).isEmpty)
    }

    @Test func userMessagePassesThroughUnchanged() {
        // User messages must never be touched, even if the text contains scaffold markers.
        let scaffoldText = "Analysis:\n\nResponse:\nsome answer"
        let msg = userMsg(scaffoldText)
        let result = CodeView.sanitizedHistory([msg])
        #expect(result.count == 1)
        #expect(result[0].text == scaffoldText,
                "user message text must be preserved verbatim")
        #expect(result[0].isUser == true)
    }

    @Test func cleanAssistantMessageReturnsSameIDAndText() {
        // A reply with no scaffold markers must pass through the no-op branch.
        let id = UUID()
        let cleanText = "Sure, here's the answer."
        let result = CodeView.sanitizedHistory([assistantMsg(cleanText, id: id)])
        #expect(result.count == 1)
        #expect(result[0].text == cleanText,
                "clean assistant text must be unchanged after sanitization")
        #expect(result[0].id == id,
                "clean assistant message must preserve its UUID")
    }

    // MARK: - stripping

    @Test func assistantWithResponseMarkerIsCleaned() {
        // The fine-tuned model used to leak "Thoughts:\n\nResponse:\nActual reply".
        // Only what follows the Response: marker should survive.
        let id = UUID()
        let dirty = "Thoughts on the query.\n\nResponse:\nActual answer here."
        let result = CodeView.sanitizedHistory([assistantMsg(dirty, id: id)])
        #expect(result.count == 1)
        #expect(result[0].text == "Actual answer here.",
                "text after 'Response:' must replace the full message text")
    }

    @Test func assistantWithThinkBlockIsCleaned() {
        // Reasoning models (QwQ, DeepSeek-R1) emit <think>…</think> before their answer.
        let id = UUID()
        let dirty = "<think>internal reasoning here</think>\nThe final answer."
        let result = CodeView.sanitizedHistory([assistantMsg(dirty, id: id)])
        #expect(result.count == 1)
        #expect(!result[0].text.contains("<think>"),
                "<think> block must be stripped")
        #expect(result[0].text.contains("The final answer."),
                "the real answer after the think block must be preserved")
    }

    // MARK: - metadata preservation

    @Test func cleanedMessagePreservesMetadata() {
        // When text is cleaned, all other fields must be copied verbatim.
        let id = UUID()
        let dirty = "Preamble:\n\nResponse:\nShort answer."
        let msg = ChatMessage(id: id, text: dirty, isUser: false,
                              timestamp: now, imagePath: "/img.png",
                              duration: 1.23)
        let result = CodeView.sanitizedHistory([msg])
        guard let r = result.first else { Issue.record("Expected one result"); return }
        #expect(r.id        == id,          "id must be preserved when text is cleaned")
        #expect(r.timestamp == now,         "timestamp must be preserved")
        #expect(r.imagePath == "/img.png",  "imagePath must be preserved")
        #expect(r.duration  == 1.23,        "duration must be preserved")
        #expect(r.isUser    == false,       "isUser must remain false after cleaning")
    }

    // MARK: - mixed list

    @Test func mixedHistoryOnlyCleansDirtyAssistantMessages() {
        let userID  = UUID()
        let cleanID = UUID()
        let dirtyID = UUID()
        let messages: [ChatMessage] = [
            userMsg("Hello, Salehman!",                          id: userID),
            assistantMsg("Clean reply.",                         id: cleanID),
            assistantMsg("Preamble:\n\nResponse:\nActual reply.", id: dirtyID),
        ]
        let result = CodeView.sanitizedHistory(messages)
        #expect(result.count == 3)
        #expect(result[0].text == "Hello, Salehman!",
                "user message must not be modified")
        #expect(result[1].text == "Clean reply.",
                "already-clean assistant message must not be modified")
        #expect(result[2].text == "Actual reply.",
                "dirty assistant message must have scaffold stripped")
        #expect(result[0].id == userID)
        #expect(result[1].id == cleanID)
        #expect(result[2].id == dirtyID)
    }
}
