import SwiftUI
import Combine

/// The chat conversation + its send/stop pipeline, extracted from `ContentView`
/// (which was a 1600-line view doing both presentation AND orchestration). This
/// owns the message list, the running state, and the actual brain calls
/// (`Orchestrator` / media transcription) — the real logic, not a stub. The view
/// keeps input/focus/search concerns; everything that drives or holds the
/// conversation lives here. `@MainActor` + `ObservableObject` to match the app's
/// existing `@ObservedObject`/`@StateObject` pattern (AppState, BrainStatus, …).
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isRunning: Bool = false
    private var runningTask: Task<Void, Never>?

    /// Clear the conversation and reset the orchestrator. (The view resets its own
    /// search UI alongside this.)
    func startNewChat() {
        stop()
        Task { await Orchestrator.reset() }
        withAnimation(DS.Motion.spring) { messages.removeAll() }
    }

    /// Cancel an in-flight response and return to a ready state.
    func stop() {
        runningTask?.cancel()
        runningTask = nil
        isRunning = false
        MissionProgress.shared.finish()
    }

    /// Re-answer: drop this assistant reply (and anything after it) and re-run the
    /// user message that preceded it, without duplicating the user bubble.
    func regenerate(_ message: ChatMessage) {
        guard !isRunning, !message.isUser, let idx = messages.firstIndex(of: message) else { return }
        guard let priorUser = messages[..<idx].last(where: { $0.isUser }) else { return }
        let clean = priorUser.text
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("📎") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        withAnimation(DS.Motion.fade) { messages.removeSubrange(idx...) }
        send(text: clean, attachment: nil, recordUser: false)
    }

    /// Edit-and-resend: pull this user message (and everything after it) out of
    /// the transcript and hand its text back so the view can load the composer.
    /// Mirrors `regenerate`'s attachment-line stripping. Returns nil when the
    /// turn isn't editable (mid-run, not a user message, or attachment-only).
    func extractForEdit(_ message: ChatMessage) -> String? {
        guard !isRunning, message.isUser, let idx = messages.firstIndex(of: message) else { return nil }
        let clean = message.text
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("📎") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        withAnimation(DS.Motion.fade) { messages.removeSubrange(idx...) }
        return clean
    }

    /// Send a user turn through the agent pipeline. The view passes the composed
    /// text + any attachment, and clears its own input/attachment afterward.
    func send(text: String, attachment att: Attachment?, recordUser: Bool = true) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isRunning else { return }
        guard !trimmed.isEmpty || att != nil else { return }

        // Pasted a YouTube link, media URL, or audio/video file path → transcribe it.
        if att == nil, let media = MediaTranscribe.detect(trimmed) {
            transcribeMedia(media, raw: trimmed)
            return
        }

        // What the user sees in their bubble.
        var displayed = trimmed
        if let att { displayed += (displayed.isEmpty ? "" : "\n\n") + "📎 \(att.name)" }

        let question = trimmed
        if recordUser {
            messages.append(ChatMessage(id: UUID(), text: displayed, isUser: true, timestamp: Date()))
        }
        // Rotation mode (≥2 brains checked): hop to the next chosen brain so this
        // message is answered by it (the whole pipeline reads the updated pin).
        AppSettings.shared.advanceRotation()
        isRunning = true

        runningTask = Task {
            // Build the message the agents receive (resolving image vision first).
            var missionToSend = question.isEmpty
                ? "Please look at the attached \(att?.kind ?? "file")." : question
            if let att {
                var content = att.extractedText
                // For images, prefer true vision (qwen2.5vl) over plain Apple Vision.
                if att.isImage, AppSettings.shared.useVision, let fileURL = att.fileURL,
                   let data = try? Data(contentsOf: fileURL),
                   let seen = await OllamaClient.vision(imageData: data, question: question) {
                    content = "What the vision model sees:\n\(seen)"
                }
                missionToSend += "\n\n[Attached \(att.kind) \"\(att.name)\"]\n\(content)"
            }

            // Auto-continue loop (claude-autocontinue): normally ONE turn, but if the
            // owner left Auto-continue on and the reply looks unfinished, keep going
            // ("continue") up to a cap so they don't have to nudge it each time. Stop
            // cancels the whole loop. Each continuation flows through the same pipeline,
            // so it inherits the conversation history recorded by AgentPipeline.run.
            var turnPrompt = missionToSend
            var autoContinues = 0
            let maxAutoContinues = 4
            while true {
                let turnStart = Date()
                let result = await Orchestrator.runAndReturnResult(mission: turnPrompt)
                if Task.isCancelled { return }
                let reply = ChatMessage(id: UUID(), text: result.output, isUser: false,
                                        timestamp: Date(),
                                        duration: Date().timeIntervalSince(turnStart))
                messages.append(reply)
                // Auto-learn durable facts from this turn (fire-and-forget, never blocks UI).
                let turnQuestion = question, turnReply = result.output
                let mem = MemoryStore.shared
                Task.detached(priority: .background) {
                    mem.autoExtract(userMessage: turnQuestion, reply: turnReply)
                }
                if AppSettings.shared.autoSpeak {
                    SpeechOut.shared.speak(result.output, id: reply.id)
                }
                if AppSettings.autoContinueEnabled, autoContinues < maxAutoContinues,
                   AgentPipeline.looksIncomplete(result.output) {
                    autoContinues += 1
                    turnPrompt = "continue"
                    continue
                }
                break
            }
            isRunning = false
            // Refresh the header brain dot now — it otherwise lags up to ~10s, so
            // this reflects reality right after a send (e.g. a brain that just failed).
            await BrainStatus.shared.refresh()
        }
    }

    /// YouTube link / audio file → transcript + auto-summary. Called from `send`
    /// when the input is detected as media.
    func transcribeMedia(_ source: MediaTranscribe.Source, raw: String) {
        messages.append(ChatMessage(id: UUID(), text: raw, isUser: true, timestamp: Date()))
        isRunning = true            // reuse the existing typing indicator

        runningTask = Task {
            let transcript = await MediaTranscribe.transcribe(source)
            if Task.isCancelled { return }

            // 1) Post the raw transcript.
            messages.append(ChatMessage(id: UUID(), text: "📝 Transcript\n\n\(transcript)",
                                        isUser: false, timestamp: Date()))

            // Skip the summary if transcription failed or there's too little text.
            guard transcript.count > 40,
                  !transcript.hasPrefix("Couldn't"),
                  !transcript.contains("no captions") else {
                isRunning = false
                return
            }

            // 2) Auto-summarize (cap the input so the on-device model isn't overrun).
            let capped = transcript.count > 8000 ? String(transcript.prefix(8000)) + "…" : transcript
            let prompt = "Summarize this transcript and list the key points and any "
                       + "action items. Reply in the transcript's language:\n\n\(capped)"
            let result = await Orchestrator.runAndReturnResult(mission: prompt)
            if Task.isCancelled { return }
            let reply = ChatMessage(id: UUID(), text: result.output, isUser: false, timestamp: Date())
            messages.append(reply)
            isRunning = false
            if AppSettings.shared.autoSpeak {
                SpeechOut.shared.speak(result.output, id: reply.id)
            }
        }
    }
}
