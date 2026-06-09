import Testing
import Foundation
@testable import Salehman_AI

// MARK: - SelfImprove patch / parse / safety surface
//
// Blast-radius functions: a bad patch or a weak isInside can corrupt user source
// or escape the project. These tests run fully HERMETICALLY — `SelfImprove`'s
// projectRoot AND backup root are redirected to a throwaway temp dir (via the
// `self_improve_project_root` / `self_improve_backup_root` UserDefaults keys), so
// nothing is ever written into the live checkout or ~/.salehman_ai_self_improve_backups.
// (Earlier these wrote scratch files into the real repo and leaked uncleaned
// backup folders into $HOME — see the 2026-06-06 review.)

@Suite(.serialized) // mutates shared SelfImprove UserDefaults keys + temp disk
struct SelfImprovePatchTests {

    /// Redirect SelfImprove.projectRoot and backupRoot at a fresh temp dir for the
    /// duration of `body`, then restore the previous overrides and delete the dir.
    private func withTempRoots(_ body: (_ projectRoot: URL) throws -> Void) rethrows {
        let ud = UserDefaults.standard
        let prevProject = ud.string(forKey: "self_improve_project_root")
        let prevBackup  = ud.string(forKey: "self_improve_backup_root")
        let baseDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SelfImproveTest_\(UUID().uuidString.prefix(8))", isDirectory: true)
        let projectRoot = baseDir.appendingPathComponent("project", isDirectory: true)
        let backupRoot  = baseDir.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        ud.set(projectRoot.path, forKey: "self_improve_project_root")
        ud.set(backupRoot.path,  forKey: "self_improve_backup_root")
        defer {
            if let prevProject { ud.set(prevProject, forKey: "self_improve_project_root") }
            else { ud.removeObject(forKey: "self_improve_project_root") }
            if let prevBackup { ud.set(prevBackup, forKey: "self_improve_backup_root") }
            else { ud.removeObject(forKey: "self_improve_backup_root") }
            try? FileManager.default.removeItem(at: baseDir)
        }
        try body(projectRoot)
    }

    private func writeScratch(_ content: String, under root: URL) -> URL {
        let url = root.appendingPathComponent("SelfImproveScratch_\(UUID().uuidString.prefix(8)).txt")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: applyPatch

    @Test
    func applyPatchValidSingleLineRewriteBacksUpAndSucceeds() {
        withTempRoots { root in
            let url = writeScratch("line1\nline2\nline3\n", under: root)
            let patch = """
            REPLACE_RANGE: 2-2
            WITH:
            REPLACED
            END
            """
            #expect(SelfImprove.applyPatch(patch, to: url.path))
            let after = try? String(contentsOf: url, encoding: .utf8)
            #expect((after?.contains("REPLACED")) ?? false)
            #expect((after?.contains("line1")) ?? false)
            #expect((after?.contains("line2")) == false)   // line 2 was the replaced one
        }
    }

    @Test
    func applyPatchOutOfBoundsReturnsFalseAndDoesNotModify() {
        withTempRoots { root in
            let url = writeScratch("one\ntwo\n", under: root)
            let orig = try? String(contentsOf: url, encoding: .utf8)
            #expect(SelfImprove.applyPatch("REPLACE_RANGE: 10-12\nWITH:\nX\nEND", to: url.path) == false)
            #expect((try? String(contentsOf: url, encoding: .utf8)) == orig)
        }
    }

    @Test
    func applyPatchMalformedMissingTokensReturnsFalse() {
        withTempRoots { root in
            let url = writeScratch("a\nb\n", under: root)
            #expect(SelfImprove.applyPatch("REPLACE_RANGE: 1-1\nNO-WITH\nX\nEND", to: url.path) == false)
            #expect(SelfImprove.applyPatch("REPLACE_RANGE: 1-1\nWITH:\nX\n", to: url.path) == false)
        }
    }

    // MARK: parseErrors (pure — no disk)

    @Test
    func parseErrorsParsesStandardAndMissingColAndIgnoresWarnings() {
        let out = """
        /abs/Project/File.swift:42:10: error: cannot find 'foo' in scope
        /abs/Project/Other.swift:7: error: bar is not a member
        /abs/Project/Warn.swift:9:10: warning: something
        /abs/Project/Note.swift:1: note: see here
        """
        let errs = SelfImprove.parseErrors(out)
        #expect(errs.count == 2)
        #expect(errs[0].file.hasSuffix("File.swift"))
        #expect(errs[0].line == 42)
        #expect(errs[0].column == 10)
        #expect(errs[1].column == nil)
    }

    @Test
    func parseErrorsDeduplicatesIdenticalAndPreservesOrder() {
        let out = """
        /p/A.swift:1: error: dup
        /p/A.swift:1: error: dup
        /p/B.swift:2: error: second
        """
        let errs = SelfImprove.parseErrors(out)
        #expect(errs.count == 2)
        #expect(errs[0].message == "dup")
        #expect(errs[1].message == "second")
    }

    // MARK: isInsideProject (symlink + escape hardening)

    @Test
    func isInsideProjectTrueForFileUnderRootFalseForSiblingAndEscapes() {
        withTempRoots { root in
            #expect(SelfImprove.isInsideProject(root.appendingPathComponent("Some.swift").path))
            // sibling dir next to the project root is out
            let parent = root.deletingLastPathComponent().path
            #expect(SelfImprove.isInsideProject("\(parent)/evil-project/x.swift") == false)
            // ../ escape is out
            #expect(SelfImprove.isInsideProject("\(root.path)/../outside.swift") == false)
        }
    }

    // MARK: backup — locks the "never overwrite the true pre-edit original" guard

    @Test
    func backupPatchingSameFileTwicePreservesOriginalPreEdit() throws {
        try withTempRoots { root in
            let url = writeScratch("ORIGINAL\nline2\n", under: root)
            #expect(SelfImprove.applyPatch("REPLACE_RANGE: 1-1\nWITH:\nPATCH1\nEND", to: url.path))
            #expect(SelfImprove.applyPatch("REPLACE_RANGE: 1-1\nWITH:\nPATCH2\nEND", to: url.path))

            // The source file ends at the SECOND edit…
            #expect(try String(contentsOf: url, encoding: .utf8).contains("PATCH2"))

            // …but the backup must still hold the TRUE pre-edit ORIGINAL, never
            // PATCH1. This actually reads the backup dir — the previous version only
            // checked the source for "PATCH2", so the guard (SelfImprove.backup:
            // "first copy wins") could have been deleted and the test stayed green.
            let backupRootPath = try #require(UserDefaults.standard.string(forKey: "self_improve_backup_root"))
            let runDir = URL(fileURLWithPath: backupRootPath)
                .appendingPathComponent(SelfImprove.backupTimestampForTesting)
            let backedUp = runDir.appendingPathComponent(url.lastPathComponent)
            let backupText = try #require(try? String(contentsOf: backedUp, encoding: .utf8),
                                          "the pre-edit backup copy should exist")
            #expect(backupText.contains("ORIGINAL"))
            #expect(backupText.contains("PATCH1") == false)
        }
    }
}
