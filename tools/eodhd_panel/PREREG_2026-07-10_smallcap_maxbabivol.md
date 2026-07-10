# PRE-REGISTRATION — MAX / low-beta / low-IVOL LONG-leg re-test on the survivorship-free panel's small/retail segment
(written 2026-07-10 ~14:40, revised ~15:00 after adversarial design review [verdict COMMIT-WITH-FIXES, all mandatory +
recommended fixes applied], committed BEFORE any test statistic was computed on this panel for these families)
[header clock-typo corrected post-run per audit F12 — the original read "written ~15:00, revised ~15:30", impossible
against the 15:02:46 commit stamp; git ancestry (prereg 1601771 → runner a85b7a9 → results 15:22) proves the discipline]

**Why this test:** the 2026-07-03 nulls for MAX/lottery, low-beta/BAB-long and low-IVOL all carry the same explicit caveat:
the 18-mega-cap substrate "excludes the small/retail-heavy segment where the published effect is strongest — conservative
test, not a literature refutation." The frozen survivorship-free panel (34,701 series, hash `5ce314475941a0cd`) is the
first substrate that CONTAINS that segment without survivorship bias. This run closes the caveat in whichever direction
the data says — the design-review fixes below exist precisely so the run can neither fabricate a pass (review #1) nor
fabricate a null (review #2/#3).

## Panel + window (frozen; no re-pull)
- Panel freeze `5ce314475941a0cd`; manifest + raw files under `~/.claude/salehman-universe/panels/eodhd_us_delisted/`.
- Window: 2000-01-03 → 2026-07-09 (full multi-regime depth: dot-com, GFC, 2020, 2022, bulls).
- Master calendar + market series: GSPC.INDX (same vendor).
- Adjusted opens+closes rebuilt in-script from RAW close/open × split ledger (vendor adjusted_close never consumed).

## Panel-freeze inclusion filters (mechanical, symmetric across arms)
1. ≥756 in-window bars; no in-window calendar gap >16 days; median in-window raw dollar volume ≥$1M; raw close ≥$1 at
   window entry (the crash-retest filters, unchanged). The $1M whole-window floor is a TRADEABILITY filter and carries a
   residual (weak, disclosed) future-conditioning shape; the DECISION partition never uses whole-window information (§Scopes).
   The count excluded by the gap clause ALONE is printed (review #14 — suspensions concentrate in the segment under test).
2. **Data-integrity screen (mandatory consequence of the crash-retest verifier F1):** exclude the name if, on its
   reconstructed in-window adjusted closes, (a) ANY adjacent-bar ratio >8 or <1/8, OR (b) within any rolling 21-bar span
   there are ≥2 opposite-direction adjacent-bar ratios >5 or <1/5 (the LAN/TRA oscillation signature). Every screened name
   is printed with its jump date AND whether a splits-ledger entry exists within ±5 bars of it (review #8 — a missing
   ledger entry looks exactly like a jump; the series is corrupt either way, but the census must be diagnosable).
   Known bias risk (disclosed): genuine one-day >87.5% collapses are real events in this segment and are exactly the
   high-MAX left-tail — mitigated by sensitivity S2b (no-screen + winsorized) for ALL THREE signals, not just MAX.

## Valid-return rule (review #2 — governs ALL signal computation; the ghost-print class lives below the 8× screen)
A valid daily return exists at master bar j for a name iff the name has bars mapped to BOTH master j and j−1, each with
raw volume>0 AND raw close>0. MAX/BETA/IVOL are computed ONLY on valid returns; returns spanning holes are EXCLUDED
(never treated as daily). Minimum counts, pinned: MAX requires ≥15 valid returns in the trailing 21 master bars;
BETA/IVOL require ≥200 valid same-day-paired returns in the trailing 252 master bars.

## Eligibility, warmup, scopes (reviews #1, #4)
- **Harmonized warmup: 252 master bars for all three signals** — every arm at a given (scope, H) draws from the IDENTICAL
  eligible set and shares ONE EQW book. Eligibility at a rebalance = passes the valid-return minimums for all three
  signals AND has a valid entry bar (below).
- **Scopes: (a) FULL eligible set; (b) LOW-LIQUIDITY tercile, AS-OF: trailing-63-bar median raw dollar volume, terciled
  cross-sectionally at each rebalance among that rebalance's eligible names** (past-only, time-varying membership — the
  review-#1 fix: whole-window liquidity is a collider that would bias cohort−EQW toward a fabricated pass, and mislabels
  the population vs the literature's as-of size sorts). Labeled a LIQUIDITY proxy, never "market cap" (no cap metadata).
- Signal terciles are computed WITHIN the scope's eligible set at each rebalance (never global-terciles-intersected-with-scope).

## Signals (ported from the 07-03 definitions; per-name, as-of, valid-returns only)
- **MAX**: mean of the top-5 valid daily returns over the trailing 21 master bars (Bali-Cakici-Whitelaw 2011). Cohort =
  LOW-MAX (bottom tercile) long, per the published lottery-demand direction.
- **BETA**: OLS slope of the name's valid trailing-252-bar daily returns on same-day GSPC returns. Cohort = LOW-BETA
  (bottom tercile) long (BAB long leg / Baker-Bradley-Wurgler defensive).
- **IVOL**: residual stdev of that same market-model regression. Cohort = LOW-IVOL (bottom tercile) long.
- Delimiter (review #12): a beta/IVOL null closes the ACTIONABLE long-tilt caveat (raw cohort−EQW at retail), not the
  academic risk-adjusted (alpha) anomaly — same delimiter as the 07-03 files.

## Books, entries/exits, truncation handling
- Rebalance every H ∈ {21, 63, 126} on non-overlapping blocks; entry at open[i+1]; cohort + EQW books equal-weighted.
- **Participation/entry (review #7 — raw presence mask, not adjo positivity):** the entry bar must exist on the RAW
  series with the `open` field present and >0 AND volume>0; the split-adjustment carries a presence mask; no
  `open or close` fallback anywhere.
- **Exit (review #3 — death-blocks must be BOOKED, not dropped):** exit price = the last valid raw-open print (open field
  present >0, volume>0) at or BEFORE the exit master date, adjusted; cash (0 return) for the remainder of the block. If
  that last valid print precedes the entry bar, the name is dropped from the block (no valid holding period). Truncations
  are counted per arm and classified (series-ended/delisting vs mid-series hole). Rationale: the lottery/IVOL premium is
  substantially carried by high-MAX names dying — silently deleting death-blocks manufactures the null this prereg exists
  to test honestly.
- Degenerate guard: skip a block if <30 eligible names in the scope; skips counted AND printed.
- Decision arms = 3 signals × 3 horizons × 2 scopes = **18**. Cost legs 13bps and 60bps RT are printed for levels only;
  the DECISION statistic is the cohort−EQW paired block diff, in which cost cancels exactly for fully-re-forming books
  (selection-diff; confirmed decision-inert by review #11). Disclosure pinned to the promotion clause: the paired-diff
  convention over-charges EQW relative to its real turnover, so a passing candidate's REAL net advantage is SMALLER than
  the printed diff.

## Statistics
- Per arm: block diff series d = COHORT − EQW (paired); mean, t; DSR on d via the `StockSageDeflatedSharpe` port
  (verified bit-exact by two lenses 2026-07-10); absolute cohort DSR also printed (context only, never qualifying).
- **Trials accounting (decided now): trials = 18 (this run's decision arms) + 106 prior family arms from the trials
  ledger (max-lottery 16 + low-beta 62 + downside-beta 28) = 124.** Registry-informed sensitivity print at trials =
  18 + 701 = 719 (the full ledger census; double-counts the 106 and the ledger's cost-leg duplicates — over-deflation,
  safe direction, stated per the registry's own caveat).
- varTrialSharpe = sample variance of this run's 18 observed arm Sharpes, **floored (review #9): the bench is also
  printed with varTrialSharpe = max(observed, 0.0343 — the crash-retest's measured value on this panel); the floor print
  is BINDING on any would-be pass** (18 arms across 3 correlated signals ≈ ~6 effective; under-spread variance would be
  anti-conservative).
- Sensitivity legs (mandatory, pre-registered; VETO-only — they can disqualify, never qualify):
  **S1** REVERSED (walk-backward) per arm; statistic = sign(rev_diff_mean) == sign(diff_mean) on the passing arm.
  **S2a** winsorized re-run (per-name block returns capped ±100%), all arms.
  **S2b** no-integrity-screen + winsorized re-run, ALL THREE signals (review #8 — screen-removed genuine collapse/lottery
  names cannot hide a real effect, in either direction).
  **S3** delisting-haircut re-run: truncated-by-delisting exits charged an ADDITIONAL −30% (Shumway-class haircut) — a
  would-be NULL must be robust to it (the haircut hurts the high cohort, i.e. helps the LOW-cohort hypothesis; a null
  that dies under S3 is reported as inconclusive-on-delisting-treatment, not null); a would-be pass must survive the
  BASE treatment (S3 cannot qualify).

## Decision rule (committed now; coded with ALL conjuncts — the crash-retest F4 lesson)
The runner's passing set is drawn ONLY from the 18 pre-registered decision arms at trials=124. An arm PASSES iff ALL of:
paired-diff mean > 0 (published direction) AND paired-diff DSR > 0.95 at trials=124 AND DSR > 0.95 under the review-#9
variance floor AND S2a DSR > 0.95 AND S2b DSR > 0.95 AND S1 sign-agreement holds. If any arm passes → owner-presented
promotion CANDIDATE only (nothing wires without the full validation bar + fresh-data confirmation; presentation must
carry the review-#11 over-statement disclosure). Anything else → NULL; the 07-03 small/retail caveat closes as "tested on
the population the literature names, still nothing"; a null is a win.
**Symmetric negative pre-commitment (review #6):** a paired diff significantly NEGATIVE (DSR > 0.95 on −d at trials=124,
surviving S1/S2a/S2b) is reported as an anti-edge flag extending the refuse-list corpus — the 07-03 significant-negative
finding's direction — never improvised at results time. Partial passes are beta/artifact flags, never findings.

## Implementation permissions (review #13)
Precomputed rolling statistics (incremental sums for beta/IVOL/MAX and the 63-bar liquidity median) are PERMITTED —
mechanically identical to direct computation; the Lens-B verifier must reproduce ≥1 name-date signal by DIRECT trailing-
252-bar OLS from raw bars. Typed arrays permitted for memory (~7-10k names × master-length series).

## Sequencing
1. Commit this prereg BEFORE running (same discipline as the crash re-test).
2. Runner extends `crash2008_retest.py`'s verified machinery (reconstruction, master calendar, DSR port, block loop) +
   the rules above.
3. Run → 2-lens adversarial verification (code audit vs THIS document conjunct-by-conjunct + independent
   re-implementation of ≥1 arm incl. one direct-OLS signal reproduction) → index + ship; ledger family
   `smallcap-maxbabivol`.
4. Full-breadth reversal on the same frozen panel follows under its own pre-registration
   (`PREREG_2026-07-10_survfree_reversal.md`), inheriting these shared-element fixes.
