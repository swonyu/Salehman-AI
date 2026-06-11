# QA system — Salehman AI (v6)

How the UI gets verified by a session that **can't see the screen**: the app
photographs every surface and judges the result in-process — no Screen-Recording
permission, no AppleScript.

## One command

```bash
bash tools/qa.sh            # request snapshots → launch app → print manifest + audit
bash tools/qa.sh --adopt    # also adopt the fresh snapshots as the diff baseline
# from a clean machine (builds first + quits a stale instance so the hook re-fires):
bash .claude/skills/run-salehman-ai/run.sh
```

It drops `qa/SNAPSHOT_REQUEST`, launches the Debug app (which fulfils the request on
launch), waits for `qa/snapshots/INDEX.md` to refresh, then prints the manifest +
pass/fail summary. Then `Read` the PNGs it names, or open `qa/snapshots/report.html`.

## The pieces

| Piece | File | Job |
|---|---|---|
| **Capture** | `Salehman AI/Tools/QASnapshots.swift` | Renders every surface offscreen → `qa/snapshots/*.png` + `INDEX.md` (manifest) + `contact_sheet.png` (montage). Runs the a11y sweep + geometry probe. |
| **Audit** | `Salehman AI/Tools/QAAudit.swift` | Judges each PNG → `AUDIT.json` + the `report.html` dashboard. The UI-test gate asserts `failures == []`. |
| **Color vision** | `Salehman AI/Tools/QAColorVision.swift` | Simulates color blindness → `*_deuter/_protan.png` + `cvd.json` + `cvd_report.html`. |
| **Geometry** | `Salehman AI/Tools/QAGeometry.swift` | Views opt in with `.qaGeometry("key")`; layout invariants become audit assertions. |
| **Runner** | `tools/qa.sh` | The one-command loop above. |

Triggers: `qa/SNAPSHOT_REQUEST` (consumed on launch) · View ▸ Capture QA Snapshots ·
the `ChatTabUITests` UI test.

## How a surface is rendered

ONE path: each view is hosted offscreen in an `NSHostingView` and its layer cached to a
bitmap (`snap(...)`). Plain `ImageRenderer` was dropped — it silently produced
blank/placeholder PNGs for anything wrapping AppKit or scroll/split containers. The host
gives every view a real AppKit context, so scroll views populate and controls draw.

## Audit checks (per surface — `AUDIT.json` / `report.html`)

- **nonBlank** — the render produced real content (catches silent capture failure).
- **canvasFlat** — sampled canvas points sit on the design grey (catches glow bleed).
- **edgeClear** *(v6)* — scans the FULL left/right edge columns for content overflowing
  or clipping at the frame edge (the truncation class).
- **contrast** — the readability probe's bands, measured vs WCAG-style ratios.
- **geo:*** — layout invariants (chat column capped at 780pt + centered, etc.).
- **axLabels** — interactive elements missing a label/help FAIL (live-window AX only).
- **tapTargets** *(v6)* — interactive elements <12pt (live-window AX only).
- **renderTime** *(v6)* — advisory render budget; surfaces the per-surface ms.
- **baselineDiff** — % pixels moved vs `qa/baselines/<name>.png` (+ red heat-map); a
  FAILURE for deterministic surfaces past their drift budget, informational for live.

## Color-vision audit *(v6)*

`QAColorVision` simulates **deuteranopia** + **protanopia** (Machado 2009 matrices,
linear RGB) on every surface → `<name>_deuter.png` / `<name>_protan.png`, and flags
red/green color pairs that go indistinguishable OR **collapse to one hue** (meaning
carried by hue alone). Catches the Markets buy=green/sell=red badges + the Notes
done-check green vs red accent. Advisory (non-gating) — see `cvd_report.html`. The CVD
pass runs **before** the audit so its findings fold into the report dashboard.

## Surfaces captured *(v6: 22)*

Live tabs (`code_tab`, `chat_live`, `today`, `agents`, `notes`, `knowledge`, `markets`,
`memory`, `settings`), sheets (`onboarding`, `about`, `shortcuts`, `command_palette`),
responsive variants (`chat_narrow`, `code_narrow`, `today_narrow`, `markets_narrow`,
`knowledge_narrow`), the `contrast_probe`, and deterministic galleries (`code_samples`,
`chat_samples` — message blocks, syntax code, markdown tables, Arabic/RTL, streaming,
agent strips, refusals; fixed clock + content so before/after is stable).
**VoiceMode is intentionally skipped** — its `.onAppear` starts the mic.

## Reading the output

1. `qa/snapshots/report.html` — **dashboard**: pass/fail, failing-check tally, total
   drift, slowest render, color-blind risks, fail-history sparkline; then every surface
   with severity-coloured checks, render time, and current/baseline/diff/deuteranopia
   images.
2. `qa/snapshots/contact_sheet.png` — whole app at a glance.
3. `qa/snapshots/INDEX.md` — what each PNG is, size, render status/time, git SHA.
4. `qa/snapshots/AUDIT.json` — machine-readable per-surface pass/fail.
5. `qa/snapshots/cvd_report.html` — color-blindness previews + merges.
6. `qa/history.jsonl` — one line per run (failures, surfaces, drift, CVD risks).

## Limits (stay on the manual checklist)

Captures draw **static** trees — no hover, focus, open-sheet, or animation states (the
galleries force a few). Those are covered by the `Salehman AIUITests` flows + a human
pass. `axLabels` / `tapTargets` only assess the LIVE window (offscreen hosts expose no
AX tree), so they skip silently in a headless capture.
