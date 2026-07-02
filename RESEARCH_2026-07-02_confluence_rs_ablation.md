# Research: Empirical ablation of the confluence tie-break (RANKING #12) and cross-sectional RS rank (HARDENING #32)

<!-- Self-run empirical study, NOT a literature-review deep-research workflow. 2026-07-02,
     autonomous continuation (owner: "continue"). Python, stdlib only (no numpy/scipy —
     t-distribution CDF and Spearman implemented from scratch, verified against known
     critical-value tables before use; see scratch script history). -->

## Question

Two engine modules shipped this session as deliberately UNVALIDATED, safe-by-default
utilities, each carrying an explicit "pending a dedicated ablation study" caveat in its own
source comment:

- **`StockSageIndicators.timeframeConfluence`** (RANKING_BACKLOG #12) — feeds
  `StockSageExpectedValue.bestOpportunity(preferConfluence:)`, an opt-in (default `false`)
  tie-break that, within an already-tight EV tie band, prefers ideas where LONG (12-1 TSMOM)
  and SHORT (21-day return) legs agree.
- **`StockSageRelativeStrength.rank`** (HARDENING_BACKLOG #32) — a standalone, completely
  unwired cross-sectional percentile-rank utility (tie-averaged), explicitly flagged in its
  own doc comment as "the SAME CLASS of unvalidated momentum-predicts-forward-returns premise"
  as the `relativeStrengthEnabled` term that was measured and killed on 2026-06-27.

Question: using REAL historical price data, does either signal show a genuine, statistically
distinguishable forward-return edge — enough to justify ever promoting either past its current
inert/opt-in-tie-break posture?

## Method

- **Universe:** 20 liquid US large-caps spanning tech/financials/healthcare/consumer/energy/
  industrials (AAPL, MSFT, GOOGL, AMZN, NVDA, JPM, JNJ, PG, XOM, HD, KO, WMT, CAT, DIS, V, MA,
  UNH, CVX, PEP, ADBE). Chosen for liquidity and sector spread, not cherry-picked for outcome —
  picked before any analysis was run.
- **Data:** real daily OHLC from Yahoo Finance's public chart endpoint (the SAME endpoint
  `StockSageQuoteService.swift` uses), `range=5y interval=1d`. All 20 symbols returned an
  identical 1254-bar calendar, 2021-07-02 → 2026-06-30 — verified bar-for-bar before use.
- **Formulas ported EXACTLY from the live Swift source** (not re-derived from memory):
  `timeSeriesMomentum`/`trendOK` (252-lookback, 21-skip 12-1 TSMOM), `returnOverPeriod`,
  `StockSageRelativeStrength.rank`'s tie-averaged percentile (`avgIdx / (n-1)`). The DAILY leg
  of `timeframeConfluence` (the advisor's full multi-factor score sign) was **deliberately
  omitted** — replicating all ~10 factors of `StockSageAdvisor.advise()` in Python risked a
  flawed replica that would make results meaningless. This study therefore tests the 2 legs
  with exact formula parity (LONG × SHORT alignment), not the full 3-leg confluence gate. That
  is a real scope limitation, disclosed rather than hidden.
- **No look-ahead:** every signal at as-of index `i` is computed only from `closes[0...i]`.
  Entry fills at bar `i+1`'s OPEN, exit at bar `i+1+horizon`'s OPEN — matching
  `StockSageBacktester`'s own "no peeking, fill at next bar's open" convention exactly.
- **Two samples per test, to separate rigor from power:**
  - **`nonoverlap`** (primary): as-of dates stepped by exactly the forward horizon, so blocks
    never share a forward-return window — each block is a genuinely independent time period.
  - **`weekly`** (secondary/descriptive): as-of dates stepped every 5 trading days — 4x more
    observations, but overlapping forward windows are serially autocorrelated, so this is NOT
    used for the primary significance claim, only as a robustness cross-check on sign/magnitude.
- **Aggregation respects cross-sectional correlation:** rather than pooling all
  symbol×date observations as if independent (they aren't — 20 stocks on the same day are
  highly correlated), the primary tests average WITHIN each block first (one number per block:
  mean forward return of a bucket, or that block's Spearman rho), THEN run a paired t-test
  across blocks. This is the standard Fama-MacBeth-style fix for panel data with cross-
  sectional correlation.
- **t-distribution CDF and Spearman rank correlation implemented from scratch** (no numpy/
  scipy available) via the regularized incomplete beta function (continued-fraction method,
  Numerical Recipes) — verified against textbook critical values (t=2.228,df=10 → p=0.050;
  t=3.169,df=5 → p=0.025) before trusting any result below.
- **Horizon sweep:** to avoid over-indexing on one arbitrary forward window, both studies were
  re-run at forward horizons of 5, 10, 21, 42, and 63 trading days (non-overlapping at each
  horizon).

## Results

### Study A — LONG+SHORT confluence alignment vs. forward return

Non-overlapping primary sample (47 blocks, 21-day horizon):

| bucket | n | mean fwd return | win rate |
|---|---|---|---|
| aligned_up (both bullish) | 303 | +1.35% | 57.8% |
| aligned_down (both bearish) | 132 | +3.84% | 62.1% |
| not_aligned | 505 | +1.01% | 54.5% |

Block-level paired t-test (the statistically defensible comparison):

| comparison | n blocks | mean diff | t | p |
|---|---|---|---|---|
| aligned_up − not_aligned | 45 | −0.25% | −0.22 | 0.828 |
| aligned_down − not_aligned | 42 | +0.95% | 0.94 | 0.353 |
| aligned_up − aligned_down | 40 | −1.69% | −1.06 | 0.295 |

The weekly (denser, overlapping) sample agrees in sign and significance: no comparison clears
p<0.05 (closest: aligned_up − aligned_down at p=0.062, and even that is the WRONG sign — bullish
alignment underperforming bearish alignment, opposite of the feature's design premise).

**Horizon sweep** (aligned_up − not_aligned, non-overlapping at each horizon):

| horizon (trading days) | p | mean diff |
|---|---|---|
| 5 | 0.794 | +0.05% |
| 10 | 0.168 | −0.48% |
| 21 | 0.828 | −0.25% |
| 42 | 0.727 | +0.61% |
| 63 | 0.342 | −5.84% |

No horizon clears significance. Sign flips across horizons — consistent with noise, not a real
effect.

### Study B — cross-sectional RS percentile rank vs. forward return

Non-overlapping primary sample (47 blocks, 21-day horizon, 21-day lookback return ranked):

- Pooled Spearman(percentile, fwd_return): rho = **−0.040** (n=940)
- Block-averaged rho (Fama-MacBeth style): mean rho = **−0.045**, t=−0.96, **p=0.344**
- Tercile block-avg forward return: low=+1.99%, mid=+1.76%, **high=+0.72%**
  (high−low diff = −1.27%, t=−1.35, p=0.185)

The point estimate is a small NEGATIVE relationship (higher recent-21d-return rank → slightly
LOWER subsequent 21-day return), not significant, but the sign is notable: it is consistent
with the well-documented **short-term (≤1-month) reversal anomaly**, which is exactly why the
app's own `timeSeriesMomentum` construction uses `skipRecent: 21` to exclude the most recent
month from its 12-1 TSMOM — this ablation's null/negative result at the 21-day horizon is
consistent with, not contradictory to, that existing design choice.

**Horizon sweep** (block-avg rho, non-overlapping at each horizon): rho is small and negative
at every horizon tested (5d: +0.004, 10d: −0.019, 21d: −0.045, 42d: −0.068, 63d: −0.076), never
significant (p ranges 0.34–0.87), but consistently non-positive — zero support for "recent
21-day winners keep winning" over the 5-63 trading day forward windows tested here.

## Conclusion

**Neither signal shows a statistically distinguishable forward-return edge in this sample.**
This is a genuine, informative NULL result — not a failure of the study, the answer to the
question both modules' own doc comments explicitly deferred.

- **RANKING #12 (`preferConfluence`)**: stays exactly as shipped — an opt-in (`default false`),
  narrow tie-break used only within an already-tight EV band, never a standalone scoring
  factor or a default-on behavior. This ablation does not support promoting it further.
- **HARDENING #32 (`StockSageRelativeStrength`)**: stays exactly as shipped — a standalone,
  completely unwired utility. This ablation does not support wiring it into `rankByEV`,
  `rankByVelocity`, `bestOpportunity`, `advise()`, conviction, or sizing anywhere. The sign of
  the (insignificant) point estimate, if anything, argues against a naive momentum-continuation
  wiring at this specific 21-day lookback/horizon combination.

**No code change follows from this study.** Its value is closing the "pending ablation" caveat
on both modules with an actual, honestly-obtained answer, using the same rigor precedent as the
2026-06-27 `relativeStrengthEnabled` kill (real data, no look-ahead, block-level significance
testing, horizon robustness, disclosed scope limits).

## Honest limitations (disclosed, not hidden)

1. **Universe**: 20 liquid US large-caps only — no small/mid-caps, no international, no FX/
   crypto/commodities the app also trades. A real edge concentrated in a different asset class
   or liquidity tier would not show up here.
2. **Sample period**: 2021-07 → 2026-06 (~5 years, one largely bull-trending regime with a
   couple of drawdowns). Not a full market cycle; results could differ across a bear regime.
3. **DAILY leg omitted from Study A** (see Method) — this tests 2-of-3 confluence legs, not the
   full `timeframeConfluence` gate as wired into the live advisor.
4. **`n_blocks` shrinks fast at longer horizons** (63-day non-overlapping → only 15 blocks over
   5 years) — the 63d row's wide, sign-flipping estimate reflects genuinely low power there,
   not a stronger finding.
5. **Multiple comparisons**: 2 studies × 2 samples × ~3 comparisons × 5 horizons were run; at
   least one nominal p<0.10 appearing somewhere by chance is expected and should not be
   over-read (none reached the conventional p<0.05 bar in the primary non-overlapping sample
   regardless).
