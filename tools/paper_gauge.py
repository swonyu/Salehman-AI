#!/usr/bin/env python3
"""Forward gauge — contrasts the ENGINE's auto-paper track vs the OWNER's own journal.

Corrects the 2026-07-12 first read: the paper store (`stocksage.papertrades.v1`) is
AUTO-FILLED by the engine from its own long-actionable ideas at every scan (StockSageStore
.updatePaperTrades -> StockSagePaperTrader.step) — it is the ENGINE's forward track, NOT the
owner's discretionary trades. The owner's own trades live in the JOURNAL
(`stocksage.journal.v1`, filled by the manual add form). This tool reads BOTH and contrasts
them — the honest "does the disciplined engine beat my gut" experiment. It is prospective:
the journal is empty until the owner logs real trades.

Two honesty caveats baked in:
  - SELECTION BIAS: only a fraction of paper trades have closed, fast. Stop-outs hit a tight
    boundary quickly; 2:1 targets take longer — so the early closers skew to losers. Below the
    ~all-resolved point, a negative read OVERSTATES; it is a status, never a verdict.
  - POWER: n<~100 closed-with-R => status read, not a claim (HLZ t>3 bar).

Usage: python3 tools/paper_gauge.py [--detail] [--json]
"""
import subprocess, plistlib, json, statistics, sys, collections, os

DOMAIN = "SA.Salehman-AI"
STORES = {"engine (auto paper)": "stocksage.papertrades.v1",
          "owner (own journal)": "stocksage.journal.v1"}
POWER_N = 100
CACHE = os.path.expanduser("~/Library/Application Support/salehman_history_cache.json")


def _cache_bars():
    """symbol -> [(epoch, high, low, close)] from the app's price cache (empty if absent)."""
    try:
        ents = json.load(open(CACHE))["entries"]
    except Exception:
        return {}
    out = {}
    for e in ents:
        sym = (e.get("symbol") or "").upper()
        if sym and e.get("dates") and e.get("highs") and e.get("lows") and e.get("closes"):
            out[sym] = list(zip(e["dates"], e["highs"], e["lows"], e["closes"]))
    return out


def _mark_to_market(arr, bars):
    """Full-book read: realized R for closed trades, else stop-first forward sim / latest-close mark
    against the cache. Removes the closed-only selection bias (fast stop-outs resolve first).
    Returns (marked_R_list, n_realized, n_unrealized) — unrealized marks lean OPTIMISTIC (open
    winners can still reverse), so this brackets the realized-only read from above."""
    full, realized, unreal = [], 0, 0
    for t in arr:
        e, s, tg = t.get("entry"), t.get("stop"), t.get("target")
        side = (t.get("side") or "Long").lower(); L = "long" in side or "buy" in side
        if not (e and s) or e == s:
            continue
        if t.get("closedAt") and t.get("exitPrice") is not None:
            x = t["exitPrice"]; full.append((x - e) / (e - s) if L else (e - x) / (s - e)); realized += 1; continue
        b = bars.get((t.get("symbol") or "").upper()); o = t.get("openedAt")
        if not b or not isinstance(o, (int, float)):
            continue
        fwd = [(h, l, c) for d, h, l, c in b if isinstance(d, (int, float)) and d > o]
        if not fwd:
            continue
        out = None
        for h, l, c in fwd:                       # stop-first (conservative), then target
            if (L and l <= s) or (not L and h >= s): out = -1.0; break
            if tg and ((L and h >= tg) or (not L and l <= tg)):
                out = (tg - e) / (e - s) if L else (e - tg) / (s - e); break
        if out is None:                           # still open -> unrealized mark at latest close
            c = fwd[-1][2]; out = (c - e) / (e - s) if L else (e - c) / (s - e); unreal += 1
        else:
            realized += 1
        full.append(out)
    return full, realized, unreal


def _deep(v):
    if isinstance(v, (bytes, bytearray)):
        try:
            return json.loads(v.decode("utf-8"))
        except Exception:
            try:
                return plistlib.loads(bytes(v))
            except Exception:
                return None
    return json.loads(v) if isinstance(v, str) else v


def _R(t):
    e, x, s = t.get("entry"), t.get("exitPrice"), t.get("stop")
    side = (t.get("side") or "Long").lower()
    if not (e and x and s) or e == s:
        return None
    return (x - e) / (e - s) if ("long" in side or "buy" in side) else (e - x) / (s - e)


def _exit_class(t):
    e, x, s, tg = t.get("entry"), t.get("exitPrice"), t.get("stop"), t.get("target")
    long = ("long" in (t.get("side") or "long").lower()) or ("buy" in (t.get("side") or "").lower())
    if tg and ((long and x >= tg * 0.997) or (not long and x <= tg * 1.003)):
        return "hit target"
    if (long and x <= s * 1.003) or (not long and x >= s * 0.997):
        return "hit/through stop"
    return "closed early"


def read_store(defaults, key):
    kk = next((k for k in defaults if key.split(".")[1] in k.lower() or k == key), None)
    if not kk:
        return None
    arr = _deep(defaults[kk])
    if not isinstance(arr, list):
        return None
    closed = [t for t in arr if isinstance(t, dict) and t.get("closedAt")]
    rows = [(t, _R(t)) for t in closed if _R(t) is not None]
    st = {"total": len(arr), "closed": len(closed), "resolved_frac": len(closed) / len(arr) if arr else 0}
    rs = [r for _, r in rows]
    if rs:
        mu, sd = statistics.mean(rs), statistics.pstdev(rs)
        st.update({"n": len(rs), "win": sum(1 for r in rs if r > 0) / len(rs), "avg_R": mu,
                   "total_R": sum(rs), "t": mu / (sd / len(rs) ** 0.5) if sd else 0.0,
                   "powered": len(rs) >= POWER_N,
                   "rows": rows})
    return st


def all_stores():
    r = subprocess.run(["defaults", "export", DOMAIN, "-"], capture_output=True)
    if r.returncode != 0:
        return {"error": "app defaults domain not readable"}
    d = plistlib.loads(r.stdout)
    return {label: read_store(d, key) for label, key in STORES.items()}


def main():
    s = all_stores()
    if "error" in s:
        print(f"gauge: {s['error']}"); return
    if "--json" in sys.argv:
        print(json.dumps({k: {kk: vv for kk, vv in (v or {}).items() if kk != "rows"}
                          for k, v in s.items()}, indent=1)); return
    for label, st in s.items():
        if st is None:
            print(f"{label:22s}  no store yet"); continue
        if not st.get("n"):
            print(f"{label:22s}  {st['total']} logged / {st['closed']} closed / 0 with R "
                  + ("(empty — log real trades to start the contrast)" if st['total'] == 0 else ""))
            continue
        bias = "  ⚠ SELECTION BIAS: only %.0f%% resolved — early closers skew to fast stop-outs; overstates" % (
            st['resolved_frac'] * 100) if st['resolved_frac'] < 0.5 else ""
        print(f"{label:22s}  {st['total']} logged / {st['closed']} closed")
        print(f"    win {st['win']:.0%}  avgR {st['avg_R']:+.2f}  totalR {st['total_R']:+.1f}  t={st['t']:.2f}"
              f"  [{'POWERED' if st['powered'] else 'status only, n<%d' % POWER_N}]{bias}")
        if "--detail" in sys.argv:
            ex = collections.Counter(_exit_class(t) for t, _ in st["rows"])
            for how, c in ex.most_common():
                rr = [r for t, r in st["rows"] if _exit_class(t) == how]
                print(f"      {how:18s} {c}/{st['n']} ({c/st['n']:.0%})  avgR {statistics.mean(rr):+.2f}")
    # Full-book mark-to-market on the engine store — removes the closed-only selection bias.
    bars = _cache_bars()
    if bars:
        r = subprocess.run(["defaults", "export", DOMAIN, "-"], capture_output=True)
        d = plistlib.loads(r.stdout)
        pk = next((k for k in d if "papertrade" in k.lower().replace(".", "")), None)
        arr = _deep(d[pk]) if pk else None
        if isinstance(arr, list):
            full, real, unreal = _mark_to_market(arr, bars)
            if full:
                n = len(full); mu = statistics.mean(full); sd = statistics.pstdev(full)
                t = mu / (sd / n ** 0.5) if sd else 0.0
                print(f"\nENGINE FULL-BOOK (bias-removed): {n} evaluable ({real} realized + {unreal} open-marked)")
                print(f"    positive {sum(1 for x in full if x > 0)/n:.0%}  avg {mu:+.3f}R  total {mu*n:+.1f}R  t={t:+.2f}")
                print("    → brackets the closed-only read from ABOVE (open marks lean optimistic); the truth is"
                      " between the two and converges as the book resolves. t<3 and avg≈0 ⇒ consistent with"
                      " NO edge / value-is-risk-discipline — NOT a losing engine (the closed-only −R was fast-loser bias).")
    else:
        print("\n(price cache absent — run the app once to enable the full-book mark-to-market)")
    own = s.get("owner (own journal)")
    if not (own and own.get("n")):
        print("Your own journal is empty — log discretionary trades (Markets → add a trade) to measure YOUR edge vs the engine.")


if __name__ == "__main__":
    main()
