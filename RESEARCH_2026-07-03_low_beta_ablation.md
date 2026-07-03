# Research: Low-beta / low-idiosyncratic-vol LONG tilt (defensive / BAB anomaly) — net-of-cost REAL-DATA ablation

**Date:** 2026-07-03 · **Author:** Opus session (autonomous ablation) · **Status:** NULL (net edge not demonstrated; in-sample increment significantly NEGATIVE) — a win; indexed.

## Question
Frazzini & Pedersen, "Betting Against Beta" (2014); Baker, Bradley & Wurgler, "Benchmarks as Limits to Arbitrage" (2011): leverage-constrained investors overpay for high-beta, so low-beta / low-vol names earn better RISK-ADJUSTED returns (the "defensive anomaly"). HYPOTHESIS tested here as a CROSS-SECTIONAL LONG-ONLY ranking tilt: does conditioning long entries on the low-realized-beta (and, separately, low idiosyncratic-vol) cohort clear the honest net-of-cost DSR>0.95 bar vs an unconditional equal-weight long baseline on the same panel? THE HONESTY QUESTION: BAB's alpha lives in the SHORT-high-beta leg + leverage; the long-only leg is thin and is largely drawdown-reduction, not alpha — AND the engine already vol-targets (StockSageExpectedValue.cryptoRiskScaler + StockSageVolRegime brake). So: is any net edge real ALPHA, or merely variance reduction the sizing layer already captures?

## Method
- **Harness fidelity:** verdict math from the REAL `StockSageDeflatedSharpe` (Acklam inverse-normal, PSR/expected-max-Sharpe/DSR), COMPILED FROM SOURCE into a standalone Swift runner — zero port risk. Cost 13bps ported exactly from `StockSageNetEdge.defaultCosts` US large-cap (spread 8 + slippage 5).
- **Universe (frozen BEFORE analysis):** 18 US large-caps across 6 sectors {NVDA,AVGO,MU; AAPL,MSFT,GOOGL; JPM,BAC; XOM,CVX; PG,KO,WMT; JNJ,UNH,PFE; HD,CAT} (the frog panel's US subset) + `^GSPC` market proxy. The frog panel's 6 Saudi/global dotted names (SHEL.L, AZN.L, SAP.DE, 2222.SR, 1120.SR, 2010.SR) were EXCLUDED FROM THE BETA CROSS-SECTION: they trade async to the US session, so their ^GSPC-beta is downward-biased by non-synchronous trading (Epps effect / stale prices), which would spuriously populate the low-beta cohort for a mechanical reason unrelated to the anomaly. A ^GSPC-beta cross-section requires a synchronous calendar. All 19 fetched cleanly (1254 bars, one calendar); no HTTP-429.
- **Data:** 5y daily, Yahoo v8 chart endpoint (the endpoint StockSageQuoteService uses), gentle (concurrency 1, ~2s spacing, backoff).
- **Signals (two variants):** trailing-252d, as-of index i: (a) beta = cov(r_i,r_mkt)/var(r_mkt); (b) idiosyncratic vol = std of residuals from r_i = alpha + beta·r_mkt (Ang-Hodrick-Xing-Zhang 2006 / low-vol). Cross-sectional rank each rebalance; LOW = bottom tercile (6 of 18), HIGH = top tercile.
- **No look-ahead:** signal from closes[0..i]; enter open[i+1], exit open[i+1+H]; as-of stepped by exactly H (non-overlapping, independent blocks). Warmup 252.
- **Three arms:** BASE = equal-weight long ALL 18 (unconditional-long baseline); LOW = long bottom-tercile; HIGH = long top-tercile. Clean incremental test = LOW − BASE (market-neutral → isolates the tilt from bull beta); mechanism = LOW − HIGH.
- **Net-of-cost (mandatory):** net = gross forward return − 13bps per long round-trip, per name, then averaged over the arm's members.
- **Block-level significance:** one net number per non-overlapping block per arm; paired t across blocks on LOW−BASE and LOW−HIGH (regularized-incomplete-beta two-sided p, self-checked t=2.228/df=10→p=0.050).
- **DSR gate:** real StockSageDeflatedSharpe.deflated on each config's per-block net series (Sharpe=mean/sd, nTrades=block count); selection-deflated trials=24 (2 signals × 4 horizons × 3 arms), varTrialSharpe=0.225 (measured across the 24 config Sharpes; expected-max-Sharpe bar=0.939).
- **Horizon sweep:** 21 / 42 / 63 / 126 trading days.
- **Note on breakEvenWinRate:** NetEdge's p*=1/(1+netRR) bar is defined for stop/target R:R trades, not a basket-return tilt; the honest bar here is BEATING the unconditional-long baseline net-of-cost, tested directly by the LOW−BASE incremental series.

## Results
Per-block NET means (bp) and DSR (real StockSageDeflatedSharpe, trials=24):

| Signal·H | nBlk | BASE net | LOW net | HIGH net | LOW Sharpe | BASE Sharpe | LOW DSR | LOW−BASE net/blk / t / p | LOW−HIGH net/blk / t / p |
|---|---|---|---|---|---|---|---|---|---|
| beta·21  | 47 | +200.0 | +21.8  | +444.3  | +0.066 | +0.524 | 0.000 | −178.3 / −2.85 / 0.007 | −422.6 / −3.07 / 0.004 |
| beta·42  | 23 | +420.4 | +78.2  | +932.1  | +0.161 | +0.899 | 0.000 | −342.1 / −2.50 / 0.020 | −853.9 / −2.79 / 0.011 |
| beta·63  | 15 | +610.2 | +92.9  | +1312.0 | +0.156 | +0.862 | 0.002 | −517.4 / −2.27 / 0.039 | −1219.1 / −2.44 / 0.028 |
| beta·126 |  7 | +1309.4| +153.1 | +3056.9 | +0.293 | +1.277 | 0.073 | −1156.3 / −2.98 / 0.025 | −2903.8 / −2.35 / 0.057 |
| ivol·21  | 47 | +200.0 | +69.2  | +372.9  | +0.204 | +0.524 | 0.000 | −130.9 / −2.96 / 0.005 | −303.8 / −3.02 / 0.004 |
| ivol·42  | 23 | +420.4 | +151.3 | +786.2  | +0.388 | +0.899 | 0.008 | −269.1 / −2.64 / 0.015 | −634.8 / −2.64 / 0.015 |
| ivol·63  | 15 | +610.2 | +246.7 | +1127.4 | +0.427 | +0.862 | 0.034 | −363.5 / −2.24 / 0.042 | −880.7 / −2.80 / 0.014 |
| ivol·126 |  7 | +1309.4| +583.1 | +2443.2 | +0.643 | +1.277 | 0.227 | −726.3 / −2.05 / 0.086 | −1860.1 / −2.34 / 0.058 |

- **NO config clears DSR>0.95.** Best absolute = ivol·126 LOW 0.227 (≈ bull beta, not the tilt). Every incremental LOW−BASE and LOW−HIGH DSR = 0.000 (negative Sharpe).
- **The tilt SUBTRACTS return:** LOW−BASE is negative at all 8 horizons and block-significant at 7/8 (p 0.005–0.086); LOW−HIGH negative and significant everywhere. In 2021–2026 the bull was high-beta-led (HIGH cohort +444 to +3057 bp/block), so selecting low-beta gave up the market's return.
- **Not even a clean risk win:** LOW's block-Sharpe is BELOW BASE's at every horizon — the mean-return collapse swamped the modest sd reduction (21d beta: sd 332 vs 382 but mean 22 vs 200 bp). Max drawdown was often WORSE for LOW (−16.7% vs −11.3% at 21d) due to 6-name concentration.
- **PSR-vs-DSR:** ivol·42/63/126 LOW show PSR 0.94–0.95 (selection-uncorrected, just "long in a bull"); DSR 0.008–0.227 after the 24-trial expected-max-Sharpe haircut — the deflation working as designed.

## Conclusion
**NULL — the low-beta / low-idiosyncratic-vol LONG tilt does not clear the net-of-cost DSR>0.95 gate on real data; in this sample its incremental return is significantly NEGATIVE. Keep the engine as shipped; do not add a low-beta selection tilt.** ALPHA-vs-RISK verdict: this is NOT alpha (the increment over unconditional long is significantly negative) and NOT even a clean variance reduction (risk-adjusted, LOW underperforms BASE; drawdown often worse). The only genuine benefit of a low-beta long leg — variance/drawdown reduction — is ALREADY delivered by the engine's vol-targeting (StockSageExpectedValue.cryptoRiskScaler + the StockSageVolRegime brake) at the sizing layer, per-name and continuously, WITHOUT discarding the cross-section. Moving that job to a low-beta ranking tilt would pay for it by throwing away return and would double-count a risk control the engine already owns. This is exactly BAB's documented structure: alpha in the short-high-beta leg + leverage; the unlevered long-only leg thin and regime-dependent.

## What this round did NOT establish
- **Not** a disproof of the academic BAB / low-vol / defensive anomaly. Only the UNLEVERED LONG-ONLY leg was tested; BAB's premium is a levered long-low / SHORT-high construct, and the short leg + leverage (which the engine does not and will not use — long-biased, unlevered, half-Kelly) is where its alpha lives.
- **Not** tested across a full market cycle. 2021–2026 is a single high-beta-led bull — the regime most hostile to a defensive long tilt. Bear/high-vol regimes (where low-beta historically shines on a drawdown basis) are under-represented in a 5y window; a longer/multi-cycle panel is the residual (Fable/owner-scoped).
- **Not** a levered risk-parity or vol-scaled implementation (scale each cohort to equal ex-ante vol) — that is the form in which the defensive premium is usually shown, but it collides directly with the engine's existing vol-targeting and would be redundant sizing, not a ranking edge.
- **Not** benchmark-subtracted on the absolute arms (they carry bull beta); the incremental LOW−BASE / LOW−HIGH arms ARE market-neutral and are the clean tests — and they fail (negatively).
- Survivorship = ceiling (all 18 names survived 5y). Panel breadth 18; blocks thin at long horizons (7 at 126d). McLean-Pontiff ~50–58% OOS haircut applied before judging — moot, the increment is already negative.

## Reproduce
Scratchpad `fetch_panel.py` (Yahoo v8, stdlib, gentle; 18 US + ^GSPC) → `panel.json`; `beta.py` (stdlib; trailing-252d beta & IVOL, cross-sectional terciles, non-overlapping blocks, paired-t, descriptive Sharpe/drawdown) → `series.json`,`table.json`; `main.swift` compiled with the real source for DSR: `swiftc -O StockSageDeflatedSharpe.swift main.swift -o runner`. Expect the null to hold (best DSR ≪ 0.95, LOW−BASE negative); short-horizon decimals/signs drift with Yahoo's sliding 5y window — only the CONCLUSION (no config clears; low-beta long leg gives up return in a high-beta bull) is stable. The negative *sign* of the increment is regime-specific (2021–26 bull); its *failure to clear the honest bar* is the durable finding.
