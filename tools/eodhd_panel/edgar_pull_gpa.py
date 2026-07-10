#!/usr/bin/env python3
"""EDGAR companyfacts extraction pull for the GP/A ablation — DATA ACQUISITION ONLY
(no test statistic; prereg discipline preserved). For every mapped name, pull
companyfacts once and extract minimal per-fiscal-year records:

  {fy, fp, form, end, filed, grossProfit, revenues, cogs, assets}

Annual forms only (10-K/20-F/40-F), USD units only, every filed occurrence kept
(the runner applies the earliest-filed-per-FY as-of rule pinned in the prereg).
Resumable per-name; SEC fair-access <=8 req/s via worker cap + pacing.
Output: ~/.claude/salehman-universe/panels/eodhd_us_delisted/edgar_facts/<CODE>.json
"""
import json, os, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
OUTDIR = os.path.join(BASE, "edgar_facts")
UA = {"User-Agent": "Salehman AI research salehalayed98@gmail.com"}
ANNUAL = ("10-K", "10-K/A", "20-F", "20-F/A", "40-F", "40-F/A")
GP_TAGS = ["GrossProfit"]
REV_TAGS = ["Revenues", "RevenueFromContractWithCustomerExcludingAssessedTax",
            "RevenueFromContractWithCustomerIncludingAssessedTax",
            "SalesRevenueNet", "SalesRevenueGoodsNet", "SalesRevenueServicesNet"]
COGS_TAGS = ["CostOfGoodsAndServicesSold", "CostOfRevenue", "CostOfGoodsSold", "CostOfServices"]
AST_TAGS = ["Assets"]

os.makedirs(OUTDIR, exist_ok=True)


def extract(facts, tags):
    out = []
    g = (facts.get("facts") or {}).get("us-gaap", {})
    for tag in tags:
        arr = (g.get(tag, {}).get("units", {}) or {}).get("USD", [])
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
            rec = {"code": code, "cik": cik,
                   "gp": extract(f, GP_TAGS), "rev": extract(f, REV_TAGS),
                   "cogs": extract(f, COGS_TAGS), "assets": extract(f, AST_TAGS)}
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
    print(f"pulling companyfacts for {len(items)} mapped names -> {OUTDIR}", flush=True)
    counts = {"ok": 0, "404": 0, "err": 0, "skip": 0}
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=6) as ex:
        for i, r in enumerate(ex.map(pull, items)):
            counts[r] += 1
            if i % 250 == 0:
                print(f"  {i}/{len(items)} {counts} t={time.time()-t0:.0f}s", flush=True)
            time.sleep(0.02)   # gentle global pacing on top of worker cap
    print(f"DONE {counts} in {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
