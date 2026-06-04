import SwiftUI

// MARK: - Theme
// Legacy brand surface — now a thin forwarding layer over the `DS` design
// system (DesignSystem.swift). Existing `Theme.*` call sites keep working;
// new code should use `DS.*` directly.
enum Theme {
    static let accent = DS.Palette.accent
    static let accent2 = DS.Palette.accent2
    static let bgTop = DS.Palette.bgTop
    static let bgBottom = DS.Palette.bgBottom
    static let userBubble = DS.Gradient.userBubble
    static let brand = DS.Gradient.brand
}

struct ContentView: View {
    @State private var mission: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isRunning: Bool = false
    @FocusState private var inputFocused: Bool
    @ObservedObject private var approval = CommandApprovalCenter.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var brain = BrainStatus.shared
    @State private var attachment: Attachment?
    @State private var loadingAttachment = false
    @State private var runningTask: Task<Void, Never>?
    @State private var showSettings = false
    @State private var showLive = false
    @State private var searching = false
    @State private var searchQuery = ""
    @ObservedObject private var speechIn = SpeechIn.shared
    @ObservedObject private var app = AppState.shared
    @ObservedObject private var library = PromptLibrary.shared
    @State private var savingPrompt = false
    @State private var newPromptTitle = ""

    private struct Suggestion: Hashable {
        let icon: String
        let title: String
        let subtitle: String
        let prompt: String
    }

    private let suggestions: [Suggestion] = [
        .init(icon: "desktopcomputer", title: "Inspect this Mac",
              subtitle: "macOS version, hardware, uptime",
              prompt: "What macOS version am I running, and give me a quick hardware summary."),
        .init(icon: "folder", title: "Find files",
              subtitle: "List what's on the Desktop",
              prompt: "List the files on my Desktop, grouped by kind."),
        .init(icon: "internaldrive", title: "Storage health",
              subtitle: "Free space + heaviest folders",
              prompt: "How much free disk space do I have, and what are the heaviest folders in my home directory?"),
        .init(icon: "photo.on.rectangle", title: "Change my wallpaper",
              subtitle: "Pick from a few options",
              prompt: "Change my wallpaper. Suggest a few options first."),
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Divider().overlay(Color.white.opacity(0.06))
                conversation
                inputBar
            }
        }
        .preferredColorScheme(.dark)
        .overlay {
            if let pending = approval.pending {
                ApprovalCard(command: pending.command,
                             onRun: { approval.resolve(true) },
                             onCancel: { approval.resolve(false) },
                             onAlways: { approval.alwaysAllow() })
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(DS.Motion.spring, value: approval.pending?.id)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLive) { LiveTranscriptionView(onAsk: { send($0) }) }
        .alert("Save prompt", isPresented: $savingPrompt) {
            TextField("Name", text: $newPromptTitle)
            Button("Save") { library.add(title: newPromptTitle, text: mission) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save the current message as a reusable prompt.")
        }
        .onAppear {
            if messages.isEmpty { messages = ChatStore.load() }
            AppSettings.shared.applyCapturePrivacy()
        }
        .onChange(of: messages) { _ in ChatStore.scheduleSave(messages) }
        .onDisappear { ChatStore.flushSave() }
        .onChange(of: speechIn.transcript) { t in if speechIn.isListening { mission = t } }
        // Menu-bar command bridges (two-parameter onChange: $1 is the NEW value).
        .onChange(of: app.newChatRequested) { _, v in if v { startNewChat(); app.newChatRequested = false } }
        .onChange(of: app.stopRequested) { _, v in if v { stop(); app.stopRequested = false } }
        .onChange(of: app.showSettingsRequested) { _, v in if v { showSettings = true; app.showSettingsRequested = false } }
        .onChange(of: app.showLiveRequested) { _, v in if v { showLive = true; app.showLiveRequested = false } }
        .onChange(of: app.toggleSearchRequested) { _, v in
            if v { withAnimation(DS.Motion.snappy) { searching.toggle(); if !searching { searchQuery = "" } }; app.toggleSearchRequested = false }
        }
    }

    // MARK: Background
    private var background: some View { BackgroundView() }

    // MARK: Header
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.brand)
                    .frame(width: 34, height: 34)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 8, y: 3)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Salehman AI")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 5) {
                    Circle()
                        .fill(isRunning ? Color.purple : brain.dotColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: (isRunning ? Color.purple : brain.dotColor).opacity(0.6), radius: 3)
                    Text(isRunning ? "Thinking…" : brain.label)
                        .font(.caption2)
                        .foregroundStyle(isRunning ? .secondary : brain.labelColor)
                }
            }

            Spacer()

            // Export conversation
            Menu {
                Button { ChatExporter.copyToPasteboard(messages) } label: {
                    Label("Copy as Markdown", systemImage: "doc.on.clipboard")
                }
                Button { ChatExporter.savePanel(messages) } label: {
                    Label("Save as Markdown…", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30)
            .disabled(messages.isEmpty)
            .help("Export this conversation")

            // Search
            CircleIconButton(systemName: "magnifyingglass",
                             tint: searching ? Theme.accent : .secondary,
                             help: "Find in conversation (⌘F)") {
                withAnimation(DS.Motion.snappy) { searching.toggle() }
            }

            // Live transcription (stealth)
            CircleIconButton(systemName: "waveform.badge.mic",
                             tint: LiveTranscriber.shared.isRunning ? .red : .secondary,
                             ring: LiveTranscriber.shared.isRunning ? .red : nil,
                             help: "Live transcription (captures the call, stays hidden)") { showLive = true }

            // Settings
            CircleIconButton(systemName: "gearshape.fill", help: "Settings") { showSettings = true }

            // New chat
            CircleIconButton(systemName: "square.and.pencil", help: "New chat") { startNewChat() }

            // Confirmation toggle — calm chip with a colored dot, no shouty fill.
            ConfirmationChip(enabled: $approval.confirmationEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: Conversation
    private var filteredMessages: [ChatMessage] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searching, !q.isEmpty else { return messages }
        return messages.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            if searching { searchBar }
            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty && !isRunning {
                        emptyState
                            .padding(.top, 60)
                            .padding(.horizontal, 24)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredMessages) { MessageBubble(message: $0, onRegenerate: regenerate) }
                            if isRunning { RunningProgressView() }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 22)
                    }
                }
                .onChange(of: messages.count) { _ in scrollToBottom(proxy) }
                .onChange(of: isRunning) { _ in scrollToBottom(proxy) }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find in conversation…", text: $searchQuery)
                .textFieldStyle(.plain)
            if !searchQuery.isEmpty {
                Text("\(filteredMessages.count) match\(filteredMessages.count == 1 ? "" : "es")")
                    .font(.caption2).foregroundStyle(.secondary)
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            Button("Done") { withAnimation(DS.Motion.snappy) { searching = false; searchQuery = "" } }
                .buttonStyle(.plain).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .bottom)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(DS.Motion.smooth) {
            if isRunning { proxy.scrollTo("typing", anchor: .bottom) }
            else { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
        }
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 28) {
            // Floating logo with twin glow halos.
            ZStack {
                Circle().fill(Theme.accent.opacity(0.18))
                    .frame(width: 130, height: 130).blur(radius: 40)
                Circle().fill(Theme.accent2.opacity(0.16))
                    .frame(width: 110, height: 110).blur(radius: 36)
                    .offset(x: 18, y: 8)
                ZStack {
                    Circle().fill(Theme.brand).frame(width: 72, height: 72)
                        .shadow(color: Theme.accent.opacity(0.55), radius: 22, y: 8)
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 10) {
                Eyebrow(text: "Salehman AI · On-device")
                Text("How can I help, Saleh?")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Ask me anything, or let me run things on your Mac.")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // 2×2 Bento of rich SuggestionCards.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(suggestions, id: \.self) { s in
                    SuggestionCard(icon: s.icon, title: s.title, subtitle: s.subtitle) {
                        send(s.prompt)
                    }
                }
            }
            .frame(maxWidth: 540)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }

    // MARK: Input bar
    private var inputBar: some View {
        VStack(spacing: 8) {
            // Pending attachment chip
            if loadingAttachment {
                attachmentChip(icon: "hourglass", title: "Reading attachment…", removable: false)
            } else if let att = attachment {
                attachmentChip(icon: att.icon, title: "\(att.name) · \(att.kind)", removable: true)
            }

            HStack(spacing: 10) {
                // Attach menu (+)
                Menu {
                    Button { Task { await attachFile() } } label: {
                        Label("Attach file…", systemImage: "doc")
                    }
                    Button { Task { await attachImage() } } label: {
                        Label("Attach image", systemImage: "photo")
                    }
                    Button { Task { await attachLastScreenshot() } } label: {
                        Label("Send last screenshot", systemImage: "camera.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 40)
                .help("Attach a file, image, or your last screenshot")

                // Prompt library
                Menu {
                    if library.prompts.isEmpty {
                        Text("No saved prompts yet")
                    } else {
                        Section("Insert a prompt") {
                            ForEach(library.prompts) { p in
                                Button(p.title) { insertPrompt(p.text) }
                            }
                        }
                    }
                    Divider()
                    Button {
                        newPromptTitle = ""
                        savingPrompt = true
                    } label: { Label("Save current as prompt…", systemImage: "plus") }
                        .disabled(mission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } label: {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 40)
                .help("Insert or save a reusable prompt")

                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                    TextField("Message Salehman AI…", text: $mission, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .focused($inputFocused)
                        .onSubmit { send(mission) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(inputFocused ? Theme.accent.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1))

                // Mic (dictation)
                CircleIconButton(systemName: speechIn.isListening ? "mic.fill" : "mic",
                                 size: 40, iconSize: 16,
                                 tint: speechIn.isListening ? .red : .white,
                                 ring: speechIn.isListening ? .red : nil,
                                 help: "Dictate with your voice") { speechIn.toggle() }

                // Stop while generating, otherwise Send
                if isRunning {
                    CircleIconButton(systemName: "stop.fill", size: 40, iconSize: 15,
                                     tint: .red, ring: .red,
                                     help: "Stop generating (⌘.)") { stop() }
                        .transition(.scale.combined(with: .opacity))
                } else {
                    CircleIconButton(systemName: "arrow.up", size: 40, iconSize: 16,
                                     tint: .white, filled: canSend, disabled: !canSend,
                                     help: "Send") { send(mission) }
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .animation(DS.Motion.snappy, value: isRunning)
    }

    private func attachmentChip(icon: String, title: String, removable: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1)
            if removable {
                Button { attachment = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canSend: Bool {
        guard !isRunning, !loadingAttachment else { return false }
        return !mission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil
    }

    // MARK: Attachment actions
    @MainActor private func attachFile() async {
        guard let url = AttachmentLoader.pickFile() else { return }
        loadingAttachment = true
        attachment = await AttachmentLoader.load(url: url)
        loadingAttachment = false
        inputFocused = true
    }

    @MainActor private func attachImage() async {
        guard let url = AttachmentLoader.pickFile() else { return }
        loadingAttachment = true
        attachment = await AttachmentLoader.load(url: url)
        loadingAttachment = false
        inputFocused = true
    }

    @MainActor private func attachLastScreenshot() async {
        loadingAttachment = true
        if let url = AttachmentLoader.lastScreenshot() {
            attachment = await AttachmentLoader.load(url: url)
        } else if let url = AttachmentLoader.captureNow() {
            // No saved screenshot found — capture the screen right now instead.
            attachment = await AttachmentLoader.load(url: url)
        } else {
            attachment = Attachment(name: "No screenshot found", kind: "note",
                                    icon: "exclamationmark.triangle",
                                    extractedText: "Could not find a recent screenshot.")
        }
        loadingAttachment = false
        inputFocused = true
    }

    private func insertPrompt(_ text: String) {
        mission = text
        inputFocused = true
    }

    // MARK: New chat / stop
    private func startNewChat() {
        stop()
        Task { await Orchestrator.reset() }
        withAnimation(DS.Motion.spring) { messages.removeAll() }
        searching = false
        searchQuery = ""
    }

    /// Cancel an in-flight response and return the UI to a ready state.
    private func stop() {
        runningTask?.cancel()
        runningTask = nil
        isRunning = false
        MissionProgress.shared.finish()
    }

    /// Re-answer: drop this assistant reply (and anything after it) and re-run
    /// the user message that preceded it, without duplicating the user bubble.
    private func regenerate(_ message: ChatMessage) {
        guard !isRunning, !message.isUser, let idx = messages.firstIndex(of: message) else { return }
        guard let priorUser = messages[..<idx].last(where: { $0.isUser }) else { return }
        // Strip any "📎 attachment" marker line from the displayed user text.
        let clean = priorUser.text
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("📎") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        withAnimation(DS.Motion.fade) { messages.removeSubrange(idx...) }
        send(clean, recordUser: false)
    }

    // MARK: Send
    private func send(_ text: String, recordUser: Bool = true) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isRunning, !loadingAttachment else { return }
        let att = attachment
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
        mission = ""
        attachment = nil
        isRunning = true
        inputFocused = true

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

            let result = await Orchestrator.runAndReturnResult(mission: missionToSend)
            if Task.isCancelled { return }
            await MainActor.run {
                let reply = ChatMessage(id: UUID(), text: result.output, isUser: false,
                                        timestamp: Date(), imagePath: GeneratedMedia.shared.consume())
                messages.append(reply)
                isRunning = false
                if AppSettings.shared.autoSpeak {
                    SpeechOut.shared.speak(result.output, id: reply.id)
                }
            }
        }
    }

    // MARK: Media transcription (YouTube link / audio file → transcript + summary)
    private func transcribeMedia(_ source: MediaTranscribe.Source, raw: String) {
        messages.append(ChatMessage(id: UUID(), text: raw, isUser: true, timestamp: Date()))
        mission = ""
        isRunning = true            // reuse the existing typing indicator
        inputFocused = true

        runningTask = Task {
            let transcript = await MediaTranscribe.transcribe(source)
            if Task.isCancelled { return }

            // 1) Post the raw transcript.
            await MainActor.run {
                messages.append(ChatMessage(id: UUID(), text: "📝 Transcript\n\n\(transcript)",
                                            isUser: false, timestamp: Date()))
            }

            // Skip the summary if transcription failed or there's too little text.
            guard transcript.count > 40,
                  !transcript.hasPrefix("Couldn't"),
                  !transcript.contains("no captions") else {
                await MainActor.run { isRunning = false }
                return
            }

            // 2) Auto-summarize (cap the input so the on-device model isn't overrun).
            let capped = transcript.count > 8000 ? String(transcript.prefix(8000)) + "…" : transcript
            let prompt = "Summarize this transcript and list the key points and any "
                       + "action items. Reply in the transcript's language:\n\n\(capped)"
            let result = await Orchestrator.runAndReturnResult(mission: prompt)
            if Task.isCancelled { return }
            await MainActor.run {
                let reply = ChatMessage(id: UUID(), text: result.output, isUser: false, timestamp: Date())
                messages.append(reply)
                isRunning = false
                if AppSettings.shared.autoSpeak {
                    SpeechOut.shared.speak(result.output, id: reply.id)
                }
            }
        }
    }
}

// MARK: - Confirmation chip (header)
// Calmer replacement for the saturated green/orange pill. A small dot carries
// the state signal (green = confirm, amber = auto-run) and the chip itself stays
// neutral glass — premium, not alarmist.
private struct ConfirmationChip: View {
    @Binding var enabled: Bool
    @State private var hovering = false

    private var dotColor: Color {
        enabled ? Color(red: 0.45, green: 0.85, blue: 0.55) : Color(red: 1.0, green: 0.72, blue: 0.35)
    }

    var body: some View {
        Button {
            withAnimation(DS.Motion.smooth) { enabled.toggle() }
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    Circle().fill(dotColor).frame(width: 7, height: 7)
                    Circle().fill(dotColor.opacity(0.35)).frame(width: 13, height: 13).blur(radius: 3)
                }
                Text(enabled ? "Confirm" : "Auto-run")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.white.opacity(hovering ? 0.10 : 0.06))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(hovering ? 0.18 : 0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
        .help(enabled
              ? "You'll approve each terminal command before it runs."
              : "Commands run automatically. Click to require approval.")
    }
}

// MARK: - Background (state-free so SwiftUI keeps it stable across body redraws)
private struct BackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Soft glows for depth. Smaller blur than before — 160px convolves
            // every frame and was the dominant GPU cost on integrated Macs.
            Circle().fill(Theme.accent.opacity(0.18)).frame(width: 480).blur(radius: 90)
                .offset(x: -220, y: -260)
            Circle().fill(Theme.accent2.opacity(0.16)).frame(width: 420).blur(radius: 90)
                .offset(x: 260, y: 300)
        }
        .ignoresSafeArea()
        .drawingGroup()
    }
}

// MARK: - Running progress (isolates MissionProgress observation so streaming
// tokens don't invalidate ContentView's body and rerun the LazyVStack diff)
private struct RunningProgressView: View {
    @ObservedObject private var progress = MissionProgress.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 9) {
                if progress.steps.isEmpty {
                    TypingIndicator()
                } else {
                    AgentRunView(steps: progress.steps)
                }
                Spacer(minLength: 48)
            }
            if !progress.streamingAnswer.isEmpty {
                HStack(alignment: .bottom, spacing: 9) {
                    StreamingBubble(text: progress.streamingAnswer)
                    Spacer(minLength: 48)
                }
            }
        }
        .id("typing")
    }
}

// MARK: - Models
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    var imagePath: String? = nil
}

/// Saves/loads the conversation so it survives quitting the app.
enum ChatStore {
    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SalehmanAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chat_history.json")
    }

    static func load() -> [ChatMessage] {
        guard let data = try? Data(contentsOf: fileURL),
              let msgs = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return [] }
        return msgs
    }

    static func save(_ messages: [ChatMessage]) {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // Debounced save: coalesce rapid message-array changes (typing, streaming
    // updates) into a single disk write a short time after the last change.
    @MainActor private static var pendingTask: Task<Void, Never>?
    @MainActor private static var pending: [ChatMessage] = []

    @MainActor static func scheduleSave(_ messages: [ChatMessage]) {
        pending = messages
        pendingTask?.cancel()
        pendingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            if Task.isCancelled { return }
            let snapshot = pending
            await Task.detached(priority: .utility) { save(snapshot) }.value
        }
    }

    @MainActor static func flushSave() {
        pendingTask?.cancel()
        pendingTask = nil
        let snapshot = pending
        if !snapshot.isEmpty { save(snapshot) }
    }
}

// MARK: - Markdown export
enum ChatExporter {
    static func markdown(_ messages: [ChatMessage]) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium; df.timeStyle = .short
        var out = "# Salehman AI — Conversation\n\n"
        for m in messages {
            let who = m.isUser ? "You" : "Salehman AI"
            out += "**\(who)** · \(df.string(from: m.timestamp))\n\n\(m.text)\n\n---\n\n"
        }
        return out
    }

    @MainActor static func copyToPasteboard(_ messages: [ChatMessage]) {
        guard !messages.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown(messages), forType: .string)
    }

    @MainActor static func savePanel(_ messages: [ChatMessage]) {
        guard !messages.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Salehman AI Conversation.md"
        panel.canCreateDirectories = true
        panel.title = "Export Conversation"
        if panel.runModal() == .OK, let url = panel.url {
            try? markdown(messages).data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    var onRegenerate: ((ChatMessage) -> Void)? = nil
    @ObservedObject private var speech = SpeechOut.shared
    @State private var hovering = false
    @State private var appeared = false   // drives fade-up-blur entry

    var body: some View {
        bubbleRow
            .opacity(appeared ? 1 : 0)
            .blur(radius: appeared ? 0 : 6)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                // Skip the entry choreography on cells SwiftUI is reusing during
                // a scroll redraw — only animate the first time this bubble's
                // identity reaches the screen.
                guard !appeared else { return }
                withAnimation(DS.Motion.cinematic) { appeared = true }
            }
    }

    private var bubbleRow: some View {
        HStack(alignment: .bottom, spacing: 9) {
            if message.isUser { Spacer(minLength: 48) } else { avatar }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 3) {
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        if message.isUser {
                            Text(message.text)
                                .font(.system(size: 14))
                                .textSelection(.enabled)
                                .foregroundStyle(.white)
                        } else {
                            MarkdownText(text: message.text)
                                .foregroundStyle(Color.white.opacity(0.92))
                        }
                        if let path = message.imagePath {
                            CachedImage(path: path)
                                .frame(maxWidth: 360, maxHeight: 360)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(message.isUser ? 0 : 0.07), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

                HStack(spacing: 10) {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if !message.isUser {
                        actionButton(speech.speakingID == message.id ? "speaker.wave.2.fill" : "speaker.wave.2",
                                     "Read aloud", active: speech.speakingID == message.id) {
                            speech.toggle(message.text, id: message.id)
                        }
                    }
                    if hovering {
                        actionButton("doc.on.doc", "Copy") { copyText() }
                        if !message.isUser, onRegenerate != nil {
                            actionButton("arrow.clockwise", "Regenerate") { onRegenerate?(message) }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .animation(DS.Motion.fade, value: hovering)
            }

            if message.isUser { userAvatar } else { Spacer(minLength: 48) }
        }
        .onHover { hovering = $0 }
    }

    private func actionButton(_ icon: String, _ help: String, active: Bool = false,
                              _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(active ? Theme.accent : .secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.text, forType: .string)
    }

    @ViewBuilder private var bubbleBackground: some View {
        if message.isUser {
            Theme.userBubble
        } else {
            Color.white.opacity(0.07)
        }
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Theme.brand).frame(width: 30, height: 30)
                .shadow(color: Theme.accent.opacity(0.5), radius: 6, y: 2)
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var userAvatar: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.12)).frame(width: 30, height: 30)
            Image(systemName: "person.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - Cached image (loads from disk once on appear, not on every render)
struct CachedImage: View {
    let path: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.white.opacity(0.04)
            }
        }
        .task(id: path) {
            let p = path
            let loaded: NSImage? = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOfFile: p)
            }.value
            if !Task.isCancelled { self.image = loaded }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().fill(Theme.brand).frame(width: 30, height: 30)
                Image(systemName: "sparkles").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            }
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .opacity(animating ? 1 : 0.4)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                                   value: animating)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .onAppear { animating = true }
    }
}

// MARK: - Agent Run View (live multi-agent progress)
struct AgentRunView: View {
    let steps: [MissionProgress.Step]

    private var doneCount: Int { steps.filter { $0.status == .done }.count }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            ZStack {
                Circle().fill(Theme.brand).frame(width: 30, height: 30)
                Image(systemName: "sparkles").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Agent team working")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(doneCount)/\(steps.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(steps) { step in
                        AgentRow(step: step)
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
}

struct AgentRow: View {
    let step: MissionProgress.Step

    private var isPending: Bool { step.status == .pending }

    var body: some View {
        HStack(spacing: 8) {
            statusIcon.frame(width: 16)
            Image(systemName: step.icon)
                .font(.system(size: 11))
                .foregroundStyle(isPending ? Color.secondary : Theme.accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(step.adapted ?? step.name)
                    .font(.system(size: 12, weight: step.adapted == nil ? .regular : .medium))
                    .foregroundStyle(isPending ? Color.secondary : Color.white.opacity(0.92))
                if step.adapted != nil {
                    Text(step.name)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .opacity(isPending ? 0.55 : 1)
    }

    @ViewBuilder private var statusIcon: some View {
        switch step.status {
        case .done:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(.green)
        case .running:
            ProgressView().controlSize(.small).scaleEffect(0.7)
        case .pending:
            Image(systemName: "circle").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Streaming Bubble (final answer as it generates)
struct StreamingBubble: View {
    let text: String
    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            ZStack {
                Circle().fill(Theme.brand).frame(width: 30, height: 30)
                Image(systemName: "sparkles").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            }
            MarkdownText(text: text)
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
    }
}

// MARK: - Approval Card
struct ApprovalCard: View {
    let command: String
    let onRun: () -> Void
    let onCancel: () -> Void
    let onAlways: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                // Top
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.18)).frame(width: 52, height: 52)
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    Text("Run this command?")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Salehman AI wants to run a command on your Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)

                // Command
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(command)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                }
                .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(20)

                // Buttons
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button("Cancel", action: onCancel)
                            .buttonStyle(SecondaryButtonStyle())
                            .keyboardShortcut(.cancelAction)

                        Button("Run", action: onRun)
                            .buttonStyle(PrimaryButtonStyle())
                            .keyboardShortcut(.defaultAction)
                    }
                    Button(action: onAlways) {
                        Text("Always run without asking")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 380)
            .background(Color(red: 0.10, green: 0.11, blue: 0.16), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
        }
    }
}
