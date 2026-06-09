import Foundation
import ScreenCaptureKit
@preconcurrency import Speech   // SFSpeech* types/closures predate Swift concurrency (not Sendable)
import AVFoundation
import CoreMedia
import CoreGraphics
import Combine
import AppKit
import QuartzCore

enum LiveLang: String, CaseIterable, Identifiable {
    case auto, english, arabic
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: return "Auto (EN + AR)"
        case .english: return "English"
        case .arabic: return "Arabic"
        }
    }
    var locales: [Locale] {
        switch self {
        case .auto:    return [Locale(identifier: "en-US"), Locale(identifier: "ar-SA")]
        case .english: return [Locale(identifier: "en-US")]
        case .arabic:  return [Locale(identifier: "ar-SA")]
        }
    }
}

struct TranscriptLine: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

/// Live, on-device transcription of the Mac's **system audio** (the call, a video,
/// a lecture) via ScreenCaptureKit. Note: capturing system audio is the ONLY thing
/// that requires "Screen Recording" permission — the app never records or shows
/// your screen, it only reads the audio.
///
/// Lightweight: audio-only (no video frames processed), buffers go straight to the
/// recognizer with no manual resampling. Bilingual "Auto" runs English + Arabic and
/// keeps the stronger hypothesis. Recognizers auto-restart per segment.
final class LiveTranscriber: NSObject, ObservableObject, SCStreamDelegate, SCStreamOutput {
    static let shared = LiveTranscriber()

    @Published var isRunning = false
    @Published var lines: [TranscriptLine] = []
    @Published var partialThem = ""
    @Published var status = "Idle"
    @Published var needsScreenPermission = false
    /// True iff EVERY active recognizer reports `supportsOnDeviceRecognition`.
    /// When false (e.g. an Arabic recognizer that only runs server-side), the
    /// captured audio is sent to Apple's servers — so the footer must say so
    /// truthfully rather than claim "On-device." Defaults to `true` so the
    /// startup state doesn't lie; flipped to the real value when recognizers
    /// are constructed in `startCapture`.
    @Published var isFullyOnDevice: Bool = true
    var language: LiveLang = .auto

    private var stream: SCStream?
    private let queue = DispatchQueue(label: "salehman.live.audio")
    // The worker surface below is CONFINED to `queue` (never the main actor), so
    // `nonisolated(unsafe)` is the honest annotation under MainActor-default
    // isolation: the compiler stops treating these as main-actor state, and the
    // queue closures that touch them stop warning. UI (@Published) state above
    // stays main-actor and is updated only via `DispatchQueue.main.async`.
    private nonisolated(unsafe) var capturing = false        // queue-confined

    // `nonisolated` + `@unchecked Sendable`: a per-recognizer scratch record used
    // ONLY on `queue`. nonisolated so its fields aren't main-actor-isolated;
    // @unchecked Sendable so it can be captured (weakly) by the SFSpeech recognition
    // callback. Safety rests on queue-confinement, not the type system.
    private nonisolated final class LangRec: @unchecked Sendable {
        let recognizer: SFSpeechRecognizer
        var request: SFSpeechAudioBufferRecognitionRequest?
        var task: SFSpeechRecognitionTask?
        var partial = ""
        init(_ r: SFSpeechRecognizer) { recognizer = r }
    }
    private nonisolated(unsafe) var recs: [LangRec] = []     // queue-confined
    private nonisolated(unsafe) var segment = 0
    private let maxLines = 1_500
    private nonisolated(unsafe) var audioBufCount = 0        // queue-confined diagnostic
    private nonisolated(unsafe) var callbackCount = 0        // any-type callback diagnostic
    private nonisolated(unsafe) var lastPublishedPartial = ""        // queue-confined: throttle gate
    private nonisolated(unsafe) var lastPublishAt: CFTimeInterval = 0 // queue-confined: throttle gate

    func toggle() { isRunning ? stop() : start() }

    var combinedText: String {
        var out = lines.map { $0.text }
        if !partialThem.isEmpty { out.append(partialThem) }
        return out.joined(separator: "\n")
    }

    func start() { Task { await begin() } }

    // MARK: Diagnostics
    // Disabled by default — the file I/O ran on the audio queue and caused the
    // lag when the panel opened. Build with -D LIVE_TRANSCRIBE_DEBUG to re-enable.
    // The @autoclosure means the log string isn't even built in release.
    private static let logURL = URL(fileURLWithPath: "/tmp/salehman_live.log")
    private nonisolated func dlog(_ s: @autoclosure () -> String) {
        #if LIVE_TRANSCRIBE_DEBUG
        let line = "\(Date()) \(s())\n"
        guard let data = line.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: Self.logURL) { h.seekToEndOfFile(); h.write(data); try? h.close() }
        else { try? data.write(to: Self.logURL) }
        #endif
    }

    private func begin() async {
        #if LIVE_TRANSCRIBE_DEBUG
        try? "".data(using: .utf8)?.write(to: Self.logURL)
        #endif
        dlog("begin()")
        let speechOK = await requestSpeechAuth()
        dlog("speechAuth=\(speechOK)")
        guard speechOK else { setStatus("Enable Speech Recognition in System Settings → Privacy."); return }

        // System-audio capture needs Screen Recording access (it does NOT share or
        // record your screen). Trigger the prompt up front.
        if !CGPreflightScreenCaptureAccess() {
            let granted = CGRequestScreenCaptureAccess()
            if !granted {
                await MainActor.run {
                    self.needsScreenPermission = true
                    self.status = "Allow Screen Recording to hear the audio (it does NOT show your screen). Then reopen the app."
                }
                return
            }
        }
        await MainActor.run { self.needsScreenPermission = false; self.lines = []; self.partialThem = "" }

        dlog("screenPreflight=\(CGPreflightScreenCaptureAccess())")
        let lang = language
        queue.sync {
            capturing = true
            segment += 1
            audioBufCount = 0
            recs = lang.locales.compactMap { loc in
                guard let r = SFSpeechRecognizer(locale: loc), r.isAvailable else {
                    self.dlog("recognizer \(loc.identifier) unavailable")
                    return nil
                }
                self.dlog("recognizer \(loc.identifier) onDevice=\(r.supportsOnDeviceRecognition)")
                return LangRec(r)
            }
            startTasks()
        }
        guard !recs.isEmpty else {
            setStatus("Speech recognizer for that language isn't available yet. Try again in a moment.")
            return
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = content.displays.first else { setStatus("No display available."); return }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.sampleRate = 48_000
            config.channelCount = 1
            config.excludesCurrentProcessAudio = true   // don't transcribe our own sounds
            // A valid (small) video size + an actually-consumed screen output is
            // required for the stream to start pumping audio. 2x2 silently stalls it.
            config.width = 128; config.height = 72
            config.minimumFrameInterval = CMTime(value: 1, timescale: 2)  // ~2 fps, negligible
            config.queueDepth = 3

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)  // drives the pipeline
            try await stream.startCapture()
            self.stream = stream
            dlog("startCapture OK displays=\(content.displays.count)")
            // Compute the real "is every recognizer running on-device?" answer
            // now that `recs` is set, and publish it so the View's footer label
            // can say "On-device" or "Cloud transcription" honestly.
            let allOnDevice = recs.allSatisfy { $0.recognizer.supportsOnDeviceRecognition }
            await MainActor.run {
                self.isRunning = true
                self.status = "Listening — system audio"
                self.isFullyOnDevice = allOnDevice
            }
        } catch {
            dlog("capture ERROR: \(error)")
            queue.sync { teardownTasks() }
            await MainActor.run {
                self.needsScreenPermission = true
                self.status = "Couldn't start. Allow Screen Recording in System Settings, then reopen. (\(error.localizedDescription))"
            }
        }
    }

    // MARK: - Recognition (queue-only)

    private nonisolated func startTasks() {
        for rec in recs { startTask(rec) }
    }

    private nonisolated func startTask(_ rec: LangRec) {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if rec.recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        req.taskHint = .dictation
        if #available(macOS 13.0, *) { req.addsPunctuation = true }
        rec.request = req
        rec.partial = ""

        let segmentAtStart = segment
        rec.task = rec.recognizer.recognitionTask(with: req) { [weak self, weak rec] result, error in
            guard let self, let rec else { return }
            self.queue.async {
                guard self.capturing, self.segment == segmentAtStart else { return }
                if let result {
                    rec.partial = result.bestTranscription.formattedString
                    if rec.partial.count <= 3 || result.isFinal {
                        // Pre-extract Sendable locals (String/Bool) so the dlog
                        // autoclosure doesn't capture the non-Sendable `rec`/`result`
                        // — otherwise it can't cross into this @Sendable queue block
                        // under the Swift 6 language mode ("sending … () -> String").
                        let loc = rec.recognizer.locale.identifier
                        let isFinal = result.isFinal
                        let preview = String(rec.partial.prefix(40))
                        self.dlog("partial[\(loc)] final=\(isFinal): \(preview)")
                    }
                    self.publishPartial()
                    if result.isFinal { self.commit() }
                } else if let error {
                    let loc = rec.recognizer.locale.identifier
                    let nsErr = error as NSError
                    let dom = nsErr.domain, code = nsErr.code   // Sendable locals
                    self.dlog("rec ERROR[\(loc)]: \(dom) \(code)")
                    self.restart(rec, segmentAtStart: segmentAtStart)
                }
            }
        }
    }

    private nonisolated var bestPartial: String {
        recs.map { $0.partial }.max(by: { $0.count < $1.count }) ?? ""
    }

    private nonisolated func commit() {
        let text = bestPartial.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            DispatchQueue.main.async {
                self.lines.append(TranscriptLine(text: text))
                if self.lines.count > self.maxLines { self.lines.removeFirst(self.lines.count - self.maxLines) }
            }
        }
        DispatchQueue.main.async { self.partialThem = "" }
        // Advance the segment so late callbacks from the just-finished tasks are
        // dropped by the `segment == segmentAtStart` guards.
        segment += 1
        lastPublishedPartial = ""; lastPublishAt = 0   // reset the throttle gate
        guard capturing else { return }
        // Recycle each recognizer's request/task IN PLACE for the next segment.
        // We must NOT call teardownTasks() here — it empties `recs` (and flips
        // `capturing` off), which permanently killed live capture after the
        // first finalized segment (startTasks() then iterated an empty `recs`).
        for rec in recs {
            rec.request?.endAudio(); rec.task?.cancel()
            rec.request = nil; rec.task = nil; rec.partial = ""
            startTask(rec)
        }
    }

    private nonisolated func restart(_ rec: LangRec, segmentAtStart: Int) {
        guard capturing, segment == segmentAtStart else { return }
        rec.task?.cancel(); rec.request?.endAudio()
        rec.task = nil; rec.request = nil; rec.partial = ""
        startTask(rec)
    }

    /// Coalesce partial updates: push to the main actor at most ~9 Hz and only
    /// when the text actually changed. Recognition callbacks fire far faster than
    /// that, and each push re-rendered the whole transcript — the old behavior was
    /// a big part of the lag. `commit()` flushes the final text via teardown.
    private nonisolated func publishPartial() {
        let text = bestPartial
        let now = CACurrentMediaTime()
        guard text != lastPublishedPartial, now - lastPublishAt >= 0.11 else { return }
        lastPublishedPartial = text
        lastPublishAt = now
        DispatchQueue.main.async { self.partialThem = text }
    }

    // MARK: - Audio delivery

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        callbackCount += 1
        if callbackCount <= 4 { dlog("callback#\(callbackCount) type=\(type == .audio ? "audio" : (type == .screen ? "screen" : "other")) ready=\(CMSampleBufferDataIsReady(sampleBuffer))") }
        guard capturing, type == .audio, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        audioBufCount += 1
        if audioBufCount == 1 {
            if let fmt = CMSampleBufferGetFormatDescription(sampleBuffer),
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt) {
                dlog("FIRST audio buf sr=\(asbd.pointee.mSampleRate) ch=\(asbd.pointee.mChannelsPerFrame) flags=\(asbd.pointee.mFormatFlags) frames=\(CMSampleBufferGetNumSamples(sampleBuffer))")
            }
        } else if audioBufCount % 100 == 0 {
            dlog("audio bufs=\(audioBufCount)")
        }

        // Wrap the buffer in its NATIVE format (no resampling) and hand it to each
        // recognizer. This is the reliable SCStream → SFSpeech path.
        guard let pcm = Self.pcmBuffer(from: sampleBuffer) else { dlog("pcm wrap nil"); return }
        for rec in recs { rec.request?.append(pcm) }
    }

    private nonisolated static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let fmtDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc),
              let format = AVAudioFormat(streamDescription: asbd) else { return nil }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0, let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        pcm.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: pcm.mutableAudioBufferList)
        return status == noErr ? pcm : nil
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        dlog("didStopWithError: \(error)")
        DispatchQueue.main.async { self.status = "Stopped: \(error.localizedDescription)"; self.isRunning = false }
        queue.async { self.teardownTasks() }
    }

    func stop() {
        let s = stream
        stream = nil
        Task { try? await s?.stopCapture() }
        queue.async { self.teardownTasks() }
        DispatchQueue.main.async { self.isRunning = false; self.status = "Idle" }
    }

    /// MUST run on `queue`.
    private nonisolated func teardownTasks() {
        capturing = false
        segment += 1
        lastPublishedPartial = ""; lastPublishAt = 0   // reset the throttle gate

        for rec in recs {
            rec.request?.endAudio(); rec.task?.cancel()
            rec.request = nil; rec.task = nil
        }
        recs = []
    }

    private func requestSpeechAuth() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    @MainActor private func setStatus(_ s: String) { status = s }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
