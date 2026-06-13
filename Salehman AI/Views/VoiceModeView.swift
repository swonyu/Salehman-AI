import SwiftUI

/// Hands-Free Voice Mode — a full-screen talk↔listen surface. All loop behavior
/// lives in `VoiceSession`; this view is pure DS.*-styled chrome bound to it.
struct VoiceModeView: View {
    let onClose: () -> Void
    @StateObject private var session = VoiceSession()
    @State private var savedConfirmation = false
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")

    private var phaseColor: Color {
        switch session.phase {
        case .listening: return DS.Palette.accent
        case .thinking:  return DS.Palette.warningSoft
        case .speaking:  return DS.Palette.successSoft
        case .idle:      return Color.white.opacity(0.3)
        }
    }

    private var phaseLabel: String {
        switch session.phase {
        case .idle:      return "Starting…"
        case .listening: return "Listening…"
        case .thinking:  return "Thinking…"
        case .speaking:  return "Speaking…"
        }
    }

    private var animate: Bool { session.phase == .listening || session.phase == .speaking }

    /// Save the whole hands-free exchange to the Notes scratchpad (on-device),
    /// with a brief in-place ✓ confirmation. No-op when there are no turns yet.
    private func saveToNotes() {
        guard !session.turns.isEmpty else { return }
        let lines = session.turns.map { "\($0.role == .salehman ? "Salehman" : "You"): \($0.text)" }
        let transcript = "🎙 Voice conversation\n\n" + lines.joined(separator: "\n")
        ScratchpadStore.shared.addNote(transcript)
        withAnimation(DS.Motion.smooth) { savedConfirmation = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(DS.Motion.smooth) { savedConfirmation = false }
        }
    }

    var body: some View {
        ZStack {
            DS.Palette.codeSurface.ignoresSafeArea()   // flat working canvas (design language)

            VStack(spacing: DS.Space.lg) {
                HStack(spacing: DS.Space.md) {
                    // Brand icon tile.
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .fill(DS.Gradient.brand)
                            .frame(width: 32, height: 32)
                            .dsShadow(DS.Elevation.accentGlow(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                                    .stroke(LinearGradient(colors: [.white.opacity(0.48), .white.opacity(0.02)],
                                                           startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
                            )
                        KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                            Image(systemName: "waveform")
                                .font(.system(size: 13, weight: .bold))
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
                        Text("Talk to Salehman")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Eyebrow(text: "Hands-Free Voice")
                    }
                    Spacer()
                    Button { saveToNotes() } label: {
                        Image(systemName: savedConfirmation ? "checkmark.circle.fill" : "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(savedConfirmation ? DS.Palette.successSoft : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                            .animation(DS.Motion.smooth, value: savedConfirmation)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.07), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.75))
                    }
                    .buttonStyle(LuxPressStyle()).disabled(session.turns.isEmpty)
                    .help("Save this conversation to Notes")
                    .accessibilityLabel(savedConfirmation ? "Saved to Notes" : "Save conversation to Notes")
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain).accessibilityLabel("Close voice mode")
                }

                Spacer()

                orb
                Text(phaseLabel).font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(DS.Motion.smooth, value: session.phase)

                Text(session.liveCaption.isEmpty ? " " : session.liveCaption)
                    .font(.system(size: 18)).foregroundStyle(.white)
                    .multilineTextAlignment(.center).lineLimit(3)
                    .frame(maxWidth: 420, minHeight: 54)
                    .animation(DS.Motion.smooth, value: session.liveCaption.isEmpty)

                Spacer()

                scrollback
                controls
            }
            .padding(DS.Space.xl)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .frame(width: 520, height: 640)
        .onAppear { session.start(); withAnimation(DS.Motion.smooth) { appeared = true } }
        .onDisappear { session.stop() }
        .accessibilityLabel("Hands-free voice mode, \(phaseLabel)")
    }

    private var orb: some View {
        ZStack {
            Circle().fill(phaseColor.opacity(0.18)).frame(width: 170, height: 170).blur(radius: 20)

            // Inner orb — PhaseAnimator pulses at phase-aware speed:
            // listening is snappier (0.70s), speaking is more measured (1.10s).
            PhaseAnimator([false, true]) { pulsing in
                Circle()
                    .fill(phaseColor.opacity(0.28))
                    .frame(width: 124, height: 124)
                    .scaleEffect(animate ? (pulsing ? 1.10 : 1.0) : 1.0)
            } animation: { pulsing in
                guard animate else { return .smooth }
                let dur: Double = session.phase == .listening ? 0.70 : 1.10
                return .timingCurve(0.45, 0.0, 0.55, 1.0, duration: pulsing ? dur : dur * 1.15)
            }

            Image(systemName: session.phase == .speaking ? "speaker.wave.2.fill" : "mic.fill")
                .font(.system(size: 42, weight: .bold)).foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .dsShadow(DS.Elevation.accentGlow(0.4))
        .animation(DS.Motion.smooth, value: session.phase)
    }

    private var scrollback: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(session.turns.suffix(3)) { turn in
                HStack(alignment: .top, spacing: 8) {
                    // Icon well — matches the app-wide pattern.
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill((turn.role == .salehman ? DS.Palette.accent : Color.white).opacity(0.12))
                            .frame(width: 20, height: 20)
                        Image(systemName: turn.role == .salehman ? "sparkles" : "person.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(turn.role == .salehman ? DS.Palette.accent : .secondary)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
                    Text(turn.text)
                        .font(.caption)
                        .foregroundStyle(turn.role == .salehman ? .white.opacity(0.9) : .secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .animation(DS.Motion.smooth, value: session.turns.count)
        .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        .opacity(session.turns.isEmpty ? 0 : 1)
        .animation(DS.Motion.smooth, value: session.turns.isEmpty)
    }

    private var controls: some View {
        HStack(spacing: DS.Space.xl) {
            CircleIconButton(systemName: session.phase == .speaking ? "stop.fill" : "mic.fill",
                             size: 58, iconSize: 22, filled: true,
                             help: session.phase == .speaking ? "Stop speaking and listen" : "Listen now") {
                session.interrupt()
            }
            CircleIconButton(systemName: "xmark", size: 44, iconSize: 17,
                             help: "Close voice mode") {
                onClose()
            }
        }
    }
}
