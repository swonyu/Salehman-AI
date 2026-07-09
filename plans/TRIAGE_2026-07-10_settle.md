# TRIAGE — settle-lens composed-state findings, 2026-07-10

**Source:** wf_b4aa8817-b24 (read-only composed review of round-J + Wave A + Wave B interacting). 6 findings (4 MED / 2 LOW), ALL ACCEPTED — same display/disclosure class, fences unchanged (no cost value/gate math/sizing math/rank-order/flag change). Worst-case-row derivation: composed stack parses and stays speakable; these fix its named defects.

## S1 (MED) — Salehman AI/Views/MarketsView.swift
**Anchor:** bestOpportunityCard "Size it now" Text (~4207-4211) + bestOpportunityCTA sizeInfo/sizeIsWarning (~4739, ~4786-4787)
**Failure (composed-state):** Wave A's unfundable disclosure renders in GO-GREEN. Co-fire: shares floor to 0 (small account) AND gate not blocked. summaryLine (Wave A) appends "Below the 1-share minimum at your account size — not fundable as sized.", but the tint logic predates the suffix and knows only two warning cases (gate blocked → danger, pctOfAccount > 100 → warning); 0 shares gives pctOfAccount == 0, so both the Ideas-tab card and the global CTA paint the whole "0 shares ≈ $0 at risk … not fundable as sized" line successSoft green — while the SAME fact is warningSoft on the weekly-$ line (Wave A F4), the Deploy empty state (Wave A F5), and the sheet sizer (Wave B T13). One surface signals go, four signal warn, for one fact.
**Fix:** Card: add `|| ps.shares == 0` to the warning branch of the foregroundStyle ternary at ~4210. CTA: `sizeIsWarning: ps.pctOfAccount > 100 || ps.shares == 0` at ~4739.

## S2 (MED) — Salehman AI/Views/MarketsTodayActionsCard.swift
**Anchor:** body crown-divergence caption (~line 65: `let first = plans.first?.symbol`)
**Failure (composed-state):** Wave A's crown cross-ref keys on the UNFILTERED list while the card renders `shownPlans`. Co-fire: "Executable now only" toggle ON + raw #1 excluded by isExecutableNow (blocked or 0-share — the very rows Wave A/C1 flag) + globalBestSymbol == the surviving #1. The card then prints "The 'Do this now' CTA leads with X instead — different lens." directly above a visible list whose #1 row IS X — a false divergence claim. Inverse hole: when raw #1 == globalBestSymbol but is filtered out, a real visible divergence gets NO disclosure, defeating F8's both-directions promise.
**Fix:** Compare against the rendered list: `let first = shownPlans.first?.symbol` (compute after shownPlans; one-line move).

## S3 (MED) — Salehman AI/Views/MarketsView.swift
**Anchor:** ideaCard .stale chip (~3564-3568) + a11y clause (~3858 "this idea's analysis is over 4 hours old")
**Failure (composed-state):** Cross-wave contradiction on one card. The chip fires on the two-axis cardIsStale (analysis >4h OR price prior-UTC-day) but its help/a11y wording claims only "analysis is over 4h old". Co-fire: fresh analysis + priceAsOf <4h old but prior UTC day (e.g. any US-evening scan after 00:00 UTC) → the chip asserts ">4h-old analysis" (false) while round-J's source tag on the SAME card reads "Yahoo · 31m" (fresh). Wave B D3 introduced exactly this price-vs-analysis wording split on bestOpportunityCard/CTA/Today tile but left the board chip conflated — the one surface that also carries the round-J age tag that exposes it.
**Fix:** Split the chip wording on the axis, mirroring D3: compute analysisStaleOnly/priceStale at the chip and pick "Analysis over 4h old — tap Refresh" vs "Price not from today — re-price"; mirror in the ~3858 a11y clause.

## S4 (MED) — Salehman AI/Views/MarketsView.swift
**Anchor:** ideaCard accessibilityLabel builder (~3893 `label += ", price ..."`)
**Failure (composed-state):** Round-J's source tag is pixels-only. The card is .accessibilityElement(children: .combine) with an explicit label that REPLACES all child labels, and the builder's own A11Y-01 contract says it must "mirror EACH render condition above in the SAME order" — but round-J added the Price sub ("sample" / "cached" / "Yahoo · 26h") at ~3746-3750 without mirroring it, so VoiceOver hears "price 227.10" with no per-idea provenance/age on any board (co-fires on every card whenever sourceTagLabel is non-nil, i.e. all sample/cached boards and any live idea with priceAsOf).
**Fix:** After the price clause: `if let src = Self.sourceTagLabel(...) { label += " (\(src))" }` — reuse the same call the render site makes (or hoist it once above the chips row).

## S5 (LOW) — Salehman AI/Views/MarketsTodayActionsCard.swift
**Anchor:** row a11y builder D1 stale clause (~390-392) vs gate clause (~397/413); same pattern in MarketsView orderLabel (~4070-4077)
**Failure (composed-state):** Wave B's staleness clauses end with "." while every successor clause prepends ". " — the exact defect class Wave A's review fixed for tilt+crown (the ~4766 comment). Co-fire: stale price + any gate state on a Today row → VoiceOver text contains "…re-price before ordering.. Don't take this trade." (or "…ordering.. Pre-trade gate: risk percent not set."); on bestOpportunityCard, stale/analysis clause + firstScanCaption or earnings → "…ordering.. First scan in progress…" / "…ordering.. Earnings risk:…".
**Fix:** Drop the trailing period from the D1/D3 spoken clauses (match every neighboring clause's no-trailing-period convention), or guard with the existing hasSuffix(".") pattern from ~4772.

## S6 (LOW) — Salehman AI/Views/MarketsTodayActionsCard.swift
**Anchor:** executableOnly footnote (~70) vs isExecutableNow (~183-190)
**Failure (composed-state):** Stale filter description now visibly contradicted by Wave A's disclosure. The footnote says the filter "includes only rows that currently clear or caution on the pre-trade gate", but isExecutableNow ALSO drops 0-share rows. Co-fire: a CLEAR-badged row carrying Wave A's "— below 1-share minimum at your account size" suffix + toggle ON → the row vanishes while the on-card explanation says only gate verdicts decide inclusion (and the empty-state fallback "Lower risk %" is the anti-remedy for fundability — lower risk shrinks shares further).
**Fix:** Extend the footnote: "…on the pre-trade gate and are fundable (≥1 share) at your account size."

## Pipeline
Single Sonnet writer in hand-managed worktree /private/tmp/settle_wt (branch ideas-card/settle) → Fable review (fence sweep + condition traces) → fix pass → independent gate on merged main → ship → pixel QA.