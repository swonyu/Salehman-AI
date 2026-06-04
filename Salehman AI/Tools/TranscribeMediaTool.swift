import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// Transcribe a local audio or video file to text on-device — callable by the
/// model when given a file path. Wraps `Transcriber`.
struct TranscribeMediaTool: Tool {
    let name = "transcribe_media"
    let description = """
    Transcribe a LOCAL audio or video file (m4a, mp3, wav, mp4, mov, …) to text \
    using on-device speech recognition. Provide the absolute file path.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Absolute path to the audio/video file on this Mac.")
        var path: String
    }

    func call(arguments: Arguments) async throws -> String {
        let url = URL(fileURLWithPath: arguments.path)
        let ext = url.pathExtension.lowercased()
        guard Transcriber.canHandle(ext) else {
            return "That file type (.\(ext)) isn't supported for transcription."
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return "No file found at \(arguments.path)."
        }
        return await Transcriber.transcribe(url)
    }
}
#endif
