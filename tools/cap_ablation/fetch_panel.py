#!/usr/bin/env python3
"""Fetch the FROZEN 20-symbol Yahoo v8 panel for the cap-vs-continuous ablation.
Stdlib only (urllib). Sequential, polite (delay + backoff on 429/5xx). Uses
adjclose (split/div-adjusted) exclusively. Aligns all 20 to ONE shared calendar
(intersect timestamps where every symbol has a non-null adjclose), then
sanity-gates each ALIGNED series for max|daily return| < 0.35 (a bigger jump =
split/data leak -> STOP, per spec; no silent pruning of names).
"""
import json
import sys
import time
import urllib.request

UNIVERSE = ["AAPL","MSFT","GOOGL","AMZN","NVDA","JPM","JNJ","PG","XOM","HD",
            "KO","WMT","CAT","DIS","V","MA","UNH","CVX","PEP","ADBE"]

UA = {"User-Agent": "Mozilla/5.0"}


def fetch_one(symbol: str, retries: int = 5) -> dict:
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?range=5y&interval=1d"
    delay = 2.0
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=20) as resp:
                if resp.status != 200:
                    raise RuntimeError(f"HTTP {resp.status}")
                data = json.loads(resp.read().decode("utf-8"))
            result = data["chart"]["result"][0]
            ts = result["timestamp"]
            adj = result["indicators"]["adjclose"][0]["adjclose"]
            assert len(ts) == len(adj), f"{symbol}: timestamp/adjclose length mismatch"
            return {"symbol": symbol, "ts": ts, "adj": adj}
        except Exception as e:
            if attempt == retries - 1:
                raise RuntimeError(f"{symbol}: fetch failed after {retries} tries: {e}")
            print(f"  {symbol}: retry {attempt+1}/{retries} after {e} (sleep {delay:.0f}s)", file=sys.stderr)
            time.sleep(delay)
            delay = min(delay * 2, 30)
    raise RuntimeError(f"{symbol}: unreachable")


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "panel.json"
    per_symbol = {}
    for i, sym in enumerate(UNIVERSE):
        print(f"fetching {sym} ({i+1}/{len(UNIVERSE)})...", file=sys.stderr)
        per_symbol[sym] = fetch_one(sym)
        time.sleep(0.6)  # polite spacing between sequential requests

    # Build per-symbol {ts: adjclose} dropping nulls, then intersect timestamps.
    maps = {}
    for sym, d in per_symbol.items():
        m = {t: a for t, a in zip(d["ts"], d["adj"]) if a is not None}
        maps[sym] = m

    common = set(maps[UNIVERSE[0]].keys())
    for sym in UNIVERSE[1:]:
        common &= set(maps[sym].keys())
    common_sorted = sorted(common)
    n = len(common_sorted)
    print(f"shared calendar: {n} bars (intersection over {len(UNIVERSE)} symbols)", file=sys.stderr)
    if n < 300:
        print(f"FATAL: shared calendar too thin ({n} bars) — stopping, not synthesizing data.", file=sys.stderr)
        sys.exit(1)

    adjclose = []
    for sym in UNIVERSE:
        series = [maps[sym][t] for t in common_sorted]
        # Sanity gate on the ALIGNED series: max|daily return| < 0.35, else STOP (split leak).
        max_abs_ret = 0.0
        for a, b in zip(series, series[1:]):
            if a > 0:
                r = abs(b / a - 1)
                max_abs_ret = max(max_abs_ret, r)
        if max_abs_ret >= 0.35:
            print(f"FATAL: {sym} max|daily return|={max_abs_ret:.4f} >= 0.35 on the aligned "
                  f"calendar — possible split/div leak. STOPPING per spec (no silent drop).",
                  file=sys.stderr)
            sys.exit(1)
        print(f"  {sym}: {len(series)} bars, max|daily ret|={max_abs_ret:.4f}", file=sys.stderr)
        assert len(series) == n, f"{sym}: aligned length {len(series)} != {n}"
        adjclose.append(series)

    panel = {
        "symbols": UNIVERSE,
        "dates": common_sorted,
        "adjclose": adjclose,
        "provenance": "Yahoo v8 chart, range=5y interval=1d, indicators.adjclose, "
                      "intersected shared calendar, fetched sequentially with polite backoff",
    }
    with open(out_path, "w") as f:
        json.dump(panel, f)
    print(f"wrote {out_path}: {len(UNIVERSE)} symbols x {n} bars", file=sys.stderr)


if __name__ == "__main__":
    main()
