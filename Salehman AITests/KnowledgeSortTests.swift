import Testing
import Foundation
@testable import Salehman_AI

/// Pins `KnowledgeSort.apply` — the document ordering behind the Knowledge list's
/// sort menu. Pure over `[KnowledgeDoc]`.
struct KnowledgeSortTests {

    private func doc(_ name: String, passages: Int = 1, at t: Double = 0) -> KnowledgeDoc {
        KnowledgeDoc(name: name, kind: "file", icon: "doc",
                     addedAt: Date(timeIntervalSince1970: t), chunkCount: passages)
    }
    private func names(_ xs: [KnowledgeDoc]) -> [String] { xs.map(\.name) }

    @Test func recentPutsNewestFirst() {
        let xs = [doc("old", at: 100), doc("new", at: 300), doc("mid", at: 200)]
        #expect(names(KnowledgeSort.recent.apply(xs)) == ["new", "mid", "old"])
    }

    @Test func nameSortsAlphabeticallyCaseInsensitive() {
        let xs = [doc("Zebra"), doc("apple"), doc("Mango")]
        #expect(names(KnowledgeSort.name.apply(xs)) == ["apple", "Mango", "Zebra"])
    }

    @Test func passagesSortsMostFirst() {
        let xs = [doc("small", passages: 3), doc("big", passages: 99), doc("mid", passages: 31)]
        #expect(names(KnowledgeSort.passages.apply(xs)) == ["big", "mid", "small"])
    }

    @Test func emptyAndSingleAreStable() {
        #expect(KnowledgeSort.recent.apply([]).isEmpty)
        #expect(names(KnowledgeSort.name.apply([doc("only")])) == ["only"])
    }

    @Test func allCasesHaveTitles() {
        for c in KnowledgeSort.allCases { #expect(!c.title.isEmpty) }
    }

    @Test func filterMatchesNameSubstringCaseInsensitive() {
        let xs = [doc("Quarterly Report"), doc("meeting notes"), doc("report draft")]
        #expect(names(KnowledgeSort.name.apply(xs, filter: "report")) == ["Quarterly Report", "report draft"])
    }

    @Test func filterThenSortComposes() {
        let xs = [doc("alpha report", passages: 5), doc("beta report", passages: 50), doc("gamma memo", passages: 99)]
        #expect(names(KnowledgeSort.passages.apply(xs, filter: "report")) == ["beta report", "alpha report"])
    }

    @Test func filterCanMatchNothingAndBlankReturnsAll() {
        #expect(KnowledgeSort.recent.apply([doc("x")], filter: "zzz").isEmpty)
        #expect(KnowledgeSort.name.apply([doc("a"), doc("b")], filter: "  ").count == 2)
    }
}
