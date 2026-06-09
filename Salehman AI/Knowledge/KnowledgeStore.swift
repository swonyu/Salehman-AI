import Foundation
import NaturalLanguage
import Accelerate

/// A document the owner added to their private Knowledge vault. `nonisolated`
/// (all-Sendable value type) so its `id`/`name` etc. are readable off the main
/// actor — the nonisolated `KnowledgeStore` returns these and the test target
/// reads them; MainActor-default isolation would make that a Swift 6 error.
nonisolated struct KnowledgeDoc: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var kind: String
    var icon: String
    var addedAt = Date()
    var chunkCount: Int
}

/// One retrievable passage of a document (+ an optional on-device embedding).
struct KnowledgeChunk: Codable, Equatable, Sendable {
    var docID: UUID
    var docName: String
    var ordinal: Int
    var text: String
    var vector: [Float]?   // Float, not Double — halves the in-memory vector RAM
}

/// A search result: the passage + which document it came from + a score.
/// `nonisolated` so its `Equatable` conformance works from nonisolated contexts
/// (the test target's `#expect(hit == …)`) — a Swift-6-language-mode error otherwise.
nonisolated struct KnowledgeHit: Equatable, Sendable {
    var docName: String
    var text: String
    var score: Double
}

/// The owner's private on-device document corpus. `@unchecked Sendable` singleton
/// (NSLock-guarded, MemoryStore pattern) so the Foundation Models `search_documents`
/// tool can query it off the main actor, and embedding runs off-main too. Persisted
/// as one JSON file in Application Support. Nothing leaves the Mac.
nonisolated final class KnowledgeStore: @unchecked Sendable {
    static let shared = KnowledgeStore()

    private let lock = NSLock()
    private var docs: [KnowledgeDoc] = []
    private var chunks: [KnowledgeChunk] = []

    /// Test-only: when set (before the store is used), persistence is redirected
    /// to this directory so tests never read or — critically — `clear()`/`save()`
    /// over the owner's REAL on-disk vault. Production never sets this; it stays
    /// nil, so behavior is unchanged. Pair with `reloadForTesting()`.
    nonisolated(unsafe) static var testBaseDirOverride: URL? = nil

    /// Test-only: drop in-memory state and reload from the (possibly overridden)
    /// file, so a test can point at a temp dir and start from a known state.
    func reloadForTesting() {
        lock.lock(); docs.removeAll(); chunks.removeAll(); lock.unlock()
        load()
    }

    private init() { load() }

    // MARK: Read

    func allDocuments() -> [KnowledgeDoc] {
        lock.lock(); defer { lock.unlock() }
        return docs
    }

    func isEmpty() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return docs.isEmpty
    }

    /// All passages of one document, concatenated in original order and capped at
    /// `maxChars` — the input for an on-device summary. Passages overlap slightly
    /// by design (see `chunk`); harmless redundancy for a summary.
    func text(forDocument id: UUID, maxChars: Int = 6000) -> String {
        lock.lock()
        let mine = chunks.filter { $0.docID == id }.sorted { $0.ordinal < $1.ordinal }
        lock.unlock()
        var out = ""
        for c in mine {
            if out.count >= maxChars { break }
            out += (out.isEmpty ? "" : "\n\n") + c.text
        }
        return String(out.prefix(maxChars))
    }

    // MARK: Mutate

    /// Chunk + embed `fullText` and add it as a document. Heavy work (embedding)
    /// is done before taking the lock so the critical section stays short.
    func addDocument(name: String, kind: String, icon: String, fullText: String) {
        let id = UUID()
        let passages = Self.chunk(fullText)
        let newChunks = passages.enumerated().map { i, t in
            KnowledgeChunk(docID: id, docName: name, ordinal: i, text: t, vector: Self.embed(t))
        }
        lock.lock()
        docs.insert(KnowledgeDoc(id: id, name: name, kind: kind, icon: icon, chunkCount: newChunks.count), at: 0)
        chunks.append(contentsOf: newChunks)
        lock.unlock()
        save()
    }

    func deleteDocument(_ id: UUID) {
        lock.lock()
        docs.removeAll { $0.id == id }
        chunks.removeAll { $0.docID == id }
        lock.unlock()
        save()
    }

    func clear() {
        lock.lock(); docs.removeAll(); chunks.removeAll(); lock.unlock()
        save()
    }

    // MARK: Search

    /// Top-`k` passages for `query`. Keyword overlap is the primary, always-works
    /// signal; an on-device embedding cosine is added as a semantic boost when
    /// `NLEmbedding` is available for both query and chunk. Pass `inDocument` to
    /// scope the search to a single document (used by the per-doc Q&A).
    func search(query: String, k: Int = 5, inDocument docID: UUID? = nil) -> [KnowledgeHit] {
        lock.lock(); var all = chunks; lock.unlock()
        if let docID { all = all.filter { $0.docID == docID } }
        guard !all.isEmpty else { return [] }
        let qVec = Self.embed(query)
        let scored: [(KnowledgeChunk, Double)] = all.map { c in
            var score = Self.keywordScore(query: query, text: c.text)
            // Clamp the embedding contribution to non-negative — a NEGATIVE
            // cosine on a weak semantic match shouldn't be allowed to drag down
            // a chunk that has solid keyword overlap.
            if let qv = qVec, let cv = c.vector { score += max(0, Self.cosine(qv, cv)) }
            return (c, score)
        }
        // Filter-then-prefix (the old order capped recall at k even when some
        // of the top-k were zero-score, silently dropping useful results).
        // Then over-fetch ~3k and run MMR so the final k passages favor
        // topical DIVERSITY — chunks overlap by ~150 chars by design, so the
        // pure top-k frequently returns near-duplicates from the same region.
        let candidates = scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        let pool = Array(candidates.prefix(max(k * 3, k + 4)))
        let picked = Self.mmr(pool, k: k)
        return picked.map { KnowledgeHit(docName: $0.0.docName, text: $0.0.text, score: $0.1) }
    }

    // MARK: Helpers

    /// Split text into ~800-char passages with ~150-char overlap, breaking on
    /// whitespace so words aren't cut mid-token.
    static func chunk(_ text: String, size: Int = 800, overlap: Int = 150) -> [String] {
        let clean = text.replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > size else { return clean.isEmpty ? [] : [clean] }
        var out: [String] = []
        let chars = Array(clean)
        var start = 0
        while start < chars.count {
            var end = min(start + size, chars.count)
            var boundaryFound = false
            if end < chars.count {  // back up to a whitespace boundary
                var b = end
                while b > start && !chars[b - 1].isWhitespace { b -= 1 }
                if b > start + size / 2 { end = b; boundaryFound = true }
            }
            out.append(String(chars[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines))
            if end >= chars.count { break }
            // On a boundaryless run (single huge token, no whitespace to break
            // on), the original `size − overlap` step gets tiny and the chunker
            // emits an explosion of near-duplicate windows. There's no semantic
            // boundary to preserve in that case, so cap the effective overlap
            // at size/2 to guarantee meaningful per-step progress. Normal text
            // always finds a boundary → unchanged behavior.
            let effOverlap = boundaryFound ? overlap : min(overlap, size / 2)
            start = max(end - effOverlap, start + 1)
        }
        return out.filter { !$0.isEmpty }
    }

    static func embed(_ text: String) -> [Float]? {
        guard let e = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        // Down-cast to Float: halves the per-chunk vector footprint (512 dims ×
        // 8→4 bytes). Cosine still accumulates in Double, so accuracy is unchanged.
        return e.vector(for: text)?.map { Float($0) }
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        // Accelerate (vDSP) computes the dot product and both squared norms with
        // SIMD — markedly faster than the scalar per-element loop on the search hot
        // path (one cosine per chunk per query), with no change to the math.
        let n = vDSP_Length(a.count)
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, n)
        vDSP_svesq(a, 1, &na, n)   // Σ a²
        vDSP_svesq(b, 1, &nb, n)   // Σ b²
        let denom = (Double(na).squareRoot() * Double(nb).squareRoot())
        return denom == 0 ? 0 : Double(dot) / denom
    }

    /// Fraction of distinct query terms (≥3 chars) that appear in `text`.
    static func keywordScore(query: String, text: String) -> Double {
        let terms = Set(query.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 3 })
        guard !terms.isEmpty else { return 0 }
        let lower = text.lowercased()
        let hits = terms.filter { lower.contains($0) }.count
        return Double(hits) / Double(terms.count)
    }

    /// Maximal-Marginal-Relevance selection. Picks `k` items from `scored` that
    /// jointly maximize relevance AND novelty:
    ///   pick = argmax_c [ λ·relevance(c) − (1−λ)·max_{s ∈ picked} sim(c, s) ]
    /// `λ = 0.7` favors relevance; bumping toward 1.0 reverts to plain top-k.
    /// The win: a chunk that overlaps a previously-picked passage (very common
    /// given our 150-char chunker overlap) gets penalized, so the final set
    /// spans the document(s) instead of returning five near-duplicate sentences.
    static func mmr(_ scored: [(KnowledgeChunk, Double)], k: Int, lambda: Double = 0.7) -> [(KnowledgeChunk, Double)] {
        guard !scored.isEmpty, k > 0 else { return [] }
        var pool = scored
        var picked: [(KnowledgeChunk, Double)] = []
        while !pool.isEmpty && picked.count < k {
            var bestIdx = 0
            var bestVal = -Double.infinity
            for (i, candidate) in pool.enumerated() {
                let maxSim = picked.lazy
                    .map { chunkSimilarity($0.0, candidate.0) }
                    .max() ?? 0
                let mmrVal = lambda * candidate.1 - (1 - lambda) * maxSim
                if mmrVal > bestVal { bestVal = mmrVal; bestIdx = i }
            }
            picked.append(pool.remove(at: bestIdx))
        }
        return picked
    }

    /// Similarity between two chunks, used by MMR to penalize near-duplicates.
    /// Prefers the on-device embedding cosine; falls back to a cheap word-set
    /// Jaccard so chunks without vectors (NLEmbedding miss, non-English text)
    /// still get diversity-pressure instead of silently degrading to top-k.
    static func chunkSimilarity(_ a: KnowledgeChunk, _ b: KnowledgeChunk) -> Double {
        if let va = a.vector, let vb = b.vector { return max(0, cosine(va, vb)) }
        let aw = wordSet(a.text), bw = wordSet(b.text)
        let uni = aw.union(bw).count
        return uni == 0 ? 0 : Double(aw.intersection(bw).count) / Double(uni)
    }

    private static func wordSet(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }
            .map(String.init).filter { $0.count >= 3 })
    }

    // MARK: Persistence

    private struct Snapshot: Codable { var docs: [KnowledgeDoc]; var chunks: [KnowledgeChunk] }

    private var fileURL: URL {
        let base = Self.testBaseDirOverride
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SalehmanAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("knowledge.json")
    }

    private func save() {
        lock.lock(); let snap = Snapshot(docs: docs, chunks: chunks); lock.unlock()
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }  // no file yet — fine
        guard let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            // The file EXISTS but is corrupt/unreadable. Don't silently start empty and
            // then save over it (that would lose the whole vault with no warning). Move
            // the bad file aside so the owner can recover it, then start fresh.
            let backup = fileURL.appendingPathExtension("corrupt-\(UUID().uuidString)")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return
        }
        docs = snap.docs
        chunks = snap.chunks
    }
}
