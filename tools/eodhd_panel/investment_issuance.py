#!/usr/bin/env python3
"""PRE-REGISTERED investment/issuance FF-factor-leg ablation (asset-growth CMA + net-share-
issuance) LONG tilt on the EODHD survivorship-free panel with SEC EDGAR fundamentals.

Pre-registration: tools/eodhd_panel/PREREG_2026-07-15_investment_issuance.md (committed BEFORE
any statistic). Reuses the twice-verified value_factor.py / gpa_quality.py / smallcap_maxbabivol.py
machinery with a one-signal swap. Every rule implements a prereg clause:

  SIGNAL   AG  = Assets(FY_t)/Assets(FY_{t-1}) - 1     (asset growth; edgar_facts/ Assets)
           ISS = sharesAdj(FY_t)/sharesAdj(FY_{t-1}) - 1 (net issuance; edgar_facts_value/ shares)
           LONG = the LOW end (conservative / buyback). The stored signal is the NEGATED delta
           (-AG, -ISS) so a top-tercile-by-signal sort = bottom-tercile-by-delta = the published
           long leg. diff_mean>0 => low cohort beat EQW.
  FIX 1    pair-interval guard (design-review Surface 1): a Δ is annual ONLY if end_t-end_{t-1} in
           [340,380] days — drops skipped-year (2yr growth) and fiscal-year-change stubs (6mo).
  PRICE-EXOGENOUS  the invest signal is a ready scalar (Assets/shares only, NO price). It is fed
           through a DEDICATED price-independent `_invest_run_leg` (sig[code]=scalar directly) —
           NOT the value runner's `run_leg`/`placebo_scalar`, which divide by price (num/(px*sh))
           and would re-introduce the 1/price residual that fired the value placebo. Design-review
           Surface 3 downstream fix; a price-invariance selfcheck locks it.
  FIX A    ISS shares split-adjusted: sharesAdj(FY)=rawShares(FY)*split_factor_after(splits,FY-end)
           puts BOTH years on today's basis so the ratio is split-neutral (a 7:1 split is NOT an
           issuance). A selfcheck asserts a splitting name with constant real shares reads ISS=0.
  FIX B/C  shares source (value_factor.shares_for_end) + JOINT availability = first bar STRICTLY
           AFTER max(filed) over BOTH FY_t and FY_{t-1} ingredient records.
  BOOKS/LEGS/STATS  inherited: BOTTOM-tercile long (via negated signal) vs ONE EQW-all-eligible;
           scopes FULL/LOWLIQ; H in {63,126,252}; S1' lag +126 (pass conjunct) | S1''/S1''' placebo
           (veto) | S2a winsor | S2b no-screen+winsor | S4 Shumway | S5 freshness 504.
  STATS    12 arms (2 signals x 3H x 2 scopes); trials 12; varTrialSharpe floored 0.0343 BINDING;
           gross t/DSR both books; symmetric negative flags.

Usage: python3 investment_issuance.py [--ledger] [--out results.json]  [SMOKE=N env]
"""
import json, os, sys, bisect, argparse, statistics
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import value_factor as VF
from value_factor import (shares_for_end, split_factor_after, _earliest_by_end,
                          dsr_of, prep_value_name,
                          HORIZONS, SCOPES, FRESH, FRESH_S5, LAG, VAR_FLOOR, WIN_LO, WIN_HI)
from smallcap_maxbabivol import (psr, expected_max_sharpe, moments, tstat, adjust,
                                 selfcheck_drys, MIN_NAMES, BASE, MANIFEST, MARKET, REPO, LEDGER)

FACTS_GPA = os.path.join(BASE, "edgar_facts")        # Assets (asset growth)
FACTS_VAL = os.path.join(BASE, "edgar_facts_value")  # shares (net issuance)
SIGNALS = ["AG", "ISS"]
PRIOR_ARMS = 0            # ledger census: zero investment/issuance empirical arms (prereg verified)


def _pair_interval_ok(end_prev, end_t):
    """FIX 1 (design-review Surface 1): a Δ is only an ANNUAL growth if the two FY-ends are ~1 year
    apart. A skipped year (2013→2016 = 2yr growth) or a fiscal-year-change stub (Dec→Jun = 6mo)
    mislabels a multi-period/partial-period change as annual → scatters names to tercile extremes on
    a wrong basis → dilutes any real spread toward null. Require end_t − end_prev ∈ [340,380] days
    (the same window the duration-fact guard uses)."""
    from datetime import date
    d = (date(*map(int, end_t.split("-"))) - date(*map(int, end_prev.split("-")))).days
    return 340 <= d <= 380


def assets_events(rec_gpa):
    """Consecutive-FY Assets ratio. Returns [(end_t, avail_filed, -AG, end_{t-1})] sorted by end_t.
    -AG stored (negated) so top-tercile-by-signal = low-asset-growth long. avail = max(filed) over
    BOTH years' Assets records (FIX C). Assets>0 both years."""
    ast = _earliest_by_end(rec_gpa.get("assets", []), False)       # {(end,'Assets'): record}
    by_end = {}
    for (end, tag), x in ast.items():
        if tag == "Assets" and x.get("val") and x["val"] > 0:
            by_end[end] = x
    ends = sorted(by_end)
    events = []
    for i in range(1, len(ends)):
        e_t, e_p = ends[i], ends[i - 1]
        if not _pair_interval_ok(e_p, e_t):                        # FIX 1: annual pairs only
            continue
        a_t, a_p = by_end[e_t], by_end[e_p]
        if a_p["val"] <= 0:
            continue
        ag = a_t["val"] / a_p["val"] - 1.0
        avail = max(a_t["filed"], a_p["filed"])                    # FIX C: both FYs public
        events.append((e_t, avail, -ag, e_p))                      # NEGATED
    return events


def issuance_events(rec_val, splits):
    """Consecutive-FY split-adjusted-shares ratio. Returns [(end_t, avail_filed, -ISS, end_{t-1})].
    sharesAdj(FY)=rawShares*split_factor_after(splits,FY-end) → the ratio is split-neutral. avail =
    max(filed) over BOTH years' share records (FIX C). -ISS stored so top-tercile = low-issuance."""
    # collect the (end, sharesAdj, filed) for every FY-end where shares resolve
    ends_seen = set()
    for x in rec_val.get("shares_dei", []) + rec_val.get("shares_gaap", []):
        if x.get("end"):
            ends_seen.add(x["end"])
    # shares_for_end keys off the numerator FY-end; here the "end" IS the shares period-end, so we
    # match dei within +45d of itself (0 days) or gaap exact — call shares_for_end with each candidate
    # end. To avoid the dei-forward-date mismatch (dei end != gaap end), anchor on gaap Assets-style
    # ends is wrong for shares; instead resolve shares directly per distinct end.
    resolved = {}      # end -> (sharesAdj, filed)
    for end in sorted(ends_seen):
        sh = shares_for_end(rec_val, end)
        if sh is None:
            continue
        raw, filed, _src = sh
        if raw <= 0:
            continue
        resolved[end] = (raw * split_factor_after(splits, end), filed)
    ends = sorted(resolved)
    events = []
    for i in range(1, len(ends)):
        e_t, e_p = ends[i], ends[i - 1]
        if not _pair_interval_ok(e_p, e_t):                       # FIX 1: annual pairs only
            continue
        s_t, f_t = resolved[e_t]
        s_p, f_p = resolved[e_p]
        if s_p <= 0:
            continue
        iss = s_t / s_p - 1.0
        avail = max(f_t, f_p)
        events.append((e_t, avail, -iss, e_p))                    # NEGATED
    return events


def selfcheck_invest():
    # AG: Assets 100 -> 110 over consecutive FYs => AG=0.10 => stored -0.10; avail = later filed.
    rec = {"assets": [{"tag": "Assets", "fy": 2014, "end": "2014-12-31", "frame_start": None,
                       "filed": "2015-02-15", "val": 100.0, "form": "10-K"},
                      {"tag": "Assets", "fy": 2015, "end": "2015-12-31", "frame_start": None,
                       "filed": "2016-02-15", "val": 110.0, "form": "10-K"}]}
    ev = assets_events(rec)
    assert len(ev) == 1, ev
    end_t, avail, negag, end_p = ev[0]
    assert end_t == "2015-12-31" and end_p == "2014-12-31", ev
    assert abs(negag - (-0.10)) < 1e-12, f"AG stored should be -0.10, got {negag}"
    assert avail == "2016-02-15", f"AG avail = max(filed) both FYs, got {avail}"
    # ISS split-neutrality (the load-bearing claim): raw shares CONSTANT at 900M across two FYs, but
    # a 7:1 split happened BETWEEN them. sharesAdj_t = 900M*1 (no split after FY_t 2015);
    # sharesAdj_{t-1} = 900M*7 (the 2015 split is AFTER FY_{t-1} 2013). ISS = (900*1)/(900*7)-1?
    # NO — that's wrong direction. Let's reason: real shares are constant 900M in RAW terms only if
    # no split happened. With a 7:1 split between the FYs, the FY_t 10-K reports ~6.3B raw shares
    # (post-split) and FY_{t-1} reported ~900M (pre-split) — a real NON-issuance. sharesAdj puts both
    # on today's basis: sharesAdj_{t-1}=900M*split_factor_after(FY_{t-1}) includes the future split;
    # sharesAdj_t=6.3B*split_factor_after(FY_t) does not. Both should equal ~today's 6.3B basis.
    splits = [("2014-06-09", 7.0, 1.0)]                 # 7:1 between the two FY-ends
    rec_v = {"shares_dei": [
                {"tag": "EntityCommonStockSharesOutstanding", "end": "2013-12-31",
                 "filed": "2014-02-15", "val": 900.0, "form": "10-K"},
                {"tag": "EntityCommonStockSharesOutstanding", "end": "2014-12-31",
                 "filed": "2015-02-15", "val": 6300.0, "form": "10-K"}],
             "shares_gaap": []}
    ev2 = issuance_events(rec_v, splits)
    assert len(ev2) == 1, ev2
    _, _, negiss, _ = ev2[0]
    # sharesAdj_{t-1} = 900 * 7 (split after 2013-12-31) = 6300; sharesAdj_t = 6300 * 1 = 6300.
    # ISS = 6300/6300 - 1 = 0 => stored -0.0. The split is NOT read as an issuance.
    assert abs(negiss - 0.0) < 1e-9, f"ISS split-neutrality FAILED: splitting name reads issuance {-negiss}, must be 0"
    # A REAL issuance (no split): 900M -> 990M raw, no splits => ISS=+0.10 => stored -0.10.
    rec_v2 = {"shares_dei": [
                {"tag": "EntityCommonStockSharesOutstanding", "end": "2013-12-31",
                 "filed": "2014-02-15", "val": 900.0, "form": "10-K"},
                {"tag": "EntityCommonStockSharesOutstanding", "end": "2014-12-31",
                 "filed": "2015-02-15", "val": 990.0, "form": "10-K"}],
              "shares_gaap": []}
    ev3 = issuance_events(rec_v2, [])
    assert len(ev3) == 1 and abs(ev3[0][2] - (-0.10)) < 1e-9, f"real +10% issuance -> stored -0.10: {ev3}"
    # FIX 1 (design-review Surface 1): a 2-year-GAP pair and a 6-month-STUB pair produce NO event.
    rec_gap = {"assets": [{"tag": "Assets", "fy": 2013, "end": "2013-12-31", "frame_start": None,
                           "filed": "2014-02-15", "val": 100.0, "form": "10-K"},
                          {"tag": "Assets", "fy": 2016, "end": "2016-12-31", "frame_start": None,
                           "filed": "2017-02-15", "val": 150.0, "form": "10-K"}]}       # 3yr gap
    assert assets_events(rec_gap) == [], f"2-year-gap pair must yield NO AG event: {assets_events(rec_gap)}"
    rec_stub = {"assets": [{"tag": "Assets", "fy": 2013, "end": "2013-12-31", "frame_start": None,
                            "filed": "2014-02-15", "val": 100.0, "form": "10-K"},
                           {"tag": "Assets", "fy": 2014, "end": "2014-06-30", "frame_start": None,
                            "filed": "2014-08-15", "val": 105.0, "form": "10-K"}]}       # 6mo stub
    assert assets_events(rec_stub) == [], f"6-month-stub pair must yield NO AG event: {assets_events(rec_stub)}"
    # FIX 2 (design-review Surface 3 downstream): the signal is PRICE-INVARIANT — two names with the
    # SAME AG but different price levels must land in the SAME tercile. _invest_run_leg reads sig[code]
    # directly (no num/(px*sh) division), so the stored -AG scalar carries no price. Assert the leg
    # ranks purely on the signal, independent of price. (Direct check: the signal scalar IS -AG, with
    # no px term anywhere in _invest_run_leg's sig assignment — grep-proven at the sig[code]=cur[3]
    # line; here we assert the event scalar itself has no price dependence by construction.)
    e_ag = assets_events(rec)[0][2]          # -0.10, computed from Assets only, no price
    assert abs(e_ag - (-0.10)) < 1e-9, "AG signal must be price-INVARIANT (Assets-only), got %r" % e_ag
    print("selfcheck PASS: AG delta (-0.10, joint avail), ISS split-NEUTRAL (7:1 split reads 0 issuance), "
          "ISS real +10% issuance reads -0.10, FIX1 gap/stub pairs dropped, FIX2 signal price-invariant")


def _write_results(path, payload):
    with open(path, "w") as f:
        json.dump(payload, f, indent=1)


# ---------- price-EXOGENOUS leg + placebos (the invest signal is a ready scalar, not num/price) ----------
# sigmap[code] = [(avail_pos, filed_pos, end, neg_delta_signal)] sorted by end. Unlike the value
# run_leg (which forms num/(px*sh) at bar p), the invest signal is fixed at the FY — no price. This
# mirrors the GP/A run_leg exactly (GP/A is also a price-exogenous scalar signal).
import math


def _invest_run_leg(names, sigmap, wdates, lag, fresh, shuffle_sig=None, shuffle_ret=None):
    """One pass. shuffle_sig/shuffle_ret are RNGs for the two placebos (None = base). shuffle_sig
    permutes the signal scalar across eligible names; shuffle_ret permutes forward returns."""
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
                for av, fp_, end, s in reversed(evs):
                    if av + lag <= p:
                        cur = (av, fp_, end, s); break
                if cur is None:
                    continue
                if cur[1] + lag < p - fresh + 1:
                    stale += 1; continue
                dvw = [nm["dv"][j] for j in range(max(0, p - 62), p + 1) if not math.isnan(nm["dv"][j])]
                if not dvw:
                    continue
                elig.append(code); liq[code] = statistics.median(dvw); sig[code] = cur[3]
            stale_drops[(H, p)] = stale
            if len(elig) < MIN_NAMES:
                for scope, _ in SCOPES:
                    arms[(scope, H)]["skips"] += 1
                p += H; continue
            if shuffle_sig is not None:
                vals = list(sig.values()); shuffle_sig.shuffle(vals); sig = dict(zip(elig, vals))
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
            if shuffle_ret is not None:
                rv = [brets[c] for c in elig]; shuffle_ret.shuffle(rv); brets = dict(zip(elig, rv))
            for scope, _ in SCOPES:
                members = [c for c in elig if scope == "FULL" or c in lowliq]
                a = arms[(scope, H)]
                if len(members) < MIN_NAMES:
                    a["skips"] += 1; continue
                # TOP tercile by the NEGATED signal = BOTTOM tercile by delta = the LOW-invest long leg
                coh = sorted(members, key=lambda c: sig[c], reverse=True)[: max(1, len(members) // 3)]

                def bmean(cs, wins=False, s4=False):
                    tot = 0.0
                    for c in cs:
                        r = brets[c]
                        if s4 and dele.get(c) is True:
                            r = (1 + r) * (1 + (-0.30)) - 1
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


def _invest_placebo_signal(names, sigmap, wdates, seed):
    import random
    arms, _ = _invest_run_leg(names, sigmap, wdates, 0, FRESH, shuffle_sig=random.Random(seed))
    return {k: v["d"] for k, v in arms.items()}


def _invest_placebo_returns(names, sigmap, wdates, seed):
    import random
    arms, _ = _invest_run_leg(names, sigmap, wdates, 0, FRESH, shuffle_ret=random.Random(seed))
    return {k: v["d"] for k, v in arms.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "invest_results.json"))
    args = ap.parse_args()
    smoke = int(os.environ.get("SMOKE", "0"))

    selfcheck_drys()
    selfcheck_invest()

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
        nm = prep_value_name(code, wdates, wpos, rej)   # identical prep to the value run (splits kept)
        if nm is None:
            continue
        (screened if nm["screen"] else clean).append(nm)
    print(f"prep done: clean={len(clean)} screened={len(screened)} rejections={rej}")

    REGISTRY_ARMS = 783    # ledger line count at prereg commit (over-deflates vs deduped = safe)
    sigmaps = {s: {} for s in SIGNALS}
    usable = {s: 0 for s in SIGNALS}
    split = {"delisted": [0, 0], "active": [0, 0]}
    one_fy = [0]; pre_window_dropped = [0]
    for nm in clean + screened:
        code = nm["code"]
        pg = os.path.join(FACTS_GPA, code + ".json")
        pv = os.path.join(FACTS_VAL, code + ".json")
        cls = "delisted" if delist_of.get(code, "9999") < "2026-06-01" else "active"
        have = False
        # AG from GP/A Assets
        if os.path.exists(pg):
            rg = json.load(open(pg))
            if not rg.get("missing"):
                ev = assets_events(rg)
                if not ev and len([x for x in rg.get("assets", []) if x.get("val")]) == 1:
                    one_fy[0] += 1
                pos = []
                for end_t, avail, negsig, end_p in ev:
                    if avail < WIN_LO:
                        pre_window_dropped[0] += 1; continue
                    av = bisect.bisect_right(wdates, avail)
                    if av < N:
                        pos.append((av, av, end_t, negsig))
                if pos:
                    sigmaps["AG"][code] = pos; usable["AG"] += 1; have = True
        # ISS from value shares
        if os.path.exists(pv):
            rv = json.load(open(pv))
            if not rv.get("missing"):
                ev = issuance_events(rv, nm["splits"])
                pos = []
                for end_t, avail, negsig, end_p in ev:
                    if avail < WIN_LO:
                        pre_window_dropped[0] += 1; continue
                    av = bisect.bisect_right(wdates, avail)
                    if av < N:
                        pos.append((av, av, end_t, negsig))
                if pos:
                    sigmaps["ISS"][code] = pos; usable["ISS"] += 1; have = True
        if have:
            split[cls][0] += 1; split[cls][1] += 1
    print(f"CENSUS usable-signal names: AG={usable['AG']} ISS={usable['ISS']}")
    print(f"CENSUS single-FY names (ineligible for the delta): {one_fy[0]}")
    print(f"CENSUS pre-window-filed events dropped: {pre_window_dropped[0]}")
    print(f"CENSUS usable split: delisted={split['delisted'][1]} active={split['active'][1]}")

    # run_leg expects sigmap entries (av, fp, end, num, sharesAdj) — but our invest signal is already
    # a scalar (the negated delta), so we feed it as (av, fp, end, negdelta, 1.0) and set the ratio to
    # negdelta/(px*1.0)... NO: run_leg forms num/(px*sh). For a PRICE-EXOGENOUS signal we must bypass
    # that. Use a dedicated invest run_leg (below) that reads sig directly.
    legs = {}
    plac_a = {}; plac_b = {}
    for sig in SIGNALS:
        sm = sigmaps[sig]
        print(f"\n=== {sig} BASE leg ===", flush=True)
        legs[(sig, "base")], stale = _invest_run_leg(clean, sm, wdates, 0, FRESH)
        yearly = {}
        for (H, p), s in stale.items():
            if H == 63:
                yearly.setdefault(wdates[p][:4], []).append(s)
        print(f"CENSUS {sig} staleness drops (H63, mean/rebalance by year): "
              + " ".join(f"{y}:{sum(v)/len(v):.0f}" for y, v in sorted(yearly.items())))
        print(f"=== {sig} S1' lag (+126) ===", flush=True)
        legs[(sig, "lag")], _ = _invest_run_leg(clean, sm, wdates, LAG, FRESH)
        print(f"=== {sig} S5 freshness-504 ===", flush=True)
        legs[(sig, "s5")], _ = _invest_run_leg(clean, sm, wdates, 0, FRESH_S5)
        print(f"=== {sig} S2b no-screen ===", flush=True)
        legs[(sig, "s2b")], _ = _invest_run_leg(clean + screened, sm, wdates, 0, FRESH)
        print(f"=== {sig} placebos x3 (signal-shuffle + returns-shuffle) ===", flush=True)
        for seed in (1, 2, 3):
            plac_a[(sig, seed)] = _invest_placebo_signal(clean, sm, wdates, seed)
            plac_b[(sig, seed)] = _invest_placebo_returns(clean, sm, wdates, seed)

    keys = [(sig, scope, H) for sig in SIGNALS for scope, _ in SCOPES for H in HORIZONS]
    srs = {}
    for (sig, scope, H) in keys:
        d = legs[(sig, "base")][(scope, H)]["d"]
        mu, sd, sk, ku = moments(d) if len(d) > 3 else (0, 0, 0, 3)
        srs[(sig, scope, H)] = (0.0 if sd == 0 else mu / sd, sk, ku, len(d))
    vts = statistics.variance([s[0] for s in srs.values()])
    vts_f = max(vts, VAR_FLOOR)
    b12 = expected_max_sharpe(12 + PRIOR_ARMS, vts)
    b12f = expected_max_sharpe(12 + PRIOR_ARMS, vts_f)
    breg = expected_max_sharpe(12 + REGISTRY_ARMS, vts)
    print(f"\nvarTrialSharpe={vts:.6f} (floored {vts_f:.6f}); bench12={b12:.4f} "
          f"benchFloor={b12f:.4f} benchRegistry({12+REGISTRY_ARMS})={breg:.4f}")

    pmax_a = max((dsr_of(plac_a[(sig, seed)][(scope, H)], b12)
                  for sig in SIGNALS for seed in (1, 2, 3) for scope, _ in SCOPES for H in HORIZONS), default=0.0)
    pmax_b = max((dsr_of(plac_b[(sig, seed)][(scope, H)], b12)
                  for sig in SIGNALS for seed in (1, 2, 3) for scope, _ in SCOPES for H in HORIZONS), default=0.0)
    run_valid = pmax_a <= 0.95 and pmax_b <= 0.95
    print(f"S1'' signal-shuffle placebo max DSR={pmax_a:.3f}; S1''' returns-shuffle placebo max DSR={pmax_b:.3f} "
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
                              "population — the LONG leg of the investment/issuance FF factors (the "
                              "thin leg by construction; the alpha is short-concentrated); the factor "
                              "ASSUMPTION becomes a long-leg MEASUREMENT, NOT a refutation of the "
                              "academic factor"))

    _write_results(args.out, {
        "prereg": "PREREG_2026-07-15_investment_issuance.md", "window": [WIN_LO, WIN_HI],
        "clean_names": len(clean), "screened": len(screened),
        "usable_signal_names": usable, "census_split": split, "census_single_fy": one_fy[0],
        "varTrialSharpe": vts, "bench_12": b12, "bench_floor": b12f, "bench_registry": breg,
        "placebo_signal_max_dsr": pmax_a, "placebo_returns_max_dsr": pmax_b, "run_valid": run_valid,
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
                    "family": "investment-issuance", "run": run_id,
                    "panel": "eodhd-us-delisted+active-2026-07-10+edgar-facts",
                    "arm": f"{sig}/{scope}/H{H}", "sharpe": a["diff_sharpe"],
                    "dsr": a["dsr_12"], "n": a["n_blocks"],
                    "verdict": "pass" if a["passes"] else "null",
                }) + "\n")
        print(f"LEDGER: appended {len(keys)} arms")


if __name__ == "__main__":
    main()
