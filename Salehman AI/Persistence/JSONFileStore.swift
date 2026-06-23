import Foundation

/// Generic, injectable JSON file store — one place for the "encode → atomic write
/// / decode-or-default" boilerplate the per-feature stores used to repeat:
/// - atomic writes
/// - injectable base directory (defaults to Application Support/SalehmanAI;
///   tests redirect persistence via this seam — see PersistenceRoundTripTests)
/// - decode-or-default on a missing/corrupt file
///
/// `nonisolated` so off-main, lock-guarded callers (e.g. `MemoryStore`) can use it
/// directly — it holds only value state (a URL + FileManager) and does pure file I/O.
nonisolated final class JSONFileStore<T: Codable> {
    private let fileURL: URL
    private let fileManager = FileManager.default

    init(filename: String, baseDirectory: URL? = nil) {
        let base = baseDirectory
            ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory)
                .appendingPathComponent("SalehmanAI", isDirectory: true)
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent(filename)
    }

    /// Decoded contents, or `defaultValue` if the file is missing. A file that EXISTS but cannot be
    /// decoded (a truncated/partial write, or a schema change) is RENAMED ASIDE to
    /// `<name>.corrupt-<uuid>` before returning the default — so the next `save()` cannot silently
    /// overwrite recoverable data with an empty snapshot (mirrors KnowledgeStore's recovery). Without
    /// this, one bad/partial write wiped long-term memory, all notes/tasks, and the Code chat history.
    func load(defaultValue: T) -> T {
        guard let data = try? Data(contentsOf: fileURL) else { return defaultValue }   // missing → default
        if let decoded = try? JSONDecoder().decode(T.self, from: data) { return decoded }
        // Present but undecodable → preserve it aside so save() starts fresh instead of clobbering it.
        let aside = fileURL.appendingPathExtension("corrupt-\(UUID().uuidString)")
        try? fileManager.moveItem(at: fileURL, to: aside)
        return defaultValue
    }

    /// Atomically write `value` as JSON.
    nonisolated func save(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: fileURL, options: .atomic)
    }
}
