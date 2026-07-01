import Foundation
import NaturalLanguage

struct MemoryItem: Codable {
    let text: String
    let vector: [Float]?   // Float, not Double — halves the in-memory vector RAM
}

/// Long-term memory: stores durable facts about the user and recalls the most
/// relevant ones using on-device sentence embeddings (free, private).
final class MemoryStore: @unchecked Sendable {
    static let shared = MemoryStore()
    private let lock = NSLock()
    private nonisolated(unsafe) var items: [MemoryItem] = []
    private nonisolated(unsafe) let store: JSONFileStore<[MemoryItem]>

    private init() {
        self.store = JSONFileStore<[MemoryItem]>(filename: "memory.json")
        self.items = store.load(defaultValue: [])
    }

    /// Testing seam — backs the store with `baseDirectory` instead of Application Support
    /// so tests stay hermetic and never touch the real data directory.
    init(baseDirectory: URL) {
        self.store = JSONFileStore<[MemoryItem]>(filename: "memory.json", baseDirectory: baseDirectory)
        self.items = store.load(defaultValue: [])
    }

    /// Persist `items`. Callers already hold `lock`.
    private nonisolated func persist() {
        do { try store.save(items) }
        catch { NSLog("MemoryStore.persist failed: %@", error.localizedDescription) }
    }

    private nonisolated func embed(_ text: String) -> [Float]? {
        guard let e = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        return e.vector(for: text)?.map { Float($0) }   // Float halves the stored-vector RAM
    }

    nonisolated func remember(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let item = MemoryItem(text: t, vector: embed(t))
        lock.lock()
        if !items.contains(where: { $0.text.caseInsensitiveCompare(t) == .orderedSame }) {
            items.append(item)
            persist()
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
        persist()
        lock.unlock()
    }

    /// Forget everything.
    func clear() {
        lock.lock()
        items.removeAll()
        persist()
        lock.unlock()
    }

    nonisolated func recall(_ query: String, k: Int = 4) -> [String] {
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

    private nonisolated func cosine(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count { let x = Double(a[i]), y = Double(b[i]); dot += x*y; na += x*x; nb += y*y }
        return (na == 0 || nb == 0) ? 0 : dot / (na.squareRoot() * nb.squareRoot())
    }

    // MARK: - Auto-extraction

    /// Extract and store durable facts from a single conversation turn.
    /// Runs purely from heuristic patterns — no model call, zero latency.
    /// Called as a fire-and-forget background task after each assistant reply.
    nonisolated func autoExtract(userMessage: String, reply: String) {
        let facts = Self.extractFacts(from: userMessage)
        for fact in facts { remember(fact) }
    }

    /// Pattern-based fact extractor. Returns zero-or-more short declarative
    /// strings describing the user. Conservative: only fires on clear first-
    /// person "I <verb> …" or possessive "my <noun> is …" shapes so we don't
    /// flood memory with noise.
    nonisolated static func extractFacts(from text: String) -> [String] {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > 4 else { return [] }

        // Sentence patterns → memory fact templates.
        // Each pair: (NSRegularExpression pattern, fact prefix).
        // Capture group 1 is the value to store.
        let patterns: [(String, String)] = [
            // Name
            (#"(?i)\bmy name is ([A-Za-z][A-Za-z '-]{1,40})"#,                  "User's name is"),
            (#"(?i)\bcall me ([A-Za-z][A-Za-z '-]{1,30})\b"#,                    "User goes by"),
            // Role / identity
            (#"(?i)\bi(?:'m| am) (?:a |an )?([a-z][a-z /&-]{2,50}(?:developer|engineer|designer|student|founder|researcher|doctor|manager|analyst|architect|scientist|teacher|writer|freelancer))"#, "User is a"),
            (#"(?i)\bi work (?:at|for) ([A-Za-z][A-Za-z0-9 .,-]{1,50})"#,       "User works at"),
            // Language / location
            (#"(?i)\bi(?:'m| am) from ([A-Za-z][A-Za-z '-]{2,40})"#,             "User is from"),
            (#"(?i)\bi(?:'m| am) (?:based |living )?in ([A-Za-z][A-Za-z '-]{2,40})"#, "User is in"),
            // Preferences
            (#"(?i)\bi (?:prefer|like|love|enjoy) ([a-z][a-z0-9 /+-]{2,60})"#,  "User prefers"),
            (#"(?i)\bi (?:don't|do not|hate|dislike) (?:like )?([a-z][a-z0-9 /+-]{2,60})"#, "User dislikes"),
            // Tech / tools
            (#"(?i)\bi(?:'m| am) using ([A-Za-z][A-Za-z0-9 /.-]{1,50})"#,        "User uses"),
            (#"(?i)\bwe(?:'re| are) using ([A-Za-z][A-Za-z0-9 /.-]{1,50})"#,     "User's team uses"),
            // Project
            (#"(?i)\bi(?:'m| am) (?:building|working on|making) ([a-z][a-z0-9 /,.-]{2,80})"#, "User is building"),
        ]

        var found: [String] = []
        for (pattern, prefix) in patterns {
            guard let rx = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(t.startIndex..., in: t)
            let matches = rx.matches(in: t, range: range)
            for m in matches {
                guard m.numberOfRanges > 1,
                      let vr = Range(m.range(at: 1), in: t) else { continue }
                let value = String(t[vr])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".!,"))
                guard value.count >= 2, value.count < 120 else { continue }
                // Skip very generic values that add no signal.
                let lower = value.lowercased()
                let noise: Set<String> = ["a", "an", "the", "this", "that", "it", "things", "stuff"]
                guard !noise.contains(lower) else { continue }
                found.append("\(prefix) \(value).")
            }
        }
        return found
    }
}

