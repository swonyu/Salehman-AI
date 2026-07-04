# stocksage CLI + MCP — design spec (2026-07-03)

**Goal (owner-approved):** a FREE `stocksage` CLI + thin MCP that lets any Claude chat query the
REAL StockSage engine — without re-implementing any of its math.

## Architecture (zero port risk)
```
Claude ⇄ thin MCP (Python FastMCP, ~50 lines) ⇄ shells out to ⇄ `stocksage` (Swift CLI)
                                                                    │
                                          compiles the 72 PURE StockSage/*.swift engine files
                                          (verified: only 5 are SwiftUI/Combine-coupled — excluded)
                                          + a thin main.swift that fetches data & calls the real API
```
The MCP is dumb plumbing. All money-math stays in the ONE tested implementation (the app's engine
files, compiled verbatim). No second copy of Kelly/EV/NetEdge/calibration to drift (F46 rule).

## Commands
- `stocksage netcost --entry E --stop S --target T --symbol SYM` → real `StockSageNetEdge.evaluate`:
  net R:R, break-even win-rate, cost breakdown by asset class. **Pure — no fetch. First TDD slice.**
- `stocksage idea SYM` → fetch daily history (free), call the real `StockSageAdvisor.advise(closes:…)`
  + `StockSageExpectedValue` + `StockSageNetEdge` → the idea card (action, signal-strength, EV gross,
  win% band, stop/target, net R:R) as JSON.
- (later) `stocksage ablate …` → reuse the shipped altdata_ablation runner.

## Free data (honest ceiling)
- Crypto (`-USD`): CoinGecko (keyless, unlimited) — fully free.
- Equities: the app's gentle Yahoo v8 path, ONE symbol at a time, ≥2s spacing, backoff on 429
  (never the bulk hammer — the poller owns bulk). Free but throttle-limited.
- Every output labels the data source + as-of date; nil = unknown, never fabricated.

## Honesty floor (carried verbatim from the engine)
- "signal strength" is a rules-based score, NOT P(profit); win% labeled assumed/measured.
- Gross vs net always labeled. The engine has NO PROVEN EDGE (DSR≈0) — the CLI says so.
- nil on insufficient data (e.g. <253 bars → trend nil), never a guessed number.

## Gates & process
- NO engine change — the CLI compiles the engine files READ-ONLY; it adds only `tools/stocksage_cli/`.
- TDD: each command gets a test (hand-derived expected values, per spec-fidelity) before it's "done".
- Build+test green (verdict line) → ship the new dir through the pipeline. No visual QA (not UI).
- Verification: CLI output cross-checked against the app's known engine outputs (same code ⇒ same numbers).

## Owner review
Docs-only design; the CLI/MCP are dev tools, not the shipped app. Owner can wire the MCP with
`claude mcp add stocksage -- python tools/stocksage_cli/mcp_server.py` once shipped.
