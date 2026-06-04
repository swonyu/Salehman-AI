import Foundation
import Speech
import AVFoundation

/// Transcribes audio and video files on-device (free) using Apple's Speech framework.
enum Transcriber {
    static let audioExts: Set<String> = ["m4a", "mp3", "wav", "aiff", "aif", "caf", "aac", "flac"]
    static let videoExts: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

    static func canHandle(_ ext: String) -> Bool {
        audioExts.contains(ext) || videoExts.contains(ext)
    }

    static func transcribe(_ url: URL) async -> String {
        let authorized = await requestAuth()
        guard authorized else {
            return "Speech recognition isn't authorized. Enable it in System Settings → Privacy → Speech Recognition."
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
            return "Speech recognizer is unavailable."
        }

        // Extract audio from video first if needed.
        let mediaURL = await extractAudioIfNeeded(url)

        let request = SFSpeechURLRecognitionRequest(url: mediaURL)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true   // private, no length limit
        }

        let box = ResumeBox()
        return await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
            // Latest non-final hypothesis — used as a fallback if the task ends
            // without ever delivering a final result.
            let latest = LockedString()

            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if box.resumeOnce() {
                        let partial = latest.value
                        cont.resume(returning: partial.isEmpty
                            ? "Transcription failed: \(error.localizedDescription)"
                            : partial)
                    }
                    return
                }
                guard let result else { return }
                latest.value = result.bestTranscription.formattedString
                if result.isFinal {
                    let text = result.bestTranscription.formattedString
                    if box.resumeOnce() { cont.resume(returning: text.isEmpty ? "(No speech detected.)" : text) }
                }
            }

            // Safety net: if the recognizer goes idle without ever delivering a
            // final result (it happens, especially on-device), resume anyway so
            // the caller never hangs forever.
            DispatchQueue.global().asyncAfter(deadline: .now() + 600) {
                guard box.resumeOnce() else { return }
                let partial = latest.value
                cont.resume(returning: partial.isEmpty ? "(Transcription timed out.)" : partial)
            }
        }
    }

    private static func requestAuth() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    private static func extractAudioIfNeeded(_ url: URL) async -> URL {
        guard videoExts.contains(url.pathExtension.lowercased()) else { return url }
        let asset = AVURLAsset(url: url)
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("salehman_audio_\(UUID().uuidString).m4a")
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { return url }
        export.outputURL = out
        export.outputFileType = .m4a
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously { cont.resume() }
        }
        return FileManager.default.fileExists(atPath: out.path) ? out : url
    }
}

/// Thread-safe string box for sharing the latest partial transcript across the
/// recognition callback and the timeout fallback.
private final class LockedString: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = ""
    var value: String {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}
