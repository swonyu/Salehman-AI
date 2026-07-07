# PLAN — OSS-borrow wave for the Ideas section (2026-07-07, owner-directed)

Owner (verbatim): "improve it even more and burrow from similiar open source apps to the ideas card".
Source: 4-surveyor fleet over OpenBB/Stocksera, Ghostfolio/PortfolioPerformance, FreqUI/Jesse/Hummingbot,
lightweight-charts/StockSharp/Lean (24 patterns) → Opus synthesis (top-5 + 15 dropped) → my triage below.
Full survey output preserved in this plan's Dropped section + the fleet record (wf_0fa52200-480).

## Vetted ship list (all honesty-CLEAN, no owner gates, data already in the engine)

| # | Item (source) | What | Where | Why honest | Effort |
|---|---|---|---|---|---|
| B1 | Per-idea at-risk $ (FreqUI TradeDetail "At risk") | The dollars lost if the stop fills — shares × stop-distance — inline on each ranked idea card next to Stop, exactly the arithmetic bestOpportunityCard's "Size it now" line already does; renders ONLY when account+risk% parse (same guard) and stop resolves; nil ⇒ nothing | Ranked idea card row | Pure arithmetic over shown numbers; "sizes the LOSS, not a profit promise" framing already established | S |
| B2 | Trade-plan band on the sheet chart (lightweight-charts "plot a trade" + series markers) | On the DETAIL-SHEET price chart: thin line at stop (danger) and target (success), translucent entry→stop / entry→target bands, entry marker dot at the last bar (= where the signal fired, honestly labeled "as of latest close"); reuses the already-shown prices/dist% — spatially ties plan to price action | Detail-sheet chart (card spark too small — deliberate adaptation) | Renders OUR OWN plan numbers on real history; no distribution/probability implication; labels reuse shipped strings | M |
| B3 | At-the-extreme flag (Ghostfolio min/max highlight) | "At recent high/low" chip when current price == running min/max of the spark window AND min≠max (Ghostfolio's own degenerate-series guard); card + sheet | Idea card + detail sheet | Deterministic descriptive fact over the shown series; complements the existing near-52wk rationale bullet with a glanceable state | S |

Fixture note (pixel-proof guaranteed): NVDA's up250 ends AT its running high and 1120.SR's downtrend at its
low — both B3 states render in QA; B1 renders under the neutralized 10000/1% sizer; B2 renders on
markets_idea_detail (long) + markets_idea_detail_brake (short direction flips the band).

## Closed at triage
- **X-ray gate checklist (Ghostfolio rules engine)** — ALREADY PRESENT: the sheet's pre-trade gate block
  renders pass/fail icons + plain-language sentences with actual numbers interpolated ("Risk 1.0% within
  the 2.0% cap", "Net reward:risk (after est. costs) 1.8:1 — thin; below 2:1") — verified in today's
  markets_idea_detail captures. The synthesis's residual (portfolio-level structural rules with per-rule
  toggles) is a NEW feature adjacent to owner-gated thresholds — parked, not borrowed silently.
- **Signal-fire marker** — folded into B2 (entry marker at the latest bar; the fire-time IS scan time).

## Dropped by the synthesis (kept for the record; do not re-file without new data feeds)
Analyst target slider / upgrades table / peer multiples / sector donut / ticker header strip / 52wk-MA
screener columns / key-stats grid (all need third-party or reference feeds the engine doesn't expose —
several are honest and good IF the owner ever wants a reference-data feed: that is an OWNER decision);
threshold-slider customization (owner-gated thresholds); monthly-returns heatmap + underwater chart
(honest but low value-per-effort for a DSR≈0 engine — heatmap invites seasonal pattern-hunting);
open-heat donut (numbers already explicit); live stop-distance (needs live position stream); kebab menu +
profit-pill list (layout niceties, deferred).

## Protocol
Per item: sonnet-xhigh impl in worktree (isolated .dd gates) → opus-xhigh adversarial review → my
independent gate → qa.sh capture (pinned binary) → Read affected PNGs (+ sips crops for detail claims;
hand-derive any numeric literal) → ship (dev-log, bundle, map if material, add-by-name, pull-rebase with
sibling-race handling, CI) → worktree cleanup. One item per capture round. STOP on plan-vs-reality mismatch.
