---
name: visual-qa
description: Live-app visual QA pass for UI-visible changes in Salehman AI (Markets tab, ideas board, idea detail sheet). Use after any UI-visible wave merges — and BEFORE merge for risky layout changes (pinned bars, sheet restructures, frame/minWidth edits, new chips/badges). A green test suite is not visual verification; only pixels are.
---

# Visual QA — the live-app pass for UI changes

Tests prove the numbers; they prove nothing about rendering. Wave 11's pinned bar compiled,
passed the full test suite, and still wrapped "Backtest 5 years" mid-word as "Backtes/t 5 years" until
someone looked at actual pixels (DEVELOPMENT_LOG 2026-07-02). This skill is that look, made mandatory.

**Run/screenshot mechanics live in `run-salehman-ai` — use its driver and click map.
This file adds only the QA checklist and the pass/fail rules.**

## When required (hard gate)
- AFTER any merge that changes what the user sees (new UI, relabels, layout, chips, sheets).
- BEFORE merge for risky layout changes: pinned/floating bars, `.frame`/minWidth edits,
  sheet restructures, anything near the sheet's 440pt floor.
- NOT required for engine-only changes with zero `Views/` diff (typecheck + tests suffice).

## The flow
```bash
.claude/skills/run-salehman-ai/driver.sh build   # gate: "** BUILD SUCCEEDED **" + "App: …"
.claude/skills/run-salehman-ai/driver.sh run     # fresh instance (kills stale copies first)
```
Then per run-salehman-ai: `request_access(["Salehman AI"])` → `open_application("Salehman AI")` →
click **Markets** (~753, 292) → **Find ideas** (~847, 484) → wait ~8s for the live board.
Coordinates are approximate and shift if the window moves.

1. Screenshot the ideas board (scroll/resize for Best-opportunity + Fast-lane, per run-salehman-ai).
2. Click an idea CARD to open its detail sheet (tap gesture on the row).
3. Walk the checklist on a BUY-family sheet, then filter menu (next to the sort picker) →
   **Sells**, and open a SELL/REDUCE sheet. Reset the filter to **All** when done — it persists (Gotchas).
4. Any finding → fix pass → re-run this QA. QA is NOT passed until a re-capture is clean.
5. `.claude/skills/run-salehman-ai/driver.sh stop` — never leave the instance running.

## THE CHECKLIST
Honesty surfaces (a regression here is P1 — the app's whole value is not lying):
(Anchor `MarketsView.swift` by the grep strings below — NEVER by line number; the file
shifts constantly and its map anchors are symbol names by repo rule.)
- [ ] Calibration chip: **"win% assumed"** (⚠ triangle) or **"win% measured · n=N"** (seal) —
      grep `calibrationChip` in `Views/MarketsView.swift`; 4 call sites (best-opp, deploy capital,
      money velocity, sheet EV).
- [ ] **"(gross)"** on every EV figure: card header "+0.51R EV (gross)", "Est. EV … (gross)" metric,
      fast-lane/deploy rows, sheet EV line.
- [ ] Sheet EV line ends **"— estimate, not a forecast."** (grep `estimate, not a forecast`).
- [ ] Partial-universe line when fetches missed: **"⚠︎ N priced · M couldn't be fetched (SYM…) —
      ranking covers only what loaded."** (grep `couldn't be fetched`). Absent only when everything loaded.
- [ ] Gate R:R label reads **"Net reward:risk (after est. costs) X.X:1"** ONLY when the net figure
      resolved; plain "Reward:risk" otherwise (grep `rrPrefix` in `StockSage/StockSageTradeGate.swift`).
      The R:R break-even note carries "gross" (`StockSageRewardRisk.swift`).
Rendering integrity:
- [ ] No **"Optional(…)"**, "nil", "(nan%)", "(inf%)" anywhere — zoom on dense metric rows.
- [ ] No mid-word wrap or ellipsis truncation at the sheet's 440pt floor
      (grep `minWidth: 440` in MarketsView) AND at the default window (~516pt).
      Drag the sheet to its narrowest and re-check the pinned bar. Canonical catch: the bar once
      wrapped "Backtest 5 years" as "Backtes/t 5 years" and, after a lineLimit fix, truncated the
      verdict to "Proceed…" — it now uses compact labels (Log trade · Copy plan · Backtest 5y).
- [ ] Pinned-bar verdict chip legible and single-line: **"Clear" / "Caution" / "Do NOT trade"**
      (buy-family only; Hold/Avoid legitimately show buttons without a chip).
- [ ] Section headers render: **Evidence**, **Exit plan**, **Context** (grep the exact
      `Text("Evidence")` / `Text("Exit plan")` / `Text("Context")` labels).
      Exit plan/Context are content-gated — MISSING on a Hold/Avoid sheet with no content is correct.
Both sides of the book:
- [ ] A BUY-family sheet AND a SELL/REDUCE sheet checked. Position sizer present on BOTH
      (buy-guard renders it inside; the `sd#D` comment's `positionSizerPanel(idea)` call renders it
      for sell/reduce — grep `sd#D`; Hold/Avoid hide it — no stop).
- [ ] Ladder direction on shorts: rungs step DOWN from entry toward the target (sign flip in
      `StockSagePartialLadder.levels`). Ascending rung prices on a sell sheet = bug.

## Reading the pixels
- Small text: use the computer-use `zoom` tool on the region — never squint at a full-window
  shot and call it verified.
- `screenshot(save_to_disk: true)` ONLY when the capture will be shared; otherwise plain screenshot.
- Verify by ABSENCE too: gated elements missing on a healthy board are PASSES — no Vol-adj metric
  when the sizing multiplier ≥ 0.85, no staleness dim/clock on a freshly refreshed board.
  Confirm the gating condition, then confirm the absence.

## Findings → fix → declare
Findings become a fix pass NOW, in this session, before "QA passed" is written anywhere:
1. Fix; `driver.sh typecheck`, then `build`. UI strings are often test-pinned — run
   `driver.sh test`; **`** TEST SUCCEEDED **` is the only verdict that counts** (per-test
   counts fluctuate ±1 from parallel-runner log interleaving — never compare counts).
2. `driver.sh run` again and re-capture the failing surface. The fix is confirmed in pixels, not in diff.
3. After any code change: `bash tools/bundle_source.sh`; DEVELOPMENT_LOG.md entry above the
   "Standing notes" anchor (verification-only passes get logged too); update the file's
   MARKETS_TAB_MAP.md entry if a mapped file materially changed.
4. If a finding's "natural fix" would resolve an owner-gated question, REFUSE and ask the
   owner — refused, not flagged-and-done. The canonical owner-gate registry lives ONLY in
   the `gated-scope` skill §1; check it before any fix that changes a label, default, or
   number the owner has parked (see also `spec-fidelity` for assertion-side gates).

## Gotchas (things that actually bit)
- **@AppStorage persists filters between sessions.** `marketsIdeaFilter` = Sells survives an app
  restart — the next session's board "looks broken" (only sell/reduce ideas). Reset via the filter
  menu → All, or with the app STOPPED: `defaults delete SA.Salehman-AI marketsIdeaFilter`.
  Same class: `marketsIdeaMinConv`, `marketsIdeaSort`, `marketsWatchlistOnly`.
- **Old UI after a rebuild = stale instance**, not your bug. `driver.sh run` handles it; an
  Xcode-launched copy must be stopped from Xcode (run-salehman-ai Gotchas).
- **"Find ideas" needs web access.** Offline, the banner stays amber "Last-good (cached) … NOT
  live" — correct behavior, not a finding; you just can't QA live-board content offline.
- **One sheet type is not a QA pass.** The rung-price format bug only manifested on sub-dollar
  names; the missing sizer only on sell/reduce sheets. Cheap symbol + short side are where
  single-surface passes have missed real regressions — hence the BUY+SELL requirement.
- **The full verdict phrase lives in `.help`/VoiceOver, not the chip.** Hover the chip for the
  wording ("Proceed with caution — …"); its absence from the visible chip is by design — the
  in-sheet gate section above remains the authoritative wording.
