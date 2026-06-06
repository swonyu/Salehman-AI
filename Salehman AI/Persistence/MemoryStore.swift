import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

struct MemoryItem: Codable {
    let text: String
    let vector: [Float]?   // Float, not Double — halves the in-memory vector RAM
}

/// Long-term memory: stores durable facts about the user and recalls the most
/// relevant ones using on-device sentence embeddings (free, private).
final class MemoryStore: @unchecked Sendable {
    static let shared = MemoryStore()
    private let lock = NSLock()
    private var items: [MemoryItem] = []

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SalehmanAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("memory.json")
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([MemoryItem].self, from: data) {
            items = saved
        }
    }

    private func embed(_ text: String) -> [Float]? {
        guard let e = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        return e.vector(for: text)?.map { Float($0) }   // Float halves the stored-vector RAM
    }

    func remember(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let item = MemoryItem(text: t, vector: embed(t))
        lock.lock()
        if !items.contains(where: { $0.text.caseInsensitiveCompare(t) == .orderedSame }) {
            items.append(item)
            if let data = try? JSONEncoder().encode(items) { try? data.write(to: fileURL, options: .atomic) }
        }
        lock.unlock()
    }

    /// All stored facts, newest last (for the memory viewer).
    func allFacts() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return items.map { $0.text }
    }

    /// Remove a single fact by its text.
    func delete(_ text: String) {
        lock.lock()
        items.removeAll { $0.text == text }
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: fileURL, options: .atomic) }
        lock.unlock()
    }

    /// Forget everything.
    func clear() {
        lock.lock()
        items.removeAll()
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: fileURL, options: .atomic) }
        lock.unlock()
    }

    func recall(_ query: String, k: Int = 4) -> [String] {
        lock.lock(); let snapshot = items; lock.unlock()
        guard !snapshot.isEmpty else { return [] }

        if let qv = embed(query) {
            let scored = snapshot.compactMap { item -> (String, Double)? in
                guard let v = item.vector else { return nil }
                return (item.text, cosine(qv, v))
            }.sorted { $0.1 > $1.1 }
            let top = scored.prefix(k).filter { $0.1 > 0.25 }.map { $0.0 }
            if !top.isEmpty { return top }
        }
        // Keyword fallback.
        let words = Set(query.lowercased().split(separator: " ").map(String.init))
        return snapshot.filter { item in
            let iw = Set(item.text.lowercased().split(separator: " ").map(String.init))
            return !words.isDisjoint(with: iw)
        }.prefix(k).map { $0.text }
    }

    private func cosine(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count { let x = Double(a[i]), y = Double(b[i]); dot += x*y; na += x*x; nb += y*y }
        return (na == 0 || nb == 0) ? 0 : dot / (na.squareRoot() * nb.squareRoot())
    }
}

#if canImport(FoundationModels)
struct RememberFactTool: Tool {
    let name = "remember_fact"
    let description = "Save a durable fact about the user (preferences, name, projects, etc.) to long-term memory so you recall it in future conversations."

    @Generable
    struct Arguments {
        @Guide(description: "The fact to remember, written as a clear standalone statement.")
        var fact: String
    }

    func call(arguments: Arguments) async throws -> String {
        MemoryStore.shared.remember(arguments.fact)
        return "Saved to long-term memory: \(arguments.fact)"
    }
}
#endif
