import Testing
import Foundation
@testable import Salehman_AI

/// Pins `MemorySort.apply` — the ordering + filter behind the Memory viewer's
/// sort menu. Facts arrive in `MemoryStore.allFacts()` order (oldest first).
struct MemorySortTests {

    // Store order: oldest → newest.
    private let facts = ["User's name is Ann.", "User likes coffee.", "User is in Riyadh."]

    @Test func oldestKeepsStoreOrder() {
        #expect(MemorySort.oldest.apply(facts) == facts)
    }

    @Test func newestReversesStoreOrder() {
        #expect(MemorySort.newest.apply(facts) == Array(facts.reversed()))
    }

    @Test func alphabeticalIsCaseInsensitive() {
        #expect(MemorySort.alphabetical.apply(["banana", "Apple", "cherry"]) == ["Apple", "banana", "cherry"])
    }

    @Test func filterIsCaseInsensitiveSubstringAppliedBeforeSort() {
        let xs = ["User likes Coffee.", "User is in Riyadh.", "User dislikes coffee shops."]
        // "coffee" matches 2 (case-insensitively), then newest reverses them.
        #expect(MemorySort.newest.apply(xs, filter: "COFFEE")
                == ["User dislikes coffee shops.", "User likes Coffee."])
    }

    @Test func blankFilterReturnsAllAndNoMatchReturnsEmpty() {
        #expect(MemorySort.oldest.apply(facts, filter: "   ").count == 3)
        #expect(MemorySort.alphabetical.apply(facts, filter: "zzz").isEmpty)
    }

    @Test func emptyInputStaysEmpty() {
        for s in MemorySort.allCases { #expect(s.apply([]).isEmpty) }
    }

    @Test func allCasesHaveTitleAndIcon() {
        for s in MemorySort.allCases {
            #expect(!s.title.isEmpty)
            #expect(!s.icon.isEmpty)
        }
    }
}
