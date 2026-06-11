import SwiftUI

/// The Notes/Tasks tab — a manual UI over `ScratchpadStore` (which the chat tools
/// also drive). Notes + tasks, inline add, check/delete, and a one-tap AI
/// "Organize"/"Summarize" over the current contents via `LocalLLM.generate`.
struct ScratchpadView: View {
    @ObservedObject private var store = ScratchpadStore.shared
    @State private var pad: Pad = .tasks
    @State private var newText = ""
    @State private var search = ""
    @State private var aiResult = ""
    @State private var working = false
    @FocusState private var addFocused: Bool

    private enum Pad: String, CaseIterable, Identifiable {
        case tasks, notes
        var id: String { rawValue }
        var title: String { self == .tasks ? "Tasks" : "Notes" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header
                Picker("Scratchpad section", selection: $pad) {
                    ForEach(Pad.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 320)
                addRow
                if store.tasks.count + store.notes.count > 5 { searchRow }
                if pad == .tasks { tasksList } else { notesList }
                if !aiResult.isEmpty { aiResultCard }
            }
            .padding(DS.Space.xl)
            // Centered content column, same as the chat surfaces.
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // Flat opaque working canvas (design language).
        .background(DS.Palette.codeSurface.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Notes").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                Text("Your scratchpad — Salehman can add & complete these from chat too.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await runAI() } } label: {
                HStack(spacing: 6) {
                    if working { ProgressView().controlSize(.small) } else { Image(systemName: "sparkles") }
                    Text(pad == .tasks ? "Organize" : "Summarize")
                }
            }
            .buttonStyle(.borderedProminent).tint(DS.Palette.accent).controlSize(.small)
            .disabled(working || (store.notes.isEmpty && store.tasks.isEmpty))
        }
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField(pad == .tasks ? "Add a task…" : "Add a note…", text: $newText)
                .textFieldStyle(.plain).font(.system(size: 14))
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                .focused($addFocused)
                .onSubmit(add)
                .accessibilityLabel(pad == .tasks ? "New task" : "New note")
            Button(action: add) {
                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(DS.Palette.accent)
            }
            .buttonStyle(.plain).help("Add")
            .accessibilityLabel(pad == .tasks ? "Add task" : "Add note")
            .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func add() {
        if pad == .tasks { store.addTask(newText) } else { store.addNote(newText) }
        newText = ""
        addFocused = true
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("Search \(pad == .tasks ? "tasks" : "notes")…", text: $search)
                .textFieldStyle(.plain).font(.system(size: 13))
                .accessibilityLabel("Search scratchpad")
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private var noMatch: some View {
        Text("No \(pad == .tasks ? "tasks" : "notes") match “\(search)”.")
            .font(.callout).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
    }

    private var tasksList: some View {
        let items = ScratchpadList.tasks(store.tasks, filter: search)
        let done = ScratchpadList.completedCount(store.tasks)
        return Group {
            if store.tasks.isEmpty {
                emptyState("No tasks yet", "checklist")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if done > 0 {
                        HStack {
                            Spacer()
                            Button("Clear \(done) completed") { clearCompleted() }
                                .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
                                .accessibilityLabel("Clear \(done) completed task\(done == 1 ? "" : "s")")
                        }
                    }
                    if items.isEmpty { noMatch } else { listCard { ForEach(items) { taskRow($0) } } }
                }
            }
        }
    }

    private func clearCompleted() {
        for t in store.tasks where t.done { store.deleteTask(t.id) }
    }

    private func taskRow(_ t: TaskItem) -> some View {
        HStack(spacing: 12) {
            Button { store.toggleTask(t.id) } label: {
                Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16)).foregroundStyle(t.done ? DS.Palette.successSoft : .secondary)
            }
            .buttonStyle(.plain).accessibilityLabel(t.done ? "Mark not done" : "Mark done")
            Text(t.title).font(.system(size: 14)).foregroundStyle(t.done ? Color.secondary : Color.white).strikethrough(t.done)
            Spacer(minLength: 8)
            deleteButton { store.deleteTask(t.id) }
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 10)
    }

    private var notesList: some View {
        let items = ScratchpadList.notes(store.notes, filter: search)
        return Group {
            if store.notes.isEmpty {
                emptyState("No notes yet", "note.text")
            } else if items.isEmpty {
                noMatch
            } else {
                listCard { ForEach(items) { noteRow($0) } }
            }
        }
    }

    private func noteRow(_ n: Note) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text").font(.system(size: 13)).foregroundStyle(DS.Palette.accent).frame(width: 18)
            Text(n.text).font(.system(size: 14)).foregroundStyle(.white).textSelection(.enabled)
            Spacer(minLength: 8)
            deleteButton { store.deleteNote(n.id) }
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 10)
    }

    private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain).help("Delete").accessibilityLabel("Delete")
    }

    private func listCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        // Flat opaque panel + hairline (design language).
        VStack(spacing: 1) { content() }
            .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func emptyState(_ text: String, _ icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34)).foregroundStyle(DS.Palette.accent.opacity(0.8))
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
    }

    private var aiResultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Salehman", systemImage: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(DS.Palette.accent)
                Spacer()
                Button { aiResult = "" } label: { Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("Dismiss")
            }
            Text(aiResult).font(.callout).foregroundStyle(DS.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.accent.opacity(0.3), lineWidth: 1))
    }

    private func runAI() async {
        working = true
        let text = store.summaryText()
        let prompt = pad == .tasks
            ? "Here are my notes and tasks:\n\n\(text)\n\nOrganize my OPEN tasks into a short, prioritized plan (group related ones, flag anything urgent). Be concise."
            : "Here are my notes and tasks:\n\n\(text)\n\nSummarize my NOTES into a tight overview with any action items called out. Be concise."
        // On-device only: the scratchpad can hold private content, so Organize/
        // Summarize never leaves the Mac (mirrors the Knowledge vault) — returns a
        // clear message instead of silently routing to a pinned cloud brain.
        aiResult = await LocalLLM.generateOnDevice(prompt, maxTokens: 400)
            ?? "No on-device model is available right now, so I can't do this privately. Start Ollama (a local model) to organize and summarize on this Mac."
        working = false
    }
}

/// Pure list shaping for the Notes tab (Chat C feature): active tasks first with
/// completed sunk, an optional case-insensitive text filter, and the
/// completed-count for the "Clear completed" affordance. Pure → unit-tested.
enum ScratchpadList {
    static func tasks(_ all: [TaskItem], filter q: String = "") -> [TaskItem] {
        let t = q.trimmingCharacters(in: .whitespaces).lowercased()
        let matched = t.isEmpty ? all : all.filter { $0.title.lowercased().contains(t) }
        return matched.filter { !$0.done } + matched.filter { $0.done }   // active first, stable
    }
    static func notes(_ all: [Note], filter q: String = "") -> [Note] {
        let t = q.trimmingCharacters(in: .whitespaces).lowercased()
        return t.isEmpty ? all : all.filter { $0.text.lowercased().contains(t) }
    }
    static func completedCount(_ all: [TaskItem]) -> Int { all.filter(\.done).count }
}
