import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Attachment.merged — message-send collapse contract
//
// `merged` sits on the hot path of every message send: the composer's attachment
// list is passed through it right before the pipeline runs. Three behaviours:
//
//   1. Empty list → nil  (nothing to send)
//   2. Single item → identity pass-through — fileURL and isImage are PRESERVED
//      so the cloud-vision path still fires on that one image attachment.
//   3. Multiple items → text-only collapsed attachment:
//        name  = comma-joined names
//        kind  = "files"
//        icon  = "doc.on.doc"
//        extractedText = "––– name (kind) –––\ntext\n\n––– …" sections
//        fileURL / isImage reset to defaults (nil / false) — multi-merge is
//        always text-only; the image bytes can't be sent for more than one file.
//
// All paths are `nonisolated static`, pure, and synchronous — no AppKit, no
// file I/O, so these tests run in any environment.

struct AttachmentMergeTests {

    // `Attachment` is qualified: Swift Testing also exports a public `Attachment`
    // type, so the bare name is ambiguous once both modules are imported.
    private func makeAttachment(name: String, kind: String = "file",
                                text: String = "content",
                                url: URL? = nil,
                                isImage: Bool = false) -> Salehman_AI.Attachment {
        var a = Salehman_AI.Attachment(name: name, kind: kind, icon: "doc",
                                       extractedText: text)
        a.fileURL  = url
        a.isImage  = isImage
        return a
    }

    // MARK: empty

    @Test func mergedEmptyListReturnsNil() {
        #expect(Attachment.merged([]) == nil,
                "empty list must return nil — nothing to attach")
    }

    // MARK: single-item identity

    @Test func mergedSingleItemIsPassThrough() {
        let url = URL(fileURLWithPath: "/tmp/photo.png")
        let a = makeAttachment(name: "photo.png", kind: "image",
                               text: "OCR text here", url: url, isImage: true)
        let result = Attachment.merged([a])
        guard let r = result else { Issue.record("merged([a]) must not be nil"); return }
        // Identity pass-through: the same attachment comes back, same id.
        #expect(r.id == a.id,                "single item: id must be preserved (identity pass-through)")
        // Name, kind, extractedText must be verbatim — this is a pure pass-through.
        #expect(r.name == "photo.png",       "single item: name must be preserved")
        #expect(r.kind == "image",           "single item: kind must be preserved")
        #expect(r.extractedText == "OCR text here",
                "single item: extractedText must be preserved")
        // Vision-path fields must survive the pass-through.
        #expect(r.fileURL == url,            "single item: fileURL must be preserved for cloud vision")
        #expect(r.isImage == true,           "single item: isImage must be preserved for cloud vision")
    }

    // MARK: multi-item merge

    @Test func mergedMultipleCollapsesCombinedName() {
        let a = makeAttachment(name: "a.txt")
        let b = makeAttachment(name: "b.py")
        let c = makeAttachment(name: "c.md")
        guard let r = Attachment.merged([a, b, c]) else {
            Issue.record("merged([a,b,c]) must not be nil"); return
        }
        #expect(r.name == "a.txt, b.py, c.md",
                "multi-merge: name must be the comma-joined input names")
    }

    @Test func mergedMultipleUsesFilesKindAndIcon() {
        let a = makeAttachment(name: "x.swift", kind: "file")
        let b = makeAttachment(name: "y.pdf",   kind: "PDF")
        guard let r = Attachment.merged([a, b]) else {
            Issue.record("merged must not be nil for two-item list"); return
        }
        #expect(r.kind == "files",         "multi-merge: kind must be 'files'")
        #expect(r.icon == "doc.on.doc",    "multi-merge: icon must be 'doc.on.doc'")
    }

    @Test func mergedMultipleFormatsExtractedTextAsSections() {
        // Expected body:
        //   "––– x.swift (file) –––\ncode text\n\n––– readme.md (file) –––\nmd text"
        let a = makeAttachment(name: "x.swift", kind: "file", text: "code text")
        let b = makeAttachment(name: "readme.md", kind: "file", text: "md text")
        guard let r = Attachment.merged([a, b]) else {
            Issue.record("merged must not be nil for two-item list"); return
        }
        #expect(r.extractedText.contains("––– x.swift (file) –––"),
                "multi-merge: first section header must be present")
        #expect(r.extractedText.contains("code text"),
                "multi-merge: first file's text must be present")
        #expect(r.extractedText.contains("––– readme.md (file) –––"),
                "multi-merge: second section header must be present")
        #expect(r.extractedText.contains("md text"),
                "multi-merge: second file's text must be present")
        // Sections are separated by \n\n.
        let separator = "\n\n––– readme.md"
        #expect(r.extractedText.contains(separator),
                "multi-merge: sections must be separated by a blank line (\\n\\n)")
    }

    @Test func mergedMultipleResetsVisionFieldsToDefaults() {
        // A multi-merge is always text-only — the pipeline cannot fan out image
        // bytes for multiple files, so fileURL and isImage must be nil/false.
        let url = URL(fileURLWithPath: "/tmp/photo.png")
        let a = makeAttachment(name: "photo.png", kind: "image",
                               text: "vision text", url: url, isImage: true)
        let b = makeAttachment(name: "other.png", kind: "image",
                               text: "other text", url: url, isImage: true)
        guard let r = Attachment.merged([a, b]) else {
            Issue.record("merged must not be nil for two-image list"); return
        }
        #expect(r.fileURL == nil,    "multi-merge: fileURL must be nil — text-only result")
        #expect(r.isImage == false,  "multi-merge: isImage must be false — no cloud vision on merged blobs")
    }
}
