#!/usr/bin/env python3
# fetch_panel.py — TSMOM multi-asset ablation panel fetcher (stdlib only).
# Universe FROZEN 2026-07-09 BEFORE any data was seen (ablation-harness recipe step 1):
# 16 liquid multi-asset ETFs, 6 asset classes, all listed pre-2011 -> full 10y coverage.
# Yahoo v8 chart endpoint (the same endpoint StockSageQuoteService uses), ADJCLOSE
# (bond/commodity ETF distributions would otherwise fake downtrends in raw closes).
# Output: panel_tsmom_multiasset.json {labels, assetClass, timestamps, returns[][]}
# where returns[s][t] = adjclose[t+1]/adjclose[t] - 1 on the intersected calendar.
import json, time, urllib.request

FROZEN = [  # (symbol, asset class)
    ("SPY", "us-equity"), ("QQQ", "us-equity"), ("IWM", "us-equity"),
    ("EFA", "intl-equity"), ("EEM", "intl-equity"),
    ("TLT", "bond"), ("IEF", "bond"), ("LQD", "bond"), ("HYG", "bond"),
    ("GLD", "commodity"), ("SLV", "commodity"), ("DBC", "commodity"), ("USO", "commodity"),
    ("VNQ", "reit"),
    ("UUP", "fx"), ("FXE", "fx"),
]

def fetch(sym):
    u = f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}?range=10y&interval=1d"
    req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
    r = json.load(urllib.request.urlopen(req, timeout=30))
    res = r["chart"]["result"][0]
    ts = res["timestamp"]
    adj = res["indicators"]["adjclose"][0]["adjclose"]
    # drop null bars (halts) keeping ts alignment
    pairs = [(t, a) for t, a in zip(ts, adj) if a is not None]
    return pairs

def main():
    data = {}
    for sym, _ in FROZEN:
        pairs = fetch(sym)
        data[sym] = dict(pairs)
        print(f"{sym}: {len(pairs)} bars  {time.strftime('%Y-%m-%d', time.gmtime(pairs[0][0]))} -> {time.strftime('%Y-%m-%d', time.gmtime(pairs[-1][0]))}")
        time.sleep(1.5)  # gentle on the throttle
    # intersect calendars (all NYSE-traded; intersection guards half-days/halts)
    common = sorted(set.intersection(*[set(d.keys()) for d in data.values()]))
    print(f"common calendar: {len(common)} bars")
    labels = [s for s, _ in FROZEN]
    classes = [c for _, c in FROZEN]
    prices = [[data[s][t] for t in common] for s in labels]
    # split-leak guard: max |1-day move| sanity print per symbol (adjusted series
    # should have no unexplained >50% jumps in these ETFs)
    rets = [[p[i+1] / p[i] - 1.0 for i in range(len(p) - 1)] for p in prices]
    for s, r in zip(labels, rets):
        mx = max(abs(x) for x in r)
        flag = "  <-- INSPECT" if mx > 0.5 else ""
        print(f"max|r| {s}: {mx:.3f}{flag}")
    out = {"frozenAt": "2026-07-09", "labels": labels, "assetClass": classes,
           "timestamps": common, "returns": rets}
    with open("tools/tsmom_multiasset/panel_tsmom_multiasset.json", "w") as f:
        f.write(json.dumps(out))
    print("wrote tools/tsmom_multiasset/panel_tsmom_multiasset.json")

if __name__ == "__main__":
    main()
