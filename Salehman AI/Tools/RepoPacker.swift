import Foundation

/// Repomix / Gitingest-style code→context packer. Walks a directory and produces
/// ONE dense, AI-friendly text digest — a file tree plus each text file's contents
/// in a fenced block — suitable for feeding a whole codebase to an LLM. Pure Swift,
/// no dependencies, fully on-device. The output mirrors the format of
/// `tools/bundle_source.sh` (the app's own `SOURCE_BUNDLE.md`), so it reads
/// familiarly to any brain that has seen this repo.
///
/// Stateless `enum` of `nonisolated static` helpers → callable from any actor (the
/// `pack_repository` tool runs it off the main actor so a big repo can't hitch UI).
enum RepoPacker {

    struct PackResult: Sendable {
        var digest: String        // the full packed text (already capped to maxTotalBytes)
        var rootName: String
        var fileCount: Int        // text files included
        var skippedCount: Int     // files skipped (binary / oversize / non-UTF8)
        var totalBytes: Int       // bytes of included file CONTENT
        var truncated: Bool       // true if the byte cap stopped us early
    }

    /// Directory names never worth packing (deps, build output, VCS, caches). Pruned
    /// at the directory level so we never even descend into `node_modules` etc.
    nonisolated static let skipDirs: Set<String> = [
        ".git", ".hg", ".svn", "node_modules", ".build", "build", "DerivedData",
        ".swiftpm", ".venv", "venv", "env", "__pycache__", ".next", "dist", "out",
        ".gradle", ".idea", ".vscode", "Pods", "Carthage", ".cache", "vendor",
        ".terraform", "target", ".mypy_cache", ".pytest_cache", "coverage", ".turbo",
        ".parcel-cache", "bin", "obj", ".dart_tool", ".expo", "__snapshots__",
    ]

    /// File extensions treated as packable text/code.
    nonisolated static let textExtensions: Set<String> = [
        "swift", "m", "mm", "h", "c", "cc", "cpp", "cxx", "hpp", "js", "jsx", "ts",
        "tsx", "mjs", "cjs", "py", "rb", "go", "rs", "java", "kt", "kts", "scala",
        "php", "cs", "sh", "bash", "zsh", "fish", "pl", "pm", "lua", "r", "jl",
        "dart", "ex", "exs", "erl", "clj", "cljs", "hs", "ml", "mli", "fs", "fsx",
        "vb", "groovy", "gradle", "html", "htm", "css", "scss", "sass", "less",
        "vue", "svelte", "astro", "json", "jsonc", "yaml", "yml", "toml", "ini",
        "cfg", "conf", "xml", "plist", "entitlements", "md", "markdown", "mdx",
        "txt", "rst", "adoc", "tex", "csv", "tsv", "sql", "graphql", "gql", "proto",
        "gitignore", "dockerignore", "editorconfig", "env", "properties", "cmake",
        "mk", "bat", "ps1",
    ]

    /// Extensionless files allowed by exact base name (READMEs, build files, …).
    nonisolated static let allowedNames: Set<String> = [
        "README", "LICENSE", "LICENCE", "Dockerfile", "Makefile", "Procfile",
        "Gemfile", "Rakefile", "Podfile", "Cartfile", "Brewfile", "CHANGELOG",
        "CONTRIBUTING", "NOTICE", "AUTHORS", "CODEOWNERS", "Vagrantfile",
    ]

    /// Whether a file should be packed — by extension, dotfile suffix, or base name.
    nonisolated static func isPackable(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") {            // dotfile: ".gitignore" → check "gitignore"
            return textExtensions.contains(String(name.dropFirst()).lowercased())
        }
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty { return textExtensions.contains(ext) }
        return allowedNames.contains(name)
    }

    /// Markdown fence language for a file (best-effort; "" = no language tag).
    nonisolated static func fenceLanguage(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "py": return "python"
        case "js", "jsx", "mjs", "cjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "c", "h": return "c"
        case "cc", "cpp", "cxx", "hpp": return "cpp"
        case "cs": return "csharp"
        case "sh", "bash", "zsh", "fish": return "bash"
        case "html", "htm": return "html"
        case "css": return "css"
        case "scss", "sass": return "scss"
        case "json", "jsonc": return "json"
        case "yaml", "yml": return "yaml"
        case "toml": return "toml"
        case "xml", "plist", "entitlements": return "xml"
        case "sql": return "sql"
        case "md", "markdown", "mdx": return "markdown"
        default: return ""
        }
    }

    /// Recursively collect files under `dir`, pruning `skipDirs`, carrying each file's
    /// path RELATIVE to the original root (accumulated during traversal). Sorted
    /// (case-insensitive) for deterministic output. We compute `rel` here rather than
    /// string-matching against the root path later — temp dirs under the
    /// /var→/private/var symlink made prefix-matching flaky (nested files lost their
    /// subdirectory). This is representation-independent.
    nonisolated static func collectFiles(_ dir: URL, relBase: String = "") -> [(url: URL, rel: String)] {
        let fm = FileManager.default
        var out: [(url: URL, rel: String)] = []
        guard let entries = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { return out }
        for entry in entries.sorted(by: {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }) {
            let childRel = relBase.isEmpty ? entry.lastPathComponent : relBase + "/" + entry.lastPathComponent
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                if skipDirs.contains(entry.lastPathComponent) { continue }
                out += collectFiles(entry, relBase: childRel)
            } else {
                out.append((entry, childRel))
            }
        }
        return out
    }

    /// Pack the directory at `rootPath` into one AI-friendly digest. `maxFileBytes`
    /// skips any single oversized file; `maxTotalBytes` caps the whole digest so it
    /// can't grow unbounded.
    nonisolated static func pack(rootPath: String,
                                 maxFileBytes: Int = 256 * 1024,
                                 maxTotalBytes: Int = 2 * 1024 * 1024) -> PackResult {
        let root = URL(fileURLWithPath: (rootPath as NSString).expandingTildeInPath,
                       isDirectory: true).standardizedFileURL
        let rootName = root.lastPathComponent
        let all = collectFiles(root)

        var included: [(rel: String, body: String, lang: String, lines: Int)] = []
        var skipped = 0
        var total = 0
        var truncated = false

        for (url, relPath) in all {
            guard isPackable(url) else { skipped += 1; continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if size > maxFileBytes { skipped += 1; continue }
            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else {  // binary / non-UTF8
                skipped += 1; continue
            }
            if total + data.count > maxTotalBytes { truncated = true; break }
            total += data.count
            let lines = text.reduce(0) { $0 + ($1 == "\n" ? 1 : 0) } + 1
            included.append((relPath, text, fenceLanguage(for: url), lines))
        }

        var out = "# 📦 Packed repository: \(rootName)\n"
        out += "_\(included.count) files · \(byteString(total))"
        if truncated { out += " · TRUNCATED at \(byteString(maxTotalBytes)) cap" }
        if skipped > 0 { out += " · \(skipped) skipped (binary/oversize/deps)" }
        out += " · packed by Salehman AI_\n\n"

        out += "## File tree\n```\n"
        out += included.map(\.rel).joined(separator: "\n")
        out += "\n```\n\n## Files\n\n"

        for f in included {
            out += "===== FILE: \(f.rel) (\(f.lines) lines) =====\n"
            out += "```\(f.lang)\n\(f.body)\n```\n\n"
        }
        if truncated {
            out += "_… digest truncated at the \(byteString(maxTotalBytes)) cap. Pack a subfolder or raise the cap to see the rest._\n"
        }

        return PackResult(digest: out, rootName: rootName, fileCount: included.count,
                          skippedCount: skipped, totalBytes: total, truncated: truncated)
    }

    /// Human-friendly byte size.
    nonisolated static func byteString(_ n: Int) -> String {
        if n >= 1_048_576 { return String(format: "%.1f MB", Double(n) / 1_048_576) }
        if n >= 1024 { return String(format: "%.0f KB", Double(n) / 1024) }
        return "\(n) B"
    }
}
