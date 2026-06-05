import Foundation
import AVFoundation
import Speech
import Combine

/// Live microphone dictation. Free; runs on-device when the recognizer supports
/// it for the current locale (en-US generally does), otherwise SFSpeechRecognizer
/// routes the audio through Apple's Speech servers. Publishes a live transcript.
@MainActor
final class SpeechIn: ObservableObject {
    static let shared = SpeechIn()

    @Published var transcript = ""
    @Published var isListening = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private init() {}

    func toggle() { isListening ? stop() : start() }

    func start() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            Task { @MainActor in self.begin() }
        }
    }

    private func begin() {
        guard let recognizer, recognizer.isAvailable, !isListening else { return }
        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Mirror Transcriber / LiveTranscriber: prefer on-device recognition
        // when the locale supports it, so audio doesn't quietly head off to
        // Apple's Speech servers when a local model is available.
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch { input.removeTap(onBus: 0); return }

        isListening = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result { self.transcript = result.bestTranscription.formattedString }
                if error != nil || (result?.isFinal ?? false) { self.stop() }
            }
        }
    }

    func stop() {
        guard isListening else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil; task = nil
        isListening = false
    }

    deinit {
        // Tear down audio + recognition resources if the singleton is ever released.
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
    }
}
