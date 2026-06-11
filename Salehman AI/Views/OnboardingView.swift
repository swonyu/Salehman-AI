import SwiftUI

/// First-run welcome. Self-contained and shown once (gated by an `@AppStorage`
/// flag at the app root). Introduces Salehman's identity, its privacy stance, the
/// multi-brain picker + rotation, and what it can actually *do* — the app's core
/// vision — using only `DS.*` tokens so it re-skins with the design system.
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        .init(icon: "sparkles",
              title: "Meet Salehman",
              body: "Your personal AI — sharp, fast, and entirely yours. Let's get you set up in a few seconds."),
        .init(icon: "lock.shield.fill",
              title: "Private by design",
              body: "Salehman runs cloud-first on free big models, with a local fallback. Turn on Offline Mode to keep everything on this Mac."),
        .init(icon: "brain.head.profile",
              title: "Choose your brain — or many",
              body: "Pin one model, or check several and Salehman rotates through them, one per message. Free local brains, your own custom model, or the cloud — your call."),
        .init(icon: "wrench.and.screwdriver.fill",
              title: "It can actually do things",
              body: "With your approval, Salehman runs terminal commands, searches the web, transcribes audio, and works as a team of agents on bigger tasks."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            DS.Gradient.bgVertical
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Brand tile + the current page's glyph (animates on change).
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(DS.Gradient.brand)
                        .frame(width: 88, height: 88)
                        .dsShadow(DS.Elevation.accentGlow(0.5))
                    Image(systemName: pages[page].icon)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                        .id("icon\(page)")
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                .padding(.bottom, 30)

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
                        Text(isLast ? "Get Started" : "Next")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 26).padding(.vertical, 11)
                            .background(DS.Gradient.brand, in: Capsule())
                            .dsShadow(DS.Elevation.accentGlow(0.4))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }

                Button("Skip") { onDone() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 14)
            }
            .padding(44)
        }
        .frame(width: 540, height: 600)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to Salehman, step \(page + 1) of \(pages.count)")
    }
}
