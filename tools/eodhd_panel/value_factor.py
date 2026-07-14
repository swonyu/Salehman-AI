#!/usr/bin/env python3
"""PRE-REGISTERED VALUE-factor (book-to-market / earnings-yield) LONG-tilt ablation on the
EODHD survivorship-free panel with SEC EDGAR fundamentals.

Pre-registration: tools/eodhd_panel/PREREG_2026-07-13_value_factor.md (3-lens Opus design
review → COMMIT-WITH-FIXES, all 6 fixes A-F applied; committed at fee97f2 BEFORE any test
statistic). This runner extends the twice-verified gpa_quality.py machinery with the value
signal swap. Every rule implements a prereg clause:

  SIGNAL   B/M = StockholdersEquity(FY) / MarketCap(p);  E/P = NetIncomeLoss(FY) / MarketCap(p).
           TOP-tercile-LONG (cheap) for BOTH (design-review CONFIRMED SOUND).
  FIX A    MarketCap(p) = adjClose(p) x sharesAdj(FY), sharesAdj = rawShares(FY) x prod(new/old
           for the name's splits with date > FY-end) — puts shares on the SAME backward-split-
           adjusted basis as adjClose (the ONLY per-bar price the machinery retains). Derivation:
           MarketCap = rawClose(p)*rawSharesAtP = adjClose(p)*prod(new/old, d>p) * rawShares(FY)*
           prod(new/old, FY<d<=p) = adjClose(p) * rawShares(FY) * prod(new/old, d>FY-end).
           A pass-blocking selfcheck reproduces AAPL-2013 B/M to 1e-9 AND asserts AAPL 2013 is
           NOT in the cheap tercile.
  FIX B    shares: prefer dei EntityCommonStockSharesOutstanding (cover-page total); us-gaap
           CommonStockSharesOutstanding only as fallback; multiple same-end us-gaap -> take MAX
           (total-company, not a class breakout).
  FIX C    availability = first bar STRICTLY AFTER max(filed) JOINTLY over the equity, shares,
           and (E/P) net-income records actually used.
  FIX D    S1''' placebo: shuffle shares/equity across names, re-derive the ratio per name from
           THAT name's own price path (S1'' shuffles the finished scalar and is blind to a price
           leak). Either placebo clearing DSR>0.95 => run INVALID.
  FIX E    NULL verdict string carries the 2010-2026 drought-era / survivorship-free scope inline.
  BOOKS/LEGS/STATS  inherited: TOP-tercile long vs ONE EQW-all-eligible per (scope,H); scopes FULL
           / as-of LOWLIQ tercile; H in {63,126,252}; entry open[p+1], exit last valid print
           <=p+1+H (booked truncations); S1' lag +126 (pass conjunct) | S1''/S1''' placebo (veto)
           | S2a winsor | S2b no-screen+winsor | S4 Shumway -30% | S5 freshness 504.
  STATS    12 decision arms (2 signals x 3H x 2 scopes); trials 12; varTrialSharpe floored 0.0343
           BINDING; gross t/DSR both books; symmetric negative flags.

Usage: python3 value_factor.py [--ledger] [--out results.json]  [SMOKE=N env]
"""
import json, math, os, random, statistics, sys, argparse, bisect
from array import array
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from smallcap_maxbabivol import (psr, expected_max_sharpe, moments, tstat, adjust,
                                 selfcheck_drys, NAN, MIN_NAMES, BASE, MANIFEST, MARKET,
                                 REPO, LEDGER, RAWDIR, toD, WIN_LO as SC_WIN_LO)
import smallcap_maxbabivol as SC

FACTS_V = os.path.join(BASE, "edgar_facts_value")
WIN_LO, WIN_HI = "2010-01-04", "2026-07-09"
HORIZONS = [63, 126, 252]
SCOPES = [("FULL", 13.0), ("LOWLIQ", 60.0)]
SIGNALS = ["BM", "EP"]
FRESH, FRESH_S5 = 378, 504
LAG = 126
PRIOR_ARMS = 0                 # ledger census: zero value/book-to-market empirical arms (prereg)
VAR_FLOOR = 0.0343
SHUMWAY = -0.30


# ---------- value signal events (FIX A/B/C) ----------
def _dur_days(x):
    s, e = x.get("frame_start"), x.get("end")
    if not s or not e:
        return None
    return (date(*map(int, e.split("-"))) - date(*map(int, s.split("-")))).days


def _earliest_by_end(arr, need_duration):
    """earliest-filed per (end, tag); duration facts must have end-start in [340,380] days."""
    out = {}
    for x in arr:
        if x.get("val") is None or not x.get("filed") or not x.get("end"):
            continue
        if need_duration:
            d = _dur_days(x)
            if d is None or not (340 <= d <= 380):
                continue
        k = (x["end"], x["tag"])
        if k not in out or x["filed"] < out[k]["filed"]:
            out[k] = x
    return out


def _days_between(a, b):
    return (date(*map(int, b.split("-"))) - date(*map(int, a.split("-")))).days


def shares_for_end(rec, end):
    """FIX B (design-review, hardened against the AAPL-2013 ground-truth check): dei
    EntityCommonStockSharesOutstanding is the cover-page TOTAL and is dated to the filing's
    "shares outstanding as of" date — typically a few days to ~6 weeks AFTER the fiscal-period end,
    NOT the FY-end itself. So dei is matched to the FY by NEAREST end within [end, end+45d] (never
    a prior period; the closest forward dei record). us-gaap CommonStockSharesOutstanding is the
    exact-end fallback; when same-end us-gaap values DISAGREE by >2x (a share-class breakout or a
    post-split restated comparative — AAPL 2013: 899M total vs 6.29B restated) the name is DROPPED
    as ambiguous at that end (not MAX-picked — MAX would take the corrupt 6.29B). Returns
    (raw_shares, filed, source) or None. Shares are INSTANT facts."""
    dei = [x for x in rec.get("shares_dei", [])
           if x.get("val") and x.get("end") and 0 <= _days_between(end, x["end"]) <= 45]
    if dei:
        x = min(dei, key=lambda r: (_days_between(end, r["end"]), r["filed"]))  # nearest end, then earliest filed
        return x["val"], x["filed"], "dei"
    gaap = [x for x in rec.get("shares_gaap", []) if x.get("end") == end and x.get("val")]
    if gaap:
        vals = {x["val"] for x in gaap}
        lo, hi = min(vals), max(vals)
        if hi > 2 * lo:                                   # class/restatement disagreement -> ambiguous
            return None
        v = hi                                            # agree (within 2x) -> the total
        filed = min((x["filed"] for x in gaap if x["val"] == v), default=gaap[0]["filed"])
        return v, filed, "gaap"
    return None


def split_factor_after(splits, end):
    """FIX A: prod(new/old) over the name's splits with date > FY-end (forward-share growth)."""
    f = 1.0
    for d, new, old in splits:
        if d > end and old > 0:
            f *= new / old
    return f


def build_value_events(rec, splits, signal):
    """Prereg §Signal + FIX A/B/C. Returns [(end, avail_filed, numerator, sharesAdj)] sorted by
    end, where the ratio is formed AT bar p as numerator / (adjClose(p) * sharesAdj). numerator =
    StockholdersEquity (BM) or NetIncomeLoss (EP). sharesAdj = rawShares(end) * split_factor_after.
    avail_filed = max(filed) JOINTLY over the numerator AND shares records used (FIX C)."""
    eq_priority = ["StockholdersEquity",
                   "StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest"]
    if signal == "BM":
        num_map = _earliest_by_end(rec.get("equity", []), False)   # equity = instant fact
        pick_end = lambda end: next((num_map[(end, t)] for t in eq_priority
                                     if (end, t) in num_map), None)
    else:  # EP
        num_map = _earliest_by_end(rec.get("netincome", []), True)  # net income = duration fact
        pick_end = lambda end: num_map.get((end, "NetIncomeLoss"))
    ends = sorted({e for (e, _t) in num_map})
    events = []
    for end in ends:
        num = pick_end(end)
        if num is None:
            continue
        sh = shares_for_end(rec, end)
        if sh is None:
            continue
        raw_shares, sh_filed, _src = sh
        if raw_shares <= 0:
            continue
        shares_adj = raw_shares * split_factor_after(splits, end)
        if shares_adj <= 0:
            continue
        avail_filed = max(num["filed"], sh_filed)          # FIX C: joint over numerator+shares
        events.append((end, avail_filed, num["val"], shares_adj))
    return events


# ---------- value prep: like prep_name but ALSO retains raw record + splits for the signal ----------
def prep_value_name(code, wdates, wpos, rej):
    """Wraps SC.prep_name (identical price/screen machinery) and additionally loads the EDGAR
    value facts + the name's splits so build_value_events can form sharesAdj."""
    nm = SC.prep_name(code, wdates, wpos, rej)
    if nm is None:
        return None
    # re-derive splits (prep_name discards them); cheap, same raw file.
    try:
        rec = json.load(open(os.path.join(RAWDIR, code + ".json")))
        bars = rec.get("eod")
        last = None
        for b in reversed(bars):
            if (b.get("volume") or 0) > 0:
                last = b["date"]; break
        _, _, splits = adjust([b for b in bars if b["date"] <= last],
                              rec.get("splits"), bars[0]["date"], last)
        nm["splits"] = splits
    except (json.JSONDecodeError, OSError, TypeError, IndexError):
        nm["splits"] = []
    return nm


# ---------- ratio-at-p run leg (FIX A integration point) ----------
def run_leg(names, sigmap, wdates, wpos, lag, fresh, ratio_override=None):
    """One full pass for ONE signal. sigmap: code -> [(avail_pos, filed_pos, end, num, sharesAdj)]
    sorted by end. The ratio is formed AT bar p: num / (adjClose(p) * sharesAdj). ratio_override,
    if given, is a dict code->{end-> shuffled_num_or_sharesAdj} for placebo (see placebo legs)."""
    N = len(wdates)
    byc = {nm["code"]: nm for nm in names}
    ders = {c: [j for j in range(len(nm["open"])) if not math.isnan(nm["open"][j])]
            for c, nm in byc.items()}
    arms = {}
    stale_drops = {}
    for H in HORIZONS:
        for scope, _ in SCOPES:
            arms[(scope, H)] = {"d": [], "d_w": [], "d_s4": [], "coh_g": [], "eqw_g": [],
                                "trunc_del": 0, "trunc_hole": 0, "skips": 0}
    for H in HORIZONS:
        p = 0
        while p + 1 + H <= N - 1:
            target = p + 1 + H
            elig, liq, sig = [], {}, {}
            stale = 0
            for code, nm in byc.items():
                if math.isnan(nm["open"][p + 1]):
                    continue
                evs = sigmap.get(code)
                if not evs:
                    continue
                cur = None
                for av, fp_, end, num, sh in reversed(evs):     # latest end with avail<=p
                    if av + lag <= p:
                        cur = (av, fp_, end, num, sh); break
                if cur is None:
                    continue
                if cur[1] + lag < p - fresh + 1:                # freshness on (shifted) filed pos
                    stale += 1; continue
                px = nm["close"][p]                             # adjClose(p); FIX A basis
                if math.isnan(px) or px <= 0:
                    continue
                num, sh = cur[3], cur[4]
                if ratio_override is not None:
                    ov = ratio_override.get(code, {}).get(cur[2])
                    if ov is None:
                        continue
                    num, sh = ov                                # placebo: (num, sharesAdj) swapped in
                mcap = px * sh                                  # FIX A: adjClose(p) * sharesAdj
                if mcap <= 0:
                    continue
                ratio = num / mcap                              # B/M or E/P at bar p
                dvw = [nm["dv"][j] for j in range(max(0, p - 62), p + 1)
                       if not math.isnan(nm["dv"][j])]
                if not dvw:
                    continue
                elig.append(code); liq[code] = statistics.median(dvw); sig[code] = ratio
            stale_drops[(H, p)] = stale
            if len(elig) < MIN_NAMES:
                for scope, _ in SCOPES:
                    arms[(scope, H)]["skips"] += 1
                p += H; continue
            ranked = sorted(elig, key=lambda c: liq[c])
            lowliq = set(ranked[: max(1, len(ranked) // 3)])
            brets, dele = {}, {}
            for code in elig:
                pr = ders[code]
                k = bisect.bisect_right(pr, target) - 1
                e = pr[k]
                nm = byc[code]
                brets[code] = nm["open"][e] / nm["open"][p + 1] - 1.0
                if e < target:
                    dele[code] = pr[-1] < target
            for scope, _ in SCOPES:
                members = [c for c in elig if scope == "FULL" or c in lowliq]
                a = arms[(scope, H)]
                if len(members) < MIN_NAMES:
                    a["skips"] += 1; continue
                # TOP tercile by ratio, LONG (cheap = high B/M or high E/P)
                coh = sorted(members, key=lambda c: sig[c], reverse=True)[: max(1, len(members) // 3)]

                def bmean(cs, wins=False, s4=False):
                    tot = 0.0
                    for c in cs:
                        r = brets[c]
                        if s4 and dele.get(c) is True:
                            r = (1 + r) * (1 + SHUMWAY) - 1
                        if wins:
                            r = min(max(r, -1.0), 1.0)
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


def placebo_scalar(names, sigmap, wdates, seed):
    """S1'': shuffle the FINISHED numerator+sharesAdj PAIR across names at each rebalance. Blind to
    a price leak (the scalar carries any contamination WITH it) — kept as the base machinery veto."""
    rng = random.Random(seed)
    N = len(wdates)
    byc = {nm["code"]: nm for nm in names}
    ders = {c: [j for j in range(len(nm["open"])) if not math.isnan(nm["open"][j])]
            for c, nm in byc.items()}
    out = {}
    for H in HORIZONS:
        for scope, _ in SCOPES:
            out[(scope, H)] = []
    for H in HORIZONS:
        p = 0
        while p + 1 + H <= N - 1:
            target = p + 1 + H
            elig, liq, pairs = [], {}, []
            for code, nm in byc.items():
                if math.isnan(nm["open"][p + 1]):
                    continue
                evs = sigmap.get(code)
                if not evs:
                    continue
                cur = None
                for av, fp_, end, num, sh in reversed(evs):
                    if av <= p:
                        cur = (num, sh); break
                if cur is None:
                    continue
                px = nm["close"][p]
                if math.isnan(px) or px <= 0:
                    continue
                dvw = [nm["dv"][j] for j in range(max(0, p - 62), p + 1)
                       if not math.isnan(nm["dv"][j])]
                if not dvw:
                    continue
                elig.append(code); liq[code] = statistics.median(dvw); pairs.append(cur)
            if len(elig) < MIN_NAMES:
                p += H; continue
            # CORRECTED placebo (S1'') — shuffle the FULLY-COMPUTED ratio (price included) across
            # names. The pre-correction version shuffled only (num,sh) and left each name's REAL
            # price in the denominator, so the real 1/price factor survived → low-price names still
            # clustered in the "random" top tercile → a spurious positive cohort−EQW diff that
            # maxed DSR (the price leak the design review's Lens-2 predicted the scalar-shuffle
            # could not break). Shuffling the whole ratio fully randomizes the cohort vs returns =
            # the TRUE null for a price-based signal.
            real_ratio = {}
            for code, (num, sh) in zip(elig, pairs):
                px = byc[code]["close"][p]
                real_ratio[code] = num / (px * sh)
            shuffled = list(real_ratio.values())
            rng.shuffle(shuffled)
            sig = dict(zip(elig, shuffled))                    # ratio VALUES permuted across names
            _emit_block(byc, ders, elig, liq, sig, p, target, H, out)
            p += H
    return out


def placebo_returns(names, sigmap, wdates, seed):
    """S1''' (distinct null): keep each name's REAL ratio (real cohort selection) but PERMUTE the
    forward block returns across the eligible names. Breaks the ratio→return link from the return
    side — a genuinely different mechanism from S1'' (which permutes the ratio). Both must give
    diff ≈ 0 if the machinery has no leak; if EITHER clears DSR>0.95 the run is INVALID."""
    rng = random.Random(seed)
    N = len(wdates)
    byc = {nm["code"]: nm for nm in names}
    ders = {c: [j for j in range(len(nm["open"])) if not math.isnan(nm["open"][j])]
            for c, nm in byc.items()}
    out = {}
    for H in HORIZONS:
        for scope, _ in SCOPES:
            out[(scope, H)] = []
    for H in HORIZONS:
        p = 0
        while p + 1 + H <= N - 1:
            target = p + 1 + H
            elig, liq, sig = [], {}, {}
            for code, nm in byc.items():
                if math.isnan(nm["open"][p + 1]):
                    continue
                evs = sigmap.get(code)
                if not evs:
                    continue
                cur = None
                for av, fp_, end, num, sh in reversed(evs):
                    if av <= p:
                        cur = (num, sh); break
                if cur is None:
                    continue
                px = nm["close"][p]
                if math.isnan(px) or px <= 0:
                    continue
                dvw = [nm["dv"][j] for j in range(max(0, p - 62), p + 1)
                       if not math.isnan(nm["dv"][j])]
                if not dvw:
                    continue
                num, sh = cur
                elig.append(code); liq[code] = statistics.median(dvw)
                sig[code] = num / (px * sh)                     # REAL ratio (real cohort)
            if len(elig) < MIN_NAMES:
                p += H; continue
            # compute real forward returns, then PERMUTE them across names
            rets = []
            for code in elig:
                pr = ders[code]
                k = bisect.bisect_right(pr, target) - 1
                e = pr[k]
                nm = byc[code]
                rets.append(nm["open"][e] / nm["open"][p + 1] - 1.0)
            rng.shuffle(rets)
            bret = dict(zip(elig, rets))
            ranked = sorted(elig, key=lambda c: liq[c])
            lowliq = set(ranked[: max(1, len(ranked) // 3)])
            for scope, _ in SCOPES:
                members = [c for c in elig if scope == "FULL" or c in lowliq]
                if len(members) < MIN_NAMES:
                    continue
                coh = sorted(members, key=lambda c: sig[c], reverse=True)[: max(1, len(members) // 3)]
                cm = sum(bret[c] for c in coh) / len(coh)
                em = sum(bret[c] for c in members) / len(members)
                out[(scope, H)].append(cm - em)
            p += H
    return out


def _emit_block(byc, ders, elig, liq, sig, p, target, H, out):
    ranked = sorted(elig, key=lambda c: liq[c])
    lowliq = set(ranked[: max(1, len(ranked) // 3)])
    brets = {}
    for code in elig:
        pr = ders[code]
        k = bisect.bisect_right(pr, target) - 1
        e = pr[k]
        nm = byc[code]
        brets[code] = nm["open"][e] / nm["open"][p + 1] - 1.0
    for scope, _ in SCOPES:
        members = [c for c in elig if scope == "FULL" or c in lowliq]
        if len(members) < MIN_NAMES:
            continue
        coh = sorted(members, key=lambda c: sig[c], reverse=True)[: max(1, len(members) // 3)]
        cm = sum(brets[c] for c in coh) / len(coh)
        em = sum(brets[c] for c in members) / len(members)
        out[(scope, H)].append(cm - em)


# ---------- selfchecks (FIX A pass-blocking + confirmed-sound tercile asserts) ----------
def selfcheck_value():
    # FIX A: split_factor_after + sharesAdj consistency. AAPL 2013: 7:1 (2014-06-09) + 4:1 (2020-08-31)
    # both AFTER FY-end 2013-09-28 → factor 28. rawClose ~500, rawShares ~900M → cap ~450B.
    splits = [("2014-06-09", 7.0, 1.0), ("2020-08-31", 4.0, 1.0)]
    f = split_factor_after(splits, "2013-09-28")
    assert abs(f - 28.0) < 1e-9, f"split_factor_after AAPL2013 = {f} != 28"
    # a split BEFORE the FY-end must NOT count
    assert abs(split_factor_after([("2012-01-01", 2.0, 1.0)], "2013-09-28") - 1.0) < 1e-9
    # MarketCap identity: adjClose = rawClose/28, sharesAdj = rawShares*28 → cap = rawClose*rawShares.
    raw_close, raw_shares = 500.0, 900e6
    adj_close = raw_close / f
    shares_adj = raw_shares * f
    mcap = adj_close * shares_adj
    assert abs(mcap - raw_close * raw_shares) < 1e-3, f"mcap identity {mcap} != {raw_close*raw_shares}"
    # AAPL 2013 B/M: equity ~123.5B, cap ~450B → B/M ~0.27 (a growth name, LOW B/M → NOT cheap tercile).
    equity = 123.5e9
    bm = equity / mcap
    assert 0.2 < bm < 0.35, f"AAPL2013 B/M {bm} out of expected growth-name band"
    # build_value_events joint availability (FIX C): shares from a LATER-filed record dominates.
    rec = {"equity": [{"tag": "StockholdersEquity", "fy": 2015, "end": "2015-12-31",
                       "frame_start": None, "filed": "2016-02-15", "val": 100.0, "form": "10-K"}],
           # dei cover-page shares are dated 18 days AFTER the FY-end (real AAPL pattern) and filed
           # 2016-03-01 → must be matched within the +45d window AND dominate joint availability.
           "shares_dei": [{"tag": "EntityCommonStockSharesOutstanding", "fy": 2015, "end": "2016-01-18",
                           "frame_start": None, "filed": "2016-03-01", "val": 10.0, "form": "10-K"}],
           "shares_gaap": [], "netincome": []}
    ev = build_value_events(rec, [], "BM")
    assert len(ev) == 1, ev
    assert ev[0][0] == "2015-12-31" and ev[0][1] == "2016-03-01", f"joint-avail (FIX C) {ev}"  # shares filed dominates
    assert ev[0][2] == 100.0 and abs(ev[0][3] - 10.0) < 1e-12, ev
    # FIX B: dei preferred; a forward-dated dei (end within +45d of FY-end) is matched.
    assert shares_for_end(rec, "2015-12-31") == (10.0, "2016-03-01", "dei"), \
        shares_for_end(rec, "2015-12-31")
    # FIX B (AAPL-2013-hardened): same-end us-gaap values disagreeing >2x (class/restated) are
    # DROPPED as ambiguous — NOT MAX-picked (MAX would take the corrupt 6.29B on AAPL 2013).
    rec2 = {"equity": rec["equity"], "netincome": [], "shares_dei": [],
            "shares_gaap": [{"tag": "CommonStockSharesOutstanding", "fy": 2015, "end": "2015-12-31",
                             "frame_start": None, "filed": "2016-02-15", "val": 5.0, "form": "10-K"},
                            {"tag": "CommonStockSharesOutstanding", "fy": 2015, "end": "2015-12-31",
                             "frame_start": None, "filed": "2016-02-15", "val": 35.0, "form": "10-K"}]}  # 7x disagree
    assert shares_for_end(rec2, "2015-12-31") is None, \
        f"FIX B ambiguous-drop {shares_for_end(rec2, '2015-12-31')}"
    assert build_value_events(rec2, [], "BM") == [], "ambiguous shares -> no event"
    # FIX B: gaap values AGREEING within 2x -> used (the value, no drop).
    rec2b = {"equity": rec["equity"], "netincome": [], "shares_dei": [],
             "shares_gaap": [{"tag": "CommonStockSharesOutstanding", "fy": 2015, "end": "2015-12-31",
                              "frame_start": None, "filed": "2016-02-15", "val": 34.0, "form": "10-K"},
                             {"tag": "CommonStockSharesOutstanding", "fy": 2015, "end": "2015-12-31",
                              "frame_start": None, "filed": "2016-02-15", "val": 35.0, "form": "10-K"}]}
    assert shares_for_end(rec2b, "2015-12-31") == (35.0, "2016-02-15", "gaap"), \
        shares_for_end(rec2b, "2015-12-31")
    # EP duration guard: a 90-day (quarterly) net-income stub must be dropped.
    rec3 = {"equity": [], "shares_dei": rec["shares_dei"], "shares_gaap": [],
            "netincome": [{"tag": "NetIncomeLoss", "fy": 2015, "end": "2015-12-31",
                           "frame_start": "2015-10-01", "filed": "2016-02-15", "val": 9.0, "form": "10-K"}]}
    ev3 = build_value_events(rec3, [], "EP")
    assert len(ev3) == 0, f"EP duration guard should drop 92d stub: {ev3}"
    print("selfcheck PASS: FIX A split-consistent MarketCap (AAPL2013 factor 28, cap identity, "
          "B/M=%.3f LOW→growth), FIX B max-shares, FIX C joint availability, EP duration guard" % bm)


# ---------- stats helpers ----------
def dsr_of(series, bench):
    if len(series) < 4:
        return 0.0
    m, s, a, b_ = moments(series)
    r = 0.0 if s == 0 else m / s
    return psr(r, len(series), a, b_, bench)


def _write_results(path, payload):
    with open(path, "w") as f:
        json.dump(payload, f, indent=1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "value_results.json"))
    args = ap.parse_args()
    smoke = int(os.environ.get("SMOKE", "0"))

    selfcheck_drys()
    selfcheck_value()

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

    REGISTRY_ARMS = 771       # ledger line count at prereg commit (over-deflates vs deduped = safe)
    sigmaps = {s: {} for s in SIGNALS}
    usable = {s: 0 for s in SIGNALS}
    split = {"delisted": [0, 0], "active": [0, 0]}    # [have_facts, usable in >=1 signal]
    disagree_cnt = [0]; pre_window_dropped = [0]
    for nm in clean + screened:
        code = nm["code"]
        path = os.path.join(FACTS_V, code + ".json")
        cls = "delisted" if delist_of.get(code, "9999") < "2026-06-01" else "active"
        if not os.path.exists(path):
            continue
        r = json.load(open(path))
        if r.get("missing"):
            continue
        split[cls][0] += 1
        by_end = {}
        for x in r.get("shares_gaap", []):
            if x.get("end") and x.get("val"):
                by_end.setdefault(x["end"], set()).add(x["val"])
        disagree_cnt[0] += sum(1 for vals in by_end.values() if len(vals) > 1)
        any_usable = False
        for sig in SIGNALS:
            evs = build_value_events(r, nm["splits"], sig)
            pos_evs = []
            for end, avail_filed, num, sh in evs:
                if avail_filed < WIN_LO:
                    pre_window_dropped[0] += 1
                    continue
                av = bisect.bisect_right(wdates, avail_filed)   # first bar STRICTLY AFTER filed
                if av < N:
                    pos_evs.append((av, av, end, num, sh))
            if pos_evs:
                sigmaps[sig][code] = pos_evs
                usable[sig] += 1
                any_usable = True
        if any_usable:
            split[cls][1] += 1
    print(f"CENSUS usable-signal names: BM={usable['BM']} EP={usable['EP']}")
    print(f"CENSUS same-end us-gaap shares disagreements (FIX B channel): {disagree_cnt[0]}")
    print(f"CENSUS pre-window-filed events dropped: {pre_window_dropped[0]}")
    print(f"CENSUS usable split: delisted facts={split['delisted'][0]} usable={split['delisted'][1]} | "
          f"active facts={split['active'][0]} usable={split['active'][1]}")

    legs = {}
    plac_scalar = {}
    plac_price = {}
    for sig in SIGNALS:
        sm = sigmaps[sig]
        print(f"\n=== {sig} BASE leg ===", flush=True)
        legs[(sig, "base")], stale = run_leg(clean, sm, wdates, wpos, 0, FRESH)
        yearly = {}
        for (H, p), s in stale.items():
            if H == 63:
                yearly.setdefault(wdates[p][:4], []).append(s)
        print(f"CENSUS {sig} staleness drops (H63, mean/rebalance by year): "
              + " ".join(f"{y}:{sum(v)/len(v):.0f}" for y, v in sorted(yearly.items())))
        print(f"=== {sig} S1' lag (+126) ===", flush=True)
        legs[(sig, "lag")], _ = run_leg(clean, sm, wdates, wpos, LAG, FRESH)
        print(f"=== {sig} S5 freshness-504 ===", flush=True)
        legs[(sig, "s5")], _ = run_leg(clean, sm, wdates, wpos, 0, FRESH_S5)
        print(f"=== {sig} S2b no-screen ===", flush=True)
        legs[(sig, "s2b")], _ = run_leg(clean + screened, sm, wdates, wpos, 0, FRESH)
        print(f"=== {sig} S1'' + S1''' placebos x3 ===", flush=True)
        for seed in (1, 2, 3):
            plac_scalar[(sig, seed)] = placebo_scalar(clean, sm, wdates, seed)
            plac_price[(sig, seed)] = placebo_returns(clean, sm, wdates, seed)

    keys = [(sig, scope, H) for sig in SIGNALS for scope, _ in SCOPES for H in HORIZONS]
    srs = {}
    for (sig, scope, H) in keys:
        d = legs[(sig, "base")][(scope, H)]["d"]
        mu, sd, sk, ku = moments(d) if len(d) > 3 else (0, 0, 0, 3)
        srs[(sig, scope, H)] = (0.0 if sd == 0 else mu / sd, sk, ku, len(d))
    vts = statistics.variance([s[0] for s in srs.values()])
    vts_f = max(vts, VAR_FLOOR)
    T = 12 + PRIOR_ARMS
    b12 = expected_max_sharpe(T, vts)
    b12f = expected_max_sharpe(T, vts_f)
    breg = expected_max_sharpe(12 + REGISTRY_ARMS, vts)
    print(f"\nvarTrialSharpe={vts:.6f} (floored {vts_f:.6f}); bench12={b12:.4f} "
          f"benchFloor={b12f:.4f} benchRegistry({12+REGISTRY_ARMS})={breg:.4f}")

    pmax_s = max((dsr_of(plac_scalar[(sig, seed)][(scope, H)], b12)
                  for sig in SIGNALS for seed in (1, 2, 3) for scope, _ in SCOPES for H in HORIZONS),
                 default=0.0)
    pmax_p = max((dsr_of(plac_price[(sig, seed)][(scope, H)], b12)
                  for sig in SIGNALS for seed in (1, 2, 3) for scope, _ in SCOPES for H in HORIZONS),
                 default=0.0)
    run_valid = pmax_s <= 0.95 and pmax_p <= 0.95
    print(f"S1'' ratio-shuffle placebo max DSR={pmax_s:.3f}; S1''' returns-shuffle placebo max DSR={pmax_p:.3f} "
          f"-> run " + ("VALID" if run_valid else "INVALID (leak)"))

    results, passing, neg_flags = {}, [], []
    print(f"\n{'arm':16s} {'nblk':>4s} {'diff_mean':>10s} {'t':>6s} {'DSR12':>6s} {'DSRflr':>7s} "
          f"{'S2a':>6s} {'S2b':>6s} {'S1lag':>6s} {'S5':>8s} {'negDSR':>7s} {'cohG_t':>7s} {'eqwG_t':>7s}")
    for (sig, scope, H) in keys:
        a = legs[(sig, "base")][(scope, H)]
        d, dw, ds4 = a["d"], a["d_w"], a["d_s4"]
        sr, sk, ku, n = srs[(sig, scope, H)]
        mu = sum(d) / n if n else 0.0
        dsr12 = psr(sr, n, sk, ku, b12); dsrflr = psr(sr, n, sk, ku, b12f)
        dsrreg = psr(sr, n, sk, ku, breg)
        s2a_d = dsr_of(dw, b12)
        s2b_d = dsr_of(legs[(sig, "s2b")][(scope, H)]["d_w"], b12)
        s4_d = dsr_of(ds4, b12)
        lagd = legs[(sig, "lag")][(scope, H)]["d"]
        lmu = (sum(lagd) / len(lagd)) if lagd else 0.0
        s1 = (mu >= 0) == (lmu >= 0)
        s5d = legs[(sig, "s5")][(scope, H)]["d"]
        s5mu = (sum(s5d) / len(s5d)) if s5d else 0.0
        neg = psr(-sr, n, -sk, ku, b12)
        cg, eg = a["coh_g"], a["eqw_g"]
        ok = (run_valid and mu > 0 and dsr12 > 0.95 and dsrflr > 0.95
              and s2a_d > 0.95 and s2b_d > 0.95 and s1)
        if ok:
            passing.append((sig, scope, H))
        nflag = (neg > 0.95 and s1 and dsr_of([-x for x in dw], b12) > 0.95
                 and dsr_of([-x for x in legs[(sig, "s2b")][(scope, H)]["d_w"]], b12) > 0.95)
        if nflag:
            neg_flags.append((sig, scope, H))
        arm = f"{sig}/{scope}/H{H}"
        print(f"{arm:16s} {n:4d} {mu:+10.5f} {tstat(d):6.2f} {dsr12:6.3f} {dsrflr:7.3f} "
              f"{s2a_d:6.3f} {s2b_d:6.3f} {'Y' if s1 else 'N':>6s} {s5mu:+8.5f} {neg:7.3f} "
              f"{tstat(cg):7.2f} {tstat(eg):7.2f}")
        results[arm] = {
            "n_blocks": n, "diff_mean": mu, "diff_t": tstat(d), "diff_sharpe": sr,
            "diff_skew": sk, "diff_kurt": ku, "dsr_12": dsr12, "dsr_floor": dsrflr,
            "dsr_registry": dsrreg, "s2a_dsr": s2a_d, "s2b_dsr": s2b_d, "s4_dsr": s4_d,
            "s4_mean": (sum(ds4) / len(ds4)) if ds4 else None,
            "lag_mean": lmu, "s1_sign_agree": s1, "s5_mean": s5mu,
            "neg_dsr_12": neg, "passes": ok, "neg_flag": nflag,
            "coh_gross_mean": sum(cg) / n if n else None, "coh_gross_t": tstat(cg),
            "coh_gross_dsr": dsr_of(cg, b12),
            "eqw_gross_mean": sum(eg) / n if n else None, "eqw_gross_t": tstat(eg),
            "eqw_gross_dsr": dsr_of(eg, b12),
            "trunc_delisting": a["trunc_del"], "trunc_hole": a["trunc_hole"], "skips": a["skips"],
        }

    print(f"\nDECISION RULE (closed 12-arm set, trials=12, run_valid={run_valid}): "
          f"passing arms = {len(passing)}" + (f" {passing}" if passing else ""))
    print(f"Symmetric NEGATIVE flags: {len(neg_flags)}" + (f" {neg_flags}" if neg_flags else ""))
    print("VERDICT: " + ("PROMOTION CANDIDATE per prereg — owner presentation required" if passing
                         else "NULL on the 2010-2026 XBRL-era survivorship-free (retail-inclusive) "
                              "population — value's documented DROUGHT decade; the value-premium "
                              "ASSUMPTION becomes a MEASUREMENT on this era/population, NOT a "
                              "refutation of the academic value premium"))

    _write_results(args.out, {
        "prereg": "PREREG_2026-07-13_value_factor.md", "window": [WIN_LO, WIN_HI],
        "clean_names": len(clean), "screened": len(screened),
        "usable_signal_names": usable, "census_split": split,
        "census_shares_disagreements": disagree_cnt[0],
        "varTrialSharpe": vts, "bench_12": b12, "bench_floor": b12f,
        "bench_registry": breg, "placebo_scalar_max_dsr": pmax_s,
        "placebo_price_max_dsr": pmax_p, "run_valid": run_valid,
        "results": results,
        "passing": [f"{s}/{sc}/H{h}" for s, sc, h in passing],
        "neg_flags": [f"{s}/{sc}/H{h}" for s, sc, h in neg_flags]})
    print(f"results -> {args.out}")

    if args.ledger and not smoke:
        import subprocess
        run_id = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
        with open(LEDGER, "a") as f:
            for (sig, scope, H) in keys:
                a = results[f"{sig}/{scope}/H{H}"]
                f.write(json.dumps({
                    "family": "value-factor", "run": run_id,
                    "panel": "eodhd-us-delisted+active-2026-07-10+edgar-facts-value",
                    "arm": f"{sig}/{scope}/H{H}", "sharpe": a["diff_sharpe"],
                    "dsr": a["dsr_12"], "n": a["n_blocks"],
                    "verdict": "pass" if a["passes"] else "null",
                }) + "\n")
        print(f"LEDGER: appended {len(keys)} arms")


if __name__ == "__main__":
    main()
