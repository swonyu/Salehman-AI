# PRE-REGISTRATION — gross profitability (GP/A) LONG tilt on the survivorship-free panel, EDGAR-fundamentals era
(written 2026-07-10 ~17:50; revised ~18:15 after adversarial design review — verdict COMMIT-WITH-FIXES, BOTH blockers +
all should-fixes + all notes applied; committed BEFORE any test statistic was computed for this family. The first
fundamentals-side ablation in project history — the campaign-milestone row's LAST surveyed named shot.)

**Why this test:** the 2026-07-09 non-price survey found quality the ONLY family with genuine published long-leg alpha
(Novy-Marx 2013: long-quintile FF3 +0.34%/mo t=5.01) AND retail cost-immunity (~once-per-4y turnover), but current-era
MEASURED ≈null on large caps (QMJ post-2013 t=1.01; QUAL lost SPY) → "low-priority incremental GP/A candidate ONLY".
The open question is exactly this panel's population: small/retail names WITH their casualties, current era. Expected
size honestly stated up front: ~0.5–1%/yr pre-haircut — an order of magnitude under the DSR bar; a NULL closes the last
surveyed shot and is a win. **Review-noted hazard, owned:** the two design blockers found pre-commit (FY-keying
contamination; a REVERSED conjunct that mechanically vetoes any pass for a price-exogenous signal) were both
NULL-manufacturing defects — the fixes below exist so a null, if it comes, is real.

## Data (acceptance-measured 2026-07-10 before this prereg)
- Prices: the frozen survivorship-free panel `5ce314475941a0cd`; master calendar GSPC.INDX.
- Fundamentals: SEC EDGAR companyfacts (free; delisted filers persist — probe-verified on DRYS). EODHD fundamentals are
  PLAN-GATED on the owner's $29.99 All World Extended subscription (403 measured incl. AAPL; that tier adds intraday,
  not fundamentals) — the $59.99 Fundamentals package would extend the window to pre-XBRL years and remains an owner
  option, NOT required for this test.
- Ticker→CIK map (committed artifact `edgar_cik_map.json`): 4,288/5,135 clean names (83.5%) — 2,644 exact-ticker vs
  current registrants + 1,644 conservative normalized-name matches (595 ambiguous names DROPPED, never guessed);
  847 unmapped (non-random: renamed/foreign/older entities — disclosed; both books draw only from the covered universe).
- Coverage census (n=120 deterministic stride): companyfacts present 88%; GP/A-usable 54% — a FLOOR for the pinned
  extraction (the census script's tag list predates the review-#7 additions; reconciliation line mandatory in the
  results artifact). The unusable share is substantially FINANCIALS (no COGS/GrossProfit) — matching the literature's
  standard financials exclusion for this factor. Median usable FY span 2011–2025 → **window 2010-01-04 → 2026-07-09**
  (XBRL era; pre-2010 casualties excluded — disclosed; the era matches the survey's open "current era" question).
- Extraction pull: `edgar_pull_gpa.py` (review-#7 tag lists), wiped + re-pulled after the review's tag additions
  (decided pre-commit: full re-pull, no mixed-tag-vintage files). Amendments (10-K/A, 20-F/A, 40-F/A) PARTICIPATE in
  the pool (review #4) — where the original predates XBRL, the /A carries the first machine-readable record with its
  own later filed date; where the earliest XBRL record is a later filing's comparative, the value is
  restated-not-as-originally-reported — accepted, direction-neutral, disclosed.

## Signal (mechanical, as-of; REVIEW-#1 FY-KEYING — the load-bearing fix)
- **FY identity = the FACT's own fiscal period, keyed by its period END date — never EDGAR's `fy`/`fp` fields, which
  describe the FILING and lump 2–3 comparative years together.** Duration facts (GrossProfit, Revenues, COGS) qualify
  only if `end − start` ∈ [340, 380] days (drops quarterly comparatives and transition stubs). Assets = the INSTANT
  fact whose `end` equals that same period-end date. "Same FY" = same end date; "most recent available FY" = latest
  end date. Earliest-filed dedup is per (name, end-date, tag).
- **GP/A(FY) = GrossProfit(FY) / Assets(FY-end)**, annual forms (10-K/20-F/40-F + their /A), USD units only
  (review #14: excludes foreign-currency 20-F filers although the ratio is unit-invariant — considered, accepted
  inside the disclosed domestic-filer bias). Assets > 0 required; negative GrossProfit permitted (per the literature).
- GrossProfit: direct `GrossProfit` tag for that period-end if present; else Revenues − COGS with pinned tag priority
  (Revenues: `Revenues` > `RevenueFromContractWithCustomerExcludingAssessedTax` >
  `RevenueFromContractWithCustomerIncludingAssessedTax` > `SalesRevenueNet` > `SalesRevenueGoodsNet` >
  `SalesRevenueServicesNet`; COGS: `CostOfGoodsAndServicesSold` > `CostOfRevenue` > `CostOfGoodsSold` >
  `CostOfServices`); both ingredients from the SAME period-end.
- **Availability (review #3): the signal for a FY becomes available the first master bar STRICTLY AFTER
  max(`filed`) over ALL ingredient records actually used** for that FY's value. (Review #10: EDGAR assigns post-5:30pm
  acceptances the next business day's filing date, so `filed` is never earlier than public availability — "strictly
  after" is verified conservative, including non-NYSE-day filings.)
- **Freshness: at rebalance p the signal uses the most recent available FY whose max-filed date is within the trailing
  378 master bars (= 252×1.5 ≈ 18 months)**; staler names are ineligible at p. Note (review #10): anchoring freshness
  on filed (not FY-end) admits data up to ~21–22 months past FY-end for slow filers vs the Fama-French ~18-month
  convention — disclosed, not decision-material.

## Books, scopes, arms
- Panel-freeze filters + integrity screen as implemented in the twice-audited sibling machinery (oscillation clause
  pinned: ≥1 up-ratio>5 AND ≥1 down-ratio<1/5 within |Δposition| ≤ 20); valid-print participation; raw-open presence
  mask; entry open[p+1]; exit = last valid raw-open print ≤ p+1+H (death-blocks BOOKED, truncations counted/classified).
- **Warmup deliberately NOT inherited from the siblings** (review #13): the signal needs no price history, so recent
  IPOs with a valid entry print are eligible — the EQW book here is NOT population-comparable across the three preregs.
- Eligibility at rebalance p: valid entry print AND a fresh GP/A signal AND ≥1 dv print in **[p−62..p] inclusive
  (63 bars, as implemented in the sibling)** (review #11). ONE EQW book per (scope,H) over ALL eligible names —
  coverage exclusion is book-symmetric; the paired diff isolates the tilt WITHIN the covered universe.
- Cohort: **TOP tercile by GP/A long** (the published direction), terciled within the scope's eligible set at each
  rebalance. Scopes: FULL; LOW-LIQUIDITY as-of trailing-63-bar median dollar-volume tercile (liquidity-proxy labeling).
- Horizons H ∈ {63, 126, 252}; blocks stepped by H from the window start; <30-eligible blocks skipped and COUNTED
  (coverage ramps 2010→2012 — early skips expected and printed). **Pre-registered expected block counts (review #9):
  H63 ≈ 66, H126 ≈ 33, H252 ≈ 14–16 after ramp skips — the H252 arms are UNDERPOWERED by construction; kept in the
  closed set (a fail is a fail) with this caveat on record before any result exists.**
- Decision arms = 3 H × 2 scopes = **6**. Costs 13/60bps by scope, levels only (cost cancels in the paired diff;
  quality's ~annual turnover makes cost second-order regardless — stated).

## Statistics
- Per arm: paired block diff d = COHORT − EQW; mean, t; DSR (`StockSageDeflatedSharpe` port, twice bit-verified);
  **GROSS t/DSR computed and reported for the cohort and EQW books** (closing the reversal run's F2 under-delivery —
  every quoted number carries significance or is not quoted).
- **Trials = 6 (this run) + 0 prior EMPIRICAL family arms (ledger census: zero `gpa`/`quality` records) = 6 primary.**
  Acknowledged (review #8): the 07-09 survey COMPUTED family statistics pre-selection (QMJ post-2013 re-derivation,
  QUAL-vs-SPY; `research/quality_family_computed_2026-07-09.csv`) — verification re-derivations that observed a null,
  not selection arms; counting them (≈+4) moves the bench immaterially and is covered by the registry print.
  Registry-informed print at 6 + 743 (ledger line count; over-deflates vs the deduped census = safe direction, per the
  registry's own caveat) = 749. varTrialSharpe = sample variance of the 6 arm Sharpes, **floored at 0.0343, floor
  BINDING on any would-be pass**.
- Sensitivity legs (VETO-only; REVIEW-#2 — S1 REVERSED is REPLACED for this family):
  **S1′ (pass conjunct) lag-robustness:** re-run with availability delayed +126 master bars (~6 extra months);
  conjunct = sign(lagged diff_mean) == sign(diff_mean). A genuine multi-year quality premium survives 6 months of
  extra lag; an as-of leak or announcement-window artifact does not. (Walk-backward is INCOHERENT here: GP/A cohorts
  are price-independent, so price reversal ≈ negates every diff mechanically and the old conjunct could never pass —
  a null-manufacturing defect, removed.)
  **S1″ (machinery veto, never a qualifier) placebo:** GP/A values shuffled cross-sectionally at each rebalance,
  3 shuffles with pinned seeds (1, 2, 3); if ANY placebo arm clears DSR > 0.95 the run is INVALID (machinery leak).
  **S2a** winsorized ±100% both books. **S2b** no-integrity-screen + winsorized (post-fix semantics).
  **S4** Shumway −30% on delisting-truncated exits (a would-be NULL must be robust to it; a would-be pass must survive
  the base treatment). **S5 (context/veto only, review #5):** freshness relaxed to 504 bars (~24 months) — reported,
  never qualifying.
- **Mandatory censuses in the results artifact (reviews #5, #6, #12):** (i) per-arm count of names dropped by
  staleness while still showing valid prints, and how many of those subsequently die in-window (the freshness rule
  excises the delinquent-filer pre-death window — a NULL-direction channel, disclosed); (ii) count of mapped names
  with Assets-but-no-revenue-tags (the amputated low-GP/A left tail — a second NULL-direction channel); (iii) usable
  rate split DELISTED vs ACTIVE (dilution check on the survivorship-free headline at the join); (iv) per-year eligible
  counts; (v) pinned-tags vs census-tags reconciliation (the 54% figure is a floor).

## Decision rule (committed now; coded with ALL conjuncts on the CLOSED 6-arm set)
An arm PASSES iff ALL of: diff_mean > 0 (published direction) AND diff DSR > 0.95 at trials=6 AND DSR > 0.95 under the
variance floor AND S2a DSR > 0.95 AND S2b DSR > 0.95 AND S1′ sign-agreement — AND the run is valid (no S1″ placebo arm
cleared). Any pass → owner-presented promotion CANDIDATE only (with the paired-diff-overstates-real-net disclosure).
Anything else → **NULL: the campaign-milestone row's LAST surveyed named shot closes**; the quality family's
current-era ≈null extends to the small/retail survivorship-free population. **Symmetric negative pre-commitment:** a
paired diff significantly NEGATIVE (DSR > 0.95 on −d at trials=6, surviving S1′/S2a/S2b) is reported as an anti-edge
flag, never improvised. Partial passes are beta/artifact flags, never findings.

## Disclosed limits (decided now, before results)
- 2010–2026 window only (XBRL); pre-2010 casualties absent; single source (EDGAR).
- Coverage: 83.5% mapped × ≥54% usable ⇒ ~2,300+-name expected universe; the covered universe over-represents
  domestic SEC filers with standard tagging; financials effectively excluded by construction (literature-consistent).
- **Two named NULL-direction channels (review #5/#6), censused not hand-waved:** staleness excision of delinquent
  filers' pre-death window; revenue-tag amputation of the low-GP/A left tail.
- Price-return-only basis (panel-wide); dividends favor high-profitability payers → the LONG-tilt diff carries a known
  CONSERVATIVE-direction bias (understates quality) — stated.
- Block machinery = the twice-verified sibling code (imported; fixes propagate).

## Sequencing
1. THIS revised document commits BEFORE any statistic (review fixes applied pre-commit; the running pull is data
   acquisition only).
2. Pull completes → coverage reconciliation print (censuses i–v above; still no test statistic).
3. Runner extends the verified sibling machinery → detached run → 2-lens verification (conjunct audit vs THIS document
   + independent re-implementation of ≥1 arm incl. one name-date signal reproduced from raw companyfacts records) →
   index + ship; ledger family `gpa-quality` (+6 arms).
