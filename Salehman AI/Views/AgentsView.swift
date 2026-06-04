import SwiftUI

/// The Agents tab: live status of every agent in the pipeline, an Autonomous
/// Mode control, and a text field to send a direct command to the agent team.
struct AgentsView: View {
    @ObservedObject private var progress = MissionProgress.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var directCommand: String = ""
    @State private var isRunningAutonomous = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.12), Color.black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: DS.Space.lg) {
                        autonomousControlSection
                        agentsGrid
                    }
                    .padding(DS.Space.xl)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("Agents")
                .font(DS.Typography.titleL).foregroundStyle(.white)
            Spacer()
            Text("\(AgentDefinitions.pipeline.count) agents")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.lg)
        .padding(.bottom, DS.Space.md)
    }

    private var autonomousControlSection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)
                    Text("Autonomous Mode")
                        .font(.headline).foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: $settings.autonomousMode)
                        .labelsHidden()
                        .tint(Color.accentColor)
                }

                Text(settings.autonomousMode
                     ? "Agents can chain tasks, self-correct, and continue working with minimal input."
                     : "Classic mode: you give a mission — they execute once.")
                    .font(.caption).foregroundStyle(.secondary)

                if settings.autonomousMode {
                    Button {
                        Task { await startAutonomousRun() }
                    } label: {
                        Label(isRunningAutonomous ? "Running…" : "Start Autonomous Run",
                              systemImage: isRunningAutonomous ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunningAutonomous)
                }

                HStack {
                    TextField("Give agents a direct command…", text: $directCommand)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .onSubmit { Task { await sendDirectCommand() } }

                    Button("Send") {
                        Task { await sendDirectCommand() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(directCommand.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var agentsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: DS.Space.md)], spacing: DS.Space.md) {
            ForEach(AgentDefinitions.pipeline) { spec in
                agentCard(spec)
            }
        }
    }

    private func agentCard(_ spec: AgentSpec) -> some View {
        let isActive = progress.steps.contains { $0.name == spec.name && $0.status == .running }

        return Card {
            HStack(spacing: DS.Space.md) {
                Image(systemName: spec.icon)
                    .font(.title2)
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.name)
                        .font(.headline).foregroundStyle(.white)
                    Text(spec.role)
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isActive {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func startAutonomousRun() async {
        isRunningAutonomous = true
        _ = await Orchestrator.runAndReturnResult(mission: "Enter autonomous mode and improve the app while reporting progress.")
        isRunningAutonomous = false
    }

    private func sendDirectCommand() async {
        let cmd = directCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        directCommand = ""
        _ = await AgentPipeline.run(mission: cmd)
    }
}
