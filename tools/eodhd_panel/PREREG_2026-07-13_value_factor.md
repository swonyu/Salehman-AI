# PRE-REGISTRATION — VALUE-factor (book-to-market / earnings-yield) LONG tilt on the survivorship-free panel

(written 2026-07-13, committed BEFORE any test statistic for this family. The SECOND fundamentals-side ablation in
project history and the FIRST price/fundamentals-ratio ablation. Surfaced by the 2026-07-13 completeness-critic
workflow `wf_91d5cdeb-a9c` as the single largest genuinely-unclosed hole in the campaign's "edge-search exhausted"
claim: `grep -riE 'value factor|value premium|book-to-market|HML|earnings yield|Fama.French'` over
research/INDEX.md + all RESEARCH_*.md returns ZERO genuine adjudications — value was ASSUMED priced-in as the
"incremental-to price/size/value/momentum" baseline, never measured on the frozen panel.)

**Why this test — and why it is NOT a re-derivation of the GP/A null.** The corpus measured PROFITABILITY (GP/A,
Novy-Marx quality) → NULL at DSR 0.326. Value is a DISTINCT FF factor: it loads OPPOSITE to profitability
(HML vs RMW; a cheap stock is often a low-profitability one) and, decisively, its denominator is PRICE (market cap),
not a balance-sheet item — so its economically-tradable weight lives in the LONG leg (cheap stocks are
retail-occupiable), unlike short-interest/13F/issuance whose alpha is short-concentrated and hits the corpus's
short-leg wall. That distinctness is exactly what makes value worth a run rather than a refuse-by-analogy.

**Honest prior, stated up front (before any statistic).** A DSR>0.95 pass is UNLIKELY: (a) the corpus's generic
fundamentals-decay pattern — GP/A NULL at 0.326, every price family NULL at full survivorship-free breadth; (b)
McLean-Pontiff 58% post-publication haircut; (c) value's own documented 2010s "drought" (HML ~flat-to-negative
2010–2020, the exact XBRL window this panel covers). BUT "unlikely" is not "already measured null" — value has never
been argued down even at survey stage in this corpus, and a NULL here legitimately CLOSES the value leg of the FF
factor space the corpus currently only assumes. Either result is durable: a pass is the campaign milestone; a null
converts an assumption into a measurement.

## Data (acceptance-measured 2026-07-13 before this prereg)
- Prices: the frozen survivorship-free panel `5ce314475941a0cd` (34,701 series, raw close×splits, vendor
  adjusted_close never consumed); master calendar GSPC.INDX. IDENTICAL substrate to the GP/A / reversal / small-cap
  siblings (5,135 clean names after the panel-freeze + integrity screen).
- Fundamentals: SEC EDGAR companyfacts (free; delisted filers persist — probe-verified). SAME ticker→CIK map as the
  GP/A run (`edgar_cik_map.json`, 4,288/5,135 mapped = 83.5%; 595 ambiguous names DROPPED, never guessed; 847 unmapped
  non-random: renamed/foreign/older — disclosed; both books draw only from the covered universe).
- Value-tag pull: `edgar_pull_value.py` (this session), a sibling of `edgar_pull_gpa.py` writing to a SEPARATE
  `edgar_facts_value/` dir (does NOT touch the GP/A extracts). Tags: `StockholdersEquity` (book value, us-gaap USD
  instant; fallback `StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest`, priority-pinned);
  `NetIncomeLoss` (earnings, us-gaap USD duration); shares outstanding from BOTH `dei/EntityCommonStockSharesOutstanding`
  and us-gaap `CommonStockSharesOutstanding` (`shares` unit, instant). Annual forms only (10-K/20-F/40-F + /A), FY only,
  every filed occurrence kept (runner applies earliest-filed-per-FY as-of).
- Window 2010-01-04 → 2026-07-09 (XBRL era; pre-2010 casualties absent — disclosed, matches the GP/A window and the
  survey's "current era" question). Financials NOT excluded by construction here (unlike GP/A, book value/net income
  ARE defined for banks) — but banks' book-to-market means something different; a financials-excluded sensitivity leg
  is included (S6, veto/context only).

## Signal (mechanical, as-of — the ONLY substantive change from the GP/A prereg)
Two value ratios, tested as SEPARATE arms (not blended — a blend is a post-hoc DoF):
- **B/M = StockholdersEquity(FY) / MarketCap(p)**. Cohort = TOP tercile B/M (cheap = high book-to-market = the published
  long direction).
- **E/P = NetIncomeLoss(FY) / MarketCap(p)** (earnings-yield). Cohort = TOP tercile E/P. Names with
  NetIncomeLoss ≤ 0 are ELIGIBLE but fall to the bottom of the E/P sort (a loss-making firm is not "cheap on
  earnings"); disclosed — this matches the standard earnings-yield construction that does not drop negative earners
  but ranks them low. (A negative-E/P-excluded sensitivity is S7, veto/context only.)
- **FIX A (design-review BLOCKER — the load-bearing MarketCap-basis gate; resolves the NULL-manufacturing AND leak
  readings, which are ONE defect with two directions):** the inherited sibling machinery (`smallcap_maxbabivol.prep_name`)
  retains ONLY the backward-split-ADJUSTED close (`nm["close"]` = adjClose; no raw-close array, volume discarded), while
  EDGAR shares are RAW as-reported counts (AAPL FY2013 ≈ 900M shares, PRE the 2014 7:1 + 2020 4:1 splits — measured).
  Naively `adjClose × rawShares` mis-scales MarketCap by each name's future-split factor (28× for AAPL 2013), which
  (a) injects split-noise orthogonal to value → dilutes any real spread toward null AND (b) makes the cohort load on
  future-forward-splitters (winners) / expel reverse-splitters (losers) → a spurious positive forward diff that can
  fake DSR>0.95. RULE, pinned: **MarketCap(p) = adjClose(p) × sharesAdj(FY, p)**, where `adjClose(p) = nm["close"][p]`
  (the ONLY per-bar price the machinery retains) and `sharesAdj(FY, p)` = the raw as-of shares put onto the SAME
  backward-split-adjusted per-share basis as `adjClose`, by dividing raw shares by the cumulative split factor for the
  name's splits with **date ≤ p** (re-derivable from the splits list `adjust()` already returns). **No split with
  date > p may enter any cap.** `nm["close"]`(=adjClose) is used for the price; a raw-close array is NOT needed once
  shares are moved onto the adjusted basis. A **PASS-BLOCKING selfcheck** in `value_factor.py` reproduces one name-date
  B/M for a known splitter (AAPL FY2013) from (adjClose, name splits, raw shares, equity) and asserts it equals the
  machinery-computed value to 1e-9 AND that AAPL 2013 does NOT land in the cheap tercile — the run aborts if this fails.
- **FIX B (design-review SHOULD_FIX — shares source disambiguation):** 26% of names carry DIFFERENT us-gaap
  `CommonStockSharesOutstanding` values at the SAME period-end (share-class members / post-split restated comparatives —
  AAPL 2013-09-28 shows both 899,213,000 total AND 6,294,494,000 under one tag; measured). The `(end,tag)` earliest-filed
  dedup would pick arbitrarily. RULE, pinned: **prefer `dei/EntityCommonStockSharesOutstanding` (cover-page total)** as
  the primary shares source; use us-gaap `CommonStockSharesOutstanding` ONLY when dei is absent; when multiple us-gaap
  values share a period-end, take the **MAX** (total-company, not a class/restated breakout) or drop the name as
  ambiguous and census it. Census (ii) extended: dei-vs-us-gaap resolution counts + same-end us-gaap disagreement count.
- **FIX C (design-review SHOULD_FIX — joint availability across FYs):** book value + shares + net income may come from
  different FYs; availability must not use a shares count before it was public. RULE, pinned: **availability(p) = first
  master bar STRICTLY AFTER max(`filed`) taken JOINTLY over the EXACT StockholdersEquity, shares, and NetIncomeLoss
  records actually used** for that arm's ratio (even when shares come from a later FY than equity). Selfcheck fixture:
  shares from a later, later-filed FY → assert availability tracks the shares filed date, not the equity filed date.
- **FY identity, freshness: IDENTICAL to the GP/A prereg** (FY keyed by each fact's own period-END date, NOT EDGAR
  `fy`/`fp`; duration facts need end−start ∈ [340,380] days; instant facts — equity, shares — at the same period-end;
  freshness = most-recent FY whose max-filed ≤ trailing 378 bars).

## Books, scopes, arms — INHERITED from the GP/A machinery
- Panel-freeze filters + integrity screen (oscillation clause: ≥1 up-ratio>5 AND ≥1 down-ratio<1/5 within
  |Δposition| ≤ 20); valid-print participation; raw-open presence mask; entry open[p+1]; exit = last valid raw-open
  print ≤ p+1+H (death-blocks BOOKED, truncations counted/classified). SAME twice-audited sibling block machinery.
- Warmup NOT inherited (signal needs no price history; recent IPOs with a valid entry print are eligible).
- Eligibility at p: valid entry print AND a fresh value signal (B/M or E/P per arm) AND ≥1 dv print in [p−62..p]
  (63 bars). ONE EQW book per (scope,H) over ALL eligible names — coverage exclusion is book-symmetric; the paired
  diff isolates the tilt WITHIN the covered universe.
- Cohort: TOP tercile by the arm's ratio, long, terciled within the scope's eligible set at each rebalance.
- Scopes: FULL; LOW-LIQUIDITY (as-of trailing-63-bar median dollar-volume bottom tercile).
- Horizons H ∈ {63, 126, 252}; blocks stepped by H from window start; <30-eligible blocks skipped and COUNTED.
  Pre-registered expected block counts (coverage ramps 2010→2012): H63 ≈ 66, H126 ≈ 33, H252 ≈ 14–16 — the H252 arms
  are UNDERPOWERED by construction; kept in the closed set (a fail is a fail) with this caveat on record.
- **Decision arms = 2 signals × 3 H × 2 scopes = 12.** Costs 13/60bps by scope, levels only (cost cancels in the
  paired diff; value's ~annual turnover makes cost second-order regardless).

## Statistics — INHERITED
- Per arm: paired block diff d = COHORT − EQW; mean, t; DSR (`StockSageDeflatedSharpe` port, bit-verified); GROSS
  t/DSR for cohort and EQW books reported (every quoted number carries significance or is not quoted).
- **Trials = 12 (this run) + 0 prior EMPIRICAL value-family arms (ledger census: zero `value`/`book-to-market`
  records — VERIFIED before this prereg) = 12 primary.** Registry-informed print at 12 + (current ledger line count)
  for the cross-family deflation context (over-deflates vs deduped census = safe direction). varTrialSharpe = sample
  variance of the 12 arm Sharpes, floored at 0.0343 (the sibling floor), floor BINDING on any would-be pass.
- Sensitivity legs (VETO/context-only, NEVER a qualifier):
  **S1′ lag-robustness (pass conjunct):** re-run with availability delayed +126 master bars; conjunct =
  sign(lagged diff_mean) == sign(diff_mean). A genuine multi-year value premium survives 6 months of extra lag; an
  as-of leak does not. (S1 REVERSED is INCOHERENT and REPLACED — value cohorts depend on price via MarketCap, so a
  reversed-price panel does NOT mechanically negate the diff the way a price-exogenous signal would; but the reversed
  construction still tangles the market-cap denominator with the reversed returns, making it uninterpretable — so
  lag-robustness is the coherent leak test, matching the GP/A ruling.)
  **S1″ placebo (machinery veto):** value ratios shuffled cross-sectionally at each rebalance, 3 seeds (1,2,3); if ANY
  placebo arm clears DSR>0.95 the run is INVALID (machinery leak).
  **S1‴ placebo (FIX D — design-review SHOULD_FIX; the price-leak detector S1″ is blind to):** shuffle only
  `shares_asof` (or Equity) across names and RE-DERIVE the ratio per name from THAT name's own as-of price path — so a
  residual price-based leak WOULD fire it (S1″ shuffles the finished scalar, carrying any price contamination WITH it,
  so it cannot detect a price leak). 3 seeds; if ANY S1‴ arm clears DSR>0.95 the run is INVALID. With FIX A applied
  the price leak is gone at source, so S1‴ is a confirming guard; committed before results regardless.
  **S2a** winsorized ±100% both books. **S2b** no-integrity-screen + winsorized.
  **S4** Shumway −30% on delisting-truncated exits.
  **S5** freshness relaxed to 504 bars (~24 months) — context, never qualifying.
  **S6** financials-excluded (SIC 6000–6799 via the EDGAR SIC where available; else the standard bank-tag heuristic) —
  context, never qualifying (bank book-to-market is a different construct).
  **S7 (E/P arms only)** negative-net-income names excluded from the cross-section — context, never qualifying.
- **Mandatory censuses in the results artifact:** (i) staleness-excised names still showing valid prints + how many
  die in-window (delinquent-filer pre-death excision, a NULL-direction channel); (ii) shares-outstanding staleness
  distribution (bars since the as-of shares FY-end) — the NEW price-denominator channel; (iii) usable rate split
  DELISTED vs ACTIVE (survivorship dilution check at the join); (iv) per-year eligible counts; (v) B/M and E/P
  cross-sectional distribution per year (a sanity check the ratios are economically plausible, not degenerate); (vi)
  count of negative-book-value and negative-net-income names per arm (the value-factor's known distress tail).

## Decision rule (committed now; coded with ALL conjuncts on the CLOSED 12-arm set)
An arm PASSES iff ALL of: diff_mean > 0 (published long direction) AND diff DSR > 0.95 at trials=12 AND DSR > 0.95
under the variance floor AND S2a DSR > 0.95 AND S2b DSR > 0.95 AND S1′ sign-agreement — AND the run is valid (NEITHER S1″ NOR
S1‴ placebo arm cleared). Any pass → owner-presented promotion CANDIDATE only (with the paired-diff-overstates-real-net
disclosure). Anything else → **FIX E (design-review SHOULD_FIX — scope the null): NULL on the 2010-2026 XBRL-era
survivorship-free (retail-inclusive) population — value's documented DROUGHT decade; the value-premium ASSUMPTION
becomes a MEASUREMENT on THIS era/population, NOT a refutation of the academic value premium.** (The verdict string
printed by the runner + the research/INDEX line must carry this scope inline — a null here does not license "value
does not work.")
**Symmetric negative pre-commitment:** a paired diff significantly NEGATIVE (DSR>0.95 on −d at trials=12, surviving
S1′/S2a/S2b) is reported as an anti-edge flag, never improvised. Partial passes are beta/artifact flags, never
findings.

## Disclosed limits (decided now, before results)
- 2010–2026 window only (XBRL) — and this window is value's documented DROUGHT decade, so a null here does NOT disprove
  the academic value premium; it measures value on THIS population and era (the honest scope of the corpus claim).
- Coverage: 83.5% mapped × usable rate (measured post-pull) ⇒ the covered universe over-represents domestic SEC filers.
- Price-return-only basis (panel-wide); dividends favor value payers → the LONG value-tilt diff carries a
  CONSERVATIVE-direction bias (understates value) — stated, same direction as the GP/A dividend caveat.
- NEW: market-cap denominator introduces a stale-shares channel (censused, ii) the price-exogenous GP/A run did not have.
- **FIX F.1 (design-review NOTE):** the EQW book already contains ~1/3 cohort names, so d = cohort − EQW is a LOWER
  BOUND on the value-premium long leg (conservative, toward null); a null on d bounds the tercile-over-blended-baseline
  spread, NOT the academic HML-long premium.
- **FIX F.2 (design-review NOTE):** cost APPROXIMATELY cancels in the paired diff; the residual = (cohort − EQW)
  turnover × cost, direction OVERSTATES net (largest in LOWLIQ/60bps), bounded small by value's ~annual turnover —
  captured by the mandatory paired-diff-overstates-real-net promotion disclosure. (The gross, cost-free diff
  computation stays as inherited from the sibling machinery.)
- Block machinery = the twice-verified sibling code (imported; fixes propagate).

## Design review (3-lens Opus red-team + adjudication, `wf_00ad60b4-3ab`, BEFORE any statistic)
Verdict **COMMIT-WITH-FIXES** (mirroring the GP/A review's own resolution). 2 BLOCKERS — both ONE root cause (the
MarketCap-basis mix of adjusted price × raw shares, empirically confirmed 28× off for AAPL 2013 in both the
null-manufacturing AND leak directions) → **FIX A**. 3 SHOULD_FIX (shares disambiguation **FIX B**, joint availability
**FIX C**, price-leak placebo **FIX D**). 2 NOTE (verdict scoping **FIX E** — promoted to a hard string requirement;
disclosure lines **FIX F**). CONFIRMED SOUND (no change): E/P negative-earnings bottom-ranking, TOP-tercile-LONG
direction for both ratios, negative-equity handling — the runner selfcheck asserts a negative-NI name lands OUTSIDE
the E/P top tercile and a negative-equity name OUTSIDE the B/M top tercile, locking the confirmed behavior. All A–F
applied to THIS document before commit; no statistic existed when they were written.

## Sequencing
1. THIS document (with FIXES A–F applied) commits BEFORE any statistic (the running `edgar_pull_value.py` is data
   acquisition only).
2. Pull completes → coverage reconciliation print (censuses i–vi above; still no test statistic).
3. Runner = `value_factor.py`, extending the verified `gpa_quality.py` machinery with the value signal swap (B/M and
   E/P as-of computation + the FIX-A split-consistent MarketCap denominator + FIX B/C shares/availability rules) with a
   PASS-BLOCKING selfcheck (AAPL-2013 B/M reproduction to 1e-9 + not-in-cheap-tercile; joint-availability fixture;
   negative-NI/negative-equity tercile-exclusion asserts) → detached run → 2-lens verification (conjunct audit vs THIS
   document + independent re-implementation of ≥1 arm incl. one name-date B/M reproduced from adjClose + name splits +
   raw shares + equity) → index + ship; ledger family `value-factor` (+12 arms).
