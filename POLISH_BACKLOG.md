# Polish backlog — curated for owner review
**Author:** Claude Chat C · **2026-06-11 (evening)** · while owner away (4h autonomous polish).

## 🔴 HIGH — privacy copy is now INACCURATE (the app went cloud-first)
**Found ~19:50 (Chat C guardian cycle).** `AppSettings.swift:45` now states the app *"itself is cloud-first;
this is its offline fallback model"* — the DEFAULT routes to cloud brains. But user-facing surfaces still
imply local/private-by-default:
- **🔴 `TodayView` greeting subtitle: *"everything here stays on this Mac."*** — **unconditionally FALSE by
  default** (data leaves the Mac unless the user turns on Offline/Private Mode). A false privacy claim on the
  HOME SCREEN of a privacy-marketed app — the exact class of "UI that lies" the dev log shows you repeatedly
  fixing. Today is Chat C's lane; **one-line fix ready on your word.**
- **🟠 `AboutView` capability #1 (lines 20–22):** title *"Private, on-device"* but body *"Runs cloud-first…"*
  — title contradicts its own body.
- **🟠 `OnboardingView` page 2 (lines 22–24):** title *"Private by design"* + *"runs cloud-first…"* body.
  (About + Onboarding both add "Turn on Offline Mode to keep everything on this Mac," so they're *defensible*
  if the titles are reworded; Today's blanket claim is not.)
**Why I did NOT just rewrite it:** privacy positioning is your most owner-defining call and you're mid-pivot
to cloud-first ("God Mode"). A coherent re-voice across all three (+ any other "on-device"/"stays on this Mac"
strings) is a product decision, not a polish edit — and changing one in isolation would fragment the message.
**Recommended minimal fix (say the word, I'll do a coherent pass in my lane):** make Today accurate, e.g.
*"cloud-first, fully private in Offline Mode,"* and align the About/Onboarding titles with their own bodies.

This is the **owner-decision** list: higher-impact / aesthetic refinements I deliberately did **not** apply
unilaterally, because the owner is actively iterating the app's visual language (Code-tab "Claude-minimal"
restyle in flight) and these would impose a direction. Each item is concrete (file:line), reversible, and
low-risk — just not mine to decide solo. The safe, unambiguous fixes are already done (see "Shipped" below).

Lane note: Chat C's claimed lane is the 7 secondary view surfaces only. Items touching `DesignSystem/*`,
`ContentView`, `SettingsView`, `Markets*`, `Agents`, `Code*` are flagged for the owning session.

> **✅ 2026-06-11 — owner said "yes": ALL 4 owner-decision items below were APPLIED** (commits `fcda86b`,
> `485cd8a`; build + AITests green, today within QA budget). Eyebrow on Today + Shortcuts (NOT Knowledge's
> inline answer labels — pill too heavy mid-content); Notes Organize/Summarize → on-device; `DS.Typography.titleXL`
> + `DS.Gradient.bgVertical` added append-only. The numbered items below are kept as the record + rationale.
> **Easy reverts if you disagree:** #1 = swap `Eyebrow(text:)` back to the tracked `Text`; #4 (behavior) =
> one line `generateOnDevice` → `generate` in `ScratchpadView.runAI`. The low-priority hygiene list is still open.

---

## ✅ Shipped (pass #1, commit `1bcd7ae` — build + AITests green, QA 14/14)
- KnowledgeView ask-field: added the `surfaceStroke` hairline the other 3 fields already had (consistency).
- KnowledgeView header subtitle `.lineLimit(1)` (narrow-width truncation guard).
- TodayView StatTile title `.lineLimit(1)`; icon-chip `cornerRadius:10` → `DS.Radius.icon` (neutral).
- ScratchpadView add-field: matching `surfaceStroke` hairline.
- MemoryView "Forget everything" `.red` → `DS.Palette.danger` (semantic token, ==.red).

---

## 🎨 Owner-decision: design-system adoption (consistent, but visible)
These align the views with components/tokens that ALREADY EXIST in `DesignSystem.swift` but aren't used.
Each is a real visual change, so they want a yes/no.

1. **Adopt the `Eyebrow` component for section labels.** `DesignSystem.swift:236` defines `Eyebrow`
   (uppercased, tracking 2, accent capsule pill) — and **no view uses it**. Every section label hand-rolls
   `Font.system(size:10/11,semibold)+.tracking(...)`:
   - TodayView:62 ("QUICK ACTIONS" / "AT A GLANCE"), KnowledgeView:107/310/324 ("SOURCES" / "ON-DEVICE
     SUMMARY" / "ANSWER"), ShortcutsView:50 (group titles).
   - **Decision:** adopt `Eyebrow(...)` everywhere (pill treatment, more branded) OR keep plain tracked
     labels (lighter, current). If you want the pill, I'll convert all of them in one pass.

2. **Tokenize one-off title sizes.** Headers use scattered magic sizes — `30` (TodayView:50, greeting),
   `22` (MemoryView:82), `20` (AboutView:64), `18` (ShortcutsView:40), `17` (Knowledge:65, Scratchpad:44),
   `26` (TodayView StatTile value). `DS.Typography` only has `titleL`(28) / `titleM`(17), both **rounded**.
   The `size:17` headers are NOT rounded, so swapping to `titleM` would make them rounded (visible).
   - **Decision:** either (a) add a `titleXL`(30) + `titleS`(20)/`numeric`(26) and route everything through
     tokens, or (b) leave bespoke. Recommend (a) for a single source of truth.

3. **De-dupe the background gradient.** OnboardingView:37 and AboutView:46 each inline
   `LinearGradient([bgTop,bgBottom], .top→.bottom)`. `DS.Gradient.bg` exists but is **diagonal**
   (`.topLeading→.bottomTrailing`). So it's NOT a drop-in — adopting changes vertical→diagonal.
   - **Decision:** add a vertical `DS.Gradient.bgVertical`, or accept the diagonal, or leave inline.

## 🔎 Owner-decision: behavior / privacy
4. **ScratchpadView "Organize/Summarize" uses `LocalLLM.generate`** (ScratchpadView:175) → routes to a
   **paid cloud brain** when one is pinned. Knowledge & StockSage were deliberately moved to
   `generateOnDevice` in an earlier privacy pass (notes can contain private content). Notes makes no explicit
   "on-device" promise, so this is a judgment call. **Decision:** switch to `generateOnDevice` (private, may
   return nil with no local model) or leave (uses whatever brain is pinned). One-line change in my lane on
   your say-so.

## 🧹 Low-priority hygiene (neutral, I can batch anytime you want)
- ShortcutsView keycap `cornerRadius:5` (ShortcutsView:60) — off the DS radius scale (`small`=8). Cosmetic.
- Off-grid paddings: MemoryView row `.vertical, 11` (MemoryView:156) vs `DS.Space.sm`(10); Onboarding
  pill paddings `26/11`. Sub-pixel; pure grid-alignment.
- Onboarding/About brand-tile size mismatch (Onboarding 88×88 @ r22 vs About 52×52 @ `DS.Radius.icon`).

---

## ✅ Verified already-clean (don't re-investigate)
- **Accessibility:** every icon-only button across the 7 surfaces has `.accessibilityLabel`/`Hint`; the
  ScratchpadView `Picker` is correctly labelled + `.labelsHidden()`. No gaps found.
- **Empty states:** Knowledge, Notes (tasks+notes), Memory all have designed empty states.
- **ShortcutsView accuracy:** ⌘1–7 (Today/Chat/Code/Agents/Markets/Notes/Knowledge) + Conversation/General
  groups exactly match `AppTab` order and the real `Salehman_AIApp` `keyboardShortcut` bindings. No drift.
- **No dead code / TODOs** in any of the 7 files.

## 🚩 Cross-lane (Chat B) — see COORDINATION.md
QA audit at commit `910a5d61` fails 2 surfaces, both Chat B's: `chat_narrow` (column 560pt vs ≈524 expected
— real geo issue in `ContentView` narrow layout) and `settings` (0.34% baselineDiff — likely needs
`qa.sh --adopt`). Not Chat C's lane; flagged for re-verify.
