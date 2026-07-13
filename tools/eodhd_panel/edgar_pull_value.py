#!/usr/bin/env python3
"""EDGAR companyfacts extraction pull for the VALUE-factor ablation — DATA ACQUISITION ONLY
(no test statistic; prereg discipline preserved). Sibling of edgar_pull_gpa.py: same
mapped-name universe, same SEC fair-access pacing, same resumable-per-name design.

For every mapped name, pull companyfacts once and extract minimal per-fiscal-year records
for the value-factor ingredients the GP/A pull did NOT save:

  StockholdersEquity (book value, us-gaap USD, instant fact)
  NetIncomeLoss      (earnings, us-gaap USD, duration fact)
  shares outstanding (dei/EntityCommonStockSharesOutstanding + us-gaap/
                      CommonStockSharesOutstanding, 'shares' unit, instant)

Annual forms only (10-K/20-F/40-F + /A), every filed occurrence kept (the runner applies
the earliest-filed-per-FY as-of rule pinned in the prereg). Output does NOT overwrite the
GP/A edgar_facts/ files — separate dir.
Output: ~/.claude/salehman-universe/panels/eodhd_us_delisted/edgar_facts_value/<CODE>.json
"""
import json, os, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
OUTDIR = os.path.join(BASE, "edgar_facts_value")
UA = {"User-Agent": "Salehman AI research salehalayed98@gmail.com"}
ANNUAL = ("10-K", "10-K/A", "20-F", "20-F/A", "40-F", "40-F/A")
# Book value: primary StockholdersEquity; the ...IncludingNoncontrolling variant kept as a
# disclosed fallback tag (the runner pins priority, exactly like GP/A's Revenues/COGS lists).
EQ_TAGS = ["StockholdersEquity",
           "StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest"]
NI_TAGS = ["NetIncomeLoss"]
SH_TAGS_GAAP = ["CommonStockSharesOutstanding"]           # us-gaap, 'shares'
SH_TAGS_DEI = ["EntityCommonStockSharesOutstanding"]      # dei, 'shares'

os.makedirs(OUTDIR, exist_ok=True)


def extract(section, tags, unit, want_instant):
    """want_instant True → keep facts with an `end` and no meaningful duration (balance-sheet
    instants: equity, shares); False → duration facts (net income). We keep frame_start so the
    runner can apply the [340,380]-day duration guard for duration facts, identical to GP/A."""
    out = []
    for tag in tags:
        arr = (section.get(tag, {}).get("units", {}) or {}).get(unit, [])
        for x in arr:
            if x.get("form") in ANNUAL and x.get("fy") and x.get("fp") == "FY" and x.get("val") is not None:
                out.append({"tag": tag, "fy": x["fy"], "end": x.get("end"),
                            "filed": x.get("filed"), "val": x["val"], "form": x["form"],
                            "frame_start": x.get("start")})
    return out


def pull(item):
    code, cik = item
    dst = os.path.join(OUTDIR, code + ".json")
    if os.path.exists(dst):
        return "skip"
    url = f"https://data.sec.gov/api/xbrl/companyfacts/CIK{cik:010d}.json"
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers=UA)
            f = json.load(urllib.request.urlopen(req, timeout=40))
            gaap = (f.get("facts") or {}).get("us-gaap", {})
            dei = (f.get("facts") or {}).get("dei", {})
            rec = {"code": code, "cik": cik,
                   "equity": extract(gaap, EQ_TAGS, "USD", True),
                   "netincome": extract(gaap, NI_TAGS, "USD", False),
                   "shares_gaap": extract(gaap, SH_TAGS_GAAP, "shares", True),
                   "shares_dei": extract(dei, SH_TAGS_DEI, "shares", True)}
            tmp = dst + ".tmp"
            json.dump(rec, open(tmp, "w"))
            os.replace(tmp, dst)
            return "ok"
        except urllib.error.HTTPError as e:
            if e.code == 404:
                json.dump({"code": code, "cik": cik, "missing": True}, open(dst, "w"))
                return "404"
            time.sleep(2 * (attempt + 1))
        except Exception:
            time.sleep(2 * (attempt + 1))
    return "err"


def main():
    m = json.load(open(os.path.join(BASE, "edgar_cik_map.json")))["mapped"]
    items = sorted((c, v["cik"]) for c, v in m.items())
    print(f"pulling value-tag companyfacts for {len(items)} mapped names -> {OUTDIR}", flush=True)
    counts = {"ok": 0, "404": 0, "err": 0, "skip": 0}
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=6) as ex:
        for i, r in enumerate(ex.map(pull, items)):
            counts[r] += 1
            if i % 250 == 0:
                print(f"  {i}/{len(items)} {counts} t={time.time()-t0:.0f}s", flush=True)
            time.sleep(0.02)   # gentle global pacing on top of the worker cap
    print(f"DONE {counts} in {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
