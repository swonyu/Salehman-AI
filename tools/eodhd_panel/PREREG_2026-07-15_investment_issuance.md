# PRE-REGISTRATION — investment/issuance FF factor legs (asset-growth CMA + net-share-issuance) LONG tilt

(written 2026-07-15, committed BEFORE any test statistic for this family. The THIRD fundamentals-side ablation,
after GP/A quality [NULL] and value B/M+E/P [NULL]. Surfaced by the 2026-07-13 completeness-critic (`wf_91d5cdeb-a9c`)
as the rank-2 gap: the investment factor (Fama-French-2015 CMA / Cooper-Gulen-Schill 2008 asset growth) and the
net-share-issuance factor (Pontiff-Woodgate 2008 / Daniel-Titman 2006) have ZERO corpus adjudication —
grep-verified — never surveyed OR ablated. Data is ALREADY on disk: `Assets` from the GP/A pull's `edgar_facts/`,
shares from the value pull's `edgar_facts_value/` — no new EDGAR fetch.)

**Honest prior + the short-leg caveat, stated up front (the completeness-critic's own disposition was "refusable-by-
analogy at survey stage"):** the economically-dominant tradable weight of BOTH anomalies is the SHORT leg — the alpha
concentrates in overpriced HIGH-asset-growth (aggressive) and HIGH-issuance firms. This ablation tests ONLY the
LONG leg (low-asset-growth conservative; low-issuance / buyback), matching the campaign's retail-occupiable constraint
(retail cannot cheaply short small-caps; the value/quality/MAX/BAB runs all tested long-only for this reason). So a
NULL is the MODAL outcome even if the factor works — the long leg is thin/weak by construction. But a measured null
> an argued-down survey-refuse, the data is free (on disk), and the runner is the twice-verified value runner with a
one-signal swap. A pass would be the campaign milestone; a null CLOSES the investment/issuance FF legs the corpus only
assumes. This is NOT a re-derivation of the value or GP/A nulls — the investment axis is a DISTINCT FF factor
(CMA/net-issuance load on neither HML nor RMW), and the LONG direction is the LOW end (cohort = BOTTOM tercile),
opposite to value/quality's top-tercile-long.

## Data (already on disk — measured 2026-07-15 before this prereg)
- Prices: the frozen survivorship-free panel `5ce314475941a0cd` (34,701 series; 5,135 clean names); GSPC.INDX master.
- Fundamentals: SEC EDGAR companyfacts (free; delisted filers persist). `Assets` (instant, us-gaap USD) from the
  GP/A pull `edgar_facts/`; shares (dei EntityCommonStockSharesOutstanding + us-gaap CommonStockSharesOutstanding)
  from the value pull `edgar_facts_value/`. Same 4,288-name CIK map, same 2010-01-04→2026-07-09 XBRL window.
- Both signals are Δ-over-consecutive-FYs, so a name needs ≥2 fiscal years of the ingredient — the eligible universe
  is smaller than the GP/A/value single-FY runs (census (iv) reports per-year eligible counts).

## Signal (mechanical, as-of; the ONLY change from the value runner — a Δ-of-consecutive-FYs)
Two signals, tested as SEPARATE arms (not blended — a blend is a post-hoc DoF):
- **AG (asset growth) = Assets(FY_t) / Assets(FY_{t-1}) − 1.** Cohort = **BOTTOM tercile AG long** (conservative /
  low-investment = the CMA long leg). FY_{t-1} = the most recent prior FY-end strictly before FY_t (both from the same
  name's Assets series). Assets(FY) > 0 required for both years.
- **ISS (net-share-issuance) = sharesAdj(FY_t) / sharesAdj(FY_{t-1}) − 1.** Cohort = **BOTTOM tercile ISS long**
  (buyback / low-issuance = the long leg). **CRITICAL — SPLIT-ADJUSTMENT (inherited FIX A):** raw EDGAR shares are
  un-split-adjusted, so a 7:1 split would fake a +600% "issuance." `sharesAdj(FY) = rawShares(FY) × split_factor_after
  (splits, FY-end)` puts BOTH years on today's backward-adjusted basis; the ratio of two sharesAdj values is then
  split-neutral (the today-basis factor cancels). Shares source + disambiguation: the value runner's FIX-B rule
  (prefer dei within [end,end+45d]; us-gaap fallback; drop same-end us-gaap disagreements >2×). NI-negative not
  relevant here.
- **FY identity, availability, freshness: IDENTICAL to the value prereg.** FY keyed by each Assets/shares fact's own
  period-END date (never EDGAR fy/fp); instant facts at the period-end; **availability = first master bar STRICTLY
  AFTER max(`filed`) JOINTLY over BOTH years' ingredient records actually used** (FIX C — the Δ needs both FYs public);
  freshness = most-recent usable FY_t whose max-filed ≤ trailing 378 bars.
- **FIX 1 (design-review Surface 1 — NULL-manufacturing pairing guard, applied pre-commit):** a Δ is an ANNUAL growth
  ONLY if the two FY-ends are ~1 year apart. `FY_{t-1}` = the most recent prior FY-end with `end_t − end_{t-1} ∈
  [340, 380] days` (the same window the duration-fact guard uses). A skipped year (2013→2016 = a 2-year growth) or a
  fiscal-year-change stub (Dec→Jun = a 6-month growth) mislabeled as annual would scatter names to the tercile extremes
  on a wrong basis → dilute any real spread toward null (the same class FIX A killed on the price side). Non-annual
  pairs are DROPPED and counted (census vi). A selfcheck asserts a 2-year-gap pair and a 6-month-stub pair produce NO
  event.
- **PRICE-EXOGENOUS SIGNAL PATH (design-review Surface 3 downstream — applied pre-commit):** AG and ISS are computed
  from Assets/shares ONLY — no price. The runner feeds the precomputed `−AG`/`−ISS` scalar through a DEDICATED
  `_invest_run_leg` (`sig[code] = scalar` directly), NOT the value runner's `run_leg`/`placebo_scalar` which divide by
  price (`num/(px·sh)`) and would re-introduce the `1/price` residual that fired the value placebo at DSR 1.000. A
  pass-blocking price-invariance selfcheck asserts the signal scalar has no price dependence. (This is why the value
  run's price-leak CANNOT arise here — the signal never touches price.)
- Signal is NOT price-dependent (AG and ISS use only balance-sheet/share counts), so — UNLIKE the value ratios — the
  price-leak the value placebo exposed CANNOT arise here; the price-exogenous placebo (shuffle the finished signal
  across names) is the correct null, and a walk-backward/lag-robustness leg is the coherent leak test (S1′).

## Books, scopes, arms — INHERITED from the value/GP-A machinery
- Panel-freeze filters + integrity screen (oscillation clause); valid-print participation; entry open[p+1]; exit last
  valid print ≤ p+1+H (death-blocks BOOKED, truncations counted). Warmup NOT inherited (signal needs no price history).
- Eligibility at p: valid entry print AND a fresh AG-or-ISS signal (per arm) AND ≥1 dv print in [p−62..p]. ONE EQW
  book per (scope,H) over ALL eligible names; the paired diff isolates the tilt WITHIN the covered universe.
- Cohort: **BOTTOM tercile by the arm's signal, long** (low AG / low ISS = the published long direction), terciled
  within the scope's eligible set at each rebalance.
- Scopes: FULL; LOW-LIQUIDITY (as-of trailing-63-bar median dollar-volume bottom tercile).
- Horizons H ∈ {63, 126, 252}; blocks stepped by H; <30-eligible blocks skipped and COUNTED. Δ-signal + 2-FY
  requirement means coverage ramps slower than the single-FY runs — H252 arms UNDERPOWERED by construction, kept in
  the closed set with this caveat on record.
- **Decision arms = 2 signals × 3 H × 2 scopes = 12.** Costs 13/60bps by scope, levels only (cost cancels in the
  paired diff; the investment/issuance signals turn over ~annually — cost second-order).

## Statistics — INHERITED
- Per arm: paired block diff d = COHORT − EQW; mean, t; DSR (`StockSageDeflatedSharpe` port, bit-verified); GROSS
  t/DSR for cohort and EQW books reported.
- **Trials = 12 (this run) + 0 prior EMPIRICAL investment/issuance-family arms (ledger census: zero
  `investment`/`issuance`/`asset-growth` records — VERIFIED before this prereg) = 12 primary.** Registry-informed
  print at 12 + (current ledger line count) for cross-family deflation (over-deflates vs deduped = safe). varTrialSharpe
  = sample variance of the 12 arm Sharpes, floored at 0.0343 (sibling floor), floor BINDING on any would-be pass.
- Sensitivity legs (VETO/context-only, NEVER a qualifier):
  **S1′ lag-robustness (pass conjunct):** availability delayed +126 master bars; conjunct = sign(lagged diff_mean) ==
  sign(diff_mean). A genuine multi-year investment premium survives 6 months of extra lag; an as-of leak does not.
  **S1″ placebo (machinery veto):** the finished AG/ISS signal shuffled cross-sectionally at each rebalance, 3 seeds
  (1,2,3); if ANY placebo arm clears DSR>0.95 the run is INVALID. (The signal is price-EXOGENOUS, so a single
  scalar-shuffle IS a true null here — the value run's price-leak cannot occur; only ONE placebo needed, but a second
  returns-shuffle placebo S1‴ is included as a confirming guard, matching the value runner.)
  **S2a** winsorized ±100% both books. **S2b** no-integrity-screen + winsorized. **S4** Shumway −30% on
  delisting-truncated exits. **S5** freshness relaxed to 504 bars — context, never qualifying.
- **Mandatory censuses:** (i) staleness-excised names still showing valid prints + how many die in-window;
  (ii) shares-staleness distribution (the split-adjusted-shares channel); (iii) usable-rate split DELISTED vs ACTIVE;
  (iv) per-year eligible counts (the 2-FY requirement's ramp); (v) AG and ISS cross-sectional distribution per year
  (sanity: not degenerate); (vi) count of names with only 1 FY (ineligible for the Δ) — the coverage cost of the Δ.

## Decision rule (committed now; coded with ALL conjuncts on the CLOSED 12-arm set)
An arm PASSES iff ALL of: diff_mean > 0 (LOW-tercile-long premium is POSITIVE for the cohort vs EQW) AND diff DSR >
0.95 at trials=12 AND DSR > 0.95 under the variance floor AND S2a DSR > 0.95 AND S2b DSR > 0.95 AND S1′ sign-agreement
— AND the run is valid (NEITHER placebo cleared). Any pass → owner-presented promotion CANDIDATE only (with the
paired-diff-overstates-real-net disclosure). Anything else → **NULL on the 2010-2026 XBRL-era survivorship-free
(retail-inclusive) population — the LONG leg of the investment/issuance FF factors (the thin leg by construction; the
alpha is short-concentrated); the factor ASSUMPTION becomes a long-leg MEASUREMENT, NOT a refutation of the academic
factor.** **Symmetric negative pre-commitment:** a paired diff significantly NEGATIVE (DSR>0.95 on −d, surviving
S1′/S2a/S2b) is reported as an anti-edge flag (would mean HIGH-investment/HIGH-issuance names OUTperformed the low —
the opposite of the published sign), never improvised. Partial passes are beta/artifact flags, never findings.

## Disclosed limits (decided now, before results)
- 2010-2026 window only (XBRL); the investment premium is regime-dependent (strongest around the dot-com/2000s
  aggressive-investment episodes largely outside this window) — a null does NOT refute the academic factor.
- LONG-LEG ONLY — the tradable alpha of both factors is short-concentrated; the long leg is thin/weak, so a null is
  the modal outcome (stated up front, not post-hoc).
- d = cohort − EQW is a LOWER BOUND on the long-leg premium (EQW already contains ~1/3 cohort; conservative, toward null).
- 2-FY Δ requirement shrinks the eligible universe vs the single-FY GP/A/value runs (census vi).
- Price-return-only basis; cost approximately (not exactly) cancels in the diff (residual OVERSTATES net, largest in
  LOWLIQ/60bps, bounded small by ~annual turnover — the value prereg's FIX-F.2 disclosure applies identically).
- Block machinery = the twice-verified sibling code (imported; fixes propagate).

## Sequencing
1. THIS document commits BEFORE any statistic (data is already on disk — no pull).
2. Runner = extend `value_factor.py`'s machinery with the Δ-signal (`build_invest_events`: consecutive-FY Assets ratio
   for AG; consecutive-FY sharesAdj ratio for ISS; BOTTOM-tercile cohort). A PASS-BLOCKING selfcheck reproduces one
   name-date AG and ISS from raw consecutive-FY facts + splits (asserts a splitting name does NOT read as a high
   issuer). Detached run → 2-lens verification (conjunct audit vs THIS document + independent re-implementation of ≥1
   arm incl. one name-date AG/ISS from raw companyfacts) → index + ship; ledger family `investment-issuance` (+12 arms).
