# RESEARCH 2026-07-10 — short-horizon reversal at FULL survivorship-free breadth (pre-registered; the campaign-milestone row's "delisting-inclusive substrate" measurement for the reversal family)

**Verdict: NULL — 0 of 24 arms pass the pre-registered all-conjunct rule; the RefuseList naive-reversal fence is
re-confirmed at the strongest substrate the literature names, and the milestone row's delisting-inclusive residual is
ANSWERED for the reversal family.** The economically substantive part, stated at audit-corrected strength: the FULL-scope
short-hold arms are **gross-mean POINT-positive** (direction restored vs the inverted 2025-26 wide-US 1y run — the 26y
window includes the pre-2010 era) but "gross reversal exists here" is NOT licensed — no gross t/DSR was computed
(prereg under-delivery, disclosed below), the means are tail-concentrated and artifact-exposed, and the deflated bar
kills everything (best DSR 0.030). In the low-liquidity segment — exactly where the point-positivity is largest — the
evidence-ratified 60bps cost tier turns every arm net-NEGATIVE (t to −4.2). The 2026-07-02 week-horizon conclusion
("reversal positive gross → decisively negative net at retail costs") reproduces in DIRECTION at survivorship-free
breadth, with the cost model the decisive lever.

## Why this test
Every prior reversal measurement (24-name/5y → 61-name/5y full-IRRX → 2,158-name/1y wide-US → 50-name/5y multi-regime)
was survivor-only, and the wide 2025-26 runs found reversal absent/inverted. The published effect concentrates in small,
illiquid, delisting-prone names — this panel's population. The campaign-milestone row names "delisting-inclusive/small-cap
substrate" as the sharpest remaining shot; this run is that measurement for reversal.

## Protocol (pre-registered, locked at `1601771` BEFORE any statistic; runner committed pre-run at `83b6e7e`)
- Shared elements inherit the sibling MAX/BAB/IVOL prereg's design-review fixes verbatim (as-of liquidity terciles,
  valid-print participation, raw-open presence mask, booked death-block exits, integrity screen) — that shared machinery
  was audited NOT-REFUTED and independently reproduced bit-exact the same day.
- **Construction = the SHIPPED `StockSageNetCostSim.irrxWeights` WEIGHT SHAPE under broad demeaning + the shipped
  PER-SIDE COST ACCOUNTING** (turnover Σ|w−prevW-as-set|, charge rt/2 per one-way unit), re-implemented and pinned by
  selfcheck to fixture anchors computed from the verbatim-compiled Swift source (weights + a full costed rebalance step,
  12dp; the audit re-derived the anchors BY HAND from the Swift algorithm: weights −1/62, −1/62, −29/62, +1/2).
  **Claim scope (audit F4):** the fixture pins the weight shape and cost accounting ONLY — the signal here is a
  price-ratio and blocks are open-to-open compound returns (the prereg's stated panel-adapted mechanics), whereas the
  Swift sim's hold convention is additive on a returns matrix. "Verbatim shipped construction" beyond weights+costing is
  not claimed.
- Signal r_lb = adjc[p]/adjc[p−lb]−1 (endpoints must be valid prints); w ∝ −(r_lb − mean), L1 gross 1 (long losers /
  short winners). Grid lb∈{5,10,21,63} × hold∈{5,10,21}; entry open[p+1]; exit = last valid print ≤ p+1+hold.
- Scopes with SCOPE-MATCHED ratified cost tiers: FULL @13bps RT, LOW-LIQUIDITY tercile @60bps RT (the ratified small/EM
  tier — 13bps is not a defensible assumption for $1–4M-ADV names); the alternate tier printed as sensitivity.
- 24 decision arms; trials = 24 + 98 prior reversal-irrx family arms = 122 (registry print 725); varTrialSharpe floored
  at 0.0343 (binding — observed 0.0036); sensitivity legs S1 REVERSED / S2a winsorized / S2b no-screen / S3
  long-leg-only implementability / S4 Shumway −30% on delisting-truncated exits; symmetric negative pre-commitment.
- Panel: 5,135 clean names (+249 screened), 2000-01-03→2026-07-09, 6,668 master bars; eligible cross-sections ~2,100+.

## Results (24 arms; net at the scope's ratified tier; cost does NOT cancel here — this is a net-of-cost test)

| arm | nblk | gross_mu | net_mu | t | DSR122 | S2a | S1 | negDSR | turnover |
|---|---|---|---|---|---|---|---|---|---|
| lb5/hd5/FULL | 1320 | +0.00174 | +0.00078 | 1.74 | 0.000 | 0.000 | N | 0.000 | 1.46 |
| lb5/hd5/LOWLIQ | 1320 | +0.00197 | −0.00246 | −4.15 | 0.000 | 0.000 | Y | 0.072 | 1.47 |
| lb5/hd10/FULL | 660 | +0.00253 | +0.00158 | 2.21 | 0.030 | 0.015 | N | 0.000 | 1.46 |
| lb5/hd10/LOWLIQ | 660 | +0.00291 | −0.00152 | −1.60 | 0.000 | 0.000 | Y | 0.009 | 1.48 |
| lb5/hd21/FULL | 314 | +0.00157 | +0.00063 | 0.40 | 0.007 | 0.005 | N | 0.001 | 1.45 |
| lb5/hd21/LOWLIQ | 314 | +0.00115 | −0.00331 | −1.78 | 0.000 | 0.000 | Y | 0.163 | 1.49 |
| lb10/hd5/FULL | 1320 | +0.00171 | +0.00105 | 2.51 | 0.000 | 0.000 | N | 0.000 | 1.02 |
| lb10/hd5/LOWLIQ | 1320 | +0.00214 | −0.00097 | −1.88 | 0.000 | 0.000 | Y | 0.000 | 1.04 |
| lb10/hd10/FULL | 660 | +0.00179 | +0.00085 | 1.15 | 0.002 | 0.000 | N | 0.000 | 1.46 |
| lb10/hd10/LOWLIQ | 660 | +0.00253 | −0.00189 | −2.19 | 0.000 | 0.000 | Y | 0.040 | 1.47 |
| lb10/hd21/FULL | 314 | +0.00182 | +0.00088 | 0.52 | 0.010 | 0.004 | N | 0.000 | 1.44 |
| lb10/hd21/LOWLIQ | 314 | +0.00157 | −0.00285 | −1.41 | 0.000 | 0.000 | Y | 0.107 | 1.47 |
| lb21/hd5/FULL | 1320 | +0.00102 | +0.00057 | 1.31 | 0.000 | 0.000 | N | 0.000 | 0.69 |
| lb21/hd5/LOWLIQ | 1320 | +0.00128 | −0.00087 | −1.66 | 0.000 | 0.000 | Y | 0.000 | 0.72 |
| lb21/hd10/FULL | 660 | +0.00117 | +0.00053 | 0.72 | 0.000 | 0.000 | N | 0.000 | 0.99 |
| lb21/hd10/LOWLIQ | 660 | +0.00172 | −0.00133 | −1.47 | 0.000 | 0.000 | Y | 0.007 | 1.02 |
| lb21/hd21/FULL | 314 | +0.00173 | +0.00079 | 0.42 | 0.008 | 0.003 | N | 0.001 | 1.45 |
| lb21/hd21/LOWLIQ | 314 | +0.00107 | −0.00336 | −1.44 | 0.000 | 0.000 | Y | 0.103 | 1.48 |
| lb63/hd5/FULL | 1320 | +0.00008 | −0.00018 | −0.28 | 0.000 | 0.000 | Y | 0.000 | 0.39 |
| lb63/hd5/LOWLIQ | 1320 | +0.00055 | −0.00074 | −1.39 | 0.000 | 0.000 | Y | 0.000 | 0.43 |
| lb63/hd10/FULL | 660 | −0.00052 | −0.00088 | −0.72 | 0.000 | 0.000 | Y | 0.000 | 0.56 |
| lb63/hd10/LOWLIQ | 660 | −0.00011 | −0.00194 | −2.02 | 0.000 | 0.000 | Y | 0.029 | 0.61 |
| lb63/hd21/FULL | 314 | −0.00088 | −0.00141 | −0.68 | 0.000 | 0.000 | Y | 0.021 | 0.82 |
| lb63/hd21/LOWLIQ | 314 | −0.00222 | −0.00489 | −1.91 | 0.000 | 0.000 | Y | 0.202 | 0.89 |

- **Decision rule (closed 24-arm set): 0 passing; 0 negative flags.**
- **The FULL-scope short-hold positivity is point-positive, tail-concentrated, artifact-exposed, deflation-dead (audit
  F11 — "gross reversal exists here" is NOT licensed):** (a) gross figures are MEANS ONLY — the prereg-promised gross
  t/DSR were never computed (deviation, disclosed below); (b) best arm lb5/hd10/FULL net +15.8bp/block t 2.21 reaches
  only **DSR 0.030** (bench 0.156 before the binding variance floor; floor-DSR ≈ 0), and its winsorized S2a HALVES to
  0.015 — with net skew +1.1…+3.2, a material share of the mean rides on >100% single-name bounce blocks
  (halt-reopens/buyouts/squeezes: the least retail-capturable, most artifact-prone returns in the panel); (c) block
  returns are TWO raw open prints on thin names; (d) no twin/share-class dedup exists in the prep; (e) these arms FAIL
  S1 sign-agreement anyway; (f) t ≤ 2.51 across a 24-arm grid against a 122-trial history is what noise + selection
  produces. Short lookbacks point-positive, lb63 flat-to-negative (consistent with the known ≤1mo reversal horizon).
- **The LOWLIQ result is COST-MODEL-DOMINATED — the sign spans the plausible cost range; at the defensible tier it is
  decisively net-negative** (audit F12, arithmetically exact: net = gross − turnover·rt/2 verified as an identity). At a
  counterfactual 13bps the LOWLIQ short-lookback arms show positive MEANS (+10 to +20bp/block — sensitivity print only,
  NO t/DSR computed, no significance may be attached; and 13bps is the ratified LARGE-CAP tier, indefensible for
  bottom-tercile-liquidity names); at the ratified 60bps band-bottom ALL TWELVE are net-negative (−7.4 to −48.9bp/block,
  t to −4.15). Charging large-cap costs on $1–4M-ADV names is the exact dangerous-direction error the cost-table
  ratification exists to prevent — the gate refusing here is the system working. Note the −4.15 t correctly did NOT
  trigger the symmetric negative flag (neg DSR ≤ 0.202) — the deflation bar applies symmetrically, per the
  pre-commitment.
- S4 (Shumway) leaves every LOWLIQ arm negative (s4 net means −7.6 to −48.1bp/block) — the null does not depend on
  delisting treatment.
- **S3 long-leg-only prints are UN-BENCHMARKED beta, not evidence — never present them as a standalone result**: the
  long-losers book's positive net means (+0.35%…+2.1%/block, t up to 4.3) carry 26 years of (micro-cap) equity beta with
  NO EQW subtraction, NO DSR, NO deflation by construction; S3 exists ONLY as an implementability conjunct for a passing
  arm (none passed — audit-confirmed it can only veto, never qualify). Any "long losers earns 2%/block at t=4" reading
  is false as an edge claim and forbidden.
- **Recorded protocol deviations (audit; all decision-inert, direction-safe):** (1) **S2b ran no-screen but
  UN-winsorized**, contra the prereg's "no-screen + winsorized" — unwinsorized screened-name jumps fatten tails and
  DEPRESS DSR, so the deviation TIGHTENS both the pass veto and the negative flag (anti-claim in both directions);
  runner fixed post-run for future use. (2) The prereg-promised GROSS t/DSR were never computed (gross means only —
  hence the point-positive-only framing above). (3) The screened-name census print is missing from this runner's log
  (recoverable from the sibling run — identical prep; the gap=249 / screened=249 coincidence was audit-verified as
  independent counters, census arithmetic closing exactly).
- Delisting-truncation booking was again load-bearing: ~1,021–1,042 truncated-delisting name-blocks per LOWLIQ arm.

## What this run did NOT establish
- Nothing about industry-relative (full-IRRX) reversal at this breadth — the panel has no industry metadata; the demean
  is broad. (The 61-name full-IRRX test with populated earnings exclusions was closed NULL 2026-07-09.)
- No borrow costs on the short leg (gross-favorable simplification, stated in the prereg) — any would-be pass was
  already an upper bound; for a null it is conservative.
- The FULL-scope positive-gross observation is not promotable evidence of anything: DSR ≤0.030 at honest trials, S2a
  halves it, and the two-point open-to-open block basis + twin-listing residuals apply as in the sibling run.

## Verification (pre-registered 2-lens bar)
- **Lens A (code audit, conjunct-by-conjunct): NOT-REFUTED — "the printed NULL stands; no decision-bearing conjunct is
  broken; all statistics recompute bit-exact from the artifacts."** Verified: look-ahead clean (signal endpoints ≤ p,
  as-of liquidity terciles honoring the collider fix, raw-open mask with no fallback, prevW ordering with full first-
  rebalance turnover; NO market series exists in this runner so the sibling's F1 class is structurally impossible);
  turnover/cost accounting exact and Swift-consistent (net = gross − turnover·rt/2 reproduced as a bit-exact identity,
  incl. the alt-tier prints; turnover monotone in lb — the Σ|Δw| signature, not naive liquidation); fixture anchors
  re-derived BY HAND from the Swift source (−1/62, −1/62, −29/62, +1/2); statistics bit-exact (varTrialSharpe
  0.0036095028948440215; bench122 0.15619317847603645; floor 0.0343 BINDING via the coded dsrflr conjunct; four arms'
  DSR/negDSR reproduced to full precision); closed 24-arm set; ledger 24 records run `67749d7`, 5 arms spot-checked
  bit-exact; prereg-before-stats timeline confirmed by git (15:02:46 → 15:37:12 → run at 15:44 HEAD → results 16:02);
  the imported machinery is the post-audit-fix version of the sibling module. Findings: the S2b deviation, gross-stats
  under-delivery, and census-print omission recorded above (all direction-safe); interpretive mandates F11/F12 applied
  throughout this file.
- **Lens B (independent re-implementation from the prereg text): reproduction PASS on all 3 checks.**
  (1) Full arms lb10/hd5/FULL and lb5/hd5/LOWLIQ: n_blocks 1320/1320 ✓, gross_mean/net_mean |Δ| ≤ 8.7e−19, net_t
  bit-exact / |Δ| ≤ 8.9e−16, mean_turnover exact, first-rebalance cross-sections reproduced (2,193 eligible; 731 LOWLIQ);
  clean set 5,135 reproduced exactly. (2) Weight-shape fixture: max|Δw| 1.3e−13 vs the Swift-derived anchors; costed
  rebalance gross/net Δ 3.2e−14. (3) DSR spot-check: varTrialSharpe bit-exact; bench122/dsr_122 to ~2e−10 (verifier's
  own Φ⁻¹ implementation — method-precision agreement). Script + log preserved in the session scratchpad
  (`indep_reversal.py`, 247s). Bonus finding from its interpretation-variant sweep: the integrity screen's
  "21-bar span" oscillation clause is ambiguous by ±1 bar between readings — BOTH readings produce the IDENTICAL
  5,135-name panel here (the oscillation rule is a rare secondary trigger vs the 8× primary), so the ambiguity is
  measured-immaterial; future preregs should pin the ratio-position convention explicitly.

## Engine mapping
**No engine change; the fences STAND and are now maximally evidenced**: RefuseList naive-reversal (anti-edge #1) has been
re-confirmed on survivor-free data spanning the era when the effect was strongest; the `.SR`/EM 60bps tier and the
cost-gate's refuse-first posture are what kept this from ever reaching the owner as a fake candidate. Trials ledger:
+24 arms, family `reversal-survfree`.

## Artifacts
Runner + prereg: `tools/eodhd_panel/{survfree_reversal.py, PREREG_2026-07-10_survfree_reversal.md}`. Results + log:
`~/.claude/salehman-universe/panels/eodhd_us_delisted/{survfree_reversal_results.json, reversal_run1.log}`. Panel frozen
`5ce314475941a0cd`.
