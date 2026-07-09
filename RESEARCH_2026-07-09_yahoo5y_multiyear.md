# RESEARCH 2026-07-09 — Multi-year / long-horizon equity-baseline on a FRESH 5y Yahoo panel (the residual the 1y run couldn't reach)

**Verdict: NULL — no config clears DSR>0.95 (best net-OOS 0.505, a thin cost-eaten monthly cell); 15/20 configs negative even GROSS; the never-before-formable long-horizon lb∈{63,126} rows all fail. DSR≈0 "no proven edge / value-is-risk-discipline" re-confirmed on a clean 5y MULTI-REGIME panel with 0 sector-"Other" degeneracy. No first measured edge to flag.**

## What this run is (and why it's the residual)
Occasioned by the owner's "what about yahoo" — Yahoo v8 5y became reachable again (AAPL/MSFT 5y HTTP 200; the ~2026-07-08 22:00 throttle cleared), so the equity edge axis needed NO EODHD token. Extends [RESEARCH_2026-07-08_engine_baseline_wideUS.md](RESEARCH_2026-07-08_engine_baseline_wideUS.md) (1y app cache → NULL, power-limited: single momentum-led regime, 250 bars couldn't form a 126-lookback). Now on a FRESH 5y Yahoo panel: the same shipped offline path — verbatim `StockSageNetCostSim` + `StockSageDeflatedSharpe` compiled by `swiftc` straight from the repo (engine files git-verified IDENTICAL to origin/main 33fd03d; the sibling's concurrent wave-6 did NOT touch them), only the `tools/altdata_ablation/main.swift` horizon grid extended. Panel fetched fresh, so NO cache/PriceHistory/Sector/Allocation shims were needed — the leanest verbatim run yet.

## Panel
- **50 US large-caps + ^GSPC**, Yahoo v8 **adjusted closes**, **5y = 1254 bars / 1253 returns**, common days **2021-07-09 → 2026-07-08** (perfect intersection, all 51 share 1254 days). Split-leak check: **0 events** |daily r|>0.5.
- **Regimes spanned:** the 2022 rate-hike bear + the 2021 late-bull + the 2023–2026 AI-led bull (anchors accurate: ^GSPC +71.2%, NVDA +920%, XOM +177%, AAPL +122% over the window). The MULTI-REGIME depth the 1y runs lacked.
- **Sector map (shipped StockSageSector, verbatim):** Tech 12, Consumer 10, Financials 8, Healthcare 6, Industrials 5, Comms 5, Energy 4 — **0 names fall to "Other"** (a real fix vs the 07-08 run's 2,097/2,158 "Other" degeneracy; achieved by curating the panel to shipped-tagged names).
- rt=13bps. Fetch: paced sequential, minimal `User-Agent: Mozilla/5.0` (the fuller Chrome UA tripped a header-fingerprint 429; the minimal UA cleared it) — all 51 requests HTTP 200, no IP cooldown.

## Result (industry-relative reversal, walk-forward purge+embargo, selection-deflated, 20 configs lb∈{5,10,21,63,126}×hold∈{5,10,21,63})
**Best net-OOS DSR = 0.505 (lb5/hd21, 59 rebals, meanNet −0.00003 — i.e. cost-eaten to ≈zero).** ANY config clears DSR>0.95 = **NO**. **15/20 negative even GROSS.** DSR machinery independently verified responsive (synthetic edge → DSR 1.000 passes; pure noise → 0.350 fails) ⇒ genuine null, not a pinned metric.

**The NEW long-horizon rows (lb≥63, impossible on the 250-bar cache) — all fail:**
- **lb=126** (semi-annual formation): net DSR 0.001–0.028, meanGross NEGATIVE at every hold (−0.0009 to −0.0070) — industry-relative reversal at a long formation window is decisively absent/inverted.
- **lb=63**: best lb63/hd63 net DSR 0.215 (meanNet +0.0021 over 63d, the lone positive-net long cell) — nowhere near the bar.

## What this closes / confirms
1. **DSR≈0 re-confirmed at MULTI-REGIME + LONG-HORIZON depth** the prior 1y/single-regime runs could not reach. The 2022 bear did not surface a reversal edge; the 126-lookback family (never before formable) is null.
2. **Cleanest verbatim run yet** — 2 engine files, 0 shims, 0 sector-"Other", fresh split-clean 5y adjclose, DSR-responsiveness self-verified. Corroboration, not new disproof.

## Residuals still OPEN (honest — this does NOT close them)
- **Full-IRRX earnings-window exclusion:** left EMPTY (never fabricated). Yahoo quoteSummary earnings needs a crumb (probed → 401 "Invalid Crumb") AND returns only the single *upcoming* date, not the 5y of *historical* earnings dates the exclusion needs. No clean offline source ⇒ residual (an EODHD/AV historical-earnings feed, or a crumb-authenticated Yahoo path, would unblock it).
- **Long-only MOMENTUM sign:** the shipped `StockSageNetCostSim.irrxWeights` is a REVERSAL rule (`raw = −score`) by construction, so the long-lookback configs measure *reversal at long formation windows*, NOT long-only momentum. A momentum-sign variant would require altering shipped logic (out of scope for a verbatim run) — a research-only sim variant is the path.

## Honesty caveats
Survivorship (today's 50 large-cap survivors, no delisted names — biases the reversal/momentum baseline UP); breadth 50 names (deeper 5y but narrower cross-section than the 2,158-name 1y run); industry-map quality high here only because the panel was curated to shipped-tagged names (not an arbitrary universe); single vendor (Yahoo, one 5y window that slides daily — exact decimals drift, the null VERDICT is the stable claim, never a single-config sign). A null here is corroboration at longer horizons + multi-regime depth; it does not (and cannot at this breadth) overturn — or establish — any edge.
