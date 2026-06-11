import Testing
import Foundation
@testable import Salehman_AI

/// Pins `ScratchpadList` — the pure shaping behind the Notes tab (active-first
/// ordering, the case-insensitive filter for the new search box, and the
/// completed-count for the "Clear completed" button).
struct ScratchpadListTests {

    private func task(_ title: String, done: Bool = false) -> TaskItem { TaskItem(title: title, done: done) }
    private func note(_ text: String) -> Note { Note(text: text) }

    @Test func tasksPutActiveBeforeDoneKeepingInsertionOrder() {
        let xs = [task("a"), task("b", done: true), task("c"), task("d", done: true)]
        #expect(ScratchpadList.tasks(xs).map(\.title) == ["a", "c", "b", "d"])
    }

    @Test func taskFilterIsCaseInsensitiveSubstringAndStaysActiveFirst() {
        let xs = [task("Buy milk"), task("call MOM"), task("buy bread", done: true)]
        #expect(ScratchpadList.tasks(xs, filter: "buy").map(\.title) == ["Buy milk", "buy bread"])
    }

    @Test func taskFilterCanMatchNothing() {
        #expect(ScratchpadList.tasks([task("x")], filter: "zzz").isEmpty)
    }

    @Test func blankOrWhitespaceFilterReturnsAllOrdered() {
        let xs = [task("a", done: true), task("b")]
        #expect(ScratchpadList.tasks(xs, filter: "   ").map(\.title) == ["b", "a"])
    }

    @Test func notesFilterMatchesBodyCaseInsensitively() {
        let xs = [note("groceries: milk"), note("meeting notes")]
        #expect(ScratchpadList.notes(xs, filter: "MILK").map(\.text) == ["groceries: milk"])
    }

    @Test func completedCountCountsDoneOnly() {
        #expect(ScratchpadList.completedCount([task("a", done: true), task("b"), task("c", done: true)]) == 2)
        #expect(ScratchpadList.completedCount([]) == 0)
    }
}
