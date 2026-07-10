# PRE-REGISTRATION — opportunistic insider purchases (FORM 4 ONLY, open-market P-code) on the survivorship-free panel
(written 2026-07-10 ~20:20; revised ~20:45 after adversarial design review — verdict COMMIT-WITH-FIXES, both blockers +
all should-fixes + all notes applied; committed BEFORE any test statistic. The strongest remaining untested family per
the 2026-07-09 non-price survey, whose data-block premise dissolved.)

**Why this test:** the survey graded insider "record, don't build" on ~70% decay, thin recent evidence (its best
post-2016 item is an UNREVIEWED MSc thesis — Wu 2025, labeled as such, carried into Disclosed limits), and a data-block
that is now FALSE (80/80 quarterly SEC ZIPs on disk, schema-stable). Its capacity-null (FRL 2025) was measured at
INSTITUTIONAL size and does not bind retail — but it concentrates residual alpha in illiquid names, so it MUST ride any
LOWLIQ owner presentation. Published core (Cohen-Malloy-Pomorski 2012, JF): OPPORTUNISTIC purchases (routine traders
excluded) predict ~monthly returns; survey-era ~0.3–0.4%/mo 2008-2024 pre-decay. Expected honest size: LOW; a null
closes the family. **Review hazard, owned:** both blockers found pre-commit (burn-in arithmetic; amendment/Form-5
leakage into events) were NULL-direction dilution defects — fixed below so a null, if it comes, is real.

## Data (acceptance-measured 2026-07-10 BEFORE this prereg)
- Insider: SEC Insider Transactions Data Sets, 80 quarterly ZIPs 2006q1–2025q4 (`~/.claude/salehman-universe/insider_sets/`;
  schema issues: none; **event coverage ENDS 2025-12-31** — see the tail rule below). Dates are DD-MON-YYYY (pinned;
  the extraction pass carries a parse fixture assert). Join: SUBMISSION.ISSUERCIK → `edgar_cik_map.json` (4,288 clean
  + 184 screened panel names; ~83.5% of clean names — unmapped excluded from BOTH books, disclosed).
- Census (measured, corrected per review #8): **267,516 panel-joined P-code non-derivative purchase transactions with
  TRANS_DATE in 2006–2025** (range 6,956/yr in 2024 to **34,956/yr in 2008**; 1,193 further rows carry out-of-range/
  garbage TRANS_DATEs and are dropped by the sanitizer below). 80% of purchase filings carry an officer/director
  reporter. The run's census (i) print must reconcile to these corrected numbers.
- Prices: frozen survivorship-free panel `5ce314475941a0cd`; master calendar GSPC.INDX.
- **Test window: 2009-01-02 → 2026-07-09** (review BLOCKER #1: the 3-year routineness lookback needs 2006–2008 as
  burn-in — a 2007 event can NEVER satisfy a 3-prior-years rule on data that starts 2006; 2009 is the first fully
  covered year. 2007–2008 blocks may be printed as context, never decision). **Panel-freeze filter basis:
  2000-01-03 → 2026-07-09 — the sibling implementation's own window, stated explicitly per the GP/A disclosure rule**
  (filters: ≥756 bars, no >16d gap, median $vol ≥$1M, $1 at entry, integrity screen with |Δposition|≤20 pinning).
- **Decision blocks end at the last rebalance whose trailing 21-bar event window is data-covered (≈2026-01)** (review
  #5) — later blocks would have structurally empty cohorts; the tail skips are pre-registered here, not anomalies.

## Signal (mechanical, as-of; FORM 4 ONLY — review BLOCKER #2)
- **Event = a NONDERIV_TRANS row with TRANS_CODE = "P" AND TRANS_ACQUIRED_DISP_CD = "A" (review #15) AND
  TRANS_FORM_TYPE = "4" AND its accession's SUBMISSION.DOCUMENT_TYPE = "4"** — this excludes 4/A amendments (~2.6% of
  P-rows: separate accessions re-reporting the original with LATER filing dates ⇒ duplicates + spurious late events)
  and Form-5-carried transactions (~4%: up-to-a-year-late disclosure, not CMP's Form-4 signal). A transaction only
  ever reported on a 4/A is lost (rare, disclosed). The SAME document filter applies to rows feeding routineness.
- **Reporter attribution (review #3): each transaction is attributed to ALL owner CIKs (`RPTOWNERCIK` — pinned exact
  field name) on its accession** (1.8% of accessions are multi-owner); the officer/director test = substring "Officer"
  OR "Director" in `RPTOWNER_RELATIONSHIP` (verified safe on the measured value set).
- **Routineness (simplified CMP; review #4 pins):** a reporter CIK is ROUTINE for issuer i at an event whose
  **TRANS_DATE** falls in year Y, month M iff that reporter placed a document-filtered P-code purchase in that issuer
  in calendar month M of EACH of years Y−1, Y−2, Y−3. Month key = TRANS_DATE (the trade — CMP's basis). Routineness
  uses **purchases only** (the sells-join sentence from the draft is DELETED — sells feed nothing). An event is
  OPPORTUNISTIC iff NO attributed owner is routine (any-routine ⇒ excluded — errs toward exclusion, CMP-faithful).
  **Disclosed asymmetry:** CMP discards insiders with <3 years of history; this design classifies them opportunistic —
  a permanent mild dilution channel (named, accepted).
- **Date sanitizer (review #4):** rows with TRANS_DATE year outside [2000, filing year] are dropped and counted.
- **Roles fully assigned:** TRANS_DATE → routineness classification; FILING_DATE → availability; PERIOD_OF_REPORT →
  unused. **Availability = the first master bar STRICTLY AFTER FILING_DATE** (EDGAR stamps post-17:30 acceptances with
  the next business day's date — the GP/A review-#10 verification transfers verbatim: strictly-after is conservative).
- **Name-level signal at rebalance p: ≥1 opportunistic officer/director Form-4 purchase with availability bar ∈
  [p−20, p] inclusive** (review #7 pin; at H=21 consecutive event windows tile exactly). At H=63 events landing in the
  middle ~42 bars of a block never enter any cohort — a DELIBERATE freshness choice (the published effect is ~1 month;
  staler events are not the signal), stated. Binary cohort, no intensity weighting (v1; intensity = a NEW prereg).

## Books, scopes, arms
- Rebalance grid: origin = window start + 21 (no price warmup — the GP/A review-#13 logic; the sibling's WARMUP=252 is
  deliberately NOT inherited), stepped by H. Eligibility at p: valid raw-open entry print at p+1 AND ≥1 dv print in
  [max(0,p−62)..p] (63 bars, clamped — the audited fix) AND CIK-mapped. **COHORT = eligible names with the signal;
  EQW = ALL eligible names** (cohort ⊂ EQW, same convention as both siblings — slight attenuation, conservative);
  paired diff per block. **Cohort guard: skip the arm's block when the cohort has <10 names** (also the standard
  30-eligible guard); skips COUNTED and printed — note the guard conditions retained blocks on higher-activity regimes;
  the paired design mostly immunizes this and the census exposes it (review #16).
- Scopes: FULL @13bps; LOW-LIQUIDITY as-of trailing-63-bar median-dv tercile @60bps (levels only; cost cancels in the
  paired diff). **Cohort turnover at H=21 is HIGH by construction** (events expire after 21 bars — near-full cohort
  re-formation; review #10): decision-inert here, but a cohort-overlap census (mean consecutive-block retention) is
  MANDATED in the results artifact, and the paired-diff-overstates-net disclosure rides any promotion.
- Horizons H ∈ {21, 63} — the published effect's reach; H=5 would import the announcement-window effect this design
  deliberately does not test; 126+ is outside the documented horizon (trials discipline, pre-justified).
- Decision arms = 2 H × 2 scopes = **4**. **Pre-registered expected block counts (review #6): H21 ≈ 210, H63 ≈ 70
  (2009→2026-01), minus tail/thin-month skips (2024–25 panel purchases run low — ~580/mo — expected skip source).**

## Statistics
- Per arm: paired block diff → mean, t, DSR (`StockSageDeflatedSharpe` port, thrice bit-verified 2026-07-10); GROSS
  t/DSR for BOTH books. **Trials = 4 + 0 empirical family arms** (ledger census: zero insider records; the acceptance
  census computed event COUNTS only — never joined to returns — and the survey's insider section was literature-only:
  verified, review #14) with the registry-informed print at 4 + N where N = the trials-ledger line count at run time
  (read fresh, never hardcoded). varTrialSharpe
  floored at 0.0343, floor BINDING on any would-be pass.
- Sensitivity legs (VETO-only): **S1′ short-lag: availability +5 master bars** (kills day-0..2 announcement artifacts
  while retaining 16/21 drift bars; +10 would eat half the H21 block and could veto a REAL monthly effect — the exact
  defect class the GP/A REVERSED fix removed; review #13). Conjunct = sign agreement. **S1″ placebo (machinery veto;
  review #9 pinned mechanics): per calendar quarter, permute the ISSUER-ASSIGNMENT of the final opportunistic event
  list among that quarter's eligible names — each event keeps its availability date (preserves the crisis-clustered
  date distribution = a fair null); routineness NOT recomputed post-shuffle; seeds 1, 2, 3** — any placebo arm clearing
  DSR>0.95 invalidates the run. **S2a** winsorized ±100% both books. **S2b** no-integrity-screen + winsorized.
  **S4** Shumway −30% on delisting-truncated exits (null must be robust; pass must survive base). REVERSED is NOT used
  (price-exogenous signal; the filing calendar cannot be reversed — the GP/A incoherence ruling applies identically).
- **Mandatory censuses:** (i) per-year event counts raw/document-filtered/opportunistic/routine-excluded + sanitizer
  drops (must reconcile to the corrected acceptance numbers above); (ii) per-year cohort sizes + blocks skipped per
  guard per arm; (iii) delisted-vs-active EVENT coverage (does the join dilute survivorship-freeness for events);
  (iv) per-year eligible counts; (v) officer/director share used vs the census's 80%; (vi) cohort-overlap/retention.

## Decision rule (committed now; coded with ALL conjuncts on the CLOSED 4-arm set)
An arm PASSES iff ALL of: diff_mean > 0 AND diff DSR > 0.95 at trials=4 AND DSR > 0.95 under the variance floor AND
S2a DSR > 0.95 AND S2b DSR > 0.95 AND S1′ sign-agreement — AND the run is valid (no placebo arm cleared). Any pass →
owner-presented promotion CANDIDATE only (paired-diff-overstates-net + the FRL capacity-null caveat for LOWLIQ arms).
Anything else → **NULL: the last credible surveyed family closes**; the measured-edge search ends at "no surveyed
family clears the honest bar at retail" pending genuinely new data classes. **Symmetric negative pre-commitment:**
significant negative (DSR>0.95 on −d, surviving S1′/S2a/S2b) is an anti-edge flag, never improvised. Partial passes
are artifact flags.

## Disclosed limits (decided now)
- Simplified CMP routineness (same-calendar-month ×3 prior years, per-issuer, purchases-only, any-owner-routine ⇒
  excluded; <3y-history insiders classified opportunistic — CMP discards them); binary 21-bar event cohort (v1).
- Window 2009→2026-01 decision blocks (burn-in + data-tail rules above); filter basis 2000–2026 (explicit).
- Price-return-only basis; CIK-join coverage ~83.5% (both books); 4/A-only transactions lost (rare).
- Best post-2016 evidence = an unreviewed MSc thesis (Wu 2025) — this run is the first refereed-grade empirical answer
  on survivorship-free data in the corpus, in either direction.
- Block machinery = the thrice-verified sibling imports; new code = event parsing + routineness + cohort formation.

## Sequencing
1. THIS revised document commits BEFORE any statistic.
2. Event-extraction pass (data-only: 80 ZIPs → per-name opportunistic event lists with availability dates; censuses
   i/iii/v printed pre-run; DD-MON-YYYY parse fixture assert).
3. Runner (imports sibling machinery) → smoke → commit pre-run → detached run → 2-lens verification (conjunct audit +
   independent re-implementation incl. ≥1 name's event list re-derived from raw TSVs) → index + ship; ledger family
   `insider-form4`.
