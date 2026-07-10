# RESEARCH 2026-07-10 — 2008-inclusive momentum-crash-state re-test on the first survivorship-free panel (pre-registered)

**Verdict: REFUTE CONFIRMED under the pre-registered decision rule — the momentum-crash overlay row closes PERMANENTLY.**
The crash-state fires **0 bars** in Sep-2008→May-2009 even on delisting-inclusive, same-vendor data (the 07-03 structural
finding reproduced on an independent vendor and the strongest substrate the disposition named), and **0 of 16 arms** show a
positive overlay−base diff with DSR>0.95. A null is a win; this one closes a 4-run chain.

## Why this test, and why it could have flipped the ruling
The 2026-07-03 momentum-crash chain (Daniel-Moskowitz 2016 conditioning) ended REFUTE-in-direction with exactly one named
revisit condition: *"Only a delisting-inclusive CRSP-grade 2008 panel could revisit."* The owner bought EODHD All World
(2026-07-10); the acceptance test passed CONDITIONAL ×3; the survivorship-free panel (34,701 reconstructed series,
delisted + active union, freeze hash `5ce314475941a0cd`) is the first substrate in project history containing the 2008-09
casualties. This run is that revisit — pre-registered before any test statistic existed
(`tools/eodhd_panel/PREREG_2026-07-10_crash2008_retest.md`, committed at `a8c0afc`).

## Method (ported verbatim — no re-derivation)
- **BASE_MOM**: long top-tercile by TSMOM `(closes[i-21]-closes[i-126])/closes[i-126]` (the shipped
  `StockSageIndicators.timeSeriesMomentum(lookback:126, skipRecent:21)` formula), equal-weighted, non-overlapping blocks
  stepped by H. **OVERLAY**: identical, except hold equal-weight-ALL during crash-state blocks.
- **CRASH-STATE** (as-of bar i, no look-ahead): market `close[i]/close[i-504]-1 < 0` AND trailing-21-bar realized vol <
  trailing-504-bar median of that vol series. Market = GSPC.INDX, same vendor as the panel.
- Entry `open[i+1]`, exit `open[i+1+H]`; H ∈ {21, 42, 63, 126}; costs 13bps AND a 60bps sensitivity leg (the ratified
  small/EM tier — the panel contains genuinely small names). Cost cancels in the OVERLAY−BASE diff by construction (both
  arms pay it), so the rt13/rt60 diff columns are identical BY DESIGN; the leg shifts only the net level prints.
- Adjusted opens+closes rebuilt in-script from RAW close/open × the split ledger (vendor `adjusted_close` never consumed —
  the acceptance test proved it clamp-corrupted for this population). Self-checks in-run: DRYS SEC boundary −0.213894
  exact, Φ/Φ⁻¹, t-stat fixture.
- **Windows**: PRIMARY 2004-01-02→2012-12-31 (pre-registered). SECONDARY 2000-01-03→2012-12-31 — **LABELED DATA-SUGGESTED**
  (added after the market-leg diagnostic showed 2001-03 fired extensively = the "fired slow-bleed crash" the 07-03
  disposition required; disclosed, not pre-registered).
- **Inclusion** (mechanical, pre-registered, symmetric across arms): ≥756 in-window bars; no in-window gap >16 calendar
  days; median in-window dollar volume ≥$1M; raw close ≥$1 at window entry. PRIMARY: 3,201 included of 15,495 overlapping
  candidates. SECONDARY: 3,323 of 17,591.
- **Stats**: block diff d = OVERLAY_net − BASE_net (nonzero only on fired blocks); mean, t; fired-only subset; DSR with
  trials = 16 arms + 9 prior family arms = 25 (registry-informed sensitivity print at trials=333),
  varTrialSharpe = sample variance of the 16 observed arm Sharpes (0.03426 → expectedMaxSharpe 0.3696 primary / 0.5419
  registry); PSR/expected-max ported arithmetic-for-arithmetic from `StockSageDeflatedSharpe.swift`. REVERSED
  (full walk-backward) per arm. EQW guard: BASE−EQW paired gross diff per arm.

## Results
**Decision-rule conjunct 1 — state fire in the GFC window: 0 bars fired in Sep-2008→May-2009** (exact-median recompute,
34,701-series panel's own market series; first post-crash firing 2009-06-12 per the independent verifier's exact
computation — matching the 07-03 Yahoo-panel finding to the day, a cross-vendor agreement; the earlier sampled diagnostic's
2009-06-15 was the approximation). The calm-vol clause structurally excludes
high-vol crashes — reproduced now on THREE substrates (Yahoo 20y, 99-year EODHD GSPC diagnostic, this run).

| window | H | nblk | nfired | diff_mean | t | fired_mean | DSR | DSRreg | rev_mean |
|---|---|---|---|---|---|---|---|---|---|
| PRIMARY 2004-12 | 21 | 101 | 13 | −0.40307 | −1.00 | −3.13153 | 0.000 | 0.000 | +0.20338 |
| PRIMARY 2004-12 | 42 | 50 | 7 | −0.00920 | −1.42 | −0.06569 | 0.000 | 0.000 | +0.40852 |
| PRIMARY 2004-12 | 63 | 33 | 4 | −0.01503 | −1.52 | −0.12396 | 0.000 | 0.000 | −0.00285 |
| PRIMARY 2004-12 | 126 | 16 | 2 | −0.01325 | −0.87 | −0.10600 | 0.000 | 0.000 | +0.00436 |
| SECONDARY 2000-12 | 21 | 149 | 35 | +0.00315 | 0.05 | +0.01343 | 0.000 | 0.000 | +0.12603 |
| SECONDARY 2000-12 | 42 | 74 | 19 | +0.13356 | 1.29 | +0.52019 | 0.000 | 0.000 | +0.27809 |
| SECONDARY 2000-12 | 63 | 49 | 11 | +0.20696 | 1.29 | +0.92190 | 0.006 | 0.000 | −0.04673 |
| SECONDARY 2000-12 | 126 | 24 | 7 | +0.17177 | 0.90 | +0.58892 | 0.064 | 0.002 | −0.04694 |

(rt13/rt60 rows identical on all diff columns — cost cancels in the diff; both legs recorded in the results JSON and ledger.)

**⚠ MEANS ARE NON-ECONOMIC — read §Data-quality before quoting any magnitude in this table.** The raw arithmetic means are
contaminated by a symbol-reuse defect class (verifier F1); the verifier's winsorized sensitivity (per-name block returns
capped ±100%) keeps every conclusion (PRIMARY H21: base +0.677→+0.0088/blk, diff −0.4031→−0.0004, fired −3.1315→−0.0031,
t −1.00→−0.79 — still null-negative) while collapsing magnitudes to plausible. The t/DSR decision statistics were already
sign/insignificance-honest; the means were not.

- **PRIMARY (the pre-registered window): overlay NEGATIVE at every horizon** (t −0.87…−1.52, DSR ≈ 0) — the 07-03 finding
  reproduced on the survivorship-free panel: where the state fires (calm recovery/continuation), flattening dilutes the tilt.
- **SECONDARY (the fired slow-bleed crash the disposition asked for): the overlay finally gets its target regime**
  (35/19/11/7 fired blocks incl. 2001-03) **and still fails** — fired-block diffs directionally positive at H42-126
  (+0.52/+0.92/+0.59 per fired block) but never near significance (t ≤ 1.29), best DSR **0.064** (registry-informed 0.002)
  ≪ 0.95. Direction-consistent with the premise, decisively short of any bar, and in a disclosed non-pre-registered window.
- **EQW guard context**: BASE−EQW gross ≈ 0 (|t| ≤ 0.04 at H21/42) — the momentum tilt itself shows no measurable edge vs
  equal-weight on this panel, consistent with the wide-US baseline nulls.
- **Decision rule applied mechanically**: state-fires-in-GFC = NO; arms with positive diff AND DSR>0.95 = 0 →
  **REFUTE CONFIRMED — row closes permanently.** (REVERSED sign-flips appear only on null arms = noise, per the
  walk-backward interpretation guide.)

## Data-quality caveats (honest, load-bearing)
- **NEW PANEL DEFECT CLASS (verifier F1, mandatory for every future run on this panel): interleaved symbol-reuse series
  pass ALL pre-registered filters.** `LAN`'s raw file interleaves two different instruments day-by-day (~$0.15 and ~$9,000
  prints alternating within the same week); block #67 (entry 2010-02-05 open $0.155 → exit 2010-03-09 open $9,002.94)
  books a fake +58,082× return, and LAN alone contributes −40.69 of the −40.71 fired-diff sum ⇒ **99.95% of the PRIMARY
  H21 `fired_diff_mean` (−3.13) is ONE symbol-reuse defect**. Other offenders: TRA (+7,221×/+6,496×/+5,562×/+457× regime
  flips), CGRN (+206×), YRCW (+7,539×), NST (+16.9× — entry priced off a volume=0 ghost print via the runner's
  `open or close` fallback, a deviation from the prereg's open-only commitment). The acceptance-documented
  symbol-reuse/ghost-print classes evade the median-$vol/$1-price/gap filters and the manifest flags.
  **Future runs on this panel MUST add a same-series price-regime-jump screen.**
- **Winsorized sensitivity (verifier F2): the verdict is insensitive; the magnitudes were not.** Capping per-name block
  returns at ±100%: PRIMARY H21 base gross +0.677→+0.0088/blk, diff −0.4031→−0.0004, fired −3.1315→−0.0031, t −1.00→−0.79
  (±300% cap: t −0.86) — still null-negative everywhere. The SECONDARY window's positive fired diffs are equally
  artifact-dominated AS MAGNITUDES (their t≤1.29/DSR≤0.064 already said "nothing" statistically). No raw mean in this file
  is an economics estimate.
- **Ghost-liquidity floor is a floor, not a fix**: the $1M median-dollar-volume + $1 price filters remove the worst
  acceptance-documented artifacts but small-name block returns remain retail-unachievable at size; this biases TOWARD
  finding an effect, which makes the null stronger.
- **Death-block truncation (verifier F7)**: a name with a valid entry but no bar at the block exit is dropped from that
  block's book — its terminal loss is never booked (measured: 657 of 282,338 name-block observations, ~0.23%; 1–18 per
  fired block). The ≥756-in-window-bars filter additionally excludes short-lived names (IPO-2007-die-2008 class). So the
  honest phrasing is: the 2008-09 casualties are included **as time series**, but their death-blocks are excluded from the
  books — "survivorship-free" at the panel level, survivorship-lite at the block level.
- **Price-return-only basis** (dividends excluded — the acceptance test found the vendor dividend field cap-corrupted for
  this population); symmetric across arms, so the diff is unaffected to first order.
- 1,362 of 36,063 raw series were honestly rejected at build (defect flags per the acceptance predictions); the panel is
  frozen (`panel_freeze.txt`, hash `5ce314475941a0cd`) — reruns are byte-reproducible.

## What this run did NOT establish
- Nothing about the overlay on dividend-inclusive total returns (price-return basis; symmetric, but stated).
- Nothing about other crash definitions — this closes THE shipped 07-03 state definition (24mo-negative AND calm-vol), not
  every conceivable regime conditioner. Any new conditioner is a NEW candidate that starts from zero at the full bar.
- The SECONDARY window's positive-but-insignificant fired diffs are NOT evidence-in-waiting: data-suggested window,
  best DSR 0.064, and the effect must survive trials accounting that only grows.

## Verification (adversarial, 2 independent lenses)
- **Lens A (code audit)**: prereg-fidelity item-by-item, look-ahead hunt (state median window, signal/entry indexing,
  inclusion-filter symmetry), cost-cancellation accounting, DSR port vs `StockSageDeflatedSharpe.swift`
  arithmetic-for-arithmetic, decision-rule mechanics, outlier characterization, ledger-append cross-check.
  **Result: NOT-REFUTED** — see verdict + findings recorded below.
- **Lens B (independent re-implementation)**: fresh-code recompute from the prereg TEXT (no shared code): GFC state-fire
  count, full PRIMARY H42 arm (included names, block series, diff mean/t, fired subset), DSR spot-check from raw moments.
  **Result: reproduction PASS** — numbers recorded below.

### Verifier findings (recorded verbatim-in-substance)
- **Lens B — reproduction PASS on all 3 checks** (fresh ~200-line implementation from the prereg text only; script preserved
  in the session scratchpad, output beside it; runtime 256s over 15,495 manifest candidates):
  (1) crash-state on GSPC: 0 fired bars in [2008-09-01, 2009-05-31] ✓; first fired date ≥2008-09-01 = **2009-06-12**
  (exact median — corrects the sampled diagnostic's 2009-06-15 and matches the 07-03 Yahoo finding to the day); 401 fired
  bars in 2001–2003 (the slow bleed) ✓. (2) PRIMARY H42_rt13 full arm: included 3201 ✓, n_blocks 50 ✓, n_fired 7 ✓,
  diff_mean −0.009196471800196495 (|Δ| 1.7e−18), diff_t −1.4204967674082103 (bit-exact), fired_diff_mean
  −0.06568908428711782 (|Δ| 1.4e−17) — agreement at float summation-order noise, far past the ≥5-dp bar; the 7 fired-block
  diffs (4 negative / 3 positive, two large negatives dominating) are individually listed in the verifier report.
  (3) DSR spot-check from raw moments: bench 0.36963482456018326, DSR 1.3254724544753477e−15 — bit-exact.
  One structural note: `GSPC_INDX.json` is a bare bar list (per-name raws use the `{"eod":…, "splits":…}` wrapper) —
  immaterial, handled per inspection.
- **Lens A — code audit: NOT-REFUTED — "the decision is robust, but the printed panel-leg magnitudes are ~99.9%
  single-name data corruption and must not be quoted as economics."** Verified clean: look-ahead (state median
  `vol21[i-503:i+1]` as-of inclusive; signal indices past-only; inclusion filters symmetric panel-freeze, cannot bias the
  diff; split back-walk correct, DRYS boundary green); DSR port faithful arithmetic-for-arithmetic vs
  `StockSageDeflatedSharpe.swift` (same denominator/√(n−1)/Euler-Mascheroni/raw-kurtosis convention; JSON reproduced
  bit-for-bit: varTrialSharpe 0.0342550, bench 0.369635, DSR(H21) 4.53e−21; hand-check Φ(−9.348) consistent); REVERSED
  convention matches the altdata precedent (period axis flipped, state calendar-anchored — docstring wording loose);
  decision rule mechanically confirmed from the JSON (max dsr_primary 0.0637; `gfc and passing` = False); cost
  cancellation in the diff CORRECT for fully-re-forming equal-weight books. Material findings → §Data-quality (F1/F2/F7)
  and the protocol notes below.

### Audit-disclosed protocol notes (Lens A — recorded, all direction-safe or moot this run)
- **F3 — the 60bps "sensitivity leg" is decision-inert by construction**: cost cancels exactly in the diff, so the 8 rt60
  arms are bit-duplicates of rt13 (results JSON confirms; 8 unique Sharpes of 16 nominal arms). The leg only shifts the
  displayed net levels. Side effect: trials=25 with duplicated arms → bench 0.3696 vs 0.350 for an honest 8-unique/17-trials
  accounting — CONSERVATIVE direction (higher bar), harmless, but the arm count is nominal, not effective.
- **F4 — the coded decision rule omitted the prereg's third conjunct** ("REVERSED shows no sign-flip on the passing
  config") and let SECONDARY (non-pre-registered) arms into the `passing` set — both make escalation EASIER
  (anti-conservative), both moot: nothing came within 15 orders of magnitude of passing.
- **F5 — minor deviations**: in-window >16-day gap recomputation substituted for the manifest `gap_days` flag (defensible —
  the flag is whole-series); block warmup satisfied from pre-window GSPC history (verified: no fired block in the added
  early region; first fired block enters 2009-07-08); the `open or close` entry fallback deviates from the prereg's
  open-only commitment and produced the NST ghost-print entry (F1).
- **F12 — nits**: the runner's "(reported, not silent)" comment on the <30-names guard is false (no skip counter printed;
  probe measured 0 skips this run, so inert); `retest_run1.log` is 0 bytes — run 1 produced no statistics before the
  prereg+runner commit, run 2 ran from the committed runner (no see-stats-then-edit loop); the verdict's DSR is a
  SELECTION-DIFF DSR (cost cancels in the diff), not a net-of-cost DSR in the usual sense — phrased accordingly here.

## Engine mapping
**No engine change.** The overlay was never wired; the RefuseList fence and the 07-03 disposition stand. The one
non-redundant mechanism the chain surfaced (vol-TRAJECTORY conditioning targets an axis vol-LEVEL controls miss) remains
true and remains net-negative-where-testable — recorded, not wired. Trials ledger: +16 arms appended
(family `momentum-crash-2008-retest`, run `a8c0afc`, panel `eodhd-us-delisted+active-2026-07-10`).

## Artifacts (durable)
- Runner: `tools/eodhd_panel/crash2008_retest.py` (self-checking; `--ledger` auto-append; REVERSED built-in).
- Pre-registration: `tools/eodhd_panel/PREREG_2026-07-10_crash2008_retest.md` (committed before any statistic).
- Results + logs + freeze: `~/.claude/salehman-universe/panels/eodhd_us_delisted/{crash2008_retest_results.json,
  retest_run2.log, panel_freeze.txt, state_fire_diagnostic_2026-07-10.txt}`.
- Panel: 34,701 reconstructed series under the same directory (`returns/`, `manifest.jsonl`, `raw/`).

## Follow-ups on the SAME frozen panel (separate pre-regs, per the prereg's sequencing note)
Small-cap MAX/BAB/IVOL (the families whose published effects live in exactly this population) and full-breadth IRRX —
each gets its own pre-registration before any statistic is computed. **MANDATORY for every follow-up (from verifier F1):
add a same-series price-regime-jump screen to the inclusion filters** (the interleaved symbol-reuse class — LAN/TRA-style
day-by-day flips between price regimes — passes the median-$vol/$1/gap filters and the manifest flags; screen BEFORE any
statistic, in the pre-registration), and use open-only entries (no `open or close` fallback — the NST ghost-print lesson).
