import Foundation
import NaturalLanguage

/// A document the owner added to their private Knowledge vault.
struct KnowledgeDoc: Codable, Identifiable, Equatable, Sendable {
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
    var vector: [Double]?
}

/// A search result: the passage + which document it came from + a score.
struct KnowledgeHit: Equatable, Sendable {
    var docName: String
    var text: String
    var score: Double
}

/// The owner's private on-device document corpus. `@unchecked Sendable` singleton
/// (NSLock-guarded, MemoryStore pattern) so the Foundation Models `search_documents`
/// tool can query it off the main actor, and embedding runs off-main too. Persisted
/// as one JSON file in Application Support. Nothing leaves the Mac.
final class KnowledgeStore: @unchecked Sendable {
    static let shared = KnowledgeStore()

    private let lock = NSLock()
    private var docs: [KnowledgeDoc] = []
    private var chunks: [KnowledgeChunk] = []

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
        let scored = all.map { c -> (KnowledgeChunk, Double) in
            var score = Self.keywordScore(query: query, text: c.text)
            if let qv = qVec, let cv = c.vector { score += Self.cosine(qv, cv) }
            return (c, score)
        }
        return scored.sorted { $0.1 > $1.1 }
            .prefix(k)
            .filter { $0.1 > 0 }
            .map { KnowledgeHit(docName: $0.0.docName, text: $0.0.text, score: $0.1) }
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
            if end < chars.count {  // back up to a whitespace boundary
                var b = end
                while b > start && !chars[b - 1].isWhitespace { b -= 1 }
                if b > start + size / 2 { end = b }
            }
            out.append(String(chars[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines))
            if end >= chars.count { break }
            start = max(end - overlap, start + 1)
        }
        return out.filter { !$0.isEmpty }
    }

    static func embed(_ text: String) -> [Double]? {
        guard let e = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        return e.vector(for: text)
    }

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in a.indices { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom == 0 ? 0 : dot / denom
    }

    /// Fraction of distinct query terms (≥3 chars) that appear in `text`.
    static func keywordScore(query: String, text: String) -> Double {
        let terms = Set(query.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 3 })
        guard !terms.isEmpty else { return 0 }
        let lower = text.lowercased()
        let hits = terms.filter { lower.contains($0) }.count
        return Double(hits) / Double(terms.count)
    }

    // MARK: Persistence

    private struct Snapshot: Codable { var docs: [KnowledgeDoc]; var chunks: [KnowledgeChunk] }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
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
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        docs = snap.docs
        chunks = snap.chunks
    }
}
