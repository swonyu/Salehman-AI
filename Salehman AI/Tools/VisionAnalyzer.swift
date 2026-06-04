import Foundation
import AppKit
import Vision

/// On-device image understanding using Apple's Vision framework (no cloud).
/// Produces a rich text description — scene/objects, people, barcodes, and all
/// readable text — which is then handed to the on-device 15-agent team.
enum VisionAnalyzer {

    static func describe(_ url: URL) async -> String {
        // Decode via ImageIO (thread-safe) instead of NSImage, which must not be
        // touched off the main thread.
        guard let cg = AttachmentLoader.loadCGImage(url) else {
            return "(Could not read the image.)"
        }

        let box = ResumeBox()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                // Text (OCR)
                let textReq = VNRecognizeTextRequest()
                textReq.recognitionLevel = .accurate
                textReq.usesLanguageCorrection = true
                textReq.recognitionLanguages = ["en-US", "ar-SA"]

                // Scene / object classification
                let classifyReq = VNClassifyImageRequest()

                // People & faces
                let faceReq = VNDetectFaceRectanglesRequest()
                let humanReq = VNDetectHumanRectanglesRequest()

                // Barcodes / QR codes
                let barcodeReq = VNDetectBarcodesRequest()

                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                try? handler.perform([textReq, classifyReq, faceReq, humanReq, barcodeReq])

                let lines = (textReq.results)?.compactMap { $0.topCandidates(1).first?.string } ?? []
                let labels = (classifyReq.results)?
                    .filter { $0.confidence > 0.3 }
                    .prefix(6)
                    .map { $0.identifier.replacingOccurrences(of: "_", with: " ") } ?? []
                let faces = faceReq.results?.count ?? 0
                let humans = humanReq.results?.count ?? 0
                let codes = barcodeReq.results?.compactMap { $0.payloadStringValue } ?? []

                var out = "On-device image analysis (Apple Vision):\n"
                if !labels.isEmpty {
                    out += "• Scene / objects: \(labels.joined(separator: ", "))\n"
                }
                if humans > 0 || faces > 0 {
                    out += "• People detected: ~\(max(humans, faces)) (faces: \(faces))\n"
                }
                if !codes.isEmpty {
                    out += "• Barcodes / QR codes: \(codes.joined(separator: " | "))\n"
                }
                if !lines.isEmpty {
                    out += "• Text read from image:\n\(lines.joined(separator: "\n"))\n"
                } else {
                    out += "• No readable text found in the image.\n"
                }
                if box.resumeOnce() { continuation.resume(returning: out) }
            }
        }
    }
}
