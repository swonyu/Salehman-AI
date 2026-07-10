#!/usr/bin/env python3
"""PRE-REGISTERED 2008-inclusive momentum-crash-state re-test on the EODHD
survivorship-free US panel (delisted + active union).

Pre-registration: tools/eodhd_panel/PREREG_2026-07-10_crash2008_retest.md
(committed BEFORE any test statistic was computed). Definitions ported verbatim
from RESEARCH_2026-07-03_momentum_crash_conditioning_ablation.md §Method:

  BASE_MOM   long top-tercile by TSMOM (closes[i-21]-closes[i-126])/closes[i-126]
             (StockSageIndicators.timeSeriesMomentum lookback:126 skipRecent:21),
             equal-weighted, non-overlapping blocks stepped by H.
  OVERLAY    identical EXCEPT hold equal-weight-ALL eligible during CRASH-STATE blocks.
  CRASH-STATE at bar i (as-of, no look-ahead), market = GSPC.INDX same-vendor:
             close[i]/close[i-504]-1 < 0
             AND vol21[i] < median(vol21[i-503 .. i])
             where vol21[j] = population stdev of the 21 daily returns ending at j.
  Entry open[i+1], exit open[i+1+H]; H ∈ {21,42,63,126}; net cost = round-trip bps
  charged once per position per block (equal-weight book ⇒ subtract rt/1e4 from the
  block return; identical on both arms so the diff isolates selection).

WINDOWS
  PRIMARY   2004-01-02 → 2012-12-31  (pre-registered)
  SECONDARY 2000-01-03 → 2012-12-31  (LABELED DATA-SUGGESTED: added after the
            state-fire diagnostic showed 2001-03 fired extensively — the
            "fired slow-bleed crash" the 07-03 disposition required. Disclosed
            as a post-diagnostic extension, NOT pre-registered.)

INCLUSION (pre-registered, mechanical, per window; panel-freeze filters —
symmetric across arms): ≥756 in-window bars; no in-window calendar gap >16 days;
median in-window raw dollar volume ≥ $1M; raw close ≥ $1 at window entry.

STATS per (window, H, rt): block diff series d = OVERLAY_net − BASE_net
(nonzero only on fired blocks); mean, t; fired-only subset mean, t; DSR on d
with trials = arms(16) + 9 prior = 25 (registry sensitivity print at +308),
varTrialSharpe = sample variance of the 16 observed arm Sharpes; PSR/expected-max
ported arithmetic-for-arithmetic from StockSageDeflatedSharpe.swift (stdlib
NormalDist for Φ, Φ⁻¹). REVERSED: full walk-backward (all in-window series
time-reversed) re-run per arm. EQW context: BASE−EQW paired diff per arm.

Adjusted opens+closes are rebuilt IN-SCRIPT from raw close/open × split ledger
(same back-adjustment walk as build_panel.py, applied to open and close; vendor
adjusted_close never consumed). Self-checks: DRYS SEC boundary; t-table; Φ/Φ⁻¹.

Usage: python3 crash2008_retest.py [--ledger] [--out results.json]
"""
import json, math, os, statistics, sys, argparse
from datetime import date

BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
RAWDIR = os.path.join(BASE, "raw")
MANIFEST = os.path.join(BASE, "manifest.jsonl")
MARKET = os.path.join(BASE, "GSPC_INDX.json")
REPO = "/Users/saleh/ai"
LEDGER = os.path.join(REPO, "research", "trials_ledger.jsonl")

HORIZONS = [21, 42, 63, 126]
COSTS_BPS = [13, 60]
WINDOWS = [("PRIMARY_2004_2012", "2004-01-02", "2012-12-31", "pre-registered"),
           ("SECONDARY_2000_2012", "2000-01-03", "2012-12-31", "DATA-SUGGESTED (post-diagnostic extension, disclosed)")]
PRIOR_ARMS = 9
ND = statistics.NormalDist()


def toD(s):
    y, m, d = s.split("-"); return date(int(y), int(m), int(d))


# ---------- DSR port (StockSageDeflatedSharpe.swift, arithmetic-for-arithmetic) ----------
def psr(sr, n, skew, kurt, bench=0.0):
    if n < 2: return 0.0
    denom = math.sqrt(max(1e-12, 1 - skew * sr + ((kurt - 1) / 4) * sr * sr))
    return ND.cdf((sr - bench) * math.sqrt(n - 1) / denom)


def expected_max_sharpe(trials, var):
    if trials <= 1 or var <= 0: return 0.0
    g = 0.5772156649015329
    return math.sqrt(var) * ((1 - g) * ND.inv_cdf(1 - 1.0 / trials)
                             + g * ND.inv_cdf(1 - 1.0 / (trials * math.e)))


def moments(xs):
    n = len(xs)
    mu = sum(xs) / n
    m2 = sum((x - mu) ** 2 for x in xs) / n
    if m2 <= 0: return mu, 0.0, 0.0, 3.0
    m3 = sum((x - mu) ** 3 for x in xs) / n
    m4 = sum((x - mu) ** 4 for x in xs) / n
    return mu, math.sqrt(m2), m3 / m2 ** 1.5, m4 / m2 ** 2   # raw (non-excess) kurtosis


def tstat(xs):
    n = len(xs)
    if n < 2: return 0.0
    mu = sum(xs) / n
    sd = statistics.stdev(xs)
    return 0.0 if sd == 0 else mu / (sd / math.sqrt(n))


def selfchecks():
    # Φ / Φ⁻¹ sanity
    assert abs(ND.cdf(0) - 0.5) < 1e-12 and abs(ND.inv_cdf(0.975) - 1.959964) < 1e-4
    # t self-check: [1..11] has mean 6, sd ~3.3166, t = 6/(3.3166/sqrt(11)) = 6.0
    assert abs(tstat(list(range(1, 12))) - 6.0) < 1e-9
    print("selfcheck PASS: normal CDF/inv + t-stat")


# ---------- reconstruction (same factor walk as build_panel.py, on open AND close) ----------
def adjust(bars, splits_raw, first, delist):
    splits = []
    for s in splits_raw or []:
        d = s.get("date", "")
        try:
            new, old = s["split"].split("/"); new, old = float(new), float(old)
        except (ValueError, KeyError, AttributeError):
            continue
        if new <= 0 or old <= 0 or d > delist or d < first:
            continue
        splits.append((d, new, old))
    splits.sort()
    factor = 1.0
    si = len(splits) - 1
    adjc = [0.0] * len(bars); adjo = [0.0] * len(bars)
    for i in range(len(bars) - 1, -1, -1):
        d = bars[i]["date"]
        while si >= 0 and splits[si][0] > d:
            _, new, old = splits[si]; factor *= old / new; si -= 1
        adjc[i] = bars[i]["close"] * factor
        adjo[i] = (bars[i].get("open") or bars[i]["close"]) * factor
    return adjo, adjc


def selfcheck_drys():
    rec = json.load(open(os.path.join(RAWDIR, "DRYS.json")))
    bars = [b for b in rec["eod"]]
    last = max(b["date"] for b in bars if (b.get("volume") or 0) > 0)
    bars = [b for b in bars if b["date"] <= last]
    _, adjc = adjust(bars, rec.get("splits"), bars[0]["date"], last)
    idx = {b["date"]: i for i, b in enumerate(bars)}
    i = idx["2016-03-11"]
    got = adjc[i] / adjc[i - 1] - 1.0
    want = (2.15 / 25) / 0.1094 - 1.0
    assert abs(got - want) < 1e-9, f"DRYS boundary {got} != {want}"
    print(f"selfcheck PASS: DRYS 2016-03-11 = {got:+.6f} (SEC boundary)")


# ---------- market state ----------
def market_state():
    rec = json.load(open(MARKET))
    bars = rec["eod"] if isinstance(rec, dict) else rec
    dates = [b["date"] for b in bars]
    close = [b["close"] for b in bars]
    n = len(close)
    rets = [0.0] * n
    for i in range(1, n):
        rets[i] = close[i] / close[i - 1] - 1.0
    vol21 = [None] * n
    for i in range(21, n):
        w = rets[i - 20:i + 1]
        mu = sum(w) / 21
        vol21[i] = math.sqrt(sum((x - mu) ** 2 for x in w) / 21)
    state = [False] * n
    for i in range(n):
        if i < 504 or vol21[i] is None or i - 503 < 21:
            continue
        med = statistics.median(vol21[i - 503:i + 1])
        state[i] = (close[i] / close[i - 504] - 1.0 < 0) and (vol21[i] < med)
    return dates, state


# ---------- panel load ----------
def load_names(win_lo, win_hi):
    """Candidates via manifest pre-filter, then raw load + in-script adjustment +
    pre-registered inclusion filters. Returns {code: (posmap, adjo, adjc)} keyed to
    the master calendar via posmap: masterIdx -> local idx or -1."""
    cands = []
    with open(MANIFEST) as f:
        for line in f:
            m = json.loads(line)
            if m.get("status") != "ok":
                continue
            if m["first"] <= win_hi and m["delist"] >= win_lo:
                cands.append(m["code"])
    print(f"  manifest candidates overlapping window: {len(cands)}")
    return cands


def prep_name(code, win_lo, win_hi, mdate_idx, nmaster):
    try:
        rec = json.load(open(os.path.join(RAWDIR, code + ".json")))
    except (json.JSONDecodeError, OSError):
        return None
    bars = rec.get("eod")
    if not isinstance(bars, list) or len(bars) < 2:
        return None
    last = None
    for b in reversed(bars):
        if (b.get("volume") or 0) > 0:
            last = b["date"]; break
    if last is None:
        return None
    bars = [b for b in bars if b["date"] <= last]
    if len(bars) < 2:
        return None
    # in-window inclusion filters (pre-registered)
    inwin = [b for b in bars if win_lo <= b["date"] <= win_hi]
    if len(inwin) < 756:
        return None
    if inwin[0]["close"] < 1.0:
        return None
    dv = sorted((b["close"] * (b.get("volume") or 0)) for b in inwin)
    if dv[len(dv) // 2] < 1e6:
        return None
    prev = None
    for b in inwin:
        d = toD(b["date"])
        if prev is not None and (d - prev).days > 16:
            return None
        prev = d
    adjo, adjc = adjust(bars, rec.get("splits"), bars[0]["date"], last)
    posmap = [-1] * nmaster
    for li, b in enumerate(bars):
        mi = mdate_idx.get(b["date"])
        if mi is not None:
            posmap[mi] = li
    return posmap, adjo, adjc


# ---------- simulation ----------
def run_window(tag, win_lo, win_hi, mdates, mstate, names, reversed_mode=False):
    """names: dict code -> (posmap, adjo, adjc). Returns per-(H, rt) block series."""
    nmaster = len(mdates)
    lo = next(i for i, d in enumerate(mdates) if d >= win_lo)
    hi = max(i for i, d in enumerate(mdates) if d <= win_hi)
    if reversed_mode:
        # walk-backward: reverse the in-window master axis and every series on it.
        span = list(range(lo, hi + 1))[::-1]
    else:
        span = list(range(lo, hi + 1))
    out = {}
    for H in HORIZONS:
        base_g, over_g, eqw_g, fired = [], [], [], []
        # first rebalance needs 126 signal bars and i+1+H exit inside span
        k = 126
        while k + 1 + H < len(span):
            i = span[k]
            sig_a, sig_b = span[k - 126], span[k - 21]
            ent, ext = span[k + 1], span[k + 1 + H]
            moms, entries = {}, {}
            for code, (pm, adjo, adjc) in names.items():
                ia, ib, ie, ix = pm[sig_a], pm[sig_b], pm[ent], pm[ext]
                if min(ia, ib, ie, ix) < 0:
                    continue
                if adjc[ia] <= 0 or adjo[ie] <= 0:
                    continue
                moms[code] = (adjc[ib] - adjc[ia]) / adjc[ia]
                entries[code] = adjo[ix] / adjo[ie] - 1.0
            if len(moms) < 30:   # degenerate cross-section guard (reported, not silent)
                k += H
                continue
            ranked = sorted(moms, key=moms.get, reverse=True)
            top = ranked[: max(1, len(ranked) // 3)]
            b_ret = sum(entries[c] for c in top) / len(top)
            e_ret = sum(entries.values()) / len(entries)
            st = mstate[i]
            o_ret = e_ret if st else b_ret
            base_g.append(b_ret); over_g.append(o_ret); eqw_g.append(e_ret); fired.append(st)
            k += H
        out[H] = (base_g, over_g, eqw_g, fired)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--out", default=os.path.join(BASE, "crash2008_retest_results.json"))
    args = ap.parse_args()

    selfchecks()
    selfcheck_drys()
    mdates, mstate = market_state()
    mdate_idx = {d: i for i, d in enumerate(mdates)}

    # decision-rule conjunct 1 (computed with the EXACT median, not the sampled diagnostic)
    gfc = [i for i, d in enumerate(mdates) if "2008-09-01" <= d <= "2009-05-31" and mstate[i]]
    print(f"STATE-FIRE (exact): {len(gfc)} fired bars in Sep-2008..May-2009"
          f" -> {'FIRES' if gfc else 'DOES NOT FIRE'} in the GFC crash window")

    all_results = {}
    arm_sharpes = {}   # (win,H,rt) -> sharpe of diff series
    for tag, lo, hi, label in WINDOWS:
        print(f"\n=== {tag} [{lo} .. {hi}] ({label}) ===")
        cands = load_names(lo, hi)
        names = {}
        for c in cands:
            r = prep_name(c, lo, hi, mdate_idx, len(mdates))
            if r is not None:
                names[c] = r
        print(f"  included after pre-registered filters: {len(names)}")
        fwd = run_window(tag, lo, hi, mdates, mstate, names, reversed_mode=False)
        rev = run_window(tag, lo, hi, mdates, mstate, names, reversed_mode=True)
        all_results[tag] = {"included": len(names), "arms": {}}
        for H in HORIZONS:
            base_g, over_g, eqw_g, fired = fwd[H]
            rbase_g, rover_g, _, rfired = rev[H]
            for rt in COSTS_BPS:
                c = rt / 1e4
                d = [(o - c) - (b - c) for o, b in zip(over_g, base_g)]     # cost cancels in the diff
                dr = [(o - c) - (b - c) for o, b in zip(rover_g, rbase_g)]
                fd = [x for x, f in zip(d, fired) if f]
                be = [b - e for b, e in zip(base_g, eqw_g)]                 # EQW guard context (gross)
                mu, sd, sk, ku = moments(d) if len(d) > 3 else (0, 0, 0, 3)
                sr = 0.0 if sd == 0 else mu / sd
                key = (tag, H, rt)
                arm_sharpes[key] = sr
                all_results[tag]["arms"][f"H{H}_rt{rt}"] = {
                    "n_blocks": len(d), "n_fired": len(fd),
                    "base_net_mean": (sum(base_g) / len(base_g) - c) if base_g else None,
                    "overlay_net_mean": (sum(over_g) / len(over_g) - c) if over_g else None,
                    "diff_mean": mu, "diff_t": tstat(d), "diff_sharpe": sr,
                    "diff_skew": sk, "diff_kurt": ku,
                    "fired_diff_mean": (sum(fd) / len(fd)) if fd else None,
                    "fired_diff_t": tstat(fd) if len(fd) > 1 else None,
                    "rev_diff_mean": (sum(dr) / len(dr)) if dr else None,
                    "rev_diff_t": tstat(dr) if len(dr) > 1 else None,
                    "base_minus_eqw_gross_mean": (sum(be) / len(be)) if be else None,
                    "base_minus_eqw_gross_t": tstat(be) if len(be) > 1 else None,
                }

    # DSR pass: trials = 16 arms + 9 prior; varTrialSharpe = sample var of the 16 arm Sharpes
    srs = list(arm_sharpes.values())
    vts = statistics.variance(srs) if len(srs) > 1 else 0.0
    n_arms = len(srs)
    for trials, note in [(n_arms + PRIOR_ARMS, "primary"), (n_arms + PRIOR_ARMS + 308, "registry-informed")]:
        bench = expected_max_sharpe(trials, vts)
        print(f"\nDSR bench ({note}, trials={trials}, varTrialSharpe={vts:.6f}): expectedMaxSharpe={bench:.4f}")
        for (tag, H, rt), sr in arm_sharpes.items():
            a = all_results[tag]["arms"][f"H{H}_rt{rt}"]
            d = psr(sr, a["n_blocks"], a["diff_skew"], a["diff_kurt"], bench)
            a[f"dsr_{note.replace('-', '_')}"] = d

    print(f"\n{'window':22s} {'H':>4s} {'rt':>3s} {'nblk':>5s} {'nfired':>6s} "
          f"{'diff_mean':>10s} {'t':>6s} {'fired_mean':>10s} {'DSR':>6s} {'DSRreg':>6s} {'rev_mean':>9s}")
    for tag, _, _, _ in WINDOWS:
        for H in HORIZONS:
            for rt in COSTS_BPS:
                a = all_results[tag]["arms"][f"H{H}_rt{rt}"]
                fm = a["fired_diff_mean"]; rm = a["rev_diff_mean"]
                print(f"{tag:22s} {H:4d} {rt:3d} {a['n_blocks']:5d} {a['n_fired']:6d} "
                      f"{a['diff_mean']:+10.5f} {a['diff_t']:6.2f} "
                      f"{(fm if fm is not None else float('nan')):+10.5f} "
                      f"{a['dsr_primary']:6.3f} {a['dsr_registry_informed']:6.3f} "
                      f"{(rm if rm is not None else float('nan')):+9.5f}")

    passing = [(k, s) for k, s in arm_sharpes.items()
               if all_results[k[0]]["arms"][f"H{k[1]}_rt{k[2]}"]["dsr_primary"] > 0.95
               and all_results[k[0]]["arms"][f"H{k[1]}_rt{k[2]}"]["diff_mean"] > 0]
    print(f"\nDECISION RULE: state fires in GFC window: {'YES' if gfc else 'NO'}; "
          f"arms with positive diff AND DSR>0.95: {len(passing)}")
    print("VERDICT: " + ("REVISIT CONDITION MET — escalate per pre-reg" if (gfc and passing)
                         else "REFUTE CONFIRMED (pre-registered decision rule) — row closes permanently"))

    with open(args.out, "w") as f:
        json.dump({"prereg": "PREREG_2026-07-10_crash2008_retest.md",
                   "gfc_fired_bars_exact": len(gfc),
                   "trials_primary": n_arms + PRIOR_ARMS, "varTrialSharpe": vts,
                   "results": all_results}, f, indent=1)
    print(f"results -> {args.out}")

    if args.ledger:
        import subprocess
        run_id = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
        with open(LEDGER, "a") as f:
            for (tag, H, rt), sr in arm_sharpes.items():
                a = all_results[tag]["arms"][f"H{H}_rt{rt}"]
                f.write(json.dumps({
                    "family": "momentum-crash-2008-retest", "run": run_id,
                    "panel": "eodhd-us-delisted+active-2026-07-10",
                    "arm": f"{tag}/H{H}/rt{rt}", "sharpe": sr,
                    "dsr": a["dsr_primary"], "n": a["n_blocks"],
                    "verdict": "pass" if a["dsr_primary"] > 0.95 and a["diff_mean"] > 0 else "null",
                }) + "\n")
        print(f"LEDGER: appended {len(arm_sharpes)} arms")


if __name__ == "__main__":
    main()
