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
