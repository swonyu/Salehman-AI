#!/usr/bin/env python3
"""PRE-REGISTERED GP/A (gross profitability) LONG-tilt ablation on the EODHD
survivorship-free panel with SEC EDGAR fundamentals.

Pre-registration: tools/eodhd_panel/PREREG_2026-07-10_gpa_quality.md (design-reviewed,
committed at 49a8300 BEFORE any test statistic). Every rule implements a prereg clause:

  FY IDENTITY  the FACT's period END date (never EDGAR fy/fp — review #1); duration facts
               need end-start in [340,380] days; Assets = instant fact at the same end.
  SIGNAL       GP/A = GrossProfit(end)/Assets(end); GrossProfit direct else Rev-COGS with
               pinned tag priority, same period-end; Assets>0; earliest-filed per
               (name,end,tag); availability = first master bar STRICTLY AFTER max(filed)
               over ingredients used (review #3); freshness max-filed within trailing
               378 bars (S5 leg: 504).
  BOOKS        TOP-tercile GP/A long vs ONE EQW-all-eligible per (scope,H); scopes FULL /
               as-of LOWLIQ tercile; H in {63,126,252}; entry open[p+1], exit last valid
               print <= p+1+H (booked truncations); no price warmup (review #13).
  LEGS         S1' lag +126 bars (pass conjunct, sign agreement) | S1'' placebo shuffle
               seeds 1,2,3 (machinery veto) | S2a winsorized | S2b no-screen+winsorized |
               S4 Shumway -30% | S5 freshness 504 (context only).
  STATS        6 decision arms; trials 6 (+743 registry print); varTrialSharpe floored
               0.0343 BINDING; gross t/DSR for both books; symmetric negative flags;
               censuses i-v mandatory.

Usage: python3 gpa_quality.py [--ledger] [--out results.json]  [SMOKE=N env]
"""
import json, math, os, random, statistics, sys, argparse, bisect
from array import array

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from smallcap_maxbabivol import (psr, expected_max_sharpe, moments, tstat, prep_name,
                                 selfcheck_drys, NAN, MIN_NAMES, BASE, MANIFEST, MARKET,
                                 REPO, LEDGER)

FACTS = os.path.join(BASE, "edgar_facts")
WIN_LO, WIN_HI = "2010-01-04", "2026-07-09"
HORIZONS = [63, 126, 252]
SCOPES = [("FULL", 13.0), ("LOWLIQ", 60.0)]
FRESH, FRESH_S5 = 378, 504
LAG = 126
PRIOR_ARMS = 0                 # ledger census: zero gpa/quality empirical arms (prereg §Statistics)
REGISTRY_ARMS = 743
VAR_FLOOR = 0.0343
SHUMWAY = -0.30
REV_PRI = ["Revenues", "RevenueFromContractWithCustomerExcludingAssessedTax",
           "RevenueFromContractWithCustomerIncludingAssessedTax",
           "SalesRevenueNet", "SalesRevenueGoodsNet", "SalesRevenueServicesNet"]
COGS_PRI = ["CostOfGoodsAndServicesSold", "CostOfRevenue", "CostOfGoodsSold", "CostOfServices"]


def build_signal_events(rec):
    """Prereg §Signal: returns [(end, max_filed, gpa)] sorted by end date, plus census flags."""
    def dur_ok(x):
        s, e = x.get("frame_start"), x.get("end")
        if not s or not e: return False
        from datetime import date
        d = (date(*map(int, e.split("-"))) - date(*map(int, s.split("-")))).days
        return 340 <= d <= 380
    def earliest_by_end(arr, need_duration):
        out = {}
        for x in arr:
            if x.get("val") is None or not x.get("filed") or not x.get("end"): continue
            if need_duration and not dur_ok(x): continue
            k = (x["end"], x["tag"])
            if k not in out or x["filed"] < out[k]["filed"]:
                out[k] = x
        return out
    gp = earliest_by_end(rec.get("gp", []), True)
    rev = earliest_by_end(rec.get("rev", []), True)
    cogs = earliest_by_end(rec.get("cogs", []), True)
    ast = earliest_by_end(rec.get("assets", []), False)
    ends = {e for (e, _) in list(gp) + list(rev) + list(cogs)}
    has_assets_no_rev = bool(ast) and not rev and not gp        # census (ii)
    events = []
    for end in sorted(ends):
        a = ast.get((end, "Assets"))
        if not a or a["val"] is None or a["val"] <= 0: continue
        g = gp.get((end, "GrossProfit"))
        if g is not None:
            val, filed = g["val"], max(g["filed"], a["filed"])
        else:
            r = next((rev[(end, t)] for t in REV_PRI if (end, t) in rev), None)
            c = next((cogs[(end, t)] for t in COGS_PRI if (end, t) in cogs), None)
            if r is None or c is None: continue
            val = r["val"] - c["val"]
            filed = max(r["filed"], c["filed"], a["filed"])
        events.append((end, filed, val / a["val"]))
    return events, has_assets_no_rev


def selfcheck_signal():
    rec = {"gp": [{"tag": "GrossProfit", "fy": 2016, "end": "2015-12-31", "frame_start": "2015-01-02",
                   "filed": "2016-02-15", "val": 50.0, "form": "10-K"},
                  {"tag": "GrossProfit", "fy": 2017, "end": "2015-12-31", "frame_start": "2015-01-02",
                   "filed": "2017-02-10", "val": 55.0, "form": "10-K"},          # later re-report: ignored
                  {"tag": "GrossProfit", "fy": 2016, "end": "2016-03-31", "frame_start": "2016-01-01",
                   "filed": "2016-05-01", "val": 12.0, "form": "10-K"}],          # 90d stub: duration guard
           "rev": [], "cogs": [],
           "assets": [{"tag": "Assets", "fy": 2016, "end": "2015-12-31", "frame_start": None,
                       "filed": "2016-02-20", "val": 200.0, "form": "10-K"}]}
    ev, flag = build_signal_events(rec)
    assert len(ev) == 1 and ev[0] == ("2015-12-31", "2016-02-20", 0.25), ev   # earliest-filed val, max(filed) avail
    assert flag is False
    # derived path + tag priority: Revenues beats SalesRevenueNet; same-end COGS required
    rec2 = {"gp": [], "assets": rec["assets"],
            "rev": [{"tag": "SalesRevenueNet", "fy": 2016, "end": "2015-12-31", "frame_start": "2015-01-02",
                     "filed": "2016-02-15", "val": 90.0, "form": "10-K"},
                    {"tag": "Revenues", "fy": 2016, "end": "2015-12-31", "frame_start": "2015-01-02",
                     "filed": "2016-03-01", "val": 100.0, "form": "10-K"}],
            "cogs": [{"tag": "CostOfRevenue", "fy": 2016, "end": "2015-12-31", "frame_start": "2015-01-02",
                      "filed": "2016-02-15", "val": 40.0, "form": "10-K"}]}
    ev2, _ = build_signal_events(rec2)
    assert len(ev2) == 1 and abs(ev2[0][2] - 0.30) < 1e-12 and ev2[0][1] == "2016-03-01", ev2
    print("selfcheck PASS: GP/A signal fixtures (FY-end keying, duration guard, earliest-filed, "
          "tag priority, max-filed availability)")


def derive(nm):
    return {"prints": [j for j in range(len(nm["open"])) if not math.isnan(nm["open"][j])]}


def run_leg(names, sigmap, wdates, wpos, lag, fresh, tag):
    """One full pass. sigmap: code -> [(avail_pos, filed_pos, end, gpa)] sorted by end.
    Returns arms[(scope,H)] block-series dicts + censuses."""
    N = len(wdates)
    ders = {nm["code"]: derive(nm) for nm in names}
    byc = {nm["code"]: nm for nm in names}
    arms = {}
    stale_drops = {}
    for H in HORIZONS:
        for scope, _ in SCOPES:
            arms[(scope, H)] = {"d": [], "d_w": [], "d_s4": [], "coh_g": [], "eqw_g": [],
                                "trunc_del": 0, "trunc_hole": 0, "skips": 0}
        p = 0
        while p + 1 + H <= N - 1:
            target = p + 1 + H
            elig, liq, sig = [], {}, {}
            stale = 0
            for code, nm in byc.items():
                if math.isnan(nm["open"][p + 1]): continue
                evs = sigmap.get(code)
                if not evs: continue
                cur = None
                for av, fp_, end, g in reversed(evs):       # latest end with avail<=p
                    if av + lag <= p:
                        cur = (av, fp_, end, g); break
                if cur is None: continue
                if cur[1] + lag < p - fresh + 1:            # freshness on (shifted) filed pos
                    stale += 1; continue
                # FIX 2026-07-10 (post-run audit B6, proven inert for the completed run — p=0 was
                # necessarily skipped, <30 eligible): clamp the dv window; Python negative indices
                # would read the FUTURE tail of the array.
                dvw = [nm["dv"][j] for j in range(max(0, p - 62), p + 1) if not math.isnan(nm["dv"][j])]
                if not dvw: continue
                elig.append(code); liq[code] = statistics.median(dvw); sig[code] = cur[3]
            stale_drops[(H, p)] = stale
            if len(elig) < MIN_NAMES:
                for scope, _ in SCOPES: arms[(scope, H)]["skips"] += 1
                p += H; continue
            ranked = sorted(elig, key=lambda c: liq[c])
            lowliq = set(ranked[: max(1, len(ranked) // 3)])
            brets, dele = {}, {}
            for code in elig:
                pr = ders[code]["prints"]
                k = bisect.bisect_right(pr, target) - 1
                e = pr[k]
                nm = byc[code]
                brets[code] = nm["open"][e] / nm["open"][p + 1] - 1.0
                if e < target: dele[code] = pr[-1] < target
            for scope, _ in SCOPES:
                members = [c for c in elig if scope == "FULL" or c in lowliq]
                a = arms[(scope, H)]
                if len(members) < MIN_NAMES:
                    a["skips"] += 1; continue
                coh = sorted(members, key=lambda c: sig[c], reverse=True)[: max(1, len(members) // 3)]
                def bmean(cs, wins=False, s4=False):
                    tot = 0.0
                    for c in cs:
                        r = brets[c]
                        if s4 and dele.get(c) is True: r = (1 + r) * (1 + SHUMWAY) - 1
                        if wins: r = min(max(r, -1.0), 1.0)
                        tot += r
                    return tot / len(cs)
                cm, em = bmean(coh), bmean(members)
                a["d"].append(cm - em)
                a["d_w"].append(bmean(coh, wins=True) - bmean(members, wins=True))
                a["d_s4"].append(bmean(coh, s4=True) - bmean(members, s4=True))
                a["coh_g"].append(cm); a["eqw_g"].append(em)
                a["trunc_del"] += sum(1 for c in coh if dele.get(c) is True)
                a["trunc_hole"] += sum(1 for c in coh if dele.get(c) is False)
            p += H
    return arms, stale_drops


def placebo_leg(names, sigmap, wdates, seed):
    """S1'': identical to the base leg except GP/A values are shuffled across eligible names
    at each rebalance (pinned rng per shuffle-run). Returns per-(scope,H) diff series."""
    rng = random.Random(seed)
    N = len(wdates)
    ders = {nm["code"]: derive(nm) for nm in names}
    byc = {nm["code"]: nm for nm in names}
    out = {}
    for H in HORIZONS:
        for scope, _ in SCOPES: out[(scope, H)] = []
        p = 0
        while p + 1 + H <= N - 1:
            target = p + 1 + H
            elig, liq, sig = [], {}, {}
            for code, nm in byc.items():
                if math.isnan(nm["open"][p + 1]): continue
                evs = sigmap.get(code)
                if not evs: continue
                cur = None
                for av, fp_, end, g in reversed(evs):
                    if av <= p: cur = (av, fp_, end, g); break
                if cur is None or cur[1] < p - FRESH + 1: continue
                dvw = [nm["dv"][j] for j in range(max(0, p - 62), p + 1) if not math.isnan(nm["dv"][j])]
                if not dvw: continue
                elig.append(code); liq[code] = statistics.median(dvw); sig[code] = cur[3]
            if len(elig) < MIN_NAMES:
                p += H; continue
            vals = [sig[c] for c in elig]
            rng.shuffle(vals)
            sig = dict(zip(elig, vals))
            ranked = sorted(elig, key=lambda c: liq[c])
            lowliq = set(ranked[: max(1, len(ranked) // 3)])
            brets = {}
            for code in elig:
                pr = ders[code]["prints"]
                e = pr[bisect.bisect_right(pr, target) - 1]
                brets[code] = byc[code]["open"][e] / byc[code]["open"][p + 1] - 1.0
            for scope, _ in SCOPES:
                members = [c for c in elig if scope == "FULL" or c in lowliq]
                if len(members) < MIN_NAMES: continue
                coh = sorted(members, key=lambda c: sig[c], reverse=True)[: max(1, len(members) // 3)]
                out[(scope, H)].append(sum(brets[c] for c in coh) / len(coh)
                                       - sum(brets[c] for c in members) / len(members))
            p += H
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--out", default=os.path.join(BASE, "gpa_quality_results.json"))
    args = ap.parse_args()
    smoke = int(os.environ.get("SMOKE", "0"))

    selfcheck_signal()
    selfcheck_drys()

    rec = json.load(open(MARKET))
    mbars = rec["eod"] if isinstance(rec, dict) else rec
    wdates = [b["date"] for b in mbars if WIN_LO <= b["date"] <= WIN_HI]
    wpos = {d: i for i, d in enumerate(wdates)}
    N = len(wdates)
    print(f"master window bars: {N} ({wdates[0]} .. {wdates[-1]})")

    cands = []
    with open(MANIFEST) as f:
        for line in f:
            m = json.loads(line)
            if m.get("status") == "ok" and m["first"] <= WIN_HI and m["delist"] >= WIN_LO:
                cands.append((m["code"], m["delist"]))
    if smoke: cands = cands[:smoke]
    rej = {"short": 0, "entry_price": 0, "dollar_vol": 0, "gap": 0, "load": 0}
    clean, screened = [], []
    delist_of = dict(cands)
    for i, (code, _) in enumerate(cands):
        if i % 4000 == 0: print(f"  prep {i}/{len(cands)}", flush=True)
        nm = prep_name(code, wdates, wpos, rej)
        if nm is None: continue
        (screened if nm["screen"] else clean).append(nm)
    print(f"prep done: clean={len(clean)} screened={len(screened)} rejections={rej}")

    # signal events -> master positions
    sigmap, no_rev_census, usable = {}, 0, 0
    split = {"delisted": [0, 0], "active": [0, 0]}   # [have_facts, usable]
    for nm in clean + screened:
        code = nm["code"]
        path = os.path.join(FACTS, code + ".json")
        cls = "delisted" if delist_of.get(code, "9999") < "2026-06-01" else "active"
        if not os.path.exists(path): continue
        r = json.load(open(path))
        if r.get("missing"): continue
        split[cls][0] += 1
        evs, no_rev = build_signal_events(r)
        no_rev_census += no_rev
        pos_evs = []
        for end, filed, g in evs:
            av = bisect.bisect_right(wdates, filed)          # first bar STRICTLY AFTER filed
            fp_ = av                                          # filed position proxy on master axis
            if av < N:
                pos_evs.append((av, fp_, end, g))
        if pos_evs:
            sigmap[code] = pos_evs
            usable += 1
            split[cls][1] += 1
    print(f"CENSUS: usable-signal names {usable} (pinned-tag extraction; the acceptance census's 54% was a floor)")
    print(f"CENSUS assets-but-no-revenue-tags: {no_rev_census}")
    print(f"CENSUS usable split: delisted facts={split['delisted'][0]} usable={split['delisted'][1]} | "
          f"active facts={split['active'][0]} usable={split['active'][1]}")

    print("\n=== BASE leg ===", flush=True)
    base, stale = run_leg(clean, sigmap, wdates, wpos, 0, FRESH, "base")
    yearly = {}
    for (H, p), s in stale.items():
        if H == 63:
            yearly.setdefault(wdates[p][:4], []).append(s)
    print("CENSUS staleness drops (H63 grid, mean per rebalance by year): "
          + " ".join(f"{y}:{sum(v)/len(v):.0f}" for y, v in sorted(yearly.items())))
    print("\n=== S1' lag leg (+126) ===", flush=True)
    lag, _ = run_leg(clean, sigmap, wdates, wpos, LAG, FRESH, "lag")
    print("=== S5 freshness-504 leg ===", flush=True)
    s5, _ = run_leg(clean, sigmap, wdates, wpos, 0, FRESH_S5, "s5")
    print("=== S2b no-screen leg ===", flush=True)
    s2b, _ = run_leg(clean + screened, sigmap, wdates, wpos, 0, FRESH, "s2b")
    print("=== S1'' placebo x3 ===", flush=True)
    plac = [placebo_leg(clean, sigmap, wdates, s) for s in (1, 2, 3)]

    keys = [(scope, H) for scope, _ in SCOPES for H in HORIZONS]
    srs = {}
    for k in keys:
        d = base[k]["d"]
        mu, sd, sk, ku = moments(d) if len(d) > 3 else (0, 0, 0, 3)
        srs[k] = (0.0 if sd == 0 else mu / sd, sk, ku, len(d))
    vts = statistics.variance([s[0] for s in srs.values()])
    vts_f = max(vts, VAR_FLOOR)
    b6 = expected_max_sharpe(6 + PRIOR_ARMS, vts)
    b6f = expected_max_sharpe(6 + PRIOR_ARMS, vts_f)
    b749 = expected_max_sharpe(6 + REGISTRY_ARMS, vts)
    print(f"\nvarTrialSharpe={vts:.6f} (floored {vts_f:.6f}); bench6={b6:.4f} "
          f"benchFloor={b6f:.4f} bench749={b749:.4f}")

    def dsr_of(series, bench):
        if len(series) < 4: return 0.0
        m, s, a, b_ = moments(series)
        r = 0.0 if s == 0 else m / s
        return psr(r, len(series), a, b_, bench)

    placebo_max = max((dsr_of(pl[k], b6) for pl in plac for k in keys), default=0.0)
    run_valid = placebo_max <= 0.95
    print(f"S1'' placebo max DSR across 3 seeds x 6 arms: {placebo_max:.3f} -> run "
          + ("VALID" if run_valid else "INVALID (machinery leak)"))

    results, passing, neg_flags = {}, [], []
    print(f"\n{'arm':14s} {'nblk':>4s} {'diff_mean':>10s} {'t':>6s} {'DSR6':>6s} {'DSRflr':>7s} "
          f"{'S2a':>6s} {'S2b':>6s} {'S1lag':>6s} {'S5':>8s} {'negDSR':>7s} {'cohG_t':>7s} {'eqwG_t':>7s}")
    for k in keys:
        scope, H = k
        d, dw, ds4 = base[k]["d"], base[k]["d_w"], base[k]["d_s4"]
        sr, sk, ku, n = srs[k]
        mu = sum(d) / n if n else 0.0
        dsr6 = psr(sr, n, sk, ku, b6); dsrflr = psr(sr, n, sk, ku, b6f)
        dsr749 = psr(sr, n, sk, ku, b749)
        s2a_d = dsr_of(dw, b6); s2b_d = dsr_of(s2b[k]["d_w"], b6); s4_d = dsr_of(ds4, b6)
        lmu = (sum(lag[k]["d"]) / len(lag[k]["d"])) if lag[k]["d"] else 0.0
        s1 = (mu >= 0) == (lmu >= 0)
        s5mu = (sum(s5[k]["d"]) / len(s5[k]["d"])) if s5[k]["d"] else 0.0
        neg = psr(-sr, n, -sk, ku, b6)
        cg, eg = base[k]["coh_g"], base[k]["eqw_g"]
        ok = (run_valid and mu > 0 and dsr6 > 0.95 and dsrflr > 0.95
              and s2a_d > 0.95 and s2b_d > 0.95 and s1)
        if ok: passing.append(k)
        nflag = (neg > 0.95 and s1 and dsr_of([-x for x in dw], b6) > 0.95
                 and dsr_of([-x for x in s2b[k]["d_w"]], b6) > 0.95)
        if nflag: neg_flags.append(k)
        arm = f"{scope}/H{H}"
        print(f"{arm:14s} {n:4d} {mu:+10.5f} {tstat(d):6.2f} {dsr6:6.3f} {dsrflr:7.3f} "
              f"{s2a_d:6.3f} {s2b_d:6.3f} {'Y' if s1 else 'N':>6s} {s5mu:+8.5f} {neg:7.3f} "
              f"{tstat(cg):7.2f} {tstat(eg):7.2f}")
        results[arm] = {
            "n_blocks": n, "diff_mean": mu, "diff_t": tstat(d), "diff_sharpe": sr,
            "diff_skew": sk, "diff_kurt": ku, "dsr_6": dsr6, "dsr_floor": dsrflr,
            "dsr_749": dsr749, "s2a_dsr": s2a_d, "s2b_dsr": s2b_d, "s4_dsr": s4_d,
            "s4_mean": (sum(ds4) / len(ds4)) if ds4 else None,
            "lag_mean": lmu, "s1_sign_agree": s1, "s5_mean": s5mu,
            "neg_dsr_6": neg, "passes": ok, "neg_flag": nflag,
            "coh_gross_mean": sum(cg) / n if n else None, "coh_gross_t": tstat(cg),
            "coh_gross_dsr": dsr_of(cg, b6),
            "eqw_gross_mean": sum(eg) / n if n else None, "eqw_gross_t": tstat(eg),
            "eqw_gross_dsr": dsr_of(eg, b6),
            "trunc_delisting": base[k]["trunc_del"], "trunc_hole": base[k]["trunc_hole"],
            "skips": base[k]["skips"],
        }

    print(f"\nDECISION RULE (closed 6-arm set, trials=6, run_valid={run_valid}): "
          f"passing arms = {len(passing)}" + (f" {passing}" if passing else ""))
    print(f"Symmetric NEGATIVE flags: {len(neg_flags)}" + (f" {neg_flags}" if neg_flags else ""))
    print("VERDICT: " + ("PROMOTION CANDIDATE per prereg — owner presentation required" if passing
                         else "NULL — the campaign-milestone row's LAST surveyed named shot closes; "
                              "the quality family's current-era ~null extends to the small/retail "
                              "survivorship-free population"))

    with open(args.out, "w") as f:
        json.dump({"prereg": "PREREG_2026-07-10_gpa_quality.md", "window": [WIN_LO, WIN_HI],
                   "clean_names": len(clean), "screened": len(screened),
                   "usable_signal_names": usable, "census_assets_no_rev": no_rev_census,
                   "census_split": split, "varTrialSharpe": vts,
                   "bench_6": b6, "bench_floor": b6f, "bench_749": b749,
                   "placebo_max_dsr": placebo_max, "run_valid": run_valid,
                   "results": results,
                   "passing": [f"{s}/H{h}" for s, h in passing],
                   "neg_flags": [f"{s}/H{h}" for s, h in neg_flags]}, f, indent=1)
    print(f"results -> {args.out}")

    if args.ledger and not smoke:
        import subprocess
        run_id = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
        with open(LEDGER, "a") as f:
            for k in keys:
                scope, H = k
                a = results[f"{scope}/H{H}"]
                f.write(json.dumps({
                    "family": "gpa-quality", "run": run_id,
                    "panel": "eodhd-us-delisted+active-2026-07-10+edgar-facts",
                    "arm": f"{scope}/H{H}", "sharpe": a["diff_sharpe"],
                    "dsr": a["dsr_6"], "n": a["n_blocks"],
                    "verdict": "pass" if a["passes"] else "null",
                }) + "\n")
        print(f"LEDGER: appended {len(keys)} arms")


if __name__ == "__main__":
    main()
