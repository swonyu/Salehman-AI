# Yahoo-independent net-of-cost ablation runner + crypto machinery validation — 2026-07-03

**Author:** Claude #1 (Opus 4.8, autonomous money-engine mandate). **Type:** infrastructure +
machinery validation (NOT an edge claim). **Campaign map:** `skills/money-campaign-map` Phase 4/6.
**Extends:** OPEN FRONTIER #1 (IRRX net-of-cost ablation) — the residual axis + a data-path unblock.

## Motivation

The campaign's edge search is bottlenecked on **data**: every existing net-of-cost validation path
fetches from Yahoo v8, which is throttled (poller stuck on repeated 429). OPEN FRONTIER #1's residual
— the **earnings-window exclusion** ("full IRRX") — was never run because the prior real-data panel
required Yahoo and died with its session. Two facts reframed the work:

1. **The ablation harness is CODE-COMPLETE.** `StockSageNetCostSim` (main tree) already implements
   the industry-relative reversal, per-side turnover costs, walk-forward + purge/embargo, the
   DSR>0.95 gate, **and the earnings-window exclusion** (`Panel.earningsExcludedAt` +
   `irrxWeights(excluded:)`, used at `rebalanceSeries` line 155). The #1 residual is **data-blocked,
   not code-blocked** — there was nothing to build in the engine.
2. **The data dependency, not the math, is the wall.** So the deliverable is a *Yahoo-independent*
   way to feed the shipped math a real panel.

## Method

- **Runner** (`tools/altdata_ablation/`): compiles the VERBATIM shipped `StockSageNetCostSim.swift` +
  `StockSageDeflatedSharpe.swift` (no reimplementation → the math is exactly what ships) with a thin
  `main.swift` that loads a return-panel JSON, sweeps a 12-config horizon grid
  (lookback ∈ {5,10,21,63} × hold ∈ {5,10,21} trading days) with **selection-deflation**
  (`trials`=configs, `varTrialSharpe`=variance of per-config net Sharpes), and reports net DSR
  **with vs without** the earnings-window exclusion. Smoke-tested on a seeded synthetic panel
  (random data → all net DSR ≪ 0.95, nothing clears — correct).
- **Data adapters** (Yahoo-free): CoinGecko (keyless, crypto) and Alpha Vantage
  `TIME_SERIES_DAILY_ADJUSTED` (split/div-adjusted — the RAW `TIME_SERIES_DAILY` endpoint would
  inject split jumps and is NOT used) + `EARNINGS`/Bigdata.com `events_calendar` for earnings dates.
- **Earnings-exclusion operationalization** (documented choice, not the code's default): a symbol is
  excluded from the book at a rebalance formed at period `t` if it has an earnings date within a
  fixed ±10-trading-day window of `t` (a config-independent earnings blackout ≈ Novy-Marx RRLP's
  earnings-window removal). Labeled as an operationalization, not a canonical definition.

## Result — crypto machinery validation (real data, NULL)

Panel: **15 coins × 400 daily returns** (CoinGecko USD, as-of 2026-07-03), 4 category "industries"
(L1 / DeFi / meme / infra), `roundTripBps=70` (crypto, per `StockSageNetEdge.defaultCosts`).

| read | value |
|---|---|
| Best net-OOS DSR across 12 configs | **0.509** (lb=5, hd=21) |
| Any config clears DSR > 0.95 | **NO** |
| Net means | mostly **negative** (e.g. lb5/hd5 meanNet −0.0064) — 70 bps erases the gross reversal |

**Interpretation:** the net-cost gate correctly kills a cost-dominated reversal on real data — first
real-data run of the shipped machinery via a Yahoo-independent path. This is **machinery validation +
a fenced-domain (crypto reversal ≈ anti-edge #5) data point**, NOT a campaign edge. It says nothing
about the equity IRRX question.

## Did NOT establish

- **Nothing about an equity edge.** Crypto ≠ the campaign target; no equity panel was run here.
- **The #1 residual is not closed.** The earnings-window axis is now *runnable* (runner + adapters +
  operationalization) but not yet *run on equities*.

## Limitations

- Crypto panel is fenced-domain and has no earnings window (exclusion N/A → `WITHOUT`-only).
- The `±10-day` earnings blackout is one reasonable operationalization; sensitivity untested.
- Selection-deflation uses the 12-config grid only; a wider grid would raise the trial count.

## Next step (queued, not forced)

Run the **equity IRRX pilot** on a proper panel the moment a split-adjusted equity source is free.
**Data-source status (verified 2026-07-03):** the equity path is BLOCKED — Yahoo v8 is throttled
(poller stuck on Korean symbols), and Alpha Vantage's `TIME_SERIES_DAILY_ADJUSTED` is a **PREMIUM**
endpoint (free key → rate-limit/premium error, not data); the raw free `TIME_SERIES_DAILY` is
unusable (split jumps fabricate returns); CoinGecko is crypto-only; Bigdata.com is news/events, not
prices. Unblock options: (a) the poller's panel once Yahoo cools; (b) a premium AV key; (c) an EODHD
token or other split-adjusted feed. Given a source, populate `earningsExcludedAt` from real earnings
dates (Bigdata.com `events_calendar`) and run WITH vs WITHOUT. The runner makes it a fetch-and-go —
the block is data access, not tooling or effort.
No engine change ships from any of this without a DSR>0.95 pass **and** owner sign-off (RANKING #10).
