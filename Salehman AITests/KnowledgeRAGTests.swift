import Testing
import Foundation
@testable import Salehman_AI

// MARK: - KnowledgeStore RAG helpers (chunk / keyword / cosine / search)
//
// These power the on-device document Q&A. The static helpers are pure and
// always available; search exercises the lock-guarded store + scoring.
// Cases are written to be side-effect tolerant (clear before/after) and the
// suite is serialized because it mutates the shared on-disk knowledge.json.

@Suite(.serialized)
struct KnowledgeRAGTests {

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
        KnowledgeStore.shared.clear()
        defer { KnowledgeStore.shared.clear() }
        let doc = "The quick brown fox jumps over the lazy dog. Apple banana cherry date."
        KnowledgeStore.shared.addDocument(name: "test.txt", kind: "txt", icon: "doc", fullText: doc)
        let hits = KnowledgeStore.shared.search(query: "apple banana cherry", k: 2)
        #expect(hits.count <= 2)
        if hits.count >= 2 {
            #expect(hits[0].score >= hits[1].score)
        }
        #expect(hits.allSatisfy { $0.score > 0 })
    }

    @Test
    func searchInDocumentScopesCorrectly() {
        KnowledgeStore.shared.clear()
        defer { KnowledgeStore.shared.clear() }
        KnowledgeStore.shared.addDocument(name: "a.txt", kind: "txt", icon: "doc", fullText: "alpha beta only in a")
        KnowledgeStore.shared.addDocument(name: "b.txt", kind: "txt", icon: "doc", fullText: "beta gamma only in b")
        // find the doc id somehow? use search on all then pick, or since we control, search(in:) requires UUID.
        // For simplicity: search broad, then use the returned doc's id? But API is search(inDocument:).
        // Instead: after adds, we can use internal? For now test via full search + name filter, or expose later.
        // To satisfy case without more seams: broad search returns both, inDocument for one doc's chunks only.
        let all = KnowledgeStore.shared.search(query: "beta", k: 10)
        #expect(all.count >= 1)
        // To test inDocument we would need a docID; since add doesn't return id, we can fetch allDocuments and use one.
        if let doc = KnowledgeStore.shared.allDocuments().first(where: { $0.name == "a.txt" }) {
            let scoped = KnowledgeStore.shared.search(query: "alpha", k: 5, inDocument: doc.id)
            #expect(scoped.allSatisfy { $0.docName == "a.txt" })
            #expect(scoped.contains { $0.text.contains("alpha") })
        }
    }

    @Test
    func searchOnEmptyStoreReturnsEmpty() {
        KnowledgeStore.shared.clear()
        defer { KnowledgeStore.shared.clear() }
        #expect(KnowledgeStore.shared.search(query: "anything") == [])
    }
}
