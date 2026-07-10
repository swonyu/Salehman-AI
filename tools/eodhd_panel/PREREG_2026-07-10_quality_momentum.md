# PRE-REGISTRATION — quality × momentum composite long tilt on the survivorship-free panel
(written 2026-07-10 ~21:40; revised ~22:10 after adversarial design review — verdict COMMIT-WITH-FIXES, both blockers +
all should-fixes + all notes applied; committed BEFORE any test statistic. The last queued combination test; a null
closes the composite space.)

**Why this test:** quality (GP/A) alone = NULL 0/6 today; momentum alone = NULL in every tested form (sign space both
directions, cross-asset, industry/residual/intermediate — near-misses EQW-guard-killed beta). The published combination
claim (quality-momentum double-sort family): near-orthogonal signals whose composite long leg historically carried more
alpha than either component at 6-12mo holds with near-zero turnover cost. Honest expectation after component nulls +
the McLean-Pontiff haircut: LOW. **Review hazard, owned:** the review's blockers were a refutable lineage claim (a GP/A
fix recorded as landed that was NOT — corrected + actually landed @ 8d75a7a the same day) and an internally
contradictory S5 clause; both fixed below.

## Data (all on disk; zero new acquisition)
- Prices: frozen panel `5ce314475941a0cd`; master GSPC.INDX. Fundamentals: the GP/A EDGAR extracts with the AUDITED
  `gpa_quality.build_signal_events` (3,940/3,940 independent match).
- **Test window: 2010-01-04 → 2026-07-09**; **panel-freeze filter basis: 2000-01-03 → 2026-07-09 (the sibling window —
  explicit per the GP/A disclosure rule)**; sibling filters incl. |Δposition|≤20 screen and the p=0 dv clamps.
- **Pre-window filed-date handling (review BLOCKER #1, re-specified here because the mapping is inline in
  `gpa_quality.main()` and cannot be imported):** GP/A events with `filed < 2010-01-04` are DROPPED with a counted
  census — the fix now actually landed in `gpa_quality.py` @ 8d75a7a (the prior "both fixed post-run" record was false
  and is corrected in the GP/A research doc). Mild NULL-direction cost (loses genuinely-fresh 2009-H2 filings at early
  rebalances) — disclosed; bounded (~20 names per the GP/A audit).

## Signals (both as-of; components reuse AUDITED builders)
- **Quality**: GP/A per the GP/A prereg's exact rules (FY-end keying, 340–380d duration guard, earliest-filed,
  max-filed availability, 378-bar freshness, pre-window drop above).
- **Momentum**: 12-1 = adjc[p−21]/adjc[p−252] − 1 (the shipped `timeSeriesMomentum(lookback:252, skipRecent:21)`
  formula on reconstructed closes); BOTH endpoints valid prints AND **≥200 valid prints (volume>0, close>0) among
  master bars in [p−252, p−21]** (review #3 — the calendar-gap filter does not cover zero-volume ghost runs; a
  suspension-recovery name valued off two isolated prints is a crisis-clustered fake-pass channel; the ≥200 rule is
  the sibling BETA/IVOL precedent).
- **Composite (review #5, pinned coded form):** eligible list in manifest order (the sibling convention);
  `order = sorted(range(n), key=sigval)` (stable ⇒ ties keep manifest order); `r[order[k]] = k/(n−1)` (n≥30 by guard;
  best → 1.0); `comp = (r_gpa + r_mom)/2`; cohort = `sorted(elig, key=comp, reverse=True)[:max(1, n//3)]` (stable
  descending). Eligibility REQUIRES both signals (fresh GP/A AND valid momentum AND entry print at p+1 AND ≥1 dv print
  in [max(0,p−62)..p]) — a missing-signal composite cannot arise.

## Books, scopes, arms
- Grid origin = window start + 252 (momentum warmup, the binding lookback — **GP/A's origin was 0 and insider's 21**
  (review #9 correction); this prereg's 252 is deliberate), stepped by H ∈ {63, 126, 252}. Entry open[p+1]; exit =
  last valid print ≤ p+1+H (booked truncations). ONE EQW per (scope,H); 30-eligible guard; skips censused.
- Scopes: FULL @13bps, as-of LOWLIQ tercile @60bps. **Net level prints ENFORCED (review #7 — this exact promise failed
  twice):** `coh_net_mean` and `eqw_net_mean` = gross block mean − scope-tier bps×1e-4, BOTH books; the runner
  SELF-FAILS (assert before the JSON is written) if either field is absent on any arm; the 2-lens audit checks the
  fields exist in the artifact. Decision statistic remains the paired diff (cost cancels).
- Decision arms = 3 × 2 = **6**; expected blocks H63 ≈ 62 / H126 ≈ 31 / H252 ≈ 14–15 (H252 pre-registered underpowered).

## Statistics
- Per arm: paired diff → mean, t, DSR; GROSS t/DSR both books; net levels (enforced).
- **Trials (review #4 — momentum's selection history belongs in the BINDING number): primary = 6 (this run) + 6 (GP/A,
  same substrate/ingredient) + M, where M = the deduped momentum-family trial-arm count read FRESH from the
  trials-ledger census at run time (expected ≈300 ⇒ primary ≈ 312; never hardcoded).** The 12-only bench is printed as
  context, never binding. varTrialSharpe = sample variance of THIS run's 6 arm Sharpes, floored at 0.0343, floor
  BINDING (pooling GP/A's 6 considered — the floor dominates either way; choice stated).
- Sensitivity legs (VETO-only): **S1′ lag +63 bars — SIGNAL CONTENT ONLY is lagged (review #6, pinned):** GP/A
  availability shifted +63 with freshness on the shifted position; momentum endpoints at p−84/p−315 with their own
  validity incl. ≥200 valid prints over [p−315, p−84]; entry/dv/rank-blend/eligibility evaluated at p within the lag
  leg's own eligible set; the lag leg skips its own guard-failing blocks; S1′ = sign(mean d) agreement, each leg over
  its own blocks. Mechanical consequences pre-registered: p<315 lag-blocks are structurally empty/skipped; at H63 the
  lag equals the hold (the lag leg trades the previous rebalance's composite — that IS the persistence test).
  **S1″ placebo:** composite values shuffled cross-sectionally per rebalance, seeds 1/2/3 (machinery veto; REVERSED
  stays excluded — the GP/A incoherence ruling carries to the half-price-exogenous composite). **S2a** winsorized
  ±100% both books. **S2b** no-integrity-screen + winsorized. **S4** Shumway −30% on delisting-truncated exits.
- **S5 component comparison (review BLOCKER #2 — resolved: context prints PLUS a veto-only pass conjunct; exact coded
  form pinned):** component tercile books (GP/A-only, momentum-only) computed IN-RUN on the SAME composite-eligible
  set, SAME grid, SAME skips (never read from `gpa_quality_results.json` — different eligible set/origin; the 12
  component-context arms are ledgered as DIAGNOSTIC class, excluded from trial counts, no promotion path, no
  symmetric-negative machinery; they will NOT match the GP/A run's numbers and are not expected to — review #10).
  ```
  assert len(d_comp) == len(d_gpa) == len(d_mom)      # identical blocks by construction
  inc_g = [a-b for a,b in zip(d_comp, d_gpa)]; inc_m = [a-b for a,b in zip(d_comp, d_mom)]
  s5_ok = sum(inc_g) > 0 and sum(inc_m) > 0           # PASS CONJUNCT (paired-mean exceedance; veto-only)
  # printed, mandatory: t and DSR (primary bench) of inc_g and inc_m
  ```
  **Claim-language rule (pre-committed):** a passing arm with min(DSR(inc_g), DSR(inc_m)) ≤ 0.95 is presented as
  "pass NOT separable from its best component" — still owner-presented, never as a combination finding.
- Mandatory censuses: per-year eligibles; GP/A-fresh vs momentum-valid attrition split; composite-vs-component cohort
  overlap (the orthogonality claim, measured); pre-window-drop count; truncations; skips.

## Decision rule (committed now; coded, closed 6-arm set)
An arm PASSES iff ALL of: diff_mean > 0 AND diff DSR > 0.95 at primary trials (6+6+M) AND DSR > 0.95 under the
variance floor AND S2a DSR > 0.95 AND S2b DSR > 0.95 AND S1′ sign-agreement AND s5_ok AND the run is valid (no placebo
arm cleared). Any pass → owner-presented promotion CANDIDATE only (with the S5 claim-language rule + the
paired-diff-overstates-net disclosure). Anything else → **NULL: the composite space closes.** **Considered-and-NOT-run
regardless of outcome (review #8, the file-drawer line):** double-sort intersection variants, any weights ≠ 50/50,
quintile cuts, and every other signal pair (quality×IVOL, momentum×insider, …) — each would need its own prereg; none
is licensed by this one. **Symmetric negative pre-commitment** as in every sibling. Partial passes are artifact flags.

## Disclosed limits (decided now)
- Rank-blend v1, equal weights (no weight search); price-return basis penalizes the quality leg AND distorts momentum
  ranks against high-yield names (both books symmetric — review #12, two-sided statement).
- The GP/A coverage-conditional scope now also gates momentum names (intersection eligibility; attrition censused);
  window 2010→2026 with filter basis 2000→2026 (explicit); H252 underpowered; pre-window drop (bounded, censused).
- Block machinery = audited sibling imports + the audited (and now correctly-fixed) GP/A signal builder; new code =
  momentum validity + rank blend + S5 books + net-print enforcement.

## Sequencing
1. THIS revised document commits BEFORE any statistic.
2. Runner → smoke → commit pre-run → detached run → 2-lens verification (conjunct audit — INCLUDING the lineage
   git-diff check the review introduced — + independent re-implementation of ≥1 arm incl. one composite value from raw
   inputs) → index + ship; ledger family `quality-momentum` (+6 decision arms; the 12 component-context arms as
   diagnostic class).
