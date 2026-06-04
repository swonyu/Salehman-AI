import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// Describe a local image (scene, on-screen text, objects, barcodes) on-device
/// via Apple Vision — callable by the model when given a file path.
struct AnalyzeImageTool: Tool {
    let name = "analyze_image"
    let description = """
    Describe what's in a LOCAL image file (scene, objects, any readable text, \
    barcodes/QR) using on-device Apple Vision. Provide the absolute file path.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Absolute path to the image file on this Mac.")
        var path: String
    }

    func call(arguments: Arguments) async throws -> String {
        let url = URL(fileURLWithPath: arguments.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return "No file found at \(arguments.path)."
        }
        return await VisionAnalyzer.describe(url)
    }
}
#endif
