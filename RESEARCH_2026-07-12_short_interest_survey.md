# Short interest as a retail equity signal — survey-grade vetting (3-vote)

**Date:** 2026-07-12 · **Disposition: REFUSE-and-index. Do NOT run an ablation.** ·
**Method:** dynamic Workflow `wf_0bd1e383-25b`, 35 agents (4 Find angles → 3-vote adversarial
Verify per load-bearing claim → synthesize). Verifiers read PRIMARY PDFs (Ritter's hosted
Asquith-Pathak-Ritter, NBER WP 20282, JF/JFE abstracts). 10 load-bearing claims: **9 CONFIRMED,
1 REVISED (numeric-precision only), 0 REFUTED.**

## The question

Is there a **retail-implementable** version of the short-interest signal (high short interest /
high days-to-cover predicting negative future returns) that could plausibly clear the campaign
bar — a net-of-cost walk-forward DSR > 0.95 on the survivorship-free panel? Short interest was
the *next data class* after news sentiment (refused 2026-07-12 @ 320edb6). It looked more
promising than news: it is genuinely orthogonal positioning information (survives Fama-MacBeth
controls for size/B-M/momentum/illiquidity — Boehmer-Huszár-Jordan 2010, Hong et al. 2015), it
is low-turnover (bimonthly reporting → no news-style churn), and FINRA covers delisted/bankrupt
names (BBBY/BBBYQ/MULN) so the **data side would pass survivorship acceptance** where news
failed.

## Verdict — three legs, each retail-accessible one fails a different structural test

**(a) SHORT leg (heavily-shorted → underperform) — the real edge, retail-inaccessible AND cost-killed.**
- Asquith-Pathak-Ritter (JFE 78(2):243-276, 2005): EW **215 bps/mo (significant)** but VW only
  **39 bps/mo (INSIGNIFICANT)** — a small/micro-cap phenomenon; only ~21 of ~5,500 stocks
  actually short-constrained per month. Authors' own turnover warning (p.245): keeping the
  portfolio restricted requires "extensive" turnover → "implementation shortfall relative to
  returns … estimated ignoring transaction costs."
- Muravyev-Pearson-Pollet (JF 80(6):3639-3694, 2025) — the decisive current-era read: across
  162 anomalies the avg long-short return is **+0.14%/mo gross → −0.01%/mo net of borrow fees**,
  the return is "due to the short leg," and is gone even *pre-fee* once the top-12%-fee
  stock-dates are dropped. Borrow on high-SI names runs 10-100%/yr.
- Drechsler-Drechsler (NBER WP 20282): the CME (cheap-minus-expensive-to-short) portfolio earns
  **1.43%/mo gross → 0.91%/mo net** (~6.2%/yr fee drag); eight major anomalies "effectively
  disappear within the ~80% of stocks that are cheap-to-short." Alpha is concentrated in the
  high-fee 20% by construction.
- Low turnover does NOT rescue this leg: the cost wall is **borrow fee**, not turnover, and a
  long-only retail engine can't hold the position at all.

**(b) LONG leg (avoid-high-SI / tilt to LOW short interest) — the only retail-tradable read, but SPANNED and DECAYED.**
- Boehmer-Huszár-Jordan (JFE 96(1):80-97, 2010) is the one pro-signal claim: LOW-SI, high-turnover
  names carry statistically-AND-economically-significant positive alpha, monthly horizon; the
  short leg is "transient and of debatable economic significance."
- **Spanned:** a long-only tilt toward low-short-interest, "boring," slowly-repriced names selects
  almost the same cohort already measured **null on the identical 34,701-series survivorship-free
  panel** — the smallcap MAX/BAB/IVOL long-tilt family (2026-07-10, 0/18 arms; the block-significant-
  negative arms carried the Jensen variance-wedge signature, not a real anomaly), GP/A quality
  (0/6), quality×momentum composite (0/6). Low-SI is a near-cousin positioning characteristic of
  those low-vol/quality cohorts. The prior is a *measured* null, not a fresh unknown.
- **Decayed:** McLean-Pontiff (JF 2016) 26% OOS / 58% post-pub haircut; Jacobs-Müller (JFE 2020,
  241 anomalies × 39 markets) — the **US is the ONLY market with a reliable post-pub decline**
  (worst-case geography for a US-first engine). Boehmer et al. is a pre-2010 in-sample result;
  haircut ~50-60% and the modest long-side alpha shrinks toward the sibling nulls.

**(c) AGGREGATE leg (market-level SII timing) — real and robust, but a DIFFERENT object.**
- Rapach-Ringgenberg-Zhou (JFE 121(1):46-65, 2016): the aggregate short-interest index is the
  single strongest known TIME-SERIES predictor of MARKET returns (annual R² 12.89% IS / 13.24%
  OOS, >300 bps/yr utility gain). But this is **market-timing / exposure**, not cross-sectional
  stock selection — out of scope for the ideas-card per-name ranking and the wrong test for the
  DSR-cross-sectional bar. Flag as a *separate* candidate object if market-exposure timing ever
  becomes a workstream; do NOT conflate with the cross-sectional refusal here.

## Why REFUSE without an ablation

The one ablatable version (long-only low-SI tilt) is (i) the weakest leg by the authors' own
words, (ii) **spanned by three already-null'd families on the identical panel** a fresh test
would use, and (iii) subject to the standard US 50-60% post-pub haircut. An ablation would
re-derive a known null under a worse signal-to-noise regime — the exact corpus anti-pattern
(re-running a spanned candidate is pollution, not a test). Unlike most refusals this is NOT
"underpowered": it's "the edge is provably where retail can't reach and is net-negative even for
those who can." The DATA passes acceptance (FINRA covers delisted names) — the refusal is on the
**ECONOMICS**, distinct from the news-sentiment refusal (which failed on data-survivorship + cost
+ endogeneity).

## The one REVISED claim (numeric precision, disposition unchanged)

The "modern short-interest anomaly is net-negative after borrow, haircut ~50-60%" claim was
REVISED (2 REVISE / 0 CONFIRM / 0 REFUTE): all three primary sources check out, but (a)
Muravyev-Pearson-Pollet is a **162-anomaly aggregate, not a short-interest-specific**
decomposition — the family-specific net figure is a defensible *extrapolation* (short interest is
a borrow-cost proxy inside those cross-sections), not a directly measured short-interest-only
number; (b) Jacobs-Müller says the US is the **ONLY** market with reliable decay (stronger than
"most reliable") — a material scope caveat for any non-US application; (c) the "post-2015" era
label is inference, not a measured window in these sources. The operative conclusion survives.

## What this survey did NOT establish

- **No same-family net-of-cost measurement** — the family-specific net figure remains inferred
  (Muravyev et al. is aggregate), not measured. A dedicated short-interest ablation was not run
  and is not recommended (see above).
- **The long-only low-SI leg was NOT empirically ablated** on the survivorship-free panel — the
  spanning is a strong prior from three sibling nulls, not a direct low-SI arm. If the owner ever
  wants the null nailed down rather than inferred, a low-SI long-tilt arm on the existing
  smallcap-tilt harness is the cheap confirmatory run — LOW priority, behind any genuinely new
  data class, expected null.
- **Non-US applicability** — Jacobs-Müller implies the anomaly may *persist* outside the US;
  untested, outside the current US-first / Saudi-first tradable scope.
- **The aggregate SII market-timing object** — surveyed but not evaluated against any bar; a
  different signal class needing its own (time-series, not DSR-cross-sectional) test.
- **Short-squeeze / gamma dynamics** on meme names (the BBBY/MULN cohort FINRA covers) — an
  event/lottery phenomenon adjacent to the already-null'd MAX family, not a positioning-signal
  edge; out of survey scope.

**Net:** REFUSE-and-index. Fence short interest as a cross-sectional retail signal. Milestone
(a proven net-of-cost DSR > 0.95 edge) unchanged. Two workflow verify-agents hit the
StructuredOutput retry cap (5) and dropped — the affected claims were re-covered by the surviving
3-vote panels; no load-bearing claim rests on a dropped agent.
