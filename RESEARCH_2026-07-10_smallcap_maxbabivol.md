# RESEARCH 2026-07-10 — MAX / low-beta / low-IVOL long tilt on the survivorship-free small/retail segment (pre-registered)

**Verdict: NULL — 0 of 18 arms pass; the 07-03 families' "small/retail-heavy segment untested" caveat CLOSES.**
Every arm's paired diff (LOW cohort − EQW) is NEGATIVE; the low-MAX and low-IVOL low-liquidity arms are block-significantly
negative (t −4.3…−5.2). The pre-registered symmetric negative direction did NOT confirm either (winsorized conjuncts fail
DSR>0.95) — so the result is a clean refusal of the actionable long tilt, not a certified anti-edge. This was the
population the published lottery-demand/defensive premia live in, tested on the first survivorship-free substrate in
project history, with the decision rule locked before any statistic (prereg committed at `1601771`, design-reviewed with
two fabrication-vector BLOCKERs fixed pre-commit).

## Why this test
The 2026-07-03 nulls for MAX/lottery (RESEARCH_2026-07-03_max_lottery_ablation.md), low-beta/BAB-long and low-IVOL
(RESEARCH_2026-07-03_low_beta_ablation.md, + the downside-beta sibling) all carried the same caveat: 18 mega-caps exclude
the small/retail-heavy segment where the published effects are strongest. The frozen survivorship-free panel
(34,701 series, hash `5ce314475941a0cd`) finally contains that segment WITH its casualties.

## Protocol (pre-registered; design-review lineage)
- **Prereg**: `tools/eodhd_panel/PREREG_2026-07-10_smallcap_maxbabivol.md` — adversarially design-reviewed BEFORE commit;
  verdict COMMIT-WITH-FIXES; the two BLOCKERs: (1) whole-window liquidity scoping was a collider biasing cohort−EQW
  toward a fabricated PASS → replaced by AS-OF trailing-63-bar liquidity terciles at each rebalance; (2) ghost-print
  (volume=0 stale-close) returns in signal computation biased toward a fabricated NULL on the low-liquidity scope →
  replaced by the valid-return rule (bars at master j and j−1, both volume>0/close>0) with pinned minimums (MAX ≥15/21,
  BETA/IVOL ≥200/252). Also: death-blocks BOOKED at the last valid raw-open print (never dropped) with truncations
  counted+classified; raw-open presence mask (no open-or-close fallback anywhere); harmonized 252-bar warmup, ONE EQW per
  (scope,H); all-conjunct coded decision rule on a CLOSED 18-arm set; symmetric negative pre-commitment.
- **Runner**: `tools/eodhd_panel/smallcap_maxbabivol.py`, committed pre-run at `a85b7a9`; hand-derived selfchecks
  (synthetic beta=2/ivol=0, MAX top-5 fixture, DRYS SEC split boundary, t/Φ fixtures) all green in the run log.
- **Panel**: window 2000-01-03→2026-07-09 (6,668 master bars, dot-com + GFC + 2020 + 2022 + bulls); 33,813 manifest
  candidates → **5,135 clean names** (+249 integrity-screened, of which 86 have a splits-ledger entry within ±5 bars of
  the jump — the missing/duplicated-ledger class; census in the results JSON); rejections: 13,930 short / 10,081 dollar-vol
  / 4,169 entry-price / 249 gap-only. Eligible cross-sections ~2,800–3,100 names per rebalance.
- **Arms**: 3 signals (MAX top-5/21d; 252d OLS beta; 252d market-model residual IVOL — LOW-tercile long cohorts, the
  published direction) × 3 horizons (21/63/126) × 2 scopes (FULL, LOW-LIQUIDITY as-of tercile) = 18; trials = 18 + 106
  prior family arms = 124 (registry print 719); varTrialSharpe 0.0441 (above the 0.0343 floor → floor inert);
  bench124 0.5473, bench719 0.6638.

## Results (all 18 arms; diff = LOW-cohort − EQW, paired per block; cost cancels exactly)

| arm | nblk | diff_mean | t | DSR124 | S2a | S2b | S1 | negDSR | truncDel |
|---|---|---|---|---|---|---|---|---|---|
| MAX/FULL/H21 | 305 | −0.00347 | −2.35 | 0.000 | 0.000 | 0.000 | Y | 0.000 | 1444 |
| MAX/FULL/H63 | 101 | −0.01266 | −2.68 | 0.000 | 0.000 | 0.000 | Y | 0.001 | 1168 |
| MAX/FULL/H126 | 50 | −0.02471 | −3.17 | 0.000 | 0.000 | 0.000 | Y | 0.224 | 927 |
| MAX/LOWLIQ/H21 | 305 | −0.00713 | −4.46 | 0.000 | 0.000 | 0.000 | Y | 0.000 | 498 |
| MAX/LOWLIQ/H63 | 101 | −0.02306 | −4.28 | 0.000 | 0.000 | 0.000 | Y | 0.064 | 400 |
| MAX/LOWLIQ/H126 | 50 | −0.04744 | −4.89 | 0.000 | 0.000 | 0.000 | Y | 0.915 | 334 |
| BETA/FULL/H21 | 305 | −0.00191 | −1.23 | 0.000 | 0.000 | 0.000 | N | 0.000 | 1252 |
| BETA/FULL/H63 | 101 | −0.00562 | −1.16 | 0.000 | 0.000 | 0.000 | N | 0.000 | 1120 |
| BETA/FULL/H126 | 50 | −0.00488 | −0.64 | 0.000 | 0.000 | 0.000 | N | 0.001 | 992 |
| BETA/LOWLIQ/H21 | 305 | −0.00235 | −1.50 | 0.000 | 0.000 | 0.000 | N | 0.000 | 509 |
| BETA/LOWLIQ/H63 | 101 | −0.00723 | −1.49 | 0.000 | 0.000 | 0.000 | N | 0.000 | 463 |
| BETA/LOWLIQ/H126 | 50 | −0.00412 | −0.44 | 0.000 | 0.000 | 0.000 | N | 0.001 | 430 |
| IVOL/FULL/H21 | 305 | −0.00512 | −3.13 | 0.000 | 0.000 | 0.000 | Y | 0.000 | 409 |
| IVOL/FULL/H63 | 101 | −0.01587 | −2.92 | 0.000 | 0.000 | 0.000 | Y | 0.001 | 376 |
| IVOL/FULL/H126 | 50 | −0.02926 | −3.33 | 0.000 | 0.000 | 0.000 | Y | 0.286 | 373 |
| IVOL/LOWLIQ/H21 | 305 | −0.00997 | −5.13 | 0.000 | 0.000 | 0.000 | Y | 0.000 | 168 |
| IVOL/LOWLIQ/H63 | 101 | −0.03130 | −4.57 | 0.000 | 0.000 | 0.000 | Y | 0.116 | 158 |
| IVOL/LOWLIQ/H126 | 50 | −0.06241 | −5.21 | 0.000 | 0.000 | 0.000 | Y | 0.959 | 172 |

- **Decision rule (closed 18-arm set, all conjuncts): 0 passing arms → NULL.**
- **S4 (Shumway −30% delisting-haircut) robustness of the null: SATISFIED arm-by-arm** — every s4 diff remains negative
  (−0.24%…−5.9%/block, all s4 DSR 0.000); no arm is "inconclusive-on-delisting-treatment".
- **Symmetric negative direction: the pre-commitment correctly did NOT fire.** Exactly ONE arm (IVOL/LOWLIQ/H126) reached
  negDSR 0.959 > 0.95 with S1 agreement and then failed the negated winsorized conjuncts; the next-nearest
  (MAX/LOWLIQ/H126, 0.915) failed at the first conjunct. Per the prereg, partial passes are artifact flags, never
  findings — this is NOT "a significant anti-edge blocked by winsorization"; the winsorization sensitivity is exactly the
  wedge diagnostic (below) doing its job.
- Truncation booking mattered on this panel: e.g. MAX/FULL/H21 booked 1,444 delisting-truncated cohort name-blocks
  (vs 0.23% total on the 2004-12 crash-retest panel) — the design-review fix that books death-blocks instead of dropping
  them was load-bearing.

## What the negative diffs DO and DO NOT mean (the write-up's honesty core)
- **DO**: the ACTIONABLE long tilt — overweighting low-MAX/low-beta/low-IVOL names the way the app's ranking would — is
  REFUSED on this population: it underperformed the equal-weight alternative in raw block means at every horizon and
  scope, 2000–2026, survivorship-free. This is exactly the prereg's delimiter ("closes the actionable long-tilt caveat").
- **DO NOT — an "anomaly reversal" reading is FORBIDDEN (audit F13, quantitative).** The construction is
  raw-arithmetic-mean, equal-weighted, long-only — not the literature's risk-adjusted (alpha) or value-weighted claim —
  and the negatives carry the exact signature of the arithmetic-mean/Jensen variance wedge (EQW contains the high-vol
  tercile the LOW cohort excludes; E[arithmetic] ≈ geometric + σ²/2 per day), which is FIRST-ORDER SUFFICIENT to produce
  them under zero mispricing. All four wedge signatures are present: (a) per-day diffs roughly CONSTANT across H
  (MAX/FULL −1.7/−2.0/−2.0 bp/day; IVOL/LOWLIQ −4.8/−5.0/−5.0 — a pricing effect would not be horizon-flat per day, a
  σ²-wedge is); (b) diff ordering IVOL > MAX > BETA matches each sort's loading on total σ; (c) LOWLIQ > FULL (higher
  σ²); (d) the neg-flags died precisely on the WINSORIZED conjuncts — capping block returns at +100% trims exactly the
  high-vol right tail that generates the wedge. EQW's own gross levels are wedge-inflated too (8.4–8.6 bp/day ≈ 24%/yr in
  LOWLIQ — not an investable estimate). Nothing in this run's outputs discriminates genuine reversal from this mechanism.
  Licensed claim ONLY: "no actionable raw long-tilt at retail on this population — the 07-03 small/retail caveat closes
  in the null direction."

## Data-quality notes
- The crash-retest's mandatory rules were applied and visible: gross levels are plausible post-screen (EQW +1.27%/block
  H21, +7.1%/block H126 — no LAN-class magnitudes); 249 names screened with a diagnosable census (86 near-ledger).
- Price-return-only basis (dividends excluded — vendor field corrupted for this population; acceptance-documented).
  Dividend exclusion penalizes LOW-vol/LOW-beta cohorts (dividend payers concentrate there), so the negative diffs carry
  a known conservative-direction bias on BETA/IVOL — stated, unquantified.
- Liquidity scope is a LIQUIDITY proxy (as-of dollar volume), never "market cap" (panel has no cap metadata).
- **Twin listings double-weight a few firms in EQW** (audit): the screened census exposes probable same-firm pairs
  (YELL/YRCW share jump date AND ratio; TUP/TUPBQ, NOVA/NOVAQ, EBIX/EBIXQ) — the bankruptcy-ticker rename class; a few
  duplicates remain plausible among clean names. Second-order for a 2,800+-name cross-section; recorded.
- Single vendor; $1M whole-window tradeability floor carries the disclosed weak future-conditioning; block returns are
  open-to-open two-point measurements.

## What this run did NOT establish
- Nothing risk-adjusted (no alpha regressions — out of scope by design and by delimiter).
- Nothing about the SHORT legs (BAB/MAX published alpha concentrates there; fenced as non-implementable at retail).
- Nothing about dividend-inclusive total returns (stated bias direction above).
- The strong negative direction is an observation for the corpus, not a certified anti-edge (winsorized conjuncts failed).

## Verification (pre-registered 2-lens bar)
- **Lens A (code audit, conjunct-by-conjunct vs the prereg): NOT-REFUTED — "the NULL stands, over-determined"** (all 18
  arms fail the first conjunct regardless of any defect found). Sequencing verified by git ancestry (prereg 15:02:46 →
  runner 15:09:01 → results 15:22; ledger stamped `a85b7a9`; freeze hash matches). Verified clean: every filter and
  census; the integrity screen exactly as pinned; the valid-return rule governing all three signals; as-of liquidity
  terciles; raw-open mask with ZERO fallback patterns (grep-proven); exit booking with the drop clause correctly vacuous;
  Shumway leg delisting-only, both books, same maps; all six decision conjuncts coded verbatim; statistics recomputed
  bit-exact from the JSON's own inputs (all 18 dsr_124/dsr_719/neg_dsr, bench124 0.5472538574, bench719 0.6637713168;
  negDSR's sign-flip construction confirmed exactly correct); no look-ahead (all windows end at p, entry p+1, grid
  alignment recomputed exactly — 305/101/50 blocks); truncation rates plausible (≈0.53%/block ≈ 6.4%/yr series-end in
  2000-26 small caps) and symmetric. Ledger 18 records bit-match.
- **Lens A findings requiring action (all applied):**
  - **F1 (MODERATE, machinery — verdict-inert this run): the S1 REVERSED pass fed `reversed(mkt_ret)` (forward return
    array reversed) while names reverse at PRICE level** — sign + one-bar misalignment; a forward beta of exactly 1.0
    came back −0.21 reversed, so the six BETA arms' S1 columns (and partially IVOL's) are NOT a coherent walk-backward
    mirror (explains BETA's anomalous rev_t up to +8.2 / S1=N). Verdict-inert because S1 is veto-only and no arm reached
    it. **FIXED post-run @ `e30cdae`** (market reversed at price level, returns recomputed) — mandatory before any run
    where S1 could decide.
  - Recorded deviations (decision-inert): the prereg's promised "absolute cohort DSR printed (context only)" was never
    produced; skips and per-cost-leg net levels landed JSON-only (not in the stdout table; all skips were 0); the
    Shumway leg is labeled S4 in runner/JSON vs S3 in the prereg (same leg); the prereg header carried a wall-clock typo
    (corrected @ `e30cdae` with the ancestry note); the runner cites but does not assert the freeze hash.
- **Lens B (independent re-implementation from the prereg text): reproduction PASS on all 3 checks, bit-exact.**
  (1) Full arms MAX/FULL/H21 and IVOL/LOWLIQ/H63: n_blocks/diff_mean/diff_t/sharpe/skew/kurt/gross-means ALL match at
  0 absolute difference (diff_mean |Δ| ≤ 4.3e−19); first H63 rebalance cross-section reproduced (2,153 eligible /
  717 low-liq scope). (2) Direct 252-bar OLS from raw bars at a 2003-04-09 rebalance: MAX/BETA/IVOL match the pipeline
  at ≤1.1e−16. (3) DSR spot-check: varTrialSharpe 0.044119959217211 bit-exact (= sample variance of the 18 JSON
  Sharpes), bench124 0.547253857383787 bit-exact, MAX/LOWLIQ/H126 dsr_124 7.815476e−30 rel-diff 0. Script preserved in
  the session scratchpad (`indep_maxbabivol.py`, output `indep_run.log`, runtime 352s).

## Engine mapping
**No engine change.** No tilt is added; the shipped vol-targeting (vol-regime brake + cryptoRiskScaler) remains the only
vol-axis machinery, per the 07-03 conclusion it re-confirms. Trials ledger: +18 arms, family `smallcap-maxbabivol`.

## Artifacts
- Runner + prereg: `tools/eodhd_panel/{smallcap_maxbabivol.py, PREREG_2026-07-10_smallcap_maxbabivol.md}`.
- Results + log: `~/.claude/salehman-universe/panels/eodhd_us_delisted/{smallcap_maxbabivol_results.json, smallcap_run1.log}`
  (incl. the full screened-name census with splits-ledger proximity).
- Panel: frozen `5ce314475941a0cd` (34,701 series).

## Follow-up on the same frozen panel
Full-breadth reversal under its own locked prereg (`PREREG_2026-07-10_survfree_reversal.md`) — the campaign-milestone
row's named "delisting-inclusive substrate" measurement for the reversal family.
