import Foundation
import Combine

/// Owns the hands-free conversation loop for Voice Mode:
///
///   listen → (1.2s of silence) → think → speak → (TTS done) → listen → …
///
/// It only *consumes* the existing singletons — `SpeechIn` (on-device dictation),
/// `SpeechOut` (AVSpeech TTS), and `Orchestrator` (the same brain/memory/tools
/// path typed chat uses) — so no audio or shared file is modified.
///
/// Defensive points (from the design review):
///   • `SpeechIn` may stop itself on `result.isFinal`; we never assume we own the
///     only stop path and re-check before re-arming.
///   • TTS audio can bleed into the mic, so re-arm is gated on `speakingID == nil`
///     PLUS a short settle delay, and the mic is fully stopped before speaking.
@MainActor
final class VoiceSession: ObservableObject {
    enum Phase: Equatable { case idle, listening, thinking, speaking }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var turns: [VoiceTurn] = []
    @Published private(set) var liveCaption = ""

    private let speechIn = SpeechIn.shared
    private let speechOut = SpeechOut.shared
    private var cancellables: Set<AnyCancellable> = []
    private var silenceTimer: Task<Void, Never>?
    private var lastTranscript = ""
    private var active = false
    private let silenceInterval: TimeInterval = 1.2

    // MARK: Lifecycle

    func start() {
        guard !active else { return }
        active = true
        turns = []

        speechIn.$transcript
            .receive(on: RunLoop.main)
            .sink { [weak self] t in self?.handleTranscript(t) }
            .store(in: &cancellables)

        speechOut.$speakingID
            .receive(on: RunLoop.main)
            .sink { [weak self] id in self?.handleSpeakingFinished(id) }
            .store(in: &cancellables)

        beginListening()
    }

    func stop() {
        active = false
        silenceTimer?.cancel(); silenceTimer = nil
        cancellables.removeAll()
        speechIn.stop()
        speechOut.stop()
        phase = .idle
        liveCaption = ""
    }

    /// Barge-in: cut off the spoken reply (if any) and listen again immediately.
    func interrupt() {
        guard active else { return }
        speechOut.stop()
        beginListening()
    }

    // MARK: Loop

    private func beginListening() {
        guard active else { return }
        lastTranscript = ""
        liveCaption = ""
        phase = .listening
        speechIn.start()
        scheduleSilenceCheck()
    }

    private func handleTranscript(_ t: String) {
        guard active, phase == .listening else { return }
        liveCaption = t
        if t != lastTranscript {
            lastTranscript = t
            scheduleSilenceCheck()   // new words → reset the silence countdown
        }
    }

    /// Fire `finishUtterance` after `silenceInterval` of no new transcript words.
    private func scheduleSilenceCheck() {
        silenceTimer?.cancel()
        let delay = silenceInterval
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            await self?.finishUtterance()
        }
    }

    private func finishUtterance() async {
        guard active, phase == .listening else { return }
        let text = lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        speechIn.stop()
        guard !text.isEmpty else { beginListening(); return }   // silence with no words → keep listening

        turns.append(VoiceTurn(role: .me, text: text))
        liveCaption = ""
        phase = .thinking

        let result = await Orchestrator.runAndReturnResult(mission: text)   // tuple → .output
        guard active else { return }
        let reply = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { beginListening(); return }

        turns.append(VoiceTurn(role: .salehman, text: reply))
        phase = .speaking
        speechOut.speak(reply, id: UUID())
    }

    /// `speakingID` flips to `nil` when TTS finishes (or is stopped). If we were
    /// speaking, re-arm the mic after a short settle so the tail of the spoken
    /// reply isn't captured. (When `interrupt`/`stop` set it nil, the phase guard
    /// or `active` flag short-circuits this, avoiding a double re-arm.)
    private func handleSpeakingFinished(_ id: UUID?) {
        guard active, phase == .speaking, id == nil else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, self.active, self.phase == .speaking else { return }
            self.beginListening()
        }
    }
}
