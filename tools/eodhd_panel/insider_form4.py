#!/usr/bin/env python3
"""PRE-REGISTERED opportunistic insider-purchase (Form 4, P-code) ablation on the
EODHD survivorship-free panel.

Pre-registration: tools/eodhd_panel/PREREG_2026-07-10_insider_form4.md (design-reviewed,
committed at c1057c2 BEFORE any test statistic). Events come from insider_extract.py's
output (data-only pass implementing the prereg §Signal: DOCUMENT_TYPE=4 ∧ TRANS_FORM_TYPE=4
∧ P ∧ A, officer/director, TRANS_DATE-keyed purchases-only routineness, sanitizer).

  SIGNAL   name has >=1 opportunistic event with availability bar in [p-20, p] (tiles at H=21)
  BOOKS    COHORT (signal fired) vs ONE EQW-all-eligible per (scope,H); paired diff; entry
           raw-open p+1; exit last valid print <= p+1+H (booked truncations); <10-cohort guard
           + 30-eligible guard, skips counted; scopes FULL@13 / as-of LOWLIQ tercile@60 (levels
           only); H in {21,63}; grid origin = window start + 21 (no price warmup); decision
           blocks require wdates[p] <= 2025-12-31 (event-coverage tail rule, pre-registered)
  LEGS     S1' lag +5 bars (sign-agreement conjunct) | S1'' placebo: per-quarter issuer-column
           shuffle, seeds 1/2/3 (machinery veto) | S2a winsorized | S2b no-screen+winsorized |
           S4 Shumway -30% on delisting-truncated exits
  STATS    4 decision arms; trials 4 (+ ledger-line-count registry print, read fresh);
           varTrialSharpe floored 0.0343 BINDING; gross t/DSR both books; censuses ii/iv/vi;
           symmetric negative flags; closed 4-arm all-conjunct rule + placebo validity.

Usage: python3 insider_form4.py [--ledger] [--out results.json]  [SMOKE=N env]
"""
import json, math, os, random, statistics, sys, argparse, bisect
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from smallcap_maxbabivol import (psr, expected_max_sharpe, moments, tstat, prep_name,
                                 selfcheck_drys, MIN_NAMES, BASE, MANIFEST, MARKET, REPO, LEDGER)

EVENTS = os.path.expanduser("~/.claude/salehman-universe/insider_sets/insider_events.json")
WIN_LO, WIN_HI = "2009-01-02", "2026-07-09"
COVER_END = "2025-12-31"          # event-data coverage (prereg tail rule)
HORIZONS = [21, 63]
SCOPES = [("FULL", 13.0), ("LOWLIQ", 60.0)]
EVENT_WIN = 20                     # [p-20, p] inclusive
MIN_COHORT = 10
LAG = 5
VAR_FLOOR = 0.0343
SHUMWAY = -0.30


def selfcheck_cohort():
    # availability bars {30}; window [p-20,p]: p=30..50 in, p=29 and p=51 out.
    avs = [30]
    def fired(p): return any(p - EVENT_WIN <= a <= p for a in avs)
    assert fired(30) and fired(50) and not fired(29) and not fired(51)
    print("selfcheck PASS: event-window membership boundaries [p-20, p]")


def derive(nm):
    return {"prints": [j for j in range(len(nm["open"])) if not math.isnan(nm["open"][j])]}


def run_leg(names, avmap, wdates, lag, tag, tail_max, mapped=None):
    """avmap: code -> sorted availability bar list. Returns arms[(scope,H)] block dicts.
    FIX 2026-07-10 (post-run 2-lens finding, verdict-inert — NULL strengthened): the prereg pins
    eligibility "...AND CIK-mapped" (unmapped names excluded from BOTH books); the completed run
    omitted it (~11.2% of EQW unmapped), which FLATTERED the diff (+19.5bp/t=1.67 as-built vs
    +16.6bp/t=1.39 prereg-faithful — measured independently by BOTH verification lenses). Pass
    `mapped` = the CIK-mapped code set to enforce the faithful book on future runs."""
    N = len(wdates)
    if mapped is not None:
        names = [nm for nm in names if nm["code"] in mapped]
    ders = {nm["code"]: derive(nm) for nm in names}
    byc = {nm["code"]: nm for nm in names}
    arms = {}
    for H in HORIZONS:
        for scope, _ in SCOPES:
            arms[(scope, H)] = {"d": [], "d_w": [], "d_s4": [], "coh_g": [], "eqw_g": [],
                                "coh_sizes": [], "elig_sizes": [], "retention": [],
                                "trunc_del": 0, "trunc_hole": 0, "skip_elig": 0,
                                "skip_cohort": 0, "skip_tail": 0}
        prev_coh = {scope: set() for scope, _ in SCOPES}
        p = 21
        while p + 1 + H <= N - 1:
            if p > tail_max:
                for scope, _ in SCOPES: arms[(scope, H)]["skip_tail"] += 1
                p += H; continue
            target = p + 1 + H
            elig, liq, sig = [], {}, set()
            for code, nm in byc.items():
                if math.isnan(nm["open"][p + 1]): continue
                dvw = [nm["dv"][j] for j in range(max(0, p - 62), p + 1) if not math.isnan(nm["dv"][j])]
                if not dvw: continue
                elig.append(code); liq[code] = statistics.median(dvw)
                avs = avmap.get(code)
                if avs:
                    i = bisect.bisect_left(avs, p - EVENT_WIN - lag)
                    if i < len(avs) and avs[i] + lag <= p:
                        sig.add(code)
            if len(elig) < MIN_NAMES:
                for scope, _ in SCOPES: arms[(scope, H)]["skip_elig"] += 1
                p += H; continue
            ranked = sorted(elig, key=lambda c: liq[c])
            lowliq = set(ranked[: max(1, len(ranked) // 3)])
            brets, dele = {}, {}
            for code in elig:
                pr = ders[code]["prints"]
                e = pr[bisect.bisect_right(pr, target) - 1]
                nm = byc[code]
                brets[code] = nm["open"][e] / nm["open"][p + 1] - 1.0
                if e < target: dele[code] = pr[-1] < target
            for scope, _ in SCOPES:
                members = [c for c in elig if scope == "FULL" or c in lowliq]
                a = arms[(scope, H)]
                coh = [c for c in members if c in sig]
                if len(members) < MIN_NAMES or len(coh) < MIN_COHORT:
                    a["skip_cohort" if len(members) >= MIN_NAMES else "skip_elig"] += 1
                    prev_coh[scope] = set(coh)
                    continue
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
                a["coh_sizes"].append(len(coh)); a["elig_sizes"].append(len(members))
                cs = set(coh)
                if prev_coh[scope]:
                    a["retention"].append(len(cs & prev_coh[scope]) / max(1, len(prev_coh[scope])))
                prev_coh[scope] = cs
                a["trunc_del"] += sum(1 for c in coh if dele.get(c) is True)
                a["trunc_hole"] += sum(1 for c in coh if dele.get(c) is False)
            p += H
    return arms


def placebo_avmap(avmap, names, wdates, seed):
    """S1'' (prereg-pinned): per calendar quarter of availability date, permute the issuer
    column of the final opportunistic event list among panel-present names; dates kept."""
    rng = random.Random(seed)
    byq = defaultdict(list)
    for code, avs in avmap.items():
        for a in avs:
            q = wdates[a][:4] + "Q" + str((int(wdates[a][5:7]) - 1) // 3 + 1)
            byq[q].append((a, code))
    out = defaultdict(list)
    for q, lst in sorted(byq.items()):
        codes = [c for _, c in lst]
        rng.shuffle(codes)
        for (a, _), c in zip(lst, codes):
            out[c].append(a)
    return {c: sorted(v) for c, v in out.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--out", default=os.path.join(BASE, "insider_form4_results.json"))
    args = ap.parse_args()
    smoke = int(os.environ.get("SMOKE", "0"))

    selfcheck_cohort()
    selfcheck_drys()

    rec = json.load(open(MARKET))
    mbars = rec["eod"] if isinstance(rec, dict) else rec
    wdates = [b["date"] for b in mbars if WIN_LO <= b["date"] <= WIN_HI]
    wpos = {d: i for i, d in enumerate(wdates)}
    N = len(wdates)
    tail_max = max(i for i, d in enumerate(wdates) if d <= COVER_END)
    print(f"master window bars: {N} ({wdates[0]} .. {wdates[-1]}); decision tail cutoff {wdates[tail_max]}")

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

    ev = json.load(open(EVENTS))["events"]
    # FIX 2026-07-10 (see run_leg doc): enforce the prereg's CIK-mapped eligibility on future runs.
    _m = json.load(open(os.path.join(BASE, "edgar_cik_map.json")))
    mapped = set(_m["mapped"]) | set(_m.get("mapped_screened", {}))
    avmap = {}
    for code, lst in ev.items():
        avs = sorted(bisect.bisect_right(wdates, fd) for fd, _ in lst)
        avs = [a for a in avs if a < N]
        if avs: avmap[code] = avs
    print(f"names with in-window availability events: {len(avmap)}; "
          f"events mapped: {sum(len(v) for v in avmap.values())}")

    print("\n=== BASE leg ===", flush=True)
    base = run_leg(clean, avmap, wdates, 0, "base", tail_max, mapped)
    print("=== S1' lag +5 leg ===", flush=True)
    lagl = run_leg(clean, avmap, wdates, LAG, "lag", tail_max, mapped)
    print("=== S2b no-screen leg ===", flush=True)
    s2b = run_leg(clean + screened, avmap, wdates, 0, "s2b", tail_max, mapped)
    print("=== S1'' placebo x3 ===", flush=True)
    plac = []
    for seed in (1, 2, 3):
        pm = placebo_avmap(avmap, clean, wdates, seed)
        plac.append(run_leg(clean, pm, wdates, 0, f"plac{seed}", tail_max, mapped))

    keys = [(scope, H) for scope, _ in SCOPES for H in HORIZONS]
    srs = {}
    for k in keys:
        d = base[k]["d"]
        mu, sd, sk, ku = moments(d) if len(d) > 3 else (0, 0, 0, 3)
        srs[k] = (0.0 if sd == 0 else mu / sd, sk, ku, len(d))
    vts = statistics.variance([s[0] for s in srs.values()])
    vts_f = max(vts, VAR_FLOOR)
    with open(LEDGER) as f:
        nled = sum(1 for _ in f)
    b4 = expected_max_sharpe(4, vts)
    b4f = expected_max_sharpe(4, vts_f)
    breg = expected_max_sharpe(4 + nled, vts)
    print(f"\nvarTrialSharpe={vts:.6f} (floored {vts_f:.6f}); bench4={b4:.4f} "
          f"benchFloor={b4f:.4f} benchReg(4+{nled})={breg:.4f}")

    def dsr_of(series, bench):
        if len(series) < 4: return 0.0
        m, s, a, b_ = moments(series)
        r = 0.0 if s == 0 else m / s
        return psr(r, len(series), a, b_, bench)

    placebo_max = max((dsr_of(pl[k]["d"], b4) for pl in plac for k in keys), default=0.0)
    run_valid = placebo_max <= 0.95
    print(f"S1'' placebo max DSR (3 seeds x 4 arms): {placebo_max:.3f} -> run "
          + ("VALID" if run_valid else "INVALID (machinery leak)"))

    results, passing, neg_flags = {}, [], []
    print(f"\n{'arm':12s} {'nblk':>4s} {'cohMed':>6s} {'diff_mean':>10s} {'t':>6s} {'DSR4':>6s} "
          f"{'DSRflr':>7s} {'S2a':>6s} {'S2b':>6s} {'S1lag':>6s} {'negDSR':>7s} {'reten':>6s} "
          f"{'skE/skC/skT':>12s}")
    for k in keys:
        scope, H = k
        a = base[k]
        d = a["d"]; n = len(d)
        sr, sk, ku, _ = srs[k]
        mu = sum(d) / n if n else 0.0
        dsr4 = psr(sr, n, sk, ku, b4); dsrflr = psr(sr, n, sk, ku, b4f)
        dsrreg = psr(sr, n, sk, ku, breg)
        s2a_d = dsr_of(a["d_w"], b4); s2b_d = dsr_of(s2b[k]["d_w"], b4)
        s4_d = dsr_of(a["d_s4"], b4)
        lmu = (sum(lagl[k]["d"]) / len(lagl[k]["d"])) if lagl[k]["d"] else 0.0
        s1 = (mu >= 0) == (lmu >= 0)
        neg = psr(-sr, n, -sk, ku, b4)
        ok = (run_valid and mu > 0 and dsr4 > 0.95 and dsrflr > 0.95
              and s2a_d > 0.95 and s2b_d > 0.95 and s1)
        if ok: passing.append(k)
        nflag = (neg > 0.95 and s1 and dsr_of([-x for x in a["d_w"]], b4) > 0.95
                 and dsr_of([-x for x in s2b[k]["d_w"]], b4) > 0.95)
        if nflag: neg_flags.append(k)
        cohmed = int(statistics.median(a["coh_sizes"])) if a["coh_sizes"] else 0
        reten = (sum(a["retention"]) / len(a["retention"])) if a["retention"] else 0.0
        arm = f"{scope}/H{H}"
        print(f"{arm:12s} {n:4d} {cohmed:6d} {mu:+10.5f} {tstat(d):6.2f} {dsr4:6.3f} {dsrflr:7.3f} "
              f"{s2a_d:6.3f} {s2b_d:6.3f} {'Y' if s1 else 'N':>6s} {neg:7.3f} {reten:6.2f} "
              f"{a['skip_elig']:3d}/{a['skip_cohort']:3d}/{a['skip_tail']:3d}")
        results[arm] = {
            "n_blocks": n, "diff_mean": mu, "diff_t": tstat(d), "diff_sharpe": sr,
            "diff_skew": sk, "diff_kurt": ku, "dsr_4": dsr4, "dsr_floor": dsrflr,
            "dsr_registry": dsrreg, "s2a_dsr": s2a_d, "s2b_dsr": s2b_d, "s4_dsr": s4_d,
            "s4_mean": (sum(a["d_s4"]) / n) if n else None,
            "lag_mean": lmu, "s1_sign_agree": s1, "neg_dsr_4": neg,
            "passes": ok, "neg_flag": nflag,
            "coh_gross_mean": sum(a["coh_g"]) / n if n else None, "coh_gross_t": tstat(a["coh_g"]),
            "coh_gross_dsr": dsr_of(a["coh_g"], b4),
            "eqw_gross_mean": sum(a["eqw_g"]) / n if n else None, "eqw_gross_t": tstat(a["eqw_g"]),
            "eqw_gross_dsr": dsr_of(a["eqw_g"], b4),
            "cohort_median": cohmed, "cohort_retention_mean": reten,
            "eligible_median": int(statistics.median(a["elig_sizes"])) if a["elig_sizes"] else 0,
            "trunc_delisting": a["trunc_del"], "trunc_hole": a["trunc_hole"],
            "skips_eligible": a["skip_elig"], "skips_cohort": a["skip_cohort"], "skips_tail": a["skip_tail"],
        }

    print(f"\nDECISION RULE (closed 4-arm set, trials=4, run_valid={run_valid}): "
          f"passing arms = {len(passing)}" + (f" {passing}" if passing else ""))
    print(f"Symmetric NEGATIVE flags: {len(neg_flags)}" + (f" {neg_flags}" if neg_flags else ""))
    print("VERDICT: " + ("PROMOTION CANDIDATE per prereg — owner presentation required "
                         "(paired-diff-overstates-net + FRL capacity caveat for LOWLIQ)" if passing
                         else "NULL — the last credible surveyed family closes; no surveyed family "
                              "clears the honest bar at retail"))

    with open(args.out, "w") as f:
        json.dump({"prereg": "PREREG_2026-07-10_insider_form4.md", "window": [WIN_LO, WIN_HI],
                   "tail_cutoff": wdates[tail_max], "clean_names": len(clean),
                   "screened": len(screened), "event_names": len(avmap),
                   "events_mapped": sum(len(v) for v in avmap.values()),
                   "varTrialSharpe": vts, "bench_4": b4, "bench_floor": b4f,
                   "bench_registry": breg, "registry_n": nled,
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
                    "family": "insider-form4", "run": run_id,
                    "panel": "eodhd-us-delisted+active-2026-07-10+sec-form345",
                    "arm": f"{scope}/H{H}", "sharpe": a["diff_sharpe"],
                    "dsr": a["dsr_4"], "n": a["n_blocks"],
                    "verdict": "pass" if a["passes"] else "null",
                }) + "\n")
        print(f"LEDGER: appended {len(keys)} arms")


if __name__ == "__main__":
    main()
