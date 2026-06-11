import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Code tab git-status dots — porcelain parser
//
// `CodeWorkspace.gitModifiedURLs` is `nonisolated static` and pure on its
// inputs, so these tests are hermetic: no git repo, no Shell, no MainActor,
// no shared state. The contract: every uncommitted file in
// `git status --porcelain -uall` output becomes `root/<path>` so the file
// tree can match rows by URL — a regression here silently kills the amber
// "uncommitted" dots without any visible error.

struct CodeGitStatusTests {

    private let root = URL(fileURLWithPath: "/tmp/proj")

    private func parse(_ porcelain: String) -> Set<URL> {
        CodeWorkspace.gitModifiedURLs(porcelain: porcelain, root: root)
    }

    @Test func modifiedAndUntrackedBecomeURLs() {
        let out = parse(" M Sources/App.swift\n?? Notes/todo.md\n")
        #expect(out == [
            root.appendingPathComponent("Sources/App.swift"),
            root.appendingPathComponent("Notes/todo.md"),
        ])
    }

    @Test func renameCountsAsNewPathOnly() {
        let out = parse("R  old/Name.swift -> new/Name.swift")
        #expect(out == [root.appendingPathComponent("new/Name.swift")])
    }

    @Test func quotedPathLosesQuotes() {
        let out = parse("?? \"weird name.txt\"")
        #expect(out == [root.appendingPathComponent("weird name.txt")])
    }

    @Test func allStatusColumnVariantsParse() {
        // Staged+unstaged ("MM"), staged-only ("M "), unstaged-only (" M").
        let out = parse("MM a.txt\nM  b.txt\n M c.txt")
        #expect(out == [
            root.appendingPathComponent("a.txt"),
            root.appendingPathComponent("b.txt"),
            root.appendingPathComponent("c.txt"),
        ])
    }

    @Test func blankAndShortLinesAreSkipped() {
        #expect(parse("").isEmpty)
        #expect(parse("\n\n??\n M \n").isEmpty)
    }
}
