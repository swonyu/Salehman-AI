#!/usr/bin/env python3
"""EDGAR companyfacts extraction pull for the ACCRUALS (Sloan 1996) ablation — DATA ACQUISITION
ONLY (no test statistic; prereg discipline preserved). Sibling of edgar_pull_value.py: same
mapped-name universe, same SEC fair-access pacing, same resumable-per-name design.

Sloan (1996) balance-sheet accruals need the working-capital line items the GP/A + value pulls
did NOT save. Per fiscal year (annual forms, USD, instant balance-sheet facts):

  AssetsCurrent, CashAndCashEquivalentsAtCarryingValue  (ΔCA − ΔCash)
  LiabilitiesCurrent, LongTermDebtCurrent/DebtCurrent, AccruedIncomeTaxesCurrent  (ΔCL − ΔSTD − ΔTP)
  DepreciationDepletionAndAmortization / Depreciation  (the depreciation term)
  Assets  (the average-total-assets denominator — re-pulled for a self-contained dataset)

Accruals(t) = [(ΔCA − ΔCash) − (ΔCL − ΔSTD − ΔTP) − Dep] / avg(Assets_t, Assets_{t-1})
(the runner forms Δ over consecutive FYs, applies the [340,380]d interval guard, and the as-of
availability = max(filed) over all ingredient records). Every filed occurrence kept; the runner
applies earliest-filed-per-(end,tag). Output: separate edgar_facts_accruals/ dir.
Output: ~/.claude/salehman-universe/panels/eodhd_us_delisted/edgar_facts_accruals/<CODE>.json
"""
import json, os, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
OUTDIR = os.path.join(BASE, "edgar_facts_accruals")
UA = {"User-Agent": "Salehman AI research salehalayed98@gmail.com"}
ANNUAL = ("10-K", "10-K/A", "20-F", "20-F/A", "40-F", "40-F/A")
# All INSTANT balance-sheet facts except depreciation (a DURATION flow). Grouped by role; the
# runner pins tag priority within each role, exactly like the value runner's Revenues/COGS lists.
TAG_GROUPS = {
    "assets": ["Assets"],
    "ca": ["AssetsCurrent"],
    "cash": ["CashAndCashEquivalentsAtCarryingValue", "CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents"],
    "cl": ["LiabilitiesCurrent"],
    "std": ["LongTermDebtCurrent", "DebtCurrent"],          # short-term/current portion of debt
    "tp": ["AccruedIncomeTaxesCurrent"],                    # taxes payable (minor; may be absent)
}
DEP_TAGS = ["DepreciationDepletionAndAmortization", "Depreciation", "DepreciationAndAmortization"]

os.makedirs(OUTDIR, exist_ok=True)


def extract_instant(g, tags):
    out = []
    for tag in tags:
        arr = (g.get(tag, {}).get("units", {}) or {}).get("USD", [])
        for x in arr:
            if x.get("form") in ANNUAL and x.get("fy") and x.get("fp") == "FY" and x.get("val") is not None:
                out.append({"tag": tag, "fy": x["fy"], "end": x.get("end"),
                            "filed": x.get("filed"), "val": x["val"], "form": x["form"]})
    return out


def extract_duration(g, tags):
    out = []
    for tag in tags:
        arr = (g.get(tag, {}).get("units", {}) or {}).get("USD", [])
        for x in arr:
            if x.get("form") in ANNUAL and x.get("fy") and x.get("fp") == "FY" and x.get("val") is not None:
                out.append({"tag": tag, "fy": x["fy"], "end": x.get("end"),
                            "filed": x.get("filed"), "val": x["val"], "form": x["form"],
                            "frame_start": x.get("start")})   # duration guard needs start
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
            g = (f.get("facts") or {}).get("us-gaap", {})
            rec = {"code": code, "cik": cik, "dep": extract_duration(g, DEP_TAGS)}
            for role, tags in TAG_GROUPS.items():
                rec[role] = extract_instant(g, tags)
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
    print(f"pulling accruals-tag companyfacts for {len(items)} mapped names -> {OUTDIR}", flush=True)
    counts = {"ok": 0, "404": 0, "err": 0, "skip": 0}
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=6) as ex:
        for i, r in enumerate(ex.map(pull, items)):
            counts[r] += 1
            if i % 250 == 0:
                print(f"  {i}/{len(items)} {counts} t={time.time()-t0:.0f}s", flush=True)
            time.sleep(0.02)
    print(f"DONE {counts} in {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
