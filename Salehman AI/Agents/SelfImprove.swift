import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Self-improvement loop: build the Xcode project, parse compiler errors, ask
/// the on-device model for a minimal patch per error, apply patches with a
/// timestamped backup, rebuild. Bails out if errors stop decreasing.
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
    static let defaultRoot = "/Users/saleh/Desktop/Salehman AI"
    static let projectFile = "Salehman AI.xcodeproj"
    static let scheme      = "Salehman AI"

    static var projectRoot: String {
        UserDefaults.standard.string(forKey: "self_improve_project_root") ?? defaultRoot
    }

    static var projectRootURL: URL { URL(fileURLWithPath: projectRoot) }

    // MARK: - Build

    struct BuildError: Hashable {
        let file: String   // absolute path
        let line: Int
        let column: Int?
        let message: String
    }

    struct BuildReport {
        let success: Bool
        let exitCode: Int32
        let errors: [BuildError]
        let logTail: String   // last ~80 lines of compiler output
    }

    /// Run `xcodebuild build`. Writes full output to a temp file so we get the
    /// whole compiler log, not the 8 KB Shell.run cap. `mode` toggles between
    /// `build` (fast) and `test` (full unit tests, much slower).
    static func runXcodebuild(mode: Mode = .build, timeoutSec: Int = 360) -> BuildReport {
        let logURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("salehman_self_improve_\(UUID().uuidString).log")
        let action = mode == .test ? "test" : "build"
        let cmd = """
        cd \(shellQuote(projectRoot)) && \
        xcodebuild -project \(shellQuote(projectFile)) -scheme \(shellQuote(scheme)) \
        -configuration Debug -destination 'platform=macOS' \(action) \
        > \(shellQuote(logURL.path)) 2>&1
        """
        let result = Shell.run(cmd, timeout: TimeInterval(timeoutSec))
        let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? result.output
        try? FileManager.default.removeItem(at: logURL)

        let errors = parseErrors(log)
        let ok = result.exitCode == 0 && errors.isEmpty
        return BuildReport(success: ok, exitCode: result.exitCode,
                           errors: errors, logTail: tail(log, lines: 80))
    }

    enum Mode { case build, test }

    /// Matches the standard clang/Swift diagnostic format:
    ///   `/abs/path/File.swift:42:10: error: cannot find 'foo' in scope`
    /// Deduplicates by (file, line, message) so the same error reported by
    /// multiple build phases counts once.
    static func parseErrors(_ output: String) -> [BuildError] {
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

    // MARK: - Fix loop

    /// Build → fix top N errors → rebuild, up to `maxIterations` rounds.
    /// Stops early on success, on no-progress, or if the model can't propose
    /// useful patches. Returns a Markdown report.
    static func selfImprove(mode: Mode = .build, maxIterations: Int = 3) async -> String {
        var report = "**Self-improve** on `\(projectRoot)`\n"
        report += "Mode: `\(mode == .test ? "build + test" : "build")` · Max iterations: \(maxIterations)\n\n"

        // Sanity-check the project actually exists where we expect.
        let projectURL = projectRootURL.appendingPathComponent(projectFile)
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            return report + "❌ Couldn't find \(projectFile) at \(projectRoot). " +
                   "Set `self_improve_project_root` in UserDefaults to the correct path."
        }

        var prevErrCount = Int.max
        var lastReport: BuildReport?

        for iter in 1...maxIterations {
            let build = runXcodebuild(mode: mode)
            lastReport = build
            report += "## Iteration \(iter)\n"
            if build.success {
                report += "✅ Build succeeded with no errors.\n"
                if mode == .test {
                    report += "All tests passed.\n"
                }
                return report
            }
            report += "Build failed (exit \(build.exitCode)) · \(build.errors.count) error(s).\n"

            if build.errors.isEmpty {
                report += "No structured errors parsed — likely a linker/codesign issue. Last log:\n```\n\(build.logTail)\n```\n"
                break
            }

            // No-progress check: if we couldn't reduce the error count from the
            // previous iteration, stop instead of burning more LLM calls.
            if iter > 1 && build.errors.count >= prevErrCount {
                report += "↪ Errors didn't decrease (\(prevErrCount) → \(build.errors.count)). Stopping.\n"
                break
            }
            prevErrCount = build.errors.count

            // Fix up to 5 errors per iteration to keep prompts bounded.
            let toFix = Array(build.errors.prefix(5))
            for err in toFix {
                let outcome = await tryFix(error: err)
                let fname = URL(fileURLWithPath: err.file).lastPathComponent
                report += "- `\(fname):\(err.line)` — \(err.message)\n  → \(outcome.label)\n"
            }
            report += "\n"
        }

        // Final summary
        report += "## Result\n"
        if let lastReport, lastReport.success {
            report += "✅ Green build.\n"
        } else if let lastReport {
            report += "⚠️ Still failing with \(lastReport.errors.count) error(s).\n"
            report += "Recent compiler output:\n```\n\(lastReport.logTail)\n```\n"
            report += "\nBackups of every edited file are in `~/.salehman_ai_self_improve_backups/`.\n"
        }
        return report
    }

    // MARK: - Per-error fix

    enum FixOutcome {
        case patched, noFix, parseFailed, refused

        var label: String {
            switch self {
            case .patched:     return "patched"
            case .noFix:       return "model declined"
            case .parseFailed: return "couldn't parse patch"
            case .refused:     return "refused (path outside project)"
            }
        }
    }

    /// Asks the on-device model for a minimal patch and applies it. Returns
    /// what happened without throwing — callers care about the outcome label.
    static func tryFix(error: BuildError) async -> FixOutcome {
        guard isInsideProject(error.file) else { return .refused }
        guard let raw = try? String(contentsOfFile: error.file, encoding: .utf8) else { return .parseFailed }

        let lines = raw.components(separatedBy: "\n")
        let centerIdx = max(0, min(lines.count - 1, error.line - 1))
        let lo = max(0, centerIdx - 25)
        let hi = min(lines.count - 1, centerIdx + 25)
        let snippet = (lo...hi).map { i in "\(i + 1): \(lines[i])" }.joined(separator: "\n")

        let prompt = """
        A Swift file failed to compile.

        Error at line \(error.line): \(error.message)

        Here are lines \(lo + 1)–\(hi + 1) of \(URL(fileURLWithPath: error.file).lastPathComponent):
        ```
        \(snippet)
        ```

        Reply with ONLY a minimal patch in EXACTLY this format — no prose, no \
        markdown fences, no commentary:

        REPLACE_RANGE: <start>-<end>
        WITH:
        <new line 1>
        <new line 2>
        END

        For a single-line edit, use the same range with start == end (e.g. \
        `REPLACE_RANGE: 42-42`). If you cannot safely fix this error, reply \
        with exactly: NO_FIX
        """

        let response = await LocalLLM.generate(prompt, maxTokens: 400)
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("NO_FIX") || trimmed.hasPrefix("[no on-device model") {
            return .noFix
        }
        return applyPatch(trimmed, to: error.file) ? .patched : .parseFailed
    }

    // MARK: - Patch application

    /// Parses one `REPLACE_RANGE: a-b / WITH: ... / END` block and rewrites
    /// the file atomically. Returns true on success. Backs up first.
    static func applyPatch(_ patch: String, to file: String) -> Bool {
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
    static func isInsideProject(_ file: String) -> Bool {
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

    private static let backupTimestamp: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }()

    /// Copies the pre-edit contents into a per-run timestamped folder. A single
    /// folder is reused for the whole loop so all edits from one invocation
    /// land together.
    static func backup(file: String, contents: String) {
        let backupDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".salehman_ai_self_improve_backups")
            .appendingPathComponent(backupTimestamp)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let dest = backupDir.appendingPathComponent(URL(fileURLWithPath: file).lastPathComponent)
        // Never overwrite an existing backup: the FIRST copy is the true pre-edit
        // original. Patching the same file twice in one run previously clobbered
        // it (same timestamped folder + same filename), destroying the recovery
        // copy this function exists to preserve.
        guard !FileManager.default.fileExists(atPath: dest.path) else { return }
        try? contents.write(to: dest, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private static func tail(_ s: String, lines n: Int) -> String {
        let parts = s.split(separator: "\n", omittingEmptySubsequences: false)
        return parts.suffix(n).joined(separator: "\n")
    }

    /// Wraps a path/scheme in single quotes for `/bin/zsh -c`. Embedded single
    /// quotes are turned into the standard `'\''` escape.
    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - Foundation Models tool

#if canImport(FoundationModels)
struct SelfImproveTool: Tool {
    let name = "self_improve"
    let description = """
    Build the Salehman AI Xcode project, find compiler errors, and try to fix \
    them automatically. Use this when the user asks you to "test yourself", \
    "build yourself", "fix yourself", "find bugs in yourself", or "make \
    yourself better". Returns a Markdown report of what was fixed and the final \
    build status. Backups of every edited file land in \
    ~/.salehman_ai_self_improve_backups/.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Maximum number of build → fix → rebuild iterations (1–5). Default 3.")
        var maxIterations: Int

        @Guide(description: "Set to true to also run the unit-test target (slower). Default false.")
        var includeTests: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        let iters = max(1, min(5, arguments.maxIterations == 0 ? 3 : arguments.maxIterations))
        let mode: SelfImprove.Mode = arguments.includeTests ? .test : .build
        return await SelfImprove.selfImprove(mode: mode, maxIterations: iters)
    }
}
#endif
