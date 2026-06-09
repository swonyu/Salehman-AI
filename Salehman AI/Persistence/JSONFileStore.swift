
import Foundation

/// Generic, injectable JSON file store.

/// - Thread-safe atomic writes

/// - Injectable base directory (defaults to Application Support/SalehmanAI)

/// - Decode-or-default on missing/corrupt files

final class JSONFileStore<T: Codable> {

    private let fileURL: URL

    private let fileManager = FileManager.default

    init(filename: String, baseDirectory: URL? = nil) {

        let base = baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

            .appendingPathComponent("SalehmanAI", isDirectory: true)

        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)

        self.fileURL = base.appendingPathComponent(filename)

    }

    func load(defaultValue: T) -> T {

        guard let data = try? Data(contentsOf: fileURL) else { return defaultValue }

        return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue

    }

    func delete() throws {

        if fileManager.fileExists(atPath: fileURL.path) {

            try fileManager.removeItem(at: fileURL)

        }

    }

    func save(_ value: T) throws {

        let data = try JSONEncoder().encode(value)

        try data.write(to: fileURL, options: .atomic)

    }

}