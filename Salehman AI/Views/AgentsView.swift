import SwiftUI

/// The Agents tab: live status of every agent in the pipeline, an Autonomous
/// Mode control, and a text field to send a direct command to the agent team.
struct AgentsView: View {
    @ObservedObject private var progress = MissionProgress.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var directCommand: String = ""
    @State private var isRunningAutonomous = false

    // Real autonomous-loop state. The Task lets us actually *cancel*
    // mid-run (flipping a boolean alone doesn't interrupt an in-flight
    // `AgentPipeline.run`).
    //
    // There is intentionally NO hard iteration cap — the user asked for
    // "run forever". The only stop conditions are:
    //   1. The Stop button (Task.cancel → checked between iterations).
    //   2. Agents emitting `AUTONOMOUS_DONE` in their reply (self-complete).
    // The 1.5s inter-iteration sleep stays — it's the gap that gives the
    // Stop button a chance to fire on a fast cloud brain.
    @State private var autonomousTask: Task<Void, Never>? = nil
    @State private var iterationCount = 0
    @State private var lastResultPreview: String = ""
    // Drives the Stop confirmation dialog — guards against an accidental click
    // discarding the current iteration's work mid-run.
    @State private var showStopConfirm = false

    var body: some View {
        ZStack {
            // Flat opaque working canvas (design language) — no gradients,
            // no glow show-through on chat-like/working surfaces.
            DS.Palette.codeSurface.ignoresSafeArea()

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
        // Slimmer header, chrome diet: the "N agents" counter badge is gone —
        // not actionable, and the gallery below already shows the team.
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agents")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                Text("Your specialist team — they plan, build, and review together.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.lg)
        .padding(.bottom, DS.Space.md)
    }

    private var autonomousControlSection: some View {
        // Flat card per the design language (was a glass-hero with gradient
        // wash + accent glow). Logic below (toggleAutonomousRun /
        // sendDirectCommand / settings binding) is unchanged — chrome only.
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent)
                Text("Autonomous Mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Toggle("Autonomous Mode", isOn: $settings.autonomousMode)
                    .labelsHidden()
                    .tint(DS.Palette.accent)
            }

            Text(settings.autonomousMode
                 ? "Agents can chain tasks, self-correct, and continue working with minimal input."
                 : "Classic mode: you give a mission — they execute once.")
                .font(.caption).foregroundStyle(DS.Palette.textSecondary)

            if settings.autonomousMode {
                Button {
                    // While running, an accidental click could discard
                    // mid-iteration work — confirm first. Starting is a normal
                    // tap (no confirmation needed).
                    if isRunningAutonomous {
                        showStopConfirm = true
                    } else {
                        toggleAutonomousRun()
                    }
                } label: {
                    Label(isRunningAutonomous
                          ? "Stop (iteration \(iterationCount))"
                          : "Start Autonomous Run",
                          systemImage: isRunningAutonomous ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunningAutonomous ? .red : DS.Palette.accent)
                .confirmationDialog("Stop the autonomous run?",
                                    isPresented: $showStopConfirm,
                                    titleVisibility: .visible) {
                    Button("Stop", role: .destructive) { toggleAutonomousRun() }
                    Button("Keep running", role: .cancel) {}
                } message: {
                    Text("The current iteration's in-flight work will be cancelled. Anything already returned is kept.")
                }

                if isRunningAutonomous && !lastResultPreview.isEmpty {
                    // Show the head of the latest reply so the user has
                    // visible proof the loop is actually iterating.
                    Text("Latest: \(lastResultPreview.prefix(160))…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }
            }

            HStack {
                TextField("Give agents a direct command…", text: $directCommand)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color.white.opacity(0.09),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onSubmit { Task { await sendDirectCommand() } }

                Button("Send") {
                    Task { await sendDirectCommand() }
                }
                .buttonStyle(.bordered)
                .tint(DS.Palette.accent)
                .disabled(directCommand.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DS.Space.lg)
        // Flat opaque card + hairline — no gradient wash, no glow shadow.
        .background(DS.Palette.codeSurfaceSide,
                    in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1)
        )
    }

    private var agentsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Space.md)], spacing: DS.Space.md) {
            ForEach(AgentDefinitions.pipeline) { spec in
                AgentCard(spec: spec,
                          isActive: progress.steps.contains { $0.name == spec.name && $0.status == .running })
            }
        }
    }

    /// Toggle between starting and stopping the autonomous loop.
    ///
    /// Why a `Task` (not just a boolean flag): `AgentPipeline.run` is `async`,
    /// and a `bool = false` doesn't interrupt an in-flight pipeline call.
    /// Stopping requires `Task.cancel()` so `Task.isCancelled` checks
    /// between iterations actually fire.
    ///
    /// **No iteration cap.** This loop runs until one of:
    ///   1. The user presses Stop (cancels the Task).
    ///   2. The agents emit `AUTONOMOUS_DONE` in a reply (self-complete).
    /// On a paid cloud brain each iteration is a billed API call. The 1.5s
    /// inter-iteration sleep is what gives the Stop button a window to
    /// actually interrupt — without it a fast brain (Groq, Cerebras) would
    /// chain calls so fast the UI couldn't get a frame to register the tap.
    private func toggleAutonomousRun() {
        if isRunningAutonomous {
            autonomousTask?.cancel()
            autonomousTask = nil
            isRunningAutonomous = false
            return
        }

        isRunningAutonomous = true
        iterationCount = 0
        lastResultPreview = ""

        autonomousTask = Task {
            // First iteration uses a generic improvement prompt; subsequent
            // iterations feed the previous reply back as context so the
            // agents are *chaining*, not redoing the same prompt.
            var mission = "Enter autonomous mode and improve the app while reporting progress. Pick one concrete next step you can take with the tools available, and produce a useful artifact (analysis, code, a plan, or a measurable change)."

            var i = 0
            while !Task.isCancelled {
                i += 1
                await MainActor.run { iterationCount = i }

                let result = await AgentPipeline.run(mission: mission)
                if Task.isCancelled { break }

                await MainActor.run {
                    lastResultPreview = result
                }

                // Bail if the agents signaled completion. This is now the
                // ONLY natural stop condition (besides the user's Stop tap),
                // since there's no iteration cap.
                if result.contains("AUTONOMOUS_DONE") { break }

                // Feed the previous result into the next iteration's mission
                // so agents see what they just produced and can build on it,
                // not redo the same task. We no longer reference an
                // "iteration X of Y" — there is no Y.
                mission = """
                You are in an autonomous run (iteration \(i + 1), no fixed end).

                Previous iteration's result:
                \(result.prefix(2000))

                Continue working. If the previous step achieved its goal, propose and execute the next useful improvement. If it didn't, refine the approach and produce a better result. Stop by saying "AUTONOMOUS_DONE" on its own line when there's nothing useful left to do.
                """

                // Brief pause between iterations so a user hitting Stop has
                // a chance to interrupt cleanly, and so a runaway loop
                // doesn't slam the cloud brain back-to-back.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if Task.isCancelled { break }
            }

            await MainActor.run {
                isRunningAutonomous = false
                autonomousTask = nil
            }
        }
    }

    private func sendDirectCommand() async {
        let cmd = directCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        directCommand = ""
        _ = await AgentPipeline.run(mission: cmd)
    }
}

// MARK: - Agent gallery card
// Extracted to its own `View` so it can own `@State hovering` (a `@State` can't
// live inside a `func` body). Themed icon circle (accent when the agent is
// running), hover lift, and the new `DS.Elevation` shadows.
private struct AgentCard: View {
    let spec: AgentSpec
    let isActive: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: DS.Space.md) {
            ZStack {
                Circle()
                    .fill(isActive ? DS.Palette.accent.opacity(0.18) : Color.white.opacity(0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: spec.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isActive ? DS.Palette.accent : Color.white.opacity(0.85))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(spec.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(spec.role).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            if isActive { ProgressView().controlSize(.small) }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Flat opaque card + hairline; the hover/active stroke is the only
        // elevation cue (no shadows — design language).
        .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(isActive ? DS.Palette.accent.opacity(0.5)
                                 : (hovering ? Color.white.opacity(0.16) : DS.Palette.surfaceStroke),
                        lineWidth: 1)
        )
        .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
    }
}
