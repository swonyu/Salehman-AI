# RESEARCH 2026-07-10 — opportunistic insider purchases (Form 4) on the survivorship-free panel (pre-registered; the LAST credible surveyed family)

**Verdict: NULL — 0 of 4 arms pass the all-conjunct rule; run VALID (placebo veto max 0.725 across 3 seeds × 4 arms).
With this, NO SURVEYED FAMILY clears the honest bar at retail** — the measured-edge search over every family the
research corpus ever surveyed is formally closed pending genuinely new data classes. The honest texture, at
audit-corrected strength: FULL/H21 is the most directionally-alive arm ANY test produced today — as-built paired diff
+19.5bp/block, t = 1.67 over 203 blocks, lag-sign-stable, cohort median 141, the published ~monthly decay profile
visible (fades by H63, where the lag sign flips) — and the honest accounting refuses it THREE ways: **(1) the
pre-registered headline is the floored DSR 0.132** (registry 0.317; the trials=4 DSR 0.835 rides a variance measured
on only 4 correlated arms — the exact failure mode the binding floor exists for); **(2) it fails S2a winsorization
(0.888)** — the texture doesn't even survive capping single-name blocks; **(3) both verification lenses independently
measured the prereg-FAITHFUL book (the run had let ~11% unmapped names sit in EQW — a pro-signal deviation) at
+16.6bp, t = 1.39, floored DSR 0.080 — farther from the bar.** And the cost arithmetic ends the story: at the
measured 0.229 cohort retention, cohort-side turnover cost ≈ **20.0bp/block at the 13bps tier — the ENTIRE as-built
gross diff** (LOWLIQ: ≈88.7bp cost vs +13.2bp diff). The whisper nets to approximately nothing.

## Why this test
The 2026-07-09 survey graded insider "record, don't build" on ~70% decay, thin recent evidence (best post-2016 item =
an unreviewed MSc thesis, Wu 2025 — carried as a limit), and a data-block that dissolved this session: SEC's Insider
Transactions Data Sets (quarterly ZIPs, 2006q1–2025q4) downloaded in full, schema-stable. The survey's capacity-null
(FRL 2025) binds institutional size, not retail — but concentrates any residual alpha in illiquid names, so it rides
every LOWLIQ statement here. Published core: Cohen-Malloy-Pomorski 2012 (JF) — OPPORTUNISTIC purchases (routine
traders excluded) predict ~monthly returns. This run is the corpus's first refereed-grade empirical answer on
survivorship-free data, in either direction.

## Protocol (locked at `c1057c2` BEFORE any statistic; design review fixed two NULL-dilution blockers pre-commit)
- **Blocker #1**: window moved to 2009-01-02 — a 3-year routineness lookback is arithmetically impossible for 2007–08
  events on data starting 2006; unclassifiable routine traders would have polluted the opportunistic cohort exactly at
  the 2008 activity peak (34,956 panel purchases — the sample maximum). Burn-in 2006–2008.
- **Blocker #2**: events require `DOCUMENT_TYPE=="4" AND TRANS_FORM_TYPE=="4"` (+ P-code, A-disposition) — the bare
  form-type filter admits 4/A amendments (~2.6%: duplicate/late re-reports) and Form-5-carried rows (~4%: up to a year
  late). 17 review findings applied in total (RPTOWNERCIK multi-owner any-routine-excludes attribution; TRANS_DATE-keyed
  purchases-only routineness; date sanitizer; corrected census numbers; [p−20,p] event-window tiling with the H63
  mid-block dropout stated as deliberate freshness; +5-bar lag justified against the +10 alternative that could veto a
  real monthly effect; quarter-preserving placebo mechanics pinned; expected block counts pre-registered H21≈210/H63≈70;
  cohort-retention census mandated; tail rule: decision blocks end 2025-12-31).
- Extraction (data-only, `insider_extract.py`, committed pre-run @ `147fe80` with the runner): **3,328 panel names /
  164,306 opportunistic officer/director Form-4 purchases** (267,516 document-filtered panel purchases 2006–2025;
  drop censuses printed; DD-MON-YYYY parse fixture asserted). Availability = first master bar STRICTLY AFTER
  FILING_DATE (EDGAR next-business-day stamping makes this conservative — the verified GP/A finding transfers).
- Books on the thrice-verified sibling machinery: cohort (≥1 event in [p−20,p]) vs ONE EQW-all-eligible, paired diff;
  <10-cohort + 30-eligible guards; FULL / as-of LOWLIQ tercile scopes; H ∈ {21,63}; closed 4-arm set; trials = 4 + 0
  empirical family priors (registry print at 4+749); variance floor 0.0343 BINDING; S1′ lag+5 sign-agreement conjunct;
  S1″ per-quarter issuer-shuffle placebo (seeds 1/2/3, dates kept — preserves the crisis-clustered event calendar);
  S2a/S2b winsorized; S4 Shumway; symmetric negative pre-commitment. **Panel-filter basis: 2000-01-03→2026-07-09 (the
  sibling window), stated explicitly per the GP/A disclosure rule.**

## Results (paired diff = event-cohort − EQW; cost cancels by construction — level prints not produced, see deviations)

| arm | nblk | cohort med | diff_mean | t | DSR4 | DSRflr | S2a | S2b | S1lag | negDSR | retention |
|---|---|---|---|---|---|---|---|---|---|---|---|
| FULL/H21 | 203 | 141 | +0.00195 | 1.67 | 0.835 | 0.132 | 0.888 | 0.964 | Y | 0.008 | 0.23 |
| FULL/H63 | 68 | 91 | +0.00214 | 0.56 | 0.560 | 0.152 | 0.711 | 0.872 | N | 0.168 | 0.23 |
| LOWLIQ/H21 | 203 | 62 | +0.00132 | 0.75 | 0.515 | 0.020 | 0.838 | 0.962 | Y | 0.069 | 0.26 |
| LOWLIQ/H63 | 68 | 33 | +0.00015 | 0.02 | 0.349 | 0.058 | 0.683 | 0.857 | N | 0.334 | 0.24 |

- **Decision rule (closed 4-arm set): 0 passing; 0 negative flags; run VALID** (placebo max 0.725 — comfortable margin
  under the 0.95 invalidation bar across 12 draws).
- varTrialSharpe 0.00225 (floored 0.0343 — binding as pre-registered); bench4 0.050 / floor 0.195 / registry(753) 0.151.
- **What the alive-looking FULL/H21 arm is and is not**: +19.5bp/block over 203 non-overlapping monthly blocks
  (2009–2025, survivorship-free) with the right decay signature — the most literature-consistent texture in the
  entire campaign. It is ALSO t=1.67 — a result that noise plus a 4-arm × 750-prior-trial search history produces
  routinely; its S2b DSR (0.964) is a VETO-only quantity that cannot qualify; and both honest DSR accountings
  (0.835 unfloored, 0.132 floored) refuse it. Per the prereg: a partial pass is an artifact flag, never a finding.
- Cohort retention ~0.23–0.26 per block — the HIGH-turnover event cohort the review predicted (census mandated);
  skips: zero eligibility/cohort skips on the full panel (guards never bound), tail skips 5/1 exactly as pre-registered.
- Gross books: both cohort and EQW carry 2009–2026 beta (gross t/DSR recorded in the JSON for both books); only the
  paired diff is evidentiary.

## What this run did NOT establish
- Nothing about intensity/size-weighted constructions, cluster-buying, or CEO-only variants — each is a NEW prereg;
  the binary 21-bar cohort is v1 and the closest to the published core.
- The paired diff does NOT control for momentum/attention contamination (event names skew toward recent-attention
  names) — a limits line, relevant only if anyone is tempted to read 0.835 as "almost"; the decision statistics
  already refuse it.
- Pre-2009 behavior (burn-in); 4/A-only transactions (rare, lost); the CMP <3y-history asymmetry (unclassifiable
  insiders counted opportunistic — mild dilution, disclosed pre-run).
- **Recorded deviation (same class as GP/A's)**: the scope cost tiers (13/60bps) were never applied anywhere — no net
  level prints exist; decision-inert (cost cancels in the paired diff) but the prereg's "levels only" sentence
  under-delivered again. Carried to the runner-template fix list.

## Verification (pre-registered 2-lens bar — the two lenses TRIANGULATE)
- **Lens A (code audit): NOT-REFUTED — "every stored statistic reproduces bit-exactly; the full event book re-derives
  exactly."** Statistics: varTrialSharpe/benches/all DSRs bit-exact; decision conjuncts re-evaluated (passes=0
  reproduced; FULL/H21 fails THREE conjuncts — dsr_4, dsr_floor, S2a). Grid/tail arithmetic exact vs the master
  calendar (skips 5/1 = the pre-registered tail). Availability strictness probed on a real filed-on-a-trading-day
  event. Lag window proven exactly the base window shifted (no off-by-one). **The full event book re-derived from the
  raw ZIPs with fresh code: all 3,328 names, all 164,306 events, 15,269 routine-exclusions EXACT**; census chain
  closed to the row (850,886 P-rows → every drop accounted). Ledger 4 records bit-checked, run id = HEAD, registry_n
  749 read fresh pre-append.
- **Lens A findings (all recorded/applied):** (1) **MODERATE fidelity deviation, PRO-signal, NULL strengthened:**
  eligibility omitted the prereg's "AND CIK-mapped" conjunct — ~11.2% of the EQW book was unmapped names (cohort-
  ineligible by construction); the prereg-faithful counterfactual, measured: FULL/H21 +16.6bp, t 1.39, dsr_4 0.756,
  dsr_floor 0.080. **Runner fixed post-run** (mapped-set conjunct now enforced for future runs). (2) Costs never
  applied (the @13/@60 scope labels decorative — the third occurrence of this deviation class; the composite prereg
  now enforces net prints by self-failing assert). (3) Routineness history was officer/director-filtered vs the
  prereg-literal document-filtered book — 442 events (0.27%) would flip, null-dilution direction, negligible.
  (4) Placebo implemented as within-quarter issuer-COLUMN permutation (preserves per-name quarterly counts — a
  STRICTER null than the literal text; fires more easily on a leak; did not fire). (5) Censuses ii/iv delivered as
  medians+skips, not per-year series (reporting gap). (6) **S4 direction note: the Shumway haircut RAISES the diff in
  all 4 arms** (EQW carries more delisting truncations than the cohort) — S4 here is not a survived stressor and must
  not be read as one. (7) Event-book survivorship: **31% of opportunistic events sit on delisted names** (50,922/164,306)
  — the survivorship-free property holds at the event level; officer/director share row-level ~70% vs the 80%
  filing-level census (basis stated).
- **Lens B (independent re-implementation from the prereg text): CHECK 2 PASS (AAMI event list 5/5 exact from raw
  ZIPs); CHECK 3 PASS (benches/DSR bit-match; varTrialSharpe at 4.3e−19 float noise). CHECK 1 implemented the prereg
  AS WRITTEN — including the CIK-mapped conjunct the runner omitted — and independently produced FULL/H21
  +16.6bp, t 1.390** (LOWLIQ/H21 +7.2bp, t 0.416), n=203/203 blocks matching: **bit-close to Lens A's faithful
  counterfactual, confirming the deviation as the complete explanation of the as-built/faithful gap.** NULL under
  both constructions; the faithful one is farther from the bar.

## Engine mapping
**No engine change; nothing wired.** The campaign conclusion this closes: across price signals (all directions, all
substrates), fundamentals quality, and now insider transactions — every family the corpus surveyed — nothing clears
DSR>0.95 net-of-selection at retail. The engine's value remains its measured risk-discipline; the forward machinery
(journal fills, calibration, realized costs) remains the owner's own-edge detector. Trials ledger: +4 arms, family
`insider-form4`.

## Artifacts
Prereg + runner + extraction + census: `tools/eodhd_panel/{PREREG_2026-07-10_insider_form4.md, insider_form4.py,
insider_extract.py, insider_census.py}`. Results + log: `~/.claude/salehman-universe/panels/eodhd_us_delisted/
{insider_form4_results.json, insider_run1.log}`; events: `~/.claude/salehman-universe/insider_sets/insider_events.json`
(+80 raw quarterly ZIPs). Panel frozen `5ce314475941a0cd`.
