import SwiftUI

// MARK: - Design System
enum DS {

    // MARK: Spacing
    enum Space {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 10
        static let md:  CGFloat = 14
        static let lg:  CGFloat = 18
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Corner radii
    enum Radius {
        static let small:  CGFloat = 8
        static let chip:   CGFloat = 12
        static let card:   CGFloat = 14
        static let bubble: CGFloat = 16
        static let field:  CGFloat = 20
        static let modal:  CGFloat = 24
        static let icon:   CGFloat = 10
    }

    // MARK: Semantic colors
    enum Palette {
        static let accent        = Color(red: 0.98, green: 0.18, blue: 0.29)
        static let accent2       = Color(red: 1.00, green: 0.33, blue: 0.55)
        static let bgTop         = Color(red: 0.11, green: 0.11, blue: 0.12)
        static let bgBottom      = Color(red: 0.04, green: 0.04, blue: 0.045)
        static let surface       = Color.white.opacity(0.07)
        // Code-tab editor surfaces — NEUTRAL grey (no red cast): the chat canvas
        // is lighter, the sidebar/inspector a step darker for depth, like an editor.
        static let codeSurface     = Color(white: 0.125)
        static let codeSurfaceSide = Color(white: 0.095)
        static let surfaceAlt    = Color.white.opacity(0.06)
        static let modalBG       = Color(red: 0.13, green: 0.13, blue: 0.14)
        static let surfaceStroke = Color.white.opacity(0.12)
        static let hairline      = Color.white.opacity(0.12)
        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.66)
        static let success       = Color.green
        static let warning       = Color.orange
        static let danger        = Color.red
        static let successSoft   = Color(red: 0.45, green: 0.85, blue: 0.55)
        static let warningSoft   = Color(red: 1.0,  green: 0.72, blue: 0.35)

        // SuperGrok (xAI) – elevated "Super" brain visual identity
        static let superGrok     = Color(red: 0.55, green: 0.45, blue: 0.95)
        static let superGrokSoft = Color(red: 0.55, green: 0.45, blue: 0.95).opacity(0.15)
    }

    // MARK: Typography
    enum Typography {
        static let titleL       = Font.system(size: 28, weight: .bold,     design: .rounded)
        static let titleXL      = Font.system(size: 30, weight: .bold,     design: .rounded)
        static let titleM       = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body         = Font.system(size: 14)
        static let mono         = Font.system(size: 13, design: .monospaced)
        static let caption      = Font.caption
        static let sectionLabel = Font.system(size: 11, weight: .semibold)

        // SuperGrok label style
        static let superLabel = Font.system(size: 11, weight: .semibold, design: .rounded)
    }

    // MARK: Motion
    enum Motion {
        static let spring   = Animation.spring(response: 0.35, dampingFraction: 0.85)
        static let snappy   = Animation.spring(response: 0.28, dampingFraction: 0.80)
        static let press    = Animation.timingCurve(0.32, 0.72, 0.0, 1.0, duration: 0.18)
        static let fade     = Animation.timingCurve(0.32, 0.72, 0.0, 1.0, duration: 0.22)
        static let smooth   = Animation.timingCurve(0.32, 0.72, 0.0, 1.0, duration: 0.45)
        static let cinematic = Animation.timingCurve(0.22, 0.61, 0.36, 1.0, duration: 0.80)
        static let magnetic = Animation.interpolatingSpring(stiffness: 220, damping: 18)
        static let stagger   = Animation.timingCurve(0.34, 0.0, 0.66, 1.0, duration: 0.32)
        static let entrance  = Animation.timingCurve(0.22, 0.61, 0.36, 1.0, duration: 0.55)
        /// The Code tab's signature curve (matches its local `lux`), promoted
        /// to a shared token so the chat composer/welcome animate identically.
        static let lux       = Animation.timingCurve(0.32, 0.72, 0.0, 1.0, duration: 0.40)
    }

    // MARK: Elevation
    enum Elevation {
        static let shadow1 = (color: Color.black.opacity(0.18), radius: CGFloat(4),  y: CGFloat(2))
        static let shadow2 = (color: Color.black.opacity(0.32), radius: CGFloat(8),  y: CGFloat(4))
        static let shadow3 = (color: Color.black.opacity(0.40), radius: CGFloat(16), y: CGFloat(6))
        static func accentGlow(_ intensity: Double = 0.24) -> (color: Color, radius: CGFloat, y: CGFloat) {
            (Palette.accent.opacity(intensity), 12, 4)
        }
    }

    // MARK: Bezel
    enum Bezel {
        static let outerRadius:  CGFloat = 22
        static let innerRadius:  CGFloat = 17
        static let shellPadding: CGFloat = 5
        static let shellFill        = Color.white.opacity(0.04)
        static let shellStroke      = Color.white.opacity(0.09)
        static let coreFill         = Color.white.opacity(0.06)
        static let coreInnerHighlight = LinearGradient(
            colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)],
            startPoint: .top, endPoint: .bottom)
        /// Subtle fill for machined card containers — the background layer under
        /// the coreInnerHighlight stroke. Matches all per-view inline cards.
        static let cardFill             = Color.white.opacity(0.035)
    }

    // MARK: Gradients
    enum Gradient {
        static let brand = LinearGradient(colors: [Palette.accent, Palette.accent2],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
        static let userBubble = LinearGradient(
            colors: [Color(red: 0.98, green: 0.22, blue: 0.35),
                     Color(red: 1.00, green: 0.40, blue: 0.60)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        static let bg = LinearGradient(colors: [Palette.bgTop, Palette.bgBottom],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
        // Vertical variant for full-screen sheets (Onboarding/About) — straight
        // top→bottom wash rather than the diagonal app background.
        static let bgVertical = LinearGradient(colors: [Palette.bgTop, Palette.bgBottom],
                                               startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Components (CircleIconButton, Card, etc.)
// MARK: - CircleIconButton
struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 30
    var iconSize: CGFloat = 14
    var tint: Color = .secondary
    var ring: Color? = nil
    var filled: Bool = false
    var disabled: Bool = false
    var help: String = ""
    var accessibilityLabel: String = ""
    let action: () -> Void

    @State private var hovering = false

    private var ringColor: Color {
        if let ring { return ring.opacity(0.6) }
        return Color.white.opacity(hovering && !disabled ? 0.22 : 0.12)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(disabled ? AnyShapeStyle(Color.secondary.opacity(0.7))
                                          : (filled ? AnyShapeStyle(.white) : AnyShapeStyle(tint)))
                .frame(width: size, height: size)
                .background((filled && !disabled) ? AnyShapeStyle(DS.Gradient.brand) : AnyShapeStyle(.ultraThinMaterial),
                            in: Circle())
                .overlay(Circle().stroke(ringColor, lineWidth: 1))
                .shadow(color: (filled && !disabled) ? DS.Palette.accent.opacity(0.5) : .clear, radius: 8, y: 3)
                .scaleEffect(hovering && !disabled ? 1.06 : 1.0)
                .opacity(disabled ? 0.55 : 1)
                .contentTransition(.symbolEffect(.replace))
                .animation(DS.Motion.smooth, value: systemName)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        .accessibilityLabel(accessibilityLabel.isEmpty ? help : accessibilityLabel)
        .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
        .animation(DS.Motion.fade, value: filled)
        .animation(DS.Motion.fade, value: disabled)
    }
}

// MARK: - Card
struct Card<Content: View>: View {
    var padding: CGFloat = DS.Space.md
    var radius: CGFloat = DS.Radius.card
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }
}

// MARK: - Button styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label
            .font(.callout.weight(.bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(DS.Gradient.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(c.isPressed ? 0.85 : 1)
            .scaleEffect(c.isPressed ? 0.98 : 1)
            .animation(DS.Motion.press, value: c.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label
            .font(.callout.weight(.semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(Color.white.opacity(c.isPressed ? 0.14 : 0.08),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(c.isPressed ? 0.98 : 1)
            .animation(DS.Motion.press, value: c.isPressed)
    }
}

/// Bare press physics for controls that carry their OWN chrome (capsule pills,
/// chips, icon buttons): 0.97 settle while pressed, press-curve release — the
/// `.plain` style with a body. No fill/font opinions, so existing chrome is
/// untouched. APPEND-ONLY addition (Chat B, 2026-06-12).
struct PressableStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label
            .scaleEffect(c.isPressed ? 0.97 : 1)
            .animation(DS.Motion.press, value: c.isPressed)
    }
}

// MARK: - Bezel
struct Bezel<Content: View>: View {
    var outerRadius: CGFloat = DS.Bezel.outerRadius
    var shellPadding: CGFloat = DS.Bezel.shellPadding
    var corePadding: CGFloat = DS.Space.lg
    @ViewBuilder let content: () -> Content

    private var innerRadius: CGFloat { max(0, outerRadius - shellPadding) }

    var body: some View {
        content()
            .padding(corePadding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .fill(DS.Bezel.coreFill)
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                }
            )
            .padding(shellPadding)
            .background(
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .fill(DS.Bezel.shellFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .stroke(DS.Bezel.shellStroke, lineWidth: 1)
            )
    }
}

// MARK: - Eyebrow
struct Eyebrow: View {
    let text: String
    var color: Color = DS.Palette.accent

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(2)
            .foregroundStyle(color.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(
                LinearGradient(colors: [color.opacity(0.40), color.opacity(0.08)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 0.5))
    }
}

// MARK: - SuggestionCard
struct SuggestionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DS.Gradient.brand.opacity(0.22))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)

                ZStack {
                    Circle().fill(Color.white.opacity(hovering ? 0.16 : 0.08))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: 24, height: 24)
                .scaleEffect(hovering ? 1.08 : 1.0)
                .offset(x: hovering ? 2 : 0, y: hovering ? -1 : 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(hovering ? 0.07 : 0.04))
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(hovering ? 0.18 : 0.08), lineWidth: 1)
            )
            .scaleEffect(hovering ? 1.015 : 1.0)
            .shadow(color: DS.Palette.accent.opacity(hovering ? 0.18 : 0.0), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.Motion.magnetic) { hovering = h } }
    }
}

// MARK: - Elevation helper
extension View {
    func dsShadow(_ e: (color: Color, radius: CGFloat, y: CGFloat)) -> some View {
        shadow(color: e.color, radius: e.radius, y: e.y)
    }
}

// MARK: - SuperGrok (added for Upgrade to SuperGrok + Anthropic migration)
struct SuperGrokBadge: View {
    var text: String = "SUPER GROK"
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(text)
                    .font(DS.Typography.superLabel)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(DS.Palette.superGrok)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(DS.Palette.superGrokSoft, in: Capsule())
            .overlay(Capsule().stroke(DS.Palette.superGrok.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cloud-key hint banner
/// Amber notice shown when the selected brain needs a cloud key but none is set,
/// so the slow local fallback (or dead-end) is never silent. Shared by the Chat
/// and Code tabs; each passes its own "open Settings" + dismiss actions.
/// `LocalLLM.lacksCloudKey` decides when to show it; `noCloudKeyHint` is the copy.
struct CloudKeyHintBanner: View {
    let onAddKey: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 12, weight: .bold))
            Text(LocalLLM.noCloudKeyHint)
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Add key", action: onAddKey)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(DS.Palette.warningSoft)
                .font(.caption)
                .accessibilityLabel("Add a cloud key in Settings")
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss cloud key notice")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(DS.Palette.warningSoft.opacity(0.12))
        .foregroundStyle(DS.Palette.warningSoft)
    }
}

