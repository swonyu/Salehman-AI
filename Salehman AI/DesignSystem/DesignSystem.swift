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

    // MARK: Motion (shared so the whole app animates coherently)
    enum Motion {
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
        static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.80)
        static let press  = Animation.easeOut(duration: 0.12)
        static let fade   = Animation.easeOut(duration: 0.20)
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
