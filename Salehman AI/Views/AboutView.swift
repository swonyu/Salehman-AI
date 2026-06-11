import SwiftUI

/// "About Salehman AI" — identity, capabilities, and the privacy stance. A small
/// self-contained sheet over the root window, reachable from the ⌘K command
/// palette. Reads the version straight from `Info.plist` so the display stays
/// honest after every Xcode version bump (no source change needed).
struct AboutView: View {
    let onClose: () -> Void

    /// Major capability rows. Edit when a new feature surfaces — this is the
    /// "what can it do" answer shown to the user.
    private struct Capability: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let capabilities: [Capability] = [
        .init(icon: "lock.shield.fill",
              title: "Private, on-device",
              body: "Runs cloud-first on free big models (DeepSeek V4 + frontier tiers) with a local MLX/Ollama fallback. Turn on Offline Mode to keep everything on this Mac."),
        .init(icon: "brain.head.profile",
              title: "Many brains, one Salehman",
              body: "MLX, Ollama, DeepSeek, and many free cloud brains. Check several to rotate through them — one per message."),
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

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "Version \(short)" : "Version \(short) (\(build))"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [DS.Palette.bgTop, DS.Palette.bgBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: DS.Space.lg) {
                // Header — brand tile + identity + close.
                HStack(alignment: .center, spacing: DS.Space.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                            .fill(DS.Gradient.brand)
                            .frame(width: 52, height: 52)
                            .dsShadow(DS.Elevation.accentGlow(0.45))
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
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

                Text("Your private, on-device AI — built by Saleh. Many brains, real tools, your own model.")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Capability list (scrolls if cramped on smaller windows).
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(capabilities) { cap in capabilityRow(cap) }
                    }
                    .background(DS.Palette.codeSurfaceSide,
                                in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                }
                .frame(maxHeight: 320)

                // Footer — small attribution + the one keyboard hint.
                HStack {
                    Text("Press ⌘K for anything · ⌘/ for shortcuts").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Made on a Mac").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(DS.Space.xl)
        }
        .frame(width: 460, height: 560)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About Salehman AI")
    }

    private func capabilityRow(_ cap: Capability) -> some View {
        HStack(alignment: .top, spacing: DS.Space.md) {
            Image(systemName: cap.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.Palette.accent)
                .frame(width: 22, height: 22)
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
    }
}
