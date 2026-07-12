#!/usr/bin/env python3
"""Forward paper-trade gauge — the one LIVE edge-detector (operationalizes the 2026-07-12
handoff watch item: "watch the lane you trade" + "re-check at n>=100 closes").

Reads the owner's real paper-trade store from the app's UserDefaults domain and computes
the forward R distribution on CLOSED trades, side-aware, from entry/exitPrice/stop.
STATUS TOOL, not a research result: at n<~100 this is a status read, never a claim.

Usage: python3 tools/paper_gauge.py            # human-readable
       python3 tools/paper_gauge.py --json     # machine-readable
"""
import subprocess, plistlib, json, statistics, sys, datetime

DOMAIN = "SA.Salehman-AI"
KEY = "stocksage.papertrades.v1"
POWER_N = 100          # ~HLZ t>3 needs ~100+ at the measured per-trade sd; below this = status only


def _deep(v):
    if isinstance(v, (bytes, bytearray)):
        try:
            return json.loads(v.decode("utf-8"))
        except Exception:
            try:
                return plistlib.loads(bytes(v))
            except Exception:
                return None
    return json.loads(v) if isinstance(v, str) else v


def _daykey(v):
    if isinstance(v, (int, float)):   # Cocoa reference date = 2001-01-01
        return (datetime.datetime(2001, 1, 1) + datetime.timedelta(seconds=v)).strftime("%Y-%m-%d")
    return str(v)[:10]


def gauge():
    r = subprocess.run(["defaults", "export", DOMAIN, "-"], capture_output=True)
    if r.returncode != 0:
        return {"error": "app defaults domain not readable (app never run on this machine?)"}
    d = plistlib.loads(r.stdout)
    kk = next((k for k in d if "papertrade" in k.lower().replace(".", "")), KEY if KEY in d else None)
    if not kk:
        return {"error": "no paper-trade store key present"}
    arr = _deep(d[kk])
    if not isinstance(arr, list):
        return {"error": f"paper store present but unparsed (type {type(d[kk]).__name__})"}
    closed = [t for t in arr if isinstance(t, dict) and t.get("closedAt")]
    rs, days = [], {}
    for t in closed:
        e, x, s = t.get("entry"), t.get("exitPrice"), t.get("stop")
        side = (t.get("side") or "Long").lower()
        if not (e and x and s) or e == s:
            continue
        R = (x - e) / (e - s) if ("long" in side or "buy" in side) else (e - x) / (s - e)
        rs.append(R)
        days[_daykey(t["closedAt"])] = days.get(_daykey(t["closedAt"]), 0) + 1
    out = {"records": len(arr), "closed": len(closed), "R_derivable": len(rs), "closes_by_day": days}
    if rs:
        mu, sd = statistics.mean(rs), statistics.pstdev(rs)
        t = mu / (sd / len(rs) ** 0.5) if sd else 0.0
        out.update({"win_rate": sum(1 for x in rs if x > 0) / len(rs), "avg_R": mu,
                    "total_R": sum(rs), "t_stat": t,
                    "median_R": statistics.median(rs), "min_R": min(rs), "max_R": max(rs),
                    "powered": len(rs) >= POWER_N,
                    "disposition": ("POWERED — treat as a real forward measurement" if len(rs) >= POWER_N
                                    else f"UNPOWERED (n={len(rs)} < {POWER_N}) — status read, NOT a result")})
    return out


def _closed_rows():
    """Closed trades with derived R + fields, for the behavioral breakdown."""
    r = subprocess.run(["defaults", "export", DOMAIN, "-"], capture_output=True)
    if r.returncode != 0:
        return []
    d = plistlib.loads(r.stdout)
    kk = next((k for k in d if "papertrade" in k.lower().replace(".", "")), KEY if KEY in d else None)
    arr = _deep(d[kk]) if kk else None
    if not isinstance(arr, list):
        return []
    out = []
    for t in arr:
        if not (isinstance(t, dict) and t.get("closedAt")):
            continue
        e, x, s = t.get("entry"), t.get("exitPrice"), t.get("stop")
        side = (t.get("side") or "Long").lower()
        if not (e and x and s) or e == s:
            continue
        long = "long" in side or "buy" in side
        R = (x - e) / (e - s) if long else (e - x) / (s - e)
        tg = t.get("target")
        if tg and ((long and x >= tg * 0.997) or (not long and x <= tg * 1.003)):
            how = "hit target"
        elif (long and x <= s * 1.003) or (not long and x >= s * 0.997):
            how = "hit/through stop"
        else:
            how = "closed early"
        out.append({"R": R, "how": how, "conviction": t.get("conviction"), "symbol": t.get("symbol")})
    return out


def detail():
    rows = _closed_rows()
    if not rows:
        print("no closed trades to break down"); return
    import collections
    n = len(rows)
    exits = collections.Counter(r["how"] for r in rows)
    print("\nBEHAVIORAL BREAKDOWN (descriptive — n too small for a verdict):")
    print(f"  HOW they closed (target break-even at 2:1 needs ~33% hitting target):")
    for how, c in exits.most_common():
        rr = [r["R"] for r in rows if r["how"] == how]
        print(f"    {how:18s} {c:2d}/{n} ({c/n:.0%})  avgR {statistics.mean(rr):+.2f}")
    convs = [(r["conviction"], r["R"]) for r in rows if r["conviction"] is not None]
    if len(convs) > 3 and len({c for c, _ in convs}) > 1:
        cs = [c for c, _ in convs]; rs = [r for _, r in convs]
        mc, mr = statistics.mean(cs), statistics.mean(rs)
        sc, sr = statistics.pstdev(cs), statistics.pstdev(rs)
        corr = sum((c - mc) * (r - mr) for c, r in convs) / (len(convs) * sc * sr) if sc and sr else 0
        print(f"  CONVICTION vs result: corr {corr:+.2f}  "
              f"({'your conviction has signal' if corr > 0.15 else 'conviction is NOT predicting your outcomes — the overconfidence trap, live'})")


def main():
    g = gauge()
    if "--json" in sys.argv:
        print(json.dumps(g, indent=1)); return
    if "error" in g:
        print(f"paper gauge: {g['error']}"); return
    print(f"FORWARD PAPER GAUGE  ({g['records']} records, {g['closed']} closed, {g['R_derivable']} R-derivable)")
    if g.get("R_derivable"):
        print(f"  win-rate {g['win_rate']:.0%}  avgR {g['avg_R']:+.3f}  totalR {g['total_R']:+.2f}  t={g['t_stat']:.2f}")
        print(f"  R spread: min {g['min_R']:+.2f} / median {g['median_R']:+.2f} / max {g['max_R']:+.2f}")
        print(f"  {g['disposition']}")
        print("  NOTE: this is the owner's own trading behavior, not an engine edge; at 1-3d holds "
              "it tests the fenced short-horizon regime (week-horizon research: net-negative at retail).")
        if "--detail" in sys.argv:
            detail()


if __name__ == "__main__":
    main()
