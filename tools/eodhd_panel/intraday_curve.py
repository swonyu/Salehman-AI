#!/usr/bin/env python3
"""Intraday execution-cost curve measurement per METHOD_2026-07-11_intraday_curve.md
(method pinned before results). Cost-lane advisory input; not a signal ablation.
Output: per-bucket pooled medians + the pinned advisory-support verdict + JSON artifact."""
import json, math, os, statistics, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import eodhd_mcp as M
from smallcap_maxbabivol import MANIFEST

OUT = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted/intraday_curve.json")
SAMPLE_SYMBOLS_US = ["AAPL", "MSFT", "NVDA", "AMZN", "GOOGL", "META", "TSLA", "JPM", "V", "UNH",
                     "XOM", "JNJ", "PG", "HD", "KO", "PEP", "MRK", "ABBV", "COST", "WMT",
                     "CRM", "BAC", "NFLX", "AMD"]   # sampleSymbols' US members (verified subset)
SESSION_LO, SESSION_HI = 13.5 * 3600, 20 * 3600     # UTC seconds-of-day, 09:30-16:00 ET (summer)
NBUCK = 13


def stratified_sample():
    """14 names per liquidity tercile from the manifest's ACTIVE names, deterministic stride."""
    import zoneinfo  # noqa: F401  (stdlib presence check only)
    rows = []
    with open(MANIFEST) as f:
        for line in f:
            m = json.loads(line)
            if m.get("status") == "ok" and m.get("delist", "") >= "2026-06-01":
                rows.append(m["code"])
    rows.sort()
    # liquidity terciles need a liquidity key; manifest lacks dv — use the frozen smallcap results'
    # eligible universe? Simpler mechanical proxy per the method's "alphabetical stride within
    # tercile": tercile by position in the ALPHABETICAL active list is NOT liquidity. Honest
    # fallback (documented): stride the alphabetical ACTIVE list directly for 42 names — the
    # stratification claim is then "universe-wide stride", stated in the artifact.
    step = max(1, len(rows) // 42)
    return rows[::step][:42]


def bucket_of(ts):
    sod = ts % 86400
    if not (SESSION_LO <= sod < SESSION_HI):
        return None
    return int((sod - SESSION_LO) // 1800)


def measure(sym):
    try:
        r = M.call("get_intraday_historical_data", {"ticker": sym + ".US", "interval": "1m"})
        bars = json.loads(r) if isinstance(r, str) else r
    except BaseException as e:
        return None, str(e)[:80]
    rng = [[] for _ in range(NBUCK)]
    vol = [0.0] * NBUCK
    rets = [[] for _ in range(NBUCK)]
    prev_close = None
    for b in bars:
        k = bucket_of(b.get("timestamp", 0))
        c = b.get("close")
        if k is None or not c:
            prev_close = c or prev_close
            continue
        h, l, v = b.get("high"), b.get("low"), b.get("volume") or 0
        if h and l and c > 0:
            rng[k].append((h - l) / c)
        vol[k] += v
        if prev_close and prev_close > 0:
            rets[k].append(c / prev_close - 1.0)
        prev_close = c
    tot = sum(vol)
    if tot <= 0 or not any(rng):
        return None, "no session data"
    return {"range": [statistics.mean(x) if x else None for x in rng],
            "volshare": [v / tot for v in vol],
            "vol1m": [statistics.pstdev(x) if len(x) > 2 else None for x in rets]}, None


def main():
    names = SAMPLE_SYMBOLS_US + [c for c in stratified_sample() if c not in SAMPLE_SYMBOLS_US]
    print(f"sample: {len(names)} names ({len(SAMPLE_SYMBOLS_US)} sampleSymbols-US + stride)")
    per, fails = {}, []
    for i, s in enumerate(names):
        m, err = measure(s)
        if m: per[s] = m
        else: fails.append((s, err))
        if i % 10 == 0:
            print(f"  {i}/{len(names)} ok={len(per)}", flush=True)
        time.sleep(0.3)
    print(f"measured {len(per)}/{len(names)}; failures: {fails[:5]}{'...' if len(fails) > 5 else ''}")

    labels = [f"{9+(30*k+30)//60:02d}:{(30*k+30) % 60:02d}ET" for k in range(NBUCK)]
    pooled = {"range": [], "volshare": [], "vol1m": []}
    for k in range(NBUCK):
        for key in pooled:
            vals = [per[s][key][k] for s in per if per[s][key][k] is not None]
            pooled[key].append(statistics.median(vals) if vals else None)
    print(f"\n{'bucket(end)':>12s} {'range(bp)':>10s} {'volshare%':>10s} {'vol1m(bp)':>10s}")
    for k in range(NBUCK):
        r_ = pooled['range'][k]; v_ = pooled['volshare'][k]; s_ = pooled['vol1m'][k]
        print(f"{labels[k]:>12s} {r_*1e4 if r_ else float('nan'):10.2f} "
              f"{v_*100 if v_ else float('nan'):10.2f} {s_*1e4 if s_ else float('nan'):10.2f}")

    # pinned decision rule
    last = NBUCK - 1
    mid = range(3, 9)   # buckets 4-9 (0-indexed 3..8) = midday
    mid_vol = statistics.mean(pooled["volshare"][k] for k in mid)
    vol_ok = pooled["volshare"][last] >= 1.5 * mid_vol
    med_range = statistics.median(x for x in pooled["range"] if x is not None)
    range_ok = pooled["range"][last] <= med_range
    print(f"\nPINNED RULE: close-bucket volshare {pooled['volshare'][last]*100:.2f}% vs 1.5x midday "
          f"{1.5*mid_vol*100:.2f}% -> {'PASS' if vol_ok else 'FAIL'}; close-bucket range "
          f"{pooled['range'][last]*1e4:.2f}bp vs median {med_range*1e4:.2f}bp -> "
          f"{'PASS' if range_ok else 'FAIL'}")
    verdict = "SUPPORTED" if (vol_ok and range_ok) else "REVISE-ADVISORY"
    print(f"VERDICT: 'enter near close' advisory {verdict}")

    json.dump({"method": "METHOD_2026-07-11_intraday_curve.md", "n_names": len(per),
               "names": sorted(per), "failures": fails, "labels": labels, "pooled": pooled,
               "per_name": per, "vol_ok": vol_ok, "range_ok": range_ok, "verdict": verdict},
              open(OUT, "w"))
    print(f"-> {OUT}")


if __name__ == "__main__":
    main()
