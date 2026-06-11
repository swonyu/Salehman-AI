import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

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
        // Under unit tests the test host launches the app; auto-scanning a real repo
        // here floods the parallel suite with file I/O (it flaked file-sensitive tests
        // like RepoPackerTests). Skip auto-open in tests — the feature still runs in
        // the real app.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        // Open the last project, or default to the owner's Salehman AI repo if present,
        // so the Code tab is ready-to-use by default (no "Open Folder" step needed).
        guard let path = UserDefaults.standard.string(forKey: Self.rootKey) ?? Self.defaultProjectPath() else { return }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        projectRoot = url
        Shell.workingDirectory = url
        Task { await reload() }
    }

    /// Default project when none was saved — the owner's Salehman AI repo if it
    /// exists, so the Code tab opens to a real project instead of an empty prompt.
    private static func defaultProjectPath() -> String? {
        [NSHomeDirectory() + "/Desktop/Salehman AI", NSHomeDirectory() + "/Salehman AI"]
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Directories that would flood the tree / diff snapshots — skipped wholesale.
    /// Reuses `RepoPacker.skipDirs` (deps / build output / VCS / caches, one source
    /// of truth) and adds this repo's own non-source folders: `External Artifacts/`
    /// (a full DUPLICATE of the repo + the browser extension — it was doubling the
    /// scan and freezing the tab) and `salehman-training/` (a ~1 GB local llama.cpp
    /// + model kit). Without these the Code tab recursively read a doubled tree on
    /// the main actor → the "lagging/stuck" the owner reported.
    private static let skipDirs: Set<String> =
        RepoPacker.skipDirs.union(["External Artifacts", "salehman-training"])
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
        Task { await reload() }
    }

    /// Scan the project tree OFF the main actor — file enumeration was blocking the
    /// UI at launch and on every refresh (part of the "lag"). Publishes `files` on main.
    func reload() async {
        guard let root = projectRoot else { files = []; return }
        let skip = Self.skipDirs, exts = Self.codeExts
        files = await Task.detached(priority: .utility) { () -> [URL] in
            var out: [URL] = []
            let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
            if let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                       options: [.skipsHiddenFiles]) {
                // `nextObject()` instead of `for-in`: an NSEnumerator's sync
                // `makeIterator` is unavailable from this async (`Task.detached`)
                // context under Swift 6.
                while let u = en.nextObject() as? URL {
                    if out.count >= 3000 { break }
                    if (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        if skip.contains(u.lastPathComponent) { en.skipDescendants() }
                        continue
                    }
                    if exts.contains(u.pathExtension.lowercased()) { out.append(u) }
                }
            }
            return out.sorted { $0.path < $1.path }
        }.value
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
    /// File reads run OFF the main actor — this used to block the UI at the start of
    /// every Code-tab send (a big chunk of the "lag").
    func snapshotAll() async {
        let urls = files
        snapshots = await Task.detached(priority: .utility) { () -> [URL: String] in
            var snap: [URL: String] = [:]
            for u in urls where (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0 < 400_000 {
                if let s = try? String(contentsOf: u, encoding: .utf8) { snap[u] = s }
            }
            return snap
        }.value
    }

    /// After a run: rescan (the agent may have created files), then flag every file
    /// whose content changed vs. the pre-run snapshot. The content diff reads run OFF
    /// the main actor so a big project doesn't freeze the UI after each run.
    func refreshAfterRun() async {
        await reload()
        let urls = files
        let before = snapshots
        let changed = await Task.detached(priority: .utility) { () -> [URL] in
            var c: [URL] = []
            for u in urls {
                let now = (try? String(contentsOf: u, encoding: .utf8)) ?? ""
                if (before[u] ?? "") != now { c.append(u) }
            }
            return c
        }.value
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
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var approval = CommandApprovalCenter.shared
    @State private var dismissedCloudHint = false   // per-session dismiss of the no-cloud-key banner

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isRunning = false
    @State private var rightPane: RightPane = .file
    @State private var runningTask: Task<Void, Never>?
    @State private var attachedFile: URL?
    @State private var attachedText: String = ""
    @State private var isDropTargeted = false   // drag-a-file-onto-input highlight
    @State private var showWarmupHint = false   // "warming up the local model…" after 5s of silence
    @State private var localServingModel: String?  // which local model serves .salehman (no-cloud case)
    @State private var lastTokPerSec: Double?       // speed of the last local reply (display only)
    @State private var hoveredFile: URL?            // file-tree row under the pointer
    @State private var atBottom = true              // chat scrolled to the end (hides the jump button)
    // Inspector (File/Diff pane) collapse — persisted so it stays out of the way
    // across launches. Auto-expands when a file is selected or a run leaves diffs.
    @AppStorage("code_inspectorCollapsed") private var inspectorCollapsed = false
    @AppStorage("code_treeCollapsed") private var treeCollapsed = false
    @State private var fileFilter = ""   // live filter for the file list
    @State private var expandedDirs: Set<String> = []   // open folders in the tree
    // Find-in-file (the open file) + scroll target shared with diff-jump.
    @State private var fileSearch = ""
    @State private var searchMatchLines: [Int] = []   // 1-based lines containing a match
    @State private var searchIndex = 0
    @State private var scrollLine: Int? = nil         // drives CodeTextView scroll
    @FocusState private var findFocused: Bool         // ⌘F focuses the find-in-file field
    @FocusState private var inputFocused: Bool        // ⌘L jumps to the message input

    /// Files matching the current filter (by relative path, case-insensitive).
    private var filteredFiles: [URL] {
        guard !fileFilter.isEmpty else { return ws.files }
        return ws.files.filter { relativePath($0).localizedCaseInsensitiveContains(fileFilter) }
    }

    enum RightPane: String, CaseIterable { case file = "File", diff = "Diff" }

    var body: some View {
        VStack(spacing: 0) {
            // No-cloud-key notice: Review / coding here silently falls back to the
            // slow local model (or can't fit the codebase). Tap "Add key" → Settings
            // (ContentView stays mounted in RootView, so its sheet handles this).
            if LocalLLM.lacksCloudKey && !dismissedCloudHint {
                CloudKeyHintBanner(onAddKey: { AppState.shared.showSettingsRequested = true },
                                   onDismiss: { dismissedCloudHint = true })
            }
            HSplitView {
                if !treeCollapsed {
                    fileTree
                        .frame(minWidth: 200, idealWidth: 240, maxWidth: 360)
                } else {
                    treeReopenStrip
                }

                VSplitView {
                    chatPane
                        .frame(minHeight: 220)
                    // Collapsible: the inspector used to be pinned at minHeight 160 —
                    // permanently eating half the tab even when empty ("I can't even
                    // minimize it"). Collapsed = a slim reopen bar; auto-expands when
                    // a file is selected or a run produces diffs.
                    if inspectorCollapsed {
                        inspectorReopenBar
                    } else {
                        inspectorPane
                            .frame(minHeight: 160)
                    }
                }
                .frame(minWidth: 420)
            }
            // Opaque flat surface (covers the app's glow blobs) — the Code tab
            // reads like a clean editor, not a mood piece. Neutral GREY, no red cast.
            .background(DS.Palette.codeSurface)
            // Inline command-approval card — the SAME gate as the Chat tab, so terminal /
            // file-edit commands the AI runs here still prompt for approval (unless
            // Unrestricted is on).
            .overlay(alignment: .bottom) {
                if let pending = approval.pending, !settings.unrestrictedTools {
                    ApprovalCard(command: pending.command,
                                 onRun: { approval.resolve(true) },
                                 onCancel: { approval.resolve(false) },
                                 onAlways: { approval.alwaysAllow() })
                        .padding(.bottom, 80).padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(DS.Motion.spring, value: approval.pending?.id)
        }
        // Expand the tree to reveal whatever file becomes selected (diff-jump, AI edit…).
        .onChange(of: ws.selectedFile) { _, sel in revealInTree(sel) }
        // Hidden keyboard shortcuts: ⌘F focuses find-in-file, ⌘. stops a run.
        .background {
            Group {
                Button("") { if ws.selectedFile != nil { rightPane = .file; findFocused = true } }
                    .keyboardShortcut("f", modifiers: .command)
                Button("") { if isRunning { stop() } }
                    .keyboardShortcut(".", modifiers: .command)
                Button("") { inputFocused = true }
                    .keyboardShortcut("l", modifiers: .command)
                Button("") { withAnimation(.easeOut(duration: 0.15)) { treeCollapsed.toggle() } }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            .opacity(0).frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    /// Open every ancestor folder of `url` in the tree so the selected file is visible.
    private func revealInTree(_ url: URL?) {
        guard let url, let root = ws.projectRoot,
              url.path.hasPrefix(root.path + "/") else { return }
        let rel = String(url.path.dropFirst(root.path.count + 1))
        var path = ""
        for part in rel.split(separator: "/").dropLast() {
            path = path.isEmpty ? String(part) : path + "/" + part
            expandedDirs.insert(path)
        }
    }

    // MARK: File tree (left)

    private var fileTree: some View {
        treeContent.background(DS.Palette.codeSurfaceSide)
    }

    private var treeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: ws.openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Palette.accent)
                .keyboardShortcut("o", modifiers: [.command, .shift])
                Spacer()
                if ws.projectRoot != nil {
                    Button { reviewProject() } label: {
                        Label("Review", systemImage: "sparkles")
                            .font(.system(size: 11.5, weight: .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(DS.Palette.accent.opacity(0.15), in: Capsule())
                            .overlay(Capsule().stroke(DS.Palette.accent.opacity(0.30), lineWidth: 1))
                    }
                    .buttonStyle(.plain).foregroundStyle(DS.Palette.accent)
                    .help("Pack the open folder and have Salehman review it — bugs, risks, improvements (⌘R)")
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(isRunning)
                    Button { Task { await ws.reload() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    Button { withAnimation(.easeOut(duration: 0.15)) { treeCollapsed = true } } label: {
                        Image(systemName: "sidebar.left").font(.system(size: 11))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Hide the file tree")
                    .accessibilityLabel("Hide the file tree")
                        .help("Rescan project files")
                        .accessibilityLabel("Rescan project files")
                }
            }
            .padding(10)

            if let root = ws.projectRoot {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10)).foregroundStyle(DS.Palette.accent)
                    Text(root.lastPathComponent)
                        .font(.system(size: 11.5, weight: .bold)).foregroundStyle(.white)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 4)
                    if !ws.files.isEmpty {
                        // Quiet plain count (chrome diet — no badge box)
                        Text("\(ws.files.count) files")
                            .font(.system(size: 9.5)).foregroundStyle(.secondary.opacity(0.8))
                    }
                }
                .padding(.horizontal, 10).padding(.bottom, 6)
            }

            Divider().overlay(DS.Palette.hairline)

            if ws.files.isEmpty {
                emptyTreeHint
            } else {
                fileFilterField
                if !fileFilter.isEmpty {
                    // Filtering → flat matched list (faster to scan than a tree).
                    let shown = filteredFiles
                    if shown.isEmpty {
                        Text("No files match \u{201C}\(fileFilter)\u{201D}")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(shown, id: \.self) { url in fileRow(url) }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                } else if let root = ws.projectRoot {
                    // No filter → collapsible folder tree.
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(FileTreeBuilder.build(files: ws.files, root: root)) { node in
                                FileTreeRow(node: node, depth: 0, expanded: $expandedDirs, ws: ws) { url in
                                    ws.select(url)
                                    rightPane = ws.changedFiles.contains(url) ? .diff : .file
                                    inspectorCollapsed = false
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
    }

    /// Live filter field for the file list (the tree is a flat list of every file,
    /// which gets long on a real project).
    private var fileFilterField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("Filter files", text: $fileFilter)
                .textFieldStyle(.plain).font(.system(size: 11))
            if !fileFilter.isEmpty {
                Button { fileFilter = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel("Clear file filter")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8).padding(.vertical, 6)
    }

    private var emptyTreeHint: some View {
        VStack(spacing: 11) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 23, weight: .light))
                .foregroundStyle(DS.Palette.accent.opacity(0.8))
            Text("Open a project folder\nto start coding")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: ws.openFolder) {
                Text("Open Folder")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 13).padding(.vertical, 6)
                    .background(DS.Palette.accent.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(DS.Palette.accent.opacity(0.30), lineWidth: 1))
            }
            .buttonStyle(.plain).foregroundStyle(DS.Palette.accent)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func fileRow(_ url: URL) -> some View {
        let isSel = ws.selectedFile == url
        let changed = ws.changedFiles.contains(url)
        let icon = FileKind.icon(for: url)
        return Button {
            ws.select(url)
            rightPane = changed ? .diff : .file
            inspectorCollapsed = false   // user asked to see a file — bring the pane back
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon.symbol)
                    .font(.system(size: 10)).foregroundStyle(changed ? DS.Palette.accent : icon.tint)
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
            .background(isSel ? Color.white.opacity(0.08)
                        : (hoveredFile == url ? Color.white.opacity(0.04) : .clear),
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onHover { inside in hoveredFile = inside ? url : (hoveredFile == url ? nil : hoveredFile) }
        }
        .buttonStyle(.plain)
        .contextMenu { fileActionsMenu(url) }
    }

    private func relativePath(_ url: URL) -> String {
        guard let root = ws.projectRoot else { return url.lastPathComponent }
        return url.path.replacingOccurrences(of: root.path + "/", with: "")
    }

    // MARK: Chat pane (top-right)

    /// Quiet icon button for the conversation header — hover-brightens, tooltip label.
    @ViewBuilder
    private func headerIcon(_ icon: String, _ help: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).font(.system(size: 12))
                .frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.secondary)
        .help(help).accessibilityLabel(help)
    }

    private var chatPane: some View {
        VStack(spacing: 0) {
            // Clear the Code-tab conversation (it otherwise accumulates with no reset).
            if !messages.isEmpty {
                HStack(spacing: 10) {
                    if treeCollapsed {
                        headerIcon("sidebar.left", "Show the file tree") {
                            withAnimation(.easeOut(duration: 0.15)) { treeCollapsed = false }
                        }
                    }
                    if let tps = lastTokPerSec {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill").font(.system(size: 8))
                            Text(String(format: "%.0f tok/s", tps)).font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.secondary.opacity(0.8))
                        .help("Speed of the last local reply")
                    }
                    Spacer()
                    headerIcon("square.and.pencil", "New chat") {
                        if !isRunning { withAnimation { messages.removeAll() } }
                    }
                    headerIcon("doc.on.doc", "Copy conversation as Markdown") {
                        let md = messages
                            .map { "**\($0.isUser ? "You" : "Salehman")**\n\n\($0.text)" }
                            .joined(separator: "\n\n---\n\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(md, forType: .string)
                    }
                }
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
                .overlay(alignment: .bottom) { Divider().overlay(DS.Palette.hairline.opacity(0.4)) }
            }
            // Agent steps — feature: plan / agent steps view.
            if isRunning && !progress.steps.isEmpty {
                agentSteps
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if messages.isEmpty && !isRunning {
                            welcome
                        }
                        ForEach(Array(messages.enumerated()), id: \.element.id) { i, msg in
                            if i > 0, msg.timestamp.timeIntervalSince(messages[i-1].timestamp) > 900 {
                                Text(msg.timestamp, style: .time)
                                    .font(.system(size: 10)).foregroundStyle(.secondary.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 2)
                            }
                            codeBubble(msg)
                                .id(msg.id)
                        }
                        if isRunning {
                            streamingView.id("stream")
                        }
                        // Bottom sentinel — tracks whether the view is scrolled to the end.
                        Color.clear.frame(height: 1).id("bottom")
                            .onAppear { atBottom = true }
                            .onDisappear { atBottom = false }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                    // Centered reading column (Claude-style): long lines are hard to
                    // read edge-to-edge on a wide window — cap and center.
                    .frame(maxWidth: 780)
                    .frame(maxWidth: .infinity)
                    .animation(.easeOut(duration: 0.15), value: messages.count)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
                .onChange(of: progress.streamingAnswer) { _, _ in
                    proxy.scrollTo("stream", anchor: .bottom)
                }
                // Floating jump-to-latest (only when scrolled up in history).
                .overlay(alignment: .bottomTrailing) {
                    if !atBottom && !messages.isEmpty {
                        Button {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 30, height: 30)
                                .background(DS.Palette.codeSurfaceSide, in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .padding(.trailing, 16).padding(.bottom, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .help("Jump to the latest message")
                        .accessibilityLabel("Jump to the latest message")
                    }
                }
            }

            inputBar
        }
        .background(Color.clear)
    }

    /// Tappable starter prompts (icon + text) shown on the empty Code conversation.
    private let welcomeExamples: [(icon: String, text: String)] = [
        ("sparkles", "Review this project"),
        ("ladybug", "Find & fix a bug"),
        ("doc.text.magnifyingglass", "Explain a file"),
    ]

    private var welcome: some View {
        VStack(spacing: 14) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(DS.Palette.accent)
                .frame(width: 60, height: 60)
                .background(DS.Palette.accent.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(DS.Palette.accent.opacity(0.22), lineWidth: 1))
                .shadow(color: DS.Palette.accent.opacity(0.16), radius: 10)
            Text("What are we building, Saleh?")
                .font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
            Text("Open a project, then ask me to build, fix, or explain. I run commands and edit files — you approve each one — and the diffs show up here.")
                .font(.system(size: 12.5)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(welcomeExamples, id: \.text) { ex in
                    Button { input = ex.text } label: {
                        HStack(spacing: 5) {
                            Image(systemName: ex.icon).font(.system(size: 10.5))
                                .foregroundStyle(DS.Palette.accent)
                            Text(ex.text).font(.system(size: 11.5, weight: .medium))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.white.opacity(0.06), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.88))
                }
            }
            .padding(.top, 6)
            HStack(spacing: 16) {
                shortcutHint("⌘O", "Open")
                shortcutHint("⌘R", "Review")
                shortcutHint("⌘L", "Ask")
            }
            .padding(.top, 10)
            // The 14B's home: show when the owner's own model is serving locally.
            if let m = localServingModel {
                HStack(spacing: 5) {
                    Circle().fill(DS.Palette.accent).frame(width: 5, height: 5)
                    Text("\(m) · local · ready")
                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
    }

    /// A small keyboard-shortcut chip (key + label) for the welcome footer.
    @ViewBuilder
    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var agentSteps: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress header — "Working · done/total" (the Background-tasks feel).
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 10)).foregroundStyle(DS.Palette.accent)
                Text("Working").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                Spacer().frame(maxWidth: 0)
                Text("\(progress.steps.filter { $0.status == .done }.count)/\(progress.steps.count)")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 5)
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
                        .background(step.status == .running ? DS.Palette.accent.opacity(0.14) : Color.white.opacity(0.05), in: Capsule())
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
            }
        }
        .background(DS.Palette.codeSurfaceSide)
        .overlay(alignment: .bottom) { Divider().overlay(DS.Palette.hairline.opacity(0.5)) }
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
        let isLastAssistant = !msg.isUser && msg.id == messages.last(where: { !$0.isUser })?.id
        return CodeMessageRow(msg: msg,
                              onRegenerate: (isLastAssistant && !isRunning) ? { regenerateLast() } : nil)
    }

    /// Re-run the last user prompt (drops the reply being regenerated first).
    private func regenerateLast() {
        guard !isRunning, let lastUser = messages.last(where: { $0.isUser }) else { return }
        if let last = messages.last, !last.isUser { messages.removeLast() }
        runMission(for: lastUser.text)
    }

    private var streamingView: some View {
        HStack(alignment: .top, spacing: 10) {
            PulsingDot().padding(.top, 7)
            VStack(alignment: .leading, spacing: 4) {
                if progress.streamingAnswer.isEmpty {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.6)
                        // After ~5s of silence the local model is probably still
                        // loading into RAM (a 14B is ~9 GB) — say so instead of
                        // looking frozen.
                        Text(showWarmupHint ? "Warming up the local model — first reply after a pause takes a few seconds…"
                                            : "Working…")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                } else if progress.streamingAnswer.count <= StreamRender.liveMarkdownLimit {
                    MarkdownText(text: progress.streamingAnswer)
                } else {
                    // Long reply still streaming: render plain to keep the main thread
                    // free — full Markdown re-parses O(n) every throttle tick, which is
                    // what makes a fast local model (the 32B) lag the UI. The committed
                    // message renders full Markdown once, the moment streaming ends.
                    Text(progress.streamingAnswer)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            if let att = attachedFile {
                HStack(spacing: 6) {
                    Image(systemName: "paperclip").font(.system(size: 10))
                    Text(att.lastPathComponent).font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                    Button { attachedFile = nil; attachedText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.white.opacity(0.05), in: Capsule())
            }
            VStack(spacing: 9) {
                // Text first — full width, comfortable, nothing competing with it.
                TextField("Ask Salehman to build, fix, or explain…", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .lineLimit(1...6)
                    .focused($inputFocused)
                    .onSubmit(send)
                    // Focusing the input = intent to send: pre-load the local model
                    // (a 14B takes seconds to come into RAM) while the user types.
                    .onChange(of: inputFocused) { _, focused in
                        if focused { OllamaClient.warmupChatModel() }
                    }
                // Controls live UNDER the text (Claude layout): brain/effort menu +
                // attach on the left, filled send on the right.
                HStack(spacing: 8) {
                    controlsMenu
                    Button { attachFile() } label: { Image(systemName: "paperclip").font(.system(size: 13)) }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .help("Attach a file as context")
                        .accessibilityLabel("Attach a file as context")
                    Spacer()
                    Button {
                        // Explicit body, not `action: isRunning ? stop : send`: unifying
                        // two method references into one closure ICEs the type-checker
                        // ("failed to produce diagnostic") under the Swift 6 language mode.
                        if isRunning { stop() } else { send() }
                    } label: {
                        Image(systemName: isRunning ? "stop.fill" : "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isRunning ? Color.white
                                : (input.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.45) : Color.white))
                            .frame(width: 27, height: 27)
                            .background(
                                isRunning ? AnyShapeStyle(Color.red.opacity(0.85))
                                    : (input.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? AnyShapeStyle(Color.white.opacity(0.10))
                                        : AnyShapeStyle(DS.Palette.accent)),
                                in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isRunning && input.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel(isRunning ? "Stop generating" : "Send")
                }
            }
            .padding(.horizontal, 13).padding(.top, 11).padding(.bottom, 9)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            // The signature red ring (owner request — matches the main chat's input):
            // always visible, warms while typing, full-strength on file drop.
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                isDropTargeted ? DS.Palette.accent
                    : DS.Palette.accent.opacity(
                        input.trimmingCharacters(in: .whitespaces).isEmpty ? 0.38 : 0.60),
                lineWidth: isDropTargeted ? 1.5 : 1))
            .shadow(color: DS.Palette.accent.opacity(inputFocused ? 0.18 : 0), radius: 12, y: 2)
            .animation(.easeOut(duration: 0.18), value: input.isEmpty)
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .animation(.easeOut(duration: 0.2), value: inputFocused)
            // Drag a file onto the input to attach it as context.
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.isFileURL else { return }
                    Task { @MainActor in
                        attachedFile = url
                        attachedText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                    }
                }
                return true
            }
        }
        .frame(maxWidth: 780)
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.ultraThinMaterial)
    }

    /// Quick controls (brain / effort / toggles) — the Code-tab equivalent of the
    /// model/effort/thinking menu, so you don't have to open Settings to switch.
    private var controlsMenu: some View {
        Menu {
            Picker("Brain", selection: $settings.brainPreference) {
                ForEach(BrainPreference.selectableCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Effort", selection: $settings.responseMode) {
                ForEach(AppSettings.ResponseMode.allCases) { Text($0.title).tag($0) }
            }
            Divider()
            Toggle("Auto-continue", isOn: $settings.autoContinue)
            Toggle("Web access", isOn: $settings.webAccess)
            Toggle("Unrestricted", isOn: $settings.unrestrictedTools)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 13))
                Text(settings.brainPreference.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                // Which LOCAL model is actually serving (only shown when Salehman has
                // no cloud configured, so the local floor is what answers): the owner's
                // own fine-tune gets the accent — a fallback coder stays grey. Makes
                // "is the real salehman14b active?" visible at a glance.
                if let m = localServingModel {
                    Text("· \(m)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(m.hasPrefix(AppSettings.customModelNameCurrent)
                                         ? AnyShapeStyle(DS.Palette.accent) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.white.opacity(0.06), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help("Active brain — tap to switch brain, effort & toggles")
        .accessibilityLabel("Active brain \(settings.brainPreference.title) — tap to change")
        // Refresh the serving-model suffix when the tab appears or the brain changes.
        .task(id: settings.brainPreference) { await refreshServingModel() }
    }

    /// Resolve which local model would serve `.salehman` right now (nil when a cloud
    /// is configured — cloud-first means the floor isn't what answers).
    private func refreshServingModel() async {
        guard settings.brainPreference == .salehman, !SalehmanEngine.hasAnyCloud else {
            localServingModel = nil; return
        }
        localServingModel = await OllamaClient.activeChatModel()
    }

    // MARK: Inspector pane (bottom-right): file viewer / diff

    /// Always-visible slim strip while the file tree is collapsed — the previous
    /// reopen button lived in the conversation header (absent on an empty chat),
    /// which made a collapsed tree unrecoverable (owner hit this). ⇧⌘E also toggles.
    private var treeReopenStrip: some View {
        VStack(spacing: 14) {
            Button { withAnimation(.easeOut(duration: 0.15)) { treeCollapsed = false } } label: {
                Image(systemName: "sidebar.left").font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help("Show the file tree (⇧⌘E)")
            .accessibilityLabel("Show the file tree")
            Button(action: ws.openFolder) {
                Image(systemName: "folder.badge.plus").font(.system(size: 10.5))
                    .frame(width: 24, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help("Open a project folder")
            .accessibilityLabel("Open a project folder")
            if ws.projectRoot != nil {
                Button { reviewProject() } label: {
                    Image(systemName: "sparkles").font(.system(size: 10.5))
                        .frame(width: 24, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(DS.Palette.accent.opacity(0.8))
                .disabled(isRunning)
                .help("Review this project (⌘R)")
                .accessibilityLabel("Review this project")
            }
            Spacer()
        }
        .padding(.top, 10)
        .frame(width: 26)
        .frame(maxHeight: .infinity)
        .background(DS.Palette.codeSurfaceSide)
    }

    /// Slim bar shown while the inspector is collapsed — one click brings it back.
    private var inspectorReopenBar: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { inspectorCollapsed = false }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up").font(.system(size: 9, weight: .semibold))
                Text("Files & Diffs").font(.system(size: 10.5, weight: .medium))
                if !ws.changedFiles.isEmpty {
                    Text("\(ws.changedFiles.count) changed")
                        .font(.system(size: 9.5, weight: .semibold)).foregroundStyle(DS.Palette.accent)
                }
                Spacer()
            }
            .padding(.horizontal, 12).frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.secondary)
        .background(DS.Palette.codeSurfaceSide)
        .help("Show the file viewer / diff panel")
        .accessibilityLabel("Show the files and diffs panel")
    }

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
                if rightPane == .diff && !ws.diff.isEmpty {
                    let stats = diffStats
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 4, height: 4)
                            Text("+\(stats.added)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.green)
                        }
                        HStack(spacing: 3) {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 4, height: 4)
                            Text("-\(stats.removed)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.03), in: Capsule())
                }
                if !ws.changedFiles.isEmpty && rightPane != .diff {
                    HStack(spacing: 4) {
                        Circle().fill(DS.Palette.accent).frame(width: 5, height: 5)
                        Text("\(ws.changedFiles.count) changed")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Palette.accent)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(DS.Palette.accent.opacity(0.12), in: Capsule())
                }
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { inspectorCollapsed = true }
                } label: {
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Hide this panel (it comes back when a run has diffs)")
                .accessibilityLabel("Hide the files and diffs panel")
            }
            .padding(10)
            Divider().overlay(DS.Palette.hairline)

            if ws.selectedFile == nil {
                VStack(spacing: 9) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.55))
                    Text("Select a file to view it,\nor run a task to see diffs.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rightPane == .diff {
                diffView
            } else {
                fileView
            }
        }
        .background(DS.Palette.codeSurfaceSide)
    }

    private var fileView: some View {
        VStack(spacing: 0) {
            fileSearchBar
            // Syntax-highlighted, line-numbered viewer (see CodeSyntaxView.swift).
            CodeTextView(content: ws.fileContent,
                         ext: ws.selectedFile?.pathExtension ?? "",
                         searchTerm: fileSearch,
                         scrollLine: scrollLine)
        }
        .onChange(of: ws.selectedFile) { _, _ in clearSearch() }
    }

    private var fileSearchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 10))
            TextField("Find in file", text: $fileSearch)
                .textFieldStyle(.plain).font(.system(size: 11))
                .focused($findFocused)
                .onSubmit { jumpMatch(+1) }
            if !fileSearch.isEmpty {
                Text(searchMatchLines.isEmpty ? "0/0" : "\(searchIndex + 1)/\(searchMatchLines.count)")
                    .font(.system(size: 10, design: .monospaced))
                Button { jumpMatch(-1) } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.plain).disabled(searchMatchLines.isEmpty).accessibilityLabel("Previous match")
                Button { jumpMatch(+1) } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.plain).disabled(searchMatchLines.isEmpty).accessibilityLabel("Next match")
                Button { clearSearch() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
            Spacer(minLength: 8)
            if let sel = ws.selectedFile {
                let ext = sel.pathExtension.isEmpty ? "—" : sel.pathExtension.uppercased()
                let lineCount = ws.fileContent.split(separator: "\n", omittingEmptySubsequences: false).count
                let sizeKB = Int((try? sel.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) / 1024
                HStack(spacing: 6) {
                    Text(ext).font(.system(size: 9, weight: .semibold, design: .monospaced))
                    Text("·").foregroundStyle(.secondary.opacity(0.5))
                    Text("\(lineCount) lines").font(.system(size: 9))
                    if sizeKB > 0 {
                        Text("·").foregroundStyle(.secondary.opacity(0.5))
                        Text("\(sizeKB) KB").font(.system(size: 9))
                    }
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Color.white.opacity(0.03), in: Capsule())
            }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .onChange(of: fileSearch) { _, _ in recomputeMatches() }
    }

    private func clearSearch() {
        fileSearch = ""; searchMatchLines = []; searchIndex = 0
    }

    private func recomputeMatches() {
        guard !fileSearch.isEmpty else { searchMatchLines = []; searchIndex = 0; return }
        searchMatchLines = ws.fileContent.components(separatedBy: "\n").enumerated().compactMap { i, line in
            line.range(of: fileSearch, options: .caseInsensitive) != nil ? i + 1 : nil
        }
        searchIndex = 0
        scrollLine = searchMatchLines.first
    }

    /// Cycle to the next (+1) / previous (-1) match and scroll to it.
    private func jumpMatch(_ dir: Int) {
        guard !searchMatchLines.isEmpty else { return }
        searchIndex = (searchIndex + dir + searchMatchLines.count) % searchMatchLines.count
        scrollLine = searchMatchLines[searchIndex]
    }

    private var diffView: some View {
        Group {
            if ws.diff.isEmpty {
                Text("No changes for this file in the last run.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let ext = ws.selectedFile?.pathExtension ?? ""
                let rows = numberedDiff(ws.diff)
                let w = max(2, String(rows.last?.new ?? rows.count).count)
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows, id: \.line.id) { row in
                            Button {
                                // Jump to this line in the file view.
                                if let target = row.new ?? row.old {
                                    rightPane = .file
                                    scrollLine = target
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(row.old.map { String(format: "%\(w)d", $0) } ?? String(repeating: "\u{00A0}", count: w))
                                        .foregroundStyle(.white.opacity(0.22))
                                    Text(row.new.map { String(format: "%\(w)d", $0) } ?? String(repeating: "\u{00A0}", count: w))
                                        .foregroundStyle(.white.opacity(0.22))
                                    Text(symbol(row.line.kind)).fontWeight(.bold)
                                        .foregroundStyle(color(row.line.kind)).frame(width: 10)
                                    Text(row.line.text.isEmpty ? AttributedString(" ") : CodeSyntax.highlight(row.line.text, ext: ext))
                                        .fixedSize(horizontal: true, vertical: false)
                                    Spacer(minLength: 0)
                                }
                                .font(.system(size: 11.5, design: .monospaced))
                                .padding(.horizontal, 8).padding(.vertical, 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(bg(row.line.kind))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Jump to line \(row.new ?? row.old ?? 0) in the file")
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    /// Quick add/remove counts for the diff view.
    private var diffStats: (added: Int, removed: Int) {
        (ws.diff.filter { $0.kind == .add }.count,
         ws.diff.filter { $0.kind == .remove }.count)
    }

    /// Annotate diff lines with their old/new file line numbers for the gutter.
    private func numberedDiff(_ diff: [DiffLine]) -> [(line: DiffLine, old: Int?, new: Int?)] {
        var out: [(line: DiffLine, old: Int?, new: Int?)] = []
        var o = 0, n = 0
        for d in diff {
            switch d.kind {
            case .same:   o += 1; n += 1; out.append((d, o, n))
            case .add:    n += 1;         out.append((d, nil, n))
            case .remove: o += 1;         out.append((d, o, nil))
            }
        }
        return out
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
        runMission(for: text)
    }

    /// The shared run pipeline — used by send() and regenerate (which must NOT
    /// re-append the user message).
    private func runMission(for text: String) {
        guard !isRunning else { return }
        isRunning = true
        // If nothing has streamed after 5s, the local model is likely still loading —
        // flip the status line to say so (cleared when the run ends).
        showWarmupHint = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if isRunning && progress.streamingAnswer.isEmpty { showWarmupHint = true }
        }

        let projectLine = ws.projectRoot.map {
            "Project folder (your working directory for terminal + file edits): \($0.path)\n\n"
        } ?? ""
        let attached = attachedText.isEmpty ? "" : "\n\nAttached file \"\(attachedFile?.lastPathComponent ?? "file")\":\n\(attachedText)"
        // A bare greeting / chit-chat ("hi", "thanks") shouldn't get the heavy
        // coding-mode preamble: that preamble alone is multi-line, >200 chars and
        // multi-sentence, so `complexity()` rates EVERY wrapped message `.hard` — and
        // in Maximum mode that spins up all 15 agents for a simple "hi". Sending the
        // raw text lets the pipeline see it's trivial → one agent → fast reply.
        let mission: String
        if attached.isEmpty, AgentPipeline.isTrivialMission(text) {
            mission = text
        } else {
            mission = """
            \(projectLine)You are Salehman in CODING mode — an elite pair-programmer. Use the terminal and file edits to ACTUALLY do the work in the project folder (don't just describe it). Be precise and complete.

            Task: \(text)\(attached)
            """
        }
        attachedFile = nil; attachedText = ""

        runningTask = Task {
            await ws.snapshotAll()                       // off-main pre-run snapshot
            let reply = await AgentPipeline.run(mission: mission)
            if Task.isCancelled { return }
            await MainActor.run {
                messages.append(ChatMessage(id: UUID(), text: reply, isUser: false, timestamp: Date()))
                isRunning = false
                showWarmupHint = false
                lastTokPerSec = OllamaClient.lastStats?.tps   // show how fast the local model ran
                MissionProgress.shared.finish()
            }
            await ws.refreshAfterRun()                   // off-main post-run diff
            await MainActor.run {
                if !ws.changedFiles.isEmpty { rightPane = .diff; inspectorCollapsed = false }
            }
        }
    }

    /// Attach a local file as context for the next message.
    private func attachFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Attach"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        attachedFile = url
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? "(binary or unreadable file)"
        attachedText = raw.count > 20_000 ? String(raw.prefix(20_000)) + "\n…(truncated)" : raw
    }

    /// "Review": Repomix-style — pack the open folder (off the main actor) into one
    /// digest and have Salehman review it: summary, bugs/risks, prioritized
    /// improvements, anything off. One click after Open Folder → choose a folder.
    private func reviewProject() {
        guard let root = ws.projectRoot, !isRunning else { return }
        isRunning = true
        messages.append(ChatMessage(id: UUID(), text: "🔍 Review \(root.lastPathComponent)", isUser: true, timestamp: Date()))
        runningTask = Task {
            // Start a CLEAN thread: clear any stale context so a prior review/chat
            // can't bleed in, then (below, via a normal run) RECORD this review so a
            // follow-up like "fix them all" knows what "them" refers to.
            await ConversationStore.shared.reset()
            let packed = await Task.detached(priority: .userInitiated) { RepoPacker.pack(rootPath: root.path) }.value
            // Honesty gate: a whole-codebase review is only trustworthy on a brain
            // that can actually INGEST the codebase. With no cloud key the only brain
            // is the local qwen2.5-coder at a 4096-token window (~12 KB of text) — it
            // would see a tiny fraction and hallucinate findings (observed repeatedly:
            // it "reviewed" code it never saw). Refuse instead of emitting guesswork;
            // small folders that DO fit the window still go through.
            let localContextBudget = 12_000
            if !SalehmanEngine.hasAnyCloud && packed.digest.count > localContextBudget {
                let pct = max(1, Int((Double(localContextBudget) / Double(packed.digest.count)) * 100))
                let msg = """
                ⚠️ Can't give a trustworthy review here.

                This folder packs to \(RepoPacker.byteString(packed.totalBytes)) across \(packed.fileCount) files, but with no cloud key the review runs on the local model's 4096-token window — it sees ~12 KB at a time (≈\(pct)% of your code), so any "review" would be guesswork (that's exactly why the last ones echoed code and refused).

                To get a real review: add a free Groq or Cerebras key in Settings → Brain — both ingest the whole codebase. Then run Review again. (Or open a smaller folder that fits the local window.)
                """
                await MainActor.run {
                    messages.append(ChatMessage(id: UUID(), text: msg, isUser: false, timestamp: Date()))
                    isRunning = false
                    MissionProgress.shared.finish()
                }
                return
            }
            let cap = 180_000
            let shown = String(packed.digest.prefix(cap))
            // Be HONEST about truncation: if the model only sees part of the project,
            // tell it so — otherwise it hallucinates "truncated file" / "missing X"
            // findings about code it simply wasn't shown (observed in the wild).
            let partial = packed.truncated || packed.digest.count > cap
            let warn = partial
                ? "\n\n⚠️ IMPORTANT: This is a PARTIAL view — the project was truncated to fit. Do NOT claim a file is missing, truncated, or absent based on this; only comment on what you can actually SEE below. If you need a specific file, ask for it by name.\n"
                : ""
            let mission = """
            Review this codebase (\(packed.fileCount) files, \(RepoPacker.byteString(packed.totalBytes))).\(warn)
            1. A 2–3 line summary of what it is.
            2. Concrete bugs or risks you can see (reference file names).
            3. The highest-value improvements, prioritized.
            4. Anything that looks off or inconsistent.
            Be specific and practical — and only about what's actually shown below.

            \(shown)
            """
            // Normal run (records the review) — context was just reset above, so it's
            // clean AND the findings are remembered for a follow-up like "fix them all".
            // Hard timeout so Review can NEVER hang on "Working…" forever: a slow or
            // stuck brain shouldn't spin indefinitely. 60 s is generous for a real
            // cloud review; past that we stop and say why instead of leaving a spinner.
            let timeoutSeconds: UInt64 = 60
            let reply: String = await withTaskGroup(of: String?.self) { group in
                group.addTask { await AgentPipeline.run(mission: mission) }
                group.addTask {
                    try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first ?? "⏱️ Review stopped — it took longer than \(timeoutSeconds)s. The current brain is too slow for a whole-codebase review. Add a fast cloud key (Groq / Cerebras, free) in Settings → Brain, or open a smaller folder."
            }
            if Task.isCancelled { return }
            await MainActor.run {
                messages.append(ChatMessage(id: UUID(), text: reply, isUser: false, timestamp: Date()))
                isRunning = false
                showWarmupHint = false
                MissionProgress.shared.finish()
            }
        }
    }

    private func stop() {
        runningTask?.cancel()
        isRunning = false
        MissionProgress.shared.finish()
    }
}

/// One conversation row, Claude-Code style: the user's message is a quiet
/// right-aligned block; Salehman's reply flows flush-left like a document —
/// no avatars, no name labels, copy appears on hover. Simple and elegant.
struct CodeMessageRow: View {
    let msg: ChatMessage
    var onRegenerate: (() -> Void)? = nil
    @ObservedObject private var speech = SpeechOut.shared
    @State private var hovering = false

    var body: some View {
        if msg.isUser {
            HStack {
                Spacer(minLength: 60)
                Text(msg.text)
                    .font(.system(size: 13.5))
                    .textSelection(.enabled)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(Color.white.opacity(0.09),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                MarkdownText(text: msg.text)
                Spacer(minLength: 26)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 64)   // room for the hover action pill
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    action(speech.speakingID == msg.id ? "speaker.wave.2.fill" : "speaker.wave.2",
                           "Read aloud", active: speech.speakingID == msg.id) {
                        speech.toggle(msg.text, id: msg.id)
                    }
                    action("doc.on.doc", "Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(msg.text, forType: .string)
                    }
                    if let regen = onRegenerate {
                        action("arrow.clockwise", "Regenerate", regen)
                    }
                }
                .opacity(hovering ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: hovering)
            }
            .onHover { hovering = $0 }
        }
    }

    private func action(_ icon: String, _ help: String, active: Bool = false,
                        _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).font(.system(size: 11))
                .foregroundStyle(active ? DS.Palette.accent : .secondary)
                .frame(width: 20, height: 20).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Small breathing accent dot shown while a reply streams in.
struct PulsingDot: View {
    @State private var on = false
    var body: some View {
        Circle().fill(DS.Palette.accent)
            .frame(width: 7, height: 7)
            .opacity(on ? 1 : 0.35)
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { on = true } }
            .accessibilityHidden(true)
    }
}

/// Deterministic Code-tab states for the QA snapshot harness — mirrors the chat
/// gallery but for the Code tab's own row style. Fixed clock + content so
/// before/after diffs are stable. Includes an Arabic reply (the 14B answers in
/// Arabic) to catch RTL/script rendering regressions.
struct CodeSampleGallery: View {
    private let now = Date(timeIntervalSince1970: 1_781_200_000)
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            sec("User block — right-aligned, no avatar") {
                CodeMessageRow(msg: .init(id: UUID(), text: "fix the off-by-one in the paginator", isUser: true, timestamp: now))
            }
            sec("Assistant — flush-left document, syntax-highlighted code, hover-copy") {
                CodeMessageRow(msg: .init(id: UUID(), text: """
                Found it in `Paginator.swift` — the loop used `<=` but pages are 0-indexed:

                ```swift
                for i in 0..<count {   // was 0...count
                    rows.append(page[i])
                }
                ```

                Built + ran the tests — all green. The last page no longer double-counts.
                """, isUser: false, timestamp: now), onRegenerate: {})
            }
            sec("Arabic reply — RTL/script rendering (the 14B speaks Arabic)") {
                CodeMessageRow(msg: .init(id: UUID(), text: "تم — أضفت زر يحذف الملفات المؤقتة، وبنيت المشروع. يشتغل تمام.", isUser: false, timestamp: now))
            }
            sec("Streaming — pulsing dot above, plain text while long") {
                HStack(alignment: .top, spacing: 10) {
                    PulsingDot().padding(.top, 7)
                    Text("Generating the refactor plan across the auth module…")
                        .font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.92))
                }
            }
            sec("Agent strip — one agent, tool-round note") {
                AgentRunView(steps: [
                    .init(name: "Reasoning Strategist", icon: "brain.head.profile",
                          status: .running, adapted: "Reasoning Strategist · tool round 2/8")
                ])
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.codeSurface)
    }

    private func sec<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(1.1)
                .foregroundStyle(DS.Palette.textSecondary)
            content()
        }
    }
}
