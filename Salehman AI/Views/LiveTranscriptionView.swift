import SwiftUI
import AppKit

struct LiveTranscriptionView: View {
    @ObservedObject private var live = LiveTranscriber.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    var onAsk: (String) -> Void

    private var filteredLines: [TranscriptLine] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return live.lines }
        return live.lines.filter { $0.text.lowercased().contains(q) }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.12), Color.black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

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
        }
        .frame(width: 640, height: 660)
        .preferredColorScheme(.dark)
    }

    // MARK: Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Live Transcription").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Transcribes the Mac's audio live (a call, video, or lecture)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
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
                .background(live.isRunning ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.brand), in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Picker("", selection: $live.language) {
                ForEach(LiveLang.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
            .disabled(live.isRunning)

            Spacer()

            if live.isRunning {
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("LIVE").font(.caption.weight(.bold)).foregroundStyle(.red)
                }
            }
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.yellow)
            Text("Allow Screen Recording to hear the audio — it does NOT show your screen.")
                .font(.caption).foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button("Open Settings") { live.openScreenRecordingSettings() }
                .buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(10)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 12))
            TextField("Search the transcript…", text: $searchText)
                .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(.white)
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
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
            withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)   // partials: no animation (was a lag source)
        }
    }

    private func lineView(text: String, live isLive: Bool) -> some View {
        let rtl = text.range(of: "\\p{Arabic}", options: .regularExpression) != nil
        return Text(text)
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(isLive ? 0.55 : 0.96))
            .textSelection(.enabled)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
            .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.white.opacity(isLive ? 0.03 : 0.06),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Footer
    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(live.combinedText, forType: .string)
            } label: { Label("Copy", systemImage: "doc.on.doc") }
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
            } label: { Label("Answer the questions", systemImage: "sparkles") }
                .buttonStyle(.borderedProminent)
                .disabled(live.combinedText.isEmpty)

            Spacer()
            Text("On-device • system audio").font(.caption2).foregroundStyle(.secondary)
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
