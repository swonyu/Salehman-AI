import Testing
import Foundation
@testable import Salehman_AI

// Restore Checkpoint (revert this run's AI edits) — pins the DISK half of the
// feature: `CodeWorkspace.revert(file:toSnapshot:)`. Modified files get their
// pre-run snapshot written back; files the run CREATED (no snapshot) are
// deleted — that IS their pre-run state. Runs against a private temp dir, so
// it's parallel-safe and touches no real project.
struct RestoreSnapshotTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("restore-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func modifiedFileGetsSnapshotBack() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let f = dir.appendingPathComponent("a.swift")
        try "AFTER — the AI's edit".write(to: f, atomically: true, encoding: .utf8)
        try CodeWorkspace.revert(file: f, toSnapshot: "BEFORE — the pre-run state")
        #expect(try String(contentsOf: f, encoding: .utf8) == "BEFORE — the pre-run state")
    }

    @Test func createdFileIsDeleted() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let f = dir.appendingPathComponent("new.swift")
        try "the run created me".write(to: f, atomically: true, encoding: .utf8)
        try CodeWorkspace.revert(file: f, toSnapshot: nil)
        #expect(!FileManager.default.fileExists(atPath: f.path))
    }

    @Test func revertOfMissingFileThrowsInsteadOfSilentlyPassing() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let ghost = dir.appendingPathComponent("never-existed.swift")
        #expect(throws: (any Error).self) {
            try CodeWorkspace.revert(file: ghost, toSnapshot: nil)   // delete of nothing
        }
    }
}
