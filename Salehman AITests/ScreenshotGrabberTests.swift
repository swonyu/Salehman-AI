import Testing
import Foundation
import AppKit
@testable import Salehman_AI

// /shot — pins both halves of the screenshot-attach feature: the newest-image
// picker (injectable directory) and the on-device OCR (a programmatically
// rendered PNG with known text must come back recognizable). Temp-dir only.
struct ScreenshotGrabberTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("shot-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writePNG(text: String, to url: URL) throws {
        let size = NSSize(width: 480, height: 120)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        (text as NSString).draw(at: NSPoint(x: 24, y: 40), withAttributes: [
            .font: NSFont.systemFont(ofSize: 32, weight: .semibold),
            .foregroundColor: NSColor.black,
        ])
        img.unlockFocus()
        var rect = CGRect(origin: .zero, size: size)
        let cg = img.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
        let rep = NSBitmapImageRep(cgImage: cg)
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }

    @Test func picksTheNewestImage() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let old = dir.appendingPathComponent("old.png")
        let new = dir.appendingPathComponent("new.png")
        try writePNG(text: "old", to: old)
        try writePNG(text: "new", to: new)
        // Make the mtimes unambiguous regardless of write timing.
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -3600)], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: new.path)
        // Compare names, not URLs: the enumerator returns /private/var/… while
        // temporaryDirectory hands out /var/… (same file, symlinked prefix).
        #expect(ScreenshotGrabber.latestScreenshot(in: dir)?.lastPathComponent == "new.png")
    }

    @Test func ignoresNonImages() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "not an image".write(to: dir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        #expect(ScreenshotGrabber.latestScreenshot(in: dir) == nil)
    }

    @Test func ocrReadsRenderedText() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let shot = dir.appendingPathComponent("shot.png")
        try writePNG(text: "SALEHMAN OCR 42", to: shot)
        let text = ScreenshotGrabber.ocr(shot)
        #expect(text.localizedCaseInsensitiveContains("SALEHMAN"))
        #expect(text.contains("42"))
    }
}
