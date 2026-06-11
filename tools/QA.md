# QA system — Salehman AI

How the UI gets verified by a session that **can't see the screen** (sandboxed: no
`screencapture`, no AppleScript). The app photographs itself and judges the result.

## One command

```bash
bash tools/qa.sh            # request snapshots → launch app → print manifest + audit
bash tools/qa.sh --adopt    # also adopt the fresh snapshots as the diff baseline
```

It drops `qa/SNAPSHOT_REQUEST`, launches the Debug app (which fulfills the request
in-process on launch), waits for `qa/snapshots/INDEX.md` to refresh, then prints the
manifest and a pass/fail summary. Then just `Read` the PNGs it names.

## The three pieces

| Piece | File | Job |
|---|---|---|
| **Capture** | `Salehman AI/Tools/QASnapshots.swift` | Renders every surface to `qa/snapshots/*.png` + writes `INDEX.md` (manifest) + `contact_sheet.png` (montage). |
| **Audit** | `Salehman AI/Tools/QAAudit.swift` | Judges each PNG → `AUDIT.json`: `nonBlank`, `canvasFlat` (design-grey), `baselineDiff` (% vs baseline + heat-map). |
| **Runner** | `tools/qa.sh` | The one-command loop above. |

Triggers: `qa/SNAPSHOT_REQUEST` (consumed on launch) · View ▸ Capture QA Snapshots ·
the `ChatTabUITests` UI test (delivers PNGs every gated run).

## Two capture paths (important)

- **`snap()`** — `ImageRenderer`, fast, pure-SwiftUI only. **Cannot draw `HSplitView`/
  `VSplitView`, `ScrollView` content, or some SF Symbols** (they come out blank or as a
  yellow "prohibited" placeholder).
- **`snapHosted()`** — hosts the view offscreen in an `NSHostingView` and caches its
  layer. Heavier but renders split views, scroll content, and symbols correctly. Use it
  for the Code tab (split layout) and the deterministic galleries (code blocks/symbols).

If a surface renders blank/placeholder, switch its line from `snap` → `snapHosted`.

## Surfaces captured

Live tabs (`code_tab`, `chat_live`, `today`, `agents`, `notes`, `knowledge`, `markets`,
`memory`, `settings`), responsive variants (`chat_narrow` 560pt, `code_narrow` 640pt),
and deterministic galleries (`code_samples`, `chat_samples`) covering message blocks,
syntax-highlighted code, **markdown tables**, **Arabic/RTL** (the 14B answers in Arabic),
streaming, agent strips, and refusals — fixed clock + content so before/after is stable.

## Reading the output

1. `qa/snapshots/contact_sheet.png` — whole app at a glance.
2. `qa/snapshots/INDEX.md` — what each PNG is, size, render status/time, git SHA.
3. `qa/snapshots/AUDIT.json` (or the runner's summary) — per-surface pass/fail; a
   `*_diff.png` heat-map appears for anything that moved >0.5% vs baseline.

## Limits (stay on the manual checklist)

`ImageRenderer`/`NSHostingView` draw **static** trees — no hover, focus, sheet, or
animation states. Those are covered by the `Salehman AIUITests` flows and a human pass.
