import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var approval = CommandApprovalCenter.shared
    @Environment(\.dismiss) private var dismiss

    @State private var appleOK = LocalLLM.isAvailable
    @State private var ollamaUp = false
    @State private var hasVision = false
    @State private var hasCoder = false
    @State private var showMemory = false
    // Grok key entry state. `grokKeyDraft` only holds what the user is typing
    // *right now* — once they hit Save it's written to Keychain and cleared.
    // The literal key never lives in `@State` after Save.
    @State private var grokKeyDraft: String = ""
    @State private var grokTestStatus: String? = nil  // nil = idle, "" = OK, "msg" = error
    @State private var grokTesting: Bool = false
    @State private var grokKeySaved: Bool = GrokClient.hasKey()

    // Four free cloud brains. Same idle/"":OK/"msg":error convention as Grok.
    @State private var geminiKeyDraft: String = ""
    @State private var geminiTestStatus: String? = nil
    @State private var geminiTesting: Bool = false
    @State private var geminiKeySaved: Bool = GeminiClient.hasKey()

    @State private var groqKeyDraft: String = ""
    @State private var groqTestStatus: String? = nil
    @State private var groqTesting: Bool = false
    @State private var groqKeySaved: Bool = GroqClient.shared.hasKey()

    @State private var mistralKeyDraft: String = ""
    @State private var mistralTestStatus: String? = nil
    @State private var mistralTesting: Bool = false
    @State private var mistralKeySaved: Bool = MistralClient.shared.hasKey()

    @State private var cerebrasKeyDraft: String = ""
    @State private var cerebrasTestStatus: String? = nil
    @State private var cerebrasTesting: Bool = false
    @State private var cerebrasKeySaved: Bool = CerebrasClient.shared.hasKey()

    @State private var openAIKeyDraft: String = ""
    @State private var openAITestStatus: String? = nil
    @State private var openAITesting: Bool = false
    @State private var openAIKeySaved: Bool = OpenAIClient.hasKey()

    // GitHub Copilot signs in via OAuth device-flow, not a pasted key.
    @State private var copilotAuthed: Bool = CopilotClient.isAuthed()
    @State private var showCopilotSignIn = false
    @State private var copilotTesting = false
    @State private var copilotWorking: Bool? = nil   // nil = untested, true/false = result

    private var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") || $0.language.hasPrefix("ar") }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.07, blue: 0.12), Color.black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    section("Intelligence", "Apple Intelligence is Salehman AI's on-device brain.") {
                        toggle("Apple Intelligence",
                               "On-device chat & reasoning. Off disables AI replies; vision & transcription keep working.",
                               "apple.logo", $settings.useAppleIntelligence)
                    }

                    section("Brain", "Which model answers. \"Auto\" prefers Apple Intelligence when available; pinning to Ollama runs a single agent for safety; Claude Haiku and xAI Grok run in the cloud (~zero local RAM, key required).") {
                        ForEach(BrainPreference.allCases) { pref in
                            brainRow(pref)
                        }
                        claudeKeyRow
                    }

                    section("xAI Grok (Cloud)", "Sends your messages to xAI. Apple Intelligence and Ollama stay on this Mac.") {
                        grokKeyRow
                        grokModelRow
                        grokTestRow
                    }

                    section("Google Gemini (Cloud · free tier)", "Sends your messages to Google. Get a key at aistudio.google.com.") {
                        geminiKeyRow
                        geminiModelRow
                        geminiTestRow
                    }

                    section("Groq (Cloud · free tier)", "Blazing-fast Llama / Mixtral. Get a key at console.groq.com.") {
                        cloudKeyRow(provider: GroqClient.shared,
                                    keySaved: $groqKeySaved, draft: $groqKeyDraft)
                        cloudModelRow(displayName: "Groq",
                                      models: GroqClient.allModels,
                                      selection: $settings.groqModel)
                        cloudTestRow(provider: GroqClient.shared,
                                     keySaved: $groqKeySaved,
                                     testing: $groqTesting, status: $groqTestStatus)
                    }

                    section("Mistral (Cloud · free tier · EU-hosted)", "Sends your messages to Mistral. Get a key at console.mistral.ai.") {
                        cloudKeyRow(provider: MistralClient.shared,
                                    keySaved: $mistralKeySaved, draft: $mistralKeyDraft)
                        cloudModelRow(displayName: "Mistral",
                                      models: MistralClient.allModels,
                                      selection: $settings.mistralModel)
                        cloudTestRow(provider: MistralClient.shared,
                                     keySaved: $mistralKeySaved,
                                     testing: $mistralTesting, status: $mistralTestStatus)
                    }

                    section("Cerebras (Cloud · free tier · ~2000 tok/s Llama)", "Sends your messages to Cerebras. Get a key at cloud.cerebras.ai.") {
                        cloudKeyRow(provider: CerebrasClient.shared,
                                    keySaved: $cerebrasKeySaved, draft: $cerebrasKeyDraft)
                        cloudModelRow(displayName: "Cerebras",
                                      models: CerebrasClient.allModels,
                                      selection: $settings.cerebrasModel)
                        cloudTestRow(provider: CerebrasClient.shared,
                                     keySaved: $cerebrasKeySaved,
                                     testing: $cerebrasTesting, status: $cerebrasTestStatus)
                    }

                    section("Codex / OpenAI (Cloud)", "Sends your messages to OpenAI. Get a key at platform.openai.com/api-keys.") {
                        cloudKeyRow(provider: OpenAIClient.shared,
                                    keySaved: $openAIKeySaved, draft: $openAIKeyDraft)
                        cloudModelRow(displayName: "OpenAI",
                                      models: OpenAIClient.allModels,
                                      selection: $settings.openAIModel)
                        cloudTestRow(provider: OpenAIClient.shared,
                                     keySaved: $openAIKeySaved,
                                     testing: $openAITesting, status: $openAITestStatus)
                    }

                    section("GitHub Copilot (Cloud)", "Uses your existing GitHub Copilot subscription. Sign in once with GitHub — no API key.") {
                        copilotRow
                    }

                    section("Performance", "Your Mac: \(MachineInfo.summary). Higher = smarter but heavier.") {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkle.magnifyingglass").foregroundStyle(Color.accentColor)
                            Text("Recommended for your Mac: \(MachineInfo.recommendedMode.title)")
                                .font(.caption).foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Button("Use") { settings.applyRecommendedMode() }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)

                        ForEach(AppSettings.ResponseMode.allCases) { mode in
                            modeRow(mode)
                        }
                    }

                    section("Capabilities", nil) {
                        toggle("Web access", "Search & read the web", "globe", $settings.webAccess)
                        toggle("Local coding model", "Use qwen2.5-coder:32b for code", "chevron.left.forwardslash.chevron.right", $settings.useCodeModel)
                        toggle("Image vision", "Understand images with qwen2.5vl", "eye", $settings.useVision)
                        toggle("Confirm terminal commands", "Ask before running each command", "lock.shield", $approval.confirmationEnabled)
                    }

                    section("Voice", nil) {
                        toggle("Auto-speak replies", "Read every answer aloud", "speaker.wave.2", $settings.autoSpeak)
                        speedRow
                        voiceRow
                        previewRow
                    }

                    section("Privacy", "Stay hidden while screen-sharing or recording.") {
                        toggle("Hide from screen capture", "Salehman AI won't appear in screenshots, recordings, or shares (you still see it)", "eye.slash", $settings.hideFromCapture)
                        memoryRow
                    }

                    section("Status", nil) {
                        statusRow("Apple Intelligence", appleOK)
                        statusRow("Ollama server", ollamaUp)
                        statusRow("Vision model (qwen2.5vl)", hasVision)
                        statusRow("Coding model (qwen2.5-coder:32b)", hasCoder)
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
            }
        }
        .frame(width: 560, height: 640)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMemory) { MemoryView() }
        .sheet(isPresented: $showCopilotSignIn) {
            CopilotSignInView { copilotAuthed = CopilotClient.isAuthed() }
        }
        .task {
            ollamaUp = await OllamaClient.isUp()
            hasVision = await OllamaClient.hasModel(OllamaClient.visionModel)
            hasCoder = await OllamaClient.hasModel(OllamaClient.codeModel)
        }
    }

    private var header: some View {
        HStack {
            Text("Settings").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, _ subtitle: String?, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary.opacity(0.7)) }
            VStack(spacing: 1) { content() }
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func modeRow(_ mode: AppSettings.ResponseMode) -> some View {
        Button { settings.responseMode = mode } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.icon).foregroundStyle(settings.responseMode == mode ? Color.accentColor : .secondary).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.title).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text(mode.detail).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if settings.responseMode == mode {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Brain-preference row. The trailing pill shows whether the pinned brain
    /// is actually reachable right now — so a user who picks "Ollama" while
    /// the server is down can see immediately why they're getting no replies.
    private func brainRow(_ pref: BrainPreference) -> some View {
        let selected = settings.brainPreference == pref
        let ready: Bool = {
            switch pref {
            case .auto:        return (appleOK && settings.useAppleIntelligence) || (ollamaUp && hasCoder)
            case .apple:       return appleOK && settings.useAppleIntelligence
            case .ollama:      return ollamaUp && hasCoder
            case .claudeHaiku: return !settings.anthropicAPIKey.trimmingCharacters(in: .whitespaces).isEmpty
            case .grok:        return GrokClient.hasKey()
            case .gemini:      return GeminiClient.hasKey()
            case .groq:        return GroqClient.shared.hasKey()
            case .mistral:     return MistralClient.shared.hasKey()
            case .cerebras:    return CerebrasClient.shared.hasKey()
            case .codex:       return OpenAIClient.hasKey()
            case .copilot:     return CopilotClient.isAuthed()
            }
        }()
        return Button { settings.brainPreference = pref } label: {
            HStack(spacing: 12) {
                Image(systemName: pref.icon)
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(pref.title).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text(pref.subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(ready ? "Ready" : "Unavailable")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ready ? Color.green : Color.orange.opacity(0.9))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((ready ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: xAI Grok rows
    //
    // Three small rows make up the Grok config UI:
    //   * grokKeyRow   — paste key into SecureField + Save (writes to Keychain).
    //   * grokModelRow — picker between grok-4 and grok-4-heavy.
    //   * grokTestRow  — "Test connection" button + status text.
    //
    // The literal key only lives in `grokKeyDraft` while the user is typing.
    // After Save, the draft is cleared and the bytes live only in Keychain.

    /// SecureField + Save/Clear. "Save" writes to Keychain and wipes the draft.
    private var grokKeyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("xAI API key").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(grokKeySaved ? "Saved in macOS Keychain · paste a new one to replace"
                                  : "Get one at console.x.ai → API Keys")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            SecureField("xai-…", text: $grokKeyDraft)
                .textFieldStyle(.plain).frame(width: 130)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
            Button("Save") {
                let trimmed = grokKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                _ = KeychainStore.write(trimmed, to: .grokAPIKey)
                grokKeyDraft = ""             // Wipe the in-memory copy immediately.
                grokKeySaved = GrokClient.hasKey()
                Task { await BrainStatus.shared.refresh() }   // Refresh header dot.
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(grokKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            if grokKeySaved {
                Button("Clear") {
                    _ = KeychainStore.delete(.grokAPIKey)
                    grokKeySaved = false
                    grokTestStatus = nil
                    Task { await BrainStatus.shared.refresh() }
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.red)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Picker between grok-4 (default) and grok-4-heavy.
    private var grokModelRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Model").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text("`grok-4` is the default; `grok-4-heavy` reasons deeper (slower / more $).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $settings.grokModel) {
                ForEach(GrokClient.allModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .labelsHidden().pickerStyle(.menu).frame(width: 150)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Test-connection button. Hits the live API with a tiny prompt to verify
    /// the saved key actually works (vs. a typo we silently 401 on later).
    private var grokTestRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Test connection").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(grokTestStatusText)
                    .font(.caption2)
                    .foregroundStyle(grokTestStatusColor)
            }
            Spacer()
            Button {
                grokTesting = true
                grokTestStatus = nil
                Task {
                    let err = await GrokClient.testConnection()
                    await MainActor.run {
                        grokTestStatus = err ?? ""    // "" = success
                        grokTesting = false
                    }
                }
            } label: {
                if grokTesting { ProgressView().controlSize(.small) }
                else           { Text("Test") }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(grokTesting || !grokKeySaved)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var grokTestStatusText: String {
        switch grokTestStatus {
        case nil:           return "Tap Test after saving the key."
        case .some(""):     return "Connected — your key works."
        case .some(let m):  return m
        }
    }

    /// GitHub Copilot OAuth device-flow sign-in + a live "is it working" check.
    private var copilotRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "person.2.badge.gearshape.fill")
                    .foregroundStyle(.secondary).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("GitHub Copilot")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text(copilotAuthed ? "Signed in · token stored in macOS Keychain"
                                       : "Requires an active Copilot subscription")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if copilotAuthed {
                    Button("Sign out") {
                        CopilotAuth.signOut()
                        copilotAuthed = false
                        copilotWorking = nil
                    }
                    .font(.caption.weight(.semibold)).buttonStyle(.bordered)
                    .controlSize(.small).tint(.red)
                } else {
                    Button("Sign in with GitHub") { showCopilotSignIn = true }
                        .font(.caption.weight(.semibold)).buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            if copilotAuthed {
                HStack(spacing: 8) {
                    workingBadge(testing: copilotTesting, working: copilotWorking)
                    Spacer()
                    Button("Test") { Task { await testCopilot() } }
                        .font(.caption2.weight(.semibold)).buttonStyle(.bordered)
                        .controlSize(.mini).disabled(copilotTesting)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Reusable "is this brain actually working" badge: spinner while testing,
    /// then a green ✓ Working / red ✗ Not working / grey "Not tested".
    @ViewBuilder
    private func workingBadge(testing: Bool, working: Bool?) -> some View {
        HStack(spacing: 6) {
            if testing {
                ProgressView().controlSize(.mini)
                Text("Checking…").font(.caption2).foregroundStyle(.secondary)
            } else if let working {
                Image(systemName: working ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(working ? .green : .red)
                Text(working ? "Working" : "Not working")
                    .font(.caption2).foregroundStyle(working ? .green : .orange)
            } else {
                Image(systemName: "circle.dashed").foregroundStyle(.secondary)
                Text("Not tested").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// Live ping for Copilot — does a one-token chat through the real path.
    private func testCopilot() async {
        copilotTesting = true
        copilotWorking = nil
        let ok = await CopilotClient.chat(prompt: "ping") != nil
        copilotTesting = false
        copilotWorking = ok
    }

    private var grokTestStatusColor: Color {
        switch grokTestStatus {
        case nil:        return .secondary
        case .some(""):  return .green
        case .some(_):   return .orange
        }
    }

    // MARK: Generic OpenAI-compatible cloud rows
    //
    // The three OpenAI-compatible brains (Groq, Mistral, Cerebras) share the
    // exact same UI shape — key entry + model picker + test. These helpers
    // take an `OpenAICompatibleClient` so each provider's Settings section is
    // ~10 lines of call site instead of ~150 lines of copy-paste.

    @ViewBuilder
    private func cloudKeyRow(provider: OpenAICompatibleClient,
                             keySaved: Binding<Bool>,
                             draft: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(provider.displayName) API key")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(keySaved.wrappedValue
                     ? "Saved in macOS Keychain · paste a new one to replace"
                     : "Get one at \(provider.consoleURL)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            SecureField("key…", text: draft)
                .textFieldStyle(.plain).frame(width: 130)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
            Button("Save") {
                let trimmed = draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                _ = KeychainStore.write(trimmed, to: provider.keychainAccount)
                draft.wrappedValue = ""
                keySaved.wrappedValue = provider.hasKey()
                Task { await BrainStatus.shared.refresh() }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            if keySaved.wrappedValue {
                Button("Clear") {
                    _ = KeychainStore.delete(provider.keychainAccount)
                    keySaved.wrappedValue = false
                    Task { await BrainStatus.shared.refresh() }
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.red)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    @ViewBuilder
    private func cloudModelRow(displayName: String,
                               models: [String],
                               selection: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cube").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(displayName) model")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text("First in the list is the lightest; last is the heaviest.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: selection) {
                ForEach(models, id: \.self) { model in Text(model).tag(model) }
            }
            .labelsHidden().pickerStyle(.menu).frame(width: 200)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    @ViewBuilder
    private func cloudTestRow(provider: OpenAICompatibleClient,
                              keySaved: Binding<Bool>,
                              testing: Binding<Bool>,
                              status: Binding<String?>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Test connection")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(testStatusText(status.wrappedValue))
                    .font(.caption2).foregroundStyle(testStatusColor(status.wrappedValue))
            }
            Spacer()
            Button {
                testing.wrappedValue = true
                status.wrappedValue = nil
                Task {
                    let err = await provider.testConnection()
                    await MainActor.run {
                        status.wrappedValue = err ?? ""
                        testing.wrappedValue = false
                    }
                }
            } label: {
                if testing.wrappedValue { ProgressView().controlSize(.small) }
                else                    { Text("Test") }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(testing.wrappedValue || !keySaved.wrappedValue)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func testStatusText(_ status: String?) -> String {
        switch status {
        case nil:           return "Tap Test after saving the key."
        case .some(""):     return "Connected — your key works."
        case .some(let m):  return m
        }
    }

    private func testStatusColor(_ status: String?) -> Color {
        switch status {
        case nil:        return .secondary
        case .some(""):  return .green
        case .some(_):   return .orange
        }
    }

    // MARK: Google Gemini rows
    //
    // Gemini doesn't speak OpenAI's wire format, so it has its own client
    // and its own row triplet. Same shape as the generic cloud rows above.

    private var geminiKeyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Gemini API key").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(geminiKeySaved
                     ? "Saved in macOS Keychain · paste a new one to replace"
                     : "Get one at aistudio.google.com → Get API key")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            SecureField("AIza…", text: $geminiKeyDraft)
                .textFieldStyle(.plain).frame(width: 130)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
            Button("Save") {
                let trimmed = geminiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                _ = KeychainStore.write(trimmed, to: .geminiAPIKey)
                geminiKeyDraft = ""
                geminiKeySaved = GeminiClient.hasKey()
                Task { await BrainStatus.shared.refresh() }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(geminiKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            if geminiKeySaved {
                Button("Clear") {
                    _ = KeychainStore.delete(.geminiAPIKey)
                    geminiKeySaved = false
                    geminiTestStatus = nil
                    Task { await BrainStatus.shared.refresh() }
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.red)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var geminiModelRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Gemini model").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text("`gemini-2.0-flash` is the default; `gemini-1.5-pro` is deeper.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $settings.geminiModel) {
                ForEach(GeminiClient.allModels, id: \.self) { model in Text(model).tag(model) }
            }
            .labelsHidden().pickerStyle(.menu).frame(width: 200)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var geminiTestRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Test connection").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(testStatusText(geminiTestStatus))
                    .font(.caption2).foregroundStyle(testStatusColor(geminiTestStatus))
            }
            Spacer()
            Button {
                geminiTesting = true
                geminiTestStatus = nil
                Task {
                    let err = await GeminiClient.testConnection()
                    await MainActor.run {
                        geminiTestStatus = err ?? ""
                        geminiTesting = false
                    }
                }
            } label: {
                if geminiTesting { ProgressView().controlSize(.small) }
                else             { Text("Test") }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(geminiTesting || !geminiKeySaved)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Anthropic API key entry — only needed for the Claude Haiku (cloud) brain.
    private var claudeKeyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Anthropic API key").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text("Needed only for Claude Haiku. Stored on this Mac.").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            SecureField("sk-ant-…", text: $settings.anthropicAPIKey)
                .textFieldStyle(.plain).frame(width: 150)
                .multilineTextAlignment(.trailing).foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func toggle(_ title: String, _ subtitle: String, _ icon: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: binding).labelsHidden().toggleStyle(.switch).tint(Color.accentColor)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: Voice rows
    private var speedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "speedometer").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Speaking speed").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text("How fast replies are read aloud").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Slider(value: $settings.speechRate, in: 0...1).frame(width: 150).tint(Color.accentColor)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var voiceRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.wave.2").foregroundStyle(.secondary).frame(width: 22)
            Text("Voice").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
            Spacer()
            Picker("", selection: $settings.speechVoiceID) {
                Text("Automatic").tag("")
                ForEach(voices, id: \.identifier) { v in
                    Text("\(v.name) (\(v.language))").tag(v.identifier)
                }
            }
            .labelsHidden().frame(width: 210)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var previewRow: some View {
        HStack {
            Spacer()
            Button {
                SpeechOut.shared.speak("Hi Saleh, this is how I'll sound when reading your replies.", id: UUID())
            } label: {
                Label("Preview voice", systemImage: "play.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered).controlSize(.small).tint(Color.accentColor)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var memoryRow: some View {
        Button { showMemory = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "brain").foregroundStyle(.secondary).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Manage memory").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text("See and delete what Salehman AI remembers about you").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusRow(_ title: String, _ ok: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red).frame(width: 22)
            Text(title).font(.system(size: 14)).foregroundStyle(.white)
            Spacer()
            Text(ok ? "Ready" : "Off").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}
