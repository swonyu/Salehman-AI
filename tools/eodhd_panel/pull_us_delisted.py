#!/usr/bin/env python3
"""EODHD survivorship-free US delisted panel — PHASE 1: raw pull (prices + splits).

Implements the MANDATORY rules from the acceptance verdict
(~/.claude/salehman-universe/eodhd_acceptance_2026-07-10.md — CONDITIONAL x3):
  - stores RAW close/volume + the splits ledger ONLY; vendor adjusted_close is
    recorded but NEVER consumed downstream (per-value clamp at 999999.9999);
    reconstruction happens in the separate panel-build step, not here.
  - universe = the acceptance run's persisted 33,351-name delisted list,
    filtered: Type == "Common Stock", no "_old" incarnations, no warrant/unit
    suffixes (-WT/-WS/-U/-R), no test tickers (ZTEST/ZBZX).
  - resumable: one JSON file per name under OUTDIR; existing non-empty files
    are skipped, so restarts/rate-limit days lose nothing.
  - rate-aware: 2 calls/name (eod + splits) x ~30k names ~= 60k calls vs the
    100k/day paid limit; gentle pacing + hard stop at BUDGET calls/run.

Token: read from the Keychain at runtime via eodhd_mcp.call (never printed).
Usage:
  python3 tools/eodhd_panel/pull_us_delisted.py [--limit N] [--budget N] [--codes A,B,C]
"""
import argparse, json, os, re, sys, threading, time
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import eodhd_mcp as M

UNIVERSE = os.path.expanduser(
    "~/.claude/salehman-universe/eodhd_acceptance_2026-07-10/delisted_all.jsonl")
OUTDIR = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted/raw")
STATE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted/pull_state.json")
WARRANT_SUFFIX = re.compile(r"-(WT|WS|U|R)$")
TEST_TICKERS = {"ZTEST", "ZBZX"}


def universe_codes():
    codes = []
    with open(UNIVERSE) as f:
        for line in f:
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            code = r.get("Code", "")
            if r.get("Type") != "Common Stock":
                continue
            if code.endswith("_old") or "_old" in code:
                continue
            if WARRANT_SUFFIX.search(code) or code in TEST_TICKERS:
                continue
            codes.append(code)
    # de-dup preserving order (venue-chunked list can repeat codes across files)
    seen, out = set(), []
    for c in codes:
        if c not in seen:
            seen.add(c)
            out.append(c)
    return out


def fetch_one(code):
    tick = f"{code}.US"
    eod = M.call("get_historical_stock_prices",
                 {"ticker": tick, "period": "d", "fmt": "json"})
    splits = M.call("get_historical_splits", {"ticker": tick, "fmt": "json"})
    return {"code": code, "pulled_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "eod": json.loads(eod) if eod.strip().startswith("[") else eod,
            "splits": json.loads(splits) if splits.strip().startswith("[") else splits}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="max names this run (0 = all)")
    ap.add_argument("--budget", type=int, default=90000, help="max API calls this run")
    ap.add_argument("--codes", default="", help="comma-separated explicit codes (smoke mode)")
    args = ap.parse_args()

    os.makedirs(OUTDIR, exist_ok=True)
    codes = [c.strip() for c in args.codes.split(",") if c.strip()] or universe_codes()
    if args.limit:
        codes = codes[: args.limit]

    pending = []
    skipped = 0
    for code in codes:
        out = os.path.join(OUTDIR, f"{code}.json")
        if os.path.exists(out) and os.path.getsize(out) > 2:
            skipped += 1
        else:
            pending.append(code)
    max_names = args.budget // 2
    if len(pending) > max_names:
        print(f"BUDGET: {len(pending)} pending, capping this run at {max_names} names")
        pending = pending[:max_names]

    lock = threading.Lock()
    stats = {"done": 0, "errors": 0}
    t0 = time.time()

    def work(code):
        out = os.path.join(OUTDIR, f"{code}.json")
        try:
            rec = fetch_one(code)
            tmp = out + ".tmp"
            with open(tmp, "w") as f:
                json.dump(rec, f)
            os.replace(tmp, out)
            with lock:
                stats["done"] += 1
        except (SystemExit, Exception) as e:  # RPC/tool/network error — record, continue
            with lock:
                stats["errors"] += 1
                with open(os.path.join(OUTDIR, "_errors.jsonl"), "a") as f:
                    f.write(json.dumps({"code": code, "err": str(e)[:300]}) + "\n")
        with lock:
            n = stats["done"] + stats["errors"]
            if n and n % 200 == 0:
                rate = n / max(1e-9, time.time() - t0)
                eta_h = (len(pending) - n) / max(rate, 1e-9) / 3600
                print(f"[{n}/{len(pending)}] done={stats['done']} errors={stats['errors']} "
                      f"rate={rate:.1f}/s eta={eta_h:.1f}h", flush=True)
                with open(STATE, "w") as f:
                    json.dump({"done": stats["done"], "skipped": skipped,
                               "errors": stats["errors"], "pending": len(pending),
                               "at": time.strftime("%H:%M:%S")}, f)

    # 8 workers ~ 5-6 calls/s: well inside the 100k/day paid quota, gentle on the server.
    with ThreadPoolExecutor(max_workers=8) as ex:
        list(ex.map(work, pending))
    print(f"RUN COMPLETE: pulled={stats['done']} skipped={skipped} errors={stats['errors']} "
          f"elapsed={time.time()-t0:.0f}s outdir={OUTDIR}")


if __name__ == "__main__":
    main()
