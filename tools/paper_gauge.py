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
import subprocess, plistlib, json, statistics, sys, collections

DOMAIN = "SA.Salehman-AI"
STORES = {"engine (auto paper)": "stocksage.papertrades.v1",
          "owner (own journal)": "stocksage.journal.v1"}
POWER_N = 100


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
    eng, own = s.get("engine (auto paper)"), s.get("owner (own journal)")
    if eng and eng.get("n") and own and own.get("n"):
        print(f"\nCONTRAST (engine vs your gut): engine avgR {eng['avg_R']:+.2f} vs yours {own['avg_R']:+.2f}"
              f"  — {'discipline is ahead' if eng['avg_R'] > own['avg_R'] else 'your calls are ahead'} "
              "(both n small; read when each reaches ~100 closed)")
    elif eng and eng.get("n"):
        print("\nCONTRAST: your own journal is empty — log discretionary trades (Markets → add a trade) "
              "to measure YOUR edge against the engine's auto-paper track above.")


if __name__ == "__main__":
    main()
