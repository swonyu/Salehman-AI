import Testing
import Foundation
@testable import Salehman_AI

// MARK: - KnowledgeStore RAG helpers (chunk / keyword / cosine / search)
//
// These power the on-device document Q&A. The static helpers are pure and
// always available; search exercises the lock-guarded store + scoring.
//
// HERMETIC: the search cases redirect KnowledgeStore persistence to a throwaway
// temp dir (via `testBaseDirOverride` + `reloadForTesting`) so they NEVER read or
// clobber the owner's real ~/Library/Application Support/SalehmanAI/knowledge.json.
// (Earlier these called `clear()` on the live singleton and silently wiped the
// real vault on every run — see the 2026-06-06 review.) Suite is serialized
// because it mutates that shared global override + singleton.

@Suite(.serialized)
struct KnowledgeRAGTests {

    /// Point the shared store at a fresh empty temp dir for `body`, then restore
    /// the previous override and delete the dir. Nothing touches the real vault.
    private func withTempVault(_ body: () throws -> Void) rethrows {
        let prev = KnowledgeStore.testBaseDirOverride
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("KnowledgeTest_\(UUID().uuidString.prefix(8))", isDirectory: true)
        KnowledgeStore.testBaseDirOverride = dir
        KnowledgeStore.shared.reloadForTesting()   // now backed by the empty temp dir
        defer {
            KnowledgeStore.shared.clear()           // writes empty snapshot to TEMP, not the real vault
            KnowledgeStore.testBaseDirOverride = prev
            try? FileManager.default.removeItem(at: dir)
        }
        try body()
    }

    // MARK: chunk

    @Test
    func chunkEmptyOrShortReturnsAsExpected() {
        // Per CODEBASE_REVIEW: empty/ws -> []; short < size -> [trimmed]; big token terminates.
        #expect(KnowledgeStore.chunk("").isEmpty)
        #expect(KnowledgeStore.chunk("   \t\n").isEmpty)
        let short = KnowledgeStore.chunk("hello")
        #expect(short.count == 1 && short[0] == "hello")
        // long non-ws token must not loop forever
        let token = String(repeating: "X", count: 1200)
        let chunks = KnowledgeStore.chunk(token, size: 200)
        #expect(chunks.count >= 1 && chunks.count < 20)
    }

    @Test
    func chunkLongTextYieldsOverlappingChunks() {
        let text = String(repeating: "word ", count: 300) // >800 chars
        let chunks = KnowledgeStore.chunk(text, size: 800, overlap: 150)
        #expect(chunks.count >= 2)
        // union of trimmed non-empty should cover original non-ws
        let union = chunks.joined(separator: " ")
        #expect(union.replacingOccurrences(of: " ", with: "").count > 0)
    }

    @Test
    func chunkSingleTokenLargerThanSizeStillTerminates() {
        let big = String(repeating: "x", count: 900)
        let chunks = KnowledgeStore.chunk(big, size: 800)
        #expect(chunks.count == 1 || chunks.count == 2)
    }

    // MARK: keywordScore

    @Test
    func keywordScoreShortTermsIgnoredAndScoringWorks() {
        #expect(KnowledgeStore.keywordScore(query: "ab c de", text: "abcde") == 0) // all <3
        let score = KnowledgeStore.keywordScore(query: "apple banana cherry", text: "I like apple and BANANA pie")
        #expect(score > 0.6 && score <= 1.0) // 2/3
    }

    @Test
    func keywordScoreEmptyQueryIsZero() {
        #expect(KnowledgeStore.keywordScore(query: "", text: "anything") == 0)
    }

    // MARK: cosine

    @Test
    func cosineIdenticalOrthogonalAndEdgeCases() {
        // Embedding vectors are [Float] (halved RAM vs [Double], commit 8152d68).
        let v: [Float] = [1.0, 0.0, 0.0]
        #expect(KnowledgeStore.cosine(v, v) == 1.0)
        #expect(KnowledgeStore.cosine(v, [0.0, 1.0, 0.0]) == 0.0)
        #expect(KnowledgeStore.cosine([], [1.0]) == 0)
        #expect(KnowledgeStore.cosine([0.0, 0.0], [0.0, 0.0]) == 0)
        // mismatched lengths -> 0 (no crash/NaN)
        #expect(KnowledgeStore.cosine([1.0, 2.0], [1.0]) == 0)
    }

    // MARK: search (requires store mutation; serialized + cleanup)

    @Test
    func searchReturnsAtMostKPositiveScoredOrdered() {
        withTempVault {
            // Two matching docs → two positive hits, so the ordering check is
            // UNCONDITIONAL (the old version guarded it behind `if count >= 2` and
            // would pass even if search silently returned nothing).
            KnowledgeStore.shared.addDocument(name: "a.txt", kind: "txt", icon: "doc",
                fullText: "apple banana cherry — first document about fruit")
            KnowledgeStore.shared.addDocument(name: "b.txt", kind: "txt", icon: "doc",
                fullText: "apple banana cherry — second document, also fruit salad")
            #expect(KnowledgeStore.shared.allDocuments().count == 2)
            let hits = KnowledgeStore.shared.search(query: "apple banana cherry", k: 2)
            #expect(hits.count == 2)
            #expect(hits[0].score >= hits[1].score)
            #expect(hits.allSatisfy { $0.score > 0 })
        }
    }

    @Test
    func searchInDocumentScopesCorrectly() throws {
        try withTempVault {
            KnowledgeStore.shared.addDocument(name: "a.txt", kind: "txt", icon: "doc", fullText: "alpha beta only in a")
            KnowledgeStore.shared.addDocument(name: "b.txt", kind: "txt", icon: "doc", fullText: "beta gamma only in b")
            // Unconditional: require the doc to exist (a skipped `if let` used to let
            // this case pass with zero scoping assertions executed).
            #expect(KnowledgeStore.shared.allDocuments().count == 2)
            let a = try #require(KnowledgeStore.shared.allDocuments().first { $0.name == "a.txt" })
            let scoped = KnowledgeStore.shared.search(query: "alpha", k: 5, inDocument: a.id)
            #expect(!scoped.isEmpty)
            #expect(scoped.allSatisfy { $0.docName == "a.txt" })
            #expect(scoped.contains { $0.text.contains("alpha") })
        }
    }

    @Test
    func searchOnEmptyStoreReturnsEmpty() {
        withTempVault {
            #expect(KnowledgeStore.shared.search(query: "anything") == [])
        }
    }
}
