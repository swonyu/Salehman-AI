# Design Research — Swift 6 UI + macOS 27 "Golden Gate" (2026-06-14)

Research for the high-end visual-design polish loop. Done **solo via WebSearch/WebFetch** (the
multi-agent `deep-research` Workflow is forbidden by the owner's standing directive). Sources at
the bottom. **Bottom line up front:** this app's branded crimson flat-dark language is a *valid,
principle-aligned* choice — adopt macOS-27 refinements that strengthen it (concentric radii,
hierarchy, dynamic controls); do **not** wholesale-convert to system Liquid Glass (that would erase
the brand and reverse the owner's deliberate flat-opaque decision).

## 1. macOS 27 "Golden Gate" — what changed vs macOS 26 "Tahoe"
macOS 27 (WWDC, June 2026) *refines* the Liquid Glass language introduced in 26, responding to
readability/transparency pushback:
- **System opacity slider** — users set glass intensity "ultra clear → fully tinted." Readability
  becomes a user-controlled, system-level concern; apps using system materials inherit it.
- **Consistent + tighter window corner radius** — auto-applied across ALL apps (incl. third-party),
  no developer work.
- **Edge-to-edge sidebars**; colored sidebar icons shown only for the active app.
- **Uniform frosted top toolbar** — better button legibility + separation from content below.
- **App icons** gain layered glass refraction (sharper, more defined).
- **Most refinements auto-apply** to apps already on the system Liquid Glass framework.

## 2. Liquid Glass SwiftUI APIs (available macOS 26+)
- `.glassEffect(_:in:)` — variant `.regular`; shape `.capsule` / `.rect(cornerRadius:)` / `.circle`;
  `.tint(Color)`; `.interactive()` for pointer response.
- `GlassEffectContainer(spacing:)` — wrap multiple glass views (shared sampling region → perf +
  morphing/merging when elements are near).
- `@Namespace` + `glassEffectID(_:in:)` + `withAnimation` — morph transitions between glass shapes.
- `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`.
- **Rules:** apply `.glassEffect()` AFTER other appearance modifiers · **never stack glass on glass**
  (muddy/unreadable — glass can't sample glass) · don't hardcode colors (use semantic colors).

## 3. Principles — Hierarchy / Harmony / Consistency
- **Hierarchy:** content-forward; prioritize the important; adaptive, not fixed chrome.
- **Harmony:** glass *enhances*, never obscures content; refined shapes + materials.
- **Consistency:** predictable patterns + fluid adaptation; **concentric corner radii**; whitespace
  that *guides attention* (functional, not padding).
- **Native vs dated:** system semantic colors > arbitrary dark palettes · dynamic content-aware
  components > fixed tab/segmented bars · glass for *functional layering*, **custom fills for
  *semantic meaning (brand / status)*.**

## 4. What this means for Salehman AI — deliberate divergence, selective alignment
The app is a **branded** surface: crimson "Salehman" identity, custom flat-opaque dark DS
(`DS.Bezel` nested fills, `DS.Radius`, forced `.preferredColorScheme(.dark)`), and the owner
*explicitly removed* the last `.ultraThinMaterial` bar (flat-opaque was a decision, not an
oversight). Per the principles themselves, **custom fills are correct for brand identity**, so:

**ADOPT (strengthens the existing language; macOS-27-aligned):**
- ✅ **Concentric corner-radius precision** — 27 makes radii consistent + tighter system-wide. Audit
  `DS.Bezel` so inner = outer − shellPadding exactly, and check the `DS.Radius` scale still reads
  crisp beside 27's tighter window radii. (Highest-value, on-brand, low-risk.)
- ✅ **Hierarchy + functional whitespace** — already strong in the polished views; preserve.
- ✅ **Dynamic over static** — already done (animated `DSSegmentPicker` sliding pill, magnetic hover,
  content-aware empty states). Audit for any remaining `.pickerStyle(.segmented)` / static chrome.
- ✅ **Reduce-Motion** — pass complete (EOBO); Liquid Glass motion respects the setting too.

**DO NOT ADOPT (would break the brand / reverse decisions):**
- ❌ System `.glassEffect()` on the main canvases/cards — the flat crimson-on-black identity *is* the
  product; translucency was deliberately removed.
- ❌ Replacing custom button styles (`PrimaryButtonStyle`/`LuxPressStyle`) with `.buttonStyle(.glass)`.
- ❌ Swapping the crimson accent for the system semantic accent — it's the product identity.

**OPTIONAL (owner's call):**
- 🤔 One genuinely-floating, transient overlay (the ⌘K command palette, tooltips) *could* use system
  glass as a tasteful system-native touchpoint **without** touching the branded canvases — only if the
  owner wants a Liquid-Glass accent. Flagged, not assumed.

## 5. Polish-phase plan (guided by the above)
1. Audit + tighten `DS.Bezel`/`DS.Radius` concentric precision (slice 1).
2. App-wide sweep for static/dated controls (`.pickerStyle(.segmented)`, naked stock controls) →
   convert to the app's dynamic equivalents.
3. Continue per-surface gap-finding consistency on any not-yet-covered views (TodayView,
   ShortcutsView, CopilotSignInView deeper; Chat/Code deeper) — same discipline, no churn.

## Sources
- [Apple announces macOS 27 'Golden Gate' at WWDC 2026 (ANI News)](https://www.aninews.in/news/tech/mobile/apple-announces-macos-27-golden-gate-at-wwdc-2026-with-liquid-glass-design-changes-and-more20260609002106/)
- [5 biggest Liquid Glass changes in iOS 27 and macOS 27 (Cult of Mac)](https://www.cultofmac.com/news/liquid-glass-changes-ios-27-macos-27)
- [macOS 27 Refines Liquid Glass After Early Pushback (AppleMagazine)](https://applemagazine.com/macos-27-liquid-glass/amp/)
- [Liquid Glass: Hierarchy, Harmony, Consistency (Create with Swift)](https://www.createwithswift.com/liquid-glass-redefining-design-through-hierarchy-harmony-and-consistency/)
- [SwiftUI Implementing Liquid Glass Design (Xcode 27 system prompts, artemnovichkov)](https://github.com/artemnovichkov/xcode-27-system-prompts/blob/main/AdditionalDocumentation/SwiftUI-Implementing-Liquid-Glass-Design.md)
- [Meet Liquid Glass — WWDC25 session 219 (Apple)](https://developer.apple.com/videos/play/wwdc2025/219/)
- [Build a SwiftUI app with the new design — WWDC25 session 323 (Apple)](https://developer.apple.com/videos/play/wwdc2025/323/)
- [SwiftUI for Mac 2025 (TrozWare)](https://troz.net/post/2025/swiftui-mac-2025/)
