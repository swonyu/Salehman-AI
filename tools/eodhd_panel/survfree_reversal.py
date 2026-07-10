#!/usr/bin/env python3
"""PRE-REGISTERED short-horizon reversal at FULL survivorship-free breadth.

Pre-registration: tools/eodhd_panel/PREREG_2026-07-10_survfree_reversal.md
(committed at 1601771 BEFORE any statistic; shared elements inherit the sibling
prereg's design-review fixes — the shared machinery is IMPORTED from the
verified smallcap_maxbabivol.py, so a fix there propagates here).

  SIGNAL   r_lb = adjc[p]/adjc[p-lb] - 1, BOTH endpoint bars valid prints (volume>0, close>0)
  WEIGHTS  w_i propto -(r_lb - mean), L1-normalized to gross 1 — the SHIPPED irrxWeights shape
           under broad demeaning; selfcheck pins the verbatim-Swift fixture anchors at 12dp
           (weights [-0.016129032258, -0.016129032258, -0.467741935484, +0.500000000000];
            rebalance gross -0.002564516129 turnover 1.0 net -0.003214516129 @ rt13/hold3)
  BOOKS    entry raw-open print at p+1; exit last valid print <= p+1+hold (booked truncation);
           gross = sum(w*r); turnover = sum|w - prevW_as-set| (full on first);
           net = gross - turnover*(rt/2/1e4) — the shipped per-side accounting
  GRID     lb {5,10,21,63} x hold {5,10,21}; scopes FULL@13bps, LOWLIQ@60bps (ratified tier;
           other tier printed as sensitivity); 24 decision arms
  STATS    DSR trials 24+98=122 (registry 24+701=725); varTrialSharpe floored 0.0343 (binding print)
  SENSITIV S1 REVERSED sign-agreement | S2a winsorized +/-100% | S2b no-screen+winsorized
           | S3 long-leg-only sub-print | S4 Shumway -30% on delisting-truncated exits
  DECISION pass iff net_mean>0 AND dsr122>0.95 AND dsr_floor>0.95 AND s2a>0.95 AND s2b>0.95
           AND s1 AND s3 long-leg positive-net; symmetric negative pre-commitment; closed 24-arm set.

Usage: python3 survfree_reversal.py [--ledger] [--out results.json]  [SMOKE=N env]
"""
import json, math, os, statistics, sys, argparse, bisect
from array import array

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from smallcap_maxbabivol import (psr, expected_max_sharpe, moments, tstat, adjust,
                                 prep_name, selfcheck_drys, NAN, ND, MIN_NAMES,
                                 WIN_LO, WIN_HI, BASE, MANIFEST, MARKET, REPO, LEDGER)

LOOKBACKS = [5, 10, 21, 63]
HOLDS = [5, 10, 21]
SCOPES = [("FULL", 13.0), ("LOWLIQ", 60.0)]     # ratified cost tier per scope; other tier = sensitivity print
WARMUP = 63                                       # max(lb) = liquidity window; uniform start for every config
PRIOR_ARMS = 98                                   # ledger census: reversal-irrx
REGISTRY_ARMS = 701
VAR_FLOOR = 0.0343
SHUMWAY = -0.30


def irrx_shape_weights(vals):
    """The shipped irrxWeights construction under broad demeaning: keys->weight, gross 1."""
    codes = list(vals.keys())
    mean = sum(vals.values()) / len(codes)
    raw = {c: -(vals[c] - mean) for c in codes}
    m2 = sum(raw.values()) / len(codes)
    raw = {c: raw[c] - m2 for c in codes}
    g = sum(abs(x) for x in raw.values())
    if g <= 0:
        return {}
    return {c: raw[c] / g for c in codes}


def selfcheck_fixture():
    rets = [
        [0.010, -0.020, 0.030, 0.005, -0.010, 0.020, 0.001, -0.003],
        [-0.005, 0.015, -0.025, 0.010, 0.020, -0.010, 0.002, 0.004],
        [0.030, 0.010, 0.020, -0.015, 0.005, 0.015, -0.020, 0.010],
        [-0.010, -0.005, 0.000, 0.020, -0.030, 0.005, 0.010, -0.015],
    ]
    vals = {i: sum(rets[i][0:5]) for i in range(4)}
    w = irrx_shape_weights(vals)
    exp = [-0.016129032258, -0.016129032258, -0.467741935484, 0.500000000000]
    assert all(abs(w[i] - exp[i]) < 1e-12 for i in range(4)), f"weight fixture mismatch {w}"
    gross = sum(w[i] * sum(rets[i][5:8]) for i in range(4))
    turn = sum(abs(x) for x in w.values())
    net = gross - turn * 13 / 2 / 1e4
    assert abs(gross - -0.002564516129) < 1e-12 and abs(net - -0.003214516129) < 1e-12
    print("selfcheck PASS: shipped irrxWeights/rebalance fixture anchors (12dp, verbatim-Swift-derived)")


def prep_universe(smoke):
    cands = []
    with open(MANIFEST) as f:
        for line in f:
            m = json.loads(line)
            if m.get("status") == "ok" and m["first"] <= WIN_HI and m["delist"] >= WIN_LO:
                cands.append(m["code"])
    if smoke:
        cands = cands[:smoke]
    rec = json.load(open(MARKET))
    mbars = rec["eod"] if isinstance(rec, dict) else rec
    wdates = [b["date"] for b in mbars if WIN_LO <= b["date"] <= WIN_HI]
    wpos = {d: i for i, d in enumerate(wdates)}
    rej = {"short": 0, "entry_price": 0, "dollar_vol": 0, "gap": 0, "load": 0}
    clean, screened = [], []
    for i, code in enumerate(cands):
        if i % 4000 == 0:
            print(f"  prep {i}/{len(cands)}", flush=True)
        nm = prep_name(code, wdates, wpos, rej)
        if nm is None:
            continue
        (screened if nm["screen"] else clean).append(nm)
    print(f"prep done: clean={len(clean)} screened={len(screened)} rejections={rej}")
    return wdates, clean, screened


def derive(nm):
    prints = [j for j in range(len(nm["open"])) if not math.isnan(nm["open"][j])]
    return {"prints": prints}


def run_pass(names, wdates, tag):
    """Returns arms[(lb,hold,scope)] = block series dicts."""
    N = len(wdates)
    ders = {nm["code"]: derive(nm) for nm in names}
    byc = {nm["code"]: nm for nm in names}
    arms = {}
    for hold in HOLDS:
        rebs = list(range(WARMUP, N - 1 - hold, hold))
        # per-rebalance eligibility + liquidity + signal endpoints, shared across lb for this hold grid
        for lb in LOOKBACKS:
            for scope, _ in SCOPES:
                arms[(lb, hold, scope)] = {"g": [], "net_r": [], "w_r": [], "b_r": [], "s4_r": [],
                                           "lg_r": [], "turn": [], "trunc_del": 0, "trunc_hole": 0,
                                           "skips": 0, "prevw": {}, "prevw_lg": {}}
        for n_i, p in enumerate(rebs):
            if n_i % 200 == 0:
                print(f"  [{tag}] hold={hold} reb {n_i}/{len(rebs)}", flush=True)
            target = p + 1 + hold
            # eligibility: valid entry print at p+1, valid close endpoints for EVERY lb handled per-lb;
            # liquidity: median of present dv in (p-62..p]
            elig, liq = [], {}
            for code, nm in byc.items():
                if math.isnan(nm["open"][p + 1]):
                    continue
                if math.isnan(nm["close"][p]):
                    continue
                dvw = [nm["dv"][j] for j in range(p - 62, p + 1) if not math.isnan(nm["dv"][j])]
                if not dvw:
                    continue
                elig.append(code)
                liq[code] = statistics.median(dvw)
            if len(elig) < MIN_NAMES:
                for lb in LOOKBACKS:
                    for scope, _ in SCOPES:
                        arms[(lb, hold, scope)]["skips"] += 1
                continue
            ranked = sorted(elig, key=lambda c: liq[c])
            lowliq = set(ranked[: max(1, len(ranked) // 3)])
            # block returns per eligible name (exit = last valid print <= target)
            brets, dele = {}, {}
            for code in elig:
                pr = ders[code]["prints"]
                k = bisect.bisect_right(pr, target) - 1
                e = pr[k]
                nm = byc[code]
                brets[code] = nm["open"][e] / nm["open"][p + 1] - 1.0
                if e < target:
                    dele[code] = pr[-1] < target
            for lb in LOOKBACKS:
                sig = {}
                for code in elig:
                    c = byc[code]["close"]
                    if p - lb >= 0 and not math.isnan(c[p - lb]):
                        sig[code] = c[p] / c[p - lb] - 1.0
                for scope, _rt in SCOPES:
                    members = [c for c in sig if scope == "FULL" or c in lowliq]
                    a = arms[(lb, hold, scope)]
                    if len(members) < MIN_NAMES:
                        a["skips"] += 1; continue
                    w = irrx_shape_weights({c: sig[c] for c in members})
                    if not w:
                        a["skips"] += 1; continue
                    gross = sum(w[c] * brets[c] for c in w)
                    wins = sum(w[c] * min(max(brets[c], -1.0), 1.0) for c in w)
                    s4 = sum(w[c] * (((1 + brets[c]) * (1 + SHUMWAY) - 1) if dele.get(c) else brets[c])
                             for c in w)
                    # long-leg-only sub-book (S3): positive weights renormalized to gross 1
                    lpos = {c: x for c, x in w.items() if x > 0}
                    lg = sum(lpos.values())
                    lgross = sum((x / lg) * brets[c] for c, x in lpos.items()) if lg > 0 else 0.0
                    turn = sum(abs(w.get(c, 0.0) - a["prevw"].get(c, 0.0))
                               for c in set(w) | set(a["prevw"]))
                    lturn = sum(abs((lpos.get(c, 0.0) / lg if lg > 0 else 0.0) - a["prevw_lg"].get(c, 0.0))
                                for c in set(lpos) | set(a["prevw_lg"]))
                    a["g"].append(gross); a["w_r"].append(wins); a["s4_r"].append(s4)
                    a["turn"].append(turn)
                    a["lg_r"].append((lgross, lturn))
                    a["prevw"] = w
                    a["prevw_lg"] = {c: x / lg for c, x in lpos.items()} if lg > 0 else {}
                    a["trunc_del"] += sum(1 for c in w if dele.get(c) is True)
                    a["trunc_hole"] += sum(1 for c in w if dele.get(c) is False)
    return arms


def net_series(a, rt):
    per = rt / 2 / 1e4
    return [g - t * per for g, t in zip(a["g"], a["turn"])]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--out", default=os.path.join(BASE, "survfree_reversal_results.json"))
    args = ap.parse_args()
    smoke = int(os.environ.get("SMOKE", "0"))

    selfcheck_fixture()
    selfcheck_drys()
    wdates, clean, screened = prep_universe(smoke)
    print("\n=== PASS 1/3: PRIMARY forward ===", flush=True)
    fwd = run_pass(clean, wdates, "fwd")
    print("=== PASS 2/3: PRIMARY reversed (S1) ===", flush=True)
    rev_names = [{"code": nm["code"], "close": array("d", reversed(nm["close"])),
                  "open": array("d", reversed(nm["open"])), "dv": array("d", reversed(nm["dv"])),
                  "screen": nm["screen"]} for nm in clean]
    rev = run_pass(rev_names, wdates, "rev")
    print("=== PASS 3/3: S2b no-screen forward ===", flush=True)
    s2b = run_pass(clean + screened, wdates, "s2b")

    keys = [(lb, hold, scope) for lb in LOOKBACKS for hold in HOLDS for scope, _ in SCOPES]
    scope_rt = dict(SCOPES)
    srs = {}
    for k in keys:
        lb, hold, scope = k
        nets = net_series(fwd[k], scope_rt[scope])
        mu, sd, sk, ku = moments(nets) if len(nets) > 3 else (0, 0, 0, 3)
        srs[k] = (0.0 if sd == 0 else mu / sd, sk, ku, len(nets))
    vts = statistics.variance([s[0] for s in srs.values()])
    vts_f = max(vts, VAR_FLOOR)
    b122 = expected_max_sharpe(24 + PRIOR_ARMS, vts)
    b122f = expected_max_sharpe(24 + PRIOR_ARMS, vts_f)
    b725 = expected_max_sharpe(24 + REGISTRY_ARMS, vts)
    print(f"\nvarTrialSharpe={vts:.6f} (floored {vts_f:.6f}); bench122={b122:.4f} "
          f"benchFloor={b122f:.4f} bench725={b725:.4f}")

    def dsr_of(series, bench):
        if len(series) < 4: return 0.0
        m, s, a, b = moments(series)
        r = 0.0 if s == 0 else m / s
        return psr(r, len(series), a, b, bench)

    results, passing, neg_flags = {}, [], []
    print(f"\n{'arm':18s} {'nblk':>5s} {'gross_mu':>9s} {'net_mu':>9s} {'t':>6s} {'DSR122':>7s} "
          f"{'DSRflr':>7s} {'S2a':>6s} {'S2b':>6s} {'S1':>3s} {'S3net':>9s} {'negDSR':>7s} {'turn':>5s}")
    for k in keys:
        lb, hold, scope = k
        rt = scope_rt[scope]
        a = fwd[k]
        nets = net_series(a, rt)
        n = len(nets)
        mu = sum(nets) / n if n else 0.0
        gmu = sum(a["g"]) / n if n else 0.0
        sr, sk, ku, _ = srs[k]
        per = rt / 2 / 1e4
        w_nets = [g - t * per for g, t in zip(a["w_r"], a["turn"])]
        b_nets = net_series(s2b[k], rt)
        s4_nets = [g - t * per for g, t in zip(a["s4_r"], a["turn"])]
        r_nets = net_series(rev[k], rt)
        lg_nets = [g - t * per for g, t in a["lg_r"]]
        dsr122 = psr(sr, n, sk, ku, b122)
        dsrflr = psr(sr, n, sk, ku, b122f)
        dsr725 = psr(sr, n, sk, ku, b725)
        s2a_d = dsr_of(w_nets, b122); s2b_d = dsr_of(b_nets, b122)
        neg = psr(-sr, n, -sk, ku, b122)
        rmu = sum(r_nets) / len(r_nets) if r_nets else 0.0
        s1 = (mu >= 0) == (rmu >= 0)
        lg_mu = sum(lg_nets) / len(lg_nets) if lg_nets else 0.0
        ok = (mu > 0 and dsr122 > 0.95 and dsrflr > 0.95 and s2a_d > 0.95 and s2b_d > 0.95
              and s1 and lg_mu > 0)
        if ok: passing.append(k)
        nflag = (neg > 0.95 and s1 and dsr_of([-x for x in w_nets], b122) > 0.95
                 and dsr_of([-x for x in b_nets], b122) > 0.95)
        if nflag: neg_flags.append(k)
        arm = f"lb{lb}/hd{hold}/{scope}"
        print(f"{arm:18s} {n:5d} {gmu:+9.5f} {mu:+9.5f} {tstat(nets):6.2f} {dsr122:7.3f} "
              f"{dsrflr:7.3f} {s2a_d:6.3f} {s2b_d:6.3f} {'Y' if s1 else 'N':>3s} {lg_mu:+9.5f} "
              f"{neg:7.3f} {sum(a['turn'])/n if n else 0:5.2f}")
        alt_rt = 60.0 if rt == 13.0 else 13.0
        alt_nets = net_series(a, alt_rt)
        results[arm] = {
            "n_blocks": n, "rt_bps": rt, "gross_mean": gmu, "net_mean": mu, "net_t": tstat(nets),
            "net_sharpe": sr, "net_skew": sk, "net_kurt": ku,
            "dsr_122": dsr122, "dsr_floor": dsrflr, "dsr_725": dsr725,
            "s2a_dsr": s2a_d, "s2b_dsr": s2b_d,
            "s4_mean": sum(s4_nets) / n if n else None, "s4_t": tstat(s4_nets),
            "rev_mean": rmu, "s1_sign_agree": s1,
            "s3_longleg_net_mean": lg_mu, "s3_longleg_net_t": tstat(lg_nets),
            "neg_dsr_122": neg, "passes": ok, "neg_flag": nflag,
            "alt_rt_net_mean": sum(alt_nets) / n if n else None,
            "mean_turnover": sum(a["turn"]) / n if n else None,
            "trunc_delisting": a["trunc_del"], "trunc_hole": a["trunc_hole"], "skips": a["skips"],
        }

    print(f"\nDECISION RULE (closed 24-arm set, trials=122): passing arms = {len(passing)}"
          + (f" {passing}" if passing else ""))
    print(f"Symmetric NEGATIVE flags: {len(neg_flags)}" + (f" {neg_flags}" if neg_flags else ""))
    print("VERDICT: " + ("PROMOTION CANDIDATE per prereg — owner presentation required" if passing
                         else "NULL — RefuseList naive-reversal fence re-confirmed at the strongest "
                              "substrate; the milestone row's delisting-inclusive residual is ANSWERED "
                              "for the reversal family"))

    with open(args.out, "w") as f:
        json.dump({"prereg": "PREREG_2026-07-10_survfree_reversal.md",
                   "window": [WIN_LO, WIN_HI], "clean_names": len(clean),
                   "screened": len(screened), "varTrialSharpe": vts,
                   "bench_122": b122, "bench_floor": b122f, "bench_725": b725,
                   "results": results,
                   "passing": [f"lb{a}/hd{b}/{c}" for a, b, c in passing],
                   "neg_flags": [f"lb{a}/hd{b}/{c}" for a, b, c in neg_flags]}, f, indent=1)
    print(f"results -> {args.out}")

    if args.ledger and not smoke:
        import subprocess
        run_id = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
        with open(LEDGER, "a") as f:
            for k in keys:
                lb, hold, scope = k
                a = results[f"lb{lb}/hd{hold}/{scope}"]
                f.write(json.dumps({
                    "family": "reversal-survfree", "run": run_id,
                    "panel": "eodhd-us-delisted+active-2026-07-10",
                    "arm": f"lb{lb}/hd{hold}/{scope}", "sharpe": a["net_sharpe"],
                    "dsr": a["dsr_122"], "n": a["n_blocks"],
                    "verdict": "pass" if a["passes"] else "null",
                }) + "\n")
        print(f"LEDGER: appended {len(keys)} arms")


if __name__ == "__main__":
    main()
