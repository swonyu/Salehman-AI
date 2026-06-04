import SwiftUI
import Combine

struct SavedPrompt: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var text: String
}

/// A small library of reusable prompts the user can insert into the composer.
/// Persisted as JSON in Application Support, mirroring ChatStore/MemoryStore.
@MainActor
final class PromptLibrary: ObservableObject {
    static let shared = PromptLibrary()

    @Published private(set) var prompts: [SavedPrompt] = []

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SalehmanAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("prompts.json")
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([SavedPrompt].self, from: data) {
            prompts = saved
        } else {
            prompts = PromptLibrary.starters   // seed first-run with useful defaults
            save()
        }
    }

    func add(title: String, text: String) {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        prompts.append(SavedPrompt(title: name.isEmpty ? String(body.prefix(40)) : name, text: body))
        save()
    }

    func delete(_ prompt: SavedPrompt) {
        prompts.removeAll { $0.id == prompt.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(prompts) { try? data.write(to: fileURL, options: .atomic) }
    }

    static let starters: [SavedPrompt] = [
        SavedPrompt(title: "Summarize",       text: "Summarize the following clearly, with key points and any action items:\n\n"),
        SavedPrompt(title: "Explain simply",  text: "Explain this in simple terms a beginner can understand:\n\n"),
        SavedPrompt(title: "Improve writing", text: "Improve the clarity, grammar, and tone of this text while keeping my meaning:\n\n"),
        SavedPrompt(title: "Brainstorm",      text: "Brainstorm 10 creative ideas for: ")
    ]
}
