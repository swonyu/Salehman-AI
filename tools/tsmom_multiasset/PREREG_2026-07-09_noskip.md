# PRE-REGISTRATION — no-skip cross-asset momentum variant (written 2026-07-09 ~23:30, BEFORE any variant result was computed)

**Origin (post-hoc, disclosed):** the TSMOM ablation's look-ahead mutation probe (verify fleet wf_092516b0-26f, lens 3) observed that a no-skip mutant (momentum window through t−1, 12-1 skip removed — a LEGIT construction, no look-ahead) raised the absolute headline DSR more than a true 1-bar leak did (0.991, 4 absolute clears). That observation was made ON THIS PANEL's results — this variant is therefore data-suggested, and its statistics must pay for that selection.

**Hypothesis:** recent-month-inclusive cross-asset momentum (skip=0) net-of-cost beats the EQW basket where 12-1 TSMOM did not. (The 12-1 skip exists to dodge the 1-month single-name equity reversal; multi-asset ETFs may not carry that reversal.)

**Frozen design (identical to the parent run except skip):**
- Panel: the SAME frozen `panel_tsmom_multiasset.json` (16 ETFs × 2,512 returns) — no refetch.
- Signal: mom_i = Π(1+r_iu)−1 over u ∈ [t−lb, t−0) — SKIP=0 via env; all else byte-identical.
- Arms LF/LS/VS, lb ∈ {63,126,252}, hold ∈ {21,42,63}, rt ∈ {13,8}bps = 54 new trials.
- **Trials accounting: trials=108** (54 prior skip=21 arms + 54 new), varTrialSharpe pooled over ALL 108 full-series net Sharpes (prior 54 from ledger run `2026-07-09_tsmom_multiasset_v1`). Registry-informed sensitivity at trials=108+308.
- Folds=3/embargo=1 OOS verdicts; EQW paired-diff guard MANDATORY; REVERSED diagnostic; ledger append (family `tsmom-multiasset`, config `...,skip=0`).

**Decision rule (committed now):** promote to Phase-6 candidate ONLY if some config clears absolute net-OOS DSR>0.95 at trials=108 AND its EQW paired-diff verdict passes AND REVERSED shows no sign-flip on that config. Anything else → NULL, indexed, variant closed. A null is a win.

**Runner-integrity rule:** the SKIP env default (21) must reproduce the parent run's stdout byte-identically before the variant runs (regression gate).
