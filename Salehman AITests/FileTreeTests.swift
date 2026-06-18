import Testing
import Foundation
import SwiftUI
@testable import Salehman_AI

// MARK: - FileKind.icon(for:) — extension → symbol mapping
//
// A silent regression here (e.g., dropping a `case "swift":` or transposing
// extensions) makes the wrong SF Symbol appear in the Code-tab file tree
// without any build error. These tests pin the symbol string for every
// recognised extension family and verify the fallback.

struct FileKindIconTests {

    private func symbol(for ext: String) -> String {
        FileKind.icon(for: URL(fileURLWithPath: "file.\(ext)")).symbol
    }

    @Test func swiftFiles() {
        #expect(symbol(for: "swift") == "swift")
    }

    @Test func pythonFiles() {
        #expect(symbol(for: "py") == "chevron.left.forwardslash.chevron.right")
    }

    @Test func javascriptFamily() {
        for ext in ["js", "jsx", "mjs", "cjs"] {
            #expect(symbol(for: ext) == "curlybraces",
                    "\(ext) must use the curlybraces symbol")
        }
    }

    @Test func typescriptFamily() {
        #expect(symbol(for: "ts") == "curlybraces")
        #expect(symbol(for: "tsx") == "curlybraces")
    }

    @Test func jsonFiles() {
        #expect(symbol(for: "json") == "curlybraces")
    }

    @Test func configFiles() {
        for ext in ["yml", "yaml", "toml"] {
            #expect(symbol(for: ext) == "curlybraces",
                    "\(ext) must use the curlybraces symbol")
        }
    }

    @Test func documentFiles() {
        for ext in ["md", "markdown", "txt", "rst"] {
            #expect(symbol(for: ext) == "doc.text",
                    "\(ext) must use the doc.text symbol")
        }
    }

    @Test func webAndStyleFiles() {
        for ext in ["html", "xml", "css", "scss"] {
            #expect(symbol(for: ext) == "chevron.left.forwardslash.chevron.right",
                    "\(ext) must use the angle-bracket symbol")
        }
    }

    @Test func shellFiles() {
        for ext in ["sh", "bash", "zsh"] {
            #expect(symbol(for: ext) == "terminal",
                    "\(ext) must use the terminal symbol")
        }
    }

    @Test func cFamilyFiles() {
        for ext in ["c", "cpp", "cc", "h", "hpp", "m", "mm"] {
            #expect(symbol(for: ext) == "chevron.left.forwardslash.chevron.right",
                    "\(ext) must use the angle-bracket symbol")
        }
    }

    @Test func otherCompiledLanguages() {
        for ext in ["rs", "go", "rb", "java", "kt"] {
            #expect(symbol(for: ext) == "chevron.left.forwardslash.chevron.right",
                    "\(ext) must use the angle-bracket symbol")
        }
    }

    @Test func imageAndPDFFiles() {
        for ext in ["png", "jpg", "jpeg", "gif", "heic", "svg", "webp", "pdf"] {
            #expect(symbol(for: ext) == "photo",
                    "\(ext) must use the photo symbol")
        }
    }

    @Test func unknownExtensionFallsBackToDoc() {
        #expect(symbol(for: "xyz") == "doc",
                "unrecognised extension must fall back to the generic doc symbol")
        #expect(symbol(for: "weirdformat") == "doc")
        // Extensionless files are also unknown.
        let noExt = FileKind.icon(for: URL(fileURLWithPath: "/no/extension")).symbol
        #expect(noExt == "doc", "file with no extension must use the doc fallback")
    }

    @Test func extensionMatchIsCaseInsensitive() {
        // The switch branches on `.lowercased()`, so uppercase extensions must
        // resolve to the same symbol as the lowercase form.
        #expect(symbol(for: "SWIFT") == symbol(for: "swift"))
        #expect(symbol(for: "MD") == symbol(for: "md"))
        #expect(symbol(for: "JS") == symbol(for: "js"))
    }
}

// MARK: - FileTreeBuilder.build(files:root:) — hierarchy construction
//
// The Code-tab file sidebar depends on this to turn a flat `[URL]` into a
// sorted tree. Key invariants:
//   1. Directories come before files at every level.
//   2. Names are sorted case-insensitively within each tier.
//   3. Files outside `root` fall back to a flat root-level FileNode.
//   4. Empty input yields an empty tree.

struct FileTreeBuilderTests {

    private func root() -> URL {
        URL(fileURLWithPath: "/project")
    }

    private func file(_ rel: String) -> URL {
        root().appendingPathComponent(rel)
    }

    @Test func emptyInputProducesEmptyTree() {
        let nodes = FileTreeBuilder.build(files: [], root: root())
        #expect(nodes.isEmpty, "empty file list must produce an empty tree")
    }

    @Test func singleFileAtRoot() {
        let nodes = FileTreeBuilder.build(files: [file("main.swift")], root: root())
        #expect(nodes.count == 1)
        guard let n = nodes.first else { Issue.record("Expected one node"); return }
        #expect(n.name == "main.swift")
        #expect(n.url == file("main.swift"))
        #expect(n.children.isEmpty, "a plain file must have no children")
        #expect(!n.isDir, "a plain file must not be a directory")
    }

    @Test func nestedFileCreatesIntermediateDirectory() {
        let nodes = FileTreeBuilder.build(files: [file("Sources/App.swift")], root: root())
        // Top level should be a "Sources" directory node, not the file itself.
        #expect(nodes.count == 1)
        guard let dir = nodes.first else { Issue.record("Expected Sources dir"); return }
        #expect(dir.name == "Sources")
        #expect(dir.isDir, "an intermediate path component must produce a directory node")
        #expect(dir.url == nil)
        // The child should be the file.
        #expect(dir.children.count == 1)
        #expect(dir.children.first?.name == "App.swift")
        #expect(dir.children.first?.isDir == false)
    }

    @Test func directoriesBeforeFilesAtSameLevel() {
        let nodes = FileTreeBuilder.build(files: [
            file("main.swift"),         // file at root
            file("Sources/App.swift"),  // directory at root
        ], root: root())
        // "Sources" (dir) must come before "main.swift" (file).
        #expect(nodes.count == 2)
        #expect(nodes[0].name == "Sources",
                "directory 'Sources' must precede file 'main.swift'")
        #expect(nodes[1].name == "main.swift")
    }

    @Test func filesSortedCaseInsensitiveWithinDirectory() {
        let nodes = FileTreeBuilder.build(files: [
            file("Zebra.swift"),
            file("apple.swift"),
            file("Mango.swift"),
        ], root: root())
        // Case-insensitive alphabetical: apple, Mango, Zebra.
        let names = nodes.map(\.name)
        #expect(names == ["apple.swift", "Mango.swift", "Zebra.swift"],
                "files must be sorted case-insensitively: got \(names)")
    }

    @Test func directoriesSortedCaseInsensitively() {
        let nodes = FileTreeBuilder.build(files: [
            file("zeta/a.swift"),
            file("Alpha/b.swift"),
            file("mango/c.swift"),
        ], root: root())
        let names = nodes.filter(\.isDir).map(\.name)
        #expect(names == ["Alpha", "mango", "zeta"],
                "directories must sort case-insensitively: got \(names)")
    }

    @Test func fileOutsideRootFallsBackToLastPathComponent() {
        // A URL that doesn't share the root prefix is handled gracefully
        // by using its lastPathComponent as the relative path.
        let outsideFile = URL(fileURLWithPath: "/other/repo/file.swift")
        let nodes = FileTreeBuilder.build(files: [outsideFile], root: root())
        // It should appear as a flat root-level node named "file.swift".
        #expect(nodes.count == 1)
        #expect(nodes.first?.name == "file.swift",
                "file outside root must fall back to lastPathComponent")
    }

    @Test func deeplyNestedHierarchy() {
        let nodes = FileTreeBuilder.build(files: [
            file("a/b/c/deep.swift"),
            file("a/b/shallow.swift"),
        ], root: root())
        // Root should have one directory "a".
        #expect(nodes.count == 1)
        guard let a = nodes.first, a.name == "a" else {
            Issue.record("Expected top-level 'a' dir"); return
        }
        // "a" should have one child "b".
        #expect(a.children.count == 1)
        guard let b = a.children.first, b.name == "b" else {
            Issue.record("Expected 'b' dir inside 'a'"); return
        }
        // "b" should have "c" (dir) then "shallow.swift" (file) — dirs first.
        #expect(b.children.count == 2)
        #expect(b.children[0].name == "c", "dir 'c' must come before file")
        #expect(b.children[1].name == "shallow.swift")
        // "c" should contain "deep.swift".
        guard let c = b.children.first, c.isDir else {
            Issue.record("Expected 'c' dir"); return
        }
        #expect(c.children.count == 1)
        #expect(c.children.first?.name == "deep.swift")
    }
}
