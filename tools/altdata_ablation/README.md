# altdata_ablation — Yahoo-independent net-of-cost IRRX ablation runner

Feeds a real return panel through the **verbatim shipped** `StockSageNetCostSim` +
`StockSageDeflatedSharpe` (compiled against the app's real source — zero reimplementation) to get an
honest net-of-cost DSR verdict, **without** touching the throttled Yahoo v8 endpoint. Sweeps a
horizon grid with selection-deflation and reports net DSR **with vs without** the earnings-window
exclusion (the OPEN FRONTIER #1 residual). Context: `skills/money-campaign-map`,
`RESEARCH_2026-07-03_altdata_netcost_harness.md`.

## Run
```bash
./build_and_run.sh path/to/panel.json
```

## panel.json shape
```json
{
  "returns": [[Double]],          // returns[s][t] = symbol s's SIMPLE return in period t (shared date axis)
  "industry": [Int],              // industry[s] = group id for the industry-relative demeaning
  "earningsExcludedAt": {"<t>": [Int]},   // optional: symbol indices to drop at a rebalance starting at t
  "roundTripBps": Double,         // StockSageNetEdge.defaultCosts(forSymbol:).roundTripBps (US 13, intl 30, crypto 70, ...)
  "labels": [String], "provenance": "source + as-of + honesty label"
}
```

## Fetching a panel (Yahoo-free)
- **Crypto (keyless, abundant):** CoinGecko `coins.marketChart` daily → align → simple returns.
  Category → `industry`; `roundTripBps=70`. (Fenced-domain: machinery validation, not a campaign edge.)
- **Equity (the campaign target) — FETCH-AND-GO via EODHD (2026-07-04).** `fetch_eodhd_panel.py`
  builds a split-adjusted 24-name/6-sector US panel from EODHD's `adjusted_close` (the RAW
  `TIME_SERIES_DAILY`/close has split jumps that fabricate returns — never use it). One command:
  ```bash
  EODHD_API_TOKEN=xxxxx ./fetch_and_ablate.sh              # base run
  EODHD_API_TOKEN=xxxxx ./fetch_and_ablate.sh --earnings   # + IRRX earnings-window exclusion (the "X")
  ```
  The fetch→parse→returns path is validated offline against the KEYLESS demo token (AAPL.US only):
  `python3 fetch_eodhd_panel.py --self-test` (confirmed 1256 adjusted bars, max|r|=15% ⇒ no split
  leak). It aligns on the INTERSECTION of trading dates (no fabricated bars), sets `roundTripBps=13`
  (US), sector → `industry`, and populates `earningsExcludedAt` from EODHD earnings dates when
  `--earnings` is passed (else EMPTY, never fabricated). Other split-adjusted paths still work too:
  the Yahoo poller's panel once the throttle clears, or a premium AV key.

## Earnings-window exclusion (operationalization — a documented choice, not the code's default)
Mark symbol `s` excluded at a rebalance formed at period `t` if `s` has an earnings date within a
fixed **±10-trading-day** window of `t` (config-independent earnings blackout ≈ Novy-Marx RRLP's
earnings-window removal). Sensitivity to the window width is untested — vary it before trusting a
close call.

## Honesty / gate
A DSR>0.95 pass is necessary but **not** sufficient to wire anything — engine activation is
owner-gated (RANKING #10). Null results are the expected, valid deliverable; index them per
`skills/research-memory`. Never present gross figures as achievable net.
