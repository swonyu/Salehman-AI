# RESEARCH 2026-07-07 — Engine-baseline offline net-cost validation on the app's OWN cache (campaign-milestone measurement)

**Verdict: NULL — no config clears DSR>0.95 (best net-OOS DSR 0.019). The shipped offline
validation path is now proven END-TO-END on real app data, and the DSR≈0 "no proven edge"
baseline is re-confirmed on the widest-breadth panel this project has ever measured.**

## What this run is (and why it's the milestone measurement)
The money-campaign map's "shipped-engine baseline" lane: instead of hand-assembled research
panels, run the **app's own data path end-to-end** — `StockSageHistoryCache` (populated by the
owner's real 2026-07-07 07:49 app session; savedAt 2026-07-07T04:49:26Z UTC, schemaV1, 209
entries) → the **verbatim shipped** `StockSageHistoryCache.panel(from:industryOf:)` (with the
same-day audit L3-05 UTC-dayKey alignment fix) → the **verbatim shipped** `StockSageNetCostSim`
+ `StockSageDeflatedSharpe` via `tools/altdata_ablation/build_and_run.sh`. Zero ported logic;
the only shim is the 11-line `StockSagePriceHistory` value container (byte-identical copy, no
logic). Bridge source: session scratchpad `baseline_bridge/main.swift` (compile line in the
detail below); reusable pattern documented here.

## Panel
- **81 US large-cap equities × 250 daily returns** (suffix-less symbols from the 209-entry
  cache; .SR/crypto/FX/index excluded), industry = shipped `StockSageSector` map → 8 groups
  (Technology, Healthcare, Other, Consumer, Financials, Industrials, Energy, Communication).
- roundTripBps = 13 (shipped US assumption). Earnings-exclusion EMPTY (never fabricated).
- Breadth 3–4× every prior equity panel (18–25 names); window LENGTH is the flip side —
  the cache trims to 252 bars ≈ 1 trading year (2025-07→2026-07), vs the 5y research panels.

## Result (industry-relative reversal, walk-forward, purge+embargo, selection-deflated over 12 configs)
| lb | hold | rebals | meanGross | meanNet | net DSR | clears |
|----|------|--------|-----------|---------|---------|--------|
| 5  | 5    | 49 | +0.00009 | −0.00084 | 0.013 | no |
| 5  | 10   | 24 | −0.00481 | −0.00573 | 0.010 | no |
| 5  | 21   | 11 | −0.02029 | −0.02110 | 0.000 | no |
| 10 | 5    | 48 | −0.00109 | −0.00173 | 0.001 | no |
| 10 | 10   | 24 | −0.00043 | −0.00134 | 0.019 | no |
| 10 | 21   | 11 | −0.01953 | −0.02037 | 0.009 | no |
| 21 | 5    | 45 | −0.00403 | −0.00446 | 0.000 | no |
| 21 | 10   | 22 | −0.00712 | −0.00774 | 0.001 | no |
| 21 | 21   | 10 | −0.01419 | −0.01506 | 0.007 | no |
| 63 | 5    | 37 | −0.00805 | −0.00827 | 0.000 | no |
| 63 | 10   | 18 | −0.01786 | −0.01817 | 0.000 | no |
| 63 | 21   | 8  | −0.02874 | −0.02922 | 0.002 | no |

**Best net DSR = 0.019 (lb=10, hd=10). ANY config clears DSR>0.95: NO.** Notably, 11 of 12
configs are negative even GROSS in this window — short-horizon reversal wasn't merely
cost-eaten (the usual finding), it was absent/inverted in 2025–26 large-caps; consistent with
a momentum-led regime.

## What this changes
1. **The shipped offline validation loop is CLOSED and working:** one owner app-session ⇒ a
   living, refreshable real-data panel with zero extra network. Every future ablation can run
   on the app's own data path (`bridge` pattern above). The audit L3-05 dayKey fix makes the
   MIXED-market (US+.SR+crypto) panel buildable too — this run used US-only (13bps homogeneous
   costs), the mixed panel is the natural next variant.
2. **Campaign milestone re-confirmed on the app's own data:** DSR ≈ 0 everywhere; the engine's
   value remains risk-discipline, not alpha. Reinforces the RefuseList naive-reversal stance
   and the honesty floor's "no proven edge" posture.
3. **NOT closed by this run:** the full-IRRX earnings-exclusion residual (needs earnings dates;
   exclusion left EMPTY here) and any long-horizon (12-1 momentum family) baseline — 250 bars
   cannot form a 126-bar-lookback walk-forward with meaningful rebalance counts.

## Honesty caveats
Power-limited: ~1y window, 8–49 rebalances per config, single (bull/momentum-led) regime;
survivorship-lite (today's constituents); US large-caps only. This run validates the
MACHINERY and re-measures the baseline on real app data — it does not (and cannot at this
power) overturn any 5y-panel conclusion. A null here is corroboration, not new disproof.
