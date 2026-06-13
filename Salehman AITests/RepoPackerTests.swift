import Testing
import Foundation
@testable import Salehman_AI

// MARK: - RepoPacker (Repomix/Gitingest-style code→context packer)
//
// Pure, on-device packing. These tests build small temp trees and assert the skip
// rules, format, and caps. Serialized so their (real) file I/O doesn't pile onto the
// suite's peak parallelism — file enumeration under heavy concurrent I/O could
// transiently under-read and flip the file-count assertions.
@Suite(.serialized)
struct RepoPackerTests {

    /// Build a temp dir with the given relative-path → content files. Caller deletes.
    private func makeTree(_ files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("repopacker-\(UUID().uuidString)", isDirectory: true)
        for (rel, content) in files {
            let url = root.appendingPathComponent(rel)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try Data(content.utf8).write(to: url)
        }
        return root
    }

    @Test func isPackableByExtensionNameAndDotfile() {
        #expect(RepoPacker.isPackable(URL(fileURLWithPath: "/x/a.swift")))
        #expect(RepoPacker.isPackable(URL(fileURLWithPath: "/x/a.py")))
        #expect(RepoPacker.isPackable(URL(fileURLWithPath: "/x/README")))
        #expect(RepoPacker.isPackable(URL(fileURLWithPath: "/x/.gitignore")))
        #expect(!RepoPacker.isPackable(URL(fileURLWithPath: "/x/photo.png")))
        #expect(!RepoPacker.isPackable(URL(fileURLWithPath: "/x/blob.bin")))
    }

    @Test func fenceLanguageMapsCommonExtensions() {
        #expect(RepoPacker.fenceLanguage(for: URL(fileURLWithPath: "a.swift")) == "swift")
        #expect(RepoPacker.fenceLanguage(for: URL(fileURLWithPath: "a.py")) == "python")
        #expect(RepoPacker.fenceLanguage(for: URL(fileURLWithPath: "a.ts")) == "typescript")
        #expect(RepoPacker.fenceLanguage(for: URL(fileURLWithPath: "a.weirdext")) == "")
    }

    @Test func packIncludesCodeButSkipsBinaryAndDepDirs() throws {
        let root = try makeTree([
            "a.swift": "let x = 1\nlet y = 2\n",
            "sub/b.py": "print('hi')\n",
            "README": "# Title\n",
            "photo.png": "not really an image",          // non-text extension → skipped
            "node_modules/dep.js": "module.exports = {}\n",  // dep dir → pruned wholesale
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let r = RepoPacker.pack(rootPath: root.path)
        #expect(r.fileCount == 3)                          // a.swift, sub/b.py, README
        #expect(r.digest.contains("===== FILE: a.swift"))
        #expect(r.digest.contains("===== FILE: sub/b.py"))
        #expect(r.digest.contains("===== FILE: README"))
        #expect(!r.digest.contains("photo.png"))           // skipped (binary ext)
        #expect(!r.digest.contains("node_modules"))        // pruned dir, never enumerated
        #expect(r.digest.contains("```swift"))             // fence language applied
    }

    @Test func packTruncatesAtTotalByteCap() throws {
        let big = String(repeating: "abcdefghij\n", count: 5_000)   // ~55 KB each
        let root = try makeTree(["a.txt": big, "b.txt": big, "c.txt": big])
        defer { try? FileManager.default.removeItem(at: root) }

        let r = RepoPacker.pack(rootPath: root.path, maxTotalBytes: 60_000)
        #expect(r.truncated)
        #expect(r.fileCount < 3)                           // the cap stopped it early
    }

    @Test func oversizeSingleFileIsSkipped() throws {
        let root = try makeTree(["huge.txt": String(repeating: "x", count: 10_000)])
        defer { try? FileManager.default.removeItem(at: root) }
        let r = RepoPacker.pack(rootPath: root.path, maxFileBytes: 1_000)
        #expect(r.fileCount == 0)
        #expect(r.skippedCount >= 1)
    }
}

// MARK: - RepoPacker.byteString
//
// Three-branch size formatter: raw bytes / KB / MB.
// Not in the serialized suite above — it's purely computational, so it runs
// in parallel with other test suites and adds no I/O latency.
//
// Boundary points:
//   < 1 024           → "N B"
//   1 024 – 1 048 575 → "N KB"  (%.0f rounds)
//   ≥ 1 048 576       → "N.N MB" (%.1f)

struct RepoPackerByteStringTests {

    @Test func bytesPath() {
        #expect(RepoPacker.byteString(0)    == "0 B",    "zero bytes must format as '0 B'")
        #expect(RepoPacker.byteString(512)  == "512 B",  "sub-kilobyte must stay in bytes")
        #expect(RepoPacker.byteString(1023) == "1023 B", "1023 is the last value in the bytes range")
    }

    @Test func kilobytesBoundaryAndRange() {
        // 1023 → bytes; 1024 → first KB value.
        #expect(RepoPacker.byteString(1023) == "1023 B",
                "1023 must use bytes path (strict less-than 1024)")
        #expect(RepoPacker.byteString(1024) == "1 KB",
                "1024 is the first value formatted as KB")
        // 512 × 1024 = 524 288 → exactly 512 KB.
        #expect(RepoPacker.byteString(524_288) == "512 KB",
                "512 × 1024 must format as '512 KB'")
    }

    @Test func megabytesBoundaryAndRange() {
        // 1_048_576 = 2^20 is the first value that crosses into MB.
        #expect(RepoPacker.byteString(1_048_576) == "1.0 MB",
                "exactly 1 MiB (2^20) must show as '1.0 MB'")
        // 2 621 440 = 2.5 × 1 048 576 → "2.5 MB".
        #expect(RepoPacker.byteString(2_621_440) == "2.5 MB",
                "2.5 × 1 MiB must format as '2.5 MB'")
    }
}
