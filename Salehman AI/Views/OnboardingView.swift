import SwiftUI

/// First-run welcome. Self-contained and shown once (gated by an `@AppStorage`
/// flag at the app root). Introduces Salehman's identity, its privacy stance, the
/// multi-brain picker + rotation, and what it can actually *do* — the app's core
/// vision — using only `DS.*` tokens so it re-skins with the design system.
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0
    @State private var ctaHover = false
    // Entrance choreography. Starts settled under `--qa` so offscreen snapshots
    // capture the final frame, not a mid-animation pose.
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let eyebrow: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        .init(icon: "sparkles", eyebrow: "WELCOME",
              title: "Meet Salehman",
              body: "Your personal AI — sharp, fast, and entirely yours. Let's get you set up in a few seconds."),
        .init(icon: "lock.shield.fill", eyebrow: "PRIVACY",
              title: "Private by design",
              body: "Salehman runs entirely on this Mac — your own `salehman` model via Ollama. Nothing leaves your device."),
        .init(icon: "brain.head.profile", eyebrow: "YOUR MODEL",
              title: "Your model, your identity",
              body: "Powered by your own fine-tuned `salehman` model. When your RunPod pod is up, pin vLLM in Settings to route there instead."),
        .init(icon: "wrench.and.screwdriver.fill", eyebrow: "CAPABILITIES",
              title: "It can actually do things",
              body: "With your approval, Salehman runs terminal commands, searches the web, transcribes audio, and works as a team of agents on bigger tasks."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            DS.Gradient.bgVertical
                .ignoresSafeArea()

            // Ambient brand glow — soft, blurred depth behind the hero tile so the
            // flat canvas reads as lit, not painted. Two orbs = layered atmosphere.
            Circle()
                .fill(DS.Palette.accent.opacity(0.18))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(y: -130)
                .allowsHitTesting(false)
            Circle()
                .fill(DS.Palette.accent.opacity(0.07))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 150, y: 180)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Brand tile + the current page's glyph (animates on change).
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(DS.Gradient.brand)
                        .frame(width: 88, height: 88)
                        .dsShadow(DS.Elevation.accentGlow(0.5))
                        // Top-lit edge highlight → the tile gains dimension instead
                        // of reading as a flat swatch.
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.04)],
                                                       startPoint: .top, endPoint: .bottom),
                                        lineWidth: 1)
                        )
                    Image(systemName: pages[page].icon)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                        .id("icon\(page)")
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                .padding(.bottom, 26)

                // Eyebrow badge — DS component for cross-view consistency.
                Eyebrow(text: pages[page].eyebrow)
                    .padding(.bottom, 10)
                    .id("eyebrow\(page)")
                    .transition(.opacity)

                Text(pages[page].title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .id("title\(page)")
                    .transition(.opacity)

                Text(pages[page].body)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.76))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 400)
                    .padding(.top, 12)
                    .id("body\(page)")
                    .transition(.opacity)

                Spacer()

                // Progress dots (the active one stretches into a pill).
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? DS.Palette.accent : Color.white.opacity(0.22))
                            .frame(width: i == page ? 22 : 7, height: 7)
                    }
                }
                .padding(.bottom, 26)

                HStack {
                    Button("Back") { withAnimation(DS.Motion.smooth) { page -= 1 } }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .opacity(page > 0 ? 1 : 0)
                        .disabled(page == 0)

                    Spacer()

                    Button {
                        if isLast { onDone() }
                        else { withAnimation(DS.Motion.smooth) { page += 1 } }
                    } label: {
                        // Button-in-button: trailing chevron in its own circle.
                        HStack(spacing: 8) {
                            Text(isLast ? "Get Started" : "Next")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(ctaHover ? 0.20 : 0.12))
                                    .frame(width: 26, height: 26)
                                Image(systemName: isLast ? "checkmark" : "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: ctaHover && !isLast ? 1 : 0)
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 11)
                        .background(DS.Gradient.brand, in: Capsule())
                        .dsShadow(DS.Elevation.accentGlow(ctaHover ? 0.62 : 0.4))
                        .scaleEffect(ctaHover ? 1.035 : 1)
                        .brightness(ctaHover ? 0.06 : 0)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .onHover { hovering in withAnimation(DS.Motion.smooth) { ctaHover = hovering } }
                }

                Button("Skip") { onDone() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 14)
            }
            .padding(44)
            // Whole card drifts up + fades in on first frame.
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .frame(width: 540, height: 600)
        .onAppear { withAnimation(DS.Motion.smooth) { appeared = true } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to Salehman, step \(page + 1) of \(pages.count)")
    }
}
