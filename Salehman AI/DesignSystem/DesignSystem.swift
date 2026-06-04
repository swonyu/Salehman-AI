import SwiftUI

// MARK: - Design System
// A single source of truth for spacing, radius, color, type, motion and the
// reusable components that used to be copy-pasted inline across the UI. New
// code should reach for `DS.*` and the components below; the legacy `Theme`
// enum (in ContentView) now forwards here so existing call sites keep working.
enum DS {

    // MARK: Spacing (4-pt base scale)
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
        static let chip:   CGFloat = 14
        static let card:   CGFloat = 16
        static let bubble: CGFloat = 18
        static let field:  CGFloat = 22
        static let modal:  CGFloat = 22
        static let icon:   CGFloat = 10   // the 34pt header logo tile
    }

    // MARK: Semantic colors (dark-tuned)
    enum Palette {
        static let accent        = Color(red: 0.40, green: 0.55, blue: 1.0)
        static let accent2       = Color(red: 0.62, green: 0.40, blue: 1.0)
        static let bgTop         = Color(red: 0.05, green: 0.06, blue: 0.11)
        static let bgBottom      = Color(red: 0.02, green: 0.02, blue: 0.05)
        static let surface       = Color.white.opacity(0.07)   // bubble / card fill
        static let surfaceStroke = Color.white.opacity(0.08)
        static let hairline      = Color.white.opacity(0.06)
        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.60)
        static let success       = Color.green
        static let warning       = Color.orange
        static let danger        = Color.red
    }

    // MARK: Typography (reuse the .rounded weights used throughout)
    enum Typography {
        static let titleL       = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let titleM       = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body         = Font.system(size: 14)
        static let mono         = Font.system(size: 13, design: .monospaced)
        static let caption      = Font.caption
        static let sectionLabel = Font.system(size: 11, weight: .semibold)
    }

    // MARK: Motion
    // Custom cubic-bezier curves (no stock easeInOut / linear anywhere). The
    // `smooth` curve is Apple's "out-quint"-ish feel used in macOS sheet
    // dismissals; `cinematic` is heavier and used for entry animations so
    // elements have perceived mass.
    enum Motion {
        static let spring   = Animation.spring(response: 0.35, dampingFraction: 0.85)
        static let snappy   = Animation.spring(response: 0.28, dampingFraction: 0.80)
        static let press    = Animation.timingCurve(0.32, 0.72, 0.0, 1.0, duration: 0.18)
        static let fade     = Animation.timingCurve(0.32, 0.72, 0.0, 1.0, duration: 0.22)
        static let smooth   = Animation.timingCurve(0.32, 0.72, 0.0, 1.0, duration: 0.45)
        static let cinematic = Animation.timingCurve(0.22, 0.61, 0.36, 1.0, duration: 0.80)
        static let magnetic = Animation.interpolatingSpring(stiffness: 220, damping: 18)
    }

    // MARK: Nested-surface tokens (Double-Bezel architecture)
    // Wrap content in `Bezel` to get an outer "tray" hairline + inner "plate"
    // with its own inner highlight. The two layers of curvature read as
    // machined hardware, not a flat panel.
    enum Bezel {
        static let outerRadius:  CGFloat = 22
        static let innerRadius:  CGFloat = 17        // = outer - shellPadding
        static let shellPadding: CGFloat = 5
        static let shellFill        = Color.white.opacity(0.04)
        static let shellStroke      = Color.white.opacity(0.09)
        static let coreFill         = Color.white.opacity(0.06)
        static let coreInnerHighlight = LinearGradient(
            colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)],
            startPoint: .top, endPoint: .bottom)
    }

    // MARK: Gradients
    enum Gradient {
        static let brand = LinearGradient(colors: [Palette.accent, Palette.accent2],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
        static let userBubble = LinearGradient(
            colors: [Color(red: 0.30, green: 0.50, blue: 1.0),
                     Color(red: 0.45, green: 0.38, blue: 1.0)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        static let bg = LinearGradient(colors: [Palette.bgTop, Palette.bgBottom],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - CircleIconButton
// The frosted circular icon button used in the header and input bar (was
// copy-pasted ~6×). Adds hover scale + brighter ring, an optional brand-filled
// variant (the Send button), an optional colored ring (e.g. red while
// recording), and a disabled appearance.
struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 30
    var iconSize: CGFloat = 14
    var tint: Color = .secondary
    var ring: Color? = nil          // colored ring for an "active" state (e.g. red mic)
    var filled: Bool = false        // brand-gradient fill (Send)
    var disabled: Bool = false
    var help: String = ""
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
                .foregroundStyle(filled ? AnyShapeStyle(.white) : AnyShapeStyle(tint))
                .frame(width: size, height: size)
                .background(filled ? AnyShapeStyle(DS.Gradient.brand) : AnyShapeStyle(.ultraThinMaterial),
                            in: Circle())
                .overlay(Circle().stroke(ringColor, lineWidth: 1))
                .shadow(color: filled ? DS.Palette.accent.opacity(0.5) : .clear, radius: 8, y: 3)
                .scaleEffect(hovering && !disabled ? 1.06 : 1.0)
                .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
        .animation(DS.Motion.fade, value: filled)
    }
}

// MARK: - Card
// The repeated "surface fill + hairline stroke + rounded" container.
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

// MARK: - Chip
// The tappable suggestion chips in the empty state.
struct Chip: View {
    let text: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Space.md).padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .stroke(Color.white.opacity(hovering ? 0.20 : 0.08), lineWidth: 1))
                .scaleEffect(hovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
    }
}

// MARK: - Button styles (dedupe the Approval card buttons)
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

// MARK: - Bezel (Double-Bezel container)
// Outer "tray" + inner "plate" with concentric radii and an inner highlight.
// Use this for premium surfaces that should read as machined hardware rather
// than a flat translucent panel.
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

// MARK: - Eyebrow (uppercase microtag above a heading)
// Used for spatial rhythm — gives a heading "section identity" without an
// actual heading-rank competing with the main title.
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
            .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 0.5))
    }
}

// MARK: - SuggestionCard
// Rich-media replacement for `Chip` in the empty state. Icon tile + title +
// one-line subtitle, with a button-in-button trailing arrow that translates
// diagonally on hover (magnetic kinetic tension).
struct SuggestionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                // Icon "plate" — small bezel of its own for hierarchical depth.
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

                // Button-in-button trailing arrow.
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
