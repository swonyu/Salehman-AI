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

    // MARK: chunkSimilarity + mmr (pure — no store mutation)
    //
    // chunkSimilarity drives the novelty-penalty inside mmr: chunks that are
    // near-duplicates (high similarity to already-picked results) lose their
    // MMR value so a less-relevant but novel chunk can win instead.
    //
    // Two similarity paths:
    //   • Both chunks have a vector → cosine similarity (clamped ≥ 0)
    //   • Either chunk lacks a vector → Jaccard over word sets (words ≥ 3 chars)

    private func makeChunk(_ text: String, vector: [Float]? = nil) -> KnowledgeChunk {
        KnowledgeChunk(docID: UUID(), docName: "d", ordinal: 0, text: text, vector: vector)
    }

    // MARK: chunkSimilarity

    @Test func chunkSimilarityIdenticalTextNoVectorIsOne() {
        let a = makeChunk("the quick brown fox")
        let b = makeChunk("the quick brown fox")
        #expect(KnowledgeStore.chunkSimilarity(a, b) == 1.0,
                "identical text with no vectors must return Jaccard=1.0")
    }

    @Test func chunkSimilarityDisjointTextIsZero() {
        let a = makeChunk("alpha beta gamma delta")
        let b = makeChunk("epsilon zeta theta iota")
        #expect(KnowledgeStore.chunkSimilarity(a, b) == 0.0,
                "fully disjoint word sets must return Jaccard=0.0")
    }

    @Test func chunkSimilarityVectorPathUsesCosineClamped() {
        // Identical unit vectors → cosine=1.0 → max(0, 1.0) = 1.0
        let a = makeChunk("x", vector: [1.0, 0.0])
        let b = makeChunk("x", vector: [1.0, 0.0])
        #expect(KnowledgeStore.chunkSimilarity(a, b) == 1.0,
                "identical vectors must return 1.0 via cosine path")
    }

    @Test func chunkSimilarityOrthogonalVectorsIsZero() {
        // cosine([1,0],[0,1]) = 0.0 → max(0, 0) = 0.0
        let a = makeChunk("x", vector: [1.0, 0.0])
        let b = makeChunk("x", vector: [0.0, 1.0])
        #expect(KnowledgeStore.chunkSimilarity(a, b) == 0.0,
                "orthogonal vectors must return 0.0 (cosine clamped at zero)")
    }

    @Test func chunkSimilarityMixedVectorNilFallsToJaccard() {
        // Only `b` has a vector → `if let va = a.vector, let vb = b.vector` guard fails.
        // Falls to Jaccard; identical text → Jaccard=1.0. Pins the BOTH-or-neither
        // requirement for the vector path.
        let a = makeChunk("same text for both chunks", vector: nil)
        let b = makeChunk("same text for both chunks", vector: [1.0, 0.0])
        #expect(KnowledgeStore.chunkSimilarity(a, b) == 1.0,
                "when only one chunk has a vector, must fall back to Jaccard (not use partial cosine)")
    }

    // MARK: mmr

    @Test func mmrEmptyPoolReturnsEmpty() {
        #expect(KnowledgeStore.mmr([], k: 5).isEmpty,
                "mmr over empty pool must return []")
    }

    @Test func mmrKZeroReturnsEmpty() {
        let c = makeChunk("some content here")
        #expect(KnowledgeStore.mmr([(c, 0.9)], k: 0).isEmpty,
                "mmr with k=0 must return []")
    }

    @Test func mmrKGreaterThanPoolReturnsAll() {
        // The while loop drains the entire pool before k is reached.
        let chunks = (1...3).map { makeChunk("chunk item number \($0)") }
        let scored = chunks.map { ($0, 0.5) }
        let result = KnowledgeStore.mmr(scored, k: 10)
        #expect(result.count == 3,
                "when k exceeds pool size, mmr must return all items; got \(result.count)")
    }

    @Test func mmrLambda1PicksInPureScoreOrder() {
        // lambda=1.0 → MMR = 1.0×score − 0.0×maxSim = score.
        // Novelty penalty vanishes; selection order equals descending relevance.
        let low  = makeChunk("low relevance content word")
        let mid  = makeChunk("mid relevance content word")
        let high = makeChunk("high relevance content word")
        let scored: [(KnowledgeChunk, Double)] = [(low, 0.3), (high, 0.9), (mid, 0.6)]
        let result = KnowledgeStore.mmr(scored, k: 3, lambda: 1.0)
        #expect(result.count == 3)
        #expect(result[0].1 == 0.9, "lambda=1.0: first pick must be highest score (0.9)")
        #expect(result[1].1 == 0.6, "lambda=1.0: second pick must be middle score (0.6)")
        #expect(result[2].1 == 0.3, "lambda=1.0: third pick must be lowest score (0.3)")
    }

    @Test func mmrDiversityPenaltySurpassesNearDuplicate() {
        // After nearDupA (score=0.9) is picked first:
        //   nearDupB  (Jaccard=1.0 with A): MMR = 0.7×0.8 − 0.3×1.0 = 0.56 − 0.30 = 0.26
        //   distinct  (Jaccard=0.0 with A): MMR = 0.7×0.5 − 0.3×0.0 = 0.35 − 0.00 = 0.35 ← wins
        //
        // lambda=0.7 is the default, so this also exercises the defaulted argument.
        let nearDupA = makeChunk("machine learning neural network deep learning transformer")
        let nearDupB = makeChunk("machine learning neural network deep learning transformer")
        let distinct = makeChunk("apple pie recipe butter sugar bake flour pastry")
        let scored: [(KnowledgeChunk, Double)] = [
            (nearDupA, 0.9),
            (nearDupB, 0.8),
            (distinct, 0.5)
        ]
        let result = KnowledgeStore.mmr(scored, k: 2)
        #expect(result.count == 2)
        #expect(result[0].1 == 0.9,
                "first pick must be the highest-scoring item (nearDupA, score=0.9)")
        #expect(result[1].1 == 0.5,
                "second pick must be 'distinct' (score=0.5), not near-dup (score=0.8) — diversity penalty wins")
    }
}
