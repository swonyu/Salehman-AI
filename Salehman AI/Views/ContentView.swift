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
    /// Unsent-draft persistence key (restored on appear, written per keystroke).
    private static let draftKey = "chat.composerDraft"
    @State private var mission: String = ""
    /// Hover highlight in the `/`-command menu (id of the hovered row).
    @State private var hoveredChatSlash: String? = nil
    /// Keyboard selection in the `/`-command menu (↑/↓ move it, ↵ picks it).
    /// Clamped against the CURRENT matches at use-time; reset when typing
    /// changes the query.
    @State private var slashSelection = 0
    /// ↑/↓ recall: which past user message is currently shown in the composer
    /// (-1 = not in recall mode). ↑ moves backward through history, ↓ moves
    /// forward. Any manual keystroke resets this via `onChange(of: mission)`.
    @State private var recallIdx = -1
    /// Prevents `onChange(of: mission)` from resetting `recallIdx` when the
    /// change was TRIGGERED BY the recall handlers (not by the user typing).
    @State private var inRecall = false
    /// Whether the user's own fine-tuned Ollama model ("salehman") is pulled —
    /// drives the empty-state eyebrow. Probed once per empty-state appearance.
    @State private var localModelReady = false
    /// Archived-conversation count for the welcome's history link (probed once
    /// per empty-state appearance, like `localModelReady`).
    @State private var archiveCount = 0
    @StateObject private var vm = ChatViewModel()
    @FocusState private var inputFocused: Bool
    @ObservedObject private var approval = CommandApprovalCenter.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var brainStatus = BrainStatus.shared
    /// Pending attachments (multi: each gets a chip; merged into one synthetic
    /// Attachment at submit so the send pipeline stays single-attachment).
    @State private var attachments: [Attachment] = []
    /// In-flight attachment loads. A COUNTER, not a Bool: a multi-file drop
    /// runs one async load per file, and the first finisher must not clear the
    /// "loading" state while siblings are still reading (that briefly enabled
    /// Send with half the files attached).
    @State private var attachmentLoads = 0
    private var loadingAttachment: Bool { attachmentLoads > 0 }
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showStats = false
    @State private var statsBlurb = ""
    // /connect — paste the cloud-GPU tunnel URL, the app wires itself.
    @State private var showConnect = false
    @State private var connectURL = ""
    @State private var showNotice = false
    @State private var noticeText = ""
    /// Welcome entrance choreography (Code-tab parity): pre-revealed on QA
    /// launches — offscreen renders never fire onAppear, so captures would
    /// otherwise photograph an invisible welcome.
    @State private var welcomeAppeared = ProcessInfo.processInfo.arguments.contains("--qa")
    @State private var welcomeContentAppeared = ProcessInfo.processInfo.arguments.contains("--qa")
    @State private var hoveredSuggestion: String? = nil
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
    /// Drives the self-dismissing "Saved to Notes" banner. Set true on save;
    /// a .task(id:) clears it automatically after 1.8s.
    @State private var noteSavedPulse = false

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
                // No warning strip above the header (Code-tab parity — its top
                // is clean, and commands run unrestricted from BOTH tabs, so a
                // chat-only banner was never the real guard). The persistent
                // mode signal is the pulsing header indicator; its tooltip
                // carries the warning and clicking it opens Settings.
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
        .sheet(isPresented: $showHistory) { ChatHistoryView(onRestore: restoreArchive) }
        .alert("Conversation stats", isPresented: $showStats) {
            Button("OK", role: .cancel) { }
        } message: { Text(statsBlurb) }
        .alert("Connect to your cloud GPU", isPresented: $showConnect) {
            TextField("https://….trycloudflare.com", text: $connectURL)
            Button("Cancel", role: .cancel) { }
            Button("Connect") {
                if let url = Self.normalizedServerURL(connectURL) {
                    settings.vllmEndpoint = url
                    settings.vllmModel = "salehman"
                    settings.brainPreference = .vllm
                    noticeText = "Connected — vLLM → \(url), model \"salehman\". Replies now come from the cloud GPU; pin Salehman in Settings → Brain to go back to local."
                } else {
                    noticeText = "That doesn't look like a server URL. Paste the https://….trycloudflare.com line the notebook's last cell prints."
                }
                showNotice = true
            }
        } message: {
            Text("Paste the trycloudflare.com URL from the notebook's last cell (salehman_cloud_gpu.ipynb).")
        }
        .alert("Cloud GPU", isPresented: $showNotice) {
            Button("OK", role: .cancel) { }
        } message: { Text(noticeText) }
        .alert("Save prompt", isPresented: $savingPrompt) {
            TextField("Name", text: $newPromptTitle)
            Button("Save") { library.add(title: newPromptTitle, text: mission) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save the current message as a reusable prompt.")
        }
        .onAppear {
            // History decode runs OFF-main (it's a full-file JSON decode that
            // grows with the conversation — decoding it synchronously here was
            // a mount hitch on ⌘2). Guarded re-check: don't clobber a
            // conversation the user started while the load was in flight.
            if vm.messages.isEmpty {
                Task {
                    let loaded = await Task.detached(priority: .userInitiated) {
                        ChatStore.load()
                    }.value
                    if vm.messages.isEmpty { vm.messages = loaded }
                }
            }
            AppSettings.shared.applyCapturePrivacy()
            ChatStore.installTerminationFlush()
            // Restore an unsent draft (quitting mid-thought shouldn't eat it).
            // Skip under --uitesting so UITests always start with an empty composer.
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
            if mission.isEmpty && !isUITesting {
                mission = UserDefaults.standard.string(forKey: Self.draftKey) ?? ""
            }
        }
        .onChange(of: mission) { _, draft in
            // Persist every keystroke (tiny string, no debounce needed);
            // sending clears `mission`, which clears the stored draft too.
            UserDefaults.standard.set(draft, forKey: Self.draftKey)
            // Typing changes the slash query → selection restarts at the top.
            slashSelection = 0
            // Recall state: a change triggered by the ↑/↓ recall handlers
            // sets `inRecall = true` first. Clear the flag this frame and
            // preserve recallIdx. Any OTHER change (user typing) resets recall.
            if inRecall { inRecall = false } else { recallIdx = -1 }
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
                withAnimation(.timingCurve(0.45, 0.0, 0.55, 1.0, duration: 1.2).repeatForever(autoreverses: true)) {
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
                    Button { app.showSettingsRequested = true } label: {
                        Text(vm.isRunning ? "UNRESTRICTED • Thinking…" : "UNRESTRICTED")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(DS.Palette.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Unrestricted Mode — runs commands without asking; catastrophic commands are still blocked. Click to manage in Settings.")
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
                let ratedCount = vm.messages.filter { $0.rating == true }.count
                if ratedCount > 0 {
                    Button { TrainingExporter.savePanel(messages: vm.messages, ratedOnly: true) } label: {
                        Label("Export Best Replies (\(ratedCount) rated)…",
                              systemImage: "hand.thumbsup")
                    }
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

            // Conversation history (archives; new chat archives, never erases)
            CircleIconButton(systemName: "clock.arrow.circlepath",
                             help: "Conversation history",
                             accessibilityLabel: "Conversation history") { showHistory = true }

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

    // (The full-width Unrestricted warning banner was retired for Code-tab
    // parity — see the note in `body`. Disable lives in Settings; the header
    // indicator's tooltip carries the warning copy.)

    // MARK: Conversation
    private var filteredMessages: [ChatMessage] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searching, !q.isEmpty else { return vm.messages }
        return vm.messages.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    /// The term to paint inside each bubble — only while the search bar is open
    /// with a non-blank query, otherwise "" (no highlight). Threaded into every
    /// MessageBubble so the matched word lights up wherever it sits in the reply.
    private var searchHighlight: String {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return (searching && !q.isEmpty) ? q : ""
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            if searching { searchBar }
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        if (vm.messages.isEmpty && !vm.isRunning) || qaForceEmptyState {
                            emptyState
                                .padding(.horizontal, 24)
                        } else if searching && filteredMessages.isEmpty {
                            searchNoResultsState
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
                                    if Self.needsSeparator(prev: prev, curr: msg) {
                                        TimeSeparator(date: msg.timestamp)
                                    }
                                    let isFirst = Self.isFirstInGroup(idx: idx, list: list)
                                    MessageBubble(message: msg,
                                                  highlight: searchHighlight,
                                                  onRegenerate: vm.regenerate,
                                                  onEdit: { m in
                                                      if let text = vm.extractForEdit(m) {
                                                          mission = text
                                                          inputFocused = true
                                                      }
                                                  },
                                                  onQuote: { text in
                                                      let q = Self.quoted(text)
                                                      mission = mission.isEmpty ? q + "\n\n"
                                                                                : mission + "\n" + q + "\n"
                                                      inputFocused = true
                                                  },
                                                  onTogglePin: { vm.togglePin($0) },
                                                  onSaveToNotes: { text in
                                                      ScratchpadStore.shared.addNote(text)
                                                      withAnimation(DS.Motion.fade) { noteSavedPulse = true }
                                                  },
                                                  onRate: { vm.rate($0, up: $1) })
                                        .equatable()
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
                // Pinned-message jump chips ride ABOVE the transcript as an
                // inset (not inside the scroll) so they're always reachable;
                // zero chrome when nothing is pinned.
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !pinnedMessages.isEmpty { pinnedStrip(proxy) }
                }
            }
        }
    }

    // MARK: Grouping & time-separator helpers
    // Avatar/tail belongs on the LAST message of a same-sender burst (Apple
    // Messages convention). A "burst" = consecutive same-sender vm.messages within
    // a 5-min window. Separator inserts on a >30-min gap or a different
    // calendar day. All read from `filteredMessages` so hidden/system vm.messages
    // never create phantom group breaks.
    // Transcript cadence rules — `nonisolated static` so tests pin them (a
    // silent change here reshapes every conversation's rhythm with no error).
    nonisolated static func needsSeparator(prev: ChatMessage?, curr: ChatMessage) -> Bool {
        guard let prev else { return false }
        let cal = Calendar.current
        if !cal.isDate(prev.timestamp, inSameDayAs: curr.timestamp) { return true }
        return curr.timestamp.timeIntervalSince(prev.timestamp) > 30 * 60
    }
    nonisolated static func isFirstInGroup(idx: Int, list: [ChatMessage]) -> Bool {
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
                // Esc closes search without reaching for the Done button.
                .onKeyPress(.escape) {
                    withAnimation(DS.Motion.snappy) { searching = false; searchQuery = "" }
                    return .handled
                }
            if !searchQuery.isEmpty {
                Text(ChatSearch.matchLabel(of: searchQuery, in: vm.messages))
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
    // Composition mirrors the Code tab's welcome 1:1 (owner: "make it look
    // similar to this tab") — flat 60pt disc hero (no glow halos), 19pt title,
    // short muted explainer, ONE row of capsule starter pills, shortcut chips,
    // then an honest status line in the Code tab's "model · local · ready"
    // slot. Same vertical centering. Token values are copied from
    // CodeView.welcome — if you change one side, change the other.
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DS.Palette.accent)
                .frame(width: 68, height: 68)
                .background(RadialGradient(colors: [DS.Palette.accent.opacity(0.22), DS.Palette.accent.opacity(0.07)], center: .center, startRadius: 0, endRadius: 34), in: Circle())
                .overlay(Circle().stroke(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .shadow(color: DS.Palette.accent.opacity(0.35), radius: 28, y: 4)
                .shadow(color: DS.Palette.accent.opacity(0.12), radius: 6, y: 1)
            Text(greetingLine)
                .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("Ask me anything, or let me run things on your Mac — inspect it, find files, check storage, tidy things up.")
                .font(.system(size: 12.5)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(suggestions.prefix(3), id: \.self) { s in
                    Button { submit(s.prompt) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: s.icon).font(.system(size: 10))
                                .foregroundStyle(DS.Palette.accent)
                                .frame(width: 22, height: 22)
                                .background(DS.Palette.accent.opacity(0.10), in: Circle())
                                .overlay(Circle().stroke(DS.Palette.accent.opacity(0.16), lineWidth: 1))
                            Text(s.title).font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.white.opacity(0.06), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(
                            hoveredSuggestion == s.title ? 0.22 : 0.10), lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .foregroundStyle(Color.white.opacity(0.88))
                    // Magnetic hover (GPU-safe: transform + hairline only).
                    .scaleEffect(hoveredSuggestion == s.title ? 1.04 : 1)
                    .animation(DS.Motion.lux, value: hoveredSuggestion)
                    .onHover { hoveredSuggestion = $0 ? s.title
                               : (hoveredSuggestion == s.title ? nil : hoveredSuggestion) }
                }
            }
            .padding(.top, 6)
            .opacity(welcomeContentAppeared ? 1 : 0)
            .offset(y: welcomeContentAppeared ? 0 : 8)
            HStack(spacing: 16) {
                welcomeShortcutHint("⌘N", "New chat")
                welcomeShortcutHint("⌘F", "Find")
                welcomeShortcutHint("⌘J", "Voice")
            }
            .padding(.top, 10)
            .opacity(welcomeContentAppeared ? 1 : 0)
            .offset(y: welcomeContentAppeared ? 0 : 8)
            // Honest status, Code-tab position (replaces the old eyebrow
            // capsule — the Code welcome has no eyebrow): offline mode wins,
            // else the live fine-tune when it's actually pulled.
            if settings.offlineOnly || localModelReady {
                HStack(spacing: 5) {
                    Circle().fill(DS.Palette.accent).frame(width: 5, height: 5)
                    Text(settings.offlineOnly ? "Offline only" : "Your 14B · local · ready")
                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
            // Quiet door back into archived conversations — the welcome is
            // exactly where "wait, where did my chat go?" happens. Hidden in
            // QA captures (the .task probe never runs offscreen), so no
            // baseline churn.
            if archiveCount > 0 {
                Button { showHistory = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 10))
                        Text("\(archiveCount) earlier conversation\(archiveCount == 1 ? "" : "s")")
                            .font(.system(size: 10.5))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .help("Browse and restore archived conversations")
            }
        }
        .background {
            RadialGradient(colors: [DS.Palette.accent.opacity(0.05), .clear],
                           center: .init(x: 0.5, y: 0.30), startRadius: 0, endRadius: 280)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        // Entrance: same heavy fade-up the Code welcome performs (lux curve,
        // 16pt rise, 0.05s settle delay). QA launches skip it via the
        // pre-revealed state above.
        .opacity(welcomeAppeared ? 1 : 0)
        .offset(y: welcomeAppeared ? 0 : 16)
        .onAppear {
            guard !welcomeAppeared else { return }
            withAnimation(DS.Motion.lux.delay(0.05)) { welcomeAppeared = true }
            withAnimation(DS.Motion.lux.delay(0.22)) { welcomeContentAppeared = true }
        }
        // The chat viewport starts 55pt lower than the Code tab's (header row
        // 54pt + 1pt divider, MEASURED from capture pixels — the rgb(19) band
        // in chat_empty.png spans y=0–54; Code has no header), so a plain
        // viewport-center sits visibly LOWER than Code's welcome (owner: "its
        // not centered"). Centering content+55pt of bottom padding lifts the
        // block by 27.5pt — both welcomes land at the same optical height.
        // Padding, not offset: short windows keep clean scrolling, no clipping.
        .padding(.bottom, 55)
        // Fill the scroll viewport and center, exactly like CodeView.welcome.
        .containerRelativeFrame(.vertical, alignment: .center)
        .task {
            localModelReady = await OllamaClient.hasCustomModel()
            archiveCount = ChatStore.archives().count
        }
    }

    /// Shown in place of the transcript when a search query produces zero matches.
    /// Lets the user clear without hunting for the Done button or the ×.
    private var searchNoResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.6))
            Text("No messages match \"\(searchQuery.trimmingCharacters(in: .whitespaces))\"")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Button("Clear search") {
                withAnimation(DS.Motion.snappy) { searchQuery = "" }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(DS.Palette.accent)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .containerRelativeFrame(.vertical, alignment: .center)
    }

    /// A small keyboard-shortcut chip (key + label) — mirrors the Code tab's
    /// welcome footer so the two landing surfaces speak the same language.
    private func welcomeShortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.16), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.22), radius: 1, y: 1)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    // MARK: Composer controls-row pieces (extracted for type-checker budget)
    /// Draft-length readout — invisible until the draft is genuinely long
    /// (zero chrome at rest), accent past the soft budget.
    @ViewBuilder private var composerCountBadge: some View {
        if let count = Self.composerCount(mission) {
            Text(count.label)
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(count.warn ? DS.Palette.accent : .secondary.opacity(0.7))
                .help(count.warn ? "Very long message — consider splitting it or attaching a file"
                                 : "Draft length")
                .accessibilityIdentifier("chat.composer.count")
        }
    }

    /// Mic (dictation) — quiet inline icon; red while listening.
    private var micButton: some View {
        Button { speechIn.toggle() } label: {
            Image(systemName: speechIn.isListening ? "mic.fill" : "mic")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(speechIn.isListening ? .red : .secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .help("Dictate with your voice")
        .accessibilityLabel(speechIn.isListening ? "Stop dictation" : "Dictate with your voice")
        .accessibilityIdentifier("chat.composer.mic")
    }

    /// Stop while generating, otherwise Send — the composer's one strong-color
    /// element (solid accent when sendable).
    @ViewBuilder private var sendOrStopButton: some View {
        if vm.isRunning {
            Button { vm.stop() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(DS.Palette.accent.opacity(0.85), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
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
            .buttonStyle(PressableStyle())
            .disabled(!canSend)
            .help("Send (↩ · ⌥↩ for a new line · ↑ recalls your last message)")
            .accessibilityLabel("Send")
            .accessibilityIdentifier("chat.composer.send")
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: Pinned messages
    private var pinnedMessages: [ChatMessage] { vm.messages.filter { $0.pinned == true } }

    /// First line of a pinned message, trimmed to chip width. Pure for tests.
    nonisolated static func pinPreview(_ text: String, max: Int = 40) -> String {
        let first = text.components(separatedBy: "\n").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return first.count <= max ? first
            : String(first.prefix(max)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Composer length readout: nil below the noise floor (short drafts get
    /// no chrome), then "N words" with `warn` past the soft budget. Words
    /// rather than characters — that's how people gauge prompts. Pure for tests.
    nonisolated static func composerCount(_ text: String,
                                          floor: Int = 120,
                                          budget: Int = 2_000) -> (label: String, warn: Bool)? {
        let words = text.split(whereSeparator: \.isWhitespace).count
        guard words >= floor else { return nil }
        let approxTok = Int((Double(words) * 1.3).rounded())
        return ("~\(approxTok) tok", words >= budget)
    }

    /// Normalizes a pasted tunnel/server URL for the Custom-server brain:
    /// trims, defaults the scheme to https, requires http(s) + a host, strips
    /// trailing slashes, appends `/v1` exactly once. nil = unusable. Pure.
    nonisolated static func normalizedServerURL(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "https://" + s }
        guard let url = URL(string: s),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty
        else { return nil }
        while s.hasSuffix("/") { s.removeLast() }
        return s.hasSuffix("/v1") ? s : s + "/v1"
    }

    /// Horizontal chip rail: click a chip to jump to (and center) its message.
    /// A chip whose message is search-filtered out scrolls nowhere — harmless.
    private func pinnedStrip(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.Palette.accent)
                    .accessibilityHidden(true)
                ForEach(pinnedMessages) { m in
                    HStack(spacing: 0) {
                        Button {
                            withAnimation(DS.Motion.smooth) { proxy.scrollTo(m.id, anchor: .center) }
                        } label: {
                            Text(Self.pinPreview(m.text))
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .padding(.leading, 9).padding(.trailing, 5).padding(.vertical, 4)
                        }
                        .buttonStyle(PressableStyle())
                        .help(m.text)
                        .accessibilityLabel("Jump to pinned message: \(Self.pinPreview(m.text))")
                        // Unpin directly from the strip — no need to scroll to the message first.
                        Button { vm.togglePin(m) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 7).padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .help("Unpin this message")
                        .accessibilityLabel("Unpin: \(Self.pinPreview(m.text))")
                    }
                    .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 6)
        }
        .frame(maxWidth: 780)
        .accessibilityIdentifier("chat.pinnedstrip")
    }

    /// Returns the user message at recall position `idx` (0 = most recent sent,
    /// 1 = second-most-recent, …). `nil` when `idx` is out of range. Pure for
    /// tests so the recall contract can be pinned without mocking state.
    nonisolated static func recalledMessage(idx: Int, from messages: [ChatMessage]) -> String? {
        guard idx >= 0 else { return nil }
        let users = messages.filter(\.isUser).map(\.text)
        guard idx < users.count else { return nil }
        return users[users.count - 1 - idx]
    }

    /// Markdown-quote a reply for the composer: every line gets a `> ` prefix
    /// (blank lines too, so multi-paragraph quotes stay one block). Pure for
    /// tests.
    nonisolated static func quoted(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { "> " + $0 }
            .joined(separator: "\n")
    }

    /// Time-aware greeting — the same buckets the Today tab uses, so the two
    /// landing surfaces always agree about the time of day. Pure on `hour` so
    /// tests can pin every bucket boundary without faking the clock.
    nonisolated static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12:  return "Good morning, Saleh"
        case 12..<17: return "Good afternoon, Saleh"
        case 17..<22: return "Good evening, Saleh"
        default:      return "Working late, Saleh?"
        }
    }
    private var greetingLine: String {
        Self.greeting(hour: Calendar.current.component(.hour, from: Date()))
    }

    // MARK: Slash commands (type `/` in the composer — Code-tab parity)
    private static let chatSlashCommands: [ChatSlashCommand] = [
        .init(id: "summarize", icon: "list.bullet.rectangle",
              blurb: "Summarize this conversation",
              kind: .template("Summarize our conversation so far — key points, decisions, and open questions.")),
        .init(id: "continue", icon: "arrow.forward",
              blurb: "Ask it to keep going",
              kind: .template("Continue.")),
        .init(id: "clear", icon: "square.and.pencil",
              blurb: "New chat (this one is archived)",
              kind: .action("clear")),
        .init(id: "copy", icon: "doc.on.clipboard",
              blurb: "Copy conversation as Markdown",
              kind: .action("copy")),
        .init(id: "export", icon: "square.and.arrow.down",
              blurb: "Save conversation as Markdown…",
              kind: .action("export")),
        .init(id: "find", icon: "magnifyingglass",
              blurb: "Find in conversation",
              kind: .action("find")),
        .init(id: "voice", icon: "waveform.badge.mic",
              blurb: "Open live voice mode",
              kind: .action("voice")),
        .init(id: "history", icon: "clock.arrow.circlepath",
              blurb: "Browse archived conversations",
              kind: .action("history")),
        .init(id: "stats", icon: "chart.bar",
              blurb: "Conversation statistics",
              kind: .action("stats")),
        .init(id: "connect", icon: "bolt.horizontal.circle",
              blurb: "Connect to your cloud-GPU Salehman (paste tunnel URL)",
              kind: .action("connect")),
        .init(id: "shot", icon: "camera.viewfinder",
              blurb: "Attach your latest screenshot as context",
              kind: .action("shot")),
        .init(id: "pin", icon: "pin",
              blurb: "Pin the last AI reply to the top strip",
              kind: .action("pin")),
        .init(id: "note", icon: "note.text.badge.plus",
              blurb: "Save the last AI reply as a Note",
              kind: .action("note")),
    ]
    /// Saved prompts join the `/` menu as templates — `/fix-my-code` inserts
    /// the prompt body. Builtins win id collisions; duplicate slugs keep the
    /// first prompt (ForEach needs unique ids); unsluggable titles are skipped.
    private var promptSlashCommands: [ChatSlashCommand] {
        var seen = Set(Self.chatSlashCommands.map(\.id))
        return library.prompts.compactMap { p in
            let s = ChatSlashCommand.slug(p.title)
            guard !s.isEmpty, seen.insert(s).inserted else { return nil }
            return ChatSlashCommand(id: s, icon: "text.book.closed",
                                    blurb: "Saved prompt", kind: .template(p.text))
        }
    }
    private var chatSlashMatches: [ChatSlashCommand] {
        ChatSlashCommand.matches(for: mission, in: Self.chatSlashCommands + promptSlashCommands)
    }
    private func applyChatSlash(_ cmd: ChatSlashCommand) {
        switch cmd.kind {
        case .template(let t):
            mission = t
            inputFocused = true
        case .action(let a):
            mission = ""
            switch a {
            case "clear":  newChat()
            case "copy":   ChatExporter.copyToPasteboard(vm.messages)
            case "export": ChatExporter.savePanel(vm.messages)
            case "find":    withAnimation(DS.Motion.snappy) { searching = true }
            case "voice":   showLive = true
            case "history": showHistory = true
            case "stats":
                statsBlurb = ChatStats.summarize(vm.messages).blurb
                showStats = true
            case "connect":
                connectURL = ""
                showConnect = true
            case "shot": Task { await attachLastScreenshot() }
            case "pin":
                if let last = vm.messages.last(where: { !$0.isUser }) {
                    vm.togglePin(last)
                }
            case "note":
                if let last = vm.messages.last(where: { !$0.isUser }) {
                    ScratchpadStore.shared.addNote(last.text)
                    withAnimation(DS.Motion.fade) { noteSavedPulse = true }
                }
            default: break
            }
        }
    }

    // MARK: Input bar
    private var inputBar: some View {
        VStack(spacing: 8) {
            // Self-dismissing "Saved to Notes" confirmation banner.
            if noteSavedPulse {
                HStack(spacing: 6) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Palette.successSoft)
                    Text("Saved to Notes")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: noteSavedPulse) {
                    guard noteSavedPulse else { return }
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    withAnimation(DS.Motion.fade) { noteSavedPulse = false }
                }
            }
            // Pending attachment chips — one per file, individually removable.
            if loadingAttachment {
                attachmentChip(icon: "hourglass", title: "Reading attachment…")
            }
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachments) { att in
                            attachmentChip(icon: att.icon,
                                           title: "\(att.name) · \(att.kind)",
                                           onRemove: { attachments.removeAll { $0.id == att.id } })
                        }
                    }
                }
            }

            // Slash-command menu — floats above the composer while typing `/…`
            // (Code-tab parity, same matcher rules; pinned by
            // ChatComposerLogicTests). `↵` picks the top row.
            if !chatSlashMatches.isEmpty {
                let selected = chatSlashMatches[min(slashSelection, chatSlashMatches.count - 1)].id
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(chatSlashMatches) { cmd in
                        Button { applyChatSlash(cmd) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: cmd.icon).font(.system(size: 12))
                                    .foregroundStyle(DS.Palette.accent).frame(width: 16)
                                Text(cmd.trigger).font(.system(size: 12.5, weight: .medium))
                                Text(cmd.blurb).font(.system(size: 11.5)).foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                if cmd.id == selected {
                                    Text("↵").font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(cmd.id == selected || hoveredChatSlash == cmd.id
                                        ? Color.white.opacity(0.06) : .clear,
                                        in: RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hoveredChatSlash = $0 ? cmd.id : (hoveredChatSlash == cmd.id ? nil : hoveredChatSlash) }
                    }
                }
                .padding(5)
                .background(DS.Palette.codeSurface, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(DS.Palette.accent.opacity(0.28), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                .frame(maxWidth: 520, alignment: .leading)
                .transition(.scale(scale: 0.97, anchor: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .move(edge: .bottom)))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("chat.composer.slashmenu")
            }

            // ONE unified composer, Claude layout (matches the Code tab's
            // owner-approved pattern): the text field rides ON TOP, a quiet
            // controls row sits beneath — + menu (attachments AND prompts,
            // halving the old left-side chrome), then mic and send at the
            // trailing edge.
            VStack(alignment: .leading, spacing: 6) {
                TextField(speechIn.isListening ? "Listening… speak now"
                          : "Message Salehman AI…   ( / for commands )",
                          text: $mission, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...8)
                    .focused($inputFocused)
                    // Enter picks the SELECTED `/`-command while the menu is
                    // open (↑/↓ move the selection); otherwise sends.
                    .onSubmit {
                        if !chatSlashMatches.isEmpty {
                            applyChatSlash(chatSlashMatches[min(slashSelection, chatSlashMatches.count - 1)])
                        } else { submit(mission) }
                    }
                    // ↑: slash selection when menu is open; otherwise cycle
                    // BACKWARD through user messages (terminal-history style).
                    // Guarded so it only activates from an empty composer or
                    // while already in recall mode — normal text editing is
                    // not captured. ↓ reverses the cycle.
                    .onKeyPress(.upArrow) {
                        if !chatSlashMatches.isEmpty {
                            slashSelection = max(0, min(slashSelection, chatSlashMatches.count - 1) - 1)
                            return .handled
                        }
                        guard mission.isEmpty || recallIdx >= 0 else { return .ignored }
                        let next = recallIdx + 1
                        guard let text = Self.recalledMessage(idx: next, from: vm.messages) else { return .handled }
                        inRecall = true; recallIdx = next; mission = text
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        if !chatSlashMatches.isEmpty {
                            slashSelection = min(slashSelection + 1, chatSlashMatches.count - 1)
                            return .handled
                        }
                        guard recallIdx >= 0 else { return .ignored }
                        if recallIdx == 0 {
                            inRecall = true; recallIdx = -1; mission = ""
                            return .handled
                        }
                        let prev = recallIdx - 1
                        guard let text = Self.recalledMessage(idx: prev, from: vm.messages) else { return .handled }
                        inRecall = true; recallIdx = prev; mission = text
                        return .handled
                    }
                    // Esc: stop a running generation first; otherwise dismiss a
                    // dangling slash query. Plain Esc with idle composer stays
                    // with the system (sheets, focus).
                    .onKeyPress(.escape) {
                        if vm.isRunning { vm.stop(); return .handled }
                        if !chatSlashMatches.isEmpty { mission = ""; return .handled }
                        return .ignored
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

                    // Count badge, mic, and send/stop are EXTRACTED subviews —
                    // Chat D measured the real build tripping the Swift 6
                    // type-checker timeout on this row's single expression
                    // (bare swiftc doesn't reproduce it — known harness gap).
                    composerCountBadge
                    micButton
                    sendOrStopButton
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            // CODE-TAB PARITY (owner: "same colors as code tab"): the Code
            // composer's DOUBLE-BEZEL, mirrored exactly — inner core (white
            // 0.045, r14 continuous, top-lit gradient hairline) seated in an
            // outer tray (white 0.03, r18 = 14+4 concentric) that carries the
            // signature accent ring (0.38 rest → 0.60 typing → full on drop)
            // and the focus glow. Motion: DS.Motion.lux (Code's curve).
            .background(Color.white.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .padding(4)
            .background(Color.white.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(
                isDropTargeted ? DS.Palette.accent
                    : DS.Palette.accent.opacity(
                        mission.trimmingCharacters(in: .whitespaces).isEmpty ? 0.38 : 0.60),
                lineWidth: isDropTargeted ? 1.5 : 1))
            .shadow(color: DS.Palette.accent.opacity(inputFocused ? 0.18 : 0), radius: 12, y: 2)
            .animation(DS.Motion.lux, value: mission.isEmpty)
            .animation(DS.Motion.lux, value: isDropTargeted)
            .animation(DS.Motion.lux, value: inputFocused)
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
                guard !providers.isEmpty else { return false }
                for provider in providers {
                    _ = provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                        guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                        Task { @MainActor in
                            attachmentLoads += 1
                            attachments.append(await AttachmentLoader.load(url: url))
                            attachmentLoads -= 1
                        }
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
        // Drives the slash-menu island's enter/exit transition (lux). Bound to
        // the EMPTY flip only — row updates while typing stay instant.
        .animation(DS.Motion.lux, value: chatSlashMatches.isEmpty)
    }

    private func attachmentChip(icon: String, title: String,
                                onRemove: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.9))
                .lineLimit(1).truncationMode(.middle)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Remove attachment")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.white.opacity(0.09), in: Capsule())
        // Chips size to content now (they sit in a horizontal row), but a
        // single long filename still shouldn't span the whole composer.
        .frame(maxWidth: 360, alignment: .leading)
    }

    private var canSend: Bool {
        guard !vm.isRunning, !loadingAttachment else { return false }
        return !mission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    // MARK: Attachment actions
    @MainActor private func attachFile() async {
        let urls = AttachmentLoader.pickFiles()
        guard !urls.isEmpty else { return }
        attachmentLoads += 1
        for url in urls { attachments.append(await AttachmentLoader.load(url: url)) }
        attachmentLoads -= 1
        inputFocused = true
    }

    @MainActor private func attachImage() async {
        let urls = AttachmentLoader.pickFiles()
        guard !urls.isEmpty else { return }
        attachmentLoads += 1
        for url in urls { attachments.append(await AttachmentLoader.load(url: url)) }
        attachmentLoads -= 1
        inputFocused = true
    }

    /// Paste an image from the clipboard — a copied file (e.g. from Finder) OR raw
    /// image data (a screenshot or copied image). Lets the owner ⌘⇧4-to-clipboard or
    /// copy a picture, then attach it here (the "I can't paste pictures" fix).
    @MainActor private func pasteImage() async {
        let pb = NSPasteboard.general
        // 1) Copied file URLs (all of them — Finder multi-copy works).
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            attachmentLoads += 1
            for url in urls { attachments.append(await AttachmentLoader.load(url: url)) }
            attachmentLoads -= 1; inputFocused = true; return
        }
        // 2) Raw image data on the clipboard (screenshot / copied image) → temp PNG.
        if let img = NSImage(pasteboard: pb), let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("pasted-\(UUID().uuidString).png")
            try? png.write(to: tmp)
            attachmentLoads += 1
            attachments.append(await AttachmentLoader.load(url: tmp))
            attachmentLoads -= 1; inputFocused = true
        }
    }

    @MainActor private func attachLastScreenshot() async {
        attachmentLoads += 1
        // Use ScreenshotGrabber so the lookup respects `com.apple.screencapture
        // location` — the same picker the Code tab's /shot uses.
        let dir = ScreenshotGrabber.screenshotsDirectory()
        if let url = ScreenshotGrabber.latestScreenshot(in: dir) {
            attachments.append(await AttachmentLoader.load(url: url))
        } else if let url = AttachmentLoader.captureNow() {
            attachments.append(await AttachmentLoader.load(url: url))
        } else {
            attachments.append(Attachment(name: "No screenshot found", kind: "note",
                                          icon: "exclamationmark.triangle",
                                          extractedText: "Could not find a recent screenshot."))
        }
        attachmentLoads -= 1
        inputFocused = true
    }

    private func insertPrompt(_ text: String) {
        mission = text
        inputFocused = true
    }

    // MARK: New chat / stop
    // MARK: Send / chat actions — the conversation now lives in `vm` (ChatViewModel).

    /// Send the composed input through `vm`, then clear the view's input +
    /// attachments. Several files collapse into one synthetic Attachment
    /// (`Attachment.merged`) so the send pipeline stays single-attachment.
    private func submit(_ text: String, recordUser: Bool = true) {
        guard !loadingAttachment else { return }
        let att = Attachment.merged(attachments)
        inputFocused = true
        vm.send(text: text, attachment: att, recordUser: recordUser)
        mission = ""
        attachments.removeAll()
    }

    /// New chat: clear the conversation (vm) + the view's search UI.
    private func newChat() {
        // Archive the conversation instead of erasing it — flush the debounce
        // first so the disk copy matches what's on screen, then snapshot it
        // into the history archive. Restorable from the clock icon / /history.
        ChatStore.flushSave()
        ChatStore.archiveCurrent()
        vm.startNewChat()
        searching = false
        searchQuery = ""
        inputFocused = true     // ready to type immediately after clearing
    }

    /// Replace the live conversation with an archived one. Symmetric with
    /// `newChat`: the current conversation is archived first, and the restored
    /// archive file is removed (it IS the live conversation now — keeping it
    /// would duplicate on the next archive pass).
    private func restoreArchive(_ item: ChatStore.ArchivedChat) {
        // Never swap the transcript under a streaming task — cancel it first
        // (the same graceful stop the composer's stop button uses).
        vm.stop()
        ChatStore.flushSave()
        ChatStore.archiveCurrent()
        let restored = ChatStore.loadArchive(item.id)
        guard !restored.isEmpty else { return }
        ChatStore.deleteArchive(item.id)
        withAnimation(DS.Motion.spring) { vm.messages = restored }
        showHistory = false
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
        .buttonStyle(PressableStyle())
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
    /// Pinned by the user (context menu). Optional, not Bool-with-default:
    /// synthesized Codable REQUIRES non-optional keys even when defaulted, so
    /// only `Bool?` lets pre-pin history decode unchanged. `true` or absent.
    var pinned: Bool? = nil
    /// User rating: `true` = thumbs-up, `false` = thumbs-down, `nil` = none.
    /// Same optional-Codable trick as `pinned` — old history decodes unchanged.
    var rating: Bool? = nil
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

    // MARK: Archive (conversation history)
    // New chats ARCHIVE the old conversation instead of erasing it. Archives
    // are sibling JSONs in `chats/` using the same [ChatMessage] coding as the
    // live file, so restore is a plain load.

    /// One archived conversation, summarized for the History sheet.
    struct ArchivedChat: Identifiable {
        let id: URL          // archive file
        let title: String
        let date: Date       // last activity (newest message timestamp)
        let messageCount: Int
        let preview: String  // first non-empty line of the first AI reply

        nonisolated init(id: URL, title: String, date: Date, messageCount: Int, preview: String = "") {
            self.id = id; self.title = title; self.date = date
            self.messageCount = messageCount; self.preview = preview
        }
    }

    nonisolated private static var archiveDir: URL {
        let dir = fileURL.deletingLastPathComponent()
            .appendingPathComponent("chats", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// First user line, trimmed to a list-row title. Pure for tests.
    nonisolated static func archiveTitle(for messages: [ChatMessage]) -> String {
        let firstLine = messages.first(where: { $0.isUser })?.text
            .components(separatedBy: "\n").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "Conversation" : String(firstLine.prefix(60))
    }

    /// First non-empty line of the first assistant reply, truncated for the row.
    /// Pure for tests; returns "" when there are no assistant messages.
    nonisolated static func archivePreview(for messages: [ChatMessage]) -> String {
        guard let reply = messages.first(where: { !$0.isUser }) else { return "" }
        let first = reply.text.components(separatedBy: "\n")
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        return String(first.trimmingCharacters(in: .whitespacesAndNewlines).prefix(90))
    }

    /// Snapshot the CURRENT (on-disk) conversation into the archive. No-op for
    /// an empty conversation. Caller flushes the debounce first.
    nonisolated static func archiveCurrent() {
        let msgs = load()
        guard !msgs.isEmpty, let data = try? JSONEncoder().encode(msgs) else { return }
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        try? data.write(to: archiveDir.appendingPathComponent("chat_\(stamp).json"),
                        options: .atomic)
        pruneArchives()
    }

    /// Keep the newest 100 archives — the timestamped filenames sort
    /// chronologically, so name order IS age order. Unbounded growth would
    /// slowly bloat `archives()` (it decodes every file to summarize it).
    nonisolated private static func pruneArchives(keep: Int = 100) {
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: archiveDir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }   // newest first
        for stale in files.dropFirst(keep) {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    /// All archived conversations, newest activity first.
    nonisolated static func archives() -> [ArchivedChat] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: archiveDir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> ArchivedChat? in
                guard let data = try? Data(contentsOf: url),
                      let msgs = try? JSONDecoder().decode([ChatMessage].self, from: data),
                      !msgs.isEmpty else { return nil }
                return ArchivedChat(id: url,
                                    title: archiveTitle(for: msgs),
                                    date: msgs.map(\.timestamp).max() ?? .distantPast,
                                    messageCount: msgs.count,
                                    preview: archivePreview(for: msgs))
            }
            .sorted { $0.date > $1.date }
    }

    /// Count of archived conversations whose last-modified date is today.
    /// Uses filesystem metadata only (no JSON decode) — safe to call off-main.
    nonisolated static func archivedTodayCount() -> Int {
        let cal = Calendar.current
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: archiveDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles)) ?? []
        return urls.filter { url in
            guard url.pathExtension == "json",
                  let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let mod = vals.contentModificationDate
            else { return false }
            return cal.isDateInToday(mod)
        }.count
    }

    nonisolated static func loadArchive(_ url: URL) -> [ChatMessage] {
        guard let data = try? Data(contentsOf: url),
              let msgs = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return [] }
        return msgs
    }

    nonisolated static func deleteArchive(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
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

/// "1 message" / "3 messages" — exporter + stats share it. Pass the plural
/// explicitly for irregulars ("reply"/"replies").
private nonisolated func counted(_ n: Int, _ singular: String, _ plural: String? = nil) -> String {
    "\(n) \(n == 1 ? singular : (plural ?? singular + "s"))"
}

enum ChatExporter {
    /// Markdown for the whole conversation. Title follows the History sheet's
    /// rule (first user line), then the date range, per-message blocks with
    /// attachments noted by filename (they were silently dropped before), and
    /// a stats footer. `nonisolated` + pure on its inputs so tests can pin the
    /// format hermetically; date strings stay locale-formatted, so tests
    /// assert structure, not exact dates.
    nonisolated static func markdown(_ messages: [ChatMessage]) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium; df.timeStyle = .short
        var out = "# \(ChatStore.archiveTitle(for: messages))\n\n"
        // Range needs two ends — a single message would render "X – X".
        if messages.count > 1,
           let first = messages.map(\.timestamp).min(),
           let last = messages.map(\.timestamp).max() {
            out += "_\(df.string(from: first)) – \(df.string(from: last))_\n\n"
        }
        out += "---\n\n"
        for m in messages {
            let who = m.isUser ? "You" : "Salehman AI"
            out += "**\(who)** · \(df.string(from: m.timestamp))\n\n"
            if let path = m.imagePath {
                out += "📎 `\(URL(fileURLWithPath: path).lastPathComponent)`\n\n"
            }
            out += "\(m.text)\n\n---\n\n"
        }
        let words = messages.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
        var footer = "_\(counted(messages.count, "message")) · \(counted(words, "word"))"
        let replies = messages.compactMap(\.duration)
        if !replies.isEmpty {
            footer += String(format: " · avg reply %.1fs", replies.reduce(0, +) / Double(replies.count))
        }
        out += footer + "_\n"
        return out
    }

    @MainActor static func copyToPasteboard(_ messages: [ChatMessage]) {
        guard !messages.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown(messages), forType: .string)
    }

    /// Suggested export filename: conversation title + last-activity date,
    /// scrubbed of path/filesystem-hostile characters. Pure for tests.
    nonisolated static func exportFilename(for messages: [ChatMessage]) -> String {
        let raw = ChatStore.archiveTitle(for: messages)
        let banned = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let safe = raw.components(separatedBy: banned).joined()
            .trimmingCharacters(in: .whitespaces)
        let df = DateFormatter()
        // Fixed-format dates need the POSIX locale: a bare DateFormatter
        // follows the DEVICE locale+calendar, so on a Hijri-calendar Mac
        // (this machine) "yyyy-MM-dd" rendered 1447-era dates in filenames.
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        let date = messages.map(\.timestamp).max() ?? Date()
        return "\(safe.isEmpty ? "Conversation" : safe) — \(df.string(from: date)).md"
    }

    @MainActor static func savePanel(_ messages: [ChatMessage]) {
        guard !messages.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = exportFilename(for: messages)
        panel.canCreateDirectories = true
        panel.title = "Export Conversation"
        if panel.runModal() == .OK, let url = panel.url {
            try? markdown(messages).data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Conversation stats
/// Whole-conversation roll-up behind the `/stats` command — the per-reply
/// hover pill answers "how fast was THIS reply"; this answers "what has this
/// conversation been". Pure + nonisolated so tests pin the math and format.
struct ChatStats: Equatable {
    let messages: Int
    let yours: Int
    let replies: Int
    let words: Int
    let approxTokens: Int           // rough English estimate: words × 1.3
    let longestReplyWords: Int?     // word count of the longest assistant reply
    let ratedUp: Int                // replies marked thumbs-up
    let ratedDown: Int              // replies marked thumbs-down
    let avgReplySeconds: Double?    // nil when no reply carries a duration
    let spanSeconds: TimeInterval?  // nil for 0–1 messages

    nonisolated static func summarize(_ msgs: [ChatMessage]) -> ChatStats {
        let yours = msgs.filter(\.isUser).count
        let words = msgs.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
        let assistantMsgs = msgs.filter { !$0.isUser }
        let replyWordCounts = assistantMsgs
            .map { $0.text.split(whereSeparator: \.isWhitespace).count }
        let durations = msgs.compactMap(\.duration)
        let stamps = msgs.map(\.timestamp)
        var span: TimeInterval? = nil
        if msgs.count > 1, let a = stamps.min(), let b = stamps.max() {
            span = b.timeIntervalSince(a)
        }
        return ChatStats(
            messages: msgs.count, yours: yours, replies: msgs.count - yours,
            words: words,
            approxTokens: Int((Double(words) * 1.3).rounded()),
            longestReplyWords: replyWordCounts.max(),
            ratedUp: assistantMsgs.filter { $0.rating == true }.count,
            ratedDown: assistantMsgs.filter { $0.rating == false }.count,
            avgReplySeconds: durations.isEmpty ? nil
                : durations.reduce(0, +) / Double(durations.count),
            spanSeconds: span)
    }

    /// "45s", "5m", "1h 20m", "2d 3h" — calendar-free span humanizer.
    nonisolated static func human(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s)s" }
        let m = s / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        if h < 24 { return m % 60 == 0 ? "\(h)h" : "\(h)h \(m % 60)m" }
        let d = h / 24
        return h % 24 == 0 ? "\(d)d" : "\(d)d \(h % 24)h"
    }

    /// Two-line summary for the `/stats` alert. `%.1f` via `String(format:)`
    /// is locale-independent, so tests can pin the exact string.
    nonisolated var blurb: String {
        let head = "\(counted(messages, "message")) — \(yours) yours, \(counted(replies, "reply", "replies"))"
        var tail = counted(words, "word") + " · ~\(approxTokens) tok"
        if let lw = longestReplyWords { tail += " · longest: \(lw)w" }
        if ratedUp > 0 || ratedDown > 0 {
            tail += " · \(ratedUp)↑ \(ratedDown)↓"
        }
        if let avg = avgReplySeconds { tail += String(format: " · avg reply %.1fs", avg) }
        if let span = spanSeconds { tail += " · spans \(Self.human(span))" }
        return head + "\n" + tail
    }
}

/// Pure helpers behind find-in-conversation. Kept free of view state so the
/// counting logic is unit-testable (ChatTranscriptLogicTests) — the searchBar
/// just renders `matchLabel(...)`.
enum ChatSearch {
    /// Count NON-overlapping, case-insensitive occurrences of `query` in `text`.
    /// "aa" in "aaaa" → 2, not 3 — we advance past each whole match (mirrors how
    /// a user reading the highlight counts them, and how the highlighter paints
    /// them). Blank query → 0.
    nonisolated static func occurrences(of query: String, in text: String) -> Int {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return 0 }
        var count = 0
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let r = text.range(of: q, options: .caseInsensitive,
                                 range: searchStart..<text.endIndex) {
            count += 1
            // Advance past the whole match so overlaps aren't double-counted; the
            // guard against an empty match keeps this from looping forever.
            searchStart = r.upperBound > r.lowerBound ? r.upperBound
                                                      : text.index(after: r.lowerBound)
        }
        return count
    }

    /// Total occurrences across every message — the number the searchBar shows.
    nonisolated static func totalMatches(of query: String, in messages: [ChatMessage]) -> Int {
        messages.reduce(0) { $0 + occurrences(of: query, in: $1.text) }
    }

    /// How many messages contain at least one occurrence (the filtered-row count).
    nonisolated static func matchingMessageCount(of query: String, in messages: [ChatMessage]) -> Int {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return 0 }
        return messages.filter { $0.text.localizedCaseInsensitiveContains(q) }.count
    }

    /// SearchBar caption: total matches, plus how many messages they span when
    /// the two differ (e.g. "5 matches in 3 messages"). "No matches" when none.
    nonisolated static func matchLabel(of query: String, in messages: [ChatMessage]) -> String {
        let total = totalMatches(of: query, in: messages)
        guard total > 0 else { return "No matches" }
        let msgs = matchingMessageCount(of: query, in: messages)
        let head = counted(total, "match", "matches")
        return msgs == total ? head : "\(head) in \(counted(msgs, "message"))"
    }
}

// MARK: - Message Bubble
struct MessageBubble: View, Equatable {
    /// Equality gates body re-evaluation (used via `.equatable()` at the
    /// transcript call site): ContentView's body re-runs on EVERY keystroke /
    /// hover flip, handing each bubble fresh closures — reflection-based
    /// diffing can't prove them unchanged, so every settled bubble re-ran its
    /// body (markdown-cache lookups + full tree diff × N messages) per
    /// keystroke. Comparing just message + qaShowActions skips all of it;
    /// speech-state updates still flow via @ObservedObject (dynamic-property
    /// invalidation bypasses ==, by design — SpeechOut publishes only
    /// speakingID, twice per read-aloud, so the bypass is cheap).
    ///
    /// ⚠️ MAINTENANCE (verified failure mode, Airbnb eng. blog): if you ADD a
    /// stored property that affects rendering, you MUST add it here — a stale
    /// == silently freezes that property's UI. Closures stay excluded (that's
    /// the point); `.equatable()` at the call site is REQUIRED, conformance
    /// alone is ignored by SwiftUI (swiftui-lab.com/equatableview).
    static func == (lhs: MessageBubble, rhs: MessageBubble) -> Bool {
        lhs.message == rhs.message
            && lhs.qaShowActions == rhs.qaShowActions
            && lhs.highlight == rhs.highlight
    }

    let message: ChatMessage
    /// Active find-in-conversation term to highlight inside this bubble's text.
    /// Empty in the common (not-searching) case. MUST be in `==` above — a stale
    /// equality would freeze the highlight when the query changes (see warning).
    var highlight: String = ""
    var onRegenerate: ((ChatMessage) -> Void)? = nil
    /// Edit-and-resend on user rows: the view model truncates the transcript
    /// from this message and the composer reloads its text. nil hides the action.
    var onEdit: ((ChatMessage) -> Void)? = nil
    /// Quote an assistant reply into the composer (`> `-prefixed). nil hides it.
    var onQuote: ((String) -> Void)? = nil
    /// Pin/unpin this message (context menu, either side). nil hides it.
    var onTogglePin: ((ChatMessage) -> Void)? = nil
    /// Save this message's text as a note in ScratchpadStore. nil hides it.
    var onSaveToNotes: ((String) -> Void)? = nil
    /// Rate this assistant reply: `true` = thumbs-up, `false` = thumbs-down.
    /// Excluded from `==` (closure); `message.rating` is in `==` via ChatMessage.
    var onRate: ((ChatMessage, Bool) -> Void)? = nil
    /// QA only: render the hover action pill as if the pointer were on the
    /// row, so static captures (which can't hover) can see and baseline it.
    var qaShowActions: Bool = false
    @ObservedObject private var speech = SpeechOut.shared
    @State private var hovering = false
    @State private var appeared = false   // drives fade-up-blur entry
    @State private var copied = false

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
        // Right-click mirrors the hover pill — the native path for users who
        // reach for the context menu before discovering hover affordances.
        .contextMenu {
            Button { copyText() } label: { Label("Copy", systemImage: "doc.on.doc") }
            if onTogglePin != nil {
                Button { onTogglePin?(message) } label: {
                    Label(message.pinned == true ? "Unpin" : "Pin",
                          systemImage: message.pinned == true ? "pin.slash" : "pin")
                }
            }
            if message.isUser {
                if onEdit != nil {
                    Button { onEdit?(message) } label: {
                        Label("Edit & Resend", systemImage: "pencil")
                    }
                }
            } else {
                if onQuote != nil {
                    Button { onQuote?(displayedText) } label: {
                        Label("Quote in Composer", systemImage: "text.quote")
                    }
                }
                Button { speech.toggle(message.text, id: message.id) } label: {
                    Label(speech.speakingID == message.id ? "Stop Speaking" : "Read Aloud",
                          systemImage: "speaker.wave.2")
                }
                if onRegenerate != nil {
                    Button { onRegenerate?(message) } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                }
                if onSaveToNotes != nil {
                    Button { onSaveToNotes?(displayedText) } label: {
                        Label("Save as Note", systemImage: "note.text.badge.plus")
                    }
                }
                if onRate != nil {
                    Button { onRate?(message, true) } label: {
                        Label(message.rating == true ? "Remove Good Rating" : "Mark as Good Response",
                              systemImage: message.rating == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                    }
                    Button { onRate?(message, false) } label: {
                        Label(message.rating == false ? "Remove Poor Rating" : "Mark as Poor Response",
                              systemImage: message.rating == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    }
                }
                Divider()
                Button { copyPlainText() } label: {
                    Label("Copy as Plain Text", systemImage: "doc.plaintext")
                }
            }
        }
        .onHover { hovering = $0 }
    }

    /// Splits a composed message into the leading markdown quote block (the
    /// `> `-prefixed lines quote-reply inserts) and the body beneath it.
    /// nil when the text doesn't OPEN with a quote. Pure for tests.
    nonisolated static func splitLeadingQuote(_ text: String) -> (quote: String, body: String)? {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.hasPrefix(">") == true else { return nil }
        var quote: [String] = [], rest: [String] = []
        var inQuote = true
        for line in lines {
            if inQuote, line.hasPrefix(">") {
                quote.append(String(line.dropFirst(line.hasPrefix("> ") ? 2 : 1)))
            } else {
                inQuote = false
                rest.append(line)
            }
        }
        let q = quote.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }
        return (q, rest.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Quoted reply rendered as a real quote block (accent rail + dimmed text)
    /// instead of raw "> " prose — quote-reply finally LOOKS quoted once sent.
    private func quoteCard(_ quote: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(DS.Palette.accent.opacity(0.55))
                .frame(width: 2)
            Text(MarkdownText.highlighted(AttributedString(quote), query: highlight))
                .font(.system(size: 12))
                .lineSpacing(1.2)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(6)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// User text, split into quote card + body when the message opens with a
    /// quote. Extracted subview (type-checker budget discipline).
    @ViewBuilder private var userTextBlock: some View {
        if let split = Self.splitLeadingQuote(message.text) {
            quoteCard(split.quote)
            if !split.body.isEmpty {
                Text(MarkdownText.highlighted(AttributedString(split.body), query: highlight))
                    .font(.system(size: 13.5))
                    .lineSpacing(1.5)
                    .textSelection(.enabled)
                    .foregroundStyle(.white)
            }
        } else {
            Text(MarkdownText.highlighted(AttributedString(message.text), query: highlight))
                .font(.system(size: 13.5))
                .lineSpacing(1.5)
                .textSelection(.enabled)
                .foregroundStyle(.white)
        }
    }

    private var userRow: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .leading, spacing: 8) {
                userTextBlock
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
                HStack(spacing: 2) {
                    // Send time — same metadata-on-demand pattern as the
                    // assistant's duration label. Appears at leading edge of
                    // the pill so timestamp scans left-to-right like reading.
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 5).padding(.trailing, 2)
                        .help(message.timestamp.formatted(date: .long, time: .standard))
                    if onEdit != nil {
                        actionButton("pencil", "Edit & resend (removes this turn and everything after)") {
                            onEdit?(message)
                        }
                    }
                    actionButton(copied ? "checkmark" : "doc.on.doc", "Copy") { copyText() }
                    if onTogglePin != nil {
                        actionButton(message.pinned == true ? "pin.slash" : "pin",
                                     message.pinned == true ? "Unpin" : "Pin to top") {
                            onTogglePin?(message)
                        }
                    }
                }
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
            MarkdownText(text: displayedText, highlight: highlight)
                .foregroundStyle(Color.white.opacity(0.92))
                .lineSpacing(2)               // calmer reading rhythm on long replies
            // Failure rows get an INLINE retry — hover-regenerate exists but
            // isn't discoverable when the user is staring at an error.
            if message.text == LocalLLM.offMessage, onRegenerate != nil {
                Button { onRegenerate?(message) } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Palette.accent)
                .help("Re-run your last message")
                .padding(.top, 2)
            }
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
                        // Full stats on demand (the pill only renders on
                        // hover, so the word count split is effectively free).
                        .help("Generated in \(String(format: "%.1f", d))s · \(message.text.split { $0.isWhitespace }.count) words · \(message.timestamp.formatted(date: .omitted, time: .shortened))")
                } else {
                    // Fallback for history-loaded replies that have no recorded
                    // duration — still show the timestamp so every bubble has
                    // time context on hover.
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 5).padding(.trailing, 2)
                        .help(message.timestamp.formatted(date: .long, time: .standard))
                }
                actionButton(speech.speakingID == message.id ? "speaker.wave.2.fill" : "speaker.wave.2",
                             "Read aloud", active: speech.speakingID == message.id) {
                    speech.toggle(message.text, id: message.id)
                }
                actionButton("doc.on.doc", "Copy") { copyText() }
                if onQuote != nil {
                    actionButton("text.quote", "Quote in your next message") {
                        onQuote?(displayedText)
                    }
                }
                if onRegenerate != nil {
                    actionButton("arrow.clockwise", "Regenerate") { onRegenerate?(message) }
                }
                if onTogglePin != nil {
                    actionButton(message.pinned == true ? "pin.slash" : "pin",
                                 message.pinned == true ? "Unpin" : "Pin to top") {
                        onTogglePin?(message)
                    }
                }
                if onRate != nil {
                    actionButton(message.rating == true ? "hand.thumbsup.fill" : "hand.thumbsup",
                                 "Good response", active: message.rating == true) {
                        onRate?(message, true)
                    }
                    actionButton(message.rating == false ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                                 "Poor response", active: message.rating == false) {
                        onRate?(message, false)
                    }
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
        copied = true
        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
    }

    private func copyPlainText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.plainText(message.text), forType: .string)
    }

    /// Strips common Markdown markers to produce clean plain text suitable for
    /// pasting into non-markdown contexts (emails, notes, etc.). Pure — tested
    /// directly. Keeps code content (strips fences / backticks), strips images,
    /// and converts links to their display text. Not a full CommonMark parser —
    /// covers the patterns Salehman's replies actually produce.
    nonisolated static func plainText(_ markdown: String) -> String {
        var s = markdown
        // Fenced code blocks: remove fence lines, keep code body
        s = s.replacingOccurrences(of: "(?s)```\\w*\\n(.*?)```",
                                    with: "$1", options: .regularExpression)
        // Remaining unmatched fences (no trailing ```)
        s = s.replacingOccurrences(of: "```\\w*", with: "", options: .regularExpression)
        // Inline code: keep content, drop backticks
        s = s.replacingOccurrences(of: "`([^`\n]+)`", with: "$1", options: .regularExpression)
        // ATX headings (# to ######)
        s = s.replacingOccurrences(of: "(?m)^#{1,6}\\s+", with: "", options: .regularExpression)
        // Bold+italic (***), bold (**), italic (*) — non-greedy, no cross-line
        s = s.replacingOccurrences(of: "\\*{3}(.+?)\\*{3}", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\*{2}(.+?)\\*{2}", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\*([^*\n]+)\\*",   with: "$1", options: .regularExpression)
        // Bold+italic (___), bold (__), italic (_)
        s = s.replacingOccurrences(of: "_{3}(.+?)_{3}",    with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "_{2}(.+?)_{2}",    with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "_([^_\n]+)_",      with: "$1", options: .regularExpression)
        // Images (drop entirely) then links (keep display text)
        s = s.replacingOccurrences(of: "!\\[.*?\\]\\(.*?\\)", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\[(.+?)\\]\\(.*?\\)", with: "$1", options: .regularExpression)
        // Blockquote leaders
        s = s.replacingOccurrences(of: "(?m)^> ?", with: "", options: .regularExpression)
        // Unordered list markers
        s = s.replacingOccurrences(of: "(?m)^[-*+]\\s+", with: "", options: .regularExpression)
        // Ordered list markers
        s = s.replacingOccurrences(of: "(?m)^\\d+\\.\\s+", with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
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
        .animation(DS.Motion.fade, value: isRunning)
        // Only run the repeating pulse WHILE generating. `pulse` is used solely under
        // `isRunning`, so when idle (the common case) we cancel it — otherwise this
        // always-visible header dot redraws every frame forever (idle CPU/GPU + battery
        // drain, very visible when the Mac is throttled in Low Power Mode).
        .onChange(of: isRunning, initial: true) { _, running in
            if running {
                withAnimation(.timingCurve(0.45, 0.0, 0.55, 1.0, duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                pulse = false
            }
        }
    }
}

// (EmptyStateLogo — the 130pt twin-halo breathing orb — was deleted when the
// chat welcome adopted the Code tab's flat 60pt disc hero. The disc is inline
// in `emptyState`; it has no animation state, so no subview is needed.)

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
    /// Entrance choreography state; QA's offscreen renders never fire
    /// onAppear, so captures use the pre-revealed path.
    @State private var appeared = false

    var body: some View {
        let visible = appeared || QAGeometry.enabled
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { onCancel() }
                .opacity(visible ? 1 : 0)

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
                    .buttonStyle(PressableStyle())
                    .accessibilityHint("Disables the approval prompt for all future commands")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 380)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            // DOUBLE-BEZEL modal (DS.Bezel tokens): the warm modalBG core keeps
            // its "lifted over the scrim" read, now seated in the canonical
            // shell tray with the top-lit core highlight.
            .background(DS.Palette.modalBG,
                        in: RoundedRectangle(cornerRadius: DS.Bezel.innerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Bezel.innerRadius, style: .continuous)
                .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5))
            .padding(DS.Bezel.shellPadding)
            .background(DS.Bezel.shellFill,
                        in: RoundedRectangle(cornerRadius: DS.Bezel.outerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Bezel.outerRadius, style: .continuous)
                .stroke(DS.Bezel.shellStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
            // Entrance: settle up from 0.96 on lux — mass, not a pop.
            .scaleEffect(visible ? 1 : 0.96)
            .opacity(visible ? 1 : 0)
            .onAppear {
                guard !appeared else { return }
                withAnimation(DS.Motion.lux) { appeared = true }
            }
        }
    }
}

/// A `/`-command for the chat composer (Code-tab parity). Internal (not
/// private) so `ChatComposerLogicTests` can pin the matcher hermetically.
struct ChatSlashCommand: Identifiable {
    enum Kind { case template(String), action(String) }
    let id: String          // trigger without the slash, e.g. "copy"
    let icon: String
    let blurb: String
    let kind: Kind
    var trigger: String { "/" + id }

    /// The menu shows only while the FIRST token is being typed: a leading
    /// `/`, no space/newline yet — so "/tests write…" or normal prose never
    /// triggers it. Empty query (just "/") matches everything. Pure on its
    /// inputs; the single source of truth for both the menu and ↵-pick.
    nonisolated static func matches(for input: String,
                                    in commands: [ChatSlashCommand]) -> [ChatSlashCommand] {
        guard input.hasPrefix("/"), !input.contains(" "), !input.contains("\n") else { return [] }
        let q = input.dropFirst().lowercased()
        return commands.filter { q.isEmpty || $0.id.hasPrefix(q) }
    }

    /// Slug a saved-prompt title into a slash trigger: lowercased, spaces →
    /// dashes, everything else non-alphanumeric dropped ("Fix my Code!" →
    /// "fix-my-code"). Empty result = title unusable as a trigger. Pure for
    /// tests.
    nonisolated static func slug(_ title: String) -> String {
        String(title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" })
    }
}
