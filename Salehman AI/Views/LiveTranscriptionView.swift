import SwiftUI
import AppKit

struct LiveTranscriptionView: View {
    @ObservedObject private var live = LiveTranscriber.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var copied = false
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")
    var onAsk: (String) -> Void

    private var filteredLines: [TranscriptLine] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return live.lines }
        return live.lines.filter { $0.text.lowercased().contains(q) }
    }

    var body: some View {
        ZStack {
            DS.Palette.codeSurface.ignoresSafeArea()

            // Ambient accent glow — depth on the flat canvas while listening.
            Circle()
                .fill((live.isRunning ? DS.Palette.accent : DS.Palette.accent.opacity(0.5)).opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 200, y: -180)
                .allowsHitTesting(false)
                .animation(DS.Motion.smooth, value: live.isRunning)

            VStack(alignment: .leading, spacing: 14) {
                header
                controls

                if live.needsScreenPermission { permissionBanner }

                Label(live.status, systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)

                searchField
                transcript

                footer
            }
            .padding(22)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .frame(width: 640, height: 660)
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(DS.Motion.smooth) { appeared = true } }
    }

    // MARK: Header
    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.md) {
            // Brand icon tile — matches VoiceModeView and other utility sheets.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Gradient.brand)
                    .frame(width: 36, height: 36)
                    .dsShadow(DS.Elevation.accentGlow(live.isRunning ? 0.55 : 0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.02)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.75)
                    )
                KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.60, duration: 0.07)
                        SpringKeyframe(1.18, spring: .snappy, duration: 0.28)
                        SpringKeyframe(1.0, spring: .bouncy, duration: 0.22)
                    }
                }
            }
            .animation(DS.Motion.smooth, value: live.isRunning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Live Transcription")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Eyebrow(text: "System Audio · On Device")
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(.secondary)
            }.buttonStyle(.plain).accessibilityLabel("Close")
        }
    }

    // MARK: Controls
    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                live.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: live.isRunning ? "stop.fill" : "record.circle")
                    Text(live.isRunning ? "Stop" : "Start listening")
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(live.isRunning ? AnyShapeStyle(DS.Palette.accent) : AnyShapeStyle(Theme.brand), in: Capsule())
                .foregroundStyle(.white)
                .shadow(color: DS.Palette.accent.opacity(0.28), radius: 6, y: 2)
            }
            .buttonStyle(LuxPressStyle())

            Picker("", selection: $live.language) {
                ForEach(LiveLang.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
            .disabled(live.isRunning)

            Spacer()

            if live.isRunning {
                HStack(spacing: 6) {
                    // PhaseAnimator pulses the glow shadow continuously while
                    // recording — makes the dot read as "actively capturing".
                    PhaseAnimator([false, true]) { bright in
                        Circle()
                            .fill(DS.Palette.accent)
                            .frame(width: 8, height: 8)
                            .shadow(color: DS.Palette.accent.opacity(bright ? 0.80 : 0.30),
                                    radius: bright ? 5 : 2)
                    } animation: { bright in
                        bright ? .easeIn(duration: 0.65) : .easeOut(duration: 1.10)
                    }
                    Text("LIVE").font(.caption.weight(.bold)).foregroundStyle(DS.Palette.accent)
                }
            }
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill").foregroundStyle(DS.Palette.accent)
            Text("Allow Screen Recording to hear the audio — it does NOT show your screen.")
                .font(.caption).foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button {
                live.openScreenRecordingSettings()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DS.Palette.accent, in: Capsule())
                    .shadow(color: DS.Palette.accent.opacity(0.25), radius: 4, y: 1)
            }
            .buttonStyle(LuxPressStyle())
        }
        .padding(10)
        // Brand-accent tint instead of off-brand yellow; subtle stroke gives it
        // structure without the harsh banner look.
        .background(DS.Palette.accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
            .stroke(DS.Palette.accent.opacity(0.30), lineWidth: 1))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 12))
            TextField("Search the transcript…", text: $searchText)
                .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(.white)
                .onKeyPress(.escape) { searchText = ""; return .handled }
                .accessibilityLabel("Search transcript")   // placeholder isn't enough for VoiceOver
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    // MARK: Transcript (speaker bubbles + live partials)
    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if live.lines.isEmpty && live.partialThem.isEmpty {
                        Text(live.isRunning ? "Listening…" : "Press Start to transcribe the audio.")
                            .font(.system(size: 14)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 40)
                    }

                    ForEach(searchText.isEmpty ? live.lines : filteredLines) { line in
                        lineView(text: line.text, live: false)
                    }
                    // In-flight (not yet finalized) text, shown faded.
                    if searchText.isEmpty && !live.partialThem.isEmpty {
                        lineView(text: live.partialThem, live: true)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 4)
            }
            .onChange(of: live.lines) { _, _ in scrollDown(proxy, animated: true) }
            .onChange(of: live.partialThem) { _, _ in scrollDown(proxy, animated: false) }
        }
        .frame(maxHeight: .infinity)
    }

    private func scrollDown(_ proxy: ScrollViewProxy, animated: Bool) {
        guard searchText.isEmpty else { return }
        if animated {
            withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.20)) { proxy.scrollTo("bottom", anchor: .bottom) }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)   // partials: no animation (was a lag source)
        }
    }

    private func lineView(text: String, live isLive: Bool) -> some View {
        let rtl = text.range(of: "\\p{Arabic}", options: .regularExpression) != nil
        return Text(text)
            .font(.system(size: 15))
            // 0.55 was ~3.9:1 on the canvas — below WCAG AA's 4.5:1 for body
            // text. 0.66 measures ~5.7:1 while staying clearly subordinate to
            // finalized lines (which run at 0.96).
            .foregroundStyle(.white.opacity(isLive ? 0.66 : 0.96))
            .textSelection(.enabled)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
            .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.white.opacity(isLive ? 0.03 : 0.06),
                        in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
    }

    // MARK: Footer
    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(live.combinedText, forType: .string)
                copied = true
                Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
            } label: {
                Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                    .animation(DS.Motion.smooth, value: copied)
            }
            .buttonStyle(.bordered)
            .disabled(live.combinedText.isEmpty)

            Button {
                let text = live.combinedText
                guard !text.isEmpty else { return }
                onAsk("Here is a live transcript of system audio (a call, video, or lecture). Summarize the key points and list any action items or decisions:\n\n\(text)")
                dismiss()
            } label: { Label("Summarize", systemImage: "list.bullet.rectangle") }
                .buttonStyle(.bordered)
                .disabled(live.combinedText.isEmpty)

            Button {
                let text = live.combinedText
                guard !text.isEmpty else { return }
                onAsk(Self.answerPrompt(transcript: text))
                dismiss()
            } label: {
                Label("Answer the questions", systemImage: "sparkles")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(DS.Palette.accent, in: Capsule())
                    .shadow(color: DS.Palette.accent.opacity(0.28), radius: 5, y: 2)
            }
            .buttonStyle(LuxPressStyle())
            .disabled(live.combinedText.isEmpty)

            Spacer()
            // Honest footer: only say "On-device" when every active recognizer
            // actually runs locally (e.g. ar-SA historically has no on-device
            // model, so SFSpeechRecognizer routes Arabic audio to Apple's
            // servers). The Bool comes from LiveTranscriber, set when the
            // recognizers are constructed in startCapture.
            Text(live.isFullyOnDevice
                 ? "On-device • system audio"
                 : "Cloud transcription • system audio (no on-device model for this language)")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// Extract every question from the transcript and answer each thoroughly.
    static func answerPrompt(transcript: String) -> String {
        """
        Below is a live transcript of system audio (a call, video, or lecture). \
        It may mix English and Arabic.

        1. Identify EVERY question that was asked (including implied/follow-up ones).
        2. Answer each clearly, correctly, and completely. Use your knowledge, and \
           use web_search / run_terminal_command when current facts or details \
           about this Mac are needed.
        3. If a question is ambiguous, state the most likely meaning and answer it.
        4. Format as a list: the question in bold, the answer beneath it.
        5. Reply in the language each question was asked in.

        If there are no real questions, give a concise summary plus action items.

        TRANSCRIPT:
        \(transcript)
        """
    }
}
