# PRE-REGISTRATION — short-horizon reversal at FULL survivorship-free breadth (the campaign milestone's named substrate)
(written 2026-07-10 ~15:10, shared elements revised ~15:35 per the sibling prereg's adversarial design review; committed
BEFORE any test statistic was computed on this panel for this family)

**Why this test:** every prior reversal measurement (24-name 5y → 61-name 5y full-IRRX → 2,158-name 1y wide-US →
50-name 5y multi-regime) was survivor-only, and the wide runs found reversal ABSENT/INVERTED in 2025-26 large caps. The
published short-horizon reversal effect concentrates in exactly the small, illiquid, delisting-prone names this panel
finally contains. The campaign-milestone row names "delisting-inclusive/small-cap substrate" as the sharpest remaining
shot at a measured edge — this run IS that measurement for the reversal family. Symmetric exit: if even GROSS reversal is
absent here, the family is closed at every substrate the literature names; if gross exists but net dies, the cost gate is
re-validated where it matters most; only a net DSR>0.95 pass (never yet seen anywhere) escalates.

## Panel + window (frozen; no re-pull)
- Panel freeze `5ce314475941a0cd`; window 2000-01-03 → 2026-07-09; master calendar + market series GSPC.INDX;
  reconstruction from RAW close/open × splits (vendor adjusted_close never consumed).

## Inclusion + participation (shared elements = the sibling prereg's post-review form, adopted verbatim)
- Panel-freeze filters: ≥756 in-window bars; no >16-day in-window gap (count excluded by the gap clause alone printed);
  median in-window raw dollar volume ≥$1M (tradeability filter — residual future-conditioning disclosed); raw close ≥$1
  at window entry; **the data-integrity screen** (any adjacent-bar ratio >8 or <1/8, OR ≥2 opposite-direction >5×/<1/5
  flips within a rolling 21-bar span; every screened name printed with its jump date + whether a splits-ledger entry
  exists within ±5 bars).
- **Valid-return rule (governs the SIGNAL): a valid daily return at master bar j requires bars at j and j−1, both raw
  volume>0 and raw close>0**; the lookback return r_lb uses adjusted closes at the rebalance bar and lb bars earlier,
  both of which must be valid-print bars (volume>0, close>0); names with holes spanning the lookback are excluded from
  that rebalance.
- **Entry (raw presence mask): the entry bar must have the raw `open` field present >0 AND volume>0** — no
  `open or close` fallback. **Exit: the last valid raw-open print at or BEFORE the exit master date, cash for the
  remainder** (death-blocks BOOKED, not dropped; truncations counted per arm, classified delisting vs mid-series hole;
  if the last valid print precedes entry, the name drops from the block).
- **Scopes: (a) FULL eligible set; (b) LOW-LIQUIDITY tercile, AS-OF — trailing-63-bar median raw dollar volume, terciled
  cross-sectionally at each rebalance among that rebalance's eligible names** (past-only; whole-window liquidity is a
  collider — the sibling review's BLOCKER #1). Liquidity-proxy labeling, never "market cap".

## Construction (the shipped engine's family, stated mechanically)
- Signal at rebalance bar i: trailing lookback-window return per name, r_lb = adjc[i]/adjc[i−lb] − 1, names demeaned
  cross-sectionally (broad demean — the panel has NO industry metadata at this breadth; stated as industry-agnostic
  reversal, the wide-US precedent's basis, NOT full-IRRX).
- Book: LONG losers / SHORT winners, weights w_i ∝ −(r_lb − mean), L1-normalized to gross 1 per side-pair (the shipped
  `irrxWeights` construction, re-implemented; ≥1 arm must be verified by independent re-implementation, and the
  construction must reproduce the shipped-sim anchors' SHAPE on a fixture before the full run).
- Grid: lb ∈ {5, 10, 21, 63} × hold ∈ {5, 10, 21} (the shipped 12-config sweep), non-overlapping blocks stepped by hold;
  entry open[i+1], exit open[i+1+hold].
- Costs: per-side turnover-charged at 13bps RT primary + 60bps low-liquidity leg (cost does NOT cancel here — the
  long-short book turns over; this is a net-of-cost test, unlike the paired-diff selection tests). GROSS also reported
  (the "does the anomaly even exist here" question).
- Degenerate guard: skip blocks with <30 eligible names; skips counted and printed.

## Statistics
- Per (scope, lb, hold, cost): net block-return series → mean, t, DSR (`StockSageDeflatedSharpe` port, verified bit-exact
  2026-07-10); GROSS series likewise.
- **Trials accounting (decided now): trials = 24 decision arms (2 scopes × 12 configs) + 98 prior reversal-irrx family
  arms = 122**; registry-informed sensitivity print at trials = 24 + 701 = 725 (double-counts the 98 + ledger cost-leg
  duplicates — over-deflation, safe direction, stated). varTrialSharpe = sample variance of this run's observed arm
  Sharpes, **floored at 0.0343 (the crash-retest's measured value on this panel) for a print that is BINDING on any
  would-be pass** (correlated-arm under-spread is anti-conservative).
- Sensitivity legs (VETO-only — can disqualify, never qualify): S1 REVERSED per arm (statistic = sign agreement with the
  forward arm); S2a winsorized (per-name block returns capped ±100%); S2b no-integrity-screen + winsorized (screened
  genuine collapses cannot hide a real effect in either direction); S3 long-leg-only sub-print (retail cannot short
  microcaps; a long-short "pass" whose alpha lives in the short leg is flagged non-implementable, per the BAB/MAX fence
  rationale); S4 delisting-haircut: truncated-by-delisting exits charged an additional −30% (Shumway-class) — a would-be
  pass must survive the BASE treatment; a null that flips under S4 is reported inconclusive-on-delisting-treatment.
- Implementation permissions: precomputed rolling statistics permitted (mechanically identical); Lens-B verifier must
  reproduce ≥1 name-date signal and ≥1 arm from raw bars; typed arrays permitted for memory.
- Borrow costs NOT modeled (gross-favorable for the short leg — stated; any pass is therefore an UPPER bound).

## Decision rule (committed now; coded with ALL conjuncts, closed 24-arm passing set — the crash-retest F4 lesson)
The runner's passing set is drawn ONLY from the 24 pre-registered decision arms at trials=122. An arm PASSES iff ALL of:
net mean > 0 AND net DSR > 0.95 at trials=122 AND DSR > 0.95 under the variance floor AND S2a net DSR > 0.95 AND S2b net
DSR > 0.95 AND S1 sign-agreement AND the S3 long-leg-only print is itself positive-net (implementability). If any arm
passes → owner-presented promotion CANDIDATE only (nothing wires without the full validation bar + fresh-data
confirmation). Anything else → NULL: the RefuseList naive-reversal fence is re-confirmed at the strongest substrate the
literature names, and the campaign-milestone row's "delisting-inclusive substrate" residual is ANSWERED for the reversal
family. Gross-positive/net-dead is reported as cost-gate re-validation, not as a finding-in-waiting.
**Symmetric negative pre-commitment:** a net series significantly NEGATIVE (DSR > 0.95 on the negated series at
trials=122, surviving S1/S2a/S2b) is reported as an anti-edge flag (reversal INVERTED — the wide-US 2025-26 direction),
never improvised at results time.

## Sequencing
1. Fold the sibling prereg's design-review fixes into the shared elements; commit BEFORE running.
2. Runner extends the same verified machinery; run AFTER the MAX/BAB/IVOL run (quota-free — panel already on disk).
3. 2-lens adversarial verification (code audit + independent re-implementation of ≥1 arm) → index + ship; ledger family
   `reversal-survfree` (+arms as recorded).
