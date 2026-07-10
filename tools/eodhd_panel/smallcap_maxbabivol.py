#!/usr/bin/env python3
"""PRE-REGISTERED MAX / low-beta / low-IVOL LONG-leg re-test on the EODHD
survivorship-free US panel (delisted + active union, freeze 5ce314475941a0cd).

Pre-registration: tools/eodhd_panel/PREREG_2026-07-10_smallcap_maxbabivol.md
(design-reviewed, committed at 1601771 BEFORE any test statistic was computed).
Every rule below implements a numbered prereg clause; deviations are bugs.

  SIGNALS   MAX = mean top-5 VALID daily returns / trailing 21 master bars (>=15 valid)
            BETA = OLS slope of valid trailing-252-bar daily returns on GSPC (>=200 valid pairs)
            IVOL = population stdev of that regression's residuals
            valid return at master j: name bars at j AND j-1, both volume>0 and close>0
  COHORTS   bottom tercile (LOW) long, within-scope, vs ONE EQW-all-eligible book per (scope,H)
  SCOPES    FULL | LOWLIQ = bottom tercile by AS-OF trailing-63-bar median raw dollar volume
  BOOKS     entry raw-open presence mask at open[i+1]; exit = last valid raw-open print <= i+1+H
            (death-blocks BOOKED, truncations counted + classified; never dropped)
  ARMS      3 signals x 3 horizons {21,63,126} x 2 scopes = 18 decision arms; costs 13/60bps
            print levels only (cost cancels exactly in the paired diff)
  STATS     DSR trials = 18+106 = 124 (registry print 18+701=719); varTrialSharpe floored at
            0.0343 for a print BINDING on any would-be pass
  SENSITIV. S1 REVERSED (sign agreement) | S2a winsorized +/-100% | S2b no-screen+winsorized
            | S4 Shumway -30% on delisting-truncated exits
  DECISION  pass iff diff_mean>0 AND dsr124>0.95 AND dsr_floor>0.95 AND s2a>0.95 AND s2b>0.95
            AND s1 sign-agreement; symmetric negative direction reported; closed 18-arm set.

Usage: python3 smallcap_maxbabivol.py [--ledger] [--out results.json]  [SMOKE=N env: limit names]
"""
import json, math, os, statistics, sys, argparse, bisect
from array import array
from datetime import date

BASE = os.path.expanduser("~/.claude/salehman-universe/panels/eodhd_us_delisted")
RAWDIR = os.path.join(BASE, "raw")
MANIFEST = os.path.join(BASE, "manifest.jsonl")
MARKET = os.path.join(BASE, "GSPC_INDX.json")
REPO = "/Users/saleh/ai"
LEDGER = os.path.join(REPO, "research", "trials_ledger.jsonl")

WIN_LO, WIN_HI = "2000-01-03", "2026-07-09"
HORIZONS = [21, 63, 126]
SIGNALS = ["MAX", "BETA", "IVOL"]
SCOPES = ["FULL", "LOWLIQ"]
COSTS_BPS = [13, 60]
WARMUP = 252
PRIOR_ARMS = 106          # ledger census: max-lottery 16 + low-beta 62 + downside-beta 28
REGISTRY_ARMS = 701
VAR_FLOOR = 0.0343        # crash-retest measured varTrialSharpe (prereg review #9)
SHUMWAY = -0.30
MIN_NAMES = 30
NAN = float("nan")
ND = statistics.NormalDist()


def toD(s):
    y, m, d = s.split("-"); return date(int(y), int(m), int(d))


# ---------- DSR port (StockSageDeflatedSharpe.swift; verified bit-exact 2026-07-10) ----------
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
    assert abs(ND.cdf(0) - 0.5) < 1e-12 and abs(ND.inv_cdf(0.975) - 1.959964) < 1e-4
    assert abs(tstat(list(range(1, 12))) - 6.0) < 1e-9
    # hand-derived signal fixtures:
    # beta/ivol: y = 2x exactly -> beta 2, ivol 0
    xs = [0.01 * (i % 7 - 3) for i in range(252)]
    ys = [2 * x for x in xs]
    b, iv, n = ols_beta_ivol(xs, ys)
    assert abs(b - 2.0) < 1e-12 and iv < 1e-12 and n == 252
    # MAX: returns 1..21 (%): top-5 = 17..21, mean 19%
    r = [i / 100 for i in range(1, 22)]
    assert abs(max_signal(r) - 0.19) < 1e-12
    print("selfcheck PASS: normal CDF/inv + t-stat + beta/ivol + MAX fixtures")


def ols_beta_ivol(xs, ys):
    n = len(xs)
    if n == 0: return NAN, NAN, 0
    sx = sum(xs); sy = sum(ys)
    sxx = sum(x * x for x in xs); sxy = sum(x * y for x, y in zip(xs, ys))
    varx = sxx - sx * sx / n
    if varx <= 0: return NAN, NAN, n
    beta = (sxy - sx * sy / n) / varx
    a = (sy - beta * sx) / n
    ss = sum((y - a - beta * x) ** 2 for x, y in zip(xs, ys))
    return beta, math.sqrt(ss / n), n     # population residual stdev (07-03 convention)


def max_signal(valid_rets):
    top = sorted(valid_rets, reverse=True)[:5]
    return sum(top) / len(top)


# ---------- reconstruction (crash-retest factor walk + review-#7 raw-open presence mask) ----------
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
    adjc = [0.0] * len(bars); adjo = [NAN] * len(bars)
    for i in range(len(bars) - 1, -1, -1):
        d = bars[i]["date"]
        while si >= 0 and splits[si][0] > d:
            _, new, old = splits[si]; factor *= old / new; si -= 1
        adjc[i] = bars[i]["close"] * factor
        rawo = bars[i].get("open")
        if rawo is not None and rawo > 0 and (bars[i].get("volume") or 0) > 0:
            adjo[i] = rawo * factor          # valid open PRINT only; no close fallback anywhere
    return adjo, adjc, [(d, n, o) for d, n, o in splits]


def selfcheck_drys():
    rec = json.load(open(os.path.join(RAWDIR, "DRYS.json")))
    bars = rec["eod"]
    last = max(b["date"] for b in bars if (b.get("volume") or 0) > 0)
    bars = [b for b in bars if b["date"] <= last]
    _, adjc, _ = adjust(bars, rec.get("splits"), bars[0]["date"], last)
    idx = {b["date"]: i for i, b in enumerate(bars)}
    i = idx["2016-03-11"]
    got = adjc[i] / adjc[i - 1] - 1.0
    want = (2.15 / 25) / 0.1094 - 1.0
    assert abs(got - want) < 1e-9, f"DRYS boundary {got} != {want}"
    print(f"selfcheck PASS: DRYS 2016-03-11 = {got:+.6f} (SEC boundary)")


# ---------- integrity screen (prereg filter #2) ----------
def integrity_screen(inwin_adjc, inwin_dates, splits):
    """Returns None if clean, else (jump_date, ratio, ledger_entry_within_5_bars)."""
    n = len(inwin_adjc)
    ratios = [0.0] * n
    first_bad = None
    ups, dns = [], []                       # positions of >5x / <1/5 ratios
    for i in range(1, n):
        if inwin_adjc[i - 1] <= 0:
            continue
        r = inwin_adjc[i] / inwin_adjc[i - 1]
        ratios[i] = r
        if (r > 8 or (r > 0 and r < 1 / 8)) and first_bad is None:
            first_bad = i
        if r > 5: ups.append(i)
        elif 0 < r < 1 / 5: dns.append(i)
    if first_bad is None:
        # oscillation rule: >=1 up-flip AND >=1 down-flip within any rolling 21-bar span
        for u in ups:
            lo, hi = u - 20, u + 20
            j = bisect.bisect_left(dns, lo)
            if j < len(dns) and dns[j] <= hi:
                first_bad = max(u, dns[j]); break
    if first_bad is None:
        return None
    jd = inwin_dates[first_bad]
    near = any(abs(i - first_bad) <= 5
               for i, d in enumerate(inwin_dates)
               for sd, _, _ in splits if sd == d) if splits else False
    return jd, ratios[first_bad], near


# ---------- per-name prep onto the in-window master axis ----------
def prep_name(code, wdates, wpos, rej):
    try:
        rec = json.load(open(os.path.join(RAWDIR, code + ".json")))
    except (json.JSONDecodeError, OSError):
        rej["load"] += 1; return None
    bars = rec.get("eod")
    if not isinstance(bars, list) or len(bars) < 2:
        rej["load"] += 1; return None
    last = None
    for b in reversed(bars):
        if (b.get("volume") or 0) > 0:
            last = b["date"]; break
    if last is None:
        rej["load"] += 1; return None
    bars = [b for b in bars if b["date"] <= last]
    inwin = [b for b in bars if WIN_LO <= b["date"] <= WIN_HI]
    if len(inwin) < 756:
        rej["short"] += 1; return None
    if inwin[0]["close"] < 1.0:
        rej["entry_price"] += 1; return None
    dvs = sorted((b["close"] * (b.get("volume") or 0)) for b in inwin)
    if dvs[len(dvs) // 2] < 1e6:
        rej["dollar_vol"] += 1; return None
    prev = None
    for b in inwin:
        d = toD(b["date"])
        if prev is not None and (d - prev).days > 16:
            rej["gap"] += 1; return None
        prev = d
    adjo, adjc, splits = adjust(bars, rec.get("splits"), bars[0]["date"], last)
    loc = {b["date"]: i for i, b in enumerate(bars)}
    # integrity screen on the name's own consecutive in-window bars (flag, not reject: S2b re-admits)
    iw_idx = [loc[b["date"]] for b in inwin]
    screen = integrity_screen([adjc[i] for i in iw_idx], [bars[i]["date"] for i in iw_idx], splits)
    # master-aligned in-window arrays
    N = len(wdates)
    close_a = array("d", [NAN] * N)
    open_a = array("d", [NAN] * N)
    dv_a = array("d", [NAN] * N)
    for b in inwin:
        p = wpos.get(b["date"])
        if p is None: continue
        li = loc[b["date"]]
        v = b.get("volume") or 0
        if v > 0 and b["close"] > 0:
            close_a[p] = adjc[li]
            dv_a[p] = b["close"] * v
        if not math.isnan(adjo[li]):
            open_a[p] = adjo[li]
    return {"code": code, "close": close_a, "open": open_a, "dv": dv_a, "screen": screen}


def build_series(nm, mkt_ret):
    """Derive valid-return series + open-print index from the base arrays (works on reversed too)."""
    N = len(nm["close"])
    ret = array("d", [NAN] * N)
    vr = bytearray(N)
    c = nm["close"]
    for j in range(1, N):
        if not math.isnan(c[j]) and not math.isnan(c[j - 1]):
            ret[j] = c[j] / c[j - 1] - 1.0
            vr[j] = 1
    prints = [j for j in range(N) if not math.isnan(nm["open"][j])]
    pre = array("l", [0] * (N + 1))
    for j in range(N):
        pre[j + 1] = pre[j] + vr[j]
    return {"ret": ret, "vr": vr, "vrpre": pre, "prints": prints}


# ---------- signals at one rebalance position ----------
def signals_at(nm, der, p, mkt_ret):
    """Returns (max_sig, beta, ivol, liq) or None if ineligible (prereg minimum counts)."""
    if der["vrpre"][p + 1] - der["vrpre"][p - 20] < 15:        # >=15 valid in trailing 21
        return None
    if der["vrpre"][p + 1] - der["vrpre"][p - 251] < 200:      # >=200 valid in trailing 252
        return None
    vr, ret = der["vr"], der["ret"]
    xs, ys = [], []
    for j in range(p - 251, p + 1):
        if vr[j]:
            xs.append(mkt_ret[j]); ys.append(ret[j])
    beta, ivol, _ = ols_beta_ivol(xs, ys)
    if math.isnan(beta):
        return None
    mret = [ret[j] for j in range(p - 20, p + 1) if vr[j]]
    msig = max_signal(mret)
    dvw = [nm["dv"][j] for j in range(p - 62, p + 1) if not math.isnan(nm["dv"][j])]
    if not dvw:
        return None
    liq = statistics.median(dvw)
    return msig, beta, ivol, liq


# ---------- one full pass (universe x direction) ----------
def run_pass(names, mkt_ret, wdates, tag):
    """names: list of prepared name dicts (base arrays possibly reversed).
    Returns arms[(sig,scope,H)] = dict of block series + truncation/skip counts."""
    N = len(wdates)
    ders = {nm["code"]: build_series(nm, mkt_ret) for nm in names}
    byc = {nm["code"]: nm for nm in names}
    # H=21 rebalance grid; H=63/126 grids are subsets (63=3*21, 126=6*21, same origin WARMUP)
    rebs = list(range(WARMUP, N - 1 - min(HORIZONS), 21))
    sig_cache = {}
    for n_i, p in enumerate(rebs):
        row = {}
        for code, nm in byc.items():
            s = signals_at(nm, ders[code], p, mkt_ret)
            if s is not None and not math.isnan(nm["open"][p + 1]):   # valid entry print required
                row[code] = s
        sig_cache[p] = row
        if n_i % 40 == 0:
            print(f"  [{tag}] signals {n_i}/{len(rebs)} rebalances, eligible={len(row)}", flush=True)
    arms = {}
    for H in HORIZONS:
        for scope in SCOPES:
            for sig in SIGNALS:
                arms[(sig, scope, H)] = {"d": [], "d_w": [], "d_s4": [], "coh_g": [], "eqw_g": [],
                                         "trunc_del": 0, "trunc_hole": 0, "skips": 0}
        p = WARMUP
        while p + 1 + H <= N - 1:
            row = sig_cache.get(p)
            if row is None:
                p += H; continue
            eligible = list(row.keys())
            if len(eligible) < MIN_NAMES:
                for sig in SIGNALS:
                    for scope in SCOPES:
                        arms[(sig, scope, H)]["skips"] += 1
                p += H; continue
            target = p + 1 + H
            # block returns per eligible name (exit = last valid print <= target; review #3)
            brets, dele = {}, {}
            for code in eligible:
                pr = ders[code]["prints"]
                k = bisect.bisect_right(pr, target) - 1
                e = pr[k]                     # >= p+1 always (entry is a print)
                nm = byc[code]
                r = nm["open"][e] / nm["open"][p + 1] - 1.0
                brets[code] = r
                if e < target:
                    died = pr[-1] < target    # nothing ever prints after target -> series ended
                    dele[code] = died
            for scope in SCOPES:
                if scope == "LOWLIQ":
                    ranked = sorted(eligible, key=lambda c: row[c][3])
                    members = ranked[: max(1, len(ranked) // 3)]
                else:
                    members = eligible
                if len(members) < MIN_NAMES:
                    for sig in SIGNALS:
                        arms[(sig, scope, H)]["skips"] += 1
                    continue
                eq = [brets[c] for c in members]
                eq_m = sum(eq) / len(eq)
                eq_w = sum(min(max(x, -1.0), 1.0) for x in eq) / len(eq)
                eq_s4 = sum(((1 + brets[c]) * (1 + SHUMWAY) - 1) if dele.get(c) else brets[c]
                            for c in members) / len(members)
                for si, sig in enumerate(SIGNALS):
                    coh = sorted(members, key=lambda c: row[c][si])[: max(1, len(members) // 3)]
                    cm = sum(brets[c] for c in coh) / len(coh)
                    cw = sum(min(max(brets[c], -1.0), 1.0) for c in coh) / len(coh)
                    cs4 = sum(((1 + brets[c]) * (1 + SHUMWAY) - 1) if dele.get(c) else brets[c]
                              for c in coh) / len(coh)
                    a = arms[(sig, scope, H)]
                    a["d"].append(cm - eq_m); a["d_w"].append(cw - eq_w); a["d_s4"].append(cs4 - eq_s4)
                    a["coh_g"].append(cm); a["eqw_g"].append(eq_m)
                    a["trunc_del"] += sum(1 for c in coh if dele.get(c) is True)
                    a["trunc_hole"] += sum(1 for c in coh if dele.get(c) is False)
            p += H
    return arms


def reversed_names(names):
    out = []
    for nm in names:
        out.append({"code": nm["code"],
                    "close": array("d", reversed(nm["close"])),
                    "open": array("d", reversed(nm["open"])),
                    "dv": array("d", reversed(nm["dv"])),
                    "screen": nm["screen"]})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--out", default=os.path.join(BASE, "smallcap_maxbabivol_results.json"))
    args = ap.parse_args()
    smoke = int(os.environ.get("SMOKE", "0"))

    selfchecks()
    selfcheck_drys()

    # market: in-window axis + returns
    rec = json.load(open(MARKET))
    mbars = rec["eod"] if isinstance(rec, dict) else rec
    wdates = [b["date"] for b in mbars if WIN_LO <= b["date"] <= WIN_HI]
    wclose = [b["close"] for b in mbars if WIN_LO <= b["date"] <= WIN_HI]
    wpos = {d: i for i, d in enumerate(wdates)}
    N = len(wdates)
    mkt_ret = array("d", [NAN] * N)
    for j in range(1, N):
        mkt_ret[j] = wclose[j] / wclose[j - 1] - 1.0
    print(f"master window bars: {N} ({wdates[0]} .. {wdates[-1]})")

    cands = []
    with open(MANIFEST) as f:
        for line in f:
            m = json.loads(line)
            if m.get("status") == "ok" and m["first"] <= WIN_HI and m["delist"] >= WIN_LO:
                cands.append(m["code"])
    if smoke:
        cands = cands[:smoke]
    print(f"manifest candidates: {len(cands)}")

    rej = {"short": 0, "entry_price": 0, "dollar_vol": 0, "gap": 0, "load": 0}
    prepped, screened = [], []
    for i, code in enumerate(cands):
        if i % 2000 == 0:
            print(f"  prep {i}/{len(cands)} (pass={len(prepped)} screened={len(screened)})", flush=True)
        nm = prep_name(code, wdates, wpos, rej)
        if nm is None:
            continue
        (screened if nm["screen"] else prepped).append(nm)
    print(f"prep done: clean={len(prepped)} screened={len(screened)} rejections={rej}")
    print(f"gap-clause-only exclusions: {rej['gap']} (prereg filter-census requirement)")
    print("screened census (code, jump_date, ratio, splits_ledger_entry_within_5_bars):")
    for nm in screened:
        jd, r, near = nm["screen"]
        print(f"  SCREEN {nm['code']:8s} {jd} ratio={r:.3f} ledger_near={near}")

    print("\n=== PASS 1/3: PRIMARY forward ===", flush=True)
    fwd = run_pass(prepped, mkt_ret, wdates, "fwd")
    print("=== PASS 2/3: PRIMARY reversed (S1) ===", flush=True)
    rev = run_pass(reversed_names(prepped), array("d", reversed(mkt_ret)), wdates, "rev")
    print("=== PASS 3/3: S2b no-screen universe forward ===", flush=True)
    s2b = run_pass(prepped + screened, mkt_ret, wdates, "s2b")

    # DSR benches from the 18 forward decision-arm Sharpes
    keys = [(sig, scope, H) for sig in SIGNALS for scope in SCOPES for H in HORIZONS]
    srs = {}
    for k in keys:
        d = fwd[k]["d"]
        mu, sd, sk, ku = moments(d) if len(d) > 3 else (0, 0, 0, 3)
        srs[k] = (0.0 if sd == 0 else mu / sd, sk, ku, len(d))
    vts = statistics.variance([s[0] for s in srs.values()])
    vts_f = max(vts, VAR_FLOOR)
    b124 = expected_max_sharpe(18 + PRIOR_ARMS, vts)
    b124f = expected_max_sharpe(18 + PRIOR_ARMS, vts_f)
    b719 = expected_max_sharpe(18 + REGISTRY_ARMS, vts)
    print(f"\nvarTrialSharpe={vts:.6f} (floored {vts_f:.6f}); bench124={b124:.4f} "
          f"benchFloor={b124f:.4f} bench719={b719:.4f}")

    results, passing, neg_flags = {}, [], []
    hdr = (f"{'arm':22s} {'nblk':>4s} {'diff_mean':>10s} {'t':>6s} {'DSR124':>7s} {'DSRflr':>7s} "
           f"{'DSR719':>7s} {'S2a':>6s} {'S2b':>6s} {'S1':>3s} {'negDSR':>7s} {'trDel':>5s} {'trHole':>6s}")
    print("\n" + hdr)
    for k in keys:
        sig, scope, H = k
        d, dw, ds4 = fwd[k]["d"], fwd[k]["d_w"], fwd[k]["d_s4"]
        dr = rev[k]["d"]; db = s2b[k]["d_w"]
        sr, sk, ku, n = srs[k]
        mu = sum(d) / n if n else 0.0
        def dsr_of(series, bench):
            if len(series) < 4: return 0.0
            m, s, a, b = moments(series)
            r = 0.0 if s == 0 else m / s
            return psr(r, len(series), a, b, bench)
        dsr124 = psr(sr, n, sk, ku, b124)
        dsrflr = psr(sr, n, sk, ku, b124f)
        dsr719 = psr(sr, n, sk, ku, b719)
        s2a_d = dsr_of(dw, b124)
        s2b_d = dsr_of(db, b124)
        s4_d = dsr_of(ds4, b124)
        neg = psr(-sr, n, -sk, ku, b124)
        rmu = sum(dr) / len(dr) if dr else 0.0
        s1 = (mu >= 0) == (rmu >= 0)
        ok = mu > 0 and dsr124 > 0.95 and dsrflr > 0.95 and s2a_d > 0.95 and s2b_d > 0.95 and s1
        if ok: passing.append(k)
        nflag = (neg > 0.95 and s1
                 and dsr_of([-x for x in dw], b124) > 0.95
                 and dsr_of([-x for x in db], b124) > 0.95)
        if nflag: neg_flags.append(k)
        arm = f"{sig}/{scope}/H{H}"
        print(f"{arm:22s} {n:4d} {mu:+10.5f} {tstat(d):6.2f} {dsr124:7.3f} {dsrflr:7.3f} "
              f"{dsr719:7.3f} {s2a_d:6.3f} {s2b_d:6.3f} {'Y' if s1 else 'N':>3s} {neg:7.3f} "
              f"{fwd[k]['trunc_del']:5d} {fwd[k]['trunc_hole']:6d}")
        results[arm] = {
            "n_blocks": n, "diff_mean": mu, "diff_t": tstat(d), "diff_sharpe": sr,
            "diff_skew": sk, "diff_kurt": ku,
            "dsr_124": dsr124, "dsr_floor": dsrflr, "dsr_719": dsr719,
            "s2a_dsr": s2a_d, "s2b_dsr": s2b_d, "s4_dsr": s4_d,
            "s4_mean": (sum(ds4) / len(ds4)) if ds4 else None, "s4_t": tstat(ds4),
            "rev_mean": rmu, "rev_t": tstat(dr), "s1_sign_agree": s1,
            "neg_dsr_124": neg, "passes": ok, "neg_flag": nflag,
            "coh_gross_mean": sum(fwd[k]["coh_g"]) / n if n else None,
            "eqw_gross_mean": sum(fwd[k]["eqw_g"]) / n if n else None,
            "coh_net_mean_13": (sum(fwd[k]["coh_g"]) / n - 13e-4) if n else None,
            "coh_net_mean_60": (sum(fwd[k]["coh_g"]) / n - 60e-4) if n else None,
            "trunc_delisting": fwd[k]["trunc_del"], "trunc_hole": fwd[k]["trunc_hole"],
            "skips": fwd[k]["skips"],
        }

    print(f"\nDECISION RULE (closed 18-arm set, trials=124): passing arms = {len(passing)}"
          + (f" {passing}" if passing else ""))
    print(f"Symmetric NEGATIVE flags (anti-edge direction): {len(neg_flags)}"
          + (f" {neg_flags}" if neg_flags else ""))
    print("VERDICT: " + ("PROMOTION CANDIDATE per prereg — owner presentation required (with the "
                         "review-#11 over-statement disclosure)" if passing
                         else "NULL — the 07-03 small/retail caveat CLOSES: tested on the population "
                              "the literature names, still nothing"))

    with open(args.out, "w") as f:
        json.dump({"prereg": "PREREG_2026-07-10_smallcap_maxbabivol.md",
                   "window": [WIN_LO, WIN_HI], "clean_names": len(prepped),
                   "screened_names": [(nm["code"],) + tuple(nm["screen"]) for nm in screened],
                   "rejections": rej, "varTrialSharpe": vts,
                   "bench_124": b124, "bench_floor": b124f, "bench_719": b719,
                   "results": results,
                   "passing": [f"{s}/{sc}/H{h}" for s, sc, h in passing],
                   "neg_flags": [f"{s}/{sc}/H{h}" for s, sc, h in neg_flags]}, f, indent=1)
    print(f"results -> {args.out}")

    if args.ledger and not smoke:
        import subprocess
        run_id = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
        with open(LEDGER, "a") as f:
            for k in keys:
                sig, scope, H = k
                a = results[f"{sig}/{scope}/H{H}"]
                f.write(json.dumps({
                    "family": "smallcap-maxbabivol", "run": run_id,
                    "panel": "eodhd-us-delisted+active-2026-07-10",
                    "arm": f"{sig}/{scope}/H{H}", "sharpe": a["diff_sharpe"],
                    "dsr": a["dsr_124"], "n": a["n_blocks"],
                    "verdict": "pass" if a["passes"] else "null",
                }) + "\n")
        print(f"LEDGER: appended {len(keys)} arms")


if __name__ == "__main__":
    main()
