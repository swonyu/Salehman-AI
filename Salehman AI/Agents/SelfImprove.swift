import Foundation

/// Building blocks for the self-improvement patcher: compiler-error parsing,
/// minimal-patch application with timestamped backups, and project-scope safety
/// checks. (The build → fix → rebuild loop that drove these was the FM
/// `self_improve` tool, removed with the Apple-Intelligence tool layer on
/// 2026-06-08; the primitives are test-covered and kept for the next driver.)
///
/// Edits go straight to source files. Every modified file is copied to
/// ~/.salehman_ai_self_improve_backups/<timestamp>/ before being touched, so a
/// bad patch can be recovered by hand. Scope is locked to the project root —
/// the patcher refuses paths outside it.
enum SelfImprove {

    // MARK: - Project location

    /// Default location of THIS project. Overridable via UserDefaults so the
    /// same binary can point at a moved/renamed checkout without recompiling.
    // Repointed 2026-06-06 from ~/Downloads/SalehmanAI_Complete_Everything_Today
    // to the live ~/Desktop checkout (the old path was deleted in the repo move;
    // commit a9b99be repointed the zip/checkpoint tools but missed this one).
    // FRAGILE: this is a hardcoded, user-specific absolute path — it will dangle
    // again on the next move/rename (the exact failure a9b99be caused). The robust
    // mechanism is the `self_improve_project_root` UserDefaults override below;
    // treat this constant as a dev-only fallback, not the source of truth.
    nonisolated static let defaultRoot = "/Users/saleh/Desktop/Salehman AI"

    nonisolated static var projectRoot: String {
        UserDefaults.standard.string(forKey: "self_improve_project_root") ?? defaultRoot
    }

    nonisolated static var projectRootURL: URL { URL(fileURLWithPath: projectRoot) }

    // MARK: - Build

    nonisolated struct BuildError: Hashable {
        let file: String   // absolute path
        let line: Int
        let column: Int?
        let message: String
    }

    /// Matches the standard clang/Swift diagnostic format:
    ///   `/abs/path/File.swift:42:10: error: cannot find 'foo' in scope`
    /// Deduplicates by (file, line, message) so the same error reported by
    /// multiple build phases counts once.
    nonisolated static func parseErrors(_ output: String) -> [BuildError] {
        var seen = Set<BuildError>()
        var ordered: [BuildError] = []
        let pattern = #"^(/[^:\n]+\.(?:swift|m|mm|c|cpp|h)):(\d+):(?:(\d+):)?\s*error:\s*(.+)$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return [] }
        let ns = output as NSString
        re.enumerateMatches(in: output, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m else { return }
            let file = ns.substring(with: m.range(at: 1))
            let line = Int(ns.substring(with: m.range(at: 2))) ?? 0
            let colR = m.range(at: 3)
            let col: Int? = (colR.location != NSNotFound) ? Int(ns.substring(with: colR)) : nil
            let msg = ns.substring(with: m.range(at: 4))
            let err = BuildError(file: file, line: line, column: col, message: msg)
            if seen.insert(err).inserted { ordered.append(err) }
        }
        return ordered
    }

    // MARK: - Patch application

    /// Parses one `REPLACE_RANGE: a-b / WITH: ... / END` block and rewrites
    /// the file atomically. Returns true on success. Backs up first.
    nonisolated static func applyPatch(_ patch: String, to file: String) -> Bool {
        guard isInsideProject(file) else { return false }
        guard let original = try? String(contentsOfFile: file, encoding: .utf8) else { return false }
        var lines = original.components(separatedBy: "\n")

        guard let rangeMatch = patch.range(of: #"REPLACE_RANGE:\s*(\d+)\s*-\s*(\d+)"#,
                                           options: .regularExpression),
              let withRange = patch.range(of: "WITH:"),
              let endRange  = patch.range(of: "END", options: .backwards),
              withRange.upperBound <= endRange.lowerBound else {
            return false
        }

        // Pull the two integers out of "REPLACE_RANGE: a-b".
        let header = String(patch[rangeMatch])
        let nums = header.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard nums.count >= 2 else { return false }
        let start = nums[0], end = nums[1]
        guard start >= 1, end >= start, end <= lines.count else { return false }

        let replacementBody = String(patch[withRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: CharacterSet.newlines)
        let replacementLines = replacementBody.components(separatedBy: "\n")

        backup(file: file, contents: original)
        lines.replaceSubrange((start - 1)...(end - 1), with: replacementLines)
        let final = lines.joined(separator: "\n")
        do {
            try final.write(toFile: file, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Safety

    /// True only when `file` resolves to something inside the configured
    /// project root. Prevents a hallucinated path from rewriting unrelated
    /// files on disk.
    nonisolated static func isInsideProject(_ file: String) -> Bool {
        // `standardizedFileURL` only normalizes path *syntax* (`./`, `../`) — it
        // does NOT resolve symlinks. A symlink planted inside the project that
        // points outside (e.g. `project/evil -> /etc/passwd`) would otherwise
        // pass this prefix check and let a write escape the project root.
        // `resolvingSymlinksInPath()` canonicalizes THROUGH symlinks (on both
        // sides, so /tmp→/private/tmp-style aliases compare consistently), so
        // the check is against the real on-disk target.
        let resolved = URL(fileURLWithPath: file).resolvingSymlinksInPath().standardizedFileURL.path
        let root = projectRootURL.resolvingSymlinksInPath().standardizedFileURL.path
        return resolved == root || resolved.hasPrefix(root + "/")
    }

    private nonisolated static let backupTimestamp: String = {
        let f = DateFormatter()
        // Pin locale + calendar: on a Hijri-defaulting locale (e.g. en_SA) an
        // unpinned formatter named backup folders like `14471220-…` (year 1447 AH),
        // making the recovery copies mis-sorted and confusing. Force Gregorian +
        // POSIX so folders are chronological `yyyyMMdd-HHmmss` everywhere.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }()

    /// Test-only accessor for the frozen per-run backup timestamp, so a test can
    /// locate THIS run's backup folder and verify the preserved pre-edit copy.
    /// Returns the same value `backup()` uses (the private frozen `static let`),
    /// not a recomputed one — recomputing could cross a second boundary and miss.
    nonisolated static var backupTimestampForTesting: String { backupTimestamp }

    /// Root for per-run backup folders. Overridable via UserDefaults
    /// (`self_improve_backup_root`) so tests redirect to a temp dir instead of
    /// littering ~/.salehman_ai_self_improve_backups. Production uses the default.
    nonisolated static var backupRoot: URL {
        if let custom = UserDefaults.standard.string(forKey: "self_improve_backup_root") {
            return URL(fileURLWithPath: custom)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".salehman_ai_self_improve_backups")
    }

    /// Copies the pre-edit contents into a per-run timestamped folder. A single
    /// folder is reused for the whole loop so all edits from one invocation
    /// land together.
    nonisolated static func backup(file: String, contents: String) {
        let backupDir = backupRoot.appendingPathComponent(backupTimestamp)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let dest = backupDir.appendingPathComponent(URL(fileURLWithPath: file).lastPathComponent)
        // Never overwrite an existing backup: the FIRST copy is the true pre-edit
        // original. Patching the same file twice in one run previously clobbered
        // it (same timestamped folder + same filename), destroying the recovery
        // copy this function exists to preserve.
        guard !FileManager.default.fileExists(atPath: dest.path) else { return }
        try? contents.write(to: dest, atomically: true, encoding: .utf8)
    }
}
