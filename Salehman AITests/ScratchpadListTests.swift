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

    // MARK: - markdownList(tasks:) — GFM task-list export

    @Test func markdownListTasksEmptyReturnsEmpty() {
        #expect(ScratchpadList.markdownList(tasks: []).isEmpty)
    }

    @Test func markdownListTasksFormatsGFMCheckboxes() {
        // Open tasks: "- [ ] title", done tasks: "- [x] title", joined with "\n".
        let tasks = [task("buy milk"), task("call mom", done: true), task("write tests")]
        let md = ScratchpadList.markdownList(tasks: tasks)
        #expect(md == "- [ ] buy milk\n- [x] call mom\n- [ ] write tests",
                "GFM task-list must use '- [ ]' for open and '- [x]' for done")
    }

    // MARK: - markdownList(notes:) — plain-list export

    @Test func markdownListNotesEmptyReturnsEmpty() {
        #expect(ScratchpadList.markdownList(notes: []).isEmpty)
    }

    @Test func markdownListNotesFormatsPlainList() {
        let notes = [note("first thought"), note("second idea")]
        let md = ScratchpadList.markdownList(notes: notes)
        #expect(md == "- first thought\n- second idea",
                "note list must prefix each line with '- ' and join with newlines")
    }

    // MARK: - ageLabel — relative time labelling

    @Test func ageLabelJustNow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(ScratchpadList.ageLabel(for: now.addingTimeInterval(-30), now: now) == "just now")
        #expect(ScratchpadList.ageLabel(for: now.addingTimeInterval(-1), now: now) == "just now",
                "1-second-old date must be 'just now'")
        #expect(ScratchpadList.ageLabel(for: now.addingTimeInterval(-59), now: now) == "just now",
                "59 seconds is still 'just now'")
    }

    @Test func ageLabelShowsMinutes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(ScratchpadList.ageLabel(for: now.addingTimeInterval(-5 * 60), now: now) == "5m")
        #expect(ScratchpadList.ageLabel(for: now.addingTimeInterval(-59 * 60), now: now) == "59m",
                "59 minutes (< 1 hour) must format as '59m'")
    }

    @Test func ageLabelShowsHours() {
        // Anchor `now` at 23:00 local so the sub-24h offsets below stay on the
        // SAME calendar day. The hours bucket is today-only: a sub-24h date that
        // has crossed midnight into the previous day reads "yesterday" instead
        // (covered by ScratchpadAgeLabelTests.yesterdayLabel). ageLabel is now
        // hermetic — its day checks use the injected `now`, not the real clock.
        var cal = Calendar.current
        cal.timeZone = .current
        let now = cal.date(from: DateComponents(year: 2000, month: 6, day: 15,
                                                hour: 23, minute: 0))!
        #expect(ScratchpadList.ageLabel(for: now.addingTimeInterval(-3 * 3600), now: now) == "3h")
        #expect(ScratchpadList.ageLabel(for: now.addingTimeInterval(-22 * 3600), now: now) == "22h",
                "22 hours earlier on the same calendar day must format as '22h'")
    }

    @Test func ageLabelShowsYesterdayForPreviousCalendarDay() {
        // Now that ageLabel is hermetic, the "yesterday" branch IS deterministic:
        // a sub-24h date that crossed midnight into the prior day reads
        // "yesterday", not "Nh". (At 06:00, a note from 20:00 the night before is
        // only 10h old but belongs to yesterday.)
        var cal = Calendar.current
        cal.timeZone = .current
        let now = cal.date(from: DateComponents(year: 2000, month: 6, day: 15,
                                                hour: 6, minute: 0))!
        #expect(ScratchpadList.ageLabel(for: now.addingTimeInterval(-10 * 3600), now: now) == "yesterday")
    }

    @Test func ageLabelFormatsOldDatesAsMonthDay() {
        // Dates ≥ 24 h ago that are NOT calendar-yesterday fall through to the
        // month+day formatter. An epoch-era date can never be "yesterday" in a
        // real test run, so the branch is exercised deterministically.
        let now  = Date(timeIntervalSince1970: 1_000_000)   // ~1970 Jan 12
        let date = Date(timeIntervalSince1970: 0)            // 1970 Jan 1
        let label = ScratchpadList.ageLabel(for: date, now: now)
        // Verify it's none of the relative labels.
        #expect(!label.hasPrefix("just"), "epoch date must not produce 'just now'")
        #expect(!label.hasSuffix("m"),    "epoch date must not produce a minute label")
        #expect(!label.hasSuffix("h"),    "epoch date must not produce an hour label")
        #expect(label != "yesterday",     "epoch date must not produce 'yesterday'")
        #expect(!label.isEmpty,           "old date must produce a non-empty formatted string")
    }

    // NOTE: ageLabel is hermetic — its day checks (`isDate(_:inSameDayAs:)`)
    // are computed against the injected `now`, so the "yesterday" branch IS
    // deterministically covered above and in ScratchpadAgeLabelTests.
}
