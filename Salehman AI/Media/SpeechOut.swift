import Foundation
import AVFoundation
import Combine

/// Reads text aloud (free, on-device). Auto-picks an Arabic or English voice.
@MainActor
final class SpeechOut: ObservableObject {
    static let shared = SpeechOut()

    @Published private(set) var speakingID: UUID?
    private let synth = AVSpeechSynthesizer()
    private let delegate = Delegate()

    private init() {
        synth.delegate = delegate
        delegate.owner = self
    }

    func toggle(_ text: String, id: UUID) {
        if speakingID == id { stop() } else { speak(text, id: id) }
    }

    func speak(_ text: String, id: UUID) {
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        let isArabic = text.range(of: "\\p{Arabic}", options: .regularExpression) != nil
        let lang = isArabic ? "ar-SA" : "en-US"

        let settings = AppSettings.shared
        // Use the chosen voice when set; otherwise auto-pick by language.
        if !settings.speechVoiceID.isEmpty,
           let chosen = AVSpeechSynthesisVoice(identifier: settings.speechVoiceID) {
            utterance.voice = chosen
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
        }
        // Map the normalized 0…1 rate onto the platform's supported range.
        let lo = AVSpeechUtteranceMinimumSpeechRate, hi = AVSpeechUtteranceMaximumSpeechRate
        utterance.rate = lo + Float(settings.speechRate) * (hi - lo)

        speakingID = id
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        speakingID = nil
    }

    fileprivate func didFinish() { speakingID = nil }

    /// AVSpeechSynthesizerDelegate is not @MainActor-typed, so we keep an inner
    /// NSObject delegate that hops back to the main actor before updating state.
    private final class Delegate: NSObject, AVSpeechSynthesizerDelegate {
        weak var owner: SpeechOut?
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            Task { @MainActor in self.owner?.didFinish() }
        }
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            Task { @MainActor in self.owner?.didFinish() }
        }
    }
}
