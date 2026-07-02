# AUDIT — StockSage money-pipeline math red-team (2026-07-03)

**Author:** Opus 4.8 xhigh parallel session (Opus lane, task **O1**), issued by the Fable 5 orchestrator.
**Type:** READ-ONLY adversarial audit. **No fixes applied** — this report is findings only; Fable turns confirmed discrepancies into plans and routes owner-gated items to the owner.
**Method provenance:** workflow `wf_7efb09c2-fe1` — 13 formula-family audit agents (Opus, effort xhigh), each re-deriving every formula from first principles and checking the Swift against its research citation; every claimed discrepancy then routed through an independent adversarial refute-verifier (default-refute under uncertainty). 23 agents, ~1.79M tokens, 281 tool calls, ~11 min. **The 3 surviving discrepancies were additionally re-verified by the Opus main loop against the actual source lines** (cited below) per `incident-ledger` IL-15 (independently re-derive an auditor's claim before trusting it) and the `opus-operating` gate 2 (the code is the fact, not any narration).

## Scope
Every formula in the StockSage money pipeline: Kelly sizing, Platt/isotonic/Beta calibration + the OOS candidate-selector, TSMOM variance scaling & regime, EV/win-prob, NetEdge round-trip costs, Deflated Sharpe/PSR, correlation/cluster/heat, Monte-Carlo ruin & drawdown, vol-regime brake, return-shape/vol-stability honesty reads, and the walk-forward backtester. Read against `research/INDEX.md`, the `RESEARCH_*.md` detail files, `EDGE_RESEARCH.md`, and `research/RESEARCH_CORPUS_DIGEST.md`.

## Honesty-floor lens (the audit's primary severity rule)
The engine's own contract: `nil`=unknown never fabricated; conviction is signal-strength, **not** a probability; win-prob only from realized-trade calibration; gross vs net always distinguished; **Deflated Sharpe ≈ 0 — no proven alpha, the value is risk discipline.** A formula that **overstates confidence** is at least HIGH severity regardless of magnitude. A wrong number that is **unreachable in a shipped path** is severity-bounded by that unreachability.

---

## Executive summary

| | Count |
|---|---|
| Formulas examined | **129** across 13 families |
| Confirmed-CORRECT | **126** |
| Discrepancies surviving adversarial verify + Opus re-verification | **3** (1 HIGH, 1 MEDIUM, 1 LOW) |
| Candidate discrepancies raised then **refuted** | 7 |

**Bottom line:** the core money math is sound. Kelly (`f* = W − (1−W)/R`, half-Kelly ×0.5, cap 0.20), EV in R, break-even `p* = 1/(1+netRR)`, Platt MLE, Deflated Sharpe/PSR (Bailey–López de Prado form incl. skew/kurtosis and the Gumbel expected-max deflation), date-aligned Pearson/cluster correlation, TSMOM variance scaling (`min(1, targetVol/realizedVol)`), and the vol-regime/return-shape honesty reads all re-derived correctly. The 3 surviving defects are **narrow and mostly latent**: one real honesty-floor asymmetry in a Beta-calibration fallback branch (HIGH, but masked on the production path by the OOS selector), one dead-code cost unit trap (already logged), and one crash-on-degenerate-input robustness gap in a public API (not production-reachable). **None currently corrupts a shipped, user-facing number.**

---

## §1 — Confirmed discrepancies (3)

### D-1 · HIGH · Beta calibration drop-and-refit omits the intercept re-anchor
- **Location:** `Salehman AI/StockSage/StockSageConvictionCalibration.swift:440-448` (`fitBeta`, the `.dropA` branch :442-443 and the symmetric `.dropB` branch :446-447).
- **Citation:** Kull et al. 2017 (Beta-3param); the module's own Platt path documents the exact guard it should mirror (:229-237).
- **Independent derivation (re-verified against source):** the Beta map is `μ = σ(c + a·ln s + b·(−ln(1−s)))`; monotonicity in conviction requires `a ≥ 0 ∧ b ≥ 0`. On an inverted/noisy sample the full IRLS fit can land `a0 < 0`, triggering the drop-A branch, which refits `x2`-only via `irls(includeX1:false, includeX2:true)` → `(c1, _, b1)` (a **joint** 2-param fit; `c1` is co-fitted *with* the slope `b1`). It then returns `BetaCalibration(a: 0, b: max(0, b1), c: c1, .dropA)`. When `b1 < 0`, `max(0, b1) = 0` and `winProb` (:313, `.dropA` ⇒ `z = c + b·x2`) **collapses to a flat map at `σ(c1)`** — but `c1` is the intercept of a *downward* line evaluated at `x2=0`, so it sits **above** the sample base-rate log-odds ⇒ `σ(c1) > base rate` = **overstated win-prob for every conviction band.**
- **Mechanism (one cause, explains both branches):** the surviving-slope clamp `max(0, ·)` is applied without re-anchoring `c` to the intercept-only MLE. The sibling `.interceptOnly` branch (:436-439) does this correctly via `irls(false, false)` ⇒ `c* = ln((nNeg+1)/(nPos+1))` = honest base rate; and the **Platt path guards this identical failure explicitly** (:234-237: *"when A is clamped, also re-anchor B to the smoothed prior log-odds … Leaving B at the Newton-converged value … produces a flat sigmoid far above the true base rate — e.g. 88.5% vs 50% … inflates Kelly EV"*). The Beta drop branches are the one place this re-anchor is missing.
- **Failing input (constructible):** a symmetric inverted ~50/50 sample where high-conviction trades lose → `a0<0`, drop-A refit `b1<0` → emits flat `σ(c1) > 0.5` on a genuinely coin-flip strategy; the honest intercept-only MLE would give `σ(0)=0.5`. Overstatement feeds half-Kelly ⇒ material over-bet.
- **Reachability / mitigation (honestly bounded):** the **standard production route** `fit(…) → selectCalibration` OOS-Brier-compares Beta against the identity floor (:578-595); a flat-overstated map scores worse OOS than identity, so identity wins and the bad map is **discarded** — this masks the standard path. **Residual live exposure is real but narrow:** (a) `fitBeta` is `nonisolated static` (**not** `private`, :325), so any direct caller bypasses the selector; (b) the selector's winner is refit on **full data** at :600 (`fitBeta(outcomes)`) and returned **without re-scoring**, so a full-data refit that lands in the buggy branch ships un-revalidated.
- **Severity rationale:** HIGH per the honesty-floor rule (a confidence-**overstating** map). Practical blast radius alone would argue MEDIUM (selector masks the standard path); the honesty-floor rule floors it at HIGH. Survived adversarial verification and Opus source re-verification.
- **For Fable (no fix here):** the remediation shape is "re-anchor `c` when the surviving slope clamps to 0" (mirror `.interceptOnly` / the Platt B-reset). Touches engine math → **owner/Fable routing** per `opus-operating` (any calibration-semantics change is not an Opus-solo edit).

### D-2 · MEDIUM (latent; LOW live impact) · `allInCost` charges the taker fee twice vs `evaluate`/`roundTripBps`
- **Location:** `Salehman AI/StockSage/StockSageNetEdge.swift:82` (`allInCost`, `takerFeeCost: e * 2 * max(0, takerFeeBps) / 10_000`) vs `evaluate` :145 and `CostAssumption.roundTripBps` :62.
- **Independent derivation (re-verified against source):** `evaluate` (:145) computes `cost = max(0, spreadBps + slippageBps + takerFeeBps)/10_000 · entry` — taker summed **once**; `roundTripBps` (:62) = `spread + slippage + taker` — **once**. But `allInCost` (:82) multiplies taker by **2** ("both fills"). The module's own crypto default (:89) is `takerFeeBps: 20` labeled `// 70bps incl. ~0.1%/fill taker`: `30+20+20 = 70` matches the label ⇒ **20 already encodes the round-trip total.** Feeding that same 20 into `allInCost`'s ×2 yields taker = 40 bps ⇒ total **90 bps vs the labeled 70** (+29%). The two surfaces disagree on whether `takerFeeBps` is per-fill or round-trip.
- **Reachability:** **dead code.** `git grep allInCost|AllInCost|dominantLeg` → references only in `StockSageNetEdgeTests.swift` + the definition; every live path (`StockSageCapitalAllocator`, `StockSageExpectedValue`, `MarketsView`, `netRR`) routes through `evaluate`/`roundTripBps`, never `allInCost`. **No shipped number is affected.**
- **Already tracked:** `DEVELOPMENT_LOG.md:8554/8574` logs this as **"#3 takerFeeBps dead-code unit trap (low)"** — this audit **re-confirms a known, still-unresolved latent trap**, it is not a new discovery.
- **Severity rationale:** MEDIUM if `allInCost.total`/`.dominantLeg` were ever wired into a cost display (would disagree with the ranking path by +20 bps on crypto); LOW live impact today (unreachable). Does **not** trip the "overstates confidence → HIGH" rule because the overstatement cannot reach any live path.
- **For Fable:** unify the convention (drop the ×2 in `allInCost`, or make `defaultCosts` express per-fill and apply ×2 uniformly across `evaluate`+`roundTripBps`) *if/when* `allInCost` is ever wired in; otherwise the existing log note stands.

### D-3 · LOW · `MonteCarloRuin.simulate` can modulo-by-zero on degenerate input
- **Location:** `Salehman AI/StockSage/StockSageMonteCarloRuin.swift:40` (guard) → `:42` (`n = rs.count`) → `:49` (`rs[Int(rng.next() % UInt64(n))]`).
- **Independent derivation (re-verified against source):** line 49 requires `n ≥ 1` (Swift integer `% 0` traps). The guard at :40 is `rs.count >= minTrades, riskFraction > 0, horizon > 0, sims > 0` — it only implies `n ≥ 1` when `minTrades ≥ 1`. `minTrades` is a caller-controllable parameter (default **20**, :38).
- **Failing input:** `simulate([], riskFraction: 0.1, horizon: 10, sims: 100, minTrades: 0)` → `rs.count = 0`, guard `0 >= 0` passes, other conjuncts pass → `:49` executes `% UInt64(0)` → runtime division-by-zero trap.
- **Reachability:** **not production-reachable.** The sole production call site uses the default `minTrades: 20` ⇒ `n ≥ 20 ≥ 1`. This is a latent robustness defect in a public static API.
- **Severity rationale:** LOW — it is a **crash on degenerate input, never a wrong-but-plausible ruin/drawdown number**, so it does not overstate any risk figure and does not breach the honesty floor.
- **For Fable:** trivial hardening if desired — `guard rs.count >= max(1, minTrades)` or add `!rs.isEmpty`. Not urgent (unreachable).

---

## §2 — Candidate discrepancies raised then refuted (7)

Each was independently re-derived by an adversarial verifier and found **not to be a math error**. Documented here so Fable sees the full coverage, plus the residual (non-discrepancy) observation each leaves behind.

| # | Family | Claim | Why refuted | Residual observation (not a discrepancy) |
|---|---|---|---|---|
| R-1 | calib_isotonic | The `isotonicMinSamples=1000` gate doesn't block isotonic below 1000 | Correct by design: with `candidateSelectorEnabled=true` (prod), the OOS-Brier selector supersedes the hard gate (research-mandated; `research/INDEX.md` iter7). Isotonic only wins when it beats identity OOS by a strict margin; Wilson-LCB haircut + identity floor keep it conservative. No wrong number. | **Stale comment** at `StockSageConvictionCalibration.swift:69/71` ("almost always takes the Platt branch") describes the flag-OFF seam. Doc nit; cf. IL-20 (source wins over docs). |
| R-2 | calib_beta | IRLS has no step-damping/separation detection → coefficients blow to ~1e5 | On (quasi-)separable data the logistic MLE **genuinely lives at infinity**; a saturating sigmoid is converging *toward* the MLE, not diverging. Outputs stay finite/clamped; monotonicity enforced by drop-and-refit; the selector discards an overfit Beta OOS. | Step-halving would be a stylistic nicety, not a fix. No spec (Kull 2017) promises a penalized fit. |
| R-3 | calib_selector | `fit(fromBacktest:dates:)` positional split leaks when `dates=[]` | **Production always supplies dates** (`StockSageStore.swift:736` passes `tradeDates`, 1:1-aligned) → the chronological sort fires → genuine future-holdout. `fromJournal` also sorts unconditionally. | Latent **defensive-coding footgun** on the default param for a hypothetical future caller that omits `dates`. Not a live leak. |
| R-4 | tsmom_regime | `trending = er >= 0.30` mislabels the threshold | `er` **is** the Kaufman Efficiency Ratio (`\|net\| / path`, ∈[0,1]); thresholding it at 0.30 is a legitimate dimensionless meta-rule (corroborated by `MARKETS_INTELLIGENCE_RESEARCH.md` §4). Boolean is byte-correct. | **Comment/citation error** at `StockSageAdvisor.swift:169` — calls the ER a "30% trailing excess return" and cites Jegadeesh-Titman 1993 (unrelated cross-sectional momentum). Zero runtime impact; could mislead a future maintainer. |
| R-5 | backtester | walk-forward has no purge/embargo between folds | Not future look-ahead: `foldRanges` tiles `[warmup, n)` with **disjoint** trade windows (verified fold-index math); the warmup prefix is read-only history the docstring discloses. Purge is an ML-labeling step for a *trained* model — `advise()` fits no per-fold model, so purge is inapplicable. | Research (`RESEARCH_2026-06-26_quant_engine.md:33`) lists purge+embargo as a **roadmap upgrade** (CPCV engine), not a correction of the existing walk-forward. Adjacent folds are serially correlated → "out-of-sample stability" is a slightly optimistic phrase. |
| R-6 | backtester | walk-forward "drops costs/exitMode/benchmark" per fold (gross-vs-net gap) | `walkForward(_:warmup:folds:)` has **no** costs/exit/benchmark params to drop; no production costed-headline run exists to be inconsistent with (only two test callers). Every fold uses identical config ⇒ mutually consistent. | Latent **API-completeness** note: `walkForward` could optionally accept+forward costs for a costed OOS check. |
| R-7 | ruin_montecarlo | (see D-3) — this row is the *survived* one, listed in §1 | — | — |

*(R-7 placeholder: the Monte-Carlo finding survived and is D-3; six of the seven refuted rows are R-1…R-6.)*

---

## §3 — Owner-gate-adjacent observation (report only; **parked** per `gated-scope`)

**O-1 · Identity calibration overstates win-prob vs the conservative nil-prior for conviction ≳ 0.45.**
On the thin-split / no-candidate-beats-floor branch the selector returns the identity map (`winProb(c) ≈ c`, `buildIdentity` :616-632). The no-calibration fallback prior is `0.35 + 0.23·c` (`StockSageExpectedValue.swift:80`). Crossover: `c = 0.35 + 0.23c ⇒ c = 0.4545`; **above it, identity assigns a strictly higher win-prob than the conservative prior** (e.g. `c=0.9`: 0.90 vs 0.557), which raises Kelly `f*`. This is **not a math error** — identity is exactly what an identity map computes, and provenance forces every display to render **"assumed"** (`method=.identity`, `isMeasuredFromOutcomes=false` :644), so the "win-prob only from realized calibration" floor is honored via labeling. It **is** a real, honesty-floor-adjacent policy question, and it is **the parked owner gate F01/F02** (see `gated-scope` §1 and `AUDIT_2026-07-02_ideas_board.md`). The in-code comment (`StockSageConvictionCalibration.swift:79-85`) already flags it as OWNER-HELD. **Reported, not recommended — do not change without the owner's answer.**

---

## §4 — Confirmed-CORRECT coverage (126 formulas, per family)

Proof of what was re-derived and verified sound. `(k/m)` = confirmed-correct / total findings in that family.

**kelly_sizing (12/12):** Kelly `f*=W−(1−W)/R` clamped [0,1]; `edge=W·R−(1−W)`; half/quarter-Kelly + `suggested=min(0.20,half)`; cost-adjusted `netR=max(1e-4, R−roundTripR)`; portfolio uniform down-scale `cap/requested`; `shares=floor(account·riskFraction/|entry−stop|)`; leverage liq/drawdown formulas; allocator weight cascade preserving the 0.20 cap; `cryptoRiskScaler=max(1, annVol/0.20)`; rebalance closed-form + iterative concentration caps; `p` to Kelly is calibrated-only-when-supplied else the 0.35+0.23c prior.

**ruin_montecarlo (10/11):** SplitMix64 PRNG; fixed-fractional `equity*=(1+f·R)` with absorbing floor + ruin barrier; bootstrap index sampling; nearest-rank percentiles; `p20DrawdownProb`; DrawdownScenario `survival=(1−f)^losses`; underwater curve; loss-limit dollar/R gate; consecutive-loss run + streak warn band. *(11th = D-3.)*

**calib_platt (8/8):** `P=σ(−(A·s+B))`; target smoothing `t+=(N++1)/(N++2)`, `t−=1/(N−+2)`; init `B=ln((N−+1)/(N++1))`; Newton `θ−=H⁻¹g`; **A>0 clamp + B re-anchor** (the guard D-1's Beta path is missing); one-sided degenerate guard; adaptive `nBins`; provenance labels Platt "fitted" not "measured".

**calib_isotonic (6/7):** Wilson LCB; PAV L2 monotone fit; conviction→band bucketing; adaptive band count; empty-band prior handling; selector isotonic OOS re-materialization. *(7th = R-1, refuted.)*

**calib_beta (4/6):** Beta map `μ=σ(c+a·ln s+b·(−ln(1−s)))`; IRLS Newton `θ+=H⁻¹g`; 3×3 Cramer + 2×2 sub-solves + intercept-only; one-sided + domain-clamp guards + both-slopes-negative→honest base rate. *(D-1 HIGH + R-2 refuted are the other two.)*

**calib_selector (13/15):** chronological 70/30 split + 1-row embargo (leak-free); OOS Brier on held-out slice only; identity-floored strict-margin selection; winner refit on all data; beta/isotonic/Platt sub-maps; Wilson LCB; PAV; the Platt re-anchor; adaptive band count; train-fit isotonic OOS remap. *(D-1 + R-3 are the other two.)*

**tsmom_regime (12/13):** `varianceScalar=min(1, targetVol/realizedVol)`; trend-family assembly ×scalar then hard-cap 0.65; half-Kelly suggestedWeight chain; TSMOM 12-1 (`lookback 252, skipRecent 21`); annualized vol `=stdev(logret)·√252`; Wilder RSI(14)/ATR(14); Kaufman ER; MACD(12,26,9); MarketRegime additive votes; 52-wk-high proximity; `actionForScore` thresholds. *(13th = R-4, refuted.)*

**ev_winprob (13/13):** `evR=p·rewardR−(1−p)`, `rewardR=min(reward/risk,50)`; `p=0.35+0.23c` prior; single `winProbEstimate` locus; break-even `p*=1/(1+netRR)`; round-trip cost & net R:R; per-day velocity; half-Kelly per-cycle log-growth; net-cost velocity ranking key; quality-weighted rank + conviction floor 0.40; conviction-scaled capped risk fraction; daily variance de-annualization; calibrated winProb bin lookup; **+ the identity>prior honesty note (O-1).**

**netedge_cost (8/9):** `p*=1/(1+netRR)`; `evaluate` round-trip cost; `netExpectancyR`; financing accrual; 50× reward cap; `costAsPctOfReward`; `roundTripBps`; asset-class default bps constants. *(9th = D-2.)*

**deflated_sharpe (6/6):** `normalCDF` via erf; Acklam inverse-normal; population moments (skew `m3/sd³`, kurtosis `m4/m2²`); **PSR** `=Φ((SR−bench)√(n−1)/√(1−g3·SR+((g4−1)/4)SR²))`; **expectedMaxSharpe** Gumbel form (γ=0.5772…); `deflated()` DSR vs expected-max, `passes = dsr>0.95`.

**correlation_cluster (7/7):** Pearson `r` clamped [−1,1], nil on zero-variance; **date-aligned** cluster correlation (intersect on UTC-day buckets); greedy maximal clique by min-correlation ≥0.70; correlation-aware `weight/=K`; portfolio heat = Σ(shares·|entry−stop|)/account; CorrelationPrecheck verdict bands; averageCorrelation excludes undefined pairs.

**honesty_reads (9/9):** annualized vol (`n−1` sample variance ·√252); rolling 21-bar vol over 252 anchors (inclusive window); empirical-CDF percentile; `sizingMultiplier=max(0.25, min(absoluteBrake, percentileBrake))`; nearest-rank median; CoV vol-stability + `sizingReliability=1/(1+CoV)`; **skewness** `=mean(((r−μ)/σ)³)` (population σ); `downside95`; 52-wk-high proximity (bear-gated).

**backtester_walkforward (11/13):** decision/entry loop (decide on `[0…i]`, fill at `opens[i+1]`, **no look-ahead**); `foldRanges` disjoint partition; conservative exit walk (stop wins ties, gap-honest); net-R with friction; `n−1` sample stats + Sharpe; `walkForwardDecay`; pooled portfolio-proxy drawdown; `tStat` + moment-corrected `tStat`; DeflatedSharpe reuse; Chandelier trail; scale-out ladder blended R. *(R-5, R-6 are the other two.)*

---

## §5 — Method, limits, and provenance

- **Independence:** every confirmed-correct verdict rests on an agent's own first-principles derivation checked against the cited `file:line`; every discrepancy passed an adversarial refuter prompted to break it (default-refute under uncertainty); the 3 survivors were re-read and re-derived by the Opus main loop against source (line numbers in §1 were opened directly, not relayed).
- **No fabricated numbers:** every constant in this report was read from the code (`file:line`) or a research doc; nothing was recalled from memory. Where reachability mattered it was proven by `git grep` (D-2) or the cited call site (D-3).
- **Cross-references to the failure archive:** D-2 ≙ `DEVELOPMENT_LOG.md` "#3 takerFeeBps dead-code unit trap"; the discipline behind this whole audit is `incident-ledger` IL-15 (re-derive an auditor's math before trusting it — the cost-R "fix" that was disproved and reverted).
- **Limits:** this is a *math/formula* audit. It does not re-run the full test suite, does not judge product/ranking policy (that is owner-gated), and treats "no proven alpha (DSR≈0)" as the established ground truth, not a finding. Downstream numeric integration (e.g. how `winProbEstimate` flows into MarketsView displays) was checked only where a formula pointed at it.
- **Deliverable status:** NEW file, Opus lane, **left for Fable's review** — Fable turns D-1 into a plan (engine-math → owner/Fable routing), notes D-2/D-3 as latent, and routes O-1 to the owner (parked F01/F02). No merge, no edits to existing files.
