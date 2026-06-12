import AppKit
import SwiftUI

/// The Notes/Tasks tab — a manual UI over `ScratchpadStore` (which the chat tools
/// also drive). Notes + tasks, inline add, check/delete, and a one-tap AI
/// "Organize"/"Summarize" over the current contents via `LocalLLM.generate`.
struct ScratchpadView: View {
    @ObservedObject private var store = ScratchpadStore.shared
    @ObservedObject private var app = AppState.shared
    @AppStorage("ui.scratchpadPad") private var pad: Pad = .tasks
    @State private var newText = ""
    @State private var search = ""
    @State private var aiResult = ""
    @State private var working = false
    @FocusState private var addFocused: Bool
    /// Inline edit: which note/task is being renamed and its live draft text.
    /// Double-clicking a title enters edit mode; ↩ or blur commits, Esc cancels.
    @State private var editingId: UUID? = nil
    @State private var editingText = ""
    @State private var hoveredTaskID: UUID?
    @State private var hoveredNoteID: UUID?
    @State private var copyAllPulse = false
    /// Whether the "X Completed" disclosure group is expanded. Default collapsed
    /// so done tasks don't clutter the active-work view.
    @State private var showCompleted = false
    @State private var appeared = false

    private enum Pad: String, CaseIterable, Identifiable {
        case tasks, notes
        var id: String { rawValue }
        var title: String { self == .tasks ? "Tasks" : "Notes" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(DS.Motion.lux, value: appeared)
                Picker("Scratchpad section", selection: $pad) {
                    ForEach(Pad.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 320)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(DS.Motion.lux.delay(0.06), value: appeared)
                addRow
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(DS.Motion.lux.delay(0.10), value: appeared)
                Group {
                    if store.tasks.count + store.notes.count > 5 { searchRow }
                    if pad == .tasks { tasksList } else { notesList }
                    if !aiResult.isEmpty {
                        aiResultCard
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
                .animation(DS.Motion.lux.delay(0.14), value: appeared)
                .animation(DS.Motion.smooth, value: aiResult.isEmpty)
            }
            .padding(DS.Space.xl)
            // Centered content column, same as the chat surfaces.
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // Flat opaque working canvas (design language).
        .background(DS.Palette.codeSurface.ignoresSafeArea())
        // Today "New Note" / "New Task" quick actions: focus the add field so
        // the user can start typing immediately after the tab switch.
        // scratchpadFocusNotesMode switches the picker to Notes before focusing.
        .onAppear {
            appeared = true
            if app.focusScratchpadAddFieldRequested {
                applyFocusTrigger()
            }
        }
        .onChange(of: app.focusScratchpadAddFieldRequested) { _, requested in
            if requested { applyFocusTrigger() }
        }
        // Clear stale add-field text when the user switches between Tasks and Notes.
        .onChange(of: pad) { _, _ in newText = "" }
    }

    private func applyFocusTrigger() {
        if app.scratchpadFocusNotesMode {
            pad = .notes
            app.scratchpadFocusNotesMode = false
        } else {
            pad = .tasks
        }
        addFocused = true
        app.focusScratchpadAddFieldRequested = false
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.md) {
            // Brand icon tile — matches TodayView / AgentsView / KnowledgeView headers.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Gradient.brand)
                    .frame(width: 36, height: 36)
                    .dsShadow(DS.Elevation.accentGlow(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.02)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.75)
                    )
                KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                    Image(systemName: pad == .tasks ? "checklist" : "note.text")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(DS.Motion.smooth, value: pad)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.60, duration: 0.07)
                        SpringKeyframe(1.18, spring: .snappy, duration: 0.28)
                        SpringKeyframe(1.0, spring: .bouncy, duration: 0.22)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Notes")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    Eyebrow(text: "Notes & Tasks")
                }
                Text("Salehman can add & complete these from chat too.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { copyAll() } label: {
                Image(systemName: copyAllPulse ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(copyAllPulse ? DS.Palette.successSoft : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(DS.Motion.smooth, value: copyAllPulse)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(pad == .tasks ? "Copy all tasks as Markdown" : "Copy all notes as Markdown")
            .disabled(pad == .tasks ? store.tasks.isEmpty : store.notes.isEmpty)
            .accessibilityLabel("Copy all \(pad == .tasks ? "tasks" : "notes")")

            Button { Task { await runAI() } } label: {
                HStack(spacing: 6) {
                    if working { ProgressView().controlSize(.small) }
                    else { Image(systemName: "sparkles") }
                    Text(pad == .tasks ? "Organize" : "Summarize")
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(DS.Gradient.brand, in: Capsule())
                .shadow(color: DS.Palette.accent.opacity(0.28), radius: 5, y: 2)
            }
            .buttonStyle(LuxPressStyle())
            .disabled(working || (store.notes.isEmpty && store.tasks.isEmpty))
        }
        .animation(DS.Motion.smooth, value: pad)
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
                .onKeyPress(.escape) { newText = ""; return .handled }
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
                .onKeyPress(.escape) { search = ""; return .handled }
                .accessibilityLabel("Search scratchpad")
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private var noMatch: some View {
        Text("No \(pad == .tasks ? "tasks" : "notes") match “\(search)”.")
            .font(.callout).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
    }

    private var tasksList: some View {
        let open = store.tasks.filter { !$0.done }
        let done = store.tasks.filter { $0.done }
        return Group {
            if store.tasks.isEmpty {
                emptyState("No tasks yet", "checklist")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if search.isEmpty {
                        if done.isEmpty {
                            // All tasks open — drag-to-reorder on the full array
                            // (indices are safe because no done tasks are mixed in).
                            reorderList {
                                ForEach(store.tasks) { taskRow($0) }
                                    .onMove { store.moveTask(from: $0, to: $1) }
                            }
                        } else {
                            // Mixed state — static list for open tasks to keep
                            // .onMove indices sane, then a collapsed disclosure
                            // for completed items so they don't clutter the view.
                            if !open.isEmpty {
                                listCard { ForEach(open) { taskRow($0) } }
                            } else {
                                Text("All tasks completed")
                                    .font(.callout).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                            }
                            completedDisclosure(done)
                        }
                    } else {
                        let filtered = ScratchpadList.tasks(store.tasks, filter: search)
                        if filtered.isEmpty { noMatch }
                        else { listCard { ForEach(filtered) { taskRow($0) } } }
                    }
                }
            }
        }
    }

    private func completedDisclosure(_ done: [TaskItem]) -> some View {
        DisclosureGroup(isExpanded: $showCompleted) {
            listCard { ForEach(done) { taskRow($0) } }
                .padding(.top, 4)
        } label: {
            HStack {
                Label("\(done.count) completed",
                      systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear all") { clearCompleted() }
                    .font(.system(size: 11)).buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear all \(done.count) completed task\(done.count == 1 ? "" : "s")")
            }
        }
        .animation(DS.Motion.smooth, value: done.count)
    }

    private func clearCompleted() {
        for t in store.tasks where t.done { store.deleteTask(t.id) }
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyAll() {
        let md = pad == .tasks
            ? ScratchpadList.markdownList(tasks: store.tasks)
            : ScratchpadList.markdownList(notes: store.notes)
        guard !md.isEmpty else { return }
        copyText(md)
        copyAllPulse = true
        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copyAllPulse = false }
    }

    private func taskRow(_ t: TaskItem) -> some View {
        let hovered = hoveredTaskID == t.id
        return HStack(spacing: 12) {
            Button { store.toggleTask(t.id) } label: {
                Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(t.done ? DS.Palette.successSoft : (hovered ? .white.opacity(0.5) : .secondary))
                    .contentTransition(.symbolEffect(.replace))
                    .animation(DS.Motion.smooth, value: t.done)
            }
            .buttonStyle(.plain).accessibilityLabel(t.done ? "Mark not done" : "Mark done")
            if editingId == t.id {
                TextField("", text: $editingText)
                    .textFieldStyle(.plain).font(.system(size: 14))
                    .onSubmit { commitEdit(isNote: false, id: t.id) }
                    .onKeyPress(.escape) { cancelEdit(); return .handled }
            } else {
                Text(t.title)
                    .font(.system(size: 14))
                    .foregroundStyle(t.done ? Color.secondary : (hovered ? .white : .white.opacity(0.9)))
                    .strikethrough(t.done)
            }
            Spacer(minLength: 8)
            if hovered && editingId != t.id {
                Text(ScratchpadList.ageLabel(for: t.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .transition(.opacity)
            }
            if editingId != t.id {
                editButton { startEdit(id: t.id, text: t.title) }
            }
            deleteButton { store.deleteTask(t.id) }
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 10)
        .background(hovered ? DS.Palette.accent.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.magnetic) {
                if over { hoveredTaskID = t.id }
                else if hoveredTaskID == t.id { hoveredTaskID = nil }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparatorTint(DS.Palette.surfaceStroke)
        .contextMenu {
            Button { copyText(t.title) } label: { Label("Copy", systemImage: "doc.on.doc") }
            Button { store.toggleTask(t.id) } label: {
                Label(t.done ? "Mark Not Done" : "Mark Done",
                      systemImage: t.done ? "circle" : "checkmark.circle")
            }
            if editingId != t.id {
                Button { startEdit(id: t.id, text: t.title) } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            Divider()
            Button(role: .destructive) { store.deleteTask(t.id) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var notesList: some View {
        Group {
            if store.notes.isEmpty {
                emptyState("No notes yet", "note.text")
            } else if search.isEmpty {
                // No filter: stored order + drag-to-reorder.
                reorderList {
                    ForEach(store.notes) { noteRow($0) }
                        .onMove { store.moveNote(from: $0, to: $1) }
                }
            } else {
                let filtered = ScratchpadList.notes(store.notes, filter: search)
                if filtered.isEmpty { noMatch }
                else { listCard { ForEach(filtered) { noteRow($0) } } }
            }
        }
    }

    private func noteRow(_ n: Note) -> some View {
        let hovered = hoveredNoteID == n.id
        return HStack(spacing: 12) {
            // Icon well — matches MemoryView fact rows.
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DS.Palette.accent.opacity(hovered ? 0.20 : 0.11))
                    .frame(width: 24, height: 24)
                Image(systemName: "note.text")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
            if editingId == n.id {
                TextField("", text: $editingText)
                    .textFieldStyle(.plain).font(.system(size: 14))
                    .onSubmit { commitEdit(isNote: true, id: n.id) }
                    .onKeyPress(.escape) { cancelEdit(); return .handled }
            } else {
                Text(n.text)
                    .font(.system(size: 14))
                    .foregroundStyle(hovered ? .white : .white.opacity(0.9))
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            if hovered && editingId != n.id {
                Text(ScratchpadList.ageLabel(for: n.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .transition(.opacity)
            }
            if editingId != n.id {
                editButton { startEdit(id: n.id, text: n.text) }
            }
            deleteButton { store.deleteNote(n.id) }
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 10)
        .background(hovered ? DS.Palette.accent.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.magnetic) {
                if over { hoveredNoteID = n.id }
                else if hoveredNoteID == n.id { hoveredNoteID = nil }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparatorTint(DS.Palette.surfaceStroke)
        .contextMenu {
            Button { copyText(n.text) } label: { Label("Copy", systemImage: "doc.on.doc") }
            if editingId != n.id {
                Button { startEdit(id: n.id, text: n.text) } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            Divider()
            Button(role: .destructive) { store.deleteNote(n.id) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func startEdit(id: UUID, text: String) {
        editingId = id; editingText = text
    }

    private func commitEdit(isNote: Bool, id: UUID) {
        if isNote { store.updateNote(id, text: editingText) }
        else { store.updateTask(id, title: editingText) }
        cancelEdit()
    }

    private func cancelEdit() { editingId = nil; editingText = "" }

    private func editButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "pencil").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain).help("Edit").accessibilityLabel("Edit")
    }

    private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain).help("Delete").accessibilityLabel("Delete")
    }

    private func listCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 1) { content() }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    /// Like `listCard` but uses a `List` so rows are reorderable by drag.
    /// `.scrollDisabled` lets the outer `ScrollView` drive paging; the `List`
    /// is purely a container here. `.scrollContentBackground(.hidden)` + per-row
    /// background keeps the design-language flat dark surface.
    private func reorderList<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        List { content() }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .listRowSeparatorTint(DS.Palette.surfaceStroke)
            // Force the List to report its ideal (content-fit) height so the
            // outer ScrollView sizes it correctly — without this the List either
            // collapses to 0 or fills the container on macOS.
            .fixedSize(horizontal: false, vertical: true)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
            .environment(\.defaultMinListRowHeight, 1)
    }

    private func emptyState(_ text: String, _ icon: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                PhaseAnimator([0.14, 0.22, 0.14]) { opacity in
                    Circle()
                        .fill(DS.Palette.accent.opacity(opacity))
                        .frame(width: 100)
                        .blur(radius: 28)
                        .allowsHitTesting(false)
                } animation: { opacity in
                    opacity > 0.18
                        ? .spring(duration: 2.2, bounce: 0.06)
                        : .easeOut(duration: 1.8)
                }
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(DS.Palette.accent)
                    .frame(width: 54, height: 54)
                    .background(RadialGradient(colors: [DS.Palette.accent.opacity(0.18), DS.Palette.accent.opacity(0.05)], center: .center, startRadius: 0, endRadius: 27), in: Circle())
                    .overlay(Circle().stroke(LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .shadow(color: DS.Palette.accent.opacity(0.26), radius: 14, y: 3)
            }
            .padding(.bottom, 2)
            Text(pad == .tasks ? "YOUR TASKS" : "YOUR NOTES")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(DS.Palette.accent)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
            Text(pad == .tasks ? "Type above and hit ↩ to add one." : "Type above and hit ↩ to add one.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private var aiResultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Salehman", systemImage: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(DS.Palette.accent)
                Spacer()
                Button {
                    store.addNote(aiResult)
                    aiResult = ""
                } label: {
                    Label("Save as Note", systemImage: "note.text.badge.plus")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(LuxPressStyle()).help("Save this summary as a note")
                .accessibilityLabel("Save AI summary as note")

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

    /// GFM task-list Markdown for the full task list — open: `- [ ] …`, done: `- [x] …`.
    /// Pure for tests; returns "" when the list is empty.
    static func markdownList(tasks: [TaskItem]) -> String {
        guard !tasks.isEmpty else { return "" }
        return tasks.map { "- [\($0.done ? "x" : " ")] \($0.title)" }.joined(separator: "\n")
    }

    /// Plain-list Markdown for notes — each note becomes `- Note text`. Pure.
    static func markdownList(notes: [Note]) -> String {
        guard !notes.isEmpty else { return "" }
        return notes.map { "- \($0.text)" }.joined(separator: "\n")
    }

    /// Human-readable relative age for a creation date. `now` is injectable for
    /// tests; defaults to `Date()` at call time. Examples: "just now", "5m", "2h",
    /// "yesterday", "Jun 5".
    static func ageLabel(for date: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if Calendar.current.isDateInYesterday(date) { return "yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
