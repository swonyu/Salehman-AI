# Research Index — cumulative, durable (lean index; detail in linked files)

One dated line per research item: topic · one-line finding · source file. Keep < ~200 lines; roll over when it grows.
**Before PLAN:** scan this index; open the relevant detail file before proposing a change in that area. Never re-research an item here — extend its entry.

> Detail lives in the repo-root `RESEARCH_*.md` / `*_RESEARCH.md` files (durable on disk, not lost in transcripts). Index seeded + enriched 2026-06-27 from those files + the Ideas-card roadmap.

## Detail files (catalog — with key findings)
- **2026-06-27 · money-fast + high-conviction** → [RESEARCH_2026-06-27_money_fast_conviction.md](../RESEARCH_2026-06-27_money_fast_conviction.md)
  "Get-rich-fast" demolished; disciplined concentration survives. Best-ideas concentration beats diversification but ONLY top-few names, GROSS of cost, high-vol (Antón-Cohen-Polk +2.8–4.5%/yr; all-ideas alpha ~0). Felt conviction = overconfidence, self-defeating (Barber-Odean: highest-turnover −7pp net, the whole gap is COSTS). >80% day-traders lose net; <1% persistently skilled, and skill is predicted by PAST PERFORMANCE not stated conviction. Kelly: overbetting ruins (≥2× → growth to risk-free then negative); half-Kelly bounded limits are the answer. → validated half-Kelly 0.5×, sizing>signal, cost-discipline.
- **2026-06-27 · quant engine II (calibration/exits/crypto/execution)** → [RESEARCH_2026-06-27_quant_engine_II.md](../RESEARCH_2026-06-27_quant_engine_II.md)
  VERDICT **CONDITIONAL-ADOPT Beta calibration** (3-param, Kull et al. 2017) as a *candidate* conviction→win-prob map ALONGSIDE isotonic + a no-op identity, OOS-selected per refit (NOT a hard replace); favor Beta/Platt <~200-300 trades, isotonic only as pooled set →~1000+. Stops = regime-gated drawdown INSURANCE, not free alpha. Crypto → short-lookback TS/ATR trend. Cost = flat-bps spread/slippage + near-zero square-root impact. ⚠️ **RELEVANT TO iter7:** this frames calibration as a candidate-SELECTOR ({isotonic, beta, identity} OOS-picked) — a richer answer than plain ridge-logistic Platt; RECONCILE the ridge-logistic plan with this before iter7.
- **2026-06-26 · quant engine I (validation/sizing/regime)** → [RESEARCH_2026-06-26_quant_engine.md](../RESEARCH_2026-06-26_quant_engine.md)
  Backtest validation: walk-forward vs CPCV, purge+embargo, **Deflated/Probabilistic Sharpe** to defeat data-snooping. Sizing: fractional Kelly + vol-targeting + correlation-aware heat caps + drawdown control. Regime detection improves live risk-adjusted returns (not pure overfit) when kept simple. → backbone for the backtest harness + iter1–6 sizing.
- **2026-06-22 · documented-edge roadmap** → [EDGE_RESEARCH.md](../EDGE_RESEARCH.md)
  5 vetted, engine-spec'd edges. ✅ DONE: #2 net-edge break-even win-rate + cost gate (→ NetEdge/iter6), #3 TSMOM 12-1 trend filter (→ iter3). ⬜ **OPEN, spec'd & ready as future iterations:** #1 per-symbol vol-regime brake (VIX-free; works on Tadawul/FX/crypto), #4 downside-skew / left-tail read, #5 vol-of-vol sizing-reliability gate. ← BACKLOG SOURCE for post-backtest iterations.
- **(undated) · markets intelligence** → [MARKETS_INTELLIGENCE_RESEARCH.md](../MARKETS_INTELLIGENCE_RESEARCH.md)
  The engine's design charter: what/when/how-much/when-to-sell. 2–3 complementary documented-edge signals (NOT more); sizing matters more than the signal; regime filter as the meta-rule; define BOTH exit prices before entering; diversify by RISK not dollars; backtest-honesty or the "edge" is fake.
- **2026-06-14 · macOS 27 design** → [DESIGN_RESEARCH_macOS27.md](../DESIGN_RESEARCH_macOS27.md)
  UI/design ONLY (not signal). macOS 27 "Golden Gate" vs 26 "Tahoe"; Liquid Glass SwiftUI APIs; the app's crimson flat-dark language is a VALID deliberate divergence — selective alignment, not wholesale adoption.

## Verified research-backed decisions (confidence labels = adversarial multi-vote)
- **Half-Kelly (0.5×) is optimal** — 75% of max growth, ruin-of-halving 1/2→1/8 (Thorp/MacLean-Ziemba; 3-0). App uses 0.5×. Do NOT raise it. → no-change + iter7 Kelly guardrail.
- **Sizing > signal quality** — "worse model + better sizing beats better model + worse sizing" (2-1). → ITER1 calibrated win-prob → half-Kelly = highest-leverage.
- **maxWeight cap (0.20) needed** — raw Kelly can exceed 1 (leverage); 0.5× + cap keeps it unleveraged (2-1).
- **TSMOM variance-scaling** — scale trend by targetVol/realizedVol, not a binary crash-veto (Barroso & Santa-Clara 2015). → ITER3.
- **Calibration for small-N** — isotonic binning unreliable < ~1000 (Niculescu-Mizil & Caruana, Platt-vs-isotonic crossover); Platt below that (Alasalmi 2020). Beta-3param is a stronger *candidate* (quant_engine_II, CONDITIONAL). → ITER4 (Platt, isotonicMinSamples=1000). OPEN #2: Platt path is plain MLE not conservative → ITER7 ridge-logistic (reconcile w/ Beta-candidate-selector).
- **52-week-high proximity** — proximity attenuates crash risk / carries momentum (Byun & Jeon 2023). → ITER5 (continuous, long-side, regime-gated).
- **Net-of-cost EV + overtrading is the #1 killer** — costs/churn erode retail edge; break-even p*=1/(1+netRR) (Barber & Odean 2000). → ITER6 (net-cost EV/day + floor). FOLLOW-UP: make floor cost-relative.
- **Deflated Sharpe** — correct for multiple-comparisons/data-snooping when ranking many strategies/names. → backtest harness (StockSageDeflatedSharpe).

## How to extend
Append a dated line here + write/extend the detail file. PLAN reads this index. This is the Research Spec Keeper's log.
