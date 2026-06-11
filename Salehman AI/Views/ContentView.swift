import SwiftUI
import AppKit

// MARK: - Theme
// Legacy brand surface — now a thin forwarding layer over the `DS` design
// system (DesignSystem.swift). Existing `Theme.*` call sites keep working;
// new code should use `DS.*` directly.
enum Theme {
    static let accent = DS.Palette.accent
    static let accent2 = DS.Palette.accent2
    static let bgTop = DS.Palette.bgTop
    static let bgBottom = DS.Palette.bgBottom
    static let brand = DS.Gradient.brand
}

struct ContentView: View {
    @State private var mission: String = ""
    @StateObject private var vm = ChatViewModel()
    @FocusState private var inputFocused: Bool
    @ObservedObject private var approval = CommandApprovalCenter.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var brainStatus = BrainStatus.shared
    @State private var attachment: Attachment?
    @State private var loadingAttachment = false
    @State private var showSettings = false
    @State private var dismissedCloudHint = false   // per-session dismiss of the no-cloud-key banner
    @State private var showLive = false
    @State private var searching = false
    @State private var searchQuery = ""
    // Floating scroll-to-latest pill: `atBottom` is flipped by a 1pt invisible
    // sentinel inside the LazyVStack via .onAppear/.onDisappear (no parallel
    // scrollPosition binding → no risk of double-firing the existing
    // scrollToBottom(proxy) on new messages). `unreadCount` accumulates only
    // when new messages arrive WHILE scrolled up.
    @State private var atBottom: Bool = true
    @State private var unreadCount: Int = 0
    @ObservedObject private var speechIn = SpeechIn.shared
    @ObservedObject private var app = AppState.shared
    @ObservedObject private var library = PromptLibrary.shared
    @State private var savingPrompt = false
    @State private var newPromptTitle = ""

    // Drives the "alive" pulse on the Unrestricted Mode indicator.
    @State private var unrestrictedPulse = false

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
            // Flat opaque chat canvas (design language): no glow show-through,
            // no translucent stacking — same shade as the Code tab's canvas.
            DS.Palette.codeSurface.ignoresSafeArea()

            // Global red tint when Unrestricted Mode is active.
            if settings.unrestrictedTools {
                Color.red.opacity(0.03).ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Warning banner appears above the normal header when active.
                if settings.unrestrictedTools {
                    unrestrictedBanner
                }
                // No-cloud-key notice: the selected brain is silently on the slow
                // local fallback (or unavailable). Tap "Add key" → Settings.
                if LocalLLM.lacksCloudKey && !dismissedCloudHint {
                    CloudKeyHintBanner(onAddKey: { showSettings = true },
                                       onDismiss: { dismissedCloudHint = true })
                }
                header
                Divider().overlay(Color.white.opacity(0.06))
                conversation
                inputBar
                    // Input pill aligns to the same 780pt reading column as the
                    // transcript (design language).
                    .frame(maxWidth: 780)
                    .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .overlay {
            if let pending = approval.pending, !settings.unrestrictedTools {
                ApprovalCard(command: pending.command,
                             onRun: { approval.resolve(true) },
                             onCancel: { approval.resolve(false) },
                             onAlways: { approval.alwaysAllow() })
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(DS.Motion.spring, value: approval.pending?.id)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLive) { LiveTranscriptionView(onAsk: { submit($0) }) }
        .alert("Save prompt", isPresented: $savingPrompt) {
            TextField("Name", text: $newPromptTitle)
            Button("Save") { library.add(title: newPromptTitle, text: mission) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save the current message as a reusable prompt.")
        }
        .onAppear {
            if vm.messages.isEmpty { vm.messages = ChatStore.load() }
            AppSettings.shared.applyCapturePrivacy()
            ChatStore.installTerminationFlush()
        }
        .onChange(of: vm.messages) { _, new in ChatStore.scheduleSave(new) }
        .onDisappear { ChatStore.flushSave() }
        .onChange(of: speechIn.transcript) { _, t in if speechIn.isListening { mission = t } }
        // Menu-bar command bridges (two-parameter onChange: $1 is the NEW value).
        .onChange(of: app.newChatRequested) { _, v in if v { newChat(); app.newChatRequested = false } }
        .onChange(of: app.stopRequested) { _, v in if v { vm.stop(); app.stopRequested = false } }
        .onChange(of: app.showSettingsRequested) { _, v in if v { showSettings = true; app.showSettingsRequested = false } }
        .onChange(of: app.showLiveRequested) { _, v in if v { showLive = true; app.showLiveRequested = false } }
        .onChange(of: app.toggleSearchRequested) { _, v in
            if v { withAnimation(DS.Motion.snappy) { searching.toggle(); if !searching { searchQuery = "" } }; app.toggleSearchRequested = false }
        }
        .onChange(of: settings.unrestrictedTools) { _, isUnrestricted in
            if isUnrestricted {
                approval.confirmationEnabled = false
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    unrestrictedPulse = true
                }
            } else {
                unrestrictedPulse = false
            }
        }
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: 12) {
            // The brand sparkles-tile + name already lives in the top tab bar.
            // Repeating either here read as the icon (and the name) appearing
            // TWICE on the Chat screen. The chat header now leads ONLY with
            // WHO is answering (live brain + status), which is the useful,
            // non-redundant info for this row.
            HStack(spacing: 8) {
                // Status indicator with a brand-accent halo that EXPANDS + pulses
                // while running (was a flat off-brand purple dot — the most
                // visible "AI is working" affordance in the chrome).
                if settings.unrestrictedTools {
                    // Red pulsing halo for Unrestricted Mode (alive / "always on" signal)
                    ZStack {
                        Circle().fill(Color.red.opacity(0.4))
                            .frame(width: 22, height: 22)
                            .blur(radius: 5)
                            .scaleEffect(unrestrictedPulse ? 1.45 : 1.0)
                            .opacity(unrestrictedPulse ? 0.6 : 0.4)
                        Circle().fill(Color.red)
                            .frame(width: 7, height: 7)
                            .shadow(color: Color.red.opacity(0.6), radius: 3)
                    }
                    Text(vm.isRunning ? "UNRESTRICTED • Thinking…" : "UNRESTRICTED")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.red)
                } else {
                    BrainStatusDot(isRunning: vm.isRunning, color: brainStatus.dotColor)
                    // AI status shown as a per-brain GLYPH, not a text label: the
                    // colored dot + a brain icon that pulses while thinking. The
                    // brain name stays available on hover and to VoiceOver.
                    Image(systemName: brainStatus.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            vm.isRunning
                                ? AnyShapeStyle(LinearGradient(colors: [DS.Palette.accent, DS.Palette.accent2],
                                                               startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(brainStatus.dotColor)
                        )
                        .symbolEffect(.pulse, isActive: vm.isRunning)
                        .help(vm.isRunning ? "Thinking…" : brainStatus.label)
                    // SuperGrok upgrade: show the DS badge (violet capsule + bolt)
                    // when the Grok brain is active. Tapping opens Settings so the
                    // user can complete the Anthropic→Grok migration or confirm
                    // the key/model. This surfaces the "Super" path directly in
                    // the primary chat chrome without cluttering local/Apple modes.
                    if brainStatus.brain == .grok {
                        SuperGrokBadge(text: "SUPER GROK") {
                            app.showSettingsRequested = true
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(settings.unrestrictedTools 
                ? "Salehman AI, Unrestricted Mode"
                : (vm.isRunning ? "Salehman AI, thinking" : "Salehman AI, \(brainStatus.label)"))

            Spacer()

            // Export conversation
            Menu {
                Button { ChatExporter.copyToPasteboard(vm.messages) } label: {
                    Label("Copy as Markdown", systemImage: "doc.on.clipboard")
                }
                Button { ChatExporter.savePanel(vm.messages) } label: {
                    Label("Save as Markdown…", systemImage: "square.and.arrow.down")
                }
                Divider()
                Button { TrainingExporter.savePanel(messages: vm.messages) } label: {
                    Label("Export Training Data (JSONL)…", systemImage: "brain")
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
            .disabled(vm.messages.isEmpty)
            .help("Export this conversation")
            .accessibilityLabel("Export this conversation")

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

            // (Settings icon was here — now lives in the top TabSwitcherBar next
            // to the market pill, so it's reachable from every tab, not just Chat.
            // ContentView still owns the `.sheet`; AppState.showSettingsRequested
            // is the bridge that opens it.)

            // New chat
            CircleIconButton(systemName: "square.and.pencil", help: "New chat") { newChat() }

            if settings.unrestrictedTools {
                // Prominent Unrestricted Mode badge (red, tappable to exit the mode)
                Button {
                    settings.unrestrictedTools = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("UNRESTRICTED")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Unrestricted Mode is active — tap to disable")
            } else {
                // Confirmation toggle — calm chip with a colored dot, no shouty fill.
                ConfirmationChip(enabled: $approval.confirmationEnabled)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // Prominent warning banner for Unrestricted Mode (global red tint + clear call-to-action).
    private var unrestrictedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
            Text("UNRESTRICTED MODE ACTIVE — the assistant runs commands without asking. Catastrophic commands are still blocked. Use with caution.")
                .font(.caption.weight(.semibold))
            Spacer()
            Button("Disable") { settings.unrestrictedTools = false }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.red)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(Color.red.opacity(0.12))
        .foregroundStyle(Color.red)
    }

    // MARK: Conversation
    private var filteredMessages: [ChatMessage] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searching, !q.isEmpty else { return vm.messages }
        return vm.messages.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            if searching { searchBar }
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        if vm.messages.isEmpty && !vm.isRunning {
                            emptyState
                                .padding(.top, 60)
                                .padding(.horizontal, 24)
                        } else {
                            // Tight 4pt default gap: grouped same-sender vm.messages
                                // stay snug; first-in-group bubbles add +10 top
                                // padding to land at the normal 14pt gap between
                                // groups (see `isFirstInGroup`).
                            LazyVStack(spacing: 4) {
                                let list = filteredMessages
                                ForEach(Array(list.enumerated()), id: \.element.id) { idx, msg in
                                    let prev: ChatMessage? = idx > 0 ? list[idx - 1] : nil
                                    if needsSeparator(prev: prev, curr: msg) {
                                        TimeSeparator(date: msg.timestamp)
                                    }
                                    let isFirst = isFirstInGroup(idx: idx, list: list)
                                    MessageBubble(message: msg,
                                                  onRegenerate: vm.regenerate)
                                        .padding(.top, isFirst ? 10 : 0)
                                }
                                if vm.isRunning { RunningProgressView() }
                                // Bottom sentinel: 1pt invisible view that
                                // flips `atBottom`. Reliable visibility-based
                                // "at bottom?" without a parallel scroll
                                // binding that could double-fire scrolls.
                                Color.clear.frame(height: 1)
                                    .id("bottomSentinel")
                                    .onAppear { atBottom = true; unreadCount = 0 }
                                    .onDisappear { atBottom = false }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 22)
                            // Centered reading column (design language): content
                            // caps at 780pt; the input pill aligns to the same
                            // column below.
                            .frame(maxWidth: 780)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    // PROTECTED PATH: the streaming/auto-scroll triggers stay
                    // exactly as they were — only the vm.messages.count branch
                    // gains an `atBottom` gate so a scrolled-up user isn't
                    // yanked back when a reply lands. `vm.isRunning` keeps
                    // unconditional scroll (deliberate: when a new turn starts
                    // the user wants to follow it).
                    .onChange(of: vm.messages.count) { _, _ in
                        if atBottom { scrollToBottom(proxy) }
                        else { unreadCount += 1 }
                    }
                    .onChange(of: vm.isRunning) { _, _ in scrollToBottom(proxy) }

                    // Floating "↓ Latest / N new" pill — only when scrolled up.
                    if !atBottom {
                        ScrollToLatestButton(unreadCount: unreadCount) {
                            withAnimation(DS.Motion.smooth) { scrollToBottom(proxy) }
                            unreadCount = 0
                        }
                        .padding(.trailing, 22)
                        .padding(.bottom, 18)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .animation(DS.Motion.snappy, value: atBottom)
            }
        }
    }

    // MARK: Grouping & time-separator helpers
    // Avatar/tail belongs on the LAST message of a same-sender burst (Apple
    // Messages convention). A "burst" = consecutive same-sender vm.messages within
    // a 5-min window. Separator inserts on a >30-min gap or a different
    // calendar day. All read from `filteredMessages` so hidden/system vm.messages
    // never create phantom group breaks.
    private func needsSeparator(prev: ChatMessage?, curr: ChatMessage) -> Bool {
        guard let prev else { return false }
        let cal = Calendar.current
        if !cal.isDate(prev.timestamp, inSameDayAs: curr.timestamp) { return true }
        return curr.timestamp.timeIntervalSince(prev.timestamp) > 30 * 60
    }
    private func isFirstInGroup(idx: Int, list: [ChatMessage]) -> Bool {
        guard idx > 0 else { return true }
        let prev = list[idx - 1]; let curr = list[idx]
        if prev.isUser != curr.isUser { return true }
        return curr.timestamp.timeIntervalSince(prev.timestamp) > 5 * 60
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
                }.buttonStyle(.plain).accessibilityLabel("Clear search")
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
            if vm.isRunning { proxy.scrollTo("typing", anchor: .bottom) }
            else { proxy.scrollTo(vm.messages.last?.id, anchor: .bottom) }
        }
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 28) {
            // Hero logo — twin glow halos with a slow "breathing" scale on the
            // brand tile. Gives the empty state a living, cinematic centerpiece
            // instead of a static glyph.
            EmptyStateLogo()

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
                        submit(s.prompt)
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
                    Button { Task { await pasteImage() } } label: {
                        Label("Paste image from clipboard", systemImage: "doc.on.clipboard")
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
                .accessibilityLabel("Attach a file, image, or screenshot")

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
                .accessibilityLabel("Insert or save a reusable prompt")

                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(inputFocused ? Theme.accent : .secondary)
                        .animation(DS.Motion.fade, value: inputFocused)
                    TextField("Message Salehman AI…", text: $mission, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .focused($inputFocused)
                        .onSubmit { submit(mission) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                // Premium focus ring: 2px gradient stroke + soft accent glow.
                // The old single-color 0.6-opacity ring was barely visible on
                // the dark canvas. Computed contrast: pure-accent stroke on the
                // canvas clears the 3:1 non-text floor; glow is decorative.
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    inputFocused ? Theme.accent.opacity(0.85)  : Color.white.opacity(0.10),
                                    inputFocused ? Theme.accent2.opacity(0.65) : Color.white.opacity(0.05),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: inputFocused ? 2 : 1
                        )
                )
                .shadow(color: inputFocused ? Theme.accent.opacity(0.20) : .clear,
                        radius: inputFocused ? 12 : 0)
                .animation(DS.Motion.smooth, value: inputFocused)

                // Mic (dictation)
                CircleIconButton(systemName: speechIn.isListening ? "mic.fill" : "mic",
                                 size: 40, iconSize: 16,
                                 tint: speechIn.isListening ? .red : .white,
                                 ring: speechIn.isListening ? .red : nil,
                                 help: "Dictate with your voice") { speechIn.toggle() }

                // Stop while generating, otherwise Send
                if vm.isRunning {
                    CircleIconButton(systemName: "stop.fill", size: 40, iconSize: 15,
                                     tint: .red, ring: .red,
                                     help: "Stop generating (⌘.)") { vm.stop() }
                        .transition(.scale.combined(with: .opacity))
                } else {
                    CircleIconButton(systemName: "arrow.up", size: 40, iconSize: 16,
                                     tint: .white, filled: canSend, disabled: !canSend,
                                     help: "Send") { submit(mission) }
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .animation(DS.Motion.snappy, value: vm.isRunning)
    }

    private func attachmentChip(icon: String, title: String, removable: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1)
            if removable {
                Button { attachment = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Remove attachment")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canSend: Bool {
        guard !vm.isRunning, !loadingAttachment else { return false }
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

    /// Paste an image from the clipboard — a copied file (e.g. from Finder) OR raw
    /// image data (a screenshot or copied image). Lets the owner ⌘⇧4-to-clipboard or
    /// copy a picture, then attach it here (the "I can't paste pictures" fix).
    @MainActor private func pasteImage() async {
        let pb = NSPasteboard.general
        // 1) A copied file URL.
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], let url = urls.first {
            loadingAttachment = true
            attachment = await AttachmentLoader.load(url: url)
            loadingAttachment = false; inputFocused = true; return
        }
        // 2) Raw image data on the clipboard (screenshot / copied image) → temp PNG.
        if let img = NSImage(pasteboard: pb), let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("pasted-\(UUID().uuidString).png")
            try? png.write(to: tmp)
            loadingAttachment = true
            attachment = await AttachmentLoader.load(url: tmp)
            loadingAttachment = false; inputFocused = true
        }
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
    // MARK: Send / chat actions — the conversation now lives in `vm` (ChatViewModel).

    /// Send the composed input through `vm`, then clear the view's input + attachment.
    private func submit(_ text: String, recordUser: Bool = true) {
        guard !loadingAttachment else { return }
        let att = attachment
        inputFocused = true
        vm.send(text: text, attachment: att, recordUser: recordUser)
        mission = ""
        attachment = nil
    }

    /// New chat: clear the conversation (vm) + the view's search UI.
    private func newChat() {
        vm.startNewChat()
        searching = false
        searchQuery = ""
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
        enabled ? DS.Palette.successSoft : DS.Palette.warningSoft
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

// MARK: - Time Separator (between message groups across a day boundary or >30min gap)
struct TimeSeparator: View {
    let date: Date
    private var label: String {
        let cal = Calendar.current
        let f = DateFormatter()
        if cal.isDateInToday(date) {
            f.dateFormat = "h:mm a"
            return f.string(from: date)
        } else if cal.isDateInYesterday(date) {
            f.dateFormat = "h:mm a"
            return "Yesterday · \(f.string(from: date))"
        } else {
            f.dateFormat = "MMM d · h:mm a"
            return f.string(from: date)
        }
    }
    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            // 0.45 was ~3.0:1 — below WCAG AA's 4.5:1 even for large secondary
            // text. 0.66 measures ~5.7:1 while still reading as subordinate to
            // the surrounding bubbles. Same bump as the LiveTranscription
            // live-partial line for the same reason.
            .foregroundStyle(Color.white.opacity(0.66))
            .padding(.top, 18).padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Floating "Scroll to latest" pill (shown when scrolled up)
struct ScrollToLatestButton: View {
    let unreadCount: Int
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                Text(unreadCount > 0 ? "\(unreadCount) new" : "Latest")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(DS.Gradient.brand, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            .dsShadow(DS.Elevation.accentGlow(0.45))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unreadCount > 0
            ? "\(unreadCount) new \(unreadCount == 1 ? "message" : "messages"), scroll to latest"
            : "Scroll to latest")
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
    nonisolated private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SalehmanAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chat_history.json")
    }

    // `nonisolated` so the debounced save can hand off to a detached, utility-
    // priority background Task without crossing main-actor boundaries. Both
    // load and save touch only the file system — no shared mutable state.
    nonisolated static func load() -> [ChatMessage] {
        guard let data = try? Data(contentsOf: fileURL),
              let msgs = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return [] }
        return msgs
    }

    nonisolated static func save(_ messages: [ChatMessage]) {
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
            // Fire-and-forget: nothing runs after the write, so awaiting
            // `.value` would only suspend the debounce task for no reason.
            // `save` is nonisolated + does its own atomic file write.
            Task.detached(priority: .utility) { save(snapshot) }
        }
    }

    @MainActor static func flushSave() {
        pendingTask?.cancel()
        pendingTask = nil
        let snapshot = pending
        if !snapshot.isEmpty { save(snapshot) }
    }

    // `onDisappear` isn't guaranteed to fire on app termination, so a quit that
    // lands inside the 1.5 s debounce window could drop the last messages. This
    // flushes synchronously on `willTerminate` (delivered on the main thread,
    // and the app waits for the handler to return before exiting — long enough
    // for one atomic file write). Installed once from the view's `.onAppear`.
    @MainActor private static var terminationObserver: NSObjectProtocol?
    @MainActor static func installTerminationFlush() {
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { flushSave() }
        }
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

    /// Same `offMessage` → `unavailableMessage` swap that `StreamingBubble` does.
    /// See the discussion above `bubbleRow` for the trade-off and why we now
    /// substitute in MessageBubble too.
    private var displayedText: String {
        message.text == LocalLLM.offMessage ? LocalLLM.unavailableMessage : message.text
    }

    var body: some View {
        bubbleRow
            .opacity(appeared ? 1 : 0)
            // Settle to 0 (crisp). The bubble ENTERS blurred and clears as it
            // arrives — the inverse of this had every settled bubble stuck at
            // radius 6, leaving the whole transcript permanently blurry.
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

    // Sentinel→friendly substitution decision history:
    //   v1: rewrote persisted offMessage → unavailableMessage at render time.
    //   v2 (the earlier author): kept history verbatim, worried that old replies
    //       from BEFORE the user added a key would re-render with the new pref's
    //       wording ("no API key" even after the key was saved).
    //   v3 (now): substitute again — see `displayedText`. The v2 trade-off
    //       optimized the wrong axis. The downside it avoided (rare: stale
    //       wording on old replies after the user fixed setup) is much less
    //       severe than the downside it created (every reply in the *active*
    //       failure state confuses the user — e.g. a Salehman-pinned user being
    //       told to pull `qwen2.5-coder`, observed in the wild). `synthesize()`
    //       still gets the deterministic sentinel because the swap is a
    //       view-layer derivation; `messages[i].text` stays unmodified, so
    //       `ChatStore` persists the canonical form.

    // Claude-Code-minimal (owner directive 2026-06-11, mirrors CodeMessageRow):
    // user = quiet right-aligned block, assistant = flush-left document flow.
    // No avatars, no name labels, no per-message timestamps (TimeSeparator rows
    // already mark time between bursts). Actions stay ALWAYS MOUNTED for
    // keyboard/VoiceOver and reveal on hover only.
    private var bubbleRow: some View {
        Group {
            if message.isUser { userRow } else { assistantRow }
        }
        .onHover { hovering = $0 }
    }

    private var userRow: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack {
                Spacer(minLength: 60)
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text)
                        .font(.system(size: 13.5))
                        .textSelection(.enabled)
                        .foregroundStyle(.white)
                    if let path = message.imagePath {
                        CachedImage(path: path)
                            .frame(maxWidth: 360, maxHeight: 360)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
                    }
                }
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(Color.white.opacity(0.09),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("You said: \(message.text)")
            }
            actionButton("doc.on.doc", "Copy") { copyText() }
                .opacity(hovering ? 1 : 0)
                .animation(DS.Motion.fade, value: hovering)
        }
    }

    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownText(text: displayedText)
                .foregroundStyle(Color.white.opacity(0.92))
                .lineSpacing(2)               // calmer reading rhythm on long replies
            if let path = message.imagePath {
                CachedImage(path: path)
                    .frame(maxWidth: 360, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 84)   // room for the hover action cluster
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Assistant replied: \(displayedText)")
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                actionButton(speech.speakingID == message.id ? "speaker.wave.2.fill" : "speaker.wave.2",
                             "Read aloud", active: speech.speakingID == message.id) {
                    speech.toggle(message.text, id: message.id)
                }
                actionButton("doc.on.doc", "Copy") { copyText() }
                if onRegenerate != nil {
                    actionButton("arrow.clockwise", "Regenerate") { onRegenerate?(message) }
                }
            }
            .opacity(hovering ? 1 : 0)
            .animation(DS.Motion.fade, value: hovering)
        }
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
        .accessibilityLabel(help)            // icon-only button → label for VoiceOver
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.text, forType: .string)
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
    @State private var halo = false
    // After ~5s of pre-stream silence the local model is probably loading into
    // RAM (the 14B is ~8.4 GB) — say so instead of looking stuck. The .task
    // auto-cancels when streaming starts (this view disappears).
    @State private var warmHint = false

    var body: some View {
        HStack(spacing: 9) {
            // Avatar with a breathing brand halo. The halo + the gradient dots
            // are the visible heartbeat of "Salehman AI is working" — the
            // single highest-leverage place to make the app feel premium during
            // a wait. (Was a flat brand circle + three white dots.)
            ZStack {
                Circle()
                    .fill(DS.Palette.accent.opacity(0.55))
                    .frame(width: 58, height: 58)
                    .blur(radius: 14)
                    .scaleEffect(halo ? 1.18 : 0.92)
                    .opacity(halo ? 0.9 : 0.4)
                Circle().fill(Theme.brand).frame(width: 30, height: 30)
                    .shadow(color: DS.Palette.accent.opacity(0.55), radius: 10, y: 2)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            }
            HStack(spacing: 6) {
                // Gradient-tinted dots — the brand reads through every beat
                // instead of generic white-on-dark blobs.
                ForEach(0..<3) { i in
                    Circle()
                        .fill(LinearGradient(colors: [DS.Palette.accent, DS.Palette.accent2],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .opacity(animating ? 1 : 0.45)
                        // Same cubic-bezier as the rest of the app's motion.
                        .animation(
                            .timingCurve(0.42, 0.0, 0.58, 1.0, duration: 0.7)
                                .repeatForever()
                                .delay(Double(i) * 0.2),
                            value: animating)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DS.Palette.accent.opacity(0.22), lineWidth: 1)
            )
            if warmHint {
                Text("Warming up the local model…")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .onAppear {
            animating = true
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                halo = true
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation { warmHint = true }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .leading)))
    }
}

/// Header brain-status indicator — a small dot with a soft halo that EXPANDS
/// and pulses while a generation is in flight. Replaces the previous flat
/// off-brand purple circle: now the dot tracks `brain.dotColor` when idle and
/// flips to the brand accent when running, with a halo that gives a clear,
/// cinematic "AI is thinking" signal in the chrome.
private struct BrainStatusDot: View {
    let isRunning: Bool
    let color: Color
    @State private var pulse = false

    var body: some View {
        let active = isRunning ? DS.Palette.accent : color
        ZStack {
            Circle().fill(active.opacity(0.4))
                .frame(width: isRunning ? 22 : 12, height: isRunning ? 22 : 12)
                .blur(radius: 5)
                .scaleEffect(isRunning && pulse ? 1.45 : 1.0)
                .opacity(isRunning && pulse ? 0.35 : (isRunning ? 0.9 : 0.6))
            Circle().fill(active)
                .frame(width: 7, height: 7)
                .shadow(color: active.opacity(0.6), radius: 3)
        }
        .animation(.easeInOut(duration: 0.25), value: isRunning)
        // Only run the repeating pulse WHILE generating. `pulse` is used solely under
        // `isRunning`, so when idle (the common case) we cancel it — otherwise this
        // always-visible header dot redraws every frame forever (idle CPU/GPU + battery
        // drain, very visible when the Mac is throttled in Low Power Mode).
        .onChange(of: isRunning, initial: true) { _, running in
            if running {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                pulse = false
            }
        }
    }
}

/// Empty-state hero logo with a slow "breathing" scale on the brand tile.
/// Extracted into its own subview so the animation `@State` is scoped to the
/// empty state and doesn't survive once the user starts chatting.
private struct EmptyStateLogo: View {
    @State private var breathing = false

    var body: some View {
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
            .scaleEffect(breathing ? 1.045 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
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
            .background(DS.Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    /// Same sentinel→context-aware substitution as `MessageBubble`. Edge case:
    /// `generateStreaming` invokes `onUpdate(offMessage)` when both brains are
    /// unreachable, so the streaming bubble briefly shows that frame too.
    private var displayedText: String {
        text == LocalLLM.offMessage ? LocalLLM.unavailableMessage : text
    }
    var body: some View {
        // Flush-left document flow, matching MessageBubble's assistant row so
        // stream-end doesn't visibly snap styles. A small pulsing dot (not an
        // avatar disc) is the "alive" affordance; `.pulse` respects
        // accessibilityReduceMotion automatically.
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.pulse.byLayer, options: .repeating)
                .padding(.top, 6)
                .accessibilityHidden(true)
            Group {
                if displayedText.count <= StreamRender.liveMarkdownLimit {
                    MarkdownText(text: displayedText)
                } else {
                    // Long reply still streaming: plain text avoids the O(n) Markdown
                    // re-parse every throttle tick (what lags a fast local model). The
                    // finalised row renders full Markdown the instant streaming ends.
                    Text(displayedText)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .foregroundStyle(Color.white.opacity(0.92))
            .lineSpacing(2)               // parity with finalised row — no rhythm jump on stream-end
            Spacer(minLength: 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        Circle()
                            .fill(DS.Palette.accent.opacity(0.18))
                            .frame(width: 52, height: 52)
                            .dsShadow(DS.Elevation.accentGlow(0.45))
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(DS.Palette.accent)
                    }
                    .accessibilityHidden(true)
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
                .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Command to run: \(command)")
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
                            .accessibilityHint("Runs the command shown above on your Mac")
                    }
                    Button(action: onAlways) {
                        Text("Always run without asking")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Disables the approval prompt for all future commands")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 380)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            // Raised modal surface, deliberately a hair LIGHTER than the canvas
            // so it reads as "lifted" over the scrim. Warm-shifted to match the
            // Apple-Music palette (was a cold-indigo 0.10/0.11/0.16 literal).
            .background(DS.Palette.modalBG, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
        }
    }
}
