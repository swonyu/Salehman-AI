# Research: Maximizing realized profit on a ~1-week horizon (1–5 day holds) — what survives retail costs

<!-- Deep-research artifact. 2026-07-02, owner ask: "everything in markets... make the [most money] fastest in a week... I like the top 3 things." deep-research workflow wf_91aa3452-fbe: 106 agents, ~6.1M tokens across the rate-limited first pass + resume, 5 search angles, 24 sources fetched, 119 claims extracted, 25 adversarially verified (3-vote), 23 confirmed / 2 killed, 12 merged findings. EXTENDS (does not re-litigate) RESEARCH_2026-06-27_money_fast_conviction.md — half-Kelly, best-ideas concentration, conviction-is-overconfidence, costs-kill are treated as settled inputs. -->

## Question

For a solo retail trader on a ~1-week horizon (1–5 trading day holds), with StockSage already shipping half-Kelly (0.20 cap), net-of-cost EV, R/day velocity ranking, top-3 fast-lane concentration, 12-1 TSMOM gating, and vol-regime brakes: (1) which documented SHORT-HORIZON edges survive realistic retail costs, quantified? (2) top-3 concentration mechanics on a weekly cycle? (3) execution/velocity levers on a weekly turnover cycle? (4) which weekly-horizon "fast money" approaches are demonstrably fake/ruinous (a refuse-list)?

## Executive summary (verified, adversarially voted)

**At the 1–5 day horizon, essentially NO documented equity edge survives realistic retail transaction costs as a standalone strategy.** Naive short-term reversal, PEAD/earnings-drift trading, ~90%-turnover anomaly rotation, daily overnight-vs-intraday round-trips, and crypto funding-seasonality timing are all cost-devoured — and any published effect size must additionally be haircut ~50–60% for out-of-sample + post-publication decay. What survives is (a) lower-turnover signals (heuristically below ~50% one-sided monthly turnover) and (b) execution levers that add expected return **without adding turnover**. Two of the three roadmap items below primarily *prevent losses* — that IS the honest answer to "make money fastest in a week": the fastest money at this horizon is the 1–1.7%/month you stop burning.

## The prioritized TOP-3 roadmap (owner's ask)

### 1. Turnover-aware cost gate + explicit refuse-list  [biggest lever: ~1–1.7%/month of cost-avoidance]
Make one-sided turnover a first-class penalty inside the net-of-cost EV ranker; haircut any published effect size 50–60% before evaluating it; hard-refuse (as a coded, surfaced policy, not a silent omission): naive short-term reversal as a standalone strategy, standalone PEAD trading, ~90%-turnover anomaly rotation, daily overnight/intraday round-trip harvesting, crypto funding-seasonality timing, and any implementation of an anomaly in the small/illiquid names where its paper edge nominally lives. Evidence: the canonical reversal decile earns +0.37%/month GROSS but **−1.28%/month NET (t=−6.02)** with 1.65%/month costs (Novy-Marx & Velikov, RFS 2016, verified 3-0); PEAD costs consume 70–100% of paper profits and the drift is 0.04%/month in liquid names vs 2.43%/month in illiquid ones (verified 3-0); published predictors decay 26% out-of-sample / 58% post-publication (McLean & Pontiff, JF, verified 3-0 ×3).

### 2. Zero-turnover execution-timing module  [single-digit to low-tens of bps/month, at ~zero incremental cost]
Three retail-actionable levers that change WHEN, not WHETHER, to trade:
- **Reversal-as-liquidity-screen:** delay trades that demand expensive liquidity (entering sharp recent winners / exiting sharp recent losers) — but no longer than necessary. This is the paper authors' OWN recommended retail use of short-run reversal (verified 3-0 / 2-1). Caveat: demonstrated for diversified books with many substitutes; a concentrated top-3 book gets a smaller, timing-only benefit.
- **Session timing by signal type:** all five past-return strategies (12-1 momentum, industry/earnings/TS momentum, reversal) earn their premia ENTIRELY OVERNIGHT (12-1 momentum overnight CAPM alpha 0.98%/month t=3.84 vs intraday −0.02%; Lou-Polk-Skouras, JFE, verified 3-0 ×3) — so execute momentum/trend ENTRIES at/near the close to hold the overnight session. Do NOT round-trip harvest the split (cost-devoured, on the refuse-list; the NightShares ETF closures empirically confirm it doesn't survive implementation).
- **Overnight-specific costs in EV:** borrow fees and higher margin apply only to positions held overnight — charge them to short-side and levered EV; cash-account long-only accrues neither (verified 3-0).

### 3. IF any new short-horizon signal is ever added: only the cleaned reversal (IRRX-style), only as an overlay, only after a net-of-cost simulation clears
The industry-relative, earnings-window-excluded reversal is the ONE short-horizon equity signal surviving the modern era GROSS of costs (58 bps/month, t=3.29 post-decimalization; 108 bps/month full-sample; Novy-Marx RRLP, verified 3-0 ×4) — the naive version is dead even gross (~18–31 bps/month, insignificant; and NO close-to-close reversal exists at all in non-microcap value-weighted 1993–2013). At 1–5 days specifically the effect is transient (plays out in ~2 weeks, then flips to momentum) so it must be measured at days-to-weeks frequency. Plausible NET retail magnitude: 0–30 bps/month at best, in liquid large caps, as an entry-timing tilt — NOT a standalone book. Gate: a genuine net-of-cost simulation (same rigor as the 2026-07-02 confluence/RS ablation) must clear BEFORE any activation.

## Refuse-list (consolidated, verified)

1. Naive short-term reversal as a standalone weekly strategy (gross +0.37%/mo → net −1.28%/mo).
2. Standalone PEAD/earnings-drift trading (costs eat 70–100%; edge lives in untradeable illiquids).
3. Any ~90%-turnover monthly anomaly rotation (costs >1%/month, exceed the gross spread for all but two variants).
4. Daily overnight/intraday round-trip harvesting of the overnight premium (explicitly cost-unattractive per the source paper; ETF implementations shuttered).
5. Crypto funding-rate-seasonality timing (peak-to-trough intraday spread ~2.5 bps vs 4–10 bps/side retail taker fees; single mid-tier journal, ~3-month sample — weak source AND negative conclusion).
6. Implementing any anomaly in small/illiquid names where the paper edge nominally lives.
7. Taking any published in-sample effect size at face value (haircut 50–60%).

## What this round did NOT establish (do not over-claim)

- **Question 2 (top-3 concentration mechanics — optimal position count, pairwise correlation limits, per-name caps on a WEEKLY cycle) produced ZERO verified claims.** The concentration design keeps resting on RESEARCH_2026-06-27_money_fast_conviction.md (monthly/quarterly-horizon evidence), not on this round.
  **2026-07-02 follow-up audit (source-code, not new research):** checked whether the app's REAL capital allocator (`StockSageCapitalAllocator.allocate`) actually caps concurrent positions at 3. It does not — the "top-3"/`maxConcurrent: Int = 3` language lives ONLY in `StockSageExpectedValue.expectedWeeklyR`/`fastLaneConcentration`, a DISPLAY PROJECTION ("if you concentrated in your top-3 fastest ideas, here's the estimated weekly R") plus a same-asset-class warning haircut — not an allocation constraint. The real allocator is governed by `maxHeat` (portfolio-heat cap, default 8%), half-Kelly per-position sizing, and `StockSageAllocationOptimizer`'s Frank-Wolfe mean-variance optimizer (correlation-aware de-weighting of redundant bets, built 2026-07-01). This is a MORE principled expression of "concentrate in the best ideas" than a hard position-count cap — a genuinely independent/low-correlation 4th or 5th idea can legitimately earn real weight without violating best-ideas-concentration research, since the optimizer's own quadratic penalty already down-weights correlated (redundant) bets automatically. **Conclusion: no code change follows.** Adding a hard top-3 cap to the real allocator would be a regression relative to the existing continuous, correlation-aware mechanism — the open question (evidence-based optimal position count at a WEEKLY horizon) remains genuinely open, but the app's current design does not need to wait on it; it already handles concentration via a more sophisticated framework than any simple count-cap answer to that question would provide.
- Question 3 only partially covered: session timing + liquidity screens verified; order-type choice (limit vs marketable, auction participation) and day-of-week effects NOT covered.
- Two claims were REFUTED in adversarial verification and must not be used: (a) that PEAD-style earnings momentum survives costs among mid-turnover strategies; (b) that a mispricing factor systematically loses money near the close (implying close executions are worse).
- Cost estimates are from samples ending 2013–2021; the post-2019 zero-commission/PFOF environment likely lowers explicit costs somewhat — the cost-devoured conclusions are directionally conservative, but exact net magnitudes may differ today.
- All "surviving edge" figures (IRRX 58 bps/mo, overnight momentum alpha 0.98%/mo) are GROSS — never quote them as achievable net retail returns.
- Three co-authors of the reversal paper are at Dimensional (disclosed conflict; content is anti-hype, but noted).
- McLean-Pontiff post-publication decay is reliably established for US markets only.

## Key sources (all fetched + adversarially verified this round)

- Novy-Marx & Velikov, "A Taxonomy of Anomalies and Their Trading Costs" (RFS 2016) — https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2535173
- McLean & Pontiff, "Does Academic Research Destroy Stock Return Predictability?" (JF) — https://onlinelibrary.wiley.com/doi/abs/10.1111/jofi.12365
- Novy-Marx et al., "Reversals and the Returns to Liquidity Provision" — https://mysimon.rochester.edu/novy-marx/research/RRLP.pdf
- Lou, Polk & Skouras, "A Tug of War: Overnight vs Intraday Expected Returns" (JFE) — https://personal.lse.ac.uk/polk/research/TugOfWar.pdf
- Chordia et al. (PEAD liquidity/costs) — https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1403342
- (Full 24-source list in the workflow output; the above carry every load-bearing number.)

## Engine mapping (what to build, in order)

1. **Refuse-list + turnover gate** → new `StockSageTurnoverGate` (or extension of `StockSageNetEdge`): expected round-trips/month per idea from `expectedHoldDays` → a turnover-cost drag term in `netEVR`/`velocityRankKey`; plus a coded refuse-list surfaced as caveat text where relevant (e.g. in the glossary/why panel). Default-preserving: pure additions, flag-gated where behavior would change.
2. **Execution-timing module** → new pure engine module (e.g. `StockSageExecutionTiming`): session-timing note per idea (momentum-family → "enter near the close"), liquidity-screen advisory (delay flag when a candidate demands expensive liquidity: recent sharp move against the trade direction), overnight borrow/margin drag charged into short-side EV (extend `StockSageNetEdge.allInCost`'s existing financing leg into the EV path for shorts). Display-only notes first; no ranking mutation without its own validation.
3. **IRRX overlay** → NOT NOW. Requires the net-of-cost simulation gate first (own ablation, same rigor as RESEARCH_2026-07-02_confluence_rs_ablation.md).
