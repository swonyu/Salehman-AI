import SwiftUI
import AppKit
import UniformTypeIdentifiers   // UTType.fileURL for the composer's drag-and-drop

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
    /// QA only: render the empty-state welcome even when history exists, so
    /// captures can picture the first-impression surface (live renders always
    /// carry the owner's history, hiding it otherwise).
    var qaForceEmptyState = false
    @State private var mission: String = ""
    /// Whether the user's own fine-tuned Ollama model ("salehman") is pulled —
    /// drives the empty-state eyebrow. Probed once per empty-state appearance.
    @State private var localModelReady = false
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
    // Composer parity with the Code tab (owner: "same colors"): drop-target
    // state for the signature ring, and which local model serves `.salehman`
    // when no cloud is configured (the "· salehman14b" badge).
    @State private var isDropTargeted = false
    @State private var servingModel: String?

    private struct Suggestion: Hashable {
        let icon: String
        let title: String
        let subtitle: String
        let prompt: String
    }

    // Subtitle copy sized to FIT the bento cards — the QA welcome render
    // showed "hardware,…" / "heaviest fold…" truncation at the old lengths.
    private let suggestions: [Suggestion] = [
        .init(icon: "desktopcomputer", title: "Inspect this Mac",
              subtitle: "macOS, hardware, uptime",
              prompt: "What macOS version am I running, and give me a quick hardware summary."),
        .init(icon: "folder", title: "Find files",
              subtitle: "What's on the Desktop",
              prompt: "List the files on my Desktop, grouped by kind."),
        .init(icon: "internaldrive", title: "Storage health",
              subtitle: "Free space + big folders",
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

            // Unrestricted Mode is signalled by the banner + header indicator
            // ONLY — never by tinting the canvas. A full-canvas wash (even 3%)
            // shifts every neutral grey warm and visibly breaks the color
            // parity with the Code tab.

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
                    .qaGeometry("chat.input")
                    .frame(maxWidth: .infinity)
            }
        }
        .coordinateSpace(name: "qaRoot")
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
                    // Pulsing halo for Unrestricted Mode (alive / "always on"
                    // signal). Brand accent, NOT system red — system red is
                    // orange-leaning and clashes with the crimson everywhere
                    // else on the screen.
                    ZStack {
                        Circle().fill(DS.Palette.accent.opacity(0.4))
                            .frame(width: 22, height: 22)
                            .blur(radius: 5)
                            .scaleEffect(unrestrictedPulse ? 1.45 : 1.0)
                            .opacity(unrestrictedPulse ? 0.6 : 0.4)
                        Circle().fill(DS.Palette.accent)
                            .frame(width: 7, height: 7)
                            .shadow(color: DS.Palette.accent.opacity(0.6), radius: 3)
                    }
                    Text(vm.isRunning ? "UNRESTRICTED • Thinking…" : "UNRESTRICTED")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent)
                } else {
                    BrainStatusDot(isRunning: vm.isRunning, color: brainStatus.dotColor)
                    // AI status shown as a per-brain GLYPH, not a text label: the
                    // colored dot + a brain icon that pulses while thinking. The
                    // brain name stays available on hover and to VoiceOver.
                    Image(systemName: brainStatus.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(vm.isRunning ? DS.Palette.accent : brainStatus.dotColor)
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
                    .background(Color.white.opacity(0.09), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            // Quiet chrome: the global app accent tints Menu labels even
            // through foregroundStyle (QA renders caught the icon glowing
            // red) — a local secondary tint keeps it calm. AppKit popups
            // ignore SwiftUI tint, so the dropdown itself is unaffected.
            .tint(Color.white.opacity(0.55))
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

            // Chrome diet (QA round): the header used to ALSO show a red
            // UNRESTRICTED capsule here — three red signals at once with the
            // banner + left status. The banner owns the warning and the
            // Disable action; the left status slot shows the mode.
            if !settings.unrestrictedTools {
                // Confirmation toggle — calm chip with a colored dot, no shouty fill.
                ConfirmationChip(enabled: $approval.confirmationEnabled)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // Flat opaque bar (design language — no translucent material).
        .background(DS.Palette.codeSurfaceSide)
    }

    // Prominent warning banner for Unrestricted Mode. Design language: a flat
    // accent-tinted panel with a hairline — the accent marks the icon and the
    // Disable action; the sentence itself stays near-white so it's actually
    // readable (red-on-red caption text measured worst on the contrast probe).
    private var unrestrictedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.Palette.accent)
            Text("UNRESTRICTED MODE ACTIVE — the assistant runs commands without asking. Catastrophic commands are still blocked. Use with caution.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.85))
            Spacer()
            Button("Disable") { settings.unrestrictedTools = false }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(DS.Palette.accent)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(DS.Palette.accent.opacity(0.13))
        .overlay(alignment: .bottom) {
            DS.Palette.accent.opacity(0.25).frame(height: 1)
        }
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
                        if (vm.messages.isEmpty && !vm.isRunning) || qaForceEmptyState {
                            emptyState
                                .padding(.top, 60)
                                .padding(.horizontal, 24)
                        } else {
                            // Reading rhythm: 10pt within a same-sender burst,
                            // +14 leading a new burst (= 24 between speakers) —
                            // document-flow replies need more air than the old
                            // bubble stacks did.
                            //
                            // Lazy in normal use; EAGER during QA captures —
                            // LazyVStack never materializes rows in an
                            // offscreen render, which left chat_live.png with
                            // a blank transcript (QA round-2 finding).
                            transcriptStack {
                                let list = filteredMessages
                                ForEach(Array(list.enumerated()), id: \.element.id) { idx, msg in
                                    let prev: ChatMessage? = idx > 0 ? list[idx - 1] : nil
                                    if needsSeparator(prev: prev, curr: msg) {
                                        TimeSeparator(date: msg.timestamp)
                                    }
                                    let isFirst = isFirstInGroup(idx: idx, list: list)
                                    MessageBubble(message: msg,
                                                  onRegenerate: vm.regenerate)
                                        .padding(.top, isFirst ? 14 : 0)
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
                            .qaGeometry("chat.column")
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
    /// Brain / Effort quick controls in the composer — Code-tab parity. One
    /// menu: the Brain picker, the real Effort dial, the team-size mode, and
    /// the big toggles, plus the live "which local model serves" badge (the
    /// owner's fine-tune gets the accent; a fallback coder stays grey).
    private var chatControlsMenu: some View {
        Menu {
            Picker("Brain", selection: $settings.brainPreference) {
                ForEach(BrainPreference.selectableCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Effort", selection: $settings.salehmanEffort) {
                ForEach(Effort.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Team", selection: $settings.responseMode) {
                ForEach(AppSettings.ResponseMode.allCases) { Text($0.title).tag($0) }
            }
            Divider()
            Toggle("Auto-continue", isOn: $settings.autoContinue)
            Toggle("Web access", isOn: $settings.webAccess)
            Toggle("Unrestricted", isOn: $settings.unrestrictedTools)
        } label: {
            HStack(spacing: 4) {
                // Explicit child styles — Menu-level tint quiets images but
                // NOT label text (proven in the Code tab's QA renders).
                Image(systemName: "slider.horizontal.3").font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.55))
                Text(settings.brainPreference.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(1)
                if let m = servingModel {
                    Text("· \(m)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(m.hasPrefix(AppSettings.customModelNameCurrent)
                                         ? AnyShapeStyle(DS.Palette.accent) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.white.opacity(0.06), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .tint(Color.white.opacity(0.55))
        .help("Active brain — tap to switch brain, effort & toggles")
        .accessibilityLabel("Active brain \(settings.brainPreference.title) — tap to change")
        .accessibilityIdentifier("chat.composer.controls")
        .task(id: settings.brainPreference) { await refreshServingModel() }
    }

    /// Which local model would serve `.salehman` right now (nil when a cloud
    /// is configured — cloud-first means the floor isn't what answers). Same
    /// probe as the Code tab so the two badges can never disagree.
    private func refreshServingModel() async {
        guard settings.brainPreference == .salehman, !SalehmanEngine.hasAnyCloud else {
            servingModel = nil; return
        }
        servingModel = await OllamaClient.activeChatModel()
    }

    /// Transcript container: Lazy normally (long histories), eager VStack
    /// during QA captures so offscreen renders actually show the rows.
    @ViewBuilder
    private func transcriptStack<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        if QAGeometry.enabled {
            VStack(spacing: 10) { content() }
        } else {
            LazyVStack(spacing: 10) { content() }
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
                }.buttonStyle(.plain).accessibilityLabel("Clear search")
            }
            Button("Done") { withAnimation(DS.Motion.snappy) { searching = false; searchQuery = "" } }
                .buttonStyle(.plain).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(DS.Palette.codeSurfaceSide)
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
        VStack(spacing: 26) {
            // Hero logo — twin glow halos with a slow "breathing" scale on the
            // brand tile. The landing moment keeps its glow (design language
            // allows it on landing surfaces); everything else stays flat.
            EmptyStateLogo()

            VStack(spacing: 10) {
                // Live, HONEST eyebrow (the blanket "On-device" claim was false
                // for a cloud-first brain — same inaccuracy class the other
                // session flagged on Today's greeting): say "offline only" when
                // that mode is on, "your 14B is live" when the fine-tune is
                // actually pulled (same probe as the Settings row), else just
                // the name.
                Eyebrow(text: settings.offlineOnly
                        ? "Salehman AI · Offline only"
                        : (localModelReady ? "Salehman AI · your 14B is live"
                                           : "Salehman AI"))
                Text(greetingLine)
                    .font(.system(size: 28, weight: .semibold))
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
            .frame(maxWidth: 600)
            .padding(.top, 4)

            // Keyboard affordances, Code-tab style — the welcome teaches the
            // three moves you'd actually reach for first.
            HStack(spacing: 16) {
                welcomeShortcutHint("⌘N", "New chat")
                welcomeShortcutHint("⌘F", "Find")
                welcomeShortcutHint("⌘J", "Voice")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
        .task { localModelReady = await OllamaClient.hasCustomModel() }
    }

    /// A small keyboard-shortcut chip (key + label) — mirrors the Code tab's
    /// welcome footer so the two landing surfaces speak the same language.
    private func welcomeShortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    /// Time-aware greeting — the same buckets the Today tab uses, so the two
    /// landing surfaces always agree about the time of day.
    private var greetingLine: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning, Saleh"
        case 12..<17: return "Good afternoon, Saleh"
        case 17..<22: return "Good evening, Saleh"
        default:      return "Working late, Saleh?"
        }
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

            // ONE unified composer, Claude layout (matches the Code tab's
            // owner-approved pattern): the text field rides ON TOP, a quiet
            // controls row sits beneath — + menu (attachments AND prompts,
            // halving the old left-side chrome), then mic and send at the
            // trailing edge.
            VStack(alignment: .leading, spacing: 6) {
                TextField(speechIn.isListening ? "Listening… speak now" : "Message Salehman AI…",
                          text: $mission, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...8)
                    .focused($inputFocused)
                    .onSubmit { submit(mission) }
                    // ⌘-less power recall: ↑ in an EMPTY composer pulls back
                    // your last message for editing/resending.
                    .onKeyPress(.upArrow) {
                        guard mission.isEmpty,
                              let last = vm.messages.last(where: { $0.isUser })?.text else { return .ignored }
                        mission = last
                        return .handled
                    }
                    .accessibilityIdentifier("chat.composer.field")
                    .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    // Brain / Effort quick controls — Code-tab parity: switch
                    // the brain, the Effort dial, and the big toggles without
                    // opening Settings. Shows which LOCAL model serves when
                    // Salehman has no cloud configured.
                    chatControlsMenu

                    Menu {
                        Section("Attach") {
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
                        }
                        Section("Prompts") {
                            ForEach(library.prompts) { p in
                                Button(p.title) { insertPrompt(p.text) }
                            }
                            Button {
                                newPromptTitle = ""
                                savingPrompt = true
                            } label: { Label("Save current as prompt…", systemImage: "plus") }
                                .disabled(mission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.07), in: Circle())
                            .contentShape(Circle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    // Same tint-leak fix as the export menu: keep the + quiet —
                    // send is the composer's ONE strong-color element.
                    .tint(Color.white.opacity(0.55))
                    .frame(width: 26)
                    .help("Attach files/images or insert a saved prompt")
                    .accessibilityLabel("Attach files, images, or insert a saved prompt")
                    .accessibilityIdentifier("chat.composer.plus")

                    Spacer(minLength: 0)

                    // Mic (dictation) — quiet inline icon; red while listening.
                    Button { speechIn.toggle() } label: {
                        Image(systemName: speechIn.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(speechIn.isListening ? .red : .secondary)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Dictate with your voice")
                    .accessibilityLabel(speechIn.isListening ? "Stop dictation" : "Dictate with your voice")
                    .accessibilityIdentifier("chat.composer.mic")

                    // Stop while generating, otherwise Send — the composer's
                    // one strong-color element (solid accent when sendable).
                    if vm.isRunning {
                        Button { vm.stop() } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.red.opacity(0.85), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Stop generating (⌘.)")
                        .accessibilityLabel("Stop generating")
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button { submit(mission) } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(canSend ? .white : .secondary)
                                .frame(width: 26, height: 26)
                                .background(canSend ? AnyShapeStyle(DS.Palette.accent)
                                                    : AnyShapeStyle(Color.white.opacity(0.08)),
                                            in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSend)
                        .help("Send (↩ · ⌥↩ for a new line · ↑ recalls your last message)")
                        .accessibilityLabel("Send")
                        .accessibilityIdentifier("chat.composer.send")
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            // CODE-TAB PARITY (owner: "same colors as code tab"): identical
            // composer treatment — white-0.05 fill, radius 14, the signature
            // always-visible accent ring (0.38 rest → 0.60 while typing →
            // full on file drop), and the soft accent glow on focus.
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                isDropTargeted ? DS.Palette.accent
                    : DS.Palette.accent.opacity(
                        mission.trimmingCharacters(in: .whitespaces).isEmpty ? 0.38 : 0.60),
                lineWidth: isDropTargeted ? 1.5 : 1))
            .shadow(color: DS.Palette.accent.opacity(inputFocused ? 0.18 : 0), radius: 12, y: 2)
            .animation(.easeOut(duration: 0.18), value: mission.isEmpty)
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .animation(.easeOut(duration: 0.2), value: inputFocused)
            // While a file hovers, say what will happen — the full-accent ring
            // alone doesn't explain itself.
            .overlay {
                if isDropTargeted {
                    HStack(spacing: 6) {
                        Image(systemName: "paperclip")
                        Text("Drop to attach as context")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(DS.Palette.accent.opacity(0.92), in: Capsule())
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
            // Drag a file anywhere onto the composer to attach it as context —
            // same affordance the Code tab's input has.
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        loadingAttachment = true
                        attachment = await AttachmentLoader.load(url: url)
                        loadingAttachment = false
                    }
                }
                return true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        // Flat — the input row sits directly on the chat canvas.
        .background(DS.Palette.codeSurface)
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
        .background(Color.white.opacity(0.09), in: Capsule())
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
                Circle().fill(dotColor).frame(width: 7, height: 7)
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
            // Solid accent, no gradient/glow (design language) — it floats over
            // the transcript, so it still reads as actionable.
            .background(DS.Palette.accent, in: Capsule())
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
    /// Seconds the reply took to generate (assistant messages only; optional
    /// so history persisted before this field decodes unchanged). Surfaced in
    /// the hover pill — zero chrome at rest.
    var duration: Double? = nil
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
    /// QA only: render the hover action pill as if the pointer were on the
    /// row, so static captures (which can't hover) can see and baseline it.
    var qaShowActions: Bool = false
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
        // QA captures bypass the entry animation: `onAppear` never fires in an
        // offscreen NSHostingView render, so `appeared` stays false and every
        // bubble rendered fully transparent (caught when the gallery's message
        // section went blank after the hosted-path switch).
        let visible = appeared || QAGeometry.enabled
        bubbleRow
            .opacity(visible ? 1 : 0)
            // Settle to 0 (crisp). The bubble ENTERS blurred and clears as it
            // arrives — the inverse of this had every settled bubble stuck at
            // radius 6, leaving the whole transcript permanently blurry.
            // 8pt rise (was 14): present, not theatrical.
            .blur(radius: visible ? 0 : 4)
            .offset(y: visible ? 0 : 8)
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
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .font(.system(size: 13.5))
                    .lineSpacing(1.5)
                    .textSelection(.enabled)
                    .foregroundStyle(.white)
                if let path = message.imagePath {
                    CachedImage(path: path)
                        .frame(maxWidth: 360, maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(Color.white.opacity(0.09),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            // Comfortable wrap measure — long pastes shouldn't span the
            // full 780 column just because they're the user's.
            .frame(maxWidth: 480, alignment: .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("You said: \(message.text)")
            // Same floating-pill pattern as assistant rows — no reserved
            // layout row beneath the block.
            .overlay(alignment: .topTrailing) {
                actionButton("doc.on.doc", "Copy") { copyText() }
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(DS.Palette.codeSurfaceSide,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                    .offset(y: -10)
                    .opacity(hovering || qaShowActions ? 1 : 0)
                    .animation(DS.Motion.fade, value: hovering)
            }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Assistant replied: \(displayedText)")
        // Floating action pill: no layout reservation (text keeps the full
        // measure), readable over any content thanks to its own flat panel.
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 2) {
                // Reply timing — metadata only on demand (hover), zero chrome
                // at rest. "4.2s" for quick replies, "1m 12s" past a minute.
                if let d = message.duration {
                    Text(d < 60 ? String(format: "%.1fs", d)
                                : "\(Int(d) / 60)m \(Int(d) % 60)s")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 5).padding(.trailing, 2)
                        .help("Time to generate this reply")
                }
                actionButton(speech.speakingID == message.id ? "speaker.wave.2.fill" : "speaker.wave.2",
                             "Read aloud", active: speech.speakingID == message.id) {
                    speech.toggle(message.text, id: message.id)
                }
                actionButton("doc.on.doc", "Copy") { copyText() }
                if onRegenerate != nil {
                    actionButton("arrow.clockwise", "Regenerate") { onRegenerate?(message) }
                }
            }
            .padding(.horizontal, 5).padding(.vertical, 3)
            .background(DS.Palette.codeSurfaceSide,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
            .offset(y: -4)
            .opacity(hovering || qaShowActions ? 1 : 0)
            .animation(DS.Motion.fade, value: hovering)
        }
    }

    private func actionButton(_ icon: String, _ help: String, active: Bool = false,
                              _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10.5))
                .foregroundStyle(active ? Theme.accent : .secondary)
                .frame(width: 22, height: 22)        // comfortable hit target
                .contentShape(Rectangle())
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
    // After ~5s of pre-stream silence the local model is probably loading into
    // RAM (the 14B is ~8.4 GB) — say so instead of looking stuck. The .task
    // auto-cancels when streaming starts (this view disappears).
    @State private var warmHint = false

    var body: some View {
        // Quiet flush-left working indicator (design language): three accent
        // dots, no avatar disc, no halo/glow chrome — matches the streaming
        // row's flush-left flow so the transition to text doesn't jump.
        HStack(spacing: 9) {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(DS.Palette.accent)
                        .frame(width: 7, height: 7)
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
            if warmHint {
                Text("Warming up the local model…")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .onAppear { animating = true }
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
        // Flush-left flat panel (no avatar disc — design language). The N/M
        // counter stays: it's live progress, not decorative chrome.
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
        .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
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
        // stream-end doesn't visibly snap styles. The pulsing dot sits ABOVE
        // the text (not beside it) so the text's leading edge is already at
        // the final x-position — no horizontal jump when the stream commits.
        // `.pulse` respects accessibilityReduceMotion automatically.
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.pulse.byLayer, options: .repeating)
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
