#!/usr/bin/env python3
"""Build a split-adjusted equity return panel for the IRRX net-cost ablation from EODHD.

Fetch-and-go: given a real EODHD token, this turns OPEN FRONTIER #1's longest-open axis
(a powered, split-adjusted equity IRRX run) into ONE command. Stdlib-only (urllib/json).

  EODHD_API_TOKEN=xxxxx python3 fetch_eodhd_panel.py --out panel.json
  ./build_and_run.sh panel.json          # → net DSR with vs without earnings exclusion

Honesty:
  * Uses `adjusted_close` ONLY (raw close has split jumps that fabricate returns).
  * Aligns every symbol on the INTERSECTION of trading dates (a shared calendar — no
    forward-fill, no fabricated bars). A symbol missing too many dates is dropped, logged.
  * earnings-window exclusion (the IRRX "X", OPEN FRONTIER #1 residual) is populated from
    EODHD earnings dates when --earnings is passed AND the endpoint returns them; otherwise
    left EMPTY with an honest provenance note (never fabricated).
  * `--self-test` fetches AAPL.US with the KEYLESS demo token (the only symbol it serves) and
    validates the fetch→parse→returns path end-to-end WITHOUT a real token.

Not an edge claim — it only builds the panel; the runner's DSR>0.95 gate yields the verdict.
"""
import json, os, sys, urllib.request, urllib.parse, urllib.error, datetime

BASE = "https://eodhd.com/api"

# 24-name US panel, 6 sectors × 4 (mirrors the 2026-07-03 IRRX ablation's 24/6 shape).
UNIVERSE = [
    ("AAPL.US", 0), ("MSFT.US", 0), ("NVDA.US", 0), ("AVGO.US", 0),   # Technology
    ("JPM.US", 1),  ("BAC.US", 1),  ("GS.US", 1),   ("MS.US", 1),     # Financials
    ("JNJ.US", 2),  ("UNH.US", 2),  ("PFE.US", 2),  ("ABBV.US", 2),   # Healthcare
    ("XOM.US", 3),  ("CVX.US", 3),  ("COP.US", 3),  ("SLB.US", 3),     # Energy
    ("AMZN.US", 4), ("HD.US", 4),   ("MCD.US", 4),  ("NKE.US", 4),     # Consumer
    ("CAT.US", 5),  ("BA.US", 5),   ("HON.US", 5),  ("UPS.US", 5),     # Industrials
]
SECTOR_NAMES = ["Technology", "Financials", "Healthcare", "Energy", "Consumer", "Industrials"]


def _get(path, params):
    url = f"{BASE}/{path}?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.loads(r.read().decode())


def fetch_adjusted(symbol, token, d1, d2):
    """[(date_str, adjusted_close)] sorted ascending, or [] on failure."""
    try:
        rows = _get(f"eod/{symbol}", {"api_token": token, "fmt": "json",
                                      "from": d1, "to": d2, "period": "d"})
    except (urllib.error.URLError, ValueError) as e:
        print(f"  ! {symbol}: fetch failed ({e})", file=sys.stderr)
        return []
    out = []
    for row in rows:
        ac = row.get("adjusted_close")
        dt = row.get("date")
        if isinstance(ac, (int, float)) and ac > 0 and dt:
            out.append((dt, float(ac)))
    out.sort(key=lambda x: x[0])
    return out


def fetch_earnings_dates(symbol, token, d1, d2):
    """Reported earnings dates for a symbol in the window, or [] if unavailable."""
    try:
        js = _get(f"calendar/earnings", {"api_token": token, "fmt": "json",
                                         "symbols": symbol, "from": d1, "to": d2})
        return sorted({e["report_date"] for e in js.get("earnings", []) if e.get("report_date")})
    except (urllib.error.URLError, ValueError, KeyError):
        return []


def build_panel(token, d1, d2, with_earnings):
    series = {}
    for sym, _ in UNIVERSE:
        s = fetch_adjusted(sym, token, d1, d2)
        if len(s) > 60:
            series[sym] = dict(s)  # date -> adj
            print(f"  ✓ {sym}: {len(s)} adjusted bars")
        else:
            print(f"  ! {sym}: only {len(s)} bars — dropped", file=sys.stderr)

    kept = [(sym, ind) for sym, ind in UNIVERSE if sym in series]
    if len(kept) < 6:
        sys.exit("too few symbols fetched — need a real EODHD_API_TOKEN (demo serves AAPL.US only)")

    # Shared calendar = intersection of dates across all kept symbols (no fabricated bars).
    common = set.intersection(*[set(series[sym].keys()) for sym, _ in kept])
    dates = sorted(common)
    if len(dates) < 60:
        sys.exit(f"only {len(dates)} common dates across the panel — insufficient overlap")

    returns, industry, labels = [], [], []
    for sym, ind in kept:
        adj = [series[sym][d] for d in dates]
        rets = [adj[t] / adj[t - 1] - 1.0 for t in range(1, len(adj))]
        returns.append(rets)
        industry.append(ind)
        labels.append(sym)

    excluded = {}
    note_earn = "earnings-window exclusion NOT applied (base run)"
    if with_earnings:
        di = {d: i for i, d in enumerate(dates[1:])}  # returns are indexed from date[1]
        hit = 0
        for s_idx, (sym, _) in enumerate(kept):
            for ed in fetch_earnings_dates(sym, token, d1, d2):
                # drop symbol s at any rebalance period t whose date is within (ed-2, ed+2] trading days
                if ed in di:
                    for t in range(max(0, di[ed] - 2), min(len(dates) - 1, di[ed] + 3)):
                        excluded.setdefault(str(t), [])
                        if s_idx not in excluded[str(t)]:
                            excluded[str(t)].append(s_idx); hit += 1
        note_earn = (f"earnings-window exclusion APPLIED from EODHD earnings dates "
                     f"({hit} symbol-period drops)" if hit else
                     "earnings requested but EODHD returned no dates — exclusion EMPTY (not fabricated)")

    return {
        "returns": returns, "industry": industry,
        "earningsExcludedAt": excluded,
        "roundTripBps": 13.0,
        "labels": labels,
        "provenance": (f"EODHD adjusted_close, {len(kept)} US names / 6 sectors, "
                       f"{len(dates)} shared trading days {dates[0]}→{dates[-1]}; "
                       f"simple returns from adjusted_close; {note_earn}. "
                       f"Sectors: {', '.join(SECTOR_NAMES)}."),
    }


def self_test(d1, d2):
    """Validate fetch→parse→returns with the keyless demo token (AAPL.US only)."""
    print("SELF-TEST: EODHD demo token, AAPL.US (fetch→parse→returns path)")
    s = fetch_adjusted("AAPL.US", "demo", d1, d2)
    assert len(s) > 5, f"expected AAPL.US bars, got {len(s)}"
    adj = [p for _, p in s]
    rets = [adj[t] / adj[t - 1] - 1.0 for t in range(1, len(adj))]
    assert all(abs(r) < 0.5 for r in rets), "a >50% daily return implies a split-jump (raw close leaked in)"
    print(f"  ✓ {len(s)} adjusted bars {s[0][0]}→{s[-1][0]}; "
          f"first adj={adj[0]:.4f}, {len(rets)} returns, max|r|={max(abs(r) for r in rets):.4f}")
    print("  ✓ fetch/parse/returns path VALID — full run needs a real EODHD_API_TOKEN.")


if __name__ == "__main__":
    args = sys.argv[1:]
    d1 = "2020-07-01"
    d2 = datetime.date(2025, 7, 1).isoformat()
    if "--self-test" in args:
        self_test(d1, d2)
        sys.exit(0)
    token = os.environ.get("EODHD_API_TOKEN")
    if not token:
        sys.exit("set EODHD_API_TOKEN (or run --self-test with the keyless demo). "
                 "Get a token at https://eodhd.com; the whole validation axis is then one command.")
    out = args[args.index("--out") + 1] if "--out" in args else "panel.json"
    panel = build_panel(token, d1, d2, with_earnings=("--earnings" in args))
    with open(out, "w") as f:
        json.dump(panel, f)
    print(f"WROTE {out}: {len(panel['returns'])} symbols × {len(panel['returns'][0])} returns")
    print(f"PROVENANCE: {panel['provenance']}")
    print(f"NEXT: ./build_and_run.sh {out}")
