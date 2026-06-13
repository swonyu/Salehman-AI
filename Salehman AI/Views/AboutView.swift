import SwiftUI

/// "About Salehman AI" — identity, capabilities, and the privacy stance. A small
/// self-contained sheet over the root window, reachable from the ⌘K command
/// palette. Reads the version straight from `Info.plist` so the display stays
/// honest after every Xcode version bump (no source change needed).
struct AboutView: View {
    let onClose: () -> Void
    // Entrance choreography — settled under `--qa` so offscreen snapshots capture
    // the final frame, not a mid-animation pose.
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")
    @State private var hoveredCap: UUID?

    /// Major capability rows. Edit when a new feature surfaces — this is the
    /// "what can it do" answer shown to the user.
    private struct Capability: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let capabilities: [Capability] = {
        var caps: [Capability] = [
            .init(icon: "lock.shield.fill",
                  title: "Fully private, on this Mac",
                  body: "Runs entirely on-device — your Ollama `salehman` model, with MLX as an upgrade path. Nothing leaves your Mac."),
            .init(icon: "brain.head.profile",
                  title: "Your model, your identity",
                  body: "Powered by your own fine-tuned `salehman` model via Ollama. When your RunPod pod is up, pin the vLLM brain in Settings to route there instead."),
            .init(icon: "wrench.and.screwdriver.fill",
                  title: "Real tools, with approval",
                  body: "Runs terminal commands, searches the web, and transcribes audio — only after you approve each one in the safety card."),
            .init(icon: "chart.line.uptrend.xyaxis",
                  title: "Markets watcher",
                  body: "Rule-based momentum signals, a heatmap, a portfolio with live P&L, and Mac notifications for strong moves."),
            .init(icon: "command",
                  title: "⌘K everywhere",
                  body: "Press ⌘K to do anything; ⌘/ to see every shortcut. New surfaces don't get hidden behind menus."),
        ]
        if AppTab.hidden.contains(.markets) { caps.removeAll { $0.icon == "chart.line.uptrend.xyaxis" } }
        return caps
    }()

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "Version \(short)" : "Version \(short) (\(build))"
    }

    var body: some View {
        ZStack {
            DS.Gradient.bgVertical
                .ignoresSafeArea()

            // Ambient brand glow behind the header — soft depth on the flat canvas.
            Circle()
                .fill(DS.Palette.accent.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -120, y: -210)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: DS.Space.lg) {
                // Header — brand tile + identity + close.
                HStack(alignment: .center, spacing: DS.Space.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                            .fill(DS.Gradient.brand)
                            .frame(width: 52, height: 52)
                            .dsShadow(DS.Elevation.accentGlow(0.45))
                            // Top-lit edge highlight → the tile reads dimensional.
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                                    .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.04)],
                                                           startPoint: .top, endPoint: .bottom),
                                            lineWidth: 1)
                            )
                        // KeyframeAnimator: compress → overshoot → settle on
                        // first appear. Hardware-accurate bounce physics.
                        KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                            Image(systemName: "sparkles")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .scaleEffect(scale)
                        } keyframes: { _ in
                            KeyframeTrack {
                                LinearKeyframe(0.60, duration: 0.07)
                                SpringKeyframe(1.20, duration: 0.30, spring: .snappy)
                                SpringKeyframe(1.0, duration: 0.24, spring: .bouncy)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Salehman AI")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(appVersion)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                Text("Your AI — on-device, private, built by Saleh. Your own model, real tools, nothing leaves this Mac.")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Section eyebrow — uses the DS component for consistency.
                Eyebrow(text: "What it does").padding(.top, 2)

                // Capability list (scrolls if cramped on smaller windows).
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(capabilities.enumerated()), id: \.element.id) { idx, cap in
                            capabilityRow(cap)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 8)
                                .animation(DS.Motion.lux.delay(Double(idx) * 0.06), value: appeared)
                        }
                    }
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
                .frame(maxHeight: 300)

                // Footer — small attribution + the one keyboard hint.
                HStack {
                    Text("Press ⌘K for anything · ⌘/ for shortcuts").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Made on a Mac").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(DS.Space.xl)
            // Card drifts up + fades in on first frame.
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .frame(width: 460, height: 560)
        .onAppear { withAnimation(DS.Motion.smooth) { appeared = true } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About Salehman AI")
    }

    private func capabilityRow(_ cap: Capability) -> some View {
        let isHovered = hoveredCap == cap.id
        return HStack(alignment: .top, spacing: DS.Space.md) {
            // Icon well — 28×28, accent-tinted, brightens on hover.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.well, style: .continuous)
                    .fill(DS.Palette.accent.opacity(isHovered ? 0.20 : 0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: cap.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.well, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
            .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(cap.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text(cap.body).font(.caption).foregroundStyle(.white.opacity(0.7))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 11)
        .background(isHovered ? DS.Palette.accent.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DS.Motion.magnetic) {
                if hovering { hoveredCap = cap.id }
                else if hoveredCap == cap.id { hoveredCap = nil }
            }
        }
    }
}
