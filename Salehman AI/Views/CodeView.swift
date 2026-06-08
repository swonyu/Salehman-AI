import SwiftUI
import AppKit
import Combine

// MARK: - Diff model

struct DiffLine: Identifiable {
    enum Kind { case same, add, remove }
    let id = UUID()
    let kind: Kind
    let text: String
}

// MARK: - Workspace (project folder + files + diffs)

/// Backing state for the Code tab: the chosen project root, its file list, the
/// selected file's content, and a line-diff of what the agent changed in the last
/// run. Snapshots every file's content BEFORE a run so the diff after the run is
/// real (red/green), the way Claude Code shows edits.
@MainActor
final class CodeWorkspace: ObservableObject {
    @Published var projectRoot: URL?
    @Published var files: [URL] = []
    @Published var selectedFile: URL?
    @Published var fileContent: String = ""
    @Published var diff: [DiffLine] = []
    @Published var changedFiles: [URL] = []

    private var snapshots: [URL: String] = [:]

    /// UserDefaults key for the last-opened project folder, so the Code tab
    /// reopens it on launch instead of making you re-pick every time. (The app
    /// isn't sandboxed, so a plain path round-trips without a security bookmark.)
    private static let rootKey = "code_projectRoot"

    init() {
        guard let path = UserDefaults.standard.string(forKey: Self.rootKey) else { return }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        projectRoot = url
        Shell.workingDirectory = url
        reload()
    }

    /// Directories that would flood the tree / diff snapshots — skipped wholesale.
    private static let skipDirs: Set<String> = ["node_modules", ".build", "DerivedData", ".git", "Pods", ".next", "dist", "build"]
    private static let codeExts: Set<String> = [
        "swift","js","ts","tsx","jsx","py","json","md","txt","html","css","scss",
        "sh","zsh","c","cpp","cc","h","hpp","m","mm","go","rs","rb","java","kt",
        "yml","yaml","toml","xml","sql","php","lua","vue","svelte","gradle",
    ]

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Project"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        projectRoot = url
        Shell.workingDirectory = url          // terminal + edits now run in the project
        UserDefaults.standard.set(url.path, forKey: Self.rootKey)   // remembered across launches
        selectedFile = nil; fileContent = ""; diff = []; changedFiles = []
        reload()
    }

    func reload() {
        guard let root = projectRoot else { files = []; return }
        var out: [URL] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        if let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                   options: [.skipsHiddenFiles]) {
            for case let u as URL in en {
                if out.count >= 3000 { break }
                if (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    if Self.skipDirs.contains(u.lastPathComponent) { en.skipDescendants() }
                    continue
                }
                if Self.codeExts.contains(u.pathExtension.lowercased()) { out.append(u) }
            }
        }
        files = out.sorted { $0.path < $1.path }
    }

    func select(_ url: URL) {
        selectedFile = url
        fileContent = (try? String(contentsOf: url, encoding: .utf8)) ?? "‹binary or unreadable file›"
        let before = snapshots[url]
        if let before, before != fileContent {
            diff = Self.lineDiff(old: before, new: fileContent)
        } else {
            diff = []
        }
    }

    /// Capture every file's content right before a run, so post-run diffs are real.
    func snapshotAll() {
        var snap: [URL: String] = [:]
        for u in files where (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0 < 400_000 {
            if let s = try? String(contentsOf: u, encoding: .utf8) { snap[u] = s }
        }
        snapshots = snap
    }

    /// After a run: rescan (the agent may have created files), then flag every
    /// file whose content changed vs. the pre-run snapshot.
    func refreshAfterRun() {
        reload()
        var changed: [URL] = []
        for u in files {
            let now = (try? String(contentsOf: u, encoding: .utf8)) ?? ""
            let before = snapshots[u] ?? ""
            if before != now { changed.append(u) }
        }
        changedFiles = changed
        if let first = changed.first { select(first) }
    }

    /// Minimal LCS line-diff. Caps each side so a huge file can't stall the UI.
    static func lineDiff(old: String, new: String) -> [DiffLine] {
        let cap = 1500
        let a = Array(old.components(separatedBy: "\n").prefix(cap))
        let b = Array(new.components(separatedBy: "\n").prefix(cap))
        let n = a.count, m = b.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        var i = 0, j = 0, out: [DiffLine] = []
        while i < n && j < m {
            if a[i] == b[j] { out.append(DiffLine(kind: .same, text: a[i])); i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { out.append(DiffLine(kind: .remove, text: a[i])); i += 1 }
            else { out.append(DiffLine(kind: .add, text: b[j])); j += 1 }
        }
        while i < n { out.append(DiffLine(kind: .remove, text: a[i])); i += 1 }
        while j < m { out.append(DiffLine(kind: .add, text: b[j])); j += 1 }
        return out
    }
}

// MARK: - Code tab

/// A Claude-Code-style coding workspace: a project file tree, a streaming coding
/// chat (with code blocks), live red/green diffs of what the agent changed, and
/// the multi-agent step view — all on top of the existing tool-capable pipeline,
/// so terminal commands + file edits run through the same approval card.
struct CodeView: View {
    @StateObject private var ws = CodeWorkspace()
    @ObservedObject private var progress = MissionProgress.shared

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isRunning = false
    @State private var rightPane: RightPane = .file
    @State private var runningTask: Task<Void, Never>?

    enum RightPane: String, CaseIterable { case file = "File", diff = "Diff" }

    var body: some View {
        HSplitView {
            fileTree
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 360)

            VSplitView {
                chatPane
                    .frame(minHeight: 220)
                inspectorPane
                    .frame(minHeight: 160)
            }
            .frame(minWidth: 420)
        }
        .background(Color.black.opacity(0.18))
    }

    // MARK: File tree (left)

    private var fileTree: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: ws.openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Palette.accent)
                Spacer()
                if ws.projectRoot != nil {
                    Button { ws.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .help("Rescan project files")
                }
            }
            .padding(10)

            if let root = ws.projectRoot {
                Text(root.lastPathComponent)
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .lineLimit(1).truncationMode(.middle)
                    .padding(.horizontal, 10).padding(.bottom, 6)
            }

            Divider().overlay(DS.Palette.hairline)

            if ws.files.isEmpty {
                emptyTreeHint
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(ws.files, id: \.self) { url in fileRow(url) }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .background(.ultraThinMaterial)
    }

    private var emptyTreeHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 26)).foregroundStyle(.secondary)
            Text("Open a project folder\nto start coding")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func fileRow(_ url: URL) -> some View {
        let isSel = ws.selectedFile == url
        let changed = ws.changedFiles.contains(url)
        return Button {
            ws.select(url)
            rightPane = changed ? .diff : .file
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10)).foregroundStyle(changed ? DS.Palette.accent : .secondary)
                Text(relativePath(url))
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(isSel ? .white : Color.white.opacity(0.72))
                    .lineLimit(1).truncationMode(.head)
                Spacer(minLength: 0)
                if changed {
                    Circle().fill(DS.Palette.accent).frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(isSel ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func relativePath(_ url: URL) -> String {
        guard let root = ws.projectRoot else { return url.lastPathComponent }
        return url.path.replacingOccurrences(of: root.path + "/", with: "")
    }

    // MARK: Chat pane (top-right)

    private var chatPane: some View {
        VStack(spacing: 0) {
            // Agent steps — feature: plan / agent steps view.
            if isRunning && !progress.steps.isEmpty {
                agentSteps
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty && !isRunning {
                            welcome
                        }
                        ForEach(messages) { msg in
                            codeBubble(msg)
                                .id(msg.id)
                        }
                        if isRunning {
                            streamingView.id("stream")
                        }
                    }
                    .padding(14)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
                .onChange(of: progress.streamingAnswer) { _, _ in
                    proxy.scrollTo("stream", anchor: .bottom)
                }
            }

            inputBar
        }
        .background(Color.black.opacity(0.12))
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Code with Salehman")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            Text("Open a project folder, then ask me to build, fix, or explain code. I can run terminal commands and edit files (you approve each one), and you'll see the diffs here.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }

    private var agentSteps: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(progress.steps) { step in
                    HStack(spacing: 5) {
                        stepIcon(step.status)
                        Text(step.adapted ?? step.name)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(step.status == .done ? .secondary : Color.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.white.opacity(0.05), in: Capsule())
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func stepIcon(_ status: MissionProgress.Status) -> some View {
        switch status {
        case .pending: Image(systemName: "circle").font(.system(size: 9)).foregroundStyle(.secondary)
        case .running: ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
        case .done:    Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(DS.Palette.accent)
        }
    }

    private func codeBubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: msg.isUser ? "person.crop.circle.fill" : "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(msg.isUser ? Color.white.opacity(0.6) : DS.Palette.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(msg.isUser ? "You" : "Salehman")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                MarkdownText(text: msg.text)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streamingView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(DS.Palette.accent).frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text("Salehman").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                if progress.streamingAnswer.isEmpty {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.6)
                        Text("Working…").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                } else {
                    MarkdownText(text: progress.streamingAnswer)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask Salehman to build, fix, or explain…", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...5)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .onSubmit(send)

            Button(action: isRunning ? stop : send) {
                Image(systemName: isRunning ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isRunning ? Color.red : (input.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : DS.Palette.accent))
            }
            .buttonStyle(.plain)
            .disabled(!isRunning && input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(10)
        .background(.ultraThinMaterial)
    }

    // MARK: Inspector pane (bottom-right): file viewer / diff

    private var inspectorPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Picker("", selection: $rightPane) {
                    ForEach(RightPane.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                if let sel = ws.selectedFile {
                    Text(relativePath(sel))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                }
                Spacer()
                if !ws.changedFiles.isEmpty {
                    Text("\(ws.changedFiles.count) changed")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent)
                }
            }
            .padding(10)
            Divider().overlay(DS.Palette.hairline)

            if ws.selectedFile == nil {
                Text("Select a file to view it, or run a task to see diffs.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rightPane == .diff {
                diffView
            } else {
                fileView
            }
        }
        .background(Color.black.opacity(0.20))
    }

    private var fileView: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(ws.fileContent.isEmpty ? "‹empty file›" : ws.fileContent)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.9))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    private var diffView: some View {
        Group {
            if ws.diff.isEmpty {
                Text("No changes for this file in the last run.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(ws.diff) { line in
                            HStack(spacing: 6) {
                                Text(symbol(line.kind)).font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(color(line.kind)).frame(width: 12)
                                Text(line.text.isEmpty ? " " : line.text)
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(line.kind == .same ? Color.white.opacity(0.55) : .white)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8).padding(.vertical, 1)
                            .background(bg(line.kind))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func symbol(_ k: DiffLine.Kind) -> String { k == .add ? "+" : (k == .remove ? "−" : "") }
    private func color(_ k: DiffLine.Kind) -> Color { k == .add ? .green : (k == .remove ? .red : .secondary) }
    private func bg(_ k: DiffLine.Kind) -> Color {
        switch k {
        case .add:    return Color.green.opacity(0.12)
        case .remove: return Color.red.opacity(0.12)
        case .same:   return .clear
        }
    }

    // MARK: Actions

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isRunning else { return }
        messages.append(ChatMessage(id: UUID(), text: text, isUser: true, timestamp: Date()))
        input = ""
        isRunning = true
        ws.snapshotAll()

        let projectLine = ws.projectRoot.map {
            "Project folder (your working directory for terminal + file edits): \($0.path)\n\n"
        } ?? ""
        let mission = """
        \(projectLine)You are Salehman in CODING mode — an elite pair-programmer. Use the terminal and file edits to ACTUALLY do the work in the project folder (don't just describe it). Be precise and complete.

        Task: \(text)
        """

        runningTask = Task {
            let reply = await AgentPipeline.run(mission: mission)
            await MainActor.run {
                messages.append(ChatMessage(id: UUID(), text: reply, isUser: false, timestamp: Date()))
                isRunning = false
                MissionProgress.shared.finish()
                ws.refreshAfterRun()
                if !ws.changedFiles.isEmpty { rightPane = .diff }
            }
        }
    }

    private func stop() {
        runningTask?.cancel()
        isRunning = false
        MissionProgress.shared.finish()
    }
}
