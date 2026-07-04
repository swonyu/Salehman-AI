# stocksage CLI + MCP

A **free** command-line + MCP interface to the REAL StockSage engine — for querying the money-math
from any Claude chat (or a shell) without re-implementing anything. The CLI compiles the app's own
pure engine files verbatim (**zero port risk** — one implementation, no drift).

## Build & check
```bash
bash tools/stocksage_cli/build.sh      # compiles ./stocksage from the real engine files
bash tools/stocksage_cli/check.sh      # verifies netcost vs a hand-derivation (spec-fidelity)
```

## Commands (v1)
```bash
stocksage netcost --entry 100 --stop 95 --target 110 --symbol AAPL
```
→ net reward:risk, break-even win-rate `p* = 1/(1+netRR)`, and the round-trip cost breakdown from
the real `StockSageNetEdge`. Asset-class cost ESTIMATES by symbol suffix (US 13bps, `.`-intl 30,
`-USD` crypto 70, `=X` FX 7, `^` index 8) — labeled, never venue quotes.

## MCP (query from Claude chats)
macOS system python is externally-managed (PEP 668), so the MCP runs from a dedicated venv:
```bash
bash tools/stocksage_cli/setup_mcp.sh    # creates .venv, installs mcp, builds the CLI, prints the add command
```
It prints the exact registration command (absolute paths, since Claude runs it from elsewhere):
```bash
claude mcp add stocksage -- /ABS/PATH/tools/stocksage_cli/.venv/bin/python /ABS/PATH/tools/stocksage_cli/mcp_server.py
```
Exposes the `net_cost` tool. The MCP is dumb plumbing; all math stays in the compiled Swift engine.
> Note: run these from a checkout that actually has `tools/stocksage_cli/` (it shipped at commit
> `a93ef37`). If your working tree is behind, `git pull` first.

## Honesty floor (inherited from the engine)
- The engine has **no proven edge** (Deflated Sharpe ≈ 0) — its value is risk-discipline, not alpha.
  Every output says so.
- Costs are labeled estimates; gross vs net always labeled; nil = unknown (never fabricated).

## Scope & roadmap (honest limitations)
- **v1 = decoupled engine math only** (`netcost`). Cleanly compiles from `StockSageNetEdge` +
  `StockSageLiquidity` + `StockSageAllocation` (3 files, zero port).
- **`idea <SYM>` (advise pipeline) is NOT here yet.** `StockSageAdvisor.advise` → `ExpectedValue` →
  `StockSageIdea`, and `StockSageIdea` lives in the SwiftUI-coupled `StockSageStore`. Exposing the
  full idea card standalone needs either an app-side decoupling of `StockSageIdea` out of the Store,
  or an Xcode CLI target that links the app engine module. Deferred to increment 2 (a real task,
  not a hack) — will NOT be done by porting the math (that would be the F46 drift bug).
