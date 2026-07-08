# RESEARCH 2026-07-08 — Engine-baseline net-cost validation on the WIDEST US cross-section yet (campaign-milestone re-measurement)

**Verdict: NULL — no config clears DSR>0.95 (best net-OOS 0.321 primary [artifact-inflated] / 0.021 depth-matched [clean]); 10/12 (primary) and 12/12 (≥250-bar) configs negative even GROSS. The DSR≈0 "no proven edge / value-is-risk-discipline" baseline is re-confirmed on ~2,100+ US names — ≈26× the breadth of the 2026-07-07 run (81 names) — not overturned. No first positive to flag.**

## What this run is
Extends [RESEARCH_2026-07-07_engine_baseline_appcache.md](RESEARCH_2026-07-07_engine_baseline_appcache.md) — same shipped offline path (app `StockSageHistoryCache` → verbatim shipped `StockSageHistoryCache.panel(from:industryOf:)` → verbatim shipped `StockSageNetCostSim` + `StockSageDeflatedSharpe`, compiled by `swiftc` from the repo, zero xcodebuild/test-daemon), now on the FRESH cache the owner's 2026-07-08 20:06 equity-2000 scan populated: **2,415 entries** (vs 209 on 07-07). Occasioned by the owner's "make money via equity research, do it yourself" directive + "ok eodhd" — I could NOT obtain an EODHD token (account creation is off-limits), but the app cache is a *better* panel than EODHD would have given, so the core measurement ran with no token / no network. Only shim = the 11-line `StockSagePriceHistory` value container (field-declarations byte-identical to `StockSageQuoteService.swift:270–281`, no logic); the 5 `StockSage*.swift` engine files compiled straight from the repo, `git status` clean.

## Panel
- **Primary:** US suffix-less symbols with ≥150 bars → **2,158 names**, bar-depth min/median/max 155/252/252, shared trading-day intersection **152 periods**, roundTripBps=13 (shipped US homogeneous cost).
- **Robustness (cleaner/deeper, depth-matched to 07-07):** ≥250 bars → **2,123 names**, **248 shared periods**.
- Earnings-window exclusion left EMPTY (never fabricated) → industry-relative reversal, NOT full IRRX (the residual).

## Result (industry-relative reversal, walk-forward purge+embargo, selection-deflated over 12 configs lb∈{5,10,21,63}×hold∈{5,10,21})

**PRIMARY (2,158 names, ≥150 bars, 152 periods):** best net DSR **0.321** (lb5/hd21); **10/12 negative gross**; ANY clears DSR>0.95 = **NO**.

**ROBUSTNESS (2,123 names, ≥250 bars, 248 periods):** best net DSR **0.021** (lb5/hd21); **12/12 negative gross**; ANY clears = **NO**.

(Full 24-row table in the run log / task output; every net DSR ≤ 0.321, the vast majority < 0.13.)

## What this changes / confirms
1. **DSR≈0 re-confirmed at unprecedented breadth.** ~2,100+ US names is ≈26× the 07-07 panel and the widest equity cross-section this project has measured. Short-horizon reversal is again **absent/inverted** (10–12 of 12 configs negative even before costs), not merely cost-eaten — consistent with the 2025–26 momentum-led regime. The deeper (≥250) panel is MORE decisively negative than 07-07.
2. **The 0.321 primary best-DSR is an artifact, not a signal.** The raw suffix-less filter swept in the whole promoted equity-2000 universe incl. thin/split-artifact listings (28 returns with |r|>0.5 — NIPG +3052%, ABTC +1060%, small biotech/SPAC); the verbatim `panel()` does not adjust these. The ≥250-bar variant that drops most thin listings collapses the best DSR to 0.021, so the artifacts do NOT manufacture a false positive — the NULL is robust to them.
3. **Machinery re-proven end-to-end** on the widest real-data panel; the app-cache `bridge` pattern (one owner scan ⇒ a refreshable 2,415-name panel, zero network) is validated at scale.

## Honesty caveats (this run does NOT overturn any prior conclusion — a null here is corroboration)
- **Degenerate industry granularity:** the shipped curated `StockSageSector` map tags only ~61 well-known names; **2,097 of 2,158 fall to "Other"** (Tech 16, Consumer 12, Financials 11, Healthcare 8, Comms 5, Industrials 5, Energy 4). So the "industry-relative" demean is effectively **broad-cross-sectional-vs-Other-mean** for the promoted names, not fine industry-relative. Real property of the shipped `industryOf`; the breadth is genuine but the industry resolution is not. (Does not change the verdict — reversal is absent/inverted at every granularity here.)
- **Window ~152 shared bars (primary)** — the wide net pulls in 155-bar recent listings that shrink the verbatim shared-date intersection; the ≥250-bar robustness run (248 bars) is the cleaner/more-powerful read and is the one to weight.
- **Single regime** (~2025-07→2026-07, one momentum-led bull); **survivorship-lite** (today's cache constituents); **US-only** (rt=13bps homogeneous); **earnings-window exclusion EMPTY** (full-IRRX residual — needs per-name earnings dates, the one thing an EODHD/AV token would add).

## Residuals / next (owner-scoped, data-gated)
- **Full-IRRX with earnings-window exclusion** — needs per-name earnings dates (EODHD `calendar/earnings` or Alpha Vantage `EARNINGS`); the `tools/altdata_ablation/fetch_and_ablate.sh --earnings` runner is fetch-and-go the instant an `EODHD_API_TOKEN` is Keychain-stored.
- **Multi-regime / long-horizon** — 252-bar cache cannot form a 126-bar-lookback walk-forward; needs a multi-year panel (EODHD or a longer-retained cache).
- **Mixed-market panel** (US+.SR+crypto, per-suffix costs) — buildable now via the L3-05 dayKey fix; a natural next variant.
