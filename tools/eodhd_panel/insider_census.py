#!/usr/bin/env python3
"""ACCEPTANCE CENSUS for the insider-Form-4 lane — DATA-ONLY (no test statistic).
Sweeps all 80 quarterly SEC insider data-set ZIPs: schema stability, join coverage
vs the survivorship-free panel (by ISSUERCIK against edgar_cik_map.json, secondary
ISSUERTRADINGSYMBOL), open-market purchase (TRANS_CODE=P) counts by year, and the
officer/director share of purchase filings. Output feeds the prereg's Data section."""
import csv, io, json, os, sys, zipfile
from collections import Counter

SETS = os.path.expanduser("~/.claude/salehman-universe/insider_sets")
BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
m = json.load(open(os.path.join(BASE, "edgar_cik_map.json")))
panel_ciks = {v["cik"] for v in m["mapped"].values()} | {v["cik"] for v in m.get("mapped_screened", {}).values()}
panel_ticks = {c.upper() for c in list(m["mapped"]) + list(m.get("mapped_screened", {}))}
print(f"panel join keys: {len(panel_ciks)} CIKs, {len(panel_ticks)} tickers")

yr_purch = Counter(); yr_purch_panel = Counter(); yr_sell_panel = Counter()
officer_purch = 0; total_purch_filings = 0
schema_issues = []
zips = sorted(f for f in os.listdir(SETS) if f.endswith(".zip"))
print(f"quarters: {len(zips)}")
for zi, zn in enumerate(zips):
    try:
        z = zipfile.ZipFile(os.path.join(SETS, zn))
        # accession -> (issuer cik int, is Form 4)
        sub = {}
        with z.open("SUBMISSION.tsv") as f:
            r = csv.DictReader(io.TextIOWrapper(f, "latin-1"), delimiter="\t")
            for row in r:
                try:
                    sub[row["ACCESSION_NUMBER"]] = (int(row["ISSUERCIK"]), row.get("DOCUMENT_TYPE", ""),
                                                    (row.get("ISSUERTRADINGSYMBOL") or "").upper())
                except (ValueError, KeyError):
                    continue
        officers = set()
        with z.open("REPORTINGOWNER.tsv") as f:
            r = csv.DictReader(io.TextIOWrapper(f, "latin-1"), delimiter="\t")
            for row in r:
                if (row.get("RPTOWNER_RELATIONSHIP") or "").upper().find("OFFICER") >= 0 \
                   or (row.get("RPTOWNER_RELATIONSHIP") or "").upper().find("DIRECTOR") >= 0:
                    officers.add(row["ACCESSION_NUMBER"])
        purch_accs = set()
        with z.open("NONDERIV_TRANS.tsv") as f:
            r = csv.DictReader(io.TextIOWrapper(f, "latin-1"), delimiter="\t")
            for row in r:
                code = row.get("TRANS_CODE")
                if code not in ("P", "S"):
                    continue
                d = row.get("TRANS_DATE", "")
                y = d[-4:] if len(d) >= 4 else "?"
                acc = row["ACCESSION_NUMBER"]
                meta = sub.get(acc)
                if code == "P":
                    yr_purch[y] += 1
                    if meta and meta[0] in panel_ciks:
                        yr_purch_panel[y] += 1
                    purch_accs.add(acc)
                elif meta and meta[0] in panel_ciks:
                    yr_sell_panel[y] += 1
        officer_purch += len(purch_accs & officers)
        total_purch_filings += len(purch_accs)
    except (KeyError, zipfile.BadZipFile) as e:
        schema_issues.append((zn, str(e)[:60]))
    if zi % 10 == 0:
        print(f"  {zi}/{len(zips)} {zn}", flush=True)

print("\nP-code purchases by year (all / panel-joined):")
for y in sorted(yr_purch):
    print(f"  {y}: {yr_purch[y]:7d} / {yr_purch_panel[y]:7d}   (panel S-code sells: {yr_sell_panel[y]:7d})")
print(f"\npurchase filings with officer/director reporter: {officer_purch}/{total_purch_filings} "
      f"= {100*officer_purch/max(1,total_purch_filings):.0f}%")
print(f"schema issues: {schema_issues if schema_issues else 'none'}")
out = {"purchases_by_year": dict(yr_purch), "panel_purchases_by_year": dict(yr_purch_panel),
       "panel_sells_by_year": dict(yr_sell_panel),
       "officer_purchase_filings": officer_purch, "total_purchase_filings": total_purch_filings,
       "schema_issues": schema_issues}
json.dump(out, open(os.path.join(SETS, "insider_census.json"), "w"), indent=1)
print(f"-> {os.path.join(SETS, 'insider_census.json')}")
