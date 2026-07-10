#!/usr/bin/env python3
"""EODHD survivorship-free panel — PHASE 2: reconstruction + audit (pure, offline).

Consumes phase-1 raw pulls (raw close/volume + splits ledger) and emits per-name
split-adjusted PRICE-RETURN series + a manifest of per-name flags, implementing the
MANDATORY rules from ~/.claude/salehman-universe/eodhd_acceptance_2026-07-10.md:

  R1  Adjusted returns are reconstructed from RAW close × per-epoch split factors —
      vendor adjusted_close is NEVER consumed (per-value clamp at 999999.9999).
      Back-adjustment: adj(t) = close(t) × Π_{splits s: s.date > t} (old_s / new_s).
      Validated on the acceptance run's SEC-verified boundaries (<0.001%); this
      builder re-asserts the DRYS 2016-03-11 boundary (−0.213894…) at import time.
  R2  Clamp audit (report-only, we reconstruct anyway): count sentinel rows
      (adjusted_close == 999999.9999) and guard-band rows (close × remaining
      factor > 9e5) per name.
  R3  Delist date = last bar with volume > 0 — NEVER the last row (trailing
      zero-volume placeholder rows are common). Series truncated there.
  R4  Continuity gate: flag internal gaps > ~10 trading days (16 calendar) and
      splits dated outside the served, truncated price range.
  R5  Rename-chain hygiene (ETRM class): splits dated after the delist date are
      successor artifacts — dropped from reconstruction, flagged.
      Splits predating all price data (CBDE class): informational flag (within-
      range returns are unaffected).
  R6  PRICE-RETURN ONLY: dividends were not pulled (the dividends endpoint caps
      at value=1000 with garbage back-fill on high-factor names) — the manifest
      says so; total-return is a later, SEC-assisted increment.

Usage: python3 tools/eodhd_panel/build_panel.py [--limit N] [--codes A,B,C]
"""
import argparse, json, os, sys

BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
RAWDIR = os.path.join(BASE, "raw")
OUTDIR = os.path.join(BASE, "returns")
MANIFEST = os.path.join(BASE, "manifest.jsonl")
SENTINEL = 999999.9999


def parse_split(s):
    """'1.000000/25.000000' → (new, old); back-adjust factor for prior prices = old/new."""
    new, old = s.split("/")
    return float(new), float(old)


def build_one(code, rec):
    bars = rec.get("eod")
    splits_raw = rec.get("splits")
    flags = []
    if not isinstance(bars, list) or len(bars) < 2:
        return None, ["no_price_data"]
    if not isinstance(splits_raw, list):
        splits_raw = []

    # R3: delist date = last volume>0 bar; truncate there.
    last_traded = None
    for b in reversed(bars):
        if (b.get("volume") or 0) > 0:
            last_traded = b["date"]
            break
    if last_traded is None:
        return None, ["never_traded"]
    bars = [b for b in bars if b["date"] <= last_traded]
    if len(bars) < 2:
        return None, ["single_traded_bar"]
    first, delist = bars[0]["date"], last_traded
    if bars and bars[-1]["date"] != rec["eod"][-1]["date"]:
        flags.append("trailing_zero_volume_rows_truncated")

    # R5: split hygiene relative to the truncated range.
    splits = []
    for s in splits_raw:
        d = s.get("date", "")
        try:
            new, old = parse_split(s.get("split", ""))
        except (ValueError, AttributeError):
            flags.append("unparseable_split")
            continue
        if new <= 0 or old <= 0:   # degenerate vendor record (e.g. "1/0") — cannot adjust across it
            flags.append("degenerate_split_ratio")
            continue
        if d > delist:
            flags.append("successor_splits_dropped")   # ETRM rename class
            continue
        if d < first:
            flags.append("splits_predate_prices")      # CBDE class — informational
            continue
        splits.append((d, new, old))
    splits.sort()

    # R1: back-adjustment factor per bar: product of old/new for all splits AFTER t.
    # Walk backward, multiplying the factor when passing each split date.
    factor = 1.0
    si = len(splits) - 1
    adj = [0.0] * len(bars)
    for i in range(len(bars) - 1, -1, -1):
        d = bars[i]["date"]
        while si >= 0 and splits[si][0] > d:
            _, new, old = splits[si]
            factor *= old / new
            si -= 1
        adj[i] = bars[i]["close"] * factor

    # R2: clamp audit (report-only).
    sentinel_rows = sum(1 for b in bars if b.get("adjusted_close") == SENTINEL)
    # guard band: close × factor-remaining-at-that-bar > 9e5 — recompute cheaply
    guard_rows = sum(1 for i, b in enumerate(bars)
                     if b["close"] > 0 and adj[i] / b["close"] * b["close"] > 9e5)
    if sentinel_rows:
        flags.append(f"clamped_rows={sentinel_rows}")
    if guard_rows:
        flags.append(f"guard_band_rows={guard_rows}")

    # R4: continuity — calendar-gap proxy for >10 trading days.
    from datetime import date as D
    def toD(s): y, m, dd = s.split("-"); return D(int(y), int(m), int(dd))
    max_gap = 0
    for i in range(1, len(bars)):
        g = (toD(bars[i]["date"]) - toD(bars[i - 1]["date"])).days
        if g > max_gap:
            max_gap = g
    if max_gap > 16:
        flags.append(f"gap_days={max_gap}")

    rets = []
    for i in range(1, len(bars)):
        if adj[i - 1] > 0:
            rets.append([bars[i]["date"], adj[i] / adj[i - 1] - 1.0])
    out = {"code": code, "first": first, "delist": delist, "n_bars": len(bars),
           "n_returns": len(rets), "n_splits": len(splits),
           "return_basis": "price-only (R6)", "flags": sorted(set(flags)),
           "returns": rets}
    return out, out["flags"]


def selfcheck():
    """Assert the SEC-verified DRYS boundary before building anything."""
    p = os.path.join(RAWDIR, "DRYS.json")
    if not os.path.exists(p):
        print("selfcheck: DRYS.json not pulled yet — skipping (will assert when present)")
        return
    rec = json.load(open(p))
    out, _ = build_one("DRYS", rec)
    r = dict((d, v) for d, v in out["returns"])
    got = r.get("2016-03-11")
    want = (2.15 / 25) / 0.1094 - 1.0     # SEC-verified boundary from the acceptance run
    assert got is not None and abs(got - want) < 1e-9, f"DRYS boundary mismatch: {got} vs {want}"
    print(f"selfcheck PASS: DRYS 2016-03-11 reconstructed return = {got:+.6f} (SEC-verified boundary)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--codes", default="")
    args = ap.parse_args()
    os.makedirs(OUTDIR, exist_ok=True)
    selfcheck()

    files = sorted(f for f in os.listdir(RAWDIR) if f.endswith(".json"))
    if args.codes:
        want = {c.strip() for c in args.codes.split(",")}
        files = [f for f in files if f[:-5] in want]
    if args.limit:
        files = files[: args.limit]

    built = skipped = rejected = 0
    flag_census = {}
    with open(MANIFEST, "w") as mf:
        for f in files:
            code = f[:-5]
            outp = os.path.join(OUTDIR, f)
            try:
                rec = json.load(open(os.path.join(RAWDIR, f)))
            except json.JSONDecodeError:
                rejected += 1
                mf.write(json.dumps({"code": code, "status": "rejected", "flags": ["bad_raw_json"]}) + "\n")
                continue
            out, flags = build_one(code, rec)
            for fl in flags:
                key = fl.split("=")[0]
                flag_census[key] = flag_census.get(key, 0) + 1
            if out is None:
                rejected += 1
                mf.write(json.dumps({"code": code, "status": "rejected", "flags": flags}) + "\n")
                continue
            with open(outp, "w") as g:
                json.dump(out, g)
            built += 1
            mf.write(json.dumps({"code": code, "status": "ok", "first": out["first"],
                                 "delist": out["delist"], "n_returns": out["n_returns"],
                                 "n_splits": out["n_splits"], "flags": out["flags"]}) + "\n")
    print(f"BUILD COMPLETE: built={built} rejected={rejected} of {len(files)} raw files")
    print("flag census:", json.dumps(flag_census, indent=0, sort_keys=True))


if __name__ == "__main__":
    main()
