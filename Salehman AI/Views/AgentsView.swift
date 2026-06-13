import SwiftUI

/// The Agents tab: live status of every agent in the pipeline, an Autonomous
/// Mode control, and a text field to send a direct command to the agent team.
struct AgentsView: View {
    @ObservedObject private var progress = MissionProgress.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var directCommand: String = ""
    @State private var agentSearch: String = ""
    /// Focus drives a subtle accent glow on the filter field — consistent with
    /// the app's other text inputs (add-note/composer focus affordance).
    @FocusState private var searchFocused: Bool
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
    @State private var runHistory: [RunEntry] = []
    @State private var hoveredRunID: UUID?
    /// Staggered entrance — sections fade up on first appear. Pre-set under
    /// `--qa` so the offscreen snapshot (onAppear never fires) captures the
    /// settled layout, not the opacity-0 pre-entrance pose.
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")

    var body: some View {
        ZStack {
            DS.Palette.codeSurface.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: DS.Space.lg) {
                        autonomousControlSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DS.Motion.entrance.delay(0.06), value: appeared)
                        if !runHistory.isEmpty {
                            runHistorySection
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .opacity(appeared ? 1 : 0)
                                .animation(DS.Motion.entrance.delay(0.10), value: appeared)
                        }
                        agentsGrid
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DS.Motion.entrance.delay(0.14), value: appeared)
                    }
                    .animation(DS.Motion.smooth, value: runHistory.isEmpty)
                    .padding(DS.Space.xl)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { appeared = true }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.md) {
            // Brand icon tile — consistent with TodayView header treatment.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Gradient.brand)
                    .frame(width: 36, height: 36)
                    .dsShadow(DS.Elevation.accentGlow(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.02)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 0.75
                            )
                    )
                KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.60, duration: 0.07)
                        SpringKeyframe(1.18, duration: 0.28, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.22, spring: .bouncy)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Agents")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    Eyebrow(text: "Specialist Team")
                }
                Text("They plan, build, and review together.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.lg)
        .padding(.bottom, DS.Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(DS.Motion.entrance, value: appeared)
    }

    // MARK: Autonomous Control

    private var autonomousControlSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(spacing: 10) {
                // Mode icon — glows brand when active.
                ZStack {
                    Circle()
                        .fill(settings.autonomousMode
                              ? DS.Palette.accent.opacity(0.20)
                              : Color.white.opacity(0.07))
                        .frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(settings.autonomousMode ? DS.Palette.accent : .secondary)
                }
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
                .contentTransition(.opacity)
                .animation(DS.Motion.smooth, value: settings.autonomousMode)

            if settings.autonomousMode {
                Button {
                    if isRunningAutonomous {
                        showStopConfirm = true
                    } else {
                        toggleAutonomousRun()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isRunningAutonomous ? "stop.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .contentTransition(.symbolEffect(.replace))
                            .animation(DS.Motion.smooth, value: isRunningAutonomous)
                        Text(isRunningAutonomous
                             ? "Stop  ·  iteration \(iterationCount)"
                             : "Start Autonomous Run")
                            .font(.system(size: 13, weight: .semibold))
                            .contentTransition(.opacity)
                            .animation(DS.Motion.smooth, value: isRunningAutonomous)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(
                        isRunningAutonomous
                            ? AnyShapeStyle(DS.Palette.danger.opacity(0.85))
                            : AnyShapeStyle(DS.Gradient.brand),
                        in: Capsule()
                    )
                    .shadow(color: (isRunningAutonomous ? DS.Palette.danger : DS.Palette.accent).opacity(0.30),
                            radius: 8, y: 3)
                }
                .buttonStyle(LuxPressStyle())
                .confirmationDialog("Stop the autonomous run?",
                                    isPresented: $showStopConfirm,
                                    titleVisibility: .visible) {
                    Button("Stop", role: .destructive) { toggleAutonomousRun() }
                    Button("Keep running", role: .cancel) {}
                } message: {
                    Text("The current iteration's in-flight work will be cancelled. Anything already returned is kept.")
                }

                if isRunningAutonomous && !lastResultPreview.isEmpty {
                    Text("Latest: \(lastResultPreview.prefix(160))…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .offset(y: -4)))
                }
            }

            // Direct command field.
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent.opacity(0.70))
                    TextField("Give agents a direct command…", text: $directCommand)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit { Task { await sendDirectCommand() } }
                        .onKeyPress(.escape) { directCommand = ""; return .handled }
                        .accessibilityLabel("Direct command to agents")
                }
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color.white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                    .stroke(DS.Palette.surfaceStroke, lineWidth: 1))

                Button("Send") {
                    Task { await sendDirectCommand() }
                }
                .buttonStyle(.bordered)
                .tint(DS.Palette.accent)
                .disabled(directCommand.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DS.Space.lg)
        // Bezel treatment: outer shell + inner core tinted by mode state.
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Bezel.innerRadius, style: .continuous)
                    .fill(settings.autonomousMode
                          ? DS.Palette.accent.opacity(0.07)
                          : DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Bezel.innerRadius, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .padding(DS.Bezel.shellPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.Bezel.outerRadius, style: .continuous)
                .fill(DS.Bezel.shellFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Bezel.outerRadius, style: .continuous)
                .stroke(isRunningAutonomous
                        ? DS.Palette.accent.opacity(0.35)
                        : DS.Bezel.shellStroke,
                        lineWidth: 1)
        )
        // Accent glow materialises while a run is in progress.
        .shadow(color: DS.Palette.accent.opacity(isRunningAutonomous ? 0.18 : 0.0),
                radius: 18, y: 6)
        .animation(DS.Motion.smooth, value: settings.autonomousMode)
        .animation(DS.Motion.smooth, value: isRunningAutonomous)
    }

    // MARK: Agent grid

    private var agentsGrid: some View {
        let agents = AgentFilter.matching(AgentDefinitions.pipeline, query: agentSearch)
        return VStack(alignment: .leading, spacing: DS.Space.md) {
            agentSearchRow
            if agents.isEmpty {
                Text("No agents match “\(agentSearch)”.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                    .transition(.opacity)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Space.md)], spacing: DS.Space.md) {
                    ForEach(agents) { spec in
                        AgentCard(spec: spec,
                                  isActive: progress.steps.contains { $0.name == spec.name && $0.status == .running })
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(DS.Motion.smooth, value: agents.isEmpty)
    }

    private var agentSearchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("Filter agents…", text: $agentSearch)
                .textFieldStyle(.plain).font(.system(size: 13))
                .focused($searchFocused)
                .onKeyPress(.escape) { agentSearch = ""; return .handled }
                .accessibilityLabel("Filter agents")
            if !agentSearch.isEmpty {
                Button { agentSearch = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear filter")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        .shadow(color: DS.Palette.accent.opacity(searchFocused ? 0.15 : 0), radius: 10, y: 2)
        .animation(DS.Motion.magnetic, value: agentSearch.isEmpty)
        .animation(DS.Motion.lux, value: searchFocused)
    }

    // MARK: Run history

    private var runHistorySection: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(spacing: 6) {
                Text("Run log")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(runHistory.count)")
                    .font(.caption2.monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(DS.Motion.smooth, value: runHistory.count)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(DS.Palette.accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(DS.Palette.accent)
                Spacer()
                Button("Clear") { withAnimation(DS.Motion.smooth) { runHistory.removeAll() } }
                    .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            VStack(spacing: 1) {
                ForEach(runHistory) { entry in
                    let entryHovered = hoveredRunID == entry.id
                    HStack(spacing: 10) {
                        Text("#\(entry.iteration)")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                            .foregroundStyle(DS.Palette.accent)
                            .frame(minWidth: 28, alignment: .trailing)
                        Text(entry.preview)
                            .font(.caption2)
                            .foregroundStyle(entryHovered ? .white.opacity(0.9) : DS.Palette.textSecondary)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        Text(entry.timestamp, style: .time)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                    .padding(.horizontal, DS.Space.md).padding(.vertical, 7)
                    .background(entryHovered ? DS.Palette.accent.opacity(0.06) : Color.clear)
                    .contentShape(Rectangle())
                    .onHover { over in
                        withAnimation(DS.Motion.smooth) {
                            if over { hoveredRunID = entry.id }
                            else if hoveredRunID == entry.id { hoveredRunID = nil }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(DS.Motion.smooth, value: runHistory.count)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(DS.Bezel.cardFill)
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        }
    }

    // MARK: Autonomous run logic

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
            var mission = "Enter autonomous mode and improve the app while reporting progress. Pick one concrete next step you can take with the tools available, and produce a useful artifact (analysis, code, a plan, or a measurable change)."

            var i = 0
            while !Task.isCancelled {
                i += 1
                await MainActor.run { iterationCount = i }

                let result = await AgentPipeline.run(mission: mission)
                if Task.isCancelled { break }

                await MainActor.run {
                    withAnimation(DS.Motion.smooth) {
                        lastResultPreview = result
                        runHistory.insert(
                            RunEntry(iteration: i, preview: String(result.prefix(120)), timestamp: Date()),
                            at: 0
                        )
                    }
                }

                if result.contains("AUTONOMOUS_DONE") { break }

                mission = """
                You are in an autonomous run (iteration \(i + 1), no fixed end).

                Previous iteration's result:
                \(result.prefix(2000))

                Continue working. If the previous step achieved its goal, propose and execute the next useful improvement. If it didn't, refine the approach and produce a better result. Stop by saying "AUTONOMOUS_DONE" on its own line when there's nothing useful left to do.
                """

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

/// Premium agent card — `RoundedRectangle` icon well (consistent with
/// TodayView's ActionTile), bezel fill, magnetic hover, and an accent glow
/// that materialises when the agent is actively running.
private struct AgentCard: View {
    let spec: AgentSpec
    let isActive: Bool
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DS.Space.md) {
            // Icon well — brand gradient when active, subtle fill at rest.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                    .fill(isActive
                          ? AnyShapeStyle(DS.Gradient.brand)
                          : AnyShapeStyle(Color.white.opacity(hovering ? 0.10 : 0.06)))
                    .frame(width: 42, height: 42)
                    .shadow(color: DS.Palette.accent.opacity(isActive ? 0.40 : 0.0),
                            radius: 8, y: 3)
                Image(systemName: spec.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isActive ? .white : Color.white.opacity(0.80))
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(isActive ? 0.45 : 0.18),
                                                    Color.white.opacity(isActive ? 0.08 : 0.04)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
            )
            .scaleEffect(hovering ? 1.06 : 1.0)

            VStack(alignment: .leading, spacing: 3) {
                Text(spec.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(spec.role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)

            // Status indicator — pulsing dot + spinner when running, subtle
            // arrow at rest. PhaseAnimator gives the dot a heartbeat glow.
            if isActive {
                HStack(spacing: 5) {
                    if reduceMotion {
                        // Reduce Motion: static running dot (no heartbeat glow).
                        Circle()
                            .fill(DS.Palette.successSoft)
                            .frame(width: 6, height: 6)
                            .shadow(color: DS.Palette.successSoft.opacity(0.50), radius: 2)
                    } else {
                        PhaseAnimator([false, true]) { bright in
                            Circle()
                                .fill(DS.Palette.successSoft)
                                .frame(width: 6, height: 6)
                                .shadow(color: DS.Palette.successSoft.opacity(bright ? 0.75 : 0.20),
                                        radius: bright ? 4 : 1)
                        } animation: { bright in
                            bright ? .easeIn(duration: 0.60) : .easeOut(duration: 1.0)
                        }
                    }
                    ProgressView().controlSize(.small)
                }
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else if hovering {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.60))
                    .transition(.opacity)
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.07 : 0.04))
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(isActive
                    ? LinearGradient(colors: [DS.Palette.accent.opacity(0.65),
                                              DS.Palette.accent.opacity(0.16)],
                                     startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color.white.opacity(hovering ? 0.16 : 0.07),
                                              Color.white.opacity(hovering ? 0.16 : 0.07)],
                                     startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
        )
        .scaleEffect(hovering ? 1.015 : 1.0)
        .shadow(color: DS.Palette.accent.opacity(isActive ? 0.14 : 0.0), radius: 12, y: 5)
        .onHover { h in withAnimation(DS.Motion.magnetic) { hovering = h } }
        .animation(DS.Motion.smooth, value: isActive)
        // One VoiceOver element per card; expose the running state, which is
        // otherwise conveyed ONLY by the pulsing dot vs. arrow (invisible to VO).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(spec.name), \(spec.role)")
        .accessibilityValue(isActive ? "Running" : "Idle")
    }
}

/// Pure agent-grid filter (Chat C feature): case-insensitive match on the agent's
/// name OR its role text. Empty query → the whole pipeline. Pure → unit-tested.
enum AgentFilter {
    static func matching(_ specs: [AgentSpec], query: String) -> [AgentSpec] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return specs }
        return specs.filter { $0.name.lowercased().contains(q) || $0.role.lowercased().contains(q) }
    }
}

// MARK: - Run-log entry
/// One completed autonomous iteration: its number, first 120 chars of output, and the wall-clock time it finished.
private struct RunEntry: Identifiable {
    let id = UUID()
    let iteration: Int
    let preview: String
    let timestamp: Date
}
