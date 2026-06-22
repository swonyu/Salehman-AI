# Visual-design polish backlog (visual-design-audit wxpxw4t5l, 2026-06-22)

7 agents → 17 pixel-safe ranked items.

### ⬜ #1 — Elevate all four card panel titles to DS.Typography.titleM
**File:** Salehman AI/Views/MarketsView.swift
**Change:** Panel titles are all size-14 semibold today (verified: line 679 "Risk-parity weights", line 780 "Allocation", line 874 "Correlation heatmap", plus "Trade journal"). Swap each .font(.system(size: 14, weight: .semibold)) to .font(DS.Typography.titleM) (17pt semibold, rounded). Pixel-safe: text-only, no layout/frame change; creates one strong primary anchor per premium card. Highest visual impact, zero functional risk.

### ⬜ #2 — Switch Browse modal background to DS.Palette.modalBG
**File:** Salehman AI/Views/BrowseMarketsView.swift
**Change:** Line 100: .background(DS.Palette.surface) is the inline-component token (white 0.07). For a sheet, use .background(DS.Palette.modalBG) (the opaque Color 0.13/0.13/0.14 reserved for modals). Restores the dark-mode elevation hierarchy where modals sit deeper than the main tab surface. One-token swap, pixel-safe.

### ⬜ #3 — Tokenize Browse row hover background (surfaceAlt + DS.Radius.small)
**File:** Salehman AI/Views/BrowseMarketsView.swift
**Change:** Line 124: .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6)) hardcodes both opacity and radius. Replace with DS.Palette.surfaceAlt (white 0.06) and DS.Radius.small (8pt). Aligns row depth + corner radius with the rest of the app's small components. Pixel-safe (small radius/opacity bump, no reflow).

### ⬜ #4 — Premium gradient divider in RuneScape fastest-flips strip
**File:** Salehman AI/Views/RuneScapeMarketView.swift
**Change:** Line 235: Divider().overlay(DS.Palette.surfaceStroke) reads as a hard full-bleed line. Replace the overlay with Rectangle().fill(LinearGradient(colors: [DS.Palette.surfaceStroke.opacity(0), DS.Palette.surfaceStroke, DS.Palette.surfaceStroke.opacity(0)], startPoint: .leading, endPoint: .trailing)) so it fades at both edges. High visual polish, no geometry change (divider keeps its 1pt height).

### ⬜ #5 — Upgrade fastest-flips strip stroke to a warningSoft bezel gradient
**File:** Salehman AI/Views/RuneScapeMarketView.swift
**Change:** Line 266: .stroke(DS.Palette.warningSoft.opacity(0.25), lineWidth: 1) is a flat single-color border that drowns into codeSurface. Replace with .stroke(LinearGradient(colors: [DS.Palette.warningSoft.opacity(0.48), DS.Palette.warningSoft.opacity(0.10)], startPoint: .top, endPoint: .bottom), lineWidth: 1) to match the regimeCard/liveBanner bezel language. Pixel-safe (same lineWidth/shape).

### ⬜ #6 — Standardize row hover opacity to a single token across all interactive rows
**File:** Salehman AI/Views/MarketsView.swift
**Change:** Hover backgrounds drift between 0.06 and 0.07 (MarketsView signalAlertRow/positionRow at DS.Palette.accent.opacity(0.07); RuneScape listingRow line 325 uses accent.opacity(0.06)). Pick one value — accent.opacity(0.06) — and apply to every hoverable row in both MarketsView and RuneScapeMarketView line 325 for a cohesive feel. Pixel-safe (0.01 opacity normalization, no layout change).

### ⬜ #7 — Promote RuneScape sub-strip title to bolder white type
**File:** Salehman AI/Views/RuneScapeMarketView.swift
**Change:** Line 212: "Fastest flips — gp/hour" is size 11 bold. Bump to size 13 bold (keep .foregroundStyle(.white)) so the premium flips card reads as a header above the commodity rows below it. Text-only, no frame change; pixel-safe.

### ⬜ #8 — Align RuneScape status-banner stroke stops with MarketsView liveBanner
**File:** Salehman AI/Views/RuneScapeMarketView.swift
**Change:** Line 150: banner stroke gradient uses tint.opacity(0.48) → 0.10. MarketsView liveBanner uses 0.45 → 0.10. Change 0.48 to 0.45 so both tabs share one banner-bezel opacity. Trivial, pixel-safe token alignment.

### ⬜ #9 — Use DS.Space.sm for fastest-flips strip vertical spacing
**File:** Salehman AI/Views/RuneScapeMarketView.swift
**Change:** Line 209: VStack(alignment: .leading, spacing: 6) is a magic number. Change to spacing: DS.Space.sm (10pt) to match ideasHeader/section grouping rhythm. Minor vertical-rhythm shift inside one card, no clipping risk; pixel-safe.

### ⬜ #10 — Tokenize Browse + RuneScape search-field backgrounds to surfaceAlt family
**File:** Salehman AI/Views/BrowseMarketsView.swift
**Change:** BrowseMarketsView line 69 uses Color.white.opacity(0.08); RuneScape searchField line 170 uses 0.08 idle / 0.11 focus. Standardize the idle state to DS.Palette.surfaceAlt (0.06)-ish and keep 0.11 on focus so all search wells share one token family. Pixel-safe opacity normalization.

### ⬜ #11 — Add a strokeBorder to the RuneScape P2P member capsule
**File:** Salehman AI/Views/RuneScapeMarketView.swift
**Change:** Line 291: the P2P badge has .background(DS.Palette.warningSoft, in: Capsule()) with no bezel highlight. Add .overlay(Capsule().stroke(DS.Palette.warningSoft.opacity(0.5), lineWidth: 0.5)) to match the glass-finish capsule pattern used elsewhere. Pixel-safe (0.5pt inset stroke).

### ⬜ #12 — Give Browse modal more breathing room (DS.Space.lg padding)
**File:** Salehman AI/Views/BrowseMarketsView.swift
**Change:** Line 98: .padding(DS.Space.md) on the 420×520 sheet is tight. Bump the outer padding to DS.Space.lg (18) while keeping the VStack(spacing: DS.Space.sm) inter-section gaps. Frame minWidth/minHeight already accommodate it; pixel-safe.

### ⬜ #13 — Bump Browse title to titleM and subtitle to readable body
**File:** Salehman AI/Views/BrowseMarketsView.swift
**Change:** Line 51: "Browse markets" is size 16 bold — change to DS.Typography.titleM (17pt semibold rounded) to match the MarketsView card headers. Line 52: subtitle is .caption2; bump to .font(.system(size: 12)) for modal-context legibility. Text-only, pixel-safe.

### ⬜ #14 — Lighten sub-section group subtitles for white-on-dark contrast
**File:** Salehman AI/Views/MarketsView.swift
**Change:** Group subtitles ("By month", "By sector", "By side", "Currency exposure", "R-multiple distribution") are size-10 semibold .secondary. Bump to size 11 semibold and .foregroundStyle(.white) so they sit clearly below the new titleM card headers without competing. Text-only; pixel-safe.

### ⬜ #15 — Tint ProgressView spinners with the brand accent
**File:** Salehman AI/Views/MarketsView.swift
**Change:** Bare ProgressView() instances (e.g. alerts/regime loading) use the default macOS tint. Add .tint(DS.Palette.accent) so loading spinners match brand. Note: the risk-parity spinner at line 687 already uses .tint(.white) on a brand-gradient button — leave that one; only tint the spinners sitting on the dark surface. Pixel-safe.

### ⬜ #16 — Tokenize idea-detail-sheet divider radius to DS.Radius.small
**File:** Salehman AI/Views/MarketsView.swift
**Change:** The idea detail sheet footer uses a hardcoded RoundedRectangle(cornerRadius: 8, style: .continuous) that is numerically identical to DS.Radius.small. Replace the literal 8 with DS.Radius.small so future DS changes propagate. Zero visual change today; token-discipline only.

### ⬜ #17 — Promote priceColumn label color to DS.Palette.textSecondary
**File:** Salehman AI/Views/RuneScapeMarketView.swift
**Change:** Line 349: priceColumn label uses raw .secondary. MarketsView parityRow uses explicit DS.Palette.textSecondary (white 0.66). Swap to DS.Palette.textSecondary for token consistency across the two markets surfaces. Pixel-safe (near-identical rendered value, deliberate token).
