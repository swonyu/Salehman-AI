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
    try:
        # 40s > the CLI's own ~30s CoinGecko fetch wait, so a slow-but-successful fetch isn't killed here.
        r = subprocess.run([CLI, *args], capture_output=True, text=True, timeout=40)
    except subprocess.TimeoutExpired:
        return json.dumps({"error": "stocksage timed out (>40s)"})
    except OSError as e:  # e.g. a present-but-non-executable binary (PermissionError)
        return json.dumps({"error": f"failed to run stocksage: {e}"})
    if r.returncode != 0:
        return json.dumps({"error": r.stderr.strip() or f"stocksage exited {r.returncode}"})
    return r.stdout.strip()


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


@mcp.tool()
def deflated_sharpe(returns: str, trials: int = 1, var_trial_sharpe: float = 0.0) -> str:
    """Per-period Sharpe, PSR, and the DEFLATED Sharpe from the real StockSageDeflatedSharpe, for a
    comma-separated return series (≥4 per-period returns, e.g. "0.02,-0.01,0.03,0.0"). `passesDSRbar`
    = DSR > 0.95 — the honest "real edge" bar. `trials` (≥2) with `var_trial_sharpe` applies the
    selection-bias haircut (DSR drops below PSR: the more strategy variants you searched, the higher
    the bar). trials=1 ⇒ DSR==PSR (no haircut). The shipped engine's measured DSR ≈ 0 (no proven edge)."""
    args = ["deflated-sharpe", "--returns", returns, "--trials", str(trials)]
    if var_trial_sharpe:
        args += ["--var-trial-sharpe", str(var_trial_sharpe)]
    return _run(args)


@mcp.tool()
def indicators(coin: str, days: int = 365) -> str:
    """Real StockSageIndicators for a CRYPTO symbol on FREE CoinGecko daily closes (keyless; the
    equity/Yahoo path stays throttled, so this is crypto-only). Returns rsi14, sma50/sma200,
    tsMomentum12_1 (12-1 trend), trendOK, efficiencyRatio (<0.30 = ranging), annualizedVol (a
    FRACTION). `coin` is the CoinGecko id — "bitcoin", "ethereum", "solana" — NOT the ticker.
    nil = unknown (insufficient history: trendOK/tsMomentum need ~253 bars), never fabricated.
    Analysis, not advice; the engine has no proven edge (DSR ≈ 0)."""
    return _run(["indicators", "--coin", coin, "--days", str(days)])


if __name__ == "__main__":
    mcp.run(transport="stdio")
