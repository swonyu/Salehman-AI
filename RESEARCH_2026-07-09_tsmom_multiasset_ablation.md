# RESEARCH 2026-07-09 — standalone multi-asset TSMOM ablation (net-of-cost, DSR-gated, EQW-diff-guarded) — NULL

**Question.** The last untested canonical signal family: does standalone time-series momentum (the shipped 12-1 `timeSeriesMomentum`/`trendOK` construction) deliver a net-of-cost DSR>0.95 edge on its natural **multi-asset** substrate — the cross-asset ETF universe where Moskowitz-Ooi-Pedersen (JFE 2012) found gross Sharpe ~1.1 — or does the price-only NULL wall extend cross-asset? Prior: the corpus's own MOP cite (`RESEARCH_2026-06-27_quant_engine_II.md` §TSMOM, incl. ">12mo lookbacks invert") and its Huang-Li-Wang-Zhou (JFE 2020) cite contesting TSMOM's pooled-t construction. TSMOM ships ONLY as an equity entry *filter* (iter3); no prior corpus panel was cross-asset.

**Verdict: NULL — not promoted. 0/54 configs clear the honest bar (absolute DSR>0.95 AND EQW paired-diff). Every one of the 54 configs has NEGATIVE mean net difference vs simply holding the equal-weight basket** — on 2016–2026 multi-asset ETFs, every tested TSMOM overlay subtracted net value versus buy-and-hold. Two configs clear the absolute DSR (LF lb=252 hd=42: 0.964 @rt13, 0.965 @rt8) and both are **beta artifacts by construction-guard**: their EQW paired-diff mean is negative with diffDSR = 0.000 — the exact bull-beta trap the momentum-sign precedent documented, caught here by the mandatory guard.

## Method (ablation-harness Path B; momsign-precedent architecture)

- **Panel:** 16 liquid multi-asset ETFs × 2,512 daily simple returns (2016-07-11 → 2026-07-09, Yahoo v8 adjclose — dividend-adjusted, mandatory for bond ETFs), 6 asset classes. Universe FROZEN before data was seen (recipe step 1): SPY QQQ IWM · EFA EEM · TLT IEF LQD HYG · GLD SLV DBC USO · VNQ · UUP FXE. Split-leak guard: max |1-day move| per name ≤ 0.285 (SLV), no unexplained >0.5 jumps. Fetcher + panel persisted: `tools/tsmom_multiasset/fetch_panel.py`, `panel_tsmom_multiasset.json`.
- **Machinery:** verbatim shipped `StockSageNetCostSim` + `StockSageDeflatedSharpe` compiled from repo source (`tools/tsmom_multiasset/build_and_run.sh`, momsign/altdata pattern — zero port risk on stats/costing). Generic weight-loop = byte-for-byte the shipped `rebalanceSeries` statement order; **port-validated 9/9 EXACT-EQUAL** against the shipped loop via shipped `irrxWeights` on this panel. Signal spot-check hand-derived independently in Python: **6/6 values match to 10dp** (SPY/TLT/GLD mom + vol63 at t=252).
- **Signal:** mom_i(t) = Π(1+r_iu)−1 over u ∈ [t−lb, t−21) — by the price-ratio identity, byte-equivalent in sign to shipped `trendOK` (`StockSageIndicators.swift` `timeSeriesMomentum`, skipRecent=21). Data strictly < t; fills over [t, t+hold).
- **Arms:** LF long/flat (w=1/16 if mom>0 else 0 — fixed slots so the book de-levers in downtrends, the crash-filter mechanism under test); LS long-short sign (±1/16; **no borrow/financing charged — gross-favorable**); VS MOP-faithful vol-scaled (sign·min(2, 0.40/σ63)/16).
- **Sweep:** lb ∈ {63,126,252} × hold ∈ {21,42,63} × rt ∈ {13,8}bps × 3 arms = **54 trials**; DSR primary accounting trials=54 with varTrialSharpe = V54 = 0.0166 (sample variance of the 54 full-series net Sharpes); sensitivity trials=27 per cost leg; walk-forward pooled-OOS verdicts (folds=3, embargo=1). DSR preflight: edge→0.99999 ≥0.95, noise→0.6905 <0.95.
- **Guards:** EQW always-long paired-diff per config (diff series → shipped verdict — the alpha test); LF exposure diagnostic; REVERSED=1 walk-backward; trials-ledger append (72 arms: 54 trial + 18 EQW benchmark, run `2026-07-09_tsmom_multiasset_v1`).

## Results (full table in `tools/tsmom_multiasset/run_output_2026-07-09.txt`; all figures NET unless labeled GROSS)

| Arm | Best config | Best abs net-OOS DSR54 | Clears | EQW-diff mean(d) | diffDSR | Verdict |
|---|---|---|---|---|---|---|
| LF (long/flat, shipped-filter semantics) | lb=252 hd=42 rt=8 | **0.965** | YES | **−0.0070/rebal** | 0.000 | **BETA ARTIFACT — refused** |
| LS (long-short sign) | lb=63 hd=42 rt=8 | 0.321 | no | −0.0099 | 0.000 | null |
| VS (MOP vol-scaled) | lb=126 hd=63 rt=8 | 0.369 | no | −0.0083 | 0.007 | null |

- **The decisive row is the guard column:** mean(netArm − netEQW) < 0 for **54/54 configs**; max diffDSR anywhere = 0.007. No TSMOM overlay beat holding the basket, in any arm, lookback, hold, or cost tier.
- LF absolute near-misses are pure bull-beta at ~0.6 exposure: LF held ~59–66% invested (exposure diagnostic) and the timing forfeited more 2016–2026 upside than the 2020/2022 downside it dodged — the same regime-dependent-defense shape as the low-beta/IVOL and momentum-crash nulls.
- LS decays with lookback at long holds (lb=252 hd=63 **negative even GROSS**: −0.035%/rebal) — consistent with MOP's own ">12-month lookbacks invert."
- **Registry-informed deflation** (trial-registry standing note): best config re-gated at trials=362 (54 + 308 census) → DSR 0.901. The near-miss shrinks further against honest selection history.
- **REVERSED (walk-backward):** 1/27 sign-flips, on an already-null LS config (inert per the interpretation guide); the LF near-miss configs hold sign in both directions — no evidence the (refused) positive was temporal-order fit.

## Adversarial verification (3 independent lenses, workflow wf_092516b0-26f — ALL NOT-REFUTED)
1. **Independent reproduction:** runner source sha-matched, recompiled from a copy with the canonical swiftc line, re-run → stdout **byte-identical** to the persisted output (mod the LEDGER line, absent with the ledger off); every headline number verbatim.
2. **Independent re-implementation:** arm LF lb=252 hd=21 rt=13 re-implemented in Python from the raw panel JSON, with the stated accounting first re-verified against the SHIPPED `rebalanceSeries` source → **bit-exact to 16+ significant digits** (meanNetPct 0.5115307618157727, Sharpe 0.22012513841424372, both = ledger values exactly). Structural note (disclosed in Method): TSMOM arm weights execute through the runner-local generic loop (itself port-validated 9/9 bit-exact vs the shipped loop), not through a shipped weight function — the shipped code has no TSMOM weight rule to call.
3. **Look-ahead audit + mutation probe:** audit clean — max index read at decision time t is t−22 (tsmom) / t−1 (vol63), forward window matches shipped; both mutants changed results materially and the true 1-bar leak IMPROVED the headline vs the original (0.989 vs 0.965 at the near-miss cell) — the harness demonstrably rewards leaks, so the original's null is not a dead-pipeline artifact. **Probe observation (recorded honestly, NOT evidence):** the no-skip mutant (legit construction, momentum through t−1 with the 12-1 skip removed) improved the absolute headline more than the leak did (0.991, 4 absolute clears) — recent-month cross-asset momentum is a plausible pre-registered FUTURE variant; as a post-hoc, in-sample, absolute-DSR-only diagnostic it promotes nothing and remains subject to the same EQW guard that killed this run's near-misses.

## What this closes / engine mapping
- **TSMOM-standalone as an edge candidate is closed NULL — including on its natural cross-asset substrate.** The single-signal search space (11 equity candidates + sign space + IRRX + TOM + seasonality + now cross-asset TSMOM) is comprehensively negative net-of-cost at retail on real data.
- **The shipped `trendOK` filter is NOT invalidated:** it ships as a veto inside a stock-selection pipeline (near-zero added turnover), not a standalone overlay; this run measured the overlay form. No engine change; nothing wired; fences stand.
- Consistent with (not merely assuming) the post-publication decay literature: the corpus's McLean-Pontiff/Huang-et-al. cites predicted exactly this current-era outcome; now it is measured on this book's own machinery.

## What this round did NOT establish
- NOT a test of futures-implemented TSMOM (MOP's substrate: 58 futures with embedded leverage/term structure; ETF proxies carry roll drag — USO — and no leverage). The published-era futures result is untouched.
- LS/VS short legs charged NO borrow/financing — their true net is WORSE than shown (safe direction: they already fail).
- One decade, one vendor, survivor-lite wrappers; the 2022 simultaneous stock-bond bear is in-window but a 2000-03/2008-class slow crash is not.
- Does NOT measure `trendOK`'s incremental value inside the shipped pipeline (filter-on vs filter-off through the app's own backtester) — that is a different, in-app experiment.
- The 40%-target/2×-cap VS parameterization is one point in MOP's family, not a sweep.

## Artifacts
`tools/tsmom_multiasset/{fetch_panel.py, panel_tsmom_multiasset.json, main.swift, build_and_run.sh, run_output_2026-07-09.txt}` · trials ledger run `2026-07-09_tsmom_multiasset_v1` (72 arms) · this file.

---

## UPDATE 2026-07-09 (late — PRE-REGISTERED no-skip variant: the probe observation, closed NULL)

The verify probe's observation (no-skip construction beat the leak mutant) was run down the same night as a **pre-registered** variant — `tools/tsmom_multiasset/PREREG_2026-07-09_noskip.md`, written before any variant number was computed, post-hoc origin disclosed, decision rule committed in advance.

**Design:** identical frozen panel, arms, and grid; SKIP=0 via env (`TSMOM_SKIP`; default 21 regression-gated **byte-identical** to the parent run's stdout before the variant ran). **Trials accounting pays for the parent run's selection: trials=108** (54 prior + 54 new arms), varTrialSharpe pooled over all 108 full-series net Sharpes (V108=0.0157, prior Sharpes read from the ledger).

**Result — NULL by the committed rule.** Best absolute net-OOS DSR108 = **0.969** (LF lb=252 hd=42 rt=8 — the same cell as the parent near-miss); 2 absolute clears, **both beta artifacts** (mean(netArm−netEQW) ≤ 0, diffDSR = 0.000); **"clears absolute AND EQW paired-diff: NO"** across all 54 variant configs. Removing the skip did lift the momentum family broadly (best LS 0.398, best VS 0.422 — both above their skip-21 siblings, still deep null), but nothing beats holding the basket. Registry-informed deflation (trials=416): best 0.935 — below the bar even absolute. REVERSED: 2/27 flips, both on null LS/VS lb252/hd63 cells (inert); the near-miss LF cell holds sign. Internal consistency: pass-A vs final rows identical mod trials-dependent columns. Ledger: 72 arms appended, run `2026-07-09_tsmom_noskip_v1`, configs suffixed `,skip=0`.

**Verification (proportionate — machinery unchanged from the 3/3-verified parent):** default-behavior regression gate byte-identical; independent recompile+rerun of the variant + env-plumbing diff audit + Python spot-recompute by a background verifier — **NOT-REFUTED**: the git diff contains exactly the four intended change groups (env plumbing, print interpolation, vPrimary substitution, ledger skip-suffix) with defaults collapsing to the parent's literals; SKIP=0 no-look-ahead re-confirmed (max signal index t−1, forward window disjoint); reproduction stdout **byte-identical** (126/126 lines, cmp clean, mod the LEDGER line); Python recompute of LF skip=0 lb=252 hd=21 rt=13: meanNetPct 0.5120560754508485 = ledger value exactly (diff 0), Sharpe 0.2572309469473370 vs ledger to one ulp (5.6e-17).

**Disposition:** the probe observation is closed — recent-month-inclusive cross-asset momentum is ALSO dominated by the EQW basket net-of-cost on this decade. The TSMOM family (12-1 AND no-skip, long/flat, long-short, vol-scaled) is closed NULL on the multi-asset substrate. Nothing wired; fences stand. Artifacts: `PREREG_2026-07-09_noskip.md`, `run_output_2026-07-09_noskip.txt`, ledger run `2026-07-09_tsmom_noskip_v1`.
