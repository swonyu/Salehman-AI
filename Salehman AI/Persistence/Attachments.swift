import Foundation
import AppKit
import Vision
import PDFKit

/// An item the user attached to a message. `extractedText` is what the
/// (text-only) model actually receives.
struct Attachment: Identifiable {
    let id = UUID()
    let name: String
    let kind: String      // "file", "image", "screenshot", "PDF"
    let icon: String
    let extractedText: String
    var fileURL: URL? = nil       // original file (used for Claude vision on images)
    var isImage: Bool = false     // true for images/screenshots → eligible for cloud vision
}

enum AttachmentLoader {

    private static let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp"]

    /// Show the macOS open panel and return the chosen file.
    @MainActor
    static func pickFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a file to attach"
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Turn a file URL into an Attachment, extracting its text appropriately.
    static func load(url: URL) async -> Attachment {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent

        // Guard against accidentally loading a multi-gigabyte file into memory.
        // Media files (audio/video) stream, so they're exempt from the cap.
        let size = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int) ?? 0
        let isMedia = Transcriber.canHandle(ext)
        if !isMedia, size > 200_000_000 {
            return Attachment(name: name, kind: "file", icon: "exclamationmark.triangle",
                              extractedText: "(This file is too large to read — \(size / 1_000_000) MB.)")
        }

        if imageExts.contains(ext) {
            // Full on-device understanding (scene, people, codes, text) via Vision.
            let description = await VisionAnalyzer.describe(url)
            return Attachment(name: name, kind: "image", icon: "photo",
                              extractedText: description, fileURL: url, isImage: true)
        }
        if ext == "pdf" {
            let text = pdfText(url)
            let body = text.isEmpty ? "(No extractable text in this PDF.)" : text
            return Attachment(name: name, kind: "PDF", icon: "doc.richtext", extractedText: body)
        }
        if Transcriber.canHandle(ext) {
            let transcript = await Transcriber.transcribe(url)
            let isVideo = Transcriber.videoExts.contains(ext)
            return Attachment(name: name, kind: isVideo ? "video" : "audio",
                              icon: isVideo ? "video" : "waveform",
                              extractedText: "Transcript:\n\(transcript)")
        }
        // Treat everything else as text/code.
        let text = (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .isoLatin1))
            ?? "(Could not read this file as text.)"
        return Attachment(name: name, kind: "file", icon: "doc.text",
                          extractedText: String(text.prefix(20_000)))
    }

    /// Find the user's most recent screenshot (Desktop, then common folders).
    static func lastScreenshot() -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let folders = [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Pictures/Screenshots")
        ]
        var candidates: [(url: URL, date: Date)] = []
        for folder in folders {
            guard let items = try? fm.contentsOfDirectory(at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]) else { continue }
            for item in items where imageExts.contains(item.pathExtension.lowercased()) {
                let lower = item.lastPathComponent.lowercased()
                let looksLikeShot = lower.hasPrefix("screen") || lower.contains("screenshot") || lower.contains("screen shot")
                let date = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                if looksLikeShot { candidates.append((item, date)) }
            }
        }
        return candidates.sorted { $0.date > $1.date }.first?.url
    }

    /// Capture a fresh screenshot of the whole screen and return it.
    static func captureNow() -> URL? {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("salehman_shot_\(UUID().uuidString).png")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", tmp.path]   // -x = no sound
        do {
            try task.run(); task.waitUntilExit()
        } catch { return nil }
        return FileManager.default.fileExists(atPath: tmp.path) ? tmp : nil
    }

    // MARK: - Extraction

    static func pdfText(_ url: URL) -> String {
        guard let doc = PDFDocument(url: url) else { return "" }
        var out = ""
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let s = page.string { out += s + "\n" }
        }
        return String(out.prefix(20_000))
    }

    static func ocr(_ url: URL) async -> String {
        guard let cg = loadCGImage(url) else { return "" }

        let box = ResumeBox()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            let request = VNRecognizeTextRequest { req, _ in
                let text = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                if box.resumeOnce() { continuation.resume(returning: text) }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "ar-SA"]

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { if box.resumeOnce() { continuation.resume(returning: "") } }
            }
        }
    }

    /// Decode an image file straight to a CGImage. Uses ImageIO (thread-safe),
    /// avoiding NSImage which is not safe to touch off the main thread.
    static func loadCGImage(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}

/// Ensures a continuation resumes exactly once.
final class ResumeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func resumeOnce() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true; return true
    }
}
