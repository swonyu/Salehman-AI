#!/usr/bin/env python3
"""Thin MCP server exposing the REAL StockSage engine via the `stocksage` CLI (zero port —
the CLI compiles the app's own engine files verbatim). Plumbing only; all math stays in Swift.

Run:  claude mcp add stocksage -- python3 tools/stocksage_cli/mcp_server.py
Requires: `pip install mcp` and a built `./stocksage` (run build.sh first).
"""
import json
import os
import subprocess

from mcp.server.fastmcp import FastMCP

CLI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stocksage")
mcp = FastMCP("stocksage")


def _run(args: list[str]) -> str:
    if not os.path.exists(CLI):
        return json.dumps({"error": f"CLI not built at {CLI} — run build.sh"})
    r = subprocess.run([CLI, *args], capture_output=True, text=True, timeout=20)
    return r.stdout.strip() if r.returncode == 0 else json.dumps({"error": r.stderr.strip()})


@mcp.tool()
def net_cost(entry: float, stop: float, target: float, symbol: str = "AAPL") -> str:
    """Net reward:risk, break-even win-rate, and cost breakdown for a trade, from the REAL
    StockSageNetEdge engine. Asset-class round-trip cost ESTIMATES (labeled, not venue quotes):
    US large-cap 13bps, intl 30, crypto 70, FX 7, index 8 — picked from the symbol suffix.
    The break-even win-rate p* = 1/(1+netRR) is the honest falsifiable bar: if the true hit-rate
    is below it, the setup loses money net of costs no matter how good the gross R:R looks.
    The engine has NO proven edge (Deflated Sharpe ≈ 0); its value is risk-discipline, not alpha."""
    return _run(["netcost", "--entry", str(entry), "--stop", str(stop),
                 "--target", str(target), "--symbol", symbol])


if __name__ == "__main__":
    mcp.run(transport="stdio")
