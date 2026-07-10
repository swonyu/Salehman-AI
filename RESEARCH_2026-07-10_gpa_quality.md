# RESEARCH 2026-07-10 — GP/A gross-profitability long tilt on the survivorship-free panel (pre-registered; the first fundamentals-side ablation in project history)

**Verdict: NULL — 0 of 6 arms pass the all-conjunct rule; run VALID (placebo veto clean); the campaign-milestone row's
LAST surveyed named shot CLOSES.** The quality family's current-era ≈null (QMJ post-2013 t=1.01, QUAL vs SPY) now
extends by measurement to the small/retail survivorship-free population — the one segment the survey left open. Diffs
are noise-grade: +0.09% to +0.29%/block at H63/H126 (t ≤ 0.67, best DSR 0.326), NEGATIVE at H252, and the small
positives flip sign under the 6-month lag conjunct on 4/6 arms — the behavior of noise, not of a slow premium.

## Why this test
The 2026-07-09 non-price survey: quality = the only family with genuine published long-leg alpha (Novy-Marx 2013
long-quintile FF3 +0.34%/mo t=5.01) AND retail cost-immunity (~once-per-4y turnover), but current-era measured ≈null on
large caps. Expected size stated in the prereg before any statistic: ~0.5–1%/yr pre-haircut — an order of magnitude
under the DSR bar; the honest purpose was closing the caveat in whichever direction the data said.

## Data path (all measured pre-prereg; the acceptance chain)
- EODHD fundamentals PLAN-GATED at the owner's $29.99 All World Extended tier (403 measured incl. AAPL.US) → routed to
  **SEC EDGAR companyfacts, free** (delisted filers persist — probe-verified). Window 2010-01-04→2026-07-09 (XBRL era;
  pre-2010 casualties absent, disclosed).
- Ticker→CIK: 4,288/5,135 clean names mapped (83.5%; conservative name-matching, 595 ambiguous dropped) + 184/249
  screened names (so S2b is real). Extraction: 3,807 facts files / 481 no-XBRL / 0 errors; wiped+re-pulled once when
  the design review extended the revenue tag lists (no mixed-vintage files).
- **Usable-signal names: 2,432** (pinned tags; the acceptance census's 54% was a floor) — **802 delisted + 1,630
  active**: the survivorship-free property SURVIVES the fundamentals join (census iii).

## Protocol (locked at `49a8300` BEFORE any statistic; design review fixed two NULL-manufacturing blockers pre-commit)
- **Review blocker #1**: EDGAR's `fy`/`fp` describe the FILING and lump 2–3 comparative years — FY identity is keyed by
  each fact's own period END date (duration facts need end−start ∈ [340,380] days; Assets = instant fact at the same
  end; earliest-filed per (name,end,tag); availability = first master bar strictly after max(`filed`) over ingredients).
- **Review blocker #2**: walk-backward REVERSED is incoherent for a price-exogenous signal (cohorts price-independent ⇒
  reversal ≈ negates every diff ⇒ the conjunct could never pass) — replaced by **S1′ lag-robustness** (+126 bars
  availability delay, sign agreement, pass conjunct) + **S1″ placebo** (GP/A shuffled cross-sectionally, seeds 1/2/3;
  any placebo arm clearing DSR>0.95 invalidates the run).
- Signal: GP/A = GrossProfit/Assets (direct tag else Revenues−COGS, pinned priorities, same period-end); freshness
  378 bars (S5 leg at 504); TOP-tercile long vs ONE EQW-all-eligible per (scope,H); scopes FULL @13bps / as-of LOWLIQ
  tercile @60bps (levels only — cost cancels in the paired diff); H ∈ {63,126,252} with H252 pre-registered as
  underpowered (~15 blocks); trials = 6 + 0 empirical family priors (registry print 749); variance floor 0.0343
  binding; S2a winsorized; S2b no-screen+winsorized; S4 Shumway −30%; gross t/DSR for BOTH books; censuses i–v;
  symmetric negative pre-commitment; runner committed pre-run at `961002e` with hand-derived signal fixtures.

## Results (closed 6-arm set; diff = TOP-GP/A cohort − EQW, paired per block)

| arm | nblk | diff_mean | t | DSR6 | DSRflr | S2a | S2b | S1lag | negDSR | cohG_t | eqwG_t |
|---|---|---|---|---|---|---|---|---|---|---|---|
| FULL/H63 | 64 | +0.00091 | 0.31 | 0.151 | 0.056 | 0.237 | 0.247 | N | 0.050 | 2.91 | 2.78 |
| FULL/H126 | 31 | +0.00291 | 0.48 | 0.326 | 0.199 | 0.432 | 0.433 | N | 0.079 | 3.32 | 3.12 |
| FULL/H252 | 15 | −0.00567 | −0.45 | 0.130 | 0.080 | 0.267 | 0.230 | Y | 0.426 | 3.22 | 3.47 |
| LOWLIQ/H63 | 64 | +0.00242 | 0.67 | 0.252 | 0.110 | 0.400 | 0.535 | N | 0.024 | 2.98 | 2.84 |
| LOWLIQ/H126 | 31 | +0.00121 | 0.17 | 0.224 | 0.125 | 0.467 | 0.573 | N | 0.134 | 3.08 | 3.04 |
| LOWLIQ/H252 | 15 | −0.01451 | −0.88 | 0.049 | 0.026 | 0.204 | 0.190 | Y | 0.606 | 3.20 | 3.52 |

- **Decision rule: 0 passing; 0 negative flags; run VALID** (placebo max DSR 0.692 across 3 seeds × 6 arms < 0.95).
- varTrialSharpe 0.0170 (floored 0.0343 — floor binding as pre-registered); bench6 0.169 / floor 0.241 / registry 0.413.
- The cohG_t/eqwG_t ≈ 3 columns are BOTH books' market beta over a 16-year window — near-identical for cohort and EQW,
  i.e. no differential whatsoever; quoted only to show the gross machinery carries significance where significance
  exists (the beta), and none where it doesn't (the tilt).
- S1′ lag behavior is the diagnostic core of the null: the H63/H126 positives (≤0.29%/block) do not survive a 6-month
  availability delay with a stable sign — a real multi-year quality premium would; noise does not.
- Censuses (i–v complete; iv and i-b filled post-hoc per the audit — data-only, appended to the results JSON):
  **(iv) eligible per rebalance**: 20 (2010) → 1,198 (2013) → stable ~1,100–1,470 through 2026 — the covered
  cross-section is well-powered from 2013 on. **(i-b) the staleness channel, bounded**: dropped-stale instances peak
  1,170/yr (2018) ≈ 10–20% of name-instances in later years, but the subset whose name subsequently DIES in-window —
  the only part that could hide quality's protective leg — is 3–244/yr ≈ **2–5% of instances**: material, disclosed,
  not verdict-scale. (ii) 227 assets-but-no-revenue names; (iii) delisted 62.7% vs active 61.8% usable — the join does
  NOT dilute the survivorship-free property; (v) 2,432/3,917 facts-present = 62.1% > the 54% census floor, direction
  consistent.

## What this run did NOT establish
- Nothing about pre-2010 quality (XBRL window); nothing risk-adjusted (raw long-tilt only, per the prereg delimiter);
  nothing about dividend-inclusive returns (price-return basis UNDERSTATES quality — the null survived a bias in its
  favor... stated precisely: the basis biases AGAINST finding the premium, so the null is on the conservative side and
  closes the ACTIONABLE raw-tilt question, not the total-return academic one).
- The two pre-registered NULL-direction channels (staleness excision of delinquent filers' pre-death window;
  revenue-tag amputation of the low-GP/A tail) are censused, not eliminated — they shave the null's decisiveness at
  the margin, and the prereg committed to closing the caveat with them disclosed.

## Verification (pre-registered 2-lens bar)
- **Lens A (code audit, conjunct-by-conjunct): NOT-REFUTED — "NULL verdict and run-validity both stand."** Provenance
  git-verified (prereg → runner=HEAD=ledger-run-id → results). Decision rule exact and re-evaluated from the JSON
  (passes=0, neg_flags=0 reproduced); **statistics bit-match to the last digit** (varTrialSharpe 0.016973568386110676;
  all three benches; DSR/negDSR on three arms); the review-#1 FY-keying fix verified LIVE-load-bearing (real 10-K
  comparatives carry fp="FY" on quarterly end-dates — only the duration guard removes them); availability strictness
  verified incl. the filed-on-a-trading-day case; the lag leg is exactly "same names, delayed"; the placebo leg diffed
  line-by-line against the base (identical books, shuffle-only difference, conservative bench). Data spot-checks: AABA
  (delisted) / AAPL / an order-contended derived-path name — GP/A values reproduced to 7 digits; **an independent
  re-implementation of the signal builder from the prereg text matched on 0/3,940 files mismatched.** S4 robustness of
  the null confirmed from the artifact (max s4_dsr 0.315, sign-stable).
- **Lens A findings requiring action (all applied/recorded):**
  - Two latent code defects, PROVEN INERT for this run (each bounded by the same 20 pre-window-filed names < the
    30-name block minimum; grid arithmetic confirms exactly 1 skipped block per arm): a p=0 negative-index dv window
    (would read the array's FUTURE tail) and a pre-window filed-date clamp (would over-extend freshness). **Both fixed
    post-run in the runner** before any re-use; verdict untouched.
  - **Two prereg-mandated censuses did not print** (disclosure-grade): census i's second half (staleness-dropped names
    that subsequently die in-window) and census iv (per-year eligible counts). **Filled post-hoc by
    `gpa_census_fill.py`** — data-only, no test statistic, prereg-safe per the audit's explicit ruling; appended to the
    results JSON (numbers below).
  - Costs 13/60bps were never applied anywhere (dead code — no net-level prints, unlike the siblings): verdict-inert
    (cost cancels in the paired diff; ~annual turnover), but the prereg's "levels printed" under-delivered — recorded.
  - The prereg's "block machinery = sibling code (imported)" is partly literal: prep/adjust/screen/stats imported; the
    block loop is a rewrite the audit verified semantically identical.
- **Lens B (independent re-implementation from the prereg text): PASS on CHECK 2 (signal derivations, two names,
  dual code paths) and CHECK 3 (DSR bit-exact: varTrialSharpe/benches/dsr all `==`; also established the runner used
  stdlib NormalDist, not an Acklam inverse). CHECK 1 (full-arm) localized a PREREG AMBIGUITY and reproduced to ~4dp
  after alignment — formally short of the 5dp bar, adjudicated sufficient BY COMPOSITION (below).**
  Its as-contracted read applied the §Data window (2010) to the panel-freeze filters and diverged (Δmean 4.7e-4 on
  FULL/H63); a 12-combo filter sweep PROVED no 2010-basis panel can reach the runner's universe, and switching ONLY the
  filter-window basis to 2000 (what §Books pins via "as implemented in the sibling machinery") collapsed the divergence
  to 7.0e-6 on FULL/H63 (2.0e-5/1.2e-4 on the other FULL arms; ~3.5dp on LOWLIQ), with n_blocks and skips EXACT on all
  six arms and eligible-by-year within 0–4/yr. Declared residual: ~80 usable names trace to its independent re-reading
  of the sibling price-filter row basis (first divergent grid position p=252: 252 vs 253 eligible — one name).
- **Adjudication (orchestrator, recorded): ship on composition.** The unaligned residual sits entirely in the
  price-filter layer that was independently reproduced BIT-EXACT this same day by the sibling run's verifier
  (clean=5,135 and full arms at 0 absdiff using these exact rules); the GP/A-specific layers were verified twice over
  (Lens A's 3,940/3,940-file signal match + Lens B's CHECK 2; stats bit-exact by both lenses); and the NULL is
  insensitive under EVERY construction tried — both Lens B variants and the runner agree in sign, magnitude and
  non-significance on all six arms.
- **DISCLOSURE (mandatory, both lenses converged on it): the prereg's §Data "window 2010-01-04→2026-07-09" describes
  the TEST window (master axis, books, signals) but NOT the panel-freeze filter basis, which §Books pins to the
  sibling implementation and therefore evaluates over 2000–2026.** The runner followed §Books; the effect of the
  ambiguity is quantified at Δmean ≤ 4.7e-4 (verdict-inert); future preregs must state the filter-window basis
  explicitly.

### Audit-mandated interpretation guards (applied throughout this file)
- **Gross-book significance is beta, not signal**: cohG/eqwG t ≈ 2.8–3.5 (and gross DSRs up to ~0.999) are
  long-the-market 2010–26, near-identical for both books, EQW ≥ cohort at H252 — only the paired-diff column is
  evidentiary; gross clears are never near-misses (the documented bull-beta trap).
- **The null is SCOPED to the signal-covered universe**: three channels feed the late-window staleness ramp —
  delinquent-filer pre-death excision (prereg-named), **pinned-tag drift (audit-PROVEN on AABA: filed
  Revenues+Assets through FY2016 but no pinned COGS tag after FY2011 — stale from mid-2013 while trading to 2019)**,
  and deregistered-while-trading names. Books are symmetric (diff internally valid); the covered universe skews
  healthier/standard-tagged/timely-filing. The post-hoc censuses bound the channels' magnitude.
- **The universe carve is the panel-freeze filters evaluated over 2000–2026** (the sibling constants, prereg-pinned):
  ≥756 bars of listed life excludes short-lived casualties and post-mid-2023 IPOs — the prereg's "recent IPOs
  eligible" wording overstated; quality effects concentrate in young/small firms, so this carve is a further
  scope limit on the null.
- **H252's negative point estimates (−0.57%/−1.45%/block) are 15-block underpowered noise** (pre-registered as such);
  they correctly did not trip the symmetric negative rule and are not an anti-edge narrative.
- **The S1′ lag sign-flips are noise + a mechanical composition channel** (recent filers absent from the lag leg by
  construction) — NOT leak evidence; S1′ is a veto conjunct that was never reached in the pass direction.

## Engine mapping
**No engine change; nothing wired.** The campaign-milestone row's last surveyed named shot is closed; remaining routes
to a measured edge are the insider-Form-4 empirical run (SEC bulk data sets confirmed live, download in progress) and
the quality×momentum composite (this run's arms become its family priors). Trials ledger: +6 arms, family `gpa-quality`.

## Artifacts
Prereg + runner + extractors: `tools/eodhd_panel/{PREREG_2026-07-10_gpa_quality.md, gpa_quality.py, edgar_pull_gpa.py,
edgar_map_census.py, edgar_map_screened.py}`. Results + log + facts + map:
`~/.claude/salehman-universe/panels/eodhd_us_delisted/{gpa_quality_results.json, gpa_run1.log, edgar_facts/,
edgar_cik_map.json}`. Panel frozen `5ce314475941a0cd`.
