import Foundation
import ImagePlayground
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device image generation via Apple's Image Playground (free, local).
enum ImageGen {
    static func generate(_ prompt: String) async -> URL? {
        guard #available(macOS 26.0, *) else { return nil }
        do {
            let creator = try await ImageCreator()
            let stream = creator.images(for: [.text(prompt)], style: .illustration, limit: 1)
            for try await created in stream {
                return savePNG(created.cgImage)
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func savePNG(_ cg: CGImage) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("salehman_img_\(UUID().uuidString).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, nil)
        return CGImageDestinationFinalize(dest) ? url : nil
    }
}

/// Holds the most recently generated image so the chat can display it after the
/// agent turn completes.
final class GeneratedMedia: @unchecked Sendable {
    static let shared = GeneratedMedia()
    private let lock = NSLock()
    private var path: String?

    func set(_ p: String) { lock.lock(); path = p; lock.unlock() }
    func consume() -> String? { lock.lock(); defer { path = nil; lock.unlock() }; return path }
}

#if canImport(FoundationModels)
struct GenerateImageTool: Tool {
    let name = "generate_image"
    let description = "Create an image from a text description using on-device Image Playground. Use when the user asks to generate, draw, or make a picture."

    @Generable
    struct Arguments {
        @Guide(description: "A vivid description of the image to create.")
        var prompt: String
    }

    func call(arguments: Arguments) async throws -> String {
        let p = arguments.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return "No image description given." }
        if let url = await ImageGen.generate(p) {
            GeneratedMedia.shared.set(url.path)
            return "Image created successfully for: \"\(p)\". It is now shown to the user."
        }
        return "Image generation isn't available (needs Apple Intelligence Image Playground enabled)."
    }
}
#endif
