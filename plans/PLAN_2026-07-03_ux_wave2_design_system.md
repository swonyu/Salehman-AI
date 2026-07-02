# PLAN 2026-07-03 — UX wave 2: ideas-surface design system (type roles, spacing rhythm, one chip system, Markets a11y) + flagship sheet-navigation execution

> **Who this is for:** an implementation agent (Sonnet-5, effort max — assume strong but HASTY)
> executing under `.claude/skills/executing-plans`. Zero improvisation: every step carries the
> byte-exact OLD/NEW blocks, the verification command, and its expected output. **STOP on any
> mismatch between this plan and the tree; a step is DONE only when its verification command's
> actual OUTPUT is pasted and proves the behavior fired.** Reviewer/refactorer: Opus-4.8 xhigh.

## 0. Plan metadata + execution context

- **Plan:** `plans/PLAN_2026-07-03_ux_wave2_design_system.md`
- **Written against:** HEAD **`c807861`** (`git rev-parse --short HEAD`),
  `Salehman AI/Views/MarketsView.swift` at **5,476 lines**, tree clean. Every anchor below was
  grepped at this SHA on 2026-07-02/03. Line numbers are orientation only — **edits anchor on
  exact text**; anchor missing/non-unique → mismatch → STOP.
- **Execution contract:** `.claude/skills/executing-plans` + `gated-scope` + `spec-fidelity` +
  `testing-discipline` + `visual-qa`. Read them before Task A.
- **WORKTREE + BRANCH (owner durability directive):** the implementer works in a git worktree on
  its own branch and NEVER touches main; the orchestrator owns the merge pipeline. Setup:
  ```bash
  cd /Users/saleh/ai
  git worktree add ../ai-ux-wave2 -b ideas-card/ux-wave-2 c807861
  cd ../ai-ux-wave2
  ```
  Build/test in the worktree with an ISOLATED DerivedData and a worktree-local log
  (two xcodebuilds on one DerivedData corrupt each other — testing-discipline):
  ```bash
  xcodebuild … -derivedDataPath .dd … 2>&1 | tee .build.log | tail -25
  ```
- **WIP COMMIT AFTER EVERY COMPLETED TASK — hard rule (owner directive: never lose work to a
  session limit).** After each task's verify passes:
  `git add <files touched by that task, BY NAME> && git commit -m 'wip(ux-wave-2): <task id + one-line>'`.
  Never `git add -A`. No pushes.
- **Owner mandate (verbatim):** "10/10 UX", "utilize proper design systems, tokens, and
  typographic ratios for the surface", "Prioritize modern, perfect UX that is holistic and
  beautiful." Constraint from `DESIGN_RESEARCH_macOS27.md`: the crimson flat-dark language is a
  DELIBERATE divergence — selective alignment only; **no Liquid-Glass adoption, no
  `.glassEffect()`, no system-material swaps, no accent replacement.**

## 1. Goal (one sentence)

The ideas board + detail sheet get a documented, token-backed design system — type roles on a
ratio ramp, a 4/8pt spacing rhythm, ONE consistent chip language, WCAG-AA danger text, and
in-sheet prev/next candidate navigation — with every honesty string byte-identical.

## 2. Owner-gate check (consulted: AUDIT_2026-07-02_ideas_board.md §5, RANKING_BACKLOG.md, gated-scope)

| Gate | Touched? |
|---|---|
| RANKING #10 (`preferVelocity` default) | **No.** Nothing reorders, re-ranks, or changes a sort/rank default. Task A only READS `displayedIdeas` order. |
| F01/F02 (identity-calibration semantics) | **No.** `calibrationChip` gets a FONT-SIZE change only (9→10pt); its method-keyed wording, `chipTitle`/`chipHelp` sourcing, and every "assumed/fitted/measured" string are byte-identical. No engine/test change. |
| F08/F21 ("Conviction" vs "Signal strength") | **No.** ZERO copy changes anywhere in this wave. Type ROLE names are Swift identifiers (`fontSectionHeader`), never displayed text. The contested terms stay exactly where and as they are. |
| F10 (decimal-comma locale) | **No.** No money/percent input or parsing touched. |
| F03/F44 (weekly-rollup netting) | **No.** No headline number or its label touched. |
| Honesty floor | **No numeric change, no label change, no nil-guard removed.** Changes are: font sizes, insets, chip chrome, a softened-red SWATCH for small danger TEXT (severity semantics, icons, and wording unchanged), one a11y label that mirrors the visible string, and a stale-dim opacity raised to clear WCAG AA (the staleness signal is still carried by the dim + clock badge + VoiceOver label + .help). §7 proves string byte-identity. |

**Verdict: NOT GATED — proceed.** Re-scan at Done-means. A "pending confirmation" note is NOT
permission. **If any step appears to require picking a side of a parked decision — REFUSE that
step, report, continue with the rest.**

## 3. REJECTED from the proposed scope (with evidence — do NOT implement these)

1. **A11Y_BUGHUNT #3 & #5 (PSR color-only + VoiceOver)** — ALREADY FIXED at `c807861`:
   `MarketsView.swift:4086–4101` has the glyph (`checkmark.seal.fill`/`exclamationmark.triangle.fill`),
   the literal "— PASS"/"— BELOW BAR" verdict word, `.accessibilityLabel(… "passes"/"below" …)`,
   and `.accessibilityHint(StockSageDeflatedSharpe.caveat)`. Task G ticks them off in the doc.
2. **A11Y_BUGHUNT #7 (OOS-decay VoiceOver)** — ALREADY FIXED at `c807861`:
   `MarketsView.swift:4138–4143` carries a speech-safe `.accessibilityLabel` ("… kept N percent
   of the edge. In sample … to out of sample …"). Task G ticks it off.
3. **A11Y_BUGHUNT #4, #8, #9, #12, #13, #14, #15** — all in
   `Salehman AI/Views/RuneScapeMarketView.swift` (stale flip-margin chip, gp/hr opacity, Buy/Sell
   price columns, Best-ROI line, loss chip). NOT the Markets/ideas surface → out of this wave.
4. **A11Y_BUGHUNT #11 (per-trade P&L fixed 11pt)** — core defect ALREADY FIXED by the F48 sweep
   (`1d734b1`): `MarketsView.swift:2017` now uses `mvFont11` (@ScaledMetric). Task G ticks it off.
5. **UI_FORMAT_AUDIT #2 (rebalance mixed-currency sum)** — Markets-tab file but NOT a UX/design
   item: it changes computed money figures (FX-converts rebalance inputs, alters trade sizes and
   drift weights). Needs its own correctness wave with hand-derived FX fixtures. Bundling money-math
   into a visual wave violates wave-cycle scope discipline. REJECTED here; left open in the doc.
6. **UI_FORMAT_AUDIT #3 (humanDollars "$1000K")** — ALREADY FIXED at `c807861`:
   `StockSage/StockSageLiquidity.swift:76–83` promotes on the rounded magnitude (`m >= 999.5 → $B`,
   `k >= 999.5 → $M`). Task G marks the doc entry DONE with this evidence.
7. **UI_FORMAT_AUDIT #4 (RSFormat.gp band tops)** — `RuneScapeMarketView.swift`, not Markets → out.
8. **Wholesale call-site migration to the new type roles** — this wave defines the role layer and
   migrates the sites it already touches (headers, chips). A full sweep of ~200 font call sites is
   a follow-up wave; doing it here would make the diff unreviewable.
9. **Journal danger-red small text** (`%+.2fR` negatives at `mvFont11` in danger ≈ 4.3:1) — real
   but journal-section; this wave's dangerSoft sweep is scoped to the ideas card + sheet. Listed
   as a deferred finding in the dev-log entry (Task G), not silently dropped.

## 4. Exact file list

1. `Salehman AI/Views/MarketsView.swift` — edits (Tasks A, B, C, D, E).
2. `Salehman AITests/SheetCandidateNavigationTests.swift` — **NEW** (Task A / its Step 2; test
   target auto-joins, no pbxproj edit).
3. `Salehman AI/DesignSystem/DesignSystem.swift` — ONE append-only addition (`dangerSoft`, Task D).
   Shared file: append-only is the sanctioned pattern; check `COORDINATION.md` for a live claim
   before editing — if another session claims it, STOP and report.
4. `DEVELOPMENT_LOG.md` — two appended entries (Task A §9a; Task G).
5. `MARKETS_TAB_MAP.md` — Ideas entry extended (Task A §9b; Task G).
6. `A11Y_BUGHUNT.md` — status ticks with evidence (Task G).
7. `UI_FORMAT_AUDIT.md` — #3 marked DONE with evidence (Task G).
8. `SOURCE_BUNDLE.md` — regenerated by `bash tools/bundle_source.sh` only (never hand-edited, never Read).

**NO other file.** A step appearing to need any other file is a mismatch → STOP.

## 5. Pre-flight captures (run ALL in the worktree before editing; any deviation → STOP, report `plan says X / tree says Y`)

```bash
cd "$(git rev-parse --show-toplevel)"

# PF-1 — tree identity
git rev-parse --short HEAD
# EXPECTED: c807861   (worktree branched from it; anything else → STOP)
git status --short -- "Salehman AI/Views/MarketsView.swift" "Salehman AI/DesignSystem/DesignSystem.swift"
# EXPECTED: (empty)
wc -l "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 5476

# PF-2 — Task-A anchors (sheet-nav plan re-verification at c807861; see Task A Amendment A-0)
grep -n 'ideaDetailSheet' "Salehman AI/Views/MarketsView.swift"
# EXPECTED (verbatim):
# 226:        .sheet(item: $selectedIdea) { ideaDetailSheet($0) }
# 4435:    private func ideaDetailSheet(_ idea: StockSageIdea) -> some View {
# 4437:        // Hoist riskFlags for the chips row and CTA bar: shared in ideaDetailSheet only.
grep -n 'keyboardShortcut' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 4471:                    .keyboardShortcut(.cancelAction)
grep -n '\.task(id: idea.symbol)' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 5197:        .task(id: idea.symbol) {
grep -n 'private var displayedIdeas' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 2837:    private var displayedIdeas: [StockSageIdea] {
grep -c 'selectedIdea = ' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 10
grep -rn "SheetCandidateNavigation\|sheetNavControls\|stepSheet\|sheetTopAnchor" "Salehman AI" "Salehman AITests" --include="*.swift"
# EXPECTED: (no output — names unclaimed)
grep -n '// F24: merged with the former summaryStat helper' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 5214:    // F24: merged with the former summaryStat helper (uniform a11y is the audit's stated goal —

# PF-3 — wave-2 anchors: section headers, chips, tokens
grep -c 'size: mvFont12, weight: .semibold' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 10     (4 of these are the Why/Evidence/Exit plan/Context headers Task B retypes)
grep -c 'padding(.horizontal, 7).padding(.vertical, 3)' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 4      (the 4 card chips Task D re-chromes)
grep -rn "IdeaSpace\|IdeaChipChrome\|fontSectionHeader\|fontChipLabel\|dangerSoft" "Salehman AI" "Salehman AITests" --include="*.swift"
# EXPECTED: (no output — new names unclaimed)
grep -n 'opacity(boardIsStale' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 3197:        .opacity(boardIsStale ? 0.75 : 1.0)   // dim stale cards
grep -c 'minimumScaleFactor(0.7)' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 1      (one pre-existing exact-0.7 site; Task E2 adds 4 → post-wave count 5)
grep -c 'frame(width: 60' "Salehman AI/Views/MarketsView.swift"
# EXPECTED: 4      (3 value columns Task E2 unlocks + 1 label column that stays)

# PF-4 — honesty-string baseline (re-run VERBATIM at §7; every count must be unchanged)
for s in 'NOT a win probability' 'win% assumed' 'win% measured' 'EV (gross)' 'gross, before costs' 'not a forecast' 'Deploy plan is authoritative' 'Do NOT trade' 'costs > edge' 'Signal strength' 'Conviction'; do printf '%s = ' "$s"; grep -c "$s" "Salehman AI/Views/MarketsView.swift"; done
# EXPECTED (verbatim):
# NOT a win probability = 1
# win% assumed = 2
# win% measured = 1
# EV (gross) = 2
# gross, before costs = 2
# not a forecast = 6
# Deploy plan is authoritative = 2
# Do NOT trade = 1
# costs > edge = 1
# Signal strength = 4
# Conviction = 13

# PF-5 — full string-literal snapshot (the §7 byte-identity proof diffs against this)
grep -o '"[^"]*"' "Salehman AI/Views/MarketsView.swift" | sort | uniq -c > /tmp/uxw2_strings_before.txt
wc -l /tmp/uxw2_strings_before.txt
# EXPECTED: a line count (record it; the file is the artifact)

# PF-6 — docs anchors
grep -n '## Standing notes / known issues' DEVELOPMENT_LOG.md
# EXPECTED: 9122:## Standing notes / known issues
grep -c 'playbook labels fastest "net" and weekly "gross, before costs".' MARKETS_TAB_MAP.md
# EXPECTED: 1

# PF-7 — green baseline build (worktree-isolated)
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee .build.log | tail -5
# EXPECTED: contains ** BUILD SUCCEEDED **

# PF-8 — baseline test-function count (Task A's gate = B + 8)
grep -ch '@Test' "Salehman AITests"/*.swift | awk '{s+=$1} END {print s}'
# EXPECTED: 1502   (measured at c807861. If you measure a different B, record YOURS — the
#                   full-suite gate then expects B + 8. NOTE: 1502 coincidentally equals the
#                   OLD sheet-nav plan's post-gate number 1494+8 — that is other waves' tests
#                   landing since 0171621, NOT the nav tests already existing; PF-2's
#                   "no output" collision grep proves the nav tests don't exist yet.)
```

---

## Task A — FLAGSHIP: execute `plans/PLAN_2026-07-02_sheet_candidate_navigation.md` under executing-plans, with Amendment A-0 (re-pin at c807861)

Execute that plan's Steps 1→7 + §7 gate + §9 docs **literally**, under
`.claude/skills/executing-plans` (STOP-on-mismatch, paste-the-output). Its §2 design constraints,
§3 gate table, Step 2 derivation/falsifiability protocol, and all HASTY-MODEL TRAPS apply
unchanged. **Amendment A-0 below is the ONLY sanctioned deviation** — it re-pins the plan from
`0171621` (5,399 lines) to `c807861` (5,476 lines), because two merged waves (`f916770`
calc-quality, `1d734b1` F48 Dynamic-Type sweep + F24 ideaMetric merge) touched MarketsView after
the plan's pin. Every substitution below was verified byte-exact against `c807861` by the plan
author on 2026-07-03. **If the tree at execution time matches NEITHER the original plan's text
NOR the A-0 text for any anchor → STOP, report, do not improvise (the orchestrator re-plans).**

### Amendment A-0 (re-pin) — substitutions, in the old plan's own numbering

**A-0.1 — PF-1:** expected SHA is `c807861` (not `0171621`); MarketsView is 5,476 lines.
**A-0.2 — PF-2..PF-6 expected line numbers:** replaced by this plan's §5 PF-2 outputs (text
identical, lines drifted: sheet at 226, ideaDetailSheet at 4435, cancelAction at 4471, task at
5197, displayedIdeas at 2837). The old plan's PF-6 `selectedIdea = ` 10-hit list is now at lines
1992/3240/3249/3258/3372/3550/3714/3844/3907/4467 — same 10 hits, same text.
**A-0.3 — PF-9:** baseline B = **1502**; full-suite gate expects **B + 8 = 1510**.

**A-0.4 — Step 3 anchor is GONE (F24 merged `ideaMetric`/`summaryStat`; the signature is now
multi-line with `sub:`/`subColor:` params).** Replacement edit — insert the helpers BEFORE the
F24 comment block instead of before the signature.
**File:** `Salehman AI/Views/MarketsView.swift` · **Anchor (unique, PF-2-verified, line ~5214):**

OLD (exact, one line):
```swift
    // F24: merged with the former summaryStat helper (uniform a11y is the audit's stated goal —
```
NEW (the old plan's Step-3 helpers VERBATIM — `stepSheet(_:from:)` then
`sheetNavControls(_:)`, including all their comments — followed by a blank line and the same
F24 comment line):
```swift
    /// Step the OPEN detail sheet to the previous/next idea in board order (displayedIdeas —
    /// the same post-sort/filter order the board renders). The current index is re-resolved
    /// by id HERE, AT PRESS TIME: displayedIdeas mutates under background refresh, so an
    /// index captured at render time can be stale by the time the press lands. Unknown-id or
    /// out-of-range steps are ignored (the chevrons also disable at the ends, but a press can
    /// race a board mutation — ignoring is the safe half of the clamp). Setting selectedIdea
    /// updates the item-bound sheet IN PLACE (no dismiss) and re-fires .task(id: idea.symbol).
    private func stepSheet(_ delta: Int, from id: String) {
        let ideas = displayedIdeas
        guard let j = SheetCandidateNavigation.neighborIndex(ids: ideas.map(\.id), currentID: id, delta: delta) else { return }
        selectedIdea = ideas[j]
    }

    /// Chevron prev/next + "N of M" label for the detail-sheet header. The render-time index
    /// drives ONLY the disabled state and the label; the button ACTIONS re-resolve via
    /// stepSheet(_:from:). When the shown idea is not on the current board (opened from
    /// bestOpportunityCTA / alerts while a filter hides it, or refreshed away) both chevrons
    /// disable and NO label renders — never a fabricated position (honesty floor).
    @ViewBuilder private func sheetNavControls(_ idea: StockSageIdea) -> some View {
        let ids = displayedIdeas.map(\.id)
        HStack(spacing: 4) {
            Button { stepSheet(-1, from: idea.id) } label: {
                Image(systemName: "chevron.up").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(SheetCandidateNavigation.neighborIndex(ids: ids, currentID: idea.id, delta: -1) == nil)
            .help("Previous idea (⌘↑)")
            .accessibilityLabel("Previous idea")
            // ⌘-modified ON PURPOSE: the sheet hosts live TextFields (journalField → the
            // sizer's Acct $/Risk % fields); a bare .upArrow key equivalent would steal the
            // fields' cursor keys. House precedent: X binds .cancelAction; CodeView binds
            // only ⌘-modified equivalents.
            .keyboardShortcut(.upArrow, modifiers: .command)
            if let label = SheetCandidateNavigation.positionLabel(ids: ids, currentID: idea.id) {
                Text(label)
                    .font(.system(size: mvFont10, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Idea \(label), board order")
            }
            Button { stepSheet(+1, from: idea.id) } label: {
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(SheetCandidateNavigation.neighborIndex(ids: ids, currentID: idea.id, delta: +1) == nil)
            .help("Next idea (⌘↓)")
            .accessibilityLabel("Next idea")
            .keyboardShortcut(.downArrow, modifiers: .command)
        }
    }

    // F24: merged with the former summaryStat helper (uniform a11y is the audit's stated goal —
```
Verify (same as the old plan's Step 3):
```bash
grep -n 'keyboardShortcut' "Salehman AI/Views/MarketsView.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee .build.log | tail -5
```
EXPECTED: `.cancelAction` first (~4471), then `⌘.upArrow` and `⌘.downArrow` (~52xx), and
`** BUILD SUCCEEDED **`. (The `size: 12` literals here are re-tokenized by Task B3 — do NOT
"pre-fix" them now; Task A stays byte-faithful to the validated plan.)

**A-0.5 — Step 4 OLD block drifted (F48 tokenized the header fonts: `20`→`mvFont20`,
`12`→`mvFont12`, `18`→`mvFont18`).** Replacement edit:
**File:** `Salehman AI/Views/MarketsView.swift` · **Anchor:** the header block at ~4453–4472
(unique: contains the file's only `Close (Esc)` string).

OLD (exact, c807861):
```swift
                // ── 1. Header (symbol / market / action badge) ──────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(idea.symbol).font(.system(size: mvFont20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text(idea.market).font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(idea.symbol), \(idea.market)")
                    Spacer()
                    Text(a.action.rawValue)
                        .font(.system(size: mvFont12, weight: .bold)).foregroundStyle(actionTextColor(a.action))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(actionColor(a.action), in: Capsule())
                        .accessibilityLabel("Action: \(a.action.rawValue)")
                    Button { selectedIdea = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: mvFont18)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain).help("Close (Esc)").accessibilityLabel("Close")
                    .keyboardShortcut(.cancelAction)
                }
```
NEW:
```swift
                // ── 1. Header (symbol / market / action badge / prev-next nav) ──────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(idea.symbol).font(.system(size: mvFont20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text(idea.market).font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(idea.symbol), \(idea.market)")
                    Spacer()
                    Text(a.action.rawValue)
                        .font(.system(size: mvFont12, weight: .bold)).foregroundStyle(actionTextColor(a.action))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(actionColor(a.action), in: Capsule())
                        .accessibilityLabel("Action: \(a.action.rawValue)")
                    // Prev/next candidate stepper — board order, next to the X (see
                    // sheetNavControls for the press-time-resolution + ⌘-modifier rationale).
                    sheetNavControls(idea)
                    Button { selectedIdea = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: mvFont18)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain).help("Close (Esc)").accessibilityLabel("Close")
                    .keyboardShortcut(.cancelAction)
                }
                // Scroll target for the prev/next stepper (Step 5): the sheet stays
                // presented across a step, so the scroll offset would otherwise persist.
                .id("sheetTopAnchor")
```
Verify: the old plan's Step-4 verify verbatim; EXPECTED **exactly 2 hits** (the call + the
anchor — the definition's literal `sheetNavControls(_ idea:` can never match; dry-run-proven)
+ `** BUILD SUCCEEDED **`.

**A-0.6 — Step 5 OLD block drifted (the `WV4: ` comment prefix was dropped at HEAD).**
Replacement edit:
**File:** `Salehman AI/Views/MarketsView.swift` · **Anchor:** the backtest `.onChange` +
ScrollViewReader close at ~5175–5182 (unique: the only `scrollTo("backtestAnchor"` in the file).

OLD (exact, c807861):
```swift
        // onChange fires when the run STARTS (Store sets backtestSymbol
        // synchronously at runBacktest entry) — scroll to the backtest anchor
        // at start so the user sees the spinner appear in place.
        .onChange(of: store.backtestSymbol) { _, sym in
            guard sym == idea.symbol else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                proxy.scrollTo("backtestAnchor", anchor: .top)
            }
        }
        } // end ScrollViewReader (house pattern — proxy stays in scope for .onChange)
```
NEW:
```swift
        // onChange fires when the run STARTS (Store sets backtestSymbol
        // synchronously at runBacktest entry) — scroll to the backtest anchor
        // at start so the user sees the spinner appear in place.
        .onChange(of: store.backtestSymbol) { _, sym in
            guard sym == idea.symbol else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                proxy.scrollTo("backtestAnchor", anchor: .top)
            }
        }
        // Prev/next step: the sheet stays presented (item-bound, updates in place), so the
        // scroll offset would carry over to the NEW idea with the header off-screen. Snap
        // to the top instantly (no animation — reorientation, not decoration). Fires only
        // on an in-place identity change; a fresh open presents at the top anyway.
        .onChange(of: idea.id) { _, _ in
            proxy.scrollTo("sheetTopAnchor", anchor: .top)
        }
        } // end ScrollViewReader (house pattern — proxy stays in scope for .onChange)
```
Verify: the old plan's Step-5 verify verbatim (`scrollTo("sheetTopAnchor"` grep + build).

**A-0.7 — Steps 1, 2, 6, 7 execute EXACTLY as written in the old plan** — author-verified
byte-matching at `c807861` on 2026-07-03: Step 1's EOF anchor line is still the file's last
line; Step 6's `.sheet`/onChange block sits at 226–229 verbatim; Step 7's `.task` block sits at
5197–5211 verbatim; the Step-2 test-file name is unclaimed (PF-2). Step 1's expected enum line
is now ~5488 (was 5412) — the grep hit is the pass condition, not the number. Step 8 (live QA):
SKIP — §Task H's pre-merge visual QA covers it.

**A-0.8 — §9a dev-log entry:** date the heading `2026-07-03`; the counts clause becomes
`@Test 1502 → 1510` (or YOUR measured B → B+8); insertion anchor `## Standing notes / known
issues` is at line 9122 (grep it, don't trust the number). Everything else in the 9a template
stands — rewrite from the final diff if reality deviated (Wave-11 rule).
**A-0.9 — §9b map entry:** the old anchor `now points to sheet's Evidence net-cost line).` is
no longer paragraph-final (the calc-quality wave appended after it). Re-anchored edit —
OLD (exact): `playbook labels fastest "net" and weekly "gross, before costs".`
NEW: that same text + one space + the old plan's §9b `wave-13 (2026-07-02): …` sentence
VERBATIM, except retitle it `wave-13 (2026-07-03):`.
**A-0.10 — full-suite gate:** `** TEST SUCCEEDED **` + @Test count **1510** + the 8 named
`SheetCandidateNavigationTests/...` cases in the log (the count fluctuation caveat in
testing-discipline applies to per-run EXECUTION counts; the `grep -ch '@Test'` SOURCE count is
deterministic).

**HASTY-MODEL TRAP (Task A):** three, all fatal: (1) "the anchors drifted, so I'll adapt other
steps too while I'm here" — A-0 is the COMPLETE list of sanctioned substitutions; any other
divergence between the old plan and the tree is a STOP. (2) Pre-applying Task B/C/D styling
(role tokens, `mvFont12` chevrons, chip chrome) inside Task A's blocks — Task A lands the
dry-run-validated feature byte-faithfully; styling migrates AFTER, in its own commits, or the
diff becomes unreviewable. (3) Skipping Step 2d's red-green falsifiability probe because the
suite is green — WHIPPYX was green too.

**WIP commit:**
```bash
git add "Salehman AI/Views/MarketsView.swift" "Salehman AITests/SheetCandidateNavigationTests.swift" DEVELOPMENT_LOG.md MARKETS_TAB_MAP.md SOURCE_BUNDLE.md
git commit -m 'wip(ux-wave-2): Task A — in-sheet prev/next candidate navigation (plan 2026-07-02 @ c807861 re-pin)'
```

---

## Task B — Typographic role layer (ratio-documented) + deliberate size changes

**Design (the owner's "typographic ratios," made concrete):** a role layer ON TOP of the
existing `mvFont` @ScaledMetric mechanism (F48) — every role resolves to a backing token, so
Dynamic-Type relativity is preserved for free. The ramp approximates a **major-second (1.125×)
modular scale anchored at the 9pt caption**: 9.0 → 10.1 → 11.4 → 12.8 → 14.4 → … → 20.5,
snapped to the existing token grid. **Complete before→after size list (default text setting):**

| Role | Backing token | Sites changed this wave | Before → After |
|---|---|---|---|
| sheetTitle | mvFont20 | none (documented) | 20 → 20 |
| cardTitle | mvFont15 | none (documented) | 15 → 15 |
| **sectionHeader** | **mvFont13** | Why / Evidence / Exit plan / Context headers (4 sites) | **12 → 13** |
| metricValue | mvFont12_5 | none (documented; legacy exact-size token kept) | 12.5 → 12.5 |
| body/button | mvFont11_5 | none (documented) | 11.5 → 11.5 |
| **chipLabel** | **mvFont10** | calibrationChip (2 branches) + CTA verdict chip — implemented in Task D | **9 → 10** |
| metricLabel / caption | mvFont9 | none (documented) | 9 → 9 |
| micro | mvFont8 | none (documented) | 8 → 8 |
| (tokenization only) | mvFont12 | Task A's 2 nav-chevron icons | 12 → 12 (gains Dynamic Type) |

Rationale for the one ramp move: section headers at 12pt sat BELOW the 12.5pt metric values
they introduce — an inverted hierarchy; 12.8 on the ramp → 13. These are DELIBERATE design
changes that must survive Task H's visual QA — not drift. **Copy is byte-identical everywhere.**

### Step B1 — insert the role layer after the mvFont token block

**File:** `Salehman AI/Views/MarketsView.swift` · **Anchor (~71–72, unique pair):**

OLD (exact):
```swift
    @ScaledMetric(relativeTo: .caption2) private var mvFont22: CGFloat = 22
    @ObservedObject private var store = StockSageStore.shared
```
NEW:
```swift
    @ScaledMetric(relativeTo: .caption2) private var mvFont22: CGFloat = 22

    // ── Ideas-surface type roles (UX wave 2) ─────────────────────────────────
    // A documented hierarchy ON TOP of the mvFont @ScaledMetric tokens (the F48
    // mechanism is unchanged — every role scales with Dynamic Type via its token).
    // Ramp ≈ a major-second (1.125×) modular scale anchored at the 9pt caption:
    //   9.0 → 10.1 → 11.4 → 12.8 → 14.4 → … → 20.5, snapped to the token grid:
    //   micro 8 · caption/metricLabel 9 · chipLabel 10 · body/button 11.5 ·
    //   metricValue 12.5 (legacy exact-size token, kept) · sectionHeader 13 ·
    //   cardTitle 15 · sheetTitle 20.
    // Deliberate wave-2 change: sectionHeader 12 → 13 (mvFont13) so the sheet's
    // section headers (Why / Evidence / Exit plan / Context) outrank the 12.5pt
    // metric values they introduce. Roles name SIZES, never displayed terms —
    // the Conviction-vs-Signal-strength wording question stays parked (F08).
    // New call sites use roles; legacy mvFontN call sites migrate in a later wave.
    private var fontSheetTitle: CGFloat { mvFont20 }
    private var fontCardTitle: CGFloat { mvFont15 }
    private var fontSectionHeader: CGFloat { mvFont13 }
    private var fontMetricValue: CGFloat { mvFont12_5 }
    private var fontBody: CGFloat { mvFont11_5 }
    private var fontChipLabel: CGFloat { mvFont10 }
    private var fontMetricLabel: CGFloat { mvFont9 }
    private var fontCaption: CGFloat { mvFont9 }
    private var fontMicro: CGFloat { mvFont8 }

    @ObservedObject private var store = StockSageStore.shared
```

### Step B2 — retype the four sheet section headers (12 → 13)

**File:** `Salehman AI/Views/MarketsView.swift` · four single-line edits, each unique
(~4654 / 4677 / 4772 / 4887 pre-Task-A numbering; Task A shifts them — anchor on text):

1. OLD: `                        Text("Why").font(.system(size: mvFont12, weight: .semibold)).foregroundStyle(.white)`
   NEW: `                        Text("Why").font(.system(size: fontSectionHeader, weight: .semibold)).foregroundStyle(.white)`
2. OLD: `                    Text("Evidence").font(.system(size: mvFont12, weight: .semibold)).foregroundStyle(.white)`
   NEW: `                    Text("Evidence").font(.system(size: fontSectionHeader, weight: .semibold)).foregroundStyle(.white)`
3. OLD: `                    Text("Exit plan").font(.system(size: mvFont12, weight: .semibold)).foregroundStyle(.white)`
   NEW: `                    Text("Exit plan").font(.system(size: fontSectionHeader, weight: .semibold)).foregroundStyle(.white)`
4. OLD: `                    Text("Context").font(.system(size: mvFont12, weight: .semibold)).foregroundStyle(.white)`
   NEW: `                    Text("Context").font(.system(size: fontSectionHeader, weight: .semibold)).foregroundStyle(.white)`

### Step B3 — tokenize Task A's chevron icons (12 → mvFont12; no size change at default)

Two single-line edits inside `sheetNavControls` (added by Task A):
1. OLD: `                Image(systemName: "chevron.up").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)`
   NEW: `                Image(systemName: "chevron.up").font(.system(size: mvFont12, weight: .semibold)).foregroundStyle(.secondary)`
2. OLD: `                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)`
   NEW: `                Image(systemName: "chevron.down").font(.system(size: mvFont12, weight: .semibold)).foregroundStyle(.secondary)`

**Verify (whole task):**
```bash
grep -c 'size: fontSectionHeader' "Salehman AI/Views/MarketsView.swift"
grep -c 'size: mvFont12, weight: .semibold' "Salehman AI/Views/MarketsView.swift"
grep -c 'chevron.up").font(.system(size: mvFont12' "Salehman AI/Views/MarketsView.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee .build.log | tail -5
```
**EXPECTED OUTPUT:**
```
4
8
1
...
** BUILD SUCCEEDED **
```
(PF-3 baseline for the mvFont12-semibold pattern was 10; −4 headers +2 chevrons (B3's NEW
lines themselves match the pattern) = 8. The chevron grep proves B3 fired.)

**HASTY-MODEL TRAP:** (1) "while I'm defining roles I'll migrate every mvFont call site" —
REJECTED scope #8; the diff for B is exactly: one inserted block + 6 one-line font swaps.
(2) Renaming a role to `fontConviction`/`fontSignalStrength` or "fixing" the Conviction/Signal
strength wording in any string the ramp touches — F08 is owner-gated; roles name sizes only.
(3) Defining roles as NEW `@ScaledMetric`s (e.g. `@ScaledMetric var sectionHeader = 13`) —
that forks the token mechanism; roles must alias the EXISTING tokens.

**WIP commit:** `git add "Salehman AI/Views/MarketsView.swift" && git commit -m 'wip(ux-wave-2): Task B — type role layer + sectionHeader 12→13 + chevron tokenization'`

---

## Task C — Spacing rhythm (4/8pt) for the ideas card + sheet

**Audit result (measured at c807861):** `DS.Space` appears 126× in MarketsView; the shared scale
(xxs 4 / xs 8 / **sm 10** / **md 14** / lg 18 / xl 24 / xxl 32) has two off-grid values, and the
ideas card/sheet lean on `sm=10` everywhere plus ad-hoc 6s. `DS.Space` itself is app-wide —
changing its VALUES would restyle every tab (out of scope). Instead: an ideas-scoped role enum
on the 4/8 grid. **Complete before→after inset list:**

| Site | Before → After |
|---|---|
| ideaCard outer `.padding` | 10 → **12** |
| ideaCard root VStack spacing | 10 → **8** |
| ideaCard header/badge HStack spacing | 10 → **8** |
| ideaCard metrics-row HStack spacing | 10 → **8** |
| sheet root VStack spacing (section rhythm) | 10 → **12** |
| sheet risk-chip row HStack spacing | 6 → **8** |
| tinted-chip insets (implemented in Task D) | h7/v3 & h8/v4 → **h8/v3** |

### Step C1 — insert `IdeaSpace` after the role layer (anchor is Task-B text)

OLD (exact — exists only after Task B1):
```swift
    private var fontMicro: CGFloat { mvFont8 }

    @ObservedObject private var store = StockSageStore.shared
```
NEW:
```swift
    private var fontMicro: CGFloat { mvFont8 }

    /// Ideas-surface spacing rhythm (UX wave 2): a 4/8pt grid. DS.Space stays app-wide
    /// (its sm=10 / md=14 are off-grid); these roles apply ONLY to the ideas card +
    /// detail sheet. Values chosen so the surface tightens INSIDE groups (stack 8)
    /// and breathes BETWEEN groups (cardPad/section 12) — rhythm, not uniform padding.
    private enum IdeaSpace {
        static let chipH: CGFloat = 8    // tinted-chip horizontal inset (was 7 and 8)
        static let chipV: CGFloat = 3    // tinted-chip vertical inset (was 3 and 4)
        static let chipGap: CGFloat = 8  // gap between chips / badge-row items (was 10 and 6)
        static let stack: CGFloat = 8    // intra-card vertical rhythm (was 10)
        static let cardPad: CGFloat = 12 // card inset (was 10)
        static let section: CGFloat = 12 // sheet root vertical rhythm (was 10)
    }

    @ObservedObject private var store = StockSageStore.shared
```

### Step C2 — card root VStack + header HStack

OLD (exact, start of `ideaCard`'s returned view, ~3013):
```swift
        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(idea.symbol).font(.system(size: mvFont15, weight: .bold, design: .rounded)).foregroundStyle(.white)
```
NEW:
```swift
        return VStack(alignment: .leading, spacing: IdeaSpace.stack) {
            HStack(spacing: IdeaSpace.chipGap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(idea.symbol).font(.system(size: mvFont15, weight: .bold, design: .rounded)).foregroundStyle(.white)
```

### Step C3 — card metrics row

OLD (exact, ~3136 — the comment line makes it unique):
```swift
            HStack(spacing: DS.Space.sm) {
                // When sorted by velocity, show the sort key first so the
```
NEW:
```swift
            HStack(spacing: IdeaSpace.chipGap) {
                // When sorted by velocity, show the sort key first so the
```

### Step C4 — card outer padding

OLD (exact, ~3195 — unique via the stale-dim line):
```swift
        .padding(DS.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(boardIsStale ? 0.75 : 1.0)   // dim stale cards
```
NEW:
```swift
        .padding(IdeaSpace.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(boardIsStale ? 0.75 : 1.0)   // dim stale cards
```
(The 0.75 is changed by Task E3, not here.)

### Step C5 — sheet root VStack (anchor includes Task A's retitled header comment)

OLD (exact — the header comment is the POST-Task-A text; if it still reads
"action badge) ──" Task A did not complete → STOP):
```swift
            VStack(alignment: .leading, spacing: DS.Space.sm) {

                // ── 1. Header (symbol / market / action badge / prev-next nav) ──────
```
NEW:
```swift
            VStack(alignment: .leading, spacing: IdeaSpace.section) {

                // ── 1. Header (symbol / market / action badge / prev-next nav) ──────
```

### Step C6 — sheet risk-chip row

OLD (exact, ~4504):
```swift
                        HStack(spacing: 6) { ForEach(riskFlags) { riskChip($0) } }
```
NEW:
```swift
                        HStack(spacing: IdeaSpace.chipGap) { ForEach(riskFlags) { riskChip($0) } }
```

**Verify (whole task):**
```bash
grep -c 'IdeaSpace\.' "Salehman AI/Views/MarketsView.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee .build.log | tail -5
```
**EXPECTED OUTPUT:** `6` (stack, chipGap ×3, cardPad, section — chipH/chipV land in Task D)
then `** BUILD SUCCEEDED **`.

**HASTY-MODEL TRAP:** (1) editing `DS.Space.sm` in DesignSystem.swift to 8 or 12 "so everything
inherits it" — that restyles EVERY tab in the app; the whole point of IdeaSpace is surface
scoping. (2) sweeping ALL 126 `DS.Space` hits in MarketsView — the §above table is the complete
sanctioned list; watchlist/journal/alerts panels keep their spacing. (3) `.padding(12)` magic
numbers instead of the named roles — the tokens ARE the deliverable.

**WIP commit:** `git add "Salehman AI/Views/MarketsView.swift" && git commit -m 'wip(ux-wave-2): Task C — IdeaSpace 4/8pt rhythm for ideas card + sheet'`

---

## Task D — ONE chip system + WCAG-AA danger text (dangerSoft)

**Inventory at c807861 (the problem):** the ideas surface has five chip dialects —
card tinted chips (mvFont10 **bold**, h7/v3, 0.14 tint, no stroke), sheet riskChip (mvFont10
**semibold**, h8/**v4**, 0.14 tint + 0.35 stroke), calibrationChip (mvFont9, no chrome),
CTA verdict chip (mvFont9, no chrome), and filled action chips (card mvFont11 bold h8/v3
minWidth 74; sheet mvFont12 bold h9/v4). And `DS.Palette.danger` (system red) is used for
small TEXT where it measures **below WCAG AA 4.5:1**.

**The system (spec):**
- **Tinted status chip** (earnings, costs>edge, EV, 3-TF confluence, riskChip): label
  `fontChipLabel` (10pt) **semibold**, Capsule, insets **8/3**, fill `tint.opacity(0.14)`,
  stroke `tint.opacity(0.35)` at 0.5pt (the riskChip pattern PROMOTED — the hairline adds a
  non-color edge channel). Weight change bold→semibold on the 4 card chips is deliberate:
  bold is reserved for the filled identity chip.
- **Filled identity chip** (the action badge): unchanged, documented as the one sanctioned
  variant (card mvFont11 bold h8/v3 minWidth74; sheet mvFont12 bold h9/v4 — it anchors the
  20pt title row).
- **Inline status label** (calibrationChip, CTA verdict chip): `fontChipLabel` (10pt, was 9)
  semibold, icon + tint semantics, NO capsule — deliberate: both live in width-critical rows
  (the CTA bar's 440pt scar; the EV evidence lines), where added chrome re-breaks wrapping.
- **Tint semantics** (existing palette only): successSoft = pass/positive ·
  warningSoft = caution/demotion · **dangerSoft (NEW) = danger small-TEXT** ·
  danger stays for icons/fills/strokes (non-text ≥3:1 bar: 4.28:1 ✓) · surfaceStroke = neutral.
  No other new colors — the crimson flat-dark language is untouched.

**Hand-derived contrast table** (WCAG 2.1; derive script at §D-derive below — re-run it and
paste the output; approximations noted are pixel-probed in Task H):

| Text on background | Ratio | AA (4.5:1) |
|---|---|---|
| warningSoft on its 0.14 tint over card / sheet | 6.59 / 6.20 | ✓ |
| successSoft on its 0.14 tint over card / sheet | 6.50 / 6.12 | ✓ |
| **system red (danger)** on its 0.14 tint over card / sheet | **3.90 / 3.68** | ✗ ← why dangerSoft exists |
| **system red (danger)** naked on sheet/CTA-bar grey | **4.28** | ✗ |
| **dangerSoft (1.0, 0.50, 0.50)** on its 0.14 tint over card / sheet | **5.01 / 4.72** | ✓ |
| dangerSoft naked on sheet/CTA-bar grey | 5.99 | ✓ |
| successSoft / warningSoft naked on sheet grey (calibration + verdict chips) | 8.34 / 8.49 | ✓ |

**§D-derive:** save the following as `<scratchpad>/derive_contrast.py`, run
`python3 <scratchpad>/derive_contrast.py`, paste the output into the execution report. Inputs
are DS.Palette source values; `danger` is modeled as macOS dark-mode systemRed #FF453A
(approximation — noted for the Task-H pixel probe).

```python
# Hand-derivation: WCAG 2.1 contrast for the ideas-surface chips (UX wave 2).
def lum(c):
    def f(v): return v/12.92 if v <= 0.03928 else ((v+0.055)/1.055)**2.4
    r,g,b = c; return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b)
def ratio(fg,bg):
    a,b = sorted((lum(fg),lum(bg)),reverse=True); return (a+0.05)/(b+0.05)
def over(top,alpha,bot): return tuple(alpha*t+(1-alpha)*b for t,b in zip(top,bot))
white=(1,1,1); bgTop=(0.11,0.11,0.12)
card=over(white,0.035,bgTop)                       # DS.Bezel.cardFill over bgTop (worst case)
sheet=over(white,0.04,(0.125,0.125,0.125))         # codeSurface + DS.Bezel.shellFill
warningSoft=(1.0,0.72,0.35); successSoft=(0.45,0.85,0.55)
sysRedDark=(1.0,0.2706,0.2275); dangerSoft=(1.0,0.50,0.50)
for n,fg in [("warningSoft",warningSoft),("successSoft",successSoft),
             ("danger(sysRed)",sysRedDark),("dangerSoft",dangerSoft)]:
    print(f"{n}: tint/card {ratio(fg,over(fg,0.14,card)):.2f} | tint/sheet "
          f"{ratio(fg,over(fg,0.14,sheet)):.2f} | naked/sheet {ratio(fg,sheet):.2f}")
for dim in (1.0,0.75,0.85):                        # Task E3's stale-dim numbers
    print(f"stale dim {dim}: .secondary {ratio(over(white,0.55*dim,card),card):.2f}")
```
**EXPECTED OUTPUT (verbatim):**
```
warningSoft: tint/card 6.59 | tint/sheet 6.20 | naked/sheet 8.49
successSoft: tint/card 6.50 | tint/sheet 6.12 | naked/sheet 8.34
danger(sysRed): tint/card 3.90 | tint/sheet 3.68 | naked/sheet 4.28
dangerSoft: tint/card 5.01 | tint/sheet 4.72 | naked/sheet 5.99
stale dim 1.0: .secondary 5.68
stale dim 0.75: .secondary 3.84
stale dim 0.85: .secondary 4.51
```

### Step D1 — `DS.Palette.dangerSoft` (append-only; shared file — check COORDINATION.md first)

**File:** `Salehman AI/DesignSystem/DesignSystem.swift` · **Anchor (~49–50):**

OLD (exact):
```swift
        static let successSoft   = Color(red: 0.45, green: 0.85, blue: 0.55)
        static let warningSoft   = Color(red: 1.0,  green: 0.72, blue: 0.35)
```
NEW:
```swift
        static let successSoft   = Color(red: 0.45, green: 0.85, blue: 0.55)
        static let warningSoft   = Color(red: 1.0,  green: 0.72, blue: 0.35)
        /// Softened red for SMALL danger TEXT on dark surfaces (chips/labels): system
        /// red measures ~3.7–4.3:1 there — under WCAG AA 4.5:1 for sub-18pt text —
        /// while this swatch clears AA on every ideas-surface background (5.01 / 4.72 /
        /// 5.99:1; derivation in PLAN_2026-07-03_ux_wave2_design_system.md §D). Keep
        /// `danger` for icons, fills and strokes (non-text 3:1 bar). Mirrors the
        /// successSoft/warningSoft precedent; A11Y_BUGHUNT #12's swatch, lightened
        /// 0.45→0.50 to clear the detail sheet's lighter chip background.
        static let dangerSoft    = Color(red: 1.0,  green: 0.50, blue: 0.50)
```

### Step D2 — the shared chip chrome (insert above `riskChip`)

**File:** `Salehman AI/Views/MarketsView.swift` · **Anchor (~4301, unique):**

OLD (exact):
```swift
    private func riskChip(_ flag: RiskFlag) -> some View {
```
NEW:
```swift
    /// ONE chip chrome for every tinted status chip on the ideas surface (UX wave 2):
    /// 8/3 capsule insets, 0.14 tint fill, 0.35 hairline stroke — the riskChip pattern
    /// promoted to all tinted chips; the stroke is a non-color edge channel. Filled
    /// identity chips (actionColor background) are the one sanctioned variant and do
    /// not use this. Fonts stay at call sites (EV needs monospacedDigit).
    private struct IdeaChipChrome: ViewModifier {
        let tint: Color
        func body(content: Content) -> some View {
            content
                .padding(.horizontal, IdeaSpace.chipH).padding(.vertical, IdeaSpace.chipV)
                .background(tint.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 0.5))
        }
    }

    private func riskChip(_ flag: RiskFlag) -> some View {
```

### Step D3 — card earnings chip

OLD (exact, ~3037):
```swift
                    Text(earnFlag.badge)
                        .font(.system(size: mvFont10, weight: .bold))
                        .foregroundStyle(earnFlag.isDemoted ? DS.Palette.warningSoft : .secondary)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((earnFlag.isDemoted ? DS.Palette.warningSoft : DS.Palette.surfaceStroke).opacity(0.14), in: Capsule())
```
NEW:
```swift
                    Text(earnFlag.badge)
                        .font(.system(size: fontChipLabel, weight: .semibold))
                        .foregroundStyle(earnFlag.isDemoted ? DS.Palette.warningSoft : .secondary)
                        .modifier(IdeaChipChrome(tint: earnFlag.isDemoted ? DS.Palette.warningSoft : DS.Palette.surfaceStroke))
```

### Step D4 — card "costs > edge" chip

OLD (exact, ~3045):
```swift
                    Text("costs > edge")
                        .font(.system(size: mvFont10, weight: .bold))
                        .foregroundStyle(DS.Palette.warningSoft)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(DS.Palette.warningSoft.opacity(0.14), in: Capsule())
```
NEW:
```swift
                    Text("costs > edge")
                        .font(.system(size: fontChipLabel, weight: .semibold))
                        .foregroundStyle(DS.Palette.warningSoft)
                        .modifier(IdeaChipChrome(tint: DS.Palette.warningSoft))
```

### Step D5 — card EV chip (keeps monospacedDigit + minWidth alignment)

OLD (exact, ~3057):
```swift
                    Text(String(format: "%+.2fR EV (gross)", ev.evR))
                        .font(.system(size: mvFont10, weight: .bold).monospacedDigit())
                        .foregroundStyle(ev.isPositive ? DS.Palette.successSoft : DS.Palette.warningSoft)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((ev.isPositive ? DS.Palette.successSoft : DS.Palette.warningSoft).opacity(0.14), in: Capsule())
                        .frame(minWidth: 72, alignment: .trailing)
```
NEW:
```swift
                    Text(String(format: "%+.2fR EV (gross)", ev.evR))
                        .font(.system(size: fontChipLabel, weight: .semibold).monospacedDigit())
                        .foregroundStyle(ev.isPositive ? DS.Palette.successSoft : DS.Palette.warningSoft)
                        .modifier(IdeaChipChrome(tint: ev.isPositive ? DS.Palette.successSoft : DS.Palette.warningSoft))
                        .frame(minWidth: 72, alignment: .trailing)
```

### Step D6 — card 3-TF confluence chip (+ bearish text → dangerSoft)

OLD (exact, ~3073):
```swift
                    Text("3-TF confluence")
                        .font(.system(size: mvFont10, weight: .bold))
                        .foregroundStyle(bearish ? DS.Palette.danger : DS.Palette.successSoft)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((bearish ? DS.Palette.danger : DS.Palette.successSoft).opacity(0.14), in: Capsule())
```
NEW:
```swift
                    Text("3-TF confluence")
                        .font(.system(size: fontChipLabel, weight: .semibold))
                        .foregroundStyle(bearish ? DS.Palette.dangerSoft : DS.Palette.successSoft)
                        .modifier(IdeaChipChrome(tint: bearish ? DS.Palette.dangerSoft : DS.Palette.successSoft))
```

### Step D7 — sheet riskChip joins the system (v4→v3; .high text → dangerSoft)

OLD (exact, ~4302–4313, the full body):
```swift
        let color = flag.level == .high ? DS.Palette.danger
                  : (flag.level == .caution ? DS.Palette.warningSoft : DS.Palette.textSecondary)
        return HStack(spacing: DS.Space.xs) {
            Image(systemName: flag.level == .high ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                .font(.system(size: mvFont9))
            Text(flag.label).font(.system(size: mvFont10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.5))
        .accessibilityLabel("Risk: \(flag.label)")
```
NEW:
```swift
        let color = flag.level == .high ? DS.Palette.dangerSoft
                  : (flag.level == .caution ? DS.Palette.warningSoft : DS.Palette.textSecondary)
        return HStack(spacing: DS.Space.xs) {
            Image(systemName: flag.level == .high ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                .font(.system(size: mvFont9))
            Text(flag.label).font(.system(size: fontChipLabel, weight: .semibold))
        }
        .foregroundStyle(color)
        .modifier(IdeaChipChrome(tint: color))
        .accessibilityLabel("Risk: \(flag.label)")
```

### Step D8 — calibrationChip label 9 → 10 (font ONLY — wording/method-keying untouched, F01/F02)

Two edits inside `calibrationChip` (~3531–3537; each OLD is unique via its Label line):

1. OLD (exact):
```swift
            Label(cal.chipTitle, systemImage: assumed ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.system(size: mvFont9, weight: .semibold))
```
   NEW:
```swift
            Label(cal.chipTitle, systemImage: assumed ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.system(size: fontChipLabel, weight: .semibold))
```
2. OLD (exact):
```swift
            Label("win% assumed", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: mvFont9, weight: .semibold)).foregroundStyle(DS.Palette.warningSoft)
```
   NEW:
```swift
            Label("win% assumed", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: fontChipLabel, weight: .semibold)).foregroundStyle(DS.Palette.warningSoft)
```

### Step D9 — CTA verdict chip: label 9 → 10; blocked text → dangerSoft

Two edits in the pinned bar (~5136–5148):

1. OLD (exact):
```swift
                            let chipColor: Color = chipGate.decision == .clear ? DS.Palette.successSoft
                                : (chipGate.decision == .caution ? DS.Palette.warningSoft : DS.Palette.danger)
```
   NEW:
```swift
                            let chipColor: Color = chipGate.decision == .clear ? DS.Palette.successSoft
                                : (chipGate.decision == .caution ? DS.Palette.warningSoft : DS.Palette.dangerSoft)
```
2. OLD (exact):
```swift
                            Label(chipCompact, systemImage: chipIcon)
                                .font(.system(size: mvFont9, weight: .semibold))
```
   NEW:
```swift
                            Label(chipCompact, systemImage: chipIcon)
                                .font(.system(size: fontChipLabel, weight: .semibold))
```

### Step D10 — danger small-TEXT sweep, ideas card + sheet only (AA)

Five edits, each a `DS.Palette.danger` → `DS.Palette.dangerSoft` swap on TEXT-bearing sites
(icons in the same expressions move too — keeping icon and text the same hue; both pass their
respective bars):

1. Card stop metric with % (~3150) — OLD:
   `                    ideaMetric("Stop", "\(adaptivePrice(stop)) (\(String(format: "%.1f%%", stopPct)))", color: DS.Palette.danger)`
   NEW: same line with `color: DS.Palette.dangerSoft)`
2. Card stop metric fallback (~3152) — OLD:
   `                    ideaMetric("Stop", adaptivePrice(stop), color: DS.Palette.danger)`
   NEW: same with `dangerSoft`
3. Sheet stop metric (~4569) — OLD:
   `                    if let s = a.stopPrice { ideaMetric("Stop", adaptivePrice(s), color: DS.Palette.danger) }`
   NEW: same with `dangerSoft`
4. Sheet earnings-imminent warning (~4513–4519) — OLD (exact block):
```swift
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "calendar.badge.exclamationmark").font(.system(size: mvFont11))
                                .foregroundStyle(ep.severity == .imminent ? DS.Palette.danger : DS.Palette.warningSoft)
                            Text(ep.note).font(.caption2).accessibilityLabel("Earnings risk — see detail sheet")
                                .foregroundStyle(ep.severity == .imminent ? DS.Palette.danger : DS.Palette.warningSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
```
   NEW: both `DS.Palette.danger` → `DS.Palette.dangerSoft` (block otherwise identical).
5. tradeGateView verdict + check colors (~4326–4338) — two edits:
   OLD: `        let color: Color = v.decision == .blocked ? DS.Palette.danger`
   NEW: `        let color: Color = v.decision == .blocked ? DS.Palette.dangerSoft`
   OLD: `                let cc: Color = c.level == .fail ? DS.Palette.danger : (c.level == .warn ? DS.Palette.warningSoft : DS.Palette.successSoft)`
   NEW: `                let cc: Color = c.level == .fail ? DS.Palette.dangerSoft : (c.level == .warn ? DS.Palette.warningSoft : DS.Palette.successSoft)`

NOT swapped (deliberate): sparkline strokes, R-distribution bin fills, leading conviction
accent, momentum dot (graphics — 3:1 bar, danger = 4.28:1 ✓); everything outside
ideaCard/ideaDetailSheet/riskChip/tradeGateView (journal etc. — Rejected #9, deferred).

**Verify (whole task):**
```bash
grep -c 'dangerSoft' "Salehman AI/Views/MarketsView.swift"
grep -c 'dangerSoft' "Salehman AI/DesignSystem/DesignSystem.swift"
grep -c 'padding(.horizontal, 7).padding(.vertical, 3)' "Salehman AI/Views/MarketsView.swift"
grep -c 'IdeaChipChrome' "Salehman AI/Views/MarketsView.swift"
grep -c 'size: fontChipLabel' "Salehman AI/Views/MarketsView.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee .build.log | tail -5
```
**EXPECTED OUTPUT:**
```
11
1
0
6
8
...
** BUILD SUCCEEDED **
```
(dangerSoft in MarketsView: D6×2 + D7×1 + D9×1 + D10×7(=1+1+1+2+2) = 11. DesignSystem: the
`static let dangerSoft` definition line only = 1. Old h7/v3 padding: 0 remaining.
IdeaChipChrome: 1 struct declaration + 5 `.modifier(...)` uses (D3,D4,D5,D6,D7) = 6.
fontChipLabel: D3,D4,D5,D6,D7, D8×2, D9 = 8.)

**HASTY-MODEL TRAP:** (1) "unify" the calibrationChip's WORDING or collapse its
identity/Platt/isotonic branches while touching its font — F01/F02 is owner-gated; the diff for
D8 is two size tokens, nothing else. (2) Give the verdict chip a capsule background "for
consistency" — the 440pt CTA bar wrapped labels before (visual-QA scar 2026-07-02); inline
status labels are chrome-less BY SPEC. (3) Swap ALL `DS.Palette.danger` in the file — the D10
list is exhaustive; the momentum dot, sparklines, and journal reds are out of scope. (4) Drop
`.frame(minWidth: 72)` from the EV chip or `minWidth: 74` from the action chip — cross-card
alignment depends on them. (5) "danger looks fine to me" — the ratios are measured (3.68:1);
your monitor is not a WCAG audit.

**WIP commit:** `git add "Salehman AI/Views/MarketsView.swift" "Salehman AI/DesignSystem/DesignSystem.swift" && git commit -m 'wip(ux-wave-2): Task D — one chip system + dangerSoft AA sweep (ideas surface)'`

---

## Task E — Markets-scoped a11y (A11Y_BUGHUNT open items on this surface)

### Step E1 — #6: Monte-Carlo forward-ruin line gets a spoken label (mirrors the visible string)

**File:** `Salehman AI/Views/MarketsView.swift` · **Anchor (~1612–1620, unique via `P(ruin)`):**

OLD (exact):
```swift
                    if let mc = StockSageMonteCarloRuin.simulate(journal.trades, riskFraction: riskFrac) {
                        Text(String(format: "Forward ruin risk (%d sims @ %g%%/trade): P(ruin) %.1f%% · P(>20%% drawdown) %.0f%% · max drawdown ~%.0f%% typical, %.0f%% 95th-pct — bootstrapped from your %d closed trades.",
                                    mc.sims, riskFrac * 100, mc.pRuin * 100, mc.p20DrawdownProb * 100,
                                    mc.medianMaxDD * 100, mc.p95MaxDD * 100, mc.sampleSize))
                            .font(.caption2)
                            .foregroundStyle(mc.pRuin > 0.05 ? DS.Palette.warningSoft : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .help(StockSageMonteCarloRuin.caveat)
                    }
```
NEW:
```swift
                    if let mc = StockSageMonteCarloRuin.simulate(journal.trades, riskFraction: riskFrac) {
                        Text(String(format: "Forward ruin risk (%d sims @ %g%%/trade): P(ruin) %.1f%% · P(>20%% drawdown) %.0f%% · max drawdown ~%.0f%% typical, %.0f%% 95th-pct — bootstrapped from your %d closed trades.",
                                    mc.sims, riskFrac * 100, mc.pRuin * 100, mc.p20DrawdownProb * 100,
                                    mc.medianMaxDD * 100, mc.p95MaxDD * 100, mc.sampleSize))
                            .font(.caption2)
                            .foregroundStyle(mc.pRuin > 0.05 ? DS.Palette.warningSoft : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .help(StockSageMonteCarloRuin.caveat)
                            // A11Y_BUGHUNT #6: VoiceOver read the literal format string — at
                            // spoken as at-sign, middle dots dropped, P(ruin) as bare letters
                            // with lost parens. Same figures, speech-safe phrasing; the
                            // engine caveat moves to the hint (hover .help kept for sighted).
                            .accessibilityLabel(String(format: "Forward ruin risk from %d simulations at %g percent risk per trade. Probability of ruin %.1f percent. Probability of a drawdown over 20 percent, %.0f percent. Typical maximum drawdown %.0f percent, 95th percentile %.0f percent. Bootstrapped from your %d closed trades.",
                                    mc.sims, riskFrac * 100, mc.pRuin * 100, mc.p20DrawdownProb * 100,
                                    mc.medianMaxDD * 100, mc.p95MaxDD * 100, mc.sampleSize))
                            .accessibilityHint(StockSageMonteCarloRuin.caveat)
                    }
```

### Step E2 — #10 residual: journal value columns un-lock (fonts were fixed by F48; the width-60/56 locks + missing shrink-fit remain)

Four edits (each unique via its loop variable):
1. By-month totalR — OLD:
```swift
                            Text(String(format: "%+.2fR", mo.totalR)).font(.system(size: mvFont11, weight: .semibold))
                                .foregroundStyle(mo.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                                .frame(width: 60, alignment: .trailing)
```
   NEW:
```swift
                            Text(String(format: "%+.2fR", mo.totalR)).font(.system(size: mvFont11, weight: .semibold))
                                .foregroundStyle(mo.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .frame(minWidth: 60, alignment: .trailing)
```
2. By-year R — OLD:
```swift
                            Text(String(format: "%+.1fR", yr.totalR)).font(.caption2).foregroundStyle(.secondary)
                                .frame(width: 56, alignment: .trailing)
```
   NEW:
```swift
                            Text(String(format: "%+.1fR", yr.totalR)).font(.caption2).foregroundStyle(.secondary)
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .frame(minWidth: 56, alignment: .trailing)
```
3. By-side totalR — OLD:
```swift
                            Text(String(format: "%+.2fR", s.totalR)).font(.system(size: mvFont11, weight: .semibold))
                                .foregroundStyle(s.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                                .frame(width: 60, alignment: .trailing)
```
   NEW:
```swift
                            Text(String(format: "%+.2fR", s.totalR)).font(.system(size: mvFont11, weight: .semibold))
                                .foregroundStyle(s.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .frame(minWidth: 60, alignment: .trailing)
```
4. By-sector totalR — OLD:
```swift
                            Text(String(format: "%+.2fR", sec.totalR)).font(.system(size: mvFont11, weight: .semibold))
                                .foregroundStyle(sec.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                                .frame(width: 60, alignment: .trailing)
```
   NEW:
```swift
                            Text(String(format: "%+.2fR", sec.totalR)).font(.system(size: mvFont11, weight: .semibold))
                                .foregroundStyle(sec.totalR >= 0 ? DS.Palette.successSoft : DS.Palette.danger)
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .frame(minWidth: 60, alignment: .trailing)
```

(Journal danger-red COLOR stays — Rejected #9; this step is layout/scaling only.)

### Step E3 — stale-card dim 0.75 → 0.85 (AA for .secondary card text)

Derivation (§D-derive output): at dim 0.75, `.secondary` card text composites to **3.84:1**
(fails AA); at 0.85 it is **4.51:1** (clears; approximation of .secondary as 55% white —
pixel-probed in Task H). The staleness signal is NOT weakened in kind: the dim remains, plus
the clock badge (`clock.badge.exclamationmark`, warningSoft), the combined VoiceOver label
("board data is over 4 hours old"), and the .help all still fire.

OLD (exact — post-Task-C text):
```swift
        .opacity(boardIsStale ? 0.75 : 1.0)   // dim stale cards
```
NEW:
```swift
        .opacity(boardIsStale ? 0.85 : 1.0)   // dim stale cards — 0.85 keeps .secondary text ≥4.5:1 AA (was 0.75 → 3.84:1); clock badge + a11y label + help still carry staleness
```

**Verify (whole task):**
```bash
grep -c 'accessibilityHint(StockSageMonteCarloRuin.caveat)' "Salehman AI/Views/MarketsView.swift"
grep -c 'frame(width: 60' "Salehman AI/Views/MarketsView.swift"
grep -c 'minimumScaleFactor(0.7)' "Salehman AI/Views/MarketsView.swift"
grep -n 'opacity(boardIsStale' "Salehman AI/Views/MarketsView.swift"
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd build 2>&1 | tee .build.log | tail -5
```
**EXPECTED OUTPUT:**
```
1
1
5
<line>:        .opacity(boardIsStale ? 0.85 : 1.0)   // dim stale cards — …
...
** BUILD SUCCEEDED **
```
(`frame(width: 60` drops 4→1 — the remaining hit is the by-side LABEL column
`Text(s.side.rawValue)…frame(width: 60, alignment: .leading)`, untouched by design: "Long"/
"Short" never outgrow it. `minimumScaleFactor(0.7)` was 1 file-wide at PF (PF-3) → 1 + 4 = 5.)

**VoiceOver label roster this wave guarantees on the ideas/Markets surface** (Task H spot-checks
with VoiceOver or the Accessibility Inspector): plan-numerics metric rows — every `ideaMetric`
call (combined label, F24, pre-existing); PSR row (pre-existing, §3.1); OOS-decay row
(pre-existing, §3.2); Monte-Carlo ruin row (**E1, new**); risk chips ("Risk: …", pre-existing);
CTA verdict chip ("Pre-trade gate: …", pre-existing); prev/next chevrons + "Idea N of M, board
order" (**Task A, new**); stale board card ("board data is over 4 hours old", pre-existing).

**HASTY-MODEL TRAP:** (1) "improving" the E1 label wording beyond the visible figures — the
label must carry the SAME numbers as the visible string (nothing added, nothing dropped:
sims, risk %, P(ruin), P(>20% DD), typical DD, 95th-pct DD, sample size) or the spoken and
visible surfaces diverge (honesty floor). (2) Widening E2 to the label columns (width 72/48/96)
or recoloring journal reds — out of the listed scope. (3) Reverting the stale dim entirely
"since the badge covers it" — the dim is a deliberate signal; E3 raises its floor, never
removes it.

**WIP commit:** `git add "Salehman AI/Views/MarketsView.swift" && git commit -m 'wip(ux-wave-2): Task E — MC VoiceOver label, journal column un-lock, stale dim AA'`

---

## Task F — UI_FORMAT_AUDIT items

**No implementation.** All four items resolved at §3 (Rejected #5/#6/#7 + #1 already DONE in
the doc). Task G updates the doc statuses with evidence.

---

## Task G — Docs, LAST, written from the final diff (executing-plans rule 7)

Run `git diff c807861 --stat` and read it FIRST; every claim below must match the diff.

**G1 — `DEVELOPMENT_LOG.md`:** insert ABOVE `## Standing notes / known issues` (grep the anchor;
~9122 at c807861 — Task A's §9a entry already added lines above it):

```markdown
## 2026-07-03 · UX wave 2 — ideas-surface design system: type roles, 4/8pt rhythm, one chip system, AA danger text, Markets a11y
**Files:** Salehman AI/Views/MarketsView.swift · Salehman AI/DesignSystem/DesignSystem.swift (append-only: dangerSoft) · A11Y_BUGHUNT.md · UI_FORMAT_AUDIT.md · MARKETS_TAB_MAP.md · SOURCE_BUNDLE.md (regenerated)
**What & why:** Owner mandate "10/10 UX / proper design systems, tokens, typographic ratios". (1) TYPE: role layer over the F48 mvFont @ScaledMetric tokens (fontSheetTitle/CardTitle/SectionHeader/MetricValue/Body/ChipLabel/MetricLabel/Caption/Micro), documented against a 1.125× modular ramp; deliberate size changes: sheet section headers Why/Evidence/Exit plan/Context 12→13pt; calibrationChip + CTA verdict chip labels 9→10pt; Task-A chevrons tokenized 12→mvFont12. (2) SPACING: IdeaSpace 4/8pt roles (chipH 8 / chipV 3 / chipGap 8 / stack 8 / cardPad 12 / section 12); card padding 10→12, card stacks 10→8, sheet rhythm 10→12, chip rows 6→8. DS.Space untouched (app-wide). (3) CHIPS: one tinted-chip chrome (IdeaChipChrome: 8/3 capsule, 0.14 fill, 0.35 hairline — riskChip pattern promoted; card chips bold→semibold, h7→h8; riskChip v4→v3); filled action chips documented as the identity variant; calibration/verdict chips stay chrome-less inline labels (440pt CTA-bar wrap scar). (4) CONTRAST: DS.Palette.dangerSoft (1.0,0.50,0.50) added for small danger TEXT — system red measured 3.68–4.28:1 (fails AA 4.5) on ideas surfaces; dangerSoft 4.72–5.99:1 (derive_contrast.py in plan §D); swapped on 3-TF bearish chip, riskChip .high, verdict-chip blocked, card/sheet Stop metrics, sheet earnings-imminent line, tradeGateView verdict+fail checks; icons/fills/graphics keep danger (3:1 bar). Stale-card dim 0.75→0.85 (.secondary 3.84→4.51:1). (5) A11Y: Monte-Carlo ruin row gains speech-safe accessibilityLabel + hint (A11Y #6); journal value columns width→minWidth + minimumScaleFactor(0.7) (#10 residual); #3/#5/#7 verified already fixed in-tree, #11 fixed by F48 — statuses ticked with evidence; UI_FORMAT #3 (humanDollars band-top) verified already fixed (StockSageLiquidity.swift:76–83), #2 (rebalance FX) explicitly deferred as a correctness wave, #4 RuneScape out of scope. Copy byte-identical everywhere (honesty-string counts pinned pre/post — plan §7); owner gates untouched (RANKING #10 / F01-F02 / F08 / F10 / F03-F44 re-scanned). DEFERRED: journal danger-red small text (~4.3:1) — follow-up wave.
**Result:** build + full suite green (`** TEST SUCCEEDED **`, @Test 1502 → 1510 — the +8 are Task A's SheetCandidateNavigationTests, logged separately above); pre-merge visual QA per plan Task H (screenshots default + 440pt).
```
(Substitute YOUR measured counts if they differ — never paste counts you didn't measure.)

**G2 — `MARKETS_TAB_MAP.md`:** extend the Ideas entry's Gotchas paragraph. OLD (exact — the
text Task A's §9b appended, at paragraph end): the final characters of the wave-13 sentence
you appended in Task A (re-grep it). Append after it: ` ux-wave-2 (2026-07-03): type ROLE
tokens (fontSectionHeader 13 etc.) alias the mvFont @ScaledMetrics — new call sites use roles;
IdeaSpace 4/8pt spacing roles are ideas-card/sheet-scoped (DS.Space untouched); ALL tinted
status chips route through IdeaChipChrome (8/3 capsule, 0.14 fill, 0.35 stroke) — new chips
must too; small danger TEXT on this surface uses DS.Palette.dangerSoft (AA), danger stays for
icons/fills; stale-card dim is 0.85 (AA floor — do not lower without re-deriving contrast);
MC ruin row carries a speech-safe accessibilityLabel that must stay figure-identical to the
visible string.`

**G3 — `A11Y_BUGHUNT.md`:** flip statuses with evidence (edit the headed lines only):
- `### ⬜ #3` → `### ✅ DONE #3` and append to its first line: ` — verified fixed in-tree
  2026-07-03 (MarketsView glyph + PASS/BELOW BAR + a11y label/hint at the PSR row; landed via
  the calc-quality/F48 waves f916770/1d734b1).`
- `### ⬜ #5` → `### ✅ DONE #5` + ` — verified fixed in-tree 2026-07-03 (same PSR block:
  spoken label + caveat hint).`
- `### ⬜ #6` → `### ✅ DONE #6` + ` — fixed 2026-07-03, ux-wave-2 (accessibilityLabel +
  hint mirror the visible figures).`
- `### ⬜ #7` → `### ✅ DONE #7` + ` — verified fixed in-tree 2026-07-03 (decay row spoken
  label with "falling to"-equivalent phrasing + red-flag tail).`
- `### ⬜ #10` → `### ✅ DONE #10` + ` — fonts fixed by F48 (mvFont11); residual width-locks +
  shrink-fit fixed 2026-07-03, ux-wave-2 (minWidth + minimumScaleFactor 0.7).`
- `### ⬜ #11` → `### ✅ DONE #11` + ` — fixed by the F48 sweep (mvFont11 at both P&L sites;
  verified 2026-07-03).`
(#4/#8/#9/#12/#13/#14/#15 stay ⬜ — RuneScape surface, untouched.)

**G4 — `UI_FORMAT_AUDIT.md`:** `### ⬜ #3` → `### ✅ DONE #3` + ` — verified already fixed
in-tree 2026-07-03: StockSageLiquidity.humanDollars promotes on the rounded magnitude
(m/k >= 999.5 → next unit), StockSageLiquidity.swift:76–83.` Leave #2/#4 open; append one line
under #2: `(2026-07-03 ux-wave-2 triage: REJECTED from the UX wave — money-math correctness
change; needs its own wave with hand-derived FX fixtures.)`

**G5 — bundle:** `bash tools/bundle_source.sh` then `git status --short SOURCE_BUNDLE.md`
→ ` M SOURCE_BUNDLE.md`.

**WIP commit:** `git add DEVELOPMENT_LOG.md MARKETS_TAB_MAP.md A11Y_BUGHUNT.md UI_FORMAT_AUDIT.md SOURCE_BUNDLE.md && git commit -m 'wip(ux-wave-2): Task G — docs from final diff + backlog status ticks'`

---

## 7. Acceptance gates (ALL require pasted output)

**7a — Honesty-string byte-identity.** Re-run PF-4's loop VERBATIM → every count must equal the
PF-4 baseline (1/2/1/2/2/6/2/1/1/4/13). Then the full-literal diff:
```bash
grep -o '"[^"]*"' "Salehman AI/Views/MarketsView.swift" | sort | uniq -c > /tmp/uxw2_strings_after.txt
diff /tmp/uxw2_strings_before.txt /tmp/uxw2_strings_after.txt
```
**EXPECTED:** ONLY additions/count-increases, and every one traces to Task A's nav feature
("chevron.up", "chevron.down", "Previous idea (⌘↑)", "Previous idea", "Next idea (⌘↓)",
"Next idea", "Idea \(label), board order", "sheetTopAnchor" ×2, comment-embedded "cannot step" /
"N of M" / "Copied"-comment rewording from Step 6) or Task E1's accessibility label — plus the
doc-comment strings this plan's own inserted comments carry. **ZERO removals or reworded
existing literals.** Any unexplained `<` line → STOP; find which step changed copy and revert it.

**7b — Contrast.** §D-derive output pasted; every CHANGED chip/text listed with its ratio
(the §D table). Task H pixel-probes dangerSoft and the 0.85 stale dim in the running app.

**7c — Full suite (worktree-isolated):**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath .dd -only-testing:"Salehman AITests" 2>&1 | tee .build.log | tail -25
grep -o "SheetCandidateNavigationTests/[a-zA-Z]*()" .build.log | sort -u
grep -ch '@Test' "Salehman AITests"/*.swift | awk '{s+=$1} END {print s}'
# on failure ONLY:
grep -E "Test case '.*' failed" .build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u
```
**EXPECTED:** `** TEST SUCCEEDED **`; the 8 named SheetCandidateNavigationTests cases; source
@Test count = **1510** (PF-8 B + 8).

**7d — Diff-vs-file-list:** `git diff c807861 --stat` pasted; touched files ⊆ §4 list.

## Task H — MANDATORY pre-merge visual QA (risky class: layout + chips + sheet)

Per `.claude/skills/visual-qa/SKILL.md` — this wave hits its BEFORE-merge triggers (frame/inset
edits, new chips/badges, sheet header change). Run on the owner machine from the WORKTREE build:
`.claude/skills/run-salehman-ai/driver.sh build && … run`, then computer-use per run-salehman-ai.
Walk the skill's FULL checklist (honesty surfaces + rendering integrity + both sides of the
book), PLUS these wave-2 deltas, at **BOTH the default window AND the sheet dragged to its
440pt floor** — screenshot each state (board, buy sheet, sell/reduce sheet, 440pt sheet):

- [ ] ZERO mid-word wraps / ellipsis truncation anywhere on the card, sheet, and pinned CTA bar
      at 440pt AND default — specifically re-check the CTA bar now that the verdict chip label
      is 10pt (its 2026-07-02 wrap scar) and the EV/earnings chips with 8pt insets.
- [ ] Prev/next chevrons + "N of M" render beside the X; ⌘↓ steps to the board's next card;
      chevron disables at the ends; label ABSENT when opened from the best-opportunity CTA
      under an excluding filter (honesty absence check).
- [ ] Section headers (Why/Evidence/Exit plan/Context) visibly outrank metric values (13 vs 12.5).
- [ ] All tinted chips share one silhouette (8/3 + hairline); filled action chip unchanged;
      zoom a bearish 3-TF chip + a blocked verdict chip → dangerSoft red, legible; pixel-probe
      one dangerSoft label against its background (the 4.7:1 derivation assumed systemRed/
      .secondary values — confirm by eye + zoom, not squint).
- [ ] Stale board (if reachable; else absence-verify per the skill): cards dim to 0.85 with
      clock badge; secondary text still readable.
- [ ] Sizer "Risk %" field: plain ↑/↓ still move the text cursor (⌘-modifier proof, Task A).
- [ ] VoiceOver / Accessibility Inspector spot-check: MC ruin row speaks the E1 label; chevrons
      speak "Previous/Next idea".

Findings → fix in-session → re-run QA (a finding is not "noted", it is fixed and re-captured);
log the QA pass per the skill. QA is not passed until the re-capture is clean.

## 8. Rollback (exact)

```bash
cd "$(git rev-parse --show-toplevel)"   # the worktree
git checkout c807861 -- "Salehman AI/Views/MarketsView.swift" "Salehman AI/DesignSystem/DesignSystem.swift" DEVELOPMENT_LOG.md MARKETS_TAB_MAP.md A11Y_BUGHUNT.md UI_FORMAT_AUDIT.md SOURCE_BUNDLE.md
rm -f "Salehman AITests/SheetCandidateNavigationTests.swift"
git status --short
# EXPECTED: (empty, apart from the wip commits already on ideas-card/ux-wave-2 — the branch
# itself is disposable; worst case: git worktree remove ../ai-ux-wave2 --force and re-plan)
```

## 9. Done-means (every box needs PASTED OUTPUT in the execution report)

- [ ] PF-1…PF-8 ran first and matched (or execution STOPPED at the first mismatch with a
      `plan says X / tree says Y` report — no silent adaptation).
- [ ] Task A executed the 2026-07-02 plan with ONLY the A-0 substitutions; its Step 2
      derivation output, 8 named test cases, and red-then-green falsifiability probe pasted;
      any anchor matching neither the original nor A-0 → STOPPED.
- [ ] Tasks B–E each closed with their verification greps' expected counts AND
      `** BUILD SUCCEEDED **`; a WIP commit exists per task (`git log --oneline` pasted).
- [ ] §7a honesty proof: PF-4 counts unchanged; string-literal diff shows only the whitelisted
      additions; zero removals/rewordings.
- [ ] §7b contrast: derive script output pasted verbatim; every changed chip's ratio listed.
- [ ] §7c full suite: `** TEST SUCCEEDED **` + @Test 1510 + the 8 nav cases named in the log.
- [ ] §7d: `git diff c807861 --stat` pasted; files ⊆ §4; the report describes what the DIFF
      shows (Wave-11 rule — narration never overrides the diff).
- [ ] Owner gates re-scanned post-hoc: RANKING #10 / F01-F02 / F08 / F10 / F03-F44 untouched;
      no wording change anywhere; no nil-guard removed; no new unlabeled number.
- [ ] Task G docs written FROM the final diff; A11Y/UI-FORMAT statuses carry evidence; bundle
      regenerated (` M SOURCE_BUNDLE.md`).
- [ ] Task H visual QA: screenshots at default AND 440pt, buy AND sell sheets, checklist walked,
      findings fixed and re-captured — pixels, not narration, close this wave.
