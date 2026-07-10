#!/usr/bin/env python3
"""EVENT-EXTRACTION pass for the insider-Form-4 ablation — DATA-ONLY (no test statistic).
Implements PREREG_2026-07-10_insider_form4.md §Signal exactly:

  event   = NONDERIV_TRANS row: TRANS_CODE=P, TRANS_ACQUIRED_DISP_CD=A, TRANS_FORM_TYPE=4,
            accession DOCUMENT_TYPE=4, issuer CIK in the panel map, >=1 attributed owner
            with Officer/Director substring relationship
  routine = an attributed owner CIK with document-filtered P-purchases in the same issuer in
            calendar month M of each of years Y-1, Y-2, Y-3 (TRANS_DATE-keyed, purchases only)
  opportunistic event = NO attributed owner routine
  availability = FILING_DATE (strictly-after handled by the runner)
  sanitizer: TRANS_DATE year outside [2000, filing year] dropped + counted

Note (disclosure, second-order): the routineness classifier uses the COMPLETED purchase-month
history (the prereg's mechanical rule). A prior-year purchase FILED after an event's own filing
would not have been public at event time; Form 4's 2-business-day deadline makes this a
second-order effect, and it acts in the exclusion (conservative) direction.

Output: ~/.claude/salehman-universe/insider_sets/insider_events.json
        {code: [[filing_date, trans_date], ...]} opportunistic officer/director Form-4 buys,
        plus censuses i/iii/v.
"""
import csv, io, json, os, sys, zipfile
from collections import defaultdict, Counter

SETS = os.path.expanduser("~/.claude/salehman-universe/insider_sets")
BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
MON = {m: i + 1 for i, m in enumerate(["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"])}

def iso(d):
    """DD-MON-YYYY -> YYYY-MM-DD; None if malformed."""
    p = (d or "").split("-")
    if len(p) != 3 or p[1] not in MON or not (p[0].isdigit() and p[2].isdigit()):
        return None
    return f"{p[2]}-{MON[p[1]]:02d}-{int(p[0]):02d}"

# parse fixture assert (prereg: DD-MON-YYYY pinned)
assert iso("31-MAR-2015") == "2015-03-31" and iso("garbage") is None
print("selfcheck PASS: DD-MON-YYYY parse fixture")

m = json.load(open(os.path.join(BASE, "edgar_cik_map.json")))
cik2code = {}
for sect in ("mapped", "mapped_screened"):
    for code, v in m.get(sect, {}).items():
        cik2code[v["cik"]] = code
manifest_delist = {}
with open(os.path.join(BASE, "manifest.jsonl")) as f:
    for line in f:
        r = json.loads(line)
        if r.get("status") == "ok":
            manifest_delist[r["code"]] = r["delist"]
print(f"panel CIKs: {len(cik2code)}")

# pass 1: collect document-filtered officer/director P-purchases for panel issuers
purchases = []          # (issuer_cik, filing_iso, trans_iso, frozenset(owner_ciks))
hist = defaultdict(set)  # (issuer_cik, owner_cik) -> {(year, month)}
cnt = Counter()
zips = sorted(f for f in os.listdir(SETS) if f.endswith(".zip"))
for zi, zn in enumerate(zips):
    z = zipfile.ZipFile(os.path.join(SETS, zn))
    sub = {}
    with z.open("SUBMISSION.tsv") as f:
        for row in csv.DictReader(io.TextIOWrapper(f, "latin-1"), delimiter="\t"):
            try:
                cik = int(row["ISSUERCIK"])
            except (ValueError, KeyError):
                continue
            if cik in cik2code and row.get("DOCUMENT_TYPE") == "4":
                sub[row["ACCESSION_NUMBER"]] = (cik, iso(row.get("FILING_DATE")))
    owners = defaultdict(list)
    with z.open("REPORTINGOWNER.tsv") as f:
        for row in csv.DictReader(io.TextIOWrapper(f, "latin-1"), delimiter="\t"):
            acc = row.get("ACCESSION_NUMBER")
            if acc in sub:
                rel = (row.get("RPTOWNER_RELATIONSHIP") or "")
                odc = ("Officer" in rel) or ("Director" in rel)
                try:
                    owners[acc].append((int(row["RPTOWNERCIK"]), odc))
                except (ValueError, KeyError, TypeError):
                    continue
    with z.open("NONDERIV_TRANS.tsv") as f:
        for row in csv.DictReader(io.TextIOWrapper(f, "latin-1"), delimiter="\t"):
            if row.get("TRANS_CODE") != "P": continue
            cnt["p_rows"] += 1
            acc = row["ACCESSION_NUMBER"]
            meta = sub.get(acc)
            if meta is None: cnt["drop_docfilter_or_nonpanel"] += 1; continue
            if row.get("TRANS_FORM_TYPE") != "4": cnt["drop_formtype"] += 1; continue
            if row.get("TRANS_ACQUIRED_DISP_CD") != "A": cnt["drop_dispcode"] += 1; continue
            td, fd = iso(row.get("TRANS_DATE")), meta[1]
            if not td or not fd or not (2000 <= int(td[:4]) <= int(fd[:4])):
                cnt["drop_sanitizer"] += 1; continue
            ow = owners.get(acc, [])
            if not any(odc for _, odc in ow): cnt["drop_not_offdir"] += 1; continue
            all_ciks = frozenset(c for c, _ in ow)
            purchases.append((meta[0], fd, td, all_ciks))
            y, mo = int(td[:4]), int(td[5:7])
            for oc in all_ciks:
                hist[(meta[0], oc)].add((y, mo))
    if zi % 10 == 0:
        print(f"  {zi}/{len(zips)} {zn} purchases={len(purchases)}", flush=True)

# pass 2: opportunistic classification (any-routine => excluded)
events = defaultdict(list)
yr_census = defaultdict(lambda: Counter())
for cik, fd, td, ow in purchases:
    y, mo = int(td[:4]), int(td[5:7])
    routine = any(all((yy, mo) in hist[(cik, oc)] for yy in (y - 1, y - 2, y - 3)) for oc in ow)
    yr_census[td[:4]]["filtered"] += 1
    if routine:
        yr_census[td[:4]]["routine"] += 1
        cnt["routine_excluded"] += 1
    else:
        yr_census[td[:4]]["opportunistic"] += 1
        events[cik2code[cik]].append([fd, td])

for code in events: events[code].sort()
out = os.path.join(SETS, "insider_events.json")
json.dump({"events": events, "counts": dict(cnt),
           "by_year": {y: dict(c) for y, c in sorted(yr_census.items())}}, open(out, "w"))

print(f"\nCENSUS (i): counts={dict(cnt)}")
print("year: filtered / opportunistic / routine")
for y in sorted(yr_census):
    c = yr_census[y]
    print(f"  {y}: {c['filtered']:6d} / {c['opportunistic']:6d} / {c['routine']:5d}")
# census (iii): delisted vs active event coverage
d_ev = a_ev = 0
for code, evs in events.items():
    if manifest_delist.get(code, "9999") < "2026-06-01": d_ev += len(evs)
    else: a_ev += len(evs)
print(f"CENSUS (iii): opportunistic events on DELISTED names {d_ev} vs ACTIVE {a_ev}")
print(f"CENSUS (v): officer/director filter applied at row level; drop_not_offdir={cnt['drop_not_offdir']}")
print(f"names with >=1 event: {len(events)}; total opportunistic events: {sum(len(v) for v in events.values())}")
print(f"-> {out}")
