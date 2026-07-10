#!/usr/bin/env python3
"""ACCEPTANCE PHASE for the GP/A (gross profitability) ablation on the survivorship-free panel.
Data-quality measurement only — computes NO test statistic (prereg discipline: the prereg commits
before any hypothesis statistic; this script measures joinability + field coverage).

Step 1  ticker->CIK mapping for the panel's filter-passing names:
        (a) SEC company_tickers.json exact ticker match (current registrants);
        (b) unmatched: normalized company-NAME exact match, EODHD delisted_all.jsonl Name
            -> SEC cik-lookup-data.txt (conservative: exact normalized match only, ambiguous -> drop).
Step 2  coverage census: for a deterministic sample of mapped names, pull companyfacts and measure
        GrossProfit/(Revenue-COGS)/Assets presence in the XBRL era + `filed` date presence.

Outputs: edgar_cik_map.json + census printout. SEC fair-access: <=8 req/s, UA with contact.
"""
import json, os, re, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
ACC = os.path.expanduser("~/.claude/salehman-universe/eodhd_acceptance_2026-07-10")
OUT = os.path.join(BASE, "edgar_cik_map.json")
UA = {"User-Agent": "Salehman AI research salehalayed98@gmail.com"}
WIN_LO, WIN_HI = "2000-01-03", "2026-07-09"

def get(url, retries=3):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            return json.load(urllib.request.urlopen(req, timeout=30))
        except Exception:
            if i == retries - 1: raise
            time.sleep(1.5 * (i + 1))

def get_text(url):
    req = urllib.request.Request(url, headers=UA)
    return urllib.request.urlopen(req, timeout=60).read().decode("latin-1")

SUFFIX = re.compile(r"\b(INC|INCORPORATED|CORP|CORPORATION|CO|COMPANY|LTD|LIMITED|PLC|LP|LLC|HOLDINGS?|GROUP|THE|TRUST|SA|AG|NV)\b\.?")
def norm(name):
    s = re.sub(r"[^A-Z0-9 ]", " ", name.upper())
    s = SUFFIX.sub(" ", s)
    return re.sub(r"\s+", " ", s).strip()

def main():
    # panel filter-passing names (reuse the window census — cheap re-derivation from manifest + raw)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from smallcap_maxbabivol import prep_name
    rec = json.load(open(os.path.join(BASE, "GSPC_INDX.json")))
    mbars = rec["eod"] if isinstance(rec, dict) else rec
    wdates = [b["date"] for b in mbars if WIN_LO <= b["date"] <= WIN_HI]
    wpos = {d: i for i, d in enumerate(wdates)}
    cands = []
    with open(os.path.join(BASE, "manifest.jsonl")) as f:
        for line in f:
            m = json.loads(line)
            if m.get("status") == "ok" and m["first"] <= WIN_HI and m["delist"] >= WIN_LO:
                cands.append(m["code"])
    rej = {"short": 0, "entry_price": 0, "dollar_vol": 0, "gap": 0, "load": 0}
    passing = []
    for i, code in enumerate(cands):
        if i % 5000 == 0: print(f"  panel prep {i}/{len(cands)}", flush=True)
        nm = prep_name(code, wdates, wpos, rej)
        if nm is not None and not nm["screen"]:
            passing.append(code)
    print(f"panel filter-passing (clean): {len(passing)}")

    # (a) ticker match against SEC current registrants
    ct = get("https://www.sec.gov/files/company_tickers.json")
    tick2cik = {v["ticker"].upper(): int(v["cik_str"]) for v in ct.values()}
    mapped, unmatched = {}, []
    for c in passing:
        cik = tick2cik.get(c.upper().replace("-", ""))
        if cik: mapped[c] = {"cik": cik, "how": "ticker"}
        else: unmatched.append(c)
    print(f"ticker-matched: {len(mapped)}  unmatched: {len(unmatched)}")

    # (b) name match: EODHD delisted Name -> SEC cik-lookup (normalized exact; ambiguous dropped)
    eod_names = {}
    for fn in ("delisted_all.jsonl",):
        p = os.path.join(ACC, fn)
        if os.path.exists(p):
            with open(p) as f:
                for line in f:
                    r = json.loads(line)
                    eod_names[r["Code"]] = r.get("Name") or ""
    print(f"EODHD delisted names available: {len(eod_names)}")
    print("fetching SEC cik-lookup-data.txt (~90MB)...", flush=True)
    lookup = get_text("https://www.sec.gov/Archives/edgar/cik-lookup-data.txt")
    name2cik = {}
    for line in lookup.splitlines():
        # format: COMPANY NAME:CIK:
        parts = line.rsplit(":", 2)
        if len(parts) >= 2 and parts[1].strip().isdigit():
            n = norm(parts[0])
            if n:
                if n in name2cik and name2cik[n] != int(parts[1]):
                    name2cik[n] = -1          # ambiguous -> poison
                else:
                    name2cik.setdefault(n, int(parts[1]))
    name_hits = amb = 0
    for c in list(unmatched):
        nm = eod_names.get(c)
        if not nm: continue
        cik = name2cik.get(norm(nm))
        if cik and cik > 0:
            mapped[c] = {"cik": cik, "how": "name"}
            unmatched.remove(c); name_hits += 1
        elif cik == -1:
            amb += 1
    print(f"name-matched: {name_hits} (ambiguous skipped: {amb}); final mapped {len(mapped)}/{len(passing)} "
          f"({100*len(mapped)/len(passing):.1f}%), unmapped {len(unmatched)}")
    json.dump({"mapped": mapped, "unmapped": unmatched}, open(OUT, "w"))
    print(f"map -> {OUT}")

    # Step 2: coverage census on a deterministic sample (every Nth mapped name)
    codes = sorted(mapped)
    sample = codes[:: max(1, len(codes) // 120)][:120]
    print(f"census sample: {len(sample)} names (deterministic stride)")
    stats = {"cf_ok": 0, "cf_404": 0, "gp_direct": 0, "gp_derivable": 0, "assets": 0,
             "filed": 0, "usable": 0, "fy_min": [], "fy_max": []}
    def census(c):
        cik = mapped[c]["cik"]
        try:
            f = get(f"https://data.sec.gov/api/xbrl/companyfacts/CIK{cik:010d}.json")
        except Exception:
            return (c, None)
        g = (f.get("facts") or {}).get("us-gaap", {})
        def fys(tag):
            u = g.get(tag, {}).get("units", {})
            arr = u.get("USD") or (list(u.values())[0] if u else [])
            return sorted({x["fy"] for x in arr if x.get("form") in ("10-K", "20-F", "40-F") and x.get("fy")})
        gp = fys("GrossProfit")
        rev = fys("Revenues") + fys("RevenueFromContractWithCustomerExcludingAssessedTax") + fys("SalesRevenueNet")
        cogs = fys("CostOfGoodsAndServicesSold") + fys("CostOfRevenue") + fys("CostOfGoodsSold")
        assets = fys("Assets")
        arr = g.get("Assets", {}).get("units", {}).get("USD", [])
        filed = any(x.get("filed") for x in arr[:5])
        return (c, {"gp": bool(gp), "gpd": bool(rev) and bool(cogs), "assets": bool(assets),
                    "filed": filed, "fy": (min(assets or [0]), max(assets or [0]))})
    with ThreadPoolExecutor(max_workers=6) as ex:
        for c, r in ex.map(census, sample):
            if r is None:
                stats["cf_404"] += 1; continue
            stats["cf_ok"] += 1
            stats["gp_direct"] += r["gp"]; stats["gp_derivable"] += r["gpd"]; stats["assets"] += r["assets"]
            stats["filed"] += r["filed"]
            if (r["gp"] or r["gpd"]) and r["assets"]:
                stats["usable"] += 1
                stats["fy_min"].append(r["fy"][0]); stats["fy_max"].append(r["fy"][1])
    n = len(sample)
    print(f"\nCENSUS (n={n}): companyfacts present {stats['cf_ok']}/{n}, missing {stats['cf_404']}")
    print(f"  GrossProfit direct {stats['gp_direct']}  derivable(rev&cogs) {stats['gp_derivable']}  "
          f"Assets {stats['assets']}  filed-dates {stats['filed']}")
    print(f"  USABLE for GP/A (gp|gpd AND assets): {stats['usable']}/{n} = {100*stats['usable']/n:.0f}%")
    if stats["fy_min"]:
        import statistics as st
        print(f"  usable FY spans: median first FY {st.median(stats['fy_min'])}, median last FY {st.median(stats['fy_max'])}")

if __name__ == "__main__":
    main()
