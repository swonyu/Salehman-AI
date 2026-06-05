import Foundation
import Combine

/// A captured note (free text).
struct Note: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var text: String
    var createdAt = Date()
}

/// A to-do item.
struct TaskItem: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var done = false
    var createdAt = Date()
}

/// The Scratchpad: the owner's local notes + tasks, shared by the Notes tab UI
/// AND the Foundation Models tools (so "add buy milk to my tasks" in chat just
/// works). `@MainActor ObservableObject` so the tab updates live; the tools call
/// its methods with `await` (they hop to the main actor). Persisted as one JSON
/// file in Application Support — same lifecycle as `MemoryStore`/`PromptLibrary`,
/// fully on-device.
@MainActor
final class ScratchpadStore: ObservableObject {
    static let shared = ScratchpadStore()

    @Published private(set) var notes: [Note] = []
    @Published private(set) var tasks: [TaskItem] = []

    private init() { load() }

    // MARK: Mutations (UI + tools)

    func addNote(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        notes.insert(Note(text: t), at: 0)
        save()
    }

    func addTask(_ title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        tasks.insert(TaskItem(title: t), at: 0)
        save()
    }

    func toggleTask(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].done.toggle()
        save()
    }

    /// Mark the first OPEN task whose title contains `query` as done. Returns
    /// whether one matched — the `complete_task` tool reports this back.
    func completeTask(matching query: String) -> Bool {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty,
              let i = tasks.firstIndex(where: { !$0.done && $0.title.lowercased().contains(q) }) else { return false }
        tasks[i].done = true
        save()
        return true
    }

    func deleteNote(_ id: UUID) { notes.removeAll { $0.id == id }; save() }
    func deleteTask(_ id: UUID) { tasks.removeAll { $0.id == id }; save() }
    func clear() { notes.removeAll(); tasks.removeAll(); save() }

    /// Plain-text dump of notes + open tasks — what `list_scratchpad` hands the
    /// model to summarize / organize.
    func summaryText() -> String {
        let open = tasks.filter { !$0.done }
        var out = "Open tasks (\(open.count)):\n"
        out += open.isEmpty ? "  (none)\n" : open.map { "  • \($0.title)" }.joined(separator: "\n") + "\n"
        out += "\nNotes (\(notes.count)):\n"
        out += notes.isEmpty ? "  (none)" : notes.map { "  • \($0.text)" }.joined(separator: "\n")
        return out
    }

    // MARK: Persistence

    private struct Snapshot: Codable { var notes: [Note]; var tasks: [TaskItem] }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SalehmanAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("scratchpad.json")
    }

    private func save() {
        let snap = Snapshot(notes: notes, tasks: tasks)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        notes = snap.notes
        tasks = snap.tasks
    }
}
