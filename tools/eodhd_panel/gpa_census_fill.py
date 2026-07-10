#!/usr/bin/env python3
"""POST-HOC CENSUS FILL for the completed GP/A run (audit findings F10/F11):
the prereg-mandated censuses (i, second half) and (iv) that the runner did not print.
DATA-ONLY — computes NO test statistic (no returns, no diffs, no DSR); prereg-safe
per the audit's explicit ruling. Appends the two censuses to the results JSON.

  census i-b : per-year count of staleness-dropped name-instances (H63 grid) whose
               name subsequently DIES in-window (last valid print < last master bar)
  census iv  : per-year eligible counts (H63 grid, first rebalance of each year)
"""
import json, math, os, sys, bisect, statistics

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from smallcap_maxbabivol import prep_name, MANIFEST, MARKET, BASE, MIN_NAMES
from gpa_quality import build_signal_events, FACTS, WIN_LO, WIN_HI, FRESH

OUT = os.path.join(BASE, "gpa_quality_results.json")

rec = json.load(open(MARKET))
mbars = rec["eod"] if isinstance(rec, dict) else rec
wdates = [b["date"] for b in mbars if WIN_LO <= b["date"] <= WIN_HI]
wpos = {d: i for i, d in enumerate(wdates)}
N = len(wdates)

cands = []
with open(MANIFEST) as f:
    for line in f:
        m = json.loads(line)
        if m.get("status") == "ok" and m["first"] <= WIN_HI and m["delist"] >= WIN_LO:
            cands.append(m["code"])
rej = {"short": 0, "entry_price": 0, "dollar_vol": 0, "gap": 0, "load": 0}
clean = []
for i, code in enumerate(cands):
    if i % 5000 == 0: print(f"  prep {i}/{len(cands)}", flush=True)
    nm = prep_name(code, wdates, wpos, rej)
    if nm is not None and not nm["screen"]:
        clean.append(nm)
print(f"clean={len(clean)}")

sigmap = {}
for nm in clean:
    path = os.path.join(FACTS, nm["code"] + ".json")
    if not os.path.exists(path): continue
    r = json.load(open(path))
    if r.get("missing"): continue
    evs, _ = build_signal_events(r)
    pos = [(bisect.bisect_right(wdates, filed), end, g) for end, filed, g in evs
           if bisect.bisect_right(wdates, filed) < N]
    if pos: sigmap[nm["code"]] = pos

last_print = {nm["code"]: max((j for j in range(N) if not math.isnan(nm["open"][j])), default=-1)
              for nm in clean}
eligible_by_year, stale_die_by_year, stale_total_by_year = {}, {}, {}
H = 63
seen_years = set()
for p in range(0, N - 1 - H, H):
    y = wdates[p][:4]
    first_of_year = y not in seen_years
    seen_years.add(y)
    elig = stale = stale_die = 0
    for nm in clean:
        code = nm["code"]
        if math.isnan(nm["open"][p + 1]): continue
        evs = sigmap.get(code)
        if not evs: continue
        cur = None
        for av, end, g in reversed(evs):
            if av <= p: cur = av; break
        if cur is None: continue
        if cur < p - FRESH + 1:
            stale += 1
            if last_print[code] < N - 1: stale_die += 1
            continue
        dvw = any(not math.isnan(nm["dv"][j]) for j in range(max(0, p - 62), p + 1))
        if dvw: elig += 1
    stale_total_by_year[y] = stale_total_by_year.get(y, 0) + stale
    stale_die_by_year[y] = stale_die_by_year.get(y, 0) + stale_die
    if first_of_year:
        eligible_by_year[y] = elig
print("census iv — eligible at first H63 rebalance of each year:")
print("  " + " ".join(f"{y}:{c}" for y, c in sorted(eligible_by_year.items())))
print("census i-b — staleness-dropped instances (H63 grid, summed/yr) and the subset whose name dies in-window:")
print("  " + " ".join(f"{y}:{stale_total_by_year[y]}/{stale_die_by_year[y]}" for y in sorted(stale_total_by_year)))

d = json.load(open(OUT))
d["census_iv_eligible_by_year"] = eligible_by_year
d["census_ib_stale_total_by_year"] = stale_total_by_year
d["census_ib_stale_then_dies_by_year"] = stale_die_by_year
json.dump(d, open(OUT, "w"), indent=1)
print(f"appended to {OUT}")
