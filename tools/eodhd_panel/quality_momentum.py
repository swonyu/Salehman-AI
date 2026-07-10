#!/usr/bin/env python3
"""PRE-REGISTERED quality × momentum composite ablation on the survivorship-free panel.

Pre-registration: tools/eodhd_panel/PREREG_2026-07-10_quality_momentum.md (design-reviewed,
committed at 1354b25 BEFORE any test statistic). Implements every pinned clause:

  QUALITY   GP/A per the audited gpa_quality rules incl. the pre-window filed drop (8d75a7a)
  MOMENTUM  adjc[p-21]/adjc[p-252]-1; endpoints valid prints AND >=200 valid prints in
            [p-252, p-21] (ghost-run guard, sibling BETA/IVOL precedent)
  COMPOSITE r[order[k]] = k/(n-1) per signal (stable sort, manifest-order ties);
            comp = (r_gpa + r_mom)/2; cohort = stable-desc top max(1, n//3)
  BOOKS     comp cohort + GP/A-only cohort + MOM-only cohort + ONE EQW, all on the SAME
            eligible set/grid (S5 component increments in-run; the 12 component-context
            arms are DIAGNOSTIC-class, no promotion path); NET LEVEL PRINTS ENFORCED by
            assert (the twice-failed promise, structurally closed)
  GRID      origin = window start + 252; H in {63,126,252}; window 2010-01-04..2026-07-09;
            panel-filter basis 2000-2026 (sibling, explicit)
  LEGS      S1' lag +63 signal-content-only | S1'' placebo comp-shuffle seeds 1/2/3 |
            S2a winsorized | S2b no-screen+winsorized | S4 Shumway
  TRIALS    primary = 6 + 6 (GP/A) + M (deduped momentum-family census read fresh via
            tools/trials_registry.py: tsmom-multiasset + momentum-sign/-intermediate/
            -industry/-residual; conditioning-overlay families excluded, stated);
            12-bench printed as context; varTrialSharpe floored 0.0343 BINDING
  DECISION  mu>0 AND dsr_primary>0.95 AND dsr_floor>0.95 AND s2a>0.95 AND s2b>0.95 AND
            s1lag AND s5_ok (sum(inc_g)>0 AND sum(inc_m)>0) AND run_valid; claim-language
            rule for non-separable passes; symmetric negative flags.

Usage: python3 quality_momentum.py [--ledger] [--out results.json]  [SMOKE=N env]
"""
import json, math, os, random, statistics, sys, argparse, bisect, subprocess
from array import array

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from smallcap_maxbabivol import (psr, expected_max_sharpe, moments, tstat, prep_name,
                                 selfcheck_drys, NAN, MIN_NAMES, BASE, MANIFEST, MARKET,
                                 REPO, LEDGER)
from gpa_quality import build_signal_events, FACTS, FRESH

WIN_LO, WIN_HI = "2010-01-04", "2026-07-09"
HORIZONS = [63, 126, 252]
SCOPES = [("FULL", 13.0), ("LOWLIQ", 60.0)]
WARMUP = 252
LAG = 63
MOM_MIN_PRINTS = 200
VAR_FLOOR = 0.0343
SHUMWAY = -0.30
MOM_FAMILIES = {"tsmom-multiasset", "momentum-sign", "momentum-intermediate",
                "momentum-industry", "momentum-residual"}


def momentum_prior_arms():
    """M read fresh via the registry consumer (deduped role=trial); fallback = raw line
    count over the same families (over-deflation, safe direction)."""
    try:
        out = subprocess.run([sys.executable, os.path.join(REPO, "tools", "trials_registry.py")],
                             capture_output=True, text=True, timeout=120, cwd=REPO).stdout
        m = 0
        for line in out.splitlines():
            t = line.strip()
            for fam in MOM_FAMILIES:
                if t.startswith(fam + ":"):
                    m += int(t.split(":")[1])
        if m > 0:
            return m, "registry-deduped"
    except Exception:
        pass
    m = 0
    with open(LEDGER) as f:
        for line in f:
            try:
                if json.loads(line).get("family") in MOM_FAMILIES: m += 1
            except json.JSONDecodeError:
                continue
    return m, "raw-line-fallback"


def rank01(vals, codes):
    """Prereg-pinned: codes in manifest order; stable sort by value; r = k/(n-1)."""
    n = len(codes)
    order = sorted(range(n), key=lambda i: vals[i])
    r = [0.0] * n
    for k, idx in enumerate(order):
        r[idx] = k / (n - 1)
    return r


def selfcheck_rank():
    # values with a tie: manifest order breaks it (stable sort)
    r = rank01([0.5, 0.2, 0.5, 0.9], ["A", "B", "C", "D"])
    assert r == [1/3, 0.0, 2/3, 1.0], r          # A before C on the tie
    print("selfcheck PASS: rank01 pinned form (k/(n-1), stable ties by manifest order)")


def derive(nm):
    N = len(nm["open"])
    prints = [j for j in range(N) if not math.isnan(nm["open"][j])]
    cpre = array("l", [0] * (N + 1))              # prefix count of valid CLOSE prints
    c = nm["close"]
    for j in range(N):
        cpre[j + 1] = cpre[j] + (0 if math.isnan(c[j]) else 1)
    return {"prints": prints, "cpre": cpre}


def run_leg(names, sigmap, wdates, lag, tag):
    """One pass. Returns arms[(scope,H)] with composite + component + EQW block series."""
    N = len(wdates)
    ders = {nm["code"]: derive(nm) for nm in names}
    byc = {nm["code"]: nm for nm in names}
    arms = {}
    for H in HORIZONS:
        for scope, _ in SCOPES:
            arms[(scope, H)] = {"d": [], "d_w": [], "d_s4": [], "dg": [], "dm": [],
                                "coh_g": [], "eqw_g": [], "elig": [], "ov_g": [], "ov_m": [],
                                "trunc_del": 0, "trunc_hole": 0, "skips": 0}
        p = WARMUP
        while p + 1 + H <= N - 1:
            target = p + 1 + H
            codes, gvals, mvals, liq = [], [], [], {}
            for code, nm in byc.items():           # manifest order preserved (clean-list order)
                if math.isnan(nm["open"][p + 1]): continue
                d_ = ders[code]
                # momentum validity (lagged endpoints per prereg: signal content only)
                e_hi, e_lo = p - 21 - lag, p - 252 - lag
                if e_lo < 0: continue
                c = nm["close"]
                if math.isnan(c[e_hi]) or math.isnan(c[e_lo]): continue
                if d_["cpre"][e_hi + 1] - d_["cpre"][e_lo] < MOM_MIN_PRINTS: continue
                # GP/A freshness (lagged availability)
                evs = sigmap.get(code)
                if not evs: continue
                cur = None
                for av, fp_, end, g in reversed(evs):
                    if av + lag <= p: cur = (av, fp_, end, g); break
                if cur is None or cur[1] + lag < p - FRESH + 1: continue
                dvw = [nm["dv"][j] for j in range(max(0, p - 62), p + 1) if not math.isnan(nm["dv"][j])]
                if not dvw: continue
                codes.append(code); gvals.append(cur[3])
                mvals.append(c[e_hi] / c[e_lo] - 1.0); liq[code] = statistics.median(dvw)
            if len(codes) < MIN_NAMES:
                for scope, _ in SCOPES: arms[(scope, H)]["skips"] += 1
                p += H; continue
            ranked = sorted(codes, key=lambda cc: liq[cc])
            lowliq = set(ranked[: max(1, len(ranked) // 3)])
            brets, dele = {}, {}
            for code in codes:
                pr = ders[code]["prints"]
                e = pr[bisect.bisect_right(pr, target) - 1]
                nm = byc[code]
                brets[code] = nm["open"][e] / nm["open"][p + 1] - 1.0
                if e < target: dele[code] = pr[-1] < target
            for scope, _ in SCOPES:
                idxs = [i for i, cc in enumerate(codes) if scope == "FULL" or cc in lowliq]
                a = arms[(scope, H)]
                if len(idxs) < MIN_NAMES:
                    a["skips"] += 1; continue
                sc = [codes[i] for i in idxs]
                rg = rank01([gvals[i] for i in idxs], sc)
                rm = rank01([mvals[i] for i in idxs], sc)
                comp = [(rg[i] + rm[i]) / 2 for i in range(len(sc))]
                k3 = max(1, len(sc) // 3)
                def top(vals):
                    order = sorted(range(len(sc)), key=lambda i: vals[i], reverse=True)
                    return [sc[i] for i in order[:k3]]
                coh, coh_g, coh_m = top(comp), top(rg), top(rm)
                def bmean(cs, wins=False, s4=False):
                    tot = 0.0
                    for cc in cs:
                        r = brets[cc]
                        if s4 and dele.get(cc) is True: r = (1 + r) * (1 + SHUMWAY) - 1
                        if wins: r = min(max(r, -1.0), 1.0)
                        tot += r
                    return tot / len(cs)
                em = bmean(sc)
                cm = bmean(coh)
                a["d"].append(cm - em)
                a["d_w"].append(bmean(coh, wins=True) - bmean(sc, wins=True))
                a["d_s4"].append(bmean(coh, s4=True) - bmean(sc, s4=True))
                a["dg"].append(bmean(coh_g) - em)
                a["dm"].append(bmean(coh_m) - em)
                a["coh_g"].append(cm); a["eqw_g"].append(em); a["elig"].append(len(sc))
                cs_ = set(coh)
                a["ov_g"].append(len(cs_ & set(coh_g)) / k3)
                a["ov_m"].append(len(cs_ & set(coh_m)) / k3)
                a["trunc_del"] += sum(1 for cc in coh if dele.get(cc) is True)
                a["trunc_hole"] += sum(1 for cc in coh if dele.get(cc) is False)
            p += H
    return arms


def placebo_leg(names, sigmap, wdates, seed):
    """S1'': composite values shuffled cross-sectionally per rebalance (pinned seeds)."""
    rng = random.Random(seed)
    N = len(wdates)
    ders = {nm["code"]: derive(nm) for nm in names}
    byc = {nm["code"]: nm for nm in names}
    out = {}
    for H in HORIZONS:
        for scope, _ in SCOPES: out[(scope, H)] = []
        p = WARMUP
        while p + 1 + H <= N - 1:
            target = p + 1 + H
            codes, gvals, mvals, liq = [], [], [], {}
            for code, nm in byc.items():
                if math.isnan(nm["open"][p + 1]): continue
                d_ = ders[code]
                e_hi, e_lo = p - 21, p - 252
                if e_lo < 0: continue
                c = nm["close"]
                if math.isnan(c[e_hi]) or math.isnan(c[e_lo]): continue
                if d_["cpre"][e_hi + 1] - d_["cpre"][e_lo] < MOM_MIN_PRINTS: continue
                evs = sigmap.get(code)
                if not evs: continue
                cur = None
                for av, fp_, end, g in reversed(evs):
                    if av <= p: cur = (av, fp_, end, g); break
                if cur is None or cur[1] < p - FRESH + 1: continue
                dvw = [nm["dv"][j] for j in range(max(0, p - 62), p + 1) if not math.isnan(nm["dv"][j])]
                if not dvw: continue
                codes.append(code); gvals.append(cur[3])
                mvals.append(c[e_hi] / c[e_lo] - 1.0); liq[code] = statistics.median(dvw)
            if len(codes) < MIN_NAMES:
                p += H; continue
            ranked = sorted(codes, key=lambda cc: liq[cc])
            lowliq = set(ranked[: max(1, len(ranked) // 3)])
            brets = {}
            for code in codes:
                pr = ders[code]["prints"]
                e = pr[bisect.bisect_right(pr, target) - 1]
                brets[code] = byc[code]["open"][e] / byc[code]["open"][p + 1] - 1.0
            for scope, _ in SCOPES:
                idxs = [i for i, cc in enumerate(codes) if scope == "FULL" or cc in lowliq]
                if len(idxs) < MIN_NAMES: continue
                sc = [codes[i] for i in idxs]
                rg = rank01([gvals[i] for i in idxs], sc)
                rm = rank01([mvals[i] for i in idxs], sc)
                comp = [(rg[i] + rm[i]) / 2 for i in range(len(sc))]
                rng.shuffle(comp)                     # the placebo: composite shuffled per rebalance
                order = sorted(range(len(sc)), key=lambda i: comp[i], reverse=True)
                coh = [sc[i] for i in order[: max(1, len(sc) // 3)]]
                out[(scope, H)].append(sum(brets[cc] for cc in coh) / len(coh)
                                       - sum(brets[cc] for cc in sc) / len(sc))
            p += H
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--out", default=os.path.join(BASE, "quality_momentum_results.json"))
    args = ap.parse_args()
    smoke = int(os.environ.get("SMOKE", "0"))

    selfcheck_rank()
    selfcheck_drys()
    M, msrc = momentum_prior_arms()
    PRIMARY_TRIALS = 6 + 6 + M
    print(f"momentum prior arms M={M} ({msrc}) -> primary trials={PRIMARY_TRIALS}")

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
                cands.append(m["code"])
    if smoke: cands = cands[:smoke]
    rej = {"short": 0, "entry_price": 0, "dollar_vol": 0, "gap": 0, "load": 0}
    clean, screened = [], []
    for i, code in enumerate(cands):
        if i % 4000 == 0: print(f"  prep {i}/{len(cands)}", flush=True)
        nm = prep_name(code, wdates, wpos, rej)
        if nm is None: continue
        (screened if nm["screen"] else clean).append(nm)
    print(f"prep done: clean={len(clean)} screened={len(screened)} rejections={rej}")

    # GP/A signal events (audited builder + the 8d75a7a pre-window drop, re-specified per prereg)
    def build_sigmap(nms):
        smap, pre_drop = {}, 0
        for nm in nms:
            path = os.path.join(FACTS, nm["code"] + ".json")
            if not os.path.exists(path): continue
            r = json.load(open(path))
            if r.get("missing"): continue
            evs, _ = build_signal_events(r)
            pos = []
            for end, filed, g in evs:
                if filed < WIN_LO: pre_drop += 1; continue
                av = bisect.bisect_right(wdates, filed)
                if av < N: pos.append((av, av, end, g))
            if pos: smap[nm["code"]] = pos
        return smap, pre_drop
    sigmap, pre_drop = build_sigmap(clean + screened)
    print(f"GP/A-usable names: {len(sigmap)}; CENSUS pre-window-filed dropped: {pre_drop}")

    print("\n=== BASE leg ===", flush=True)
    base = run_leg(clean, sigmap, wdates, 0, "base")
    print("=== S1' lag +63 leg ===", flush=True)
    lagl = run_leg(clean, sigmap, wdates, LAG, "lag")
    print("=== S2b no-screen leg ===", flush=True)
    s2b = run_leg(clean + screened, sigmap, wdates, 0, "s2b")
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
    bP = expected_max_sharpe(PRIMARY_TRIALS, vts)
    bPf = expected_max_sharpe(PRIMARY_TRIALS, vts_f)
    b12 = expected_max_sharpe(12, vts)
    print(f"\nvarTrialSharpe={vts:.6f} (floored {vts_f:.6f}); benchPrimary({PRIMARY_TRIALS})={bP:.4f} "
          f"benchFloor={bPf:.4f} bench12(context)={b12:.4f}")

    def dsr_of(series, bench):
        if len(series) < 4: return 0.0
        m, s, a, b_ = moments(series)
        r = 0.0 if s == 0 else m / s
        return psr(r, len(series), a, b_, bench)

    placebo_max = max((dsr_of(pl[k], bP) for pl in plac for k in keys), default=0.0)
    run_valid = placebo_max <= 0.95
    print(f"S1'' placebo max DSR (3 seeds x 6 arms): {placebo_max:.3f} -> run "
          + ("VALID" if run_valid else "INVALID (machinery leak)"))

    results, passing, neg_flags = {}, [], []
    print(f"\n{'arm':12s} {'nblk':>4s} {'diff_mean':>10s} {'t':>6s} {'DSRp':>6s} {'DSRflr':>7s} "
          f"{'S2a':>6s} {'S2b':>6s} {'S1':>3s} {'s5g':>9s} {'s5m':>9s} {'negDSR':>7s}")
    for k in keys:
        scope, H = k
        rt = dict(SCOPES)[scope]
        a = base[k]
        d = a["d"]; n = len(d)
        sr, sk, ku, _ = srs[k]
        mu = sum(d) / n if n else 0.0
        dsrP = psr(sr, n, sk, ku, bP); dsrflr = psr(sr, n, sk, ku, bPf)
        dsr12 = psr(sr, n, sk, ku, b12)
        s2a_d = dsr_of(a["d_w"], bP); s2b_d = dsr_of(s2b[k]["d_w"], bP)
        lmu = (sum(lagl[k]["d"]) / len(lagl[k]["d"])) if lagl[k]["d"] else 0.0
        s1 = (mu >= 0) == (lmu >= 0)
        inc_g = [x - y for x, y in zip(d, a["dg"])]
        inc_m = [x - y for x, y in zip(d, a["dm"])]
        s5_ok = sum(inc_g) > 0 and sum(inc_m) > 0
        neg = psr(-sr, n, -sk, ku, bP)
        ok = (run_valid and mu > 0 and dsrP > 0.95 and dsrflr > 0.95
              and s2a_d > 0.95 and s2b_d > 0.95 and s1 and s5_ok)
        if ok: passing.append(k)
        nflag = (neg > 0.95 and s1 and dsr_of([-x for x in a["d_w"]], bP) > 0.95
                 and dsr_of([-x for x in s2b[k]["d_w"]], bP) > 0.95)
        if nflag: neg_flags.append(k)
        arm = f"{scope}/H{H}"
        print(f"{arm:12s} {n:4d} {mu:+10.5f} {tstat(d):6.2f} {dsrP:6.3f} {dsrflr:7.3f} "
              f"{s2a_d:6.3f} {s2b_d:6.3f} {'Y' if s1 else 'N':>3s} {sum(inc_g)/max(1,n):+9.5f} "
              f"{sum(inc_m)/max(1,n):+9.5f} {neg:7.3f}")
        results[arm] = {
            "n_blocks": n, "diff_mean": mu, "diff_t": tstat(d), "diff_sharpe": sr,
            "diff_skew": sk, "diff_kurt": ku,
            "dsr_primary": dsrP, "dsr_floor": dsrflr, "dsr_12_context": dsr12,
            "s2a_dsr": s2a_d, "s2b_dsr": s2b_d,
            "s4_mean": (sum(a["d_s4"]) / n) if n else None, "s4_dsr": dsr_of(a["d_s4"], bP),
            "lag_mean": lmu, "s1_sign_agree": s1,
            "s5_ok": s5_ok, "inc_gpa_mean": sum(inc_g) / n if n else None,
            "inc_gpa_t": tstat(inc_g), "inc_gpa_dsr": dsr_of(inc_g, bP),
            "inc_mom_mean": sum(inc_m) / n if n else None,
            "inc_mom_t": tstat(inc_m), "inc_mom_dsr": dsr_of(inc_m, bP),
            "comp_gpa_diff_mean": sum(a["dg"]) / n if n else None, "comp_gpa_diff_t": tstat(a["dg"]),
            "comp_mom_diff_mean": sum(a["dm"]) / n if n else None, "comp_mom_diff_t": tstat(a["dm"]),
            "neg_dsr_primary": neg, "passes": ok, "neg_flag": nflag,
            "coh_gross_mean": sum(a["coh_g"]) / n if n else None, "coh_gross_t": tstat(a["coh_g"]),
            "eqw_gross_mean": sum(a["eqw_g"]) / n if n else None, "eqw_gross_t": tstat(a["eqw_g"]),
            "coh_net_mean": (sum(a["coh_g"]) / n - rt * 1e-4) if n else None,
            "eqw_net_mean": (sum(a["eqw_g"]) / n - rt * 1e-4) if n else None,
            "overlap_comp_gpa": sum(a["ov_g"]) / n if n else None,
            "overlap_comp_mom": sum(a["ov_m"]) / n if n else None,
            "eligible_median": int(statistics.median(a["elig"])) if a["elig"] else 0,
            "trunc_delisting": a["trunc_del"], "trunc_hole": a["trunc_hole"], "skips": a["skips"],
        }

    # PREREG ENFORCEMENT (review #7): net level prints must exist on every NON-EMPTY arm, both
    # books (an arm with zero blocks has no levels — smoke-sample legitimate, not a violation).
    for arm, a in results.items():
        if a["n_blocks"] == 0: continue
        for f_ in ("coh_net_mean", "eqw_net_mean"):
            assert a.get(f_) is not None, f"PREREG VIOLATION: net level missing on {arm}"
    print("selfcheck PASS: net level prints present on all arms (prereg enforcement)")

    print(f"\nDECISION RULE (closed 6-arm set, primary trials={PRIMARY_TRIALS}, run_valid={run_valid}): "
          f"passing arms = {len(passing)}" + (f" {passing}" if passing else ""))
    print(f"Symmetric NEGATIVE flags: {len(neg_flags)}" + (f" {neg_flags}" if neg_flags else ""))
    print("VERDICT: " + ("PROMOTION CANDIDATE per prereg (claim-language rule applies)" if passing
                         else "NULL — the composite space closes; further combinations are fenced "
                              "post-hoc mining"))

    with open(args.out, "w") as f:
        json.dump({"prereg": "PREREG_2026-07-10_quality_momentum.md", "window": [WIN_LO, WIN_HI],
                   "clean_names": len(clean), "screened": len(screened),
                   "gpa_usable": len(sigmap), "pre_window_dropped": pre_drop,
                   "momentum_prior_arms": M, "momentum_prior_src": msrc,
                   "primary_trials": PRIMARY_TRIALS, "varTrialSharpe": vts,
                   "bench_primary": bP, "bench_floor": bPf, "bench_12_context": b12,
                   "placebo_max_dsr": placebo_max, "run_valid": run_valid,
                   "results": results,
                   "passing": [f"{s}/H{h}" for s, h in passing],
                   "neg_flags": [f"{s}/H{h}" for s, h in neg_flags]}, f, indent=1)
    print(f"results -> {args.out}")

    if args.ledger and not smoke:
        run_id = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
        with open(LEDGER, "a") as f:
            for k in keys:
                scope, H = k
                a = results[f"{scope}/H{H}"]
                f.write(json.dumps({
                    "family": "quality-momentum", "run": run_id,
                    "panel": "eodhd-us-delisted+active-2026-07-10+edgar-facts",
                    "arm": f"{scope}/H{H}", "sharpe": a["diff_sharpe"],
                    "dsr": a["dsr_primary"], "n": a["n_blocks"],
                    "verdict": "pass" if a["passes"] else "null",
                }) + "\n")
                for comp, mkey in (("gpa", "comp_gpa_diff_mean"), ("mom", "comp_mom_diff_mean")):
                    f.write(json.dumps({
                        "family": "quality-momentum", "run": run_id, "role": "diagnostic",
                        "panel": "eodhd-us-delisted+active-2026-07-10+edgar-facts",
                        "arm": f"component-{comp}/{scope}/H{H}",
                        "mean": a[mkey], "n": a["n_blocks"], "verdict": "diagnostic",
                    }) + "\n")
        print(f"LEDGER: appended {len(keys)} decision arms + {2*len(keys)} diagnostic component arms")


if __name__ == "__main__":
    main()
