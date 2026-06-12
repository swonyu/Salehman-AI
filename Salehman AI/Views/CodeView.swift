import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import Vision

// MARK: - Screenshot attach (/shot)

/// Finds the user's most recent screenshot and extracts its TEXT on-device
/// (Vision OCR) — the local 14B has no image input, but error dialogs, terminal
/// output, and UI text in a screenshot become perfectly good context as text.
enum ScreenshotGrabber {
    /// Where macOS saves screenshots (`com.apple.screencapture location` is the
    /// authority — this owner moved theirs to ~/Pictures/Screenshots; Desktop is
    /// the fallback).
    nonisolated static func screenshotsDirectory() -> URL {
        if let loc = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !loc.isEmpty {
            let url = URL(fileURLWithPath: (loc as NSString).expandingTildeInPath, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    /// Newest image file in `dir` (by modification date). Injectable for tests.
    nonisolated static func latestScreenshot(in dir: URL) -> URL? {
        let exts: Set<String> = ["png", "jpg", "jpeg", "heic"]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])) ?? []
        return files
            .filter { exts.contains($0.pathExtension.lowercased()) }
            .max { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return da < db
            }
    }

    /// On-device OCR (accurate mode). Returns recognized lines top-to-bottom,
    /// empty string when nothing is legible.
    nonisolated static func ocr(_ url: URL) -> String {
        guard let img = NSImage(contentsOf: url) else { return "" }
        var rect = CGRect.zero
        guard let cg = img.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cg)
        try? handler.perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

// MARK: - Diff model

nonisolated struct DiffLine: Identifiable {
    nonisolated enum Kind: Equatable { case same, add, remove }
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
    /// Per-file added/removed line counts for the last run's changes — shown as
    /// "+N −M" next to each row in the right panel's Changed-files list.
    @Published var changeStats: [URL: DiffStat] = [:]
    struct DiffStat: Equatable { let added: Int; let removed: Int }

    /// Files git considers modified/untracked (amber dot in the tree) — refreshed
    /// on every `reload()`. Distinct from `changedFiles` (THIS RUN's edits, accent
    /// dot): git dots show everything uncommitted, run dots show what the AI just
    /// touched. Empty when the project isn't a git repo.
    @Published var gitModified: Set<URL> = []

    private func refreshGitStatus() async {
        guard let root = projectRoot else { gitModified = []; return }
        let modified = await Task.detached(priority: .utility) { () -> Set<URL> in
            // -uall lists files inside untracked directories individually — without
            // it git collapses them to one "dir/" entry that no tree row matches.
            let escaped = root.path.replacingOccurrences(of: "'", with: "'\\''")
            let res = Shell.run("git -C '\(escaped)' status --porcelain -uall", timeout: 10)
            guard res.exitCode == 0 else { return [] }
            return CodeWorkspace.gitModifiedURLs(porcelain: res.output, root: root)
        }.value
        gitModified = modified
    }

    /// Parses `git status --porcelain` output into the set of file URLs with
    /// uncommitted changes. Renames count as the NEW path; C-quoted paths get
    /// their quotes stripped (escape sequences inside are left as-is — those
    /// rows just won't match a tree URL, which is a harmless miss).
    nonisolated static func gitModifiedURLs(porcelain: String, root: URL) -> Set<URL> {
        var out: Set<URL> = []
        for line in porcelain.components(separatedBy: "\n") where line.count > 3 {
            // porcelain: "XY path" (or "XY old -> new" for renames — take the new side)
            var path = String(line.dropFirst(3))
            if let arrow = path.range(of: " -> ") { path = String(path[arrow.upperBound...]) }
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            out.insert(root.appendingPathComponent(path))
        }
        return out
    }

    private var snapshots: [URL: String] = [:]

    /// UserDefaults key for the last-opened project folder, so the Code tab
    /// reopens it on launch instead of making you re-pick every time. (The app
    /// isn't sandboxed, so a plain path round-trips without a security bookmark.)
    private static let rootKey = "code_projectRoot"
    private static let recentsKey = "code_recentProjects"

    /// MRU project folders (most recent first, existing-on-disk only, max 6) —
    /// drives the tree header's quick-switcher so changing projects is one click
    /// instead of a re-pick through the open panel every time.
    @Published var recentProjects: [URL] = []

    private func noteRecent(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        paths = Array(paths.prefix(6))
        UserDefaults.standard.set(paths, forKey: Self.recentsKey)
        recentProjects = paths.filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Switch straight to a known folder (recents menu) — same plumbing as
    /// `openFolder()` minus the panel.
    func openProject(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        projectRoot = url
        Shell.workingDirectory = url
        UserDefaults.standard.set(url.path, forKey: Self.rootKey)
        noteRecent(url)
        selectedFile = nil; fileContent = ""; diff = []; changedFiles = []; changeStats = [:]
        Task { await reload() }
    }

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
        noteRecent(url)
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
        openProject(at: url)
    }

    // MARK: Restore checkpoint (revert this run's AI edits)

    /// Disk side of a revert: write the pre-run snapshot back, or — when the run
    /// CREATED the file (no snapshot) — delete it. Pure function of its inputs;
    /// unit-tested against a temp directory.
    nonisolated static func revert(file: URL, toSnapshot snapshot: String?) throws {
        if let snapshot {
            try snapshot.write(to: file, atomically: true, encoding: .utf8)
        } else {
            try FileManager.default.removeItem(at: file)
        }
    }

    /// Revert ONE changed file to its pre-run state (Cursor's "Restore Checkpoint",
    /// per file). Updates every dependent surface: changed list, stats, tree, the
    /// open file/diff pane, and the git dots.
    @discardableResult
    func restoreFromSnapshot(_ url: URL) -> Bool {
        let snap = snapshots[url]          // nil ⇒ the run created this file
        do { try Self.revert(file: url, toSnapshot: snap) } catch { return false }
        changedFiles.removeAll { $0 == url }
        changeStats[url] = nil
        if snap == nil { files.removeAll { $0 == url } }
        if selectedFile == url {
            if let snap { fileContent = snap; diff = [] }
            else { selectedFile = nil; fileContent = ""; diff = [] }
        }
        Task { await refreshGitStatus() }
        return true
    }

    /// Revert EVERY file the last run touched — the one-click "Restore all".
    func restoreAllChanged() {
        for url in changedFiles { restoreFromSnapshot(url) }
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
        await refreshGitStatus()
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
        let (changed, stats) = await Task.detached(priority: .utility) { () -> ([URL], [URL: DiffStat]) in
            var c: [URL] = []
            var s: [URL: DiffStat] = [:]
            for u in urls {
                let now = (try? String(contentsOf: u, encoding: .utf8)) ?? ""
                let old = before[u] ?? ""
                guard old != now else { continue }
                c.append(u)
                // +N −M for the panel list — same capped LCS as the diff pane,
                // so the numbers always agree with what the pane shows.
                let lines = CodeWorkspace.lineDiff(old: old, new: now)
                s[u] = DiffStat(added: lines.filter { $0.kind == .add }.count,
                                removed: lines.filter { $0.kind == .remove }.count)
            }
            return (c, s)
        }.value
        changedFiles = changed
        changeStats = stats
        if let first = changed.first { select(first) }
    }

    /// Minimal LCS line-diff. Caps each side so a huge file can't stall the UI.
    nonisolated static func lineDiff(old: String, new: String) -> [DiffLine] {
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
/// A `/`-command in the Code composer (Claude-Code style). `template` commands
/// pre-fill the input with a ready-to-continue prompt; `action` commands run an
/// in-view operation (new chat, copy) immediately.
struct SlashCommand: Identifiable {
    let id: String            // the trigger word, e.g. "tests"
    let icon: String
    let blurb: String
    let kind: Kind
    enum Kind { case template(String), action(String) }
    var trigger: String { "/" + id }
}

/// Press physics for pills and primary actions (design language): the whole
/// control compresses slightly under the pointer — simulated mass, not a color
/// swap. GPU-safe (transform only), sprung on the shared lux curve.
struct LuxPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(CodeView.lux, value: configuration.isPressed)
    }
}

/// The `/`-command dropdown rendered above the Code composer. Extracted as its own
/// view so the QA gallery can photograph it deterministically (the inline version
/// only exists while `input` starts with "/").
struct SlashMenuView: View {
    let matches: [SlashCommand]
    @Binding var hovered: String?
    var onPick: (SlashCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(matches) { cmd in
                Button { onPick(cmd) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: cmd.icon).font(.system(size: 12))
                            .foregroundStyle(DS.Palette.accent).frame(width: 16)
                        Text(cmd.trigger).font(.system(size: 12.5, weight: .medium))
                        Text(cmd.blurb).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        if cmd.id == matches.first?.id {
                            Text("↵").font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(hovered == cmd.id ? Color.white.opacity(0.06) : .clear,
                                in: RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .offset(y: 4)))
                .onHover { over in
                    withAnimation(DS.Motion.magnetic) {
                        hovered = over ? cmd.id : (hovered == cmd.id ? nil : hovered)
                    }
                }
            }
        }
        .animation(DS.Motion.smooth, value: matches.count)
        .padding(5)
        // Inner core: its own surface + machined top bevel…
        .background(DS.Palette.codeSurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        // …seated in an outer tray carrying the accent ring (double-bezel, 15−4=11).
        .padding(4)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .stroke(DS.Palette.accent.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 5)
    }
}

/// One agent step card in the right panel's Activity section. Extracted so the
/// QA gallery photographs the REAL component in a deterministic running state.
struct ActivityStepRow: View {
    let step: MissionProgress.Step

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Self.icon(step.status)
            Text(step.adapted ?? step.name).font(.system(size: 11.5))
                .foregroundStyle(step.status == .done ? .secondary : Color.white.opacity(0.9))
                .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            step.status == .running ? DS.Palette.accent.opacity(0.07) : Color.white.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            if step.status == .running {
                DS.Palette.accent.frame(width: 2.5)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        // Machined top bevel — each step card reads as a physical tile.
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.01)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        .animation(DS.Motion.smooth, value: step.status)
    }

    @ViewBuilder static func icon(_ status: MissionProgress.Status) -> some View {
        switch status {
        case .pending: Image(systemName: "circle").font(.system(size: 9)).foregroundStyle(.secondary)
        case .running: ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
        case .done:    Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(DS.Palette.accent)
        }
    }
}

/// One row of the right panel's "Changed files" list. Extracted for the same
/// reason as `ActivityStepRow` — gallery coverage of the real component.
struct ChangedFileRow: View {
    let label: String
    let isSelected: Bool
    var stat: CodeWorkspace.DiffStat? = nil
    var onRestore: (() -> Void)? = nil
    var onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                Image(systemName: "plus.forwardslash.minus").font(.system(size: 9))
                    .foregroundStyle(DS.Palette.accent.opacity(0.85))
                Text(label)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1).truncationMode(.head)
                    .foregroundStyle(isSelected ? .white : .secondary)
                Spacer(minLength: 0)
                // Hover swaps the stats for a per-file undo — accept the good
                // files, revert just the bad one (Cursor/Zed review pattern).
                if hovering, let onRestore {
                    Button(action: onRestore) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.07), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Revert this file to its pre-run state")
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                } else if let stat {
                    // "+12 −3" — git-style change magnitude at a glance.
                    HStack(spacing: 4) {
                        if stat.added > 0 {
                            Text("+\(stat.added)").foregroundStyle(DS.Palette.successSoft.opacity(0.85))
                        }
                        if stat.removed > 0 {
                            Text("−\(stat.removed)").foregroundStyle(DS.Palette.danger.opacity(0.8))
                        }
                    }
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(isSelected ? Color.white.opacity(0.06) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show this file's diff")
        .onHover { hovering = $0 }
        .animation(DS.Motion.press, value: hovering)
    }
}

struct CodeView: View {
    @StateObject private var ws = CodeWorkspace()
    @ObservedObject private var app = AppState.shared
    @ObservedObject private var progress = MissionProgress.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var approval = CommandApprovalCenter.shared
    @State private var dismissedCloudHint = false   // per-session dismiss of the no-cloud-key banner

    @State private var messages: [ChatMessage] = []
    /// Conversation persistence — the chat tab survives relaunches but Code-tab
    /// messages were pure @State and vanished on every quit (and the QA loop
    /// relaunches the app all day). Last 100 turns round-trip via JSONFileStore.
    /// (The store is built inside each off-main task — it's a cheap value and
    /// JSONFileStore isn't Sendable, so a shared static can't cross actors.)
    nonisolated private static let historyFile = "code_history.json"
    @State private var historyLoaded = false
    @State private var saveDebounce: Task<Void, Never>?
    @State private var input = ""
    @State private var isRunning = false
    @State private var rightPane: RightPane = .file
    @State private var runningTask: Task<Void, Never>?
    @State private var attachedFile: URL?
    @State private var attachedText: String = ""
    @State private var isDropTargeted = false   // drag-a-file-onto-input highlight
    @State private var showWarmupHint = false   // "warming up the local model…" after 5s of silence
    /// Design-language motion: one sprung curve for every Code-tab transition
    /// (cubic-bezier(0.32, 0.72, 0, 1) — heavy start, soft landing). Replaces the
    /// scattered `easeOut` micro-durations so all motion shares one physical feel.
    static let lux = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.4)
    /// Welcome entrance: pre-revealed on QA launches (offscreen renders never fire
    /// onAppear, so the capture would otherwise photograph an invisible welcome).
    @State private var welcomeAppeared = ProcessInfo.processInfo.arguments.contains("--qa")
    @State private var welcomeContentAppeared = ProcessInfo.processInfo.arguments.contains("--qa")
    // Find-in-conversation (⌥⌘F; ⌘F stays find-in-FILE). Jump-based search over
    // the message history with a subtle wash on the current match.
    @State private var convoSearching = false
    @State private var convoQuery = ""
    @State private var convoMatchIndex = 0
    @FocusState private var convoSearchFocused: Bool

    /// % of the local model's history window this conversation occupies (chars vs
    /// `AgentPipeline.localHistoryCharBudget` — the same budget the trim uses, so
    /// the meter and the trimming can never disagree).
    private var contextPct: Int {
        let chars = messages.reduce(0) { $0 + $1.text.count + 16 }
        return Int((Double(chars) / Double(AgentPipeline.localHistoryCharBudget) * 100).rounded())
    }

    private var convoMatches: [UUID] {
        let q = convoQuery.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        return messages.filter { $0.text.localizedCaseInsensitiveContains(q) }.map(\.id)
    }
    private var currentConvoMatch: UUID? {
        guard convoSearching, !convoMatches.isEmpty else { return nil }
        return convoMatches[min(convoMatchIndex, convoMatches.count - 1)]
    }
    @State private var localServingModel: String?  // which local model serves .salehman (no-cloud case)
    @State private var lastTokPerSec: Double?       // speed of the last local reply (display only)
    @State private var hoveredFile: URL?            // file-tree row under the pointer
    @State private var hoveredSlash: String?        // `/`-menu row under the pointer
    @State private var atBottom = true              // chat scrolled to the end (hides the jump button)
    // Inspector (File/Diff pane) collapse — persisted so it stays out of the way
    // across launches. Auto-expands when a file is selected or a run leaves diffs.
    @AppStorage("code_inspectorCollapsed") private var inspectorCollapsed = false
    @AppStorage("code_treeCollapsed") private var treeCollapsed = false
    // The right sidebar: Activity (what Salehman is doing) on top + Files & Diffs at
    // the bottom. Closable to a slim strip; auto-opens when a file/diff appears.
    @AppStorage("code_rightPanelCollapsed") private var rightPanelCollapsed = false
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
                CloudKeyHintBanner(onAddKey: { app.showSettingsRequested = true },
                                   onDismiss: { dismissedCloudHint = true })
            }
            HSplitView {
                if !treeCollapsed {
                    fileTree
                        .frame(minWidth: 200, idealWidth: 240, maxWidth: 360)
                } else {
                    treeReopenStrip
                }

                chatPane
                    .frame(minWidth: 420)

                // Right sidebar — Activity (live agent steps) on top, the Files & Diffs
                // inspector at the bottom. Closable to a slim strip; auto-opens when a
                // file is selected or a run produces diffs.
                if !rightPanelCollapsed {
                    rightPanel
                        .frame(minWidth: 280, idealWidth: 360, maxWidth: 480)
                } else {
                    rightReopenStrip
                }
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
        // Restore the last session's conversation once (off-main decode; tiny file).
        .onAppear {
            guard !historyLoaded else { return }
            historyLoaded = true
            Task.detached(priority: .utility) {
                let saved = Self.sanitizedHistory(
                    JSONFileStore<[ChatMessage]>(filename: Self.historyFile).load(defaultValue: []))
                if !saved.isEmpty {
                    await MainActor.run { if messages.isEmpty { messages = saved } }
                }
            }
        }
        // Persist on every change, debounced — a streaming run appends in bursts;
        // one write ~0.8s after the last mutation is plenty.
        .onChange(of: messages) { _, snapshot in
            guard historyLoaded else { return }
            saveDebounce?.cancel()
            let tail = Array(snapshot.suffix(100))
            saveDebounce = Task.detached(priority: .utility) {
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                try? JSONFileStore<[ChatMessage]>(filename: Self.historyFile).save(tail)
            }
        }
        // Expand the tree to reveal whatever file becomes selected (diff-jump, AI edit…),
        // and pop the right panel open so the file/diff is actually visible.
        .onChange(of: ws.selectedFile) { _, sel in
            revealInTree(sel)
            if sel != nil { withAnimation(CodeView.lux) { rightPanelCollapsed = false } }
        }
        // A run that produces diffs auto-opens the panel too (so changes aren't hidden).
        .onChange(of: ws.changedFiles) { _, files in
            if !files.isEmpty { withAnimation(CodeView.lux) { rightPanelCollapsed = false } }
        }
        // Edge-triggers from BottomShortcutBar hints (same actions as the local shortcuts).
        .onChange(of: app.reviewProjectRequested) { _, req in
            guard req else { return }
            app.reviewProjectRequested = false
            reviewProject()
        }
        .onChange(of: app.toggleCodeFindRequested) { _, req in
            guard req else { return }
            app.toggleCodeFindRequested = false
            if ws.selectedFile != nil { rightPane = .file; findFocused = true }
        }
        .onChange(of: app.focusCodeInputRequested) { _, req in
            guard req else { return }
            app.focusCodeInputRequested = false
            inputFocused = true
        }
        .onChange(of: app.toggleCodeTreeRequested) { _, req in
            guard req else { return }
            app.toggleCodeTreeRequested = false
            withAnimation(CodeView.lux) { treeCollapsed.toggle() }
        }
        // Hidden keyboard shortcuts: ⌘F focuses find-in-file, ⌘. stops a run.
        .background {
            Group {
                Button("") { if ws.selectedFile != nil { rightPane = .file; findFocused = true } }
                    .keyboardShortcut("f", modifiers: .command)
                Button("") { if isRunning { stop() } }
                    .keyboardShortcut(".", modifiers: .command)
                Button("") { inputFocused = true }
                    .keyboardShortcut("l", modifiers: .command)
                Button("") { withAnimation(CodeView.lux) { treeCollapsed.toggle() } }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("") { withAnimation(CodeView.lux) { rightPanelCollapsed.toggle() } }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Button("") {
                    withAnimation(CodeView.lux) { convoSearching = true }
                    convoSearchFocused = true
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
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
                // Click = open panel; the chevron lists recent projects (one-click switch).
                Menu {
                    ForEach(ws.recentProjects.filter { $0 != ws.projectRoot }, id: \.self) { url in
                        Button { ws.openProject(at: url) } label: {
                            Label(url.lastPathComponent, systemImage: "clock.arrow.circlepath")
                        }
                        .help(url.path)
                    }
                    if ws.recentProjects.count > 1 { Divider() }
                    Button { ws.openFolder() } label: {
                        Label("Open Folder…", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                } primaryAction: {
                    ws.openFolder()
                }
                .menuStyle(.button).buttonStyle(.plain).fixedSize()
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
                    .buttonStyle(LuxPressStyle()).foregroundStyle(DS.Palette.accent)
                    .help("Pack the open folder and have Salehman review it — bugs, risks, improvements (⌘R)")
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(isRunning)
                    Button { Task { await ws.reload() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .help("Rescan project files")
                        .accessibilityLabel("Rescan project files")
                    Button { withAnimation(CodeView.lux) { treeCollapsed = true } } label: {
                        Image(systemName: "sidebar.left").font(.system(size: 11))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Hide the file tree")
                    .accessibilityLabel("Hide the file tree")
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
                            .contentTransition(.numericText())
                            .animation(DS.Motion.smooth, value: ws.files.count)
                    }
                }
                .padding(.horizontal, 10).padding(.bottom, 6)
            }

            Divider().overlay(DS.Palette.hairline)

            if ws.files.isEmpty {
                emptyTreeHint
            } else {
                fileFilterField
                Group {
                if !fileFilter.isEmpty {
                    // Filtering → flat matched list (faster to scan than a tree).
                    let shown = filteredFiles
                    if shown.isEmpty {
                        Text("No files match \u{201C}\(fileFilter)\u{201D}")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                            .transition(.opacity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(shown, id: \.self) { url in
                                    fileRow(url)
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }
                            .animation(DS.Motion.smooth, value: shown.count)
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
                                    rightPanelCollapsed = false
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .transition(.opacity)
                }
                }
                .animation(DS.Motion.smooth, value: fileFilter.isEmpty)
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
                .onKeyPress(.escape) { fileFilter = ""; return .handled }
            if !fileFilter.isEmpty {
                Button { fileFilter = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel("Clear file filter")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 8).padding(.vertical, 6)
        .animation(DS.Motion.magnetic, value: fileFilter.isEmpty)
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
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(DS.Palette.accent.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(DS.Palette.accent.opacity(0.38), lineWidth: 1))
            }
            .buttonStyle(LuxPressStyle()).foregroundStyle(DS.Palette.accent)
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
            rightPanelCollapsed = false   // user asked to see a file — bring the panel back
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
                    // Accent dot: the AI changed this file THIS run.
                    Circle().fill(DS.Palette.accent).frame(width: 6, height: 6)
                } else if ws.gitModified.contains(url) {
                    // Amber dot: uncommitted in git (modified/untracked).
                    Circle().fill(DS.Palette.warningSoft.opacity(0.75)).frame(width: 5, height: 5)
                        .help("Uncommitted changes (git)")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(isSel ? Color.white.opacity(0.10)
                        : (hoveredFile == url ? Color.white.opacity(0.05) : .clear),
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSel ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onHover { inside in
                withAnimation(DS.Motion.magnetic) {
                    hoveredFile = inside ? url : (hoveredFile == url ? nil : hoveredFile)
                }
            }
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
                            withAnimation(CodeView.lux) { treeCollapsed = false }
                        }
                    }
                    // Context meter — the local 14B sees only ~9k chars of history;
                    // beyond that the OLDEST turns silently drop. Surfacing it
                    // answers "why did it forget" before the question is asked.
                    if contextPct >= 50 {
                        Text("ctx \(min(contextPct, 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(contextPct >= 90 ? DS.Palette.warningSoft : .secondary.opacity(0.8))
                            .padding(.horizontal, 7).padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.05), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                            .help(contextPct >= 100
                                  ? "The local model's context window is full — oldest turns are being trimmed. /clear starts fresh."
                                  : "How much of the local model's history window this conversation uses.")
                    }
                    if let tps = lastTokPerSec {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill").font(.system(size: 8))
                            Text(String(format: "%.0f tok/s", tps)).font(.system(size: 10, weight: .medium))
                                .contentTransition(.numericText())
                                .animation(DS.Motion.smooth, value: tps)
                        }
                        .padding(.horizontal, 7).padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.05), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .help("Speed of the last local reply")
                    }
                    Spacer()
                    headerIcon("square.and.pencil", "New chat") {
                        if !isRunning { withAnimation(DS.Motion.smooth) { messages.removeAll() } }
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
              VStack(spacing: 0) {
                if convoSearching { convoSearchBar(proxy) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if messages.isEmpty && !isRunning {
                            welcome
                                // Heavy fade-up entrance (one-shot). Pre-revealed on
                                // QA launches: onAppear never fires in offscreen
                                // hosted renders, so captures would photograph an
                                // invisible welcome without the --qa short-circuit.
                                .opacity(welcomeAppeared ? 1 : 0)
                                .offset(y: welcomeAppeared ? 0 : 16)
                                .onAppear {
                                    guard !welcomeAppeared else { return }
                                    withAnimation(Self.lux.delay(0.05)) { welcomeAppeared = true }
                                    withAnimation(Self.lux.delay(0.22)) { welcomeContentAppeared = true }
                                }
                        }
                        ForEach(Array(messages.enumerated()), id: \.element.id) { i, msg in
                            if i > 0, msg.timestamp.timeIntervalSince(messages[i-1].timestamp) > 900 {
                                Text(msg.timestamp, style: .time)
                                    .font(.system(size: 10)).foregroundStyle(.secondary.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 2)
                            }
                            codeBubble(msg)
                                .background(currentConvoMatch == msg.id
                                            ? DS.Palette.accent.opacity(0.08) : .clear,
                                            in: RoundedRectangle(cornerRadius: 10))
                                .id(msg.id)
                                .transition(.opacity.combined(with: .offset(y: 8)))
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
                    .animation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.15), value: messages.count)
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
            }

            // Same centered 780 reading column as the messages — so the composer lines
            // up under the conversation instead of stretching full-width (which read as
            // "off-centre" on a wide window).
            inputBar
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
        }
        .background(Color.clear)
    }

    /// Replies recorded BEFORE `stripNarration` existed still carry the fine-tune's
    /// leaked scaffold ("Thoughts on this response?", fake footnotes…). Applied to
    /// assistant turns whenever history loads, so old garbage doesn't resurface —
    /// the next save then persists the cleaned text. Pure + testable.
    nonisolated static func sanitizedHistory(_ saved: [ChatMessage]) -> [ChatMessage] {
        saved.map { m in
            guard !m.isUser else { return m }
            let clean = AgentPipeline.stripNarration(m.text)
            guard clean != m.text else { return m }
            return ChatMessage(id: m.id, text: clean, isUser: false,
                               timestamp: m.timestamp, imagePath: m.imagePath,
                               duration: m.duration)
        }
    }

    /// The find-in-conversation strip (⌥⌘F): query, live "n/total", ↑↓ jumps, Esc/✕ closes.
    private func convoSearchBar(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
            TextField("Find in conversation…", text: $convoQuery)
                .textFieldStyle(.plain).font(.system(size: 12.5))
                .focused($convoSearchFocused)
                .onSubmit { jumpToMatch(convoMatchIndex + 1, proxy) }
                .onKeyPress(.escape) { closeConvoSearch(); return .handled }
            if !convoMatches.isEmpty {
                Text("\(min(convoMatchIndex, convoMatches.count - 1) + 1)/\(convoMatches.count)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: convoMatchIndex)
            } else if convoQuery.count >= 2 {
                Text("0 results").font(.system(size: 10.5)).foregroundStyle(.secondary.opacity(0.7))
                    .transition(.opacity)
            }
            Button { jumpToMatch(convoMatchIndex - 1, proxy) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.plain).foregroundStyle(.secondary).disabled(convoMatches.isEmpty)
                .accessibilityLabel("Previous match")
            Button { jumpToMatch(convoMatchIndex + 1, proxy) } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.plain).foregroundStyle(.secondary).disabled(convoMatches.isEmpty)
                .accessibilityLabel("Next match")
            Button { closeConvoSearch() } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel("Close search")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(DS.Palette.codeSurfaceSide)
        // Top-bevel hairline: the find strip is a fixed tool surface, not chat.
        .overlay(alignment: .top) {
            LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) { Divider().overlay(DS.Palette.hairline.opacity(0.4)) }
        .onChange(of: convoQuery) { _, _ in
            convoMatchIndex = 0
            if let first = convoMatches.first { withAnimation { proxy.scrollTo(first, anchor: .center) } }
        }
    }

    private func jumpToMatch(_ index: Int, _ proxy: ScrollViewProxy) {
        guard !convoMatches.isEmpty else { return }
        let n = convoMatches.count
        convoMatchIndex = ((index % n) + n) % n   // wrap both directions
        withAnimation { proxy.scrollTo(convoMatches[convoMatchIndex], anchor: .center) }
    }

    private func closeConvoSearch() {
        withAnimation(CodeView.lux) { convoSearching = false }
        convoQuery = ""; convoMatchIndex = 0
        inputFocused = true
    }

    // MARK: - Slash commands (type `/` in the composer)
    // (internal, not private: the QA gallery photographs the menu with this list)
    static let slashCommands: [SlashCommand] = [
        .init(id: "explain",  icon: "text.magnifyingglass", blurb: "Explain how it works",   kind: .template("Explain how this works, step by step:\n\n")),
        .init(id: "fix",      icon: "ladybug",              blurb: "Find and fix a bug",      kind: .template("Find and fix the bug in this:\n\n")),
        .init(id: "tests",    icon: "checkmark.diamond",    blurb: "Write unit tests",        kind: .template("Write thorough unit tests for this:\n\n")),
        .init(id: "refactor", icon: "wand.and.stars",       blurb: "Refactor for clarity",    kind: .template("Refactor this for clarity and simplicity, keeping behaviour identical:\n\n")),
        .init(id: "review",   icon: "magnifyingglass",      blurb: "Review for issues",       kind: .template("Review this for bugs, edge cases, and improvements:\n\n")),
        .init(id: "docs",     icon: "doc.text",             blurb: "Add documentation",       kind: .template("Write clear doc comments for this:\n\n")),
        .init(id: "shot",     icon: "camera.viewfinder",    blurb: "Attach your latest screenshot (on-device OCR)", kind: .action("shot")),
        .init(id: "clear",    icon: "square.and.pencil",    blurb: "Start a new chat",        kind: .action("clear")),
        .init(id: "copy",     icon: "doc.on.doc",           blurb: "Copy chat as Markdown",   kind: .action("copy")),
    ]
    /// The `/` menu shows only while the FIRST token is being typed (a leading `/`,
    /// no space/newline yet) — so "/tests write…" or normal text never triggers it.
    private var slashActive: Bool {
        input.hasPrefix("/") && !input.contains(" ") && !input.contains("\n")
    }
    private var slashMatches: [SlashCommand] {
        guard slashActive else { return [] }
        let q = input.dropFirst().lowercased()
        return Self.slashCommands.filter { q.isEmpty || $0.id.hasPrefix(q) }
    }
    private func applySlash(_ cmd: SlashCommand) {
        switch cmd.kind {
        case .template(let t):
            input = t
            inputFocused = true
        case .action(let a):
            input = ""
            switch a {
            case "shot": attachLatestScreenshot()
            case "clear": if !isRunning { withAnimation(DS.Motion.smooth) { messages.removeAll() } }
            case "copy":
                let md = messages
                    .map { "**\($0.isUser ? "You" : "Salehman")**\n\n\($0.text)" }
                    .joined(separator: "\n\n---\n\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(md, forType: .string)
            default: break
            }
        }
    }

    /// Tappable starter prompts (icon + text) shown on the empty Code conversation.
    private let welcomeExamples: [(icon: String, text: String)] = [
        ("sparkles", "Review this project"),
        ("ladybug", "Find & fix a bug"),
        ("doc.text.magnifyingglass", "Explain a file"),
    ]

    private var welcome: some View {
        VStack(spacing: 16) {
            // Eyebrow tag (design-language): microscopic tracked caps above the hero.
            Text("PAIR PROGRAMMER")
                .font(.system(size: 9, weight: .semibold)).tracking(2.2)
                .foregroundStyle(.secondary.opacity(0.85))
                .padding(.horizontal, 10).padding(.vertical, 3.5)
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DS.Palette.accent)
                .frame(width: 68, height: 68)
                .background(
                    RadialGradient(colors: [DS.Palette.accent.opacity(0.24), DS.Palette.accent.opacity(0.07)],
                                   center: .center, startRadius: 0, endRadius: 34),
                    in: Circle())
                .overlay(Circle().stroke(
                    LinearGradient(colors: [DS.Palette.accent.opacity(0.55), DS.Palette.accent.opacity(0.10)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1))
                .shadow(color: DS.Palette.accent.opacity(0.38), radius: 28, y: 4)
                .shadow(color: DS.Palette.accent.opacity(0.18), radius: 6, y: 1)
            Text("What are we building, Saleh?")
                .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("Open a project, then ask me to build, fix, or explain. I run commands and edit files — you approve each one — and the diffs show up here.")
                .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(welcomeExamples, id: \.text) { ex in
                    // Island architecture: the icon never sits naked next to the
                    // text — it's seated in its own circular wrapper, flush with
                    // the capsule's leading padding. Press = physical compression.
                    Button { input = ex.text } label: {
                        HStack(spacing: 7) {
                            Image(systemName: ex.icon).font(.system(size: 10))
                                .foregroundStyle(DS.Palette.accent)
                                .frame(width: 22, height: 22)
                                .background(DS.Palette.accent.opacity(0.14), in: Circle())
                                .overlay(Circle().stroke(DS.Palette.accent.opacity(0.24), lineWidth: 1))
                            Text(ex.text).font(.system(size: 12, weight: .medium))
                        }
                        .padding(.leading, 5).padding(.trailing, 14).padding(.vertical, 6)
                        .background(Color.white.opacity(0.07), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(LuxPressStyle())
                    .foregroundStyle(Color.white.opacity(0.88))
                }
            }
            .padding(.top, 6)
            .opacity(welcomeContentAppeared ? 1 : 0)
            .offset(y: welcomeContentAppeared ? 0 : 10)
            HStack(spacing: 16) {
                shortcutHint("⌘O", "Open")
                shortcutHint("⌘R", "Review")
                shortcutHint("⌘L", "Ask")
                shortcutHint("/", "Commands")
            }
            .padding(.top, 10)
            .opacity(welcomeContentAppeared ? 1 : 0)
            .offset(y: welcomeContentAppeared ? 0 : 8)

            // Recent projects — one click back into anything you worked on lately
            // (the tree may be collapsed, so the welcome carries its own way in).
            let recents = ws.recentProjects.filter { $0 != ws.projectRoot }.prefix(3)
            if !recents.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10)).foregroundStyle(.secondary.opacity(0.7))
                    ForEach(Array(recents), id: \.self) { url in
                        Button { ws.openProject(at: url) } label: {
                            Text(url.lastPathComponent)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.white.opacity(0.05), in: Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .help(url.path)
                    }
                }
                .padding(.top, 10)
            }
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
        // Fill the scroll viewport and center — the hero used to ride high
        // over a large void (QA renders). containerRelativeFrame sizes the
        // empty state to the visible area, like the main chat's welcome.
        .containerRelativeFrame(.vertical, alignment: .center)
        .background {
            RadialGradient(colors: [DS.Palette.accent.opacity(0.05), .clear],
                           center: .init(x: 0.5, y: 0.32),
                           startRadius: 0, endRadius: 280)
                .allowsHitTesting(false)
        }
    }

    /// A small keyboard-shortcut chip (key + label) for the welcome footer.
    @ViewBuilder
    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary.opacity(0.82))
        }
    }

    private var agentSteps: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress header — "Working · done/total" (the Background-tasks feel).
            HStack(spacing: 6) {
                PulsingDot().scaleEffect(0.75)
                Text("Working").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.white.opacity(0.92))
                Spacer().frame(maxWidth: 0)
                Text("\(progress.steps.filter { $0.status == .done }.count)/\(progress.steps.count)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: progress.steps.filter { $0.status == .done }.count)
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
                        .background(step.status == .running ? DS.Palette.accent.opacity(0.12) : Color.white.opacity(0.05), in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                step.status == .running ? DS.Palette.accent.opacity(0.42) : Color.clear,
                                lineWidth: 1
                            )
                        )
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
        ActivityStepRow.icon(status)
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
                HStack(spacing: 7) {
                    // Screenshots show a real thumbnail in a machined micro-tile;
                    // other files keep the paperclip.
                    if ["png", "jpg", "jpeg", "heic"].contains(att.pathExtension.lowercased()),
                       let thumb = NSImage(contentsOf: att) {
                        Image(nsImage: thumb)
                            .resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 26, height: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1))
                    } else {
                        Image(systemName: "paperclip").font(.system(size: 10))
                    }
                    Text(att.lastPathComponent).font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                    if attachedText.hasPrefix("[Text recognized") {
                        Text("OCR").font(.system(size: 8, weight: .bold)).tracking(0.8)
                            .foregroundStyle(DS.Palette.accent)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .overlay(Capsule().stroke(DS.Palette.accent.opacity(0.35), lineWidth: 1))
                    }
                    Button { attachedFile = nil; attachedText = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .frame(width: 16, height: 16)
                            .background(Color.white.opacity(0.08), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(LuxPressStyle())
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            // Slash-command menu — appears above the composer while typing `/…`.
            // `↵` picks the top row; clicking a row runs it. Templates pre-fill the
            // input; actions (clear/copy) run immediately.
            if !slashMatches.isEmpty {
                SlashMenuView(matches: slashMatches, hovered: $hoveredSlash, onPick: applySlash)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            VStack(spacing: 9) {
                // Text first — full width, comfortable, nothing competing with it.
                TextField("Ask Salehman to build, fix, or explain…   ( / for commands )", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .lineLimit(1...6)
                    .focused($inputFocused)
                    // Enter picks the top `/`-command when the menu is open; otherwise sends.
                    .onSubmit { if let top = slashMatches.first { applySlash(top) } else { send() } }
                    // Esc dismisses the `/` menu (clears the half-typed trigger).
                    .onKeyPress(.escape) {
                        guard slashActive else { return .ignored }
                        input = ""
                        return .handled
                    }
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
                    Button { attachLatestScreenshot() } label: {
                        Image(systemName: "camera.viewfinder").font(.system(size: 13))
                    }
                    .buttonStyle(LuxPressStyle()).foregroundStyle(.secondary)
                    .help("Attach your latest screenshot — its text is read on-device (OCR) so the model can use it")
                    .accessibilityLabel("Attach your latest screenshot")
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
                            .contentTransition(.symbolEffect(.replace))
                            .animation(DS.Motion.smooth, value: isRunning)
                            .frame(width: 27, height: 27)
                            .background(
                                isRunning ? AnyShapeStyle(DS.Palette.accent.opacity(0.85))
                                    : (input.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? AnyShapeStyle(Color.white.opacity(0.10))
                                        : AnyShapeStyle(DS.Palette.accent)),
                                in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(LuxPressStyle())
                    .disabled(!isRunning && input.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel(isRunning ? "Stop generating" : "Send")
                }
            }
            .padding(.horizontal, 13).padding(.top, 11).padding(.bottom, 9)
            // DOUBLE-BEZEL composer (design-language pass): an inner core with its
            // own surface + machined top-bevel highlight, seated in an outer tray.
            // Concentric radii (18 outer − 4 padding = 14 inner) read as hardware.
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .padding(4)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            // The signature red ring (owner request — matches the main chat's input):
            // always visible, warms while typing, full-strength on file drop. Now on
            // the OUTER shell so the bezel sits inside it.
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(
                isDropTargeted ? DS.Palette.accent
                    : DS.Palette.accent.opacity(
                        input.trimmingCharacters(in: .whitespaces).isEmpty ? 0.38 : 0.60),
                lineWidth: isDropTargeted ? 1.5 : 1))
            .shadow(color: DS.Palette.accent.opacity(inputFocused ? 0.18 : 0), radius: 12, y: 2)
            .animation(Self.lux, value: input.isEmpty)
            .animation(Self.lux, value: isDropTargeted)
            .animation(Self.lux, value: inputFocused)
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
        // Flat — the last translucent bar in the app (design language; every
        // other surface went opaque in the restyle).
        .background(DS.Palette.codeSurface)
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
                // EXPLICIT child styles: the QA render proved Menu-level tint
                // quiets Image-only labels but NOT label text — explicit styles
                // on the children are what actually win (same mechanism that
                // keeps `· salehman14b` accent below).
                Image(systemName: "slider.horizontal.3").font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.55))
                Text(settings.brainPreference.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
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
        // Tint-leak fix (QA renders): the global app accent paints Menu labels
        // straight through foregroundStyle — quiet local tint instead. The
        // deliberate `· salehman14b` accent child keeps its EXPLICIT style;
        // AppKit popups ignore SwiftUI tint, so the menu items are unaffected.
        .tint(Color.white.opacity(0.55))
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
            Button { withAnimation(CodeView.lux) { treeCollapsed = false } } label: {
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

    // MARK: Right sidebar — Activity (top) + Files & Diffs (bottom), closable

    /// The whole right panel: a header with a close button, an Activity feed of the
    /// live agent steps, and the Files & Diffs inspector below it (resizable split).
    private var rightPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.horizontal.circle.fill").font(.system(size: 11))
                    .foregroundStyle(DS.Palette.accent.opacity(0.90))
                Text("ACTIVITY").font(.system(size: 9.5, weight: .semibold)).tracking(1.6)
                    .foregroundStyle(.secondary.opacity(0.85))
                if isRunning && !progress.steps.isEmpty {
                    Text("\(progress.steps.filter { $0.status == .done }.count)/\(progress.steps.count)")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(DS.Motion.smooth, value: progress.steps.filter { $0.status == .done }.count)
                }
                // Live elapsed readout — long local runs are minutes of silence
                // otherwise; a ticking clock shows the run is alive.
                if isRunning, let t0 = progress.startedAt {
                    TimelineView(.periodic(from: t0, by: 1)) { ctx in
                        HStack(spacing: 6) {
                            Text(elapsedLabel(since: t0, now: ctx.date))
                            // Live throughput estimate while the answer streams
                            // (chars/4 ≈ tokens; average since run start — honest,
                            // not a fake instantaneous number).
                            if !progress.streamingAnswer.isEmpty {
                                let secs = max(1, ctx.date.timeIntervalSince(t0))
                                Text(String(format: "≈%.0f tok/s",
                                            Double(progress.streamingAnswer.count) / 4 / secs))
                                    .contentTransition(.numericText())
                                    .animation(DS.Motion.smooth, value: progress.streamingAnswer.count)
                            }
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.85))
                    }
                }
                Spacer()
                Button { withAnimation(CodeView.lux) { rightPanelCollapsed = true } } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Close this panel").accessibilityLabel("Close the activity panel")
            }
            .padding(.horizontal, 10).frame(height: 34)
            Divider().overlay(DS.Palette.hairline.opacity(0.5))
            VSplitView {
                VStack(spacing: 0) {
                    activitySection.frame(minHeight: 90)
                    if !ws.changedFiles.isEmpty { changedFilesList }
                }
                inspectorPane.frame(minHeight: 150)
            }
        }
        .background(DS.Palette.codeSurfaceSide)
    }

    /// `/shot` and the camera button: grab the newest screenshot, OCR it
    /// off-main, and attach the recognized TEXT (the local model has no image
    /// input — its words are the useful part).
    private func attachLatestScreenshot() {
        guard let shot = ScreenshotGrabber.latestScreenshot(in: ScreenshotGrabber.screenshotsDirectory()) else {
            attachedFile = nil
            attachedText = ""
            input = ""
            withAnimation(Self.lux) {
                messages.append(ChatMessage(id: UUID(),
                    text: "No screenshots found in \(ScreenshotGrabber.screenshotsDirectory().path).",
                    isUser: false, timestamp: Date()))
            }
            return
        }
        attachedFile = shot
        attachedText = "(reading screenshot…)"
        Task.detached(priority: .userInitiated) {
            let text = ScreenshotGrabber.ocr(shot)
            await MainActor.run {
                guard attachedFile == shot else { return }   // user swapped attachments meanwhile
                attachedText = text.isEmpty
                    ? "[Screenshot \(shot.lastPathComponent) — no legible text found by OCR]"
                    : "[Text recognized on-device from screenshot \(shot.lastPathComponent)]\n\(text)"
                inputFocused = true
            }
        }
    }

    /// "12s" / "2m 05s" — the Activity header's run clock.
    private func elapsedLabel(since start: Date, now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(start)))
        return s < 60 ? "\(s)s" : String(format: "%dm %02ds", s / 60, s % 60)
    }

    /// Clickable list of the files the last run touched — one tap opens its diff.
    private var changedFilesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(DS.Palette.hairline.opacity(0.5))
            HStack(spacing: 6) {
                Circle().fill(DS.Palette.accent).frame(width: 5, height: 5)
                    .shadow(color: DS.Palette.accent.opacity(0.60), radius: 4)
                Text("CHANGED FILES").font(.system(size: 9.5, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(.secondary.opacity(0.85))
                Text("\(ws.changedFiles.count)")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.Palette.accent)
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: ws.changedFiles.count)
                Spacer()
                // The run-level safety net: one click reverts EVERY AI edit from
                // this run (your own edits in other files are untouched).
                Button { withAnimation(CodeView.lux) { ws.restoreAllChanged() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 8.5, weight: .semibold))
                        Text("Restore all").font(.system(size: 9.5, weight: .semibold))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Revert every file this run changed back to its pre-run state")
                .disabled(isRunning)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(ws.changedFiles, id: \.self) { url in
                        ChangedFileRow(label: relativePath(url),
                                       isSelected: ws.selectedFile == url,
                                       stat: ws.changeStats[url],
                                       onRestore: { withAnimation(CodeView.lux) { _ = ws.restoreFromSnapshot(url) } }) {
                            ws.select(url)
                            rightPane = .diff
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .animation(DS.Motion.smooth, value: ws.changedFiles.count)
                .padding(.horizontal, 5).padding(.bottom, 6)
            }
            .frame(maxHeight: 110)
        }
        .background(DS.Palette.codeSurfaceSide)
    }

    /// The Activity feed: live agent steps as cards while running, a friendly idle
    /// state otherwise. (Row + idle extracted into helpers so the type-checker can
    /// handle the body in reasonable time.)
    @ViewBuilder private var activitySection: some View {
        if isRunning && !progress.steps.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(progress.steps) {
                        activityStepRow($0)
                            .transition(.opacity.combined(with: .offset(y: 6)))
                    }
                }
                .animation(DS.Motion.smooth, value: progress.steps.count)
                .padding(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Palette.codeSurfaceSide)
        } else {
            activityIdle
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.Palette.codeSurfaceSide)
        }
    }

    private func activityStepRow(_ step: MissionProgress.Step) -> some View {
        ActivityStepRow(step: step)
    }

    @ViewBuilder private var activityIdle: some View {
        VStack(spacing: 10) {
            Image(systemName: isRunning ? "sparkles" : "bolt.horizontal.circle")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.secondary.opacity(0.42))
                .contentTransition(.symbolEffect(.replace))
                .animation(DS.Motion.smooth, value: isRunning)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.04), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            Text(isRunning ? "Working…" : "Ready")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.82))
            if !isRunning {
                Text("Send a message and\nagent steps appear here.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary.opacity(0.50))
                    .multilineTextAlignment(.center)
                    .lineSpacing(1.5)
                // Last local run's engine + measured speed — the "is my model
                // fast right now" answer lives where the run activity lives.
                if let stats = OllamaClient.lastStats {
                    HStack(spacing: 5) {
                        Circle().fill(DS.Palette.successSoft.opacity(0.65)).frame(width: 5, height: 5)
                        Text("\(stats.model)  \(String(format: "%.0f tok/s", stats.tps))")
                            .font(.system(size: 9.5, weight: .medium))
                            .contentTransition(.numericText())
                            .animation(DS.Motion.smooth, value: stats.tps)
                    }
                    .foregroundStyle(.secondary.opacity(0.62))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.white.opacity(0.04), in: Capsule())
                    .padding(.top, 4)
                }
            }
        }
        .padding(20)
    }

    /// Slim right-edge strip shown while the panel is closed — one click reopens it.
    private var rightReopenStrip: some View {
        VStack(spacing: 14) {
            Button { withAnimation(CodeView.lux) { rightPanelCollapsed = false } } label: {
                Image(systemName: "sidebar.right").font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(LuxPressStyle()).foregroundStyle(.secondary)
            .help("Show the activity / files panel").accessibilityLabel("Show the activity and files panel")
            if !ws.changedFiles.isEmpty {
                Button { withAnimation(CodeView.lux) { rightPanelCollapsed = false } } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 10.5))
                        .frame(width: 24, height: 22).contentShape(Rectangle())
                        .overlay(alignment: .topTrailing) {
                            Circle().fill(DS.Palette.accent).frame(width: 5, height: 5).offset(x: 1, y: -1)
                        }
                }
                .buttonStyle(.plain).foregroundStyle(DS.Palette.accent.opacity(0.85))
                .help("\(ws.changedFiles.count) changed file\(ws.changedFiles.count == 1 ? "" : "s")")
                .accessibilityLabel("\(ws.changedFiles.count) changed files")
            }
            Spacer()
        }
        .padding(.top, 10).frame(width: 26).frame(maxHeight: .infinity)
        .background(DS.Palette.codeSurfaceSide)
    }

    /// Slim bar shown while the inspector is collapsed — one click brings it back.
    private var inspectorReopenBar: some View {
        Button {
            withAnimation(CodeView.lux) { inspectorCollapsed = false }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up").font(.system(size: 9, weight: .semibold))
                Text("Files & Diffs").font(.system(size: 10.5, weight: .medium))
                if !ws.changedFiles.isEmpty {
                    Text("\(ws.changedFiles.count) changed")
                        .font(.system(size: 9.5, weight: .semibold)).foregroundStyle(DS.Palette.accent)
                        .contentTransition(.numericText())
                        .animation(DS.Motion.smooth, value: ws.changedFiles.count)
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
                            Circle().fill(DS.Palette.successSoft.opacity(0.8)).frame(width: 4, height: 4)
                            Text("+\(stats.added)").font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.Palette.successSoft)
                        }
                        HStack(spacing: 3) {
                            Circle().fill(DS.Palette.danger.opacity(0.8)).frame(width: 4, height: 4)
                            Text("-\(stats.removed)").font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.Palette.danger)
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
                            .contentTransition(.numericText())
                            .animation(DS.Motion.smooth, value: ws.changedFiles.count)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(DS.Palette.accent.opacity(0.12), in: Capsule())
                }
                Button {
                    withAnimation(CodeView.lux) { rightPanelCollapsed = true }
                } label: {
                    Image(systemName: "sidebar.right").font(.system(size: 10, weight: .semibold))
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Close the panel (it comes back when a run has diffs)")
                .accessibilityLabel("Close the activity and files panel")
            }
            .padding(10)
            Divider().overlay(DS.Palette.hairline)

            if ws.selectedFile == nil {
                VStack(spacing: 11) {
                    Text("FILES & DIFFS")
                        .font(.system(size: 8.5, weight: .semibold)).tracking(2.0)
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.48))
                        .frame(width: 54, height: 54)
                        .background(Color.white.opacity(0.04), in: Circle())
                        .overlay(Circle().stroke(
                            LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    Text("Select a file to view it,\nor run a task to see diffs.")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary.opacity(0.65))
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
                .onKeyPress(.escape) { clearSearch(); return .handled }
            if !fileSearch.isEmpty {
                Text(searchMatchLines.isEmpty ? "0/0" : "\(searchIndex + 1)/\(searchMatchLines.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: searchIndex)
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
    private func color(_ k: DiffLine.Kind) -> Color {
        k == .add ? Color(red: 0.35, green: 0.82, blue: 0.48) : (k == .remove ? Color(red: 1.0, green: 0.40, blue: 0.40) : .secondary)
    }
    private func bg(_ k: DiffLine.Kind) -> Color {
        switch k {
        case .add:    return Color(red: 0.35, green: 0.82, blue: 0.48).opacity(0.10)
        case .remove: return Color(red: 1.0, green: 0.40, blue: 0.40).opacity(0.11)
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
            // NO "You are Salehman in CODING mode…" preamble. The model already gets
            // the Salehman system prompt + its tools as specs; repeating the persona
            // inside the message made the fine-tune NARRATE its instructions back
            // ("How should Salehman respond?"). Just project context + the task.
            mission = "\(projectLine)\(text)\(attached)"
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
                if !ws.changedFiles.isEmpty { rightPane = .diff; rightPanelCollapsed = false }
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
    @State private var copied = false

    var body: some View {
        if msg.isUser {
            HStack {
                Spacer(minLength: 60)
                Text(msg.text)
                    .font(.system(size: 13.5))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color.white.opacity(0.11),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    // Machined tile: the same top-bevel hairline as the composer
                    // core, so user turns read as physical objects in the flow.
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.02)],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    )
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                MarkdownText(text: msg.text)
                Spacer(minLength: 26)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 64)   // room for the hover action pill
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 4) {
                    action(speech.speakingID == msg.id ? "speaker.wave.2.fill" : "speaker.wave.2",
                           "Read aloud", active: speech.speakingID == msg.id) {
                        speech.toggle(msg.text, id: msg.id)
                    }
                    action(copied ? "checkmark" : "doc.on.doc", "Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(msg.text, forType: .string)
                        copied = true
                        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
                    }
                    if let regen = onRegenerate {
                        action("arrow.clockwise", "Regenerate", regen)
                    }
                }
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(Color.white.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                .opacity(hovering ? 1 : 0)
                .animation(DS.Motion.fade, value: hovering)
            }
            // Make the ENTIRE row (text + the empty gap + the button area) a single
            // solid hover target. Without this, the transparent space between the
            // text and the top-right buttons isn't hit-testable, so moving the cursor
            // toward the buttons reads as "left the row" and they vanish before you
            // can click them.
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
        }
    }

    private func action(_ icon: String, _ help: String, active: Bool = false,
                        _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? DS.Palette.accent : Color.white.opacity(0.55))
                .frame(width: 22, height: 22).contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
                .animation(DS.Motion.smooth, value: icon)
        }
        .buttonStyle(LuxPressStyle())
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Small breathing accent dot shown while a reply streams in.
/// PhaseAnimator cycles 0.35↔1.0 opacity continuously — no @State needed.
struct PulsingDot: View {
    var body: some View {
        PhaseAnimator([0.35, 1.0]) { opacity in
            Circle().fill(DS.Palette.accent)
                .frame(width: 7, height: 7)
                .opacity(opacity)
        } animation: { opacity in
            opacity > 0.5
                ? .timingCurve(0.45, 0.0, 0.55, 1.0, duration: 0.75)
                : .timingCurve(0.45, 0.0, 0.55, 1.0, duration: 0.90)
        }
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
            sec("Markdown table — cells wrap, no mid-word clip (table-wrap fix)") {
                CodeMessageRow(msg: .init(id: UUID(), text: """
                | round | recipe | eval loss |
                |---|---|---|
                | r3 | r128 + app-missions | **1.3033** — shipped |
                | r5 | + round-5 data | 1.3446 |
                """, isUser: false, timestamp: now))
            }
            sec("Long user paste — right-block wrap / max-width measure") {
                CodeMessageRow(msg: .init(id: UUID(), text: "here's a long requirement i'm pasting to sanity-check that the right-aligned user block caps its width, wraps cleanly, and keeps its padding + corner radius instead of running edge to edge across a wide window", isUser: true, timestamp: now))
            }
            sec("Refusal — honest, no hedging") {
                CodeMessageRow(msg: .init(id: UUID(), text: "No — I can't promise bug-free code; that wouldn't be honest for anything non-trivial. What I *will* do: run the tests, read the diff, and tell you exactly what I verified.", isUser: false, timestamp: now))
            }
            sec("Slash-command menu — type / in the composer (↵ picks the top row)") {
                SlashMenuView(matches: CodeView.slashCommands,
                              hovered: .constant("fix"),
                              onPick: { _ in })
                    .frame(maxWidth: 520, alignment: .leading)
            }
            sec("Right panel — run in flight (Activity cards + changed files)") {
                VStack(alignment: .leading, spacing: 6) {
                    ActivityStepRow(step: .init(name: "Reasoning Strategist", icon: "brain.head.profile",
                                                status: .done, adapted: "Map the auth module's entry points"))
                    ActivityStepRow(step: .init(name: "Code Surgeon", icon: "scissors",
                                                status: .running, adapted: "Code Surgeon · tool round 3/8"))
                    ActivityStepRow(step: .init(name: "Verifier", icon: "checkmark.seal",
                                                status: .pending))
                    Divider().padding(.vertical, 4)
                    ChangedFileRow(label: "Sources/Auth/LoginFlow.swift", isSelected: true,
                                   stat: .init(added: 24, removed: 9), onTap: {})
                    ChangedFileRow(label: "Sources/Auth/TokenStore.swift", isSelected: false,
                                   stat: .init(added: 6, removed: 0), onTap: {})
                    ChangedFileRow(label: "Tests/AuthTests.swift", isSelected: false,
                                   stat: .init(added: 41, removed: 2), onTap: {})
                }
                .frame(maxWidth: 360, alignment: .leading)
                .padding(8)
                .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: 10))
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
