#!/usr/bin/env python3
"""PRE-REGISTERED ACCRUALS (Sloan 1996) LONG-tilt ablation on the EODHD survivorship-free panel
with SEC EDGAR fundamentals.

Pre-registration: tools/eodhd_panel/PREREG_2026-07-15_accruals.md (committed BEFORE any statistic).
Extends the twice-verified investment_issuance.py machinery (the price-exogenous Δ leg + interval
guard + placebos) with the Sloan balance-sheet accruals signal. Every rule implements a clause:

  SIGNAL   Accruals(t) = [(ΔCA-ΔCash) - (ΔCL-ΔSTD-ΔTP) - Dep(t)] / avg(Assets_t, Assets_{t-1})
           Δ = FY_t - FY_{t-1} of the instant balance-sheet item; Dep(t) = FY_t depreciation flow.
           LONG = LOW accruals (high earnings quality = Sloan's long leg). Stored NEGATED (-Accruals)
           so the invest runner's top-tercile-by-signal = bottom-tercile-by-accruals = long leg.
  FIX 1    pair-interval guard [340,380]d (inherited).
  FIX C    joint availability = first bar STRICTLY AFTER max(filed) over ALL ingredient records used
           across BOTH FYs (inherited).
  PRICE-EXOGENOUS  balance-sheet only, NO price → fed through _invest_run_leg (sig=scalar).
  STATS    6 arms (1 signal x 3H x 2 scopes); trials 6; varTrialSharpe floored 0.0343 BINDING.

Usage: python3 accruals.py [--ledger] [--out results.json]  [SMOKE=N env]
"""
import json, os, sys, bisect, argparse, statistics
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import investment_issuance as II
from investment_issuance import (_invest_run_leg, _invest_placebo_signal, _invest_placebo_returns,
                                 _pair_interval_ok, _write_results, prep_value_name,
                                 HORIZONS, SCOPES, FRESH, FRESH_S5, LAG, VAR_FLOOR)
from smallcap_maxbabivol import (psr, expected_max_sharpe, moments, tstat,
                                 selfcheck_drys, MIN_NAMES, BASE, MANIFEST, MARKET, REPO, LEDGER)

FACTS_ACC = os.path.join(BASE, "edgar_facts_accruals")
WIN_LO, WIN_HI = "2010-01-04", "2026-07-09"
SIGNALS = ["ACC"]
PRIOR_ARMS = 0            # ledger census: zero accruals empirical arms (prereg verified)

# Required roles (a name missing any at either FY is ineligible); optional roles default to 0.
REQUIRED = ("assets", "ca", "cash", "cl")
OPTIONAL = ("std", "tp")


def _by_end_earliest(records):
    """earliest-filed per FY-end for an instant-fact role. records: [{tag,fy,end,filed,val}]."""
    out = {}
    for x in records or []:
        if x.get("val") is None or not x.get("filed") or not x.get("end"):
            continue
        e = x["end"]
        if e not in out or x["filed"] < out[e]["filed"]:
            out[e] = x
    return out


def _dep_by_end(records):
    """Depreciation is a DURATION flow — apply the [340,380]d guard, earliest-filed per FY-end."""
    from datetime import date
    out = {}
    for x in records or []:
        if x.get("val") is None or not x.get("filed") or not x.get("end") or not x.get("frame_start"):
            continue
        d = (date(*map(int, x["end"].split("-"))) - date(*map(int, x["frame_start"].split("-")))).days
        if not (340 <= d <= 380):
            continue
        e = x["end"]
        if e not in out or x["filed"] < out[e]["filed"]:
            out[e] = x
    return out


def accruals_events(rec):
    """Sloan (1996) balance-sheet accruals over consecutive FYs. Returns
    [(end_t, avail_filed, -Accruals, end_{t-1})] sorted by end_t. -Accruals stored so top-tercile-
    by-signal = low-accruals long. avail = max(filed) JOINTLY over all ingredient records used."""
    roles = {r: _by_end_earliest(rec.get(r, [])) for r in REQUIRED + OPTIONAL}
    dep = _dep_by_end(rec.get("dep", []))
    # candidate FY-ends: those present in ALL required INSTANT roles (both FY_t and FY_{t-1} draw
    # from this set). Dep is a FY_t-only flow — required at FY_t, checked inside the loop, NOT part
    # of the candidate-end set (else FY_{t-1}, which needs no dep, would be excluded — the bug the
    # selfcheck caught).
    ends = sorted(set(roles["assets"]) & set(roles["ca"]) & set(roles["cash"]) & set(roles["cl"]))
    events = []
    for i in range(1, len(ends)):
        e_t, e_p = ends[i], ends[i - 1]
        if not _pair_interval_ok(e_p, e_t):                        # FIX 1
            continue
        # both FYs need the required instant roles; dep required at FY_t only
        if not all(e_t in roles[r] and e_p in roles[r] for r in REQUIRED):
            continue
        if e_t not in dep:                                         # FY_t depreciation flow required
            continue
        A_t = roles["assets"][e_t]["val"]; A_p = roles["assets"][e_p]["val"]
        avg_assets = (A_t + A_p) / 2.0
        if avg_assets <= 0:
            continue

        def delta(role):
            return roles[role][e_t]["val"] - roles[role][e_p]["val"]

        def delta_opt(role):
            rt = roles[role].get(e_t); rp = roles[role].get(e_p)
            return (rt["val"] if rt else 0.0) - (rp["val"] if rp else 0.0)

        d_ca = delta("ca"); d_cash = delta("cash"); d_cl = delta("cl")
        d_std = delta_opt("std"); d_tp = delta_opt("tp")
        dep_t = dep[e_t]["val"]
        acc = ((d_ca - d_cash) - (d_cl - d_std - d_tp) - dep_t) / avg_assets
        # availability: max filed over EVERY record actually used (both FYs of the 4 required roles,
        # the optional roles where present, and dep_t)
        used = [roles[r][e_t]["filed"] for r in REQUIRED] + [roles[r][e_p]["filed"] for r in REQUIRED]
        for role in OPTIONAL:
            if roles[role].get(e_t): used.append(roles[role][e_t]["filed"])
            if roles[role].get(e_p): used.append(roles[role][e_p]["filed"])
        used.append(dep[e_t]["filed"])
        avail = max(used)
        events.append((e_t, avail, -acc, e_p))                     # NEGATED
    return events


def selfcheck_accruals():
    # Hand-derived Sloan case. FY13->FY14:
    #   CA 100->130 (+30), Cash 20->25 (+5), CL 60->70 (+10), STD 10->12 (+2), TP absent,
    #   Dep(FY14)=8, Assets 200->220 (avg 210).
    #   Accruals = [(30-5) - (10-2-0) - 8] / 210 = [25 - 8 - 8] / 210 = 9/210 = 0.042857...
    #   stored -0.042857
    def rr(role, e13, e14, filed13="2014-02-15", filed14="2015-02-15"):
        return [{"tag": role, "fy": 2013, "end": "2013-12-31", "filed": filed13, "val": e13, "form": "10-K"},
                {"tag": role, "fy": 2014, "end": "2014-12-31", "filed": filed14, "val": e14, "form": "10-K"}]
    rec = {"assets": rr("Assets", 200.0, 220.0),
           "ca": rr("AssetsCurrent", 100.0, 130.0),
           "cash": rr("CashAndCashEquivalentsAtCarryingValue", 20.0, 25.0),
           "cl": rr("LiabilitiesCurrent", 60.0, 70.0),
           "std": rr("LongTermDebtCurrent", 10.0, 12.0),
           "tp": [],
           "dep": [{"tag": "DepreciationDepletionAndAmortization", "fy": 2014, "end": "2014-12-31",
                    "frame_start": "2014-01-01", "filed": "2015-02-15", "val": 8.0, "form": "10-K"}]}
    ev = accruals_events(rec)
    assert len(ev) == 1, ev
    end_t, avail, negacc, end_p = ev[0]
    assert end_t == "2014-12-31" and end_p == "2013-12-31", ev
    want = -((25.0 - 8.0 - 8.0) / 210.0)
    assert abs(negacc - want) < 1e-12, f"accruals stored {negacc} != {want}"
    assert avail == "2015-02-15", f"avail = max(filed) all FY_t/FY_p records = {avail}"
    # interval guard: a 2-year gap yields NO event
    rec_gap = {"assets": [{"tag": "Assets", "fy": 2013, "end": "2013-12-31", "filed": "2014-02-15", "val": 200.0, "form": "10-K"},
                          {"tag": "Assets", "fy": 2016, "end": "2016-12-31", "filed": "2017-02-15", "val": 260.0, "form": "10-K"}],
               "ca": [{"tag": "AssetsCurrent", "fy": 2013, "end": "2013-12-31", "filed": "2014-02-15", "val": 100.0, "form": "10-K"},
                      {"tag": "AssetsCurrent", "fy": 2016, "end": "2016-12-31", "filed": "2017-02-15", "val": 140.0, "form": "10-K"}],
               "cash": [{"tag": "CashAndCashEquivalentsAtCarryingValue", "fy": 2013, "end": "2013-12-31", "filed": "2014-02-15", "val": 20.0, "form": "10-K"},
                        {"tag": "CashAndCashEquivalentsAtCarryingValue", "fy": 2016, "end": "2016-12-31", "filed": "2017-02-15", "val": 30.0, "form": "10-K"}],
               "cl": [{"tag": "LiabilitiesCurrent", "fy": 2013, "end": "2013-12-31", "filed": "2014-02-15", "val": 60.0, "form": "10-K"},
                      {"tag": "LiabilitiesCurrent", "fy": 2016, "end": "2016-12-31", "filed": "2017-02-15", "val": 80.0, "form": "10-K"}],
               "std": [], "tp": [],
               "dep": [{"tag": "Depreciation", "fy": 2016, "end": "2016-12-31", "frame_start": "2016-01-01", "filed": "2017-02-15", "val": 8.0, "form": "10-K"},
                       {"tag": "Depreciation", "fy": 2013, "end": "2013-12-31", "frame_start": "2013-01-01", "filed": "2014-02-15", "val": 8.0, "form": "10-K"}]}
    assert accruals_events(rec_gap) == [], f"2-year-gap must yield NO accruals event: {accruals_events(rec_gap)}"
    # required-role missing: drop cash at FY_t -> no event
    rec_missing = {k: (v if k != "cash" else [v[0]]) for k, v in rec.items()}   # only FY13 cash
    assert accruals_events(rec_missing) == [], "missing required role at FY_t must yield NO event"
    # price-invariance: signal is balance-sheet-only, no price term
    assert abs(accruals_events(rec)[0][2] - want) < 1e-12, "accruals signal must be price-INVARIANT"
    print(f"selfcheck PASS: Sloan accruals = {-want:+.6f} (stored {want:+.6f}), joint avail, "
          "interval guard drops 2yr gap, required-role gate, price-invariant")


def dsr_of(series, bench):
    from smallcap_maxbabivol import moments as _m, psr as _p
    if len(series) < 4:
        return 0.0
    m, s, a, b_ = _m(series)
    r = 0.0 if s == 0 else m / s
    return _p(r, len(series), a, b_, bench)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "accruals_results.json"))
    args = ap.parse_args()
    smoke = int(os.environ.get("SMOKE", "0"))

    selfcheck_drys()
    selfcheck_accruals()

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
    if smoke:
        cands = cands[:smoke]
    rej = {"short": 0, "entry_price": 0, "dollar_vol": 0, "gap": 0, "load": 0}
    clean, screened = [], []
    delist_of = dict(cands)
    for i, (code, _) in enumerate(cands):
        if i % 4000 == 0:
            print(f"  prep {i}/{len(cands)}", flush=True)
        nm = prep_value_name(code, wdates, wpos, rej)
        if nm is None:
            continue
        (screened if nm["screen"] else clean).append(nm)
    print(f"prep done: clean={len(clean)} screened={len(screened)} rejections={rej}")

    REGISTRY_ARMS = 807       # ledger line count at prereg commit (over-deflates = safe)
    sigmap = {}
    usable = 0
    split = {"delisted": [0, 0], "active": [0, 0]}
    role_missing = [0]; pre_window_dropped = [0]
    for nm in clean + screened:
        code = nm["code"]
        path = os.path.join(FACTS_ACC, code + ".json")
        cls = "delisted" if delist_of.get(code, "9999") < "2026-06-01" else "active"
        if not os.path.exists(path):
            continue
        r = json.load(open(path))
        if r.get("missing"):
            continue
        split[cls][0] += 1
        ev = accruals_events(r)
        if not ev:
            role_missing[0] += 1
        pos = []
        for end_t, avail, negsig, end_p in ev:
            if avail < WIN_LO:
                pre_window_dropped[0] += 1; continue
            av = bisect.bisect_right(wdates, avail)
            if av < N:
                pos.append((av, av, end_t, negsig))
        if pos:
            sigmap[code] = pos; usable += 1; split[cls][1] += 1
    print(f"CENSUS usable-signal names (ACC): {usable}")
    print(f"CENSUS names with facts but no usable accruals event (role/interval gaps): {role_missing[0]}")
    print(f"CENSUS pre-window-filed dropped: {pre_window_dropped[0]}")
    print(f"CENSUS usable split: delisted={split['delisted'][1]} active={split['active'][1]}")

    legs = {}
    plac_a = {}; plac_b = {}
    print("\n=== ACC BASE leg ===", flush=True)
    legs["base"], stale = _invest_run_leg(clean, sigmap, wdates, 0, FRESH)
    yearly = {}
    for (H, p), s in stale.items():
        if H == 63:
            yearly.setdefault(wdates[p][:4], []).append(s)
    print("CENSUS ACC staleness drops (H63, mean/rebalance by year): "
          + " ".join(f"{y}:{sum(v)/len(v):.0f}" for y, v in sorted(yearly.items())))
    print("=== ACC S1' lag (+126) ===", flush=True)
    legs["lag"], _ = _invest_run_leg(clean, sigmap, wdates, LAG, FRESH)
    print("=== ACC S5 freshness-504 ===", flush=True)
    legs["s5"], _ = _invest_run_leg(clean, sigmap, wdates, 0, FRESH_S5)
    print("=== ACC S2b no-screen ===", flush=True)
    legs["s2b"], _ = _invest_run_leg(clean + screened, sigmap, wdates, 0, FRESH)
    print("=== ACC placebos x3 ===", flush=True)
    for seed in (1, 2, 3):
        plac_a[seed] = _invest_placebo_signal(clean, sigmap, wdates, seed)
        plac_b[seed] = _invest_placebo_returns(clean, sigmap, wdates, seed)

    keys = [(scope, H) for scope, _ in SCOPES for H in HORIZONS]
    srs = {}
    for (scope, H) in keys:
        d = legs["base"][(scope, H)]["d"]
        mu, sd, sk, ku = moments(d) if len(d) > 3 else (0, 0, 0, 3)
        srs[(scope, H)] = (0.0 if sd == 0 else mu / sd, sk, ku, len(d))
    vts = statistics.variance([s[0] for s in srs.values()])
    vts_f = max(vts, VAR_FLOOR)
    b6 = expected_max_sharpe(6 + PRIOR_ARMS, vts)
    b6f = expected_max_sharpe(6 + PRIOR_ARMS, vts_f)
    breg = expected_max_sharpe(6 + REGISTRY_ARMS, vts)
    print(f"\nvarTrialSharpe={vts:.6f} (floored {vts_f:.6f}); bench6={b6:.4f} "
          f"benchFloor={b6f:.4f} benchRegistry({6+REGISTRY_ARMS})={breg:.4f}")

    pmax_a = max((dsr_of(plac_a[seed][(scope, H)], b6)
                  for seed in (1, 2, 3) for scope, _ in SCOPES for H in HORIZONS), default=0.0)
    pmax_b = max((dsr_of(plac_b[seed][(scope, H)], b6)
                  for seed in (1, 2, 3) for scope, _ in SCOPES for H in HORIZONS), default=0.0)
    run_valid = pmax_a <= 0.95 and pmax_b <= 0.95
    print(f"S1'' signal-shuffle placebo max DSR={pmax_a:.3f}; S1''' returns-shuffle placebo max DSR={pmax_b:.3f} "
          f"-> run " + ("VALID" if run_valid else "INVALID (leak)"))

    results, passing, neg_flags = {}, [], []
    print(f"\n{'arm':12s} {'nblk':>4s} {'diff_mean':>10s} {'t':>6s} {'DSR6':>6s} {'DSRflr':>7s} "
          f"{'S2a':>6s} {'S2b':>6s} {'S1lag':>6s} {'S5':>8s} {'negDSR':>7s} {'cohG_t':>7s} {'eqwG_t':>7s}")
    for (scope, H) in keys:
        a = legs["base"][(scope, H)]
        d, dw, ds4 = a["d"], a["d_w"], a["d_s4"]
        sr, sk, ku, n = srs[(scope, H)]
        mu = sum(d) / n if n else 0.0
        dsr6 = psr(sr, n, sk, ku, b6); dsrflr = psr(sr, n, sk, ku, b6f)
        dsrreg = psr(sr, n, sk, ku, breg)
        s2a_d = dsr_of(dw, b6)
        s2b_d = dsr_of(legs["s2b"][(scope, H)]["d_w"], b6)
        s4_d = dsr_of(ds4, b6)
        lagd = legs["lag"][(scope, H)]["d"]
        lmu = (sum(lagd) / len(lagd)) if lagd else 0.0
        s1 = (mu >= 0) == (lmu >= 0)
        s5d = legs["s5"][(scope, H)]["d"]
        s5mu = (sum(s5d) / len(s5d)) if s5d else 0.0
        neg = psr(-sr, n, -sk, ku, b6)
        cg, eg = a["coh_g"], a["eqw_g"]
        ok = (run_valid and mu > 0 and dsr6 > 0.95 and dsrflr > 0.95
              and s2a_d > 0.95 and s2b_d > 0.95 and s1)
        if ok:
            passing.append((scope, H))
        nflag = (neg > 0.95 and s1 and dsr_of([-x for x in dw], b6) > 0.95
                 and dsr_of([-x for x in legs["s2b"][(scope, H)]["d_w"]], b6) > 0.95)
        if nflag:
            neg_flags.append((scope, H))
        arm = f"{scope}/H{H}"
        print(f"{arm:12s} {n:4d} {mu:+10.5f} {tstat(d):6.2f} {dsr6:6.3f} {dsrflr:7.3f} "
              f"{s2a_d:6.3f} {s2b_d:6.3f} {'Y' if s1 else 'N':>6s} {s5mu:+8.5f} {neg:7.3f} "
              f"{tstat(cg):7.2f} {tstat(eg):7.2f}")
        results[arm] = {
            "n_blocks": n, "diff_mean": mu, "diff_t": tstat(d), "diff_sharpe": sr,
            "diff_skew": sk, "diff_kurt": ku, "dsr_6": dsr6, "dsr_floor": dsrflr,
            "dsr_registry": dsrreg, "s2a_dsr": s2a_d, "s2b_dsr": s2b_d, "s4_dsr": s4_d,
            "s4_mean": (sum(ds4) / len(ds4)) if ds4 else None,
            "lag_mean": lmu, "s1_sign_agree": s1, "s5_mean": s5mu,
            "neg_dsr_6": neg, "passes": ok, "neg_flag": nflag,
            "coh_gross_mean": sum(cg) / n if n else None, "coh_gross_t": tstat(cg),
            "coh_gross_dsr": dsr_of(cg, b6),
            "eqw_gross_mean": sum(eg) / n if n else None, "eqw_gross_t": tstat(eg),
            "eqw_gross_dsr": dsr_of(eg, b6),
            "trunc_delisting": a["trunc_del"], "trunc_hole": a["trunc_hole"], "skips": a["skips"],
        }

    print(f"\nDECISION RULE (closed 6-arm set, trials=6, run_valid={run_valid}): "
          f"passing arms = {len(passing)}" + (f" {passing}" if passing else ""))
    print(f"Symmetric NEGATIVE flags: {len(neg_flags)}" + (f" {neg_flags}" if neg_flags else ""))
    print("VERDICT: " + ("PROMOTION CANDIDATE per prereg — owner presentation required" if passing
                         else "NULL on the 2010-2026 XBRL-era (POST-DECAY) survivorship-free "
                              "(retail-inclusive) population — the LONG leg of the accruals anomaly "
                              "(thin by construction; alpha short-concentrated AND long-dead post-2003); "
                              "the accruals ASSUMPTION becomes a long-leg MEASUREMENT, NOT a refutation "
                              "of the (pre-decay) academic anomaly"))

    _write_results(args.out, {
        "prereg": "PREREG_2026-07-15_accruals.md", "window": [WIN_LO, WIN_HI],
        "clean_names": len(clean), "screened": len(screened), "usable_signal_names": usable,
        "census_split": split, "census_role_missing": role_missing[0],
        "varTrialSharpe": vts, "bench_6": b6, "bench_floor": b6f, "bench_registry": breg,
        "placebo_signal_max_dsr": pmax_a, "placebo_returns_max_dsr": pmax_b, "run_valid": run_valid,
        "results": results,
        "passing": [f"{s}/H{h}" for s, h in passing],
        "neg_flags": [f"{s}/H{h}" for s, h in neg_flags]})
    print(f"results -> {args.out}")

    if args.ledger and not smoke:
        import subprocess
        run_id = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
        with open(LEDGER, "a") as f:
            for (scope, H) in keys:
                a = results[f"{scope}/H{H}"]
                f.write(json.dumps({
                    "family": "accruals", "run": run_id,
                    "panel": "eodhd-us-delisted+active-2026-07-10+edgar-facts-accruals",
                    "arm": f"{scope}/H{H}", "sharpe": a["diff_sharpe"],
                    "dsr": a["dsr_6"], "n": a["n_blocks"],
                    "verdict": "pass" if a["passes"] else "null",
                }) + "\n")
        print(f"LEDGER: appended {len(keys)} arms")


if __name__ == "__main__":
    main()
