#!/usr/bin/env python3
"""Supplemental ticker->CIK mapping + companyfacts pull for the 249 integrity-SCREENED names
(S2b's no-screen universe needs their fundamentals too, else the S2b conjunct degenerates).
Same conservative match policy as edgar_map_census.py; appends to edgar_cik_map.json under
"mapped_screened"; pulls into the same edgar_facts/ dir. Data acquisition only."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from edgar_map_census import get, get_text, norm, ACC
from edgar_pull_gpa import pull

BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
MAP = os.path.join(BASE, "edgar_cik_map.json")

screened = [s[0] for s in json.load(open(os.path.join(BASE, "smallcap_maxbabivol_results.json")))["screened_names"]]
print(f"screened names: {len(screened)}")
m = json.load(open(MAP))
ct = get("https://www.sec.gov/files/company_tickers.json")
tick2cik = {v["ticker"].upper(): int(v["cik_str"]) for v in ct.values()}
mapped, unmatched = {}, []
for c in screened:
    cik = tick2cik.get(c.upper().replace("-", ""))
    if cik: mapped[c] = {"cik": cik, "how": "ticker"}
    else: unmatched.append(c)
eod_names = {}
with open(os.path.join(ACC, "delisted_all.jsonl")) as f:
    for line in f:
        r = json.loads(line)
        eod_names[r["Code"]] = r.get("Name") or ""
lookup = get_text("https://www.sec.gov/Archives/edgar/cik-lookup-data.txt")
name2cik = {}
for line in lookup.splitlines():
    parts = line.rsplit(":", 2)
    if len(parts) >= 2 and parts[1].strip().isdigit():
        n = norm(parts[0])
        if n:
            if n in name2cik and name2cik[n] != int(parts[1]): name2cik[n] = -1
            else: name2cik.setdefault(n, int(parts[1]))
hits = 0
for c in list(unmatched):
    nm = eod_names.get(c)
    cik = name2cik.get(norm(nm)) if nm else None
    if cik and cik > 0:
        mapped[c] = {"cik": cik, "how": "name"}; unmatched.remove(c); hits += 1
print(f"screened mapped: {len(mapped)}/{len(screened)} (ticker {len(mapped)-hits} + name {hits}); unmapped {len(unmatched)}")
m["mapped_screened"] = mapped
json.dump(m, open(MAP, "w"))
for i, (c, v) in enumerate(sorted(mapped.items())):
    r = pull((c, v["cik"]))
    if i % 50 == 0: print(f"  pull {i}/{len(mapped)} last={r}", flush=True)
print("screened pull DONE")
