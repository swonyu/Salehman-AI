# PRE-REGISTRATION — 2008-inclusive momentum-crash-state re-test on the survivorship-free panel
(written 2026-07-10 ~11:20, BEFORE the panel build completed and before any test statistic was computed)

**Why this test first:** the momentum-crash INDEX row's final disposition (REFUTE-in-direction, 2026-07-03) names EXACTLY ONE revisit condition: "Only a delisting-inclusive CRSP-grade 2008 panel could revisit." The EODHD panel now assembling is the first substrate in project history that includes the 2008-09 casualties.

## Ported definitions (verbatim from RESEARCH_2026-07-03_momentum_crash_conditioning_ablation.md §Method — no re-derivation)
- BASE_MOM: long top-tercile by TSMOM ported exactly from `StockSageIndicators.timeSeriesMomentum(lookback:126, skipRecent:21)` = `(closes[i-21]-closes[i-126])/closes[i-126]`, `closes[0...i]` only; equal-weighted; non-overlapping blocks stepped by H.
- OVERLAY: identical, EXCEPT hold equal-weight-ALL during CRASH-STATE blocks.
- CRASH-STATE (as-of bar i, no look-ahead): market (^GSPC-equivalent) `close[i]/close[i-504]-1 < 0` AND trailing-21-bar realized market vol < the trailing-504-bar median of that vol series.
- Entry `open[i+1]`, exit `open[i+1+H]`; horizons H ∈ {21, 42, 63, 126}; net-of-cost 13bps RT; block-level significance; DSR selection-deflated.

## Panel construction (pre-registered rules; build code = tools/eodhd_panel/build_panel.py, already selfchecked vs the SEC boundary)
- Universe: union of (a) the delisted pull (reconstructed price-return series) and (b) a SUPPLEMENTAL active-US common-stock pull (same puller, active list venue-chunked) — required because a delisted-only cross-section is REVERSE-survivorship (only casualties); the 2008 cross-section must contain both the names that died AND the names that lived.
- Test window: 2004-01-02 → 2012-12-31 (matches the prior 2004+ re-run's window; warmup 523 bars inside it).
- Name inclusion (mechanical, decided now): series overlaps ≥ 756 bars (~3y) of the window; no `gap_days` flag inside the window; median daily dollar volume within the window ≥ $1M in then-dollars (tradeability floor — the acceptance run's ghost-print names must not enter); price ≥ $1 at window entry (penny-stock microstructure floor, consistent with the published momentum literature's filters).
- Market series: GSPC.INDX from EODHD (1 call) — same-vendor calendar.
- Cost tier: 13bps for the large/liquid names AND a sensitivity leg at 60bps (the ratified small/EM-class tier) — the panel now contains genuinely small names for which 13bps is the acceptance-documented dangerous direction.
- Trials accounting: this family has ~9 prior arms (07-03 chain) + registry census — primary trials = this run's arms + 9, plus the registry-informed sensitivity print (+308).

## Decision rule (committed now)
The 07-03 REFUTE stands UNLESS, on this delisting-inclusive panel: the crash-state FIRES during Sep-2008→May-2009 (the prior finding was that the calm-vol clause structurally cannot fire then — if that holds here too, the REFUTE is confirmed at the strongest possible substrate and the row closes permanently), AND the in-state OVERLAY−BASE_MOM diff is positive with net-OOS DSR > 0.95 at trials as above, AND REVERSED shows no sign-flip on the passing config. Anything else → REFUTE CONFIRMED, row closed permanently; a null is a win.

## Sequencing
1. Delisted pull completes (~13:00) → error-triage + one retry pass.
2. Supplemental ACTIVE-US pull (list fetch + ~11k names × 2 calls; quota-permitting today, else tomorrow after reset).
3. Full build_panel.py (both cohorts) → flag census → panel freeze (record the exact name list hash).
4. Run the re-test per this pre-reg → verify fleet → index + ship.
Small-cap MAX/BAB/IVOL and full-breadth IRRX follow on the same frozen panel (separate pre-regs).
