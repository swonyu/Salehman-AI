# PROPOSAL — UX wave follow-ups (deferred list, docs-only) — 2026-07-03

**Author:** Opus 4.8 lane, task O9 (issued by Fable 5). **Status:** proposal, NO code. Fable converts to a
house plan **after the UX wave (`ideas-card/ux-wave-2`) merges** (post owner visual-QA).
**Origin:** the three deferred items from the shipped/held UX work — two AA-contrast sites the wave did not
cover (review-fleet catches) and one DRY duplication the wave recolored but left duplicated.

**Dependency:** `DS.Palette.dangerSoft` (the WCAG-AA soft red) is defined on the **held** `ideas-card/ux-wave-2`
branch, not on `main` (`git show ideas-card/ux-wave-2:"Salehman AI/DesignSystem/DesignSystem.swift"` →
`static let dangerSoft = Color(red: 1.0, green: 0.50, blue: 0.50)`). All three items are therefore
**post-UX-merge** work (they consume `dangerSoft`). On `main` today, `DS.Palette.danger = Color.red`
(`DesignSystem.swift:48`).

## Contrast method (re-derived, not asserted)
WCAG 2.1 ratio `= (L_light + 0.05) / (L_dark + 0.05)`, relative luminance
`L = 0.2126·R' + 0.7152·G' + 0.0722·B'` with `c' = c/12.92 (c≤0.04045)` else `((c+0.055)/1.055)^2.4`.
Background = the dark card surface `DS.Palette.bgTop = (0.11, 0.11, 0.12)` → **L_bg = 0.0118**.
- `danger = Color.red` (modelled pure sRGB red `(1,0,0)`, which reproduces the review-fleet's measured value):
  L = 0.2126 → ratio **4.25:1** ≈ the flagged ~4.3:1. **Below the 4.5:1 AA floor** for text < 18pt (or < 14pt bold).
- `dangerSoft = (1.0, 0.50, 0.50)`: L = 0.3811 → ratio **6.98:1** — clears AA (4.5) and AAA (7.0).

The AA gap is real and the fix is decisive (dangerSoft is ~1.65× the contrast). The conclusion is robust to the
exact card background: `dangerSoft` is much lighter, so its luminance dominates against any dark surface.
*(Caveat: `Color.red` may render as the slightly-desaturated system red; the review fleet's pixel measurement
(~4.3:1) is the authoritative anchor and the pure-red model reproduces it.)*

---

## Item 1 — Journal / edge danger-red small text → `dangerSoft`  (AA fix)
- **Sites (grep-verified, `Views/MarketsView.swift`):**
  - `:1697` — `.foregroundStyle(yr.realizedDollars >= 0 ? DS.Palette.successSoft : DS.Palette.danger)` (journal year-row realized-dollars, negative branch).
  - `:1543` — `ideaMetric("Avg loss", …, color: DS.Palette.danger)` (backtest-edge avg-loss metric — same danger-on-small-text class).
- **Issue:** small (`ideaMetric`/stat-size) text in `DS.Palette.danger` ⇒ **4.25:1**, below the 4.5:1 AA floor.
- **Fix (no code):** swap `DS.Palette.danger → DS.Palette.dangerSoft` at these small-text sites → **6.98:1**.
  A pure color-token swap; no layout, no logic. (Leave any ≥18pt/bold danger uses alone — they already clear AA
  at 3:1/large-text rules; this is only for the small-text sites.)
- **Risk:** LOW (single-token substitution, no geometry).

## Item 2 — `bestOpportunityCard` earnings-imminent note → `dangerSoft`  (AA fix, high-visibility)
- **Site (`Views/MarketsView.swift:3412-3419`, inside `bestOpportunityCard`):**
  `Text(ep.note).font(.caption2).foregroundStyle(ep.severity == .imminent ? DS.Palette.danger : DS.Palette.warningSoft)` (`:3416-3417`), with the matching `calendar.badge.exclamationmark` icon at `:3414-3415`.
- **Issue:** `.caption2` (~11pt) earnings-risk text in `DS.Palette.danger` on the `.imminent` branch ⇒ **4.25:1**,
  sub-AA — and this is the **flagship "best opportunity" card**, the most-seen surface, showing a **risk warning**
  (earnings can gap through a protective stop). An unreadable warning is the worst place for a contrast miss.
- **Fix (no code):** swap the Text's `.imminent → DS.Palette.danger` to `→ DS.Palette.dangerSoft` (6.98:1). The
  icon (`:3415`) may swap too for visual consistency (icons are held only to 3:1, so it already passes, but
  matching the text reads cleaner). No layout change.
- **Risk:** LOW (color-token swap).

## Item 3 — DRY-extract the duplicated earnings-warning HStack in `ideaDetailSheet`  (maintainability)
- **Sites (byte-identical, both in `ideaDetailSheet` `Views/MarketsView.swift:4461`):**
  - `:4538-4546` — buy-family branch (`if a.action == .buy || .strongBuy`), earnings warning above the gate.
  - `:4919-4927` — sell/reduce fallback (`if a.action != .buy && != .strongBuy`).
  - Both are the **identical** block (verified char-for-char):
    ```
    if let ep = store.earnings[idea.symbol.uppercased()], ep.isWarning {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "calendar.badge.exclamationmark").font(.system(size: mvFont11))
                .foregroundStyle(ep.severity == .imminent ? DS.Palette.danger : DS.Palette.warningSoft)
            Text(ep.note).font(.caption2).accessibilityLabel("Earnings risk — see detail sheet")
                .foregroundStyle(ep.severity == .imminent ? DS.Palette.danger : DS.Palette.warningSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    ```
  (The UX wave recolors both to `dangerSoft` per Amendment A-3 per the handoff — so extract the **post-merge**,
  `dangerSoft` version. The `bestOpportunityCard` HStack at `:3413` is NOT part of this pair — it carries
  `.accessibilityHidden(true)` and omits the `accessibilityLabel`, so it is deliberately different; leave it.)
- **Issue:** a byte-identical duplication is drift-prone — a future edit to one branch (color, copy, a11y label,
  spacing) silently diverges the two paths (the class of bug behind `incident-ledger` IL-16/IL-22 — the sizer
  buried in one branch of a two-branch sheet).
- **Fix (no code, extraction shape):** extract into a single
  `@ViewBuilder private func earningsWarningRow(_ idea: StockSageIdea) -> some View` that returns the
  `if let ep …ep.isWarning { HStack { … } }` block verbatim; both call sites become
  `earningsWarningRow(idea)` **inside their existing `a.action` gates** (the buy-vs-sell/reduce gating stays at
  the call sites — only the inner identical view moves). **Why it cannot change rendering:** the helper returns
  the exact same SwiftUI subtree from the same inputs (`store.earnings`, `idea.symbol`, `ep`), and the enclosing
  `if a.action …` branches are untouched, so the view hierarchy is identical at both sites — a pure de-duplication.
- **Risk:** LOW-MEDIUM. It is a refactor, not a swap, so it must be verified byte-identical (a11y label, `mvFont11`,
  `spacing: 6`, `.fixedSize`) and QA'd on BOTH a buy idea and a sell/reduce idea (the two branches) per `visual-qa`
  — the both-sheets check that IL-22 spawned.

---

## Ranking (value ÷ risk)
1. **Item 2 (bestOpportunityCard note)** — highest value: the most-visible surface, a *risk warning*, sub-AA;
   LOW risk (token swap). Do first.
2. **Item 1 (journal/edge small text)** — clear AA fix on real stats; LOW risk (token swap). Do with Item 2 —
   together they are "the remaining `danger → dangerSoft` small-text swaps," one tiny diff.
3. **Item 3 (DRY extraction)** — maintainability, not a user-visible fix; LOW-MEDIUM risk (refactor discipline +
   both-branch QA). Do after, as its own change so the a11y swaps aren't entangled with a refactor.

## Notes
- **NO code written.** All three consume `dangerSoft`, which lands with the UX wave — so this is strictly
  post-UX-merge follow-up work, matching Fable's sequencing.
- Every site is grep-cited to a current `file:line`; the contrast numbers are re-derived above (WCAG 2.1),
  anchored to the review-fleet's pixel measurement.
- Out of the Opus lane to implement (UI code is not an Opus-solo edit per `opus-operating`); this hands Fable a
  ready-to-plan follow-up.

---

## Appendix — complete danger-text site inventory (grouped by surface)

Fable's post-code-review note: the fix round's residual grep found ~36 small danger-TEXT sites beyond the
wave's claimed surfaces. Below is the **grep-verified** inventory (I re-grepped the current tree —
`grep -nE 'foregroundStyle\([^)]*DS.Palette.danger' "Salehman AI/Views/MarketsView.swift"` returns **36
foreground-danger sites**, cross-checked against the review JSON's line refs). **Shared contrast class for
every row:** `DS.Palette.danger = Color.red` small text ⇒ **≈4.25:1** on the dark card bg (sub the 4.5:1 AA
floor for text < 18pt / < 14pt-bold) → **`dangerSoft` ≈6.98:1** (AA/AAA). All fonts below are < 18pt, so all
fall in the sub-AA class. A handful of companion **icons** share the `danger` token (e.g. `:3415`, `:4540`,
`:4944` `calendar`/warning glyphs) — icons are held only to 3:1, so they already pass and are *not* counted as
text sites (they may swap for visual consistency). Many sites are `up ? successSoft : danger` P&L conditionals
— the fix applies to the **danger (loss) branch only**, preserving the red-for-loss semantic while fixing AA.

### A. Out-of-scope surfaces (~27) — Markets tab, NOT the ideas card
| Surface | Sites (`MarketsView.swift` unless noted) | Renders | Size |
|---|---|---|---|
| **A1 Trade-journal totals** | `:1682`, `:1697`, `:1716`, `:1734`, `:2028`, `:2033` | monthly/yearly/side/sector `totalR` + realized-$ + trade-row side/P&L (loss → red) | caption / mvFont-small |
| **A2 Portfolio risk analytics** | `:4946` (pc.note), `:4974` (impact.note), `:4986` (sectorImpact.note); `MarketsRiskAllocationSection.swift:223`, `:259`, `:419` (cluster.note) | position-concentration / market-impact / sector warnings + risk-delta + cluster note | caption2 (~11pt) / small |
| **A3 Watchlist / signals P&L** | `:974`, `:1074`, `:1260`, `:2572`, `:3090` | quote %-change (down → red), signal delta, bearish label | caption / small |
| **A4 Alerts panel** | `:3330` (alert.kind), `:1792` (act.kind == .stopHit) | triggered-alert label / stop-hit action | caption2 |

### B. Ideas-surface stragglers (~9) — the wave's own surface, missed
| Straggler | Sites (`MarketsView.swift`) | Renders | Size |
|---|---|---|---|
| **B1 ep.note earnings** | `:3416` (bestOpp = Item 2), `:4542` + `:4923` (sheet dup = Item 3) | earnings-imminent warning text | caption2 |
| **B2 gap-risk warning** | `:4313` (`"⚠︎ " + gap.verdict`) | "can gap through your stop" verdict | mvFont9 |
| **B3 leverage verdict** | `:4294` (`"⚠︎ " + lev.verdict`) | "can lose more than account" | mvFont9 |
| **B4 strategy-backtest Worst/Pooled DD** | `:4190` (`"worst −%…"`) | worst/pooled drawdown figure | mvFont9 semibold |
| **B5 OOS-decay red-flag note** | `:4155` (`d.isRedFlag`) | walk-forward decay red flag | caption2 |
| **B6 momentum 'cold' label** | `~:3194` / `:3875` / `:3897` (`mqLabel == "cold"`) | momentum-quality "cold" chip | small chip |
| **B7 ladder / gate stop chips** | `:4352` (gate `.blocked`), `:4364` (check `.fail`), `:5465` (pinned stop text) | trade-gate blocked/fail + pinned CTA stop | mvFont9 / mvFont13 |
| **B8 cluster-correlation note** | `:1444` (cluster.note) | "correlated with a holding" note | caption2 |
| **B9 today-actions card** | `MarketsTodayActionsCard.swift:115` | today-action danger label | font8 semibold |

**How to use this:** the follow-up wave should (a) do B1–B9 **with** the ideas card (they are on-surface and the
wave already claims that surface), and (b) treat A1–A4 as a **separate broader-AA sweep decision** — the same
`danger → dangerSoft` swap fixes them and preserves red-for-loss, but they are out of the ideas-card scope, so
whether to include them is an owner/Fable scoping call. **Verification:** every row above is a current
`file:line`; re-grep before editing (IL-20 — the tree is the territory). The per-site fix is identical (swap the
`danger` branch to `dangerSoft`); no layout change on any of them.
