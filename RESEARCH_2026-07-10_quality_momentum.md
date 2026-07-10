# RESEARCH 2026-07-10 — quality × momentum composite on the survivorship-free panel (pre-registered; the last queued combination — the COMPOSITE SPACE CLOSES)

**Verdict: NULL — 0 of 6 arms pass; run VALID (placebo max 0.521). The composite space closes** (further combinations
are fenced post-hoc mining, enumerated in the prereg). The decisive texture is the one the novel S5 conjunct was built
to expose: **the composite never beats its own momentum component — s5m (composite − momentum-only increment) is
NEGATIVE at every arm.** On this population the published quality×momentum combination is momentum diluted by quality,
and momentum is itself a measured null — so even a statistical fluke could never have been sold as a combination
finding. All diffs are point-positive noise (t ≤ 1.15; best DSR_primary 0.620 on a 15-block arm).

## Why this test
Both components individually measured null today (GP/A 0/6; momentum null in every tested form across the campaign);
the published claim was that the COMBINATION at 6-12mo holds is where retail-viable premia survive (near-orthogonal
signals, near-zero turnover cost). Expected LOW; a null closes the last queued test of the entire campaign.

## Protocol (locked at `1354b25` BEFORE any statistic; the design review's blockers were themselves load-bearing)
- **Review blocker #1 exposed a false lineage claim**: the GP/A doc's "both fixed post-run" was wrong (only the dv
  clamp had landed) — corrected + the real pre-window filed-date drop landed @ `8d75a7a` (IL-27 class, 2nd instance
  today; the lineage git-diff check is now part of the review template). This runner re-specifies the drop inline
  (census: 34 events dropped).
- **Review blocker #2**: the S5 clause was internally contradictory — resolved as context prints PLUS a veto-only
  paired-mean-exceedance pass conjunct with a pinned coded form and a claim-language rule (a pass not separable from
  its best component must be presented as such).
- Also: momentum ≥200-valid-prints interior guard (ghost-run channel); rank blend pinned (k/(n−1), stable sorts,
  manifest-order ties — selfcheck fixture); lag +63 signal-content-only; **primary trials = 6 + 6 (GP/A) + 200 (the
  deduped momentum-family registry census, read fresh) = 212**; variance floor 0.0343 binding; **net level prints
  ENFORCED by an n-conditional assert** — the twice-failed promise structurally closed (the smoke PROVED the assert
  fires); placebo comp-shuffle seeds 1/2/3; S2a/S2b winsorized; S4 Shumway; runner committed pre-run @ `9f33986`.
- Substrate: 4,629 clean names; 2,432 GP/A-usable; window 2010→2026 (filter basis 2000→2026, explicit); grid origin 252.

## Results (paired diff = composite TOP-tercile − EQW; s5g/s5m = composite-minus-component increments)

| arm | nblk | diff_mean | t | DSRp(212) | DSRflr | S2a | S2b | S1lag | s5g | s5m | negDSR |
|---|---|---|---|---|---|---|---|---|---|---|---|
| FULL/H63 | 61 | +0.00317 | 1.02 | 0.245 | 0.003 | 0.596 | 0.630 | Y | +0.00242 | −0.00147 | 0.005 |
| FULL/H126 | 30 | +0.00395 | 0.62 | 0.279 | 0.019 | 0.626 | 0.693 | Y | +0.00014 | −0.00028 | 0.039 |
| FULL/H252 | 15 | +0.00591 | 0.55 | 0.385 | 0.091 | 0.792 | 0.840 | Y | +0.01208 | −0.00795 | 0.088 |
| LOWLIQ/H63 | 61 | +0.00279 | 0.67 | 0.150 | 0.001 | 0.878 | 0.927 | N | −0.00002 | −0.00094 | 0.010 |
| LOWLIQ/H126 | 30 | +0.00309 | 0.49 | 0.232 | 0.012 | 0.934 | 0.975 | N | +0.00178 | −0.00149 | 0.044 |
| LOWLIQ/H252 | 15 | +0.01370 | 1.15 | 0.620 | 0.207 | 0.993 | 0.995 | N | +0.02871 | −0.01306 | 0.019 |

- **Decision rule (closed 6-arm set, primary trials=212): 0 passing; 0 negative flags; run VALID.**
- **The S5 verdict is the finding**: s5m < 0 at all six arms — adding quality to momentum SUBTRACTS from the momentum
  component's own (null) diff on this population. The combination claim does not survive contact with survivorship-free
  small/retail data; the composite is a diluted re-derivation of a measured null.
- The elevated LOWLIQ/H252 winsorized legs (S2a 0.993 / S2b 0.995) are VETO-only quantities on an arm that fails
  dsr_primary (0.620), dsr_floor (0.207), the lag conjunct AND s5_ok, over 15 blocks. The honest mechanism (audit):
  a long-only book's per-name tail is one-sided — LOWLIQ multi-baggers exceed +100% while losses floor at −100% —
  so ±100% winsorization is de facto right-tail truncation, shrinking variance far more than mean and RAISING the
  Sharpe/DSR. That says the raw diff is **carried by a handful of extreme low-liquidity names — a fragility
  indicator, not robustness**. Never quote 0.993/0.995 as near-passes.
- All six point-means positive licenses NO joint statement: the arms are one correlated cluster (same panel and
  composite, nested horizons, LOWLIQ ⊂ FULL) — effectively one modestly positive H63 series (t=1.02), noise-level.
- **The measured "orthogonality": the composite cohort overlaps ~65% with the GP/A-only cohort and ~67% with the
  momentum-only cohort** — the blend never selected a genuinely distinct book (census, audit-mandated report line).
- The momentum-only component book's `comp_mom_diff_t` reaches 2.40 at LOWLIQ/H252 — a trials-UNCORRECTED,
  role=diagnostic quantity with no promotion path, on a family already closed NULL by its own pre-registered runs;
  it must never be inverted into "momentum works here".
- Net level prints present on all arms (assert-enforced): e.g. FULL/H63 cohort net +0.187%/block at 13bps — levels
  carry the same insignificance as the diffs.

## What this run did NOT establish
Nothing about double-sort intersections, non-equal weights, quintiles, or any other signal pair — all pre-enumerated
as considered-and-NOT-run; each would need its own prereg and now faces the closed-space fence. Nothing risk-adjusted.
The prereg's disclosed limits (rank-blend v1, price-return basis penalizing both legs symmetrically, intersection
coverage) all carry.

## Verification (pre-registered 2-lens bar)
- **Lens A (code audit incl. the lineage git-diff check): NOT-REFUTED** — sequencing git-verified (prereg 21:15 →
  runner 21:27 = HEAD, byte-identical → results 21:33); **the lineage clause satisfied AND load-bearing** (8d75a7a
  verified ancestor-of-HEAD with the fix content present; the runner's inline re-specification + 34-dropped census
  confirmed); every pinned mechanic verified (rank01 fixture hand-re-derived; manifest order proven through dict
  insertion-order; momentum prefix arithmetic = [p−252, p−21] inclusive; lag composition byte-equal to the audited
  GP/A leg; placebo faithful; floor binding; net-print assert before the JSON write with spot-checked arithmetic;
  M=200 reproduced from the live registry); **statistics bit-exact** (varTrialSharpe, all three benches, two arms'
  full DSR sets; t=SR·√(n−1) to <1e−12 on all arms; decision rule re-evaluated to 0 passes; s5_ok reproduced;
  inc_mom_mean negative 6/6); ledger 6+12 records spot-checked bit-exact with role=diagnostic carried.
- **Lens A findings (all recorded/applied):** (1) the prereg's pinned S5 length-assert was omitted (equality held by
  construction — single guarded append site, audit-verified; **assert added post-run** for future reruns); (2) two of
  the mandated censuses (per-year eligibles; GP/A-fresh vs momentum-valid attrition split) were not emitted —
  disclosed as a reporting gap, decision-inert; (3) pre-window census unit note: 34 EVENTS dropped (a name can carry
  several pre-2010 filings; the prereg's "~20 names" bound is the name-level figure) — NULL-safe direction;
  (4) **MODERATE infrastructure find, fixed same-session: the registry consumer's (run, config) dedup collapsed every
  arm-keyed ledger record** (this run + the five sibling panel runs each counted as 1 instead of 24/18/16/6/4/18) —
  future deflation censuses would have UNDER-counted selection history (the dangerous direction, inverse of the
  ledger's documented safe-direction caveat). Dedup key now falls back to `arm`; verified: N_raw 421 → 484 with every
  family at its true count.
- **Lens B (independent re-implementation from the prereg text): CHECK 2 PASS — the composite value reproduced
  END-TO-END from raw inputs** (AAPL at the first decision rebalance: GP/A 0.34161978106752855 hand-derived from the
  raw 10-K records = pipeline exactly; momentum 0.4866155536947874 from raw bars = pipeline exactly; both ranks and
  the composite 0.7278225806451613 equal; cohort membership confirmed). **CHECK 3 PASS bit-exact** (varTrialSharpe,
  benches, FULL/H63 dsr_primary all `==`). **CHECK 1: arm means to ~3–4dp, formally short of 5dp — localized to the
  lens's OWN panel-filter re-derivation** (its clean = 5,111 vs the runner's 4,629, where 4,629 exactly matches the
  audited shared filter code's GP/A-run output on the identical window; that filter layer was bit-exact-reproduced
  three separate times today by other lenses). With eligible medians (428=428), n_blocks (61/15) and skips matching,
  its arms land at +0.00304/t 0.98 and +0.01161/t 0.95 — same signs, same insignificance: **NULL under its
  construction too.** Bonus finding: its first pass crashed on a degenerate vendor "1/0" split record — an independent
  re-confirmation of the acceptance-documented defect class the panel toolchain guards.
- **Adjudication (orchestrator, recorded — the GP/A precedent applies): ship on composition.** Every layer carries at
  least one bit-exact independent verification (filters: three exact reproductions today; composite signals: Lens B
  end-to-end; statistics: both lenses; books/decision: Lens A), the residual sits in the most-verified layer, and the
  NULL is insensitive under every construction tried.

## Engine mapping
**No engine change; nothing wired. This closes the LAST queued test of the campaign.** With it: price signals (all
directions, all substrates), fundamentals quality, insider transactions, and now the quality×momentum composite are ALL
measured nulls at the honest bar — the surveyed AND queued space is exhausted. The steady state: the engine's
maximally-evidenced risk discipline; the owner's fills feeding the live calibration/realized-cost machinery (the one
edge no dataset can test); any new idea enters via prereg or not at all. Trials ledger: +6 decision arms + 12
diagnostic component arms, family `quality-momentum`.

## Artifacts
Prereg + runner: `tools/eodhd_panel/{PREREG_2026-07-10_quality_momentum.md, quality_momentum.py}`. Results + log:
`~/.claude/salehman-universe/panels/eodhd_us_delisted/{quality_momentum_results.json, qm_run1.log}`. Panel frozen
`5ce314475941a0cd`; EDGAR facts + events artifacts as in the sibling files.
