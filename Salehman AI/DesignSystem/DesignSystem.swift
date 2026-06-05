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
    // Tiered radius scale (8 → 24) so nested surfaces read as concentric, milled
    // hardware rather than arbitrary roundness. Slightly tightened from the old
    // values (bubble 18→16, field 22→20) for a crisper, more modern silhouette.
    enum Radius {
        static let small:  CGFloat = 8
        static let chip:   CGFloat = 12
        static let card:   CGFloat = 14
        static let bubble: CGFloat = 16
        static let field:  CGFloat = 20
        static let modal:  CGFloat = 24
        static let icon:   CGFloat = 10   // the 34pt header logo tile
    }

    // MARK: Semantic colors (dark-tuned)
    enum Palette {
        // Apple-Music-style brand identity (2026-06-05). Recoloring these four
        // tokens cascades automatically: `Gradient.brand` is a computed
        // `LinearGradient([accent, accent2])`, so tab-bar selection, send button,
        // logo tile, brand glow, focus ring, ConfirmationChip, etc. all re-skin
        // with zero view edits. Warm near-black canvas + red→pink accent reads
        // "Apple Music" instead of the cool indigo/Copilot blue we had.
        static let accent        = Color(red: 0.98, green: 0.18, blue: 0.29)   // #FA2D4A — Apple Music red
        static let accent2       = Color(red: 1.00, green: 0.33, blue: 0.55)   // #FF548C — pink/magenta
        static let bgTop         = Color(red: 0.09, green: 0.05, blue: 0.07)   // warm dark charcoal
        static let bgBottom      = Color(red: 0.03, green: 0.02, blue: 0.03)   // near-black (slight warmth)
        static let surface       = Color.white.opacity(0.07)   // bubble / card fill
        /// A subtly *lifted* surface used for sub-cards that sit on top of an
        /// already-`surface` parent (e.g. the AgentRunView nested card inside a
        /// bubble). Slightly stronger than `surface` so the nesting is legible.
        static let surfaceAlt    = Color.white.opacity(0.06)
        /// Solid-warm-dark background used for the approval modal & similar
        /// fully-opaque overlays. Was inlined as `Color(red:0.13,green:0.09,blue:0.11)`
        /// in ContentView — promoted so a future palette swap re-skins it.
        static let modalBG       = Color(red: 0.13, green: 0.09, blue: 0.11)
        // Strokes ↑ from 0.06/0.08 → more visible separators. NOTE (measured):
        // even at 0.12 these are ~1.37:1 vs the canvas — they do NOT meet WCAG
        // 1.4.11's 3:1, and a stroke that did would read boxy on dark. So they're
        // decorative: component boundaries/state are carried by fill + the
        // labeled status indicators (successSoft/warningSoft measure ~9.8:1).
        static let surfaceStroke = Color.white.opacity(0.12)
        static let hairline      = Color.white.opacity(0.12)
        static let textPrimary   = Color.white                 // measured 19:1 on canvas
        static let textSecondary = Color.white.opacity(0.66)   // measured 8.5:1 (was already 7.2:1 at 0.60 — this is polish, not a fix)
        static let success       = Color.green
        static let warning       = Color.orange
        static let danger        = Color.red
        // Softer, desaturated status tints for small inline indicators (e.g.
        // the ConfirmationChip dot) where full-saturation green/orange reads
        // as alarming. These are the exact values that were previously
        // inlined in ContentView — promoted to tokens so the next status dot
        // doesn't reinvent them.
        static let successSoft   = Color(red: 0.45, green: 0.85, blue: 0.55)
        static let warningSoft   = Color(red: 1.0,  green: 0.72, blue: 0.35)
    }

    // MARK: Typography (reuse the .rounded weights used throughout)
    enum Typography {
        // Apple-Music "Listen Now" treatment: a properly hefty hero title used on
        // the tab landing pages (AgentsView "Agents", MarketsView "Saudi Markets").
        // Bumping the TOKEN cascades automatically — no per-view rewrite needed.
        static let titleL       = Font.system(size: 28, weight: .bold,     design: .rounded)
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
        // `stagger` for per-item entrance offsets in a list; `entrance` for a
        // single element settling in with perceived mass.
        static let stagger   = Animation.timingCurve(0.34, 0.0, 0.66, 1.0, duration: 0.32)
        static let entrance  = Animation.timingCurve(0.22, 0.61, 0.36, 1.0, duration: 0.55)
    }

    // MARK: Elevation
    // A 3-step shadow scale + an accent glow, so depth is consistent instead of
    // ad-hoc `.shadow(...)` everywhere. Apply via the `.dsShadow(_:)` helper
    // below, e.g. `.dsShadow(DS.Elevation.shadow2)` or `.dsShadow(DS.Elevation.accentGlow())`.
    enum Elevation {
        static let shadow1 = (color: Color.black.opacity(0.18), radius: CGFloat(4),  y: CGFloat(2))
        static let shadow2 = (color: Color.black.opacity(0.32), radius: CGFloat(8),  y: CGFloat(4))
        static let shadow3 = (color: Color.black.opacity(0.40), radius: CGFloat(16), y: CGFloat(6))
        static func accentGlow(_ intensity: Double = 0.24) -> (color: Color, radius: CGFloat, y: CGFloat) {
            (Palette.accent.opacity(intensity), 12, 4)
        }
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
        // User-message bubble — hand-tuned red→pink that's slightly hotter than
        // `brand` so user messages "lead" visually (they're the active thing in
        // the conversation). Tracks the Apple-Music identity even though it
        // isn't a literal `[accent, accent2]` reuse.
        static let userBubble = LinearGradient(
            colors: [Color(red: 0.98, green: 0.22, blue: 0.35),
                     Color(red: 1.00, green: 0.40, blue: 0.60)],
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
    var accessibilityLabel: String = ""   // VoiceOver name; falls back to `help`
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
                // Disabled: desaturate the glyph (don't keep brand-white/tint at
                // half opacity — that still reads "active, just dim").
                .foregroundStyle(disabled ? AnyShapeStyle(Color.secondary.opacity(0.7))
                                          : (filled ? AnyShapeStyle(.white) : AnyShapeStyle(tint)))
                .frame(width: size, height: size)
                // Disabled: drop the brand gradient fill so a disabled Send button
                // doesn't glow red as if it were ready.
                .background((filled && !disabled) ? AnyShapeStyle(DS.Gradient.brand) : AnyShapeStyle(.ultraThinMaterial),
                            in: Circle())
                .overlay(Circle().stroke(ringColor, lineWidth: 1))
                .shadow(color: (filled && !disabled) ? DS.Palette.accent.opacity(0.5) : .clear, radius: 8, y: 3)
                .scaleEffect(hovering && !disabled ? 1.06 : 1.0)
                .opacity(disabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        // macOS `.help()` is only a tooltip — it does NOT set the VoiceOver name.
        // Every icon-only caller was unlabeled; derive the label from `help`.
        .accessibilityLabel(accessibilityLabel.isEmpty ? help : accessibilityLabel)
        .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
        .animation(DS.Motion.fade, value: filled)
        .animation(DS.Motion.fade, value: disabled)
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

// MARK: - Elevation helper
// Apply a `DS.Elevation` token in one call: `.dsShadow(DS.Elevation.shadow2)`
// or `.dsShadow(DS.Elevation.accentGlow())`. Keeps depth consistent app-wide.
extension View {
    func dsShadow(_ e: (color: Color, radius: CGFloat, y: CGFloat)) -> some View {
        shadow(color: e.color, radius: e.radius, y: e.y)
    }
}
