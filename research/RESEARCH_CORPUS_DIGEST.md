# Research Corpus Digest — fast-load distillation of the three largest research docs

<!-- Generated 2026-07-02 (workflow wf_fea6c291-abd, full-read Sonnet-max digesters).
     Purpose: load the LOAD-BEARING content of ~100KB of deep research in ~1/6 the tokens.
     The ORIGINALS remain the source of truth — this digest is for fast session-start
     recall; if a digest line and the original disagree, the original wins. The other four
     research docs (EDGE_RESEARCH, MARKETS_INTELLIGENCE_RESEARCH, and the two 2026-07-02
     docs) are compact enough to read directly — see research/INDEX.md. -->

## RESEARCH_2026-06-26_quant_engine.md

### Core verdicts
SECTION 1 — BACKTEST VALIDATION

[HIGH] ADOPT CPCV over single walk-forward: single walk-forward is statistically fragile for 3 named reasons (one scenario only, sequence bias, warm-up waste). CPCV yields a Sharpe distribution — report median, dispersion, fraction-of-paths profitable. Keep walk-forward as sanity cross-check only.

[HIGH] ADOPT purge + embargo (two distinct steps): (a) PURGE training obs whose label window overlaps test label times; (b) EMBARGO h = ceil(0.01·T) bars after every test block. Raise h if label/feature memory exceeds ~1% of sample. Embargo h is NOT "50 of 1000 obs" — that is an arbitrary tutorial figure explicitly rejected.

[HIGH] ADOPT Deflated Sharpe Ratio gate (DSR > 0.95) ABOVE the pooled-t > 3 bar: the fixed t > 3 bar provably breaks near N ≈ 1000 trials because the no-skill expected maximum Sharpe alone reaches that region. DSR = Φ((SR_hat − SR0)·√(T−1) / √(1 − g3·SR_hat + ((g4−1)/4)·SR_hat²)). SR0 from the False Strategy Theorem. REQUIRES logging every variant tried (prerequisite, blocked without it).

[HIGH] ADOPT moment-corrected t-stat: compute SE(SR_hat) on NON-annualized returns with NON-excess kurtosis (g4 = 3 for normal, NOT Fisher/excess default). Report next to raw t. Autocorrelated returns make PSR/DSR OPTIMISTIC — the formula assumes serially uncorrelated returns; Lo's HAC is a separate term not included.

[HIGH] ADOPT walk-backward robustness check: reverse the sequence and re-backtest. Material flip = direct evidence of overfitting; down-weight the strategy. Cheap; blocks NOTHING if it passes.

[HIGH] ADOPT trial logging of every variant (prerequisite for all above): log every parameter, feature, threshold combination — not just winners. The full {SR_n} set is required to estimate V[SR_n] and count trials; without it FWER/FDR/PBO and DSR are uncomputable. THIS IS THE CHEAPEST AND HIGHEST-LEVERAGE ITEM.

[HIGH] REJECT fixed t > 3 bar: replace with a rising floor starting at t ≥ 3.18 (HLZ BHY-FDR 5%), escalating with trial count N via DSR.

SECTION 2 — POSITION SIZING

[HIGH] ADOPT half-Kelly as the working target, 1× Kelly as the hard outer ceiling, never the target: overbetting is strictly growth-security dominated (the exact optimum is flat-topped; downside is steep). Half-Kelly yields exactly 75% of max excess growth at 50% of volatility (c(2−c) formula, exact only for r = 0 excess growth, approximate for absolute growth with r > 0 where it is ~88%).

[HIGH] ADOPT adaptive Kelly shrinkage tied to calibration uncertainty: shrink further (more sub-Kelly) when Wilson interval / calibration confidence is wide. "When in doubt bet less" (Ziemba). Edge-estimation error is ~20× more damaging than covariance error.

[HIGH] ADOPT MC ruin sim as the primary finite-horizon safety check: no closed-form Kelly result guarantees finite-horizon protection — 700 favorable bets → $1,000 to $18 (full Kelly) / $145 (half-Kelly). Keep the MC sim; feed it the CPCV path distribution.

[HIGH] REJECT "Kelly never blows up": measure-zero / no-leverage statement. Half-Kelly worst case over 700 bets = $145 (−85.5%).

[HIGH] REJECT full Kelly as the target: estimation error biases the measured fraction HIGH, so "full Kelly on an estimate" can be effective overbetting (if estimated drift is 2× true, full Kelly drives true growth to zero).

[HIGH] ADOPT sizing-to-Sharpe framing: max Kelly growth g(f*) = r + S²/2. Surface the implied Sharpe alongside pooled t-stat — edge/Sharpe quality, not leverage, is what compounds.

[MIXED] CONDITIONAL-ADOPT myopic single-period sizing: valid for the FRACTION choice, but conditions must be documented — conditional return distribution needed under serial dependence; theorems say nothing about correlation coupling, estimation error, costs, or discrete sizing. Real-world soundness comes from cost gate, correlation haircut, heat cap, sub-Kelly sizing, and calibration quality.

SECTION 3 — REGIME DETECTION

[HIGH] ADOPT regime layer as risk-reduction tool, NOT alpha generator: documented OOS payoff is overwhelmingly volatility/drawdown reduction. Bulla et al. (2011) 40-year study: volatility cut ~41%, added only 18.5 bp/yr on S&P 500. The 201.6 bp Nikkei figure is loss-avoidance on a still-negative return stream. Budget as Sharpe-via-denominator improvement.

[HIGH] ADOPT filtered/online probabilities with t+1 execution delay: NEVER use smoothed (full-sample) probabilities in the backtester — Kim (1994) backward pass uses future data. Look-ahead contamination inflates pooled t-stat against the t > 3 bar.

[HIGH] ADOPT bear = high-vol heuristic: the robust, exploitable regime signal is volatility asymmetry. Size off the volatility STATE, not an inferred return direction — the regime MEAN is the fragile part (partly a mechanical artifact of fitting negative skewness, Kirby 2023).

[HIGH] ADOPT one-directional regime-conditioned correlation haircut: floor only (resize down, never up, when stress is flagged). Avoids under-haircutting in stress (correlations rise in bear regime, Ang & Chen 2002) while staying robust to misclassification. Do NOT apply bear-regime max haircuts unconditionally in calm regimes — turns hedges into directional bets.

[HIGH] REJECT smoothed-probability backtesting: look-ahead contamination, invalidates the t > 3 bar result.

[HIGH] REJECT regime-mean as a return-forecasting edge: the mean estimate is partly an artifact; the reliable signal is variance/correlation asymmetry.

[HIGH] REJECT naive high-vol slicing for bear correlations: conditioning on extreme returns biases correlation upward even under stationary normality (Forbes & Rigobon 2002). Use a bias-aware/stress floor, condition on the regime state.

SECTION 4 — CALIBRATION

[HIGH] ADOPT beta calibration as the default conviction→win-probability stage, replacing isotonic/PAV as the primary stage while the journal is sub-~1000 closed trades. Beta calibration is a 3-parameter bivariate logistic on ln(s) and ln(1−s): p_hat = 1/(1 + exp(−c − a·ln(s) + b·ln(1−s))). Enforce a ≥ 0, b ≥ 0 for monotonicity.

[HIGH] ADOPT sample-size-gated method selection: beta (or log-odds Platt with smoothed targets) below ~1000 trades; blend/switch to isotonic only above ~1000 (soft band 200–1000). Select by walk-forward OOS log-loss and Brier on purged/embargoed folds.

[HIGH] ADOPT identity-map check before locking any calibrator: beta CONTAINS the identity at a=b=1, c=0 — so it can leave an already-honest score unchanged. Platt does NOT contain the identity and "can easily uncalibrate a perfectly calibrated classifier."

[HIGH] ADOPT Platt smoothed-target regularizer if any logistic component is retained: fit against t+ = (N+ + 1)/(N+ + 2) and t− = 1/(N− + 2) (add-one/Laplace smoothing). Prevents 0/1 saturation on separable tiny sets. Do NOT apply these smoothed targets to the isotonic stage.

[HIGH] ADOPT Online Beta Scaling (OPS/OBS + calibeating / Gupta & Ramdas 2023) for live recalibration under regime drift. The hedging variant (HOPS/HOBS) gives an ASYMPTOTIC adversarial-calibration guarantee (L1/ECE decay ~T^−1/4 to T^−1/3). Scope explicitly as calibration robustness, NOT predictive edge.

[HIGH] REJECT isotonic as the primary stage below ~1000 trades: its flexibility is a liability (overfits below ~200–1000); stepwise output collapses distinct convictions to the same probability (destroys half-Kelly bet-sizing resolution); gives NaN/flat-clamp outside observed support (no informative extrapolation).

[HIGH] REJECT plain Platt on the raw score as the small-sample winner: plain Platt is biased on skewed scores, cannot represent the identity, and can uncalibrate an already-honest score. The evidence-backed small-sample default is beta.

### Quantified claims
BACKTEST VALIDATION NUMBERS

- CPCV mechanics: N=6, k=2 → C(6,2) = 15 combinations, φ[6,2] = 5 distinct backtest paths. Formula: φ[N,k] = (k/N)·C(N,k). [López de Prado, AFML Ch.7]
- Recommended embargo h: h = ceil(0.01·T) bars (~1% of total bars). Raise to ≥ max label horizon if needed. [López de Prado]
- False Strategy Theorem: SR0 = √(V[SR_n]) · [(1−γ)·Z⁻¹(1−1/N) + γ·Z⁻¹(1−1/(N·e))], γ ≈ 0.5772 (Euler-Mascheroni). SR0/σ crosses the t ≈ 3 region near N ≈ 1000 trials. [Bailey & López de Prado, 2014]
- DSR formula: DSR = Φ((SR_hat − SR0)·√(T−1) / √(1 − g3·SR_hat + ((g4−1)/4)·SR_hat²)). Require DSR > 0.95. T = number of NON-annualized return observations. g4 = NON-excess kurtosis (3 for normal). [Bailey & López de Prado, JPM 2014]
- SE(SR_hat) = √((1 − g3·SR_hat + ((g4−1)/4)·SR_hat²)/(T−1)) (Mertens 2002 / Lo 2002 IID estimator, generalized by Opdyke 2007)
- HLZ t-bar: Harvey, Liu & Zhu (2016) document ≥ 316 published factors. BHY-FDR at 5% implies t ≥ 3.18. Bonferroni implies ~3.78. [Harvey, Liu & Zhu, RFS 2016]
- False positives at N = 20 trials: expected false positives = N × 0.05 = 1 at N = 20 (5% nominal bar). ~20 iterations suffice to manufacture one false positive even OOS. [López de Prado]

POSITION SIZING NUMBERS

- Half-Kelly growth formula: g(cf*)/g(f*) = c(2−c). At c = 0.5: 0.5 × (2 − 0.5) = 0.75 → exactly 75% of max excess growth at exactly 50% of volatility (Thorp 2006, Eq 7.6). QUALIFIER: exact for excess growth (r=0); for S&P example (m=0.11, s=0.15, r=0.06) approximately ~88% of absolute growth. [Thorp 2006, Handbook of Asset and Liability Mgmt Vol. 1, Ch. 9]
- Overbetting crossover: 2× Kelly drives excess growth to zero; beyond 2× it goes negative. [MacLean-Ziemba-Blazenko 1992; MacLean-Thorp-Ziemba 2010]
- Drawdown formula: P(wealth ever falls to fraction x of start) = x^(2/c−1). Full Kelly (c=1): P = x (50% chance of ever halving). Half-Kelly (c=0.5): P = x³, so 12.5% (1/8) chance of ever halving; "double-before-halve" = 8/9. QUALIFIER: r=0, continuous-time GBM, no jumps, known parameters, infinite horizon, fall-from-INITIAL-capital NOT peak-to-trough. [Thorp 2006, Eq 7.13]
- Half-Kelly = RRA 2: alpha = 1/(1−δ), so c=0.5 → δ=−1 → RRA=2; quarter-Kelly → δ=−3 → RRA=4. EXACT only for continuous-time lognormal diffusion. [Thorp 2008]
- Finite-horizon catastrophe: 700 independent bets, 14% edge, ≥19% win probability: $1,000 → $18 (>98% loss) under full Kelly; half-Kelly worst case → $145 (−85.5%). Half-Kelly: 99% chance of not losing more than half vs 91.6% for full Kelly. [MacLean-Thorp-Ziemba 2010; CAIA/Ziemba 2016]
- Kelly max growth formula: g(f*) = r + S²/2 where S = (m−r)/s is the Sharpe ratio. [closed-form, standard]
- Edge vs covariance error sensitivity: mean (edge) errors are ~20× as damaging as covariance errors and ~10× as variance errors. Chopra-Ziemba 1993 ratio: ~20:2:1. For the full-Kelly/log investor: ~100:3:1. CAVEAT: in-sample CEs; Michaud-Esch-Michaud (2012) dispute OOS generalization to large multi-asset Markowitz. [Chopra & Ziemba 1993, JPM 19(2)]
- Live trading calibration example: Clark-Ziemba (1988) ran live trading at quarter-Kelly (25%). [Clark & Ziemba 1988]

REGIME DETECTION NUMBERS

- Regime duration formula: expected duration = 1/(1 − p_ii). At p_ii = 0.98 daily → ~50-day expected duration (MEAN of a right-skewed geometric; median ~34 days). Delta-method SE scales ~1/(1−p_ii)². [Hamilton 1989]
- OOS regime-timing performance (S&P 500): Bulla et al. (2011) 40-year Viterbi-HMM equity-timing: cut volatility ~41% on average, added only 18.5 bp/yr on S&P 500, net of 10 bp one-way costs. Nikkei: turned −4.30%/yr into −2.28%/yr (+201.6 bp, all loss-avoidance). [Bulla et al. 2011, J. Asset Mgmt 12]
- Real-time detection latency: one HMM study (Nystrup, DTU PhD) reports ~25-day median detection latency. Real-time switch counts can run ~2× the smoothed in-sample switch counts. [arXiv 2410.14841, citing Bulla et al. 2011]
- The 18.5 bp S&P figure barely clears a 10 bp one-way cost gate — apply cost gate to every regime-driven trade. [derived from Bulla et al.]

CALIBRATION NUMBERS

- Isotonic vs Platt crossover: Niculescu-Mizil & Caruana (2005, verbatim): "When the calibration set is small (less than about 200–1000 cases), Platt Scaling outperforms Isotonic Regression with all nine learning methods"; isotonic ties/wins only at "1000 or more points." Soft band: strongest case against isotonic below ~200; genuinely ambiguous 300–1000. [Niculescu-Mizil & Caruana, ICML 2005; scikit-learn]
- Online calibration guarantee rate: OPS/OBS + calibeating asymptotic L1/ECE decay ~T^−1/4 to T^−1/3. NOT a finite-sample guarantee. [Gupta & Ramdas, ICML 2023, arXiv:2305.00070]
- Platt smoothed targets: t+ = (N+ + 1)/(N+ + 2), t− = 1/(N− + 2). [Platt 1999; Lin, Lin & Weng 2007]

### Engine mappings
ALREADY IMPLEMENTED (confirmed in the document as existing StockSage architecture)

- Conviction-to-win-probability calibration: Wilson lower bound + isotonic/PAV stage [Section 4 — upgrading to beta; Wilson is KEPT]
- Half-Kelly sizing with a cost gate [Section 2 — KEEP, extend with adaptive shrinkage]
- Regime bias / regime sizing signal [Section 3 — RE-WIRE to filtered probabilities + volatility-state keying]
- Volatility targeting [Section 2 — KEEP]
- Correlation haircut [Section 3 — EXTEND to regime-conditioned stress floor]
- Heat cap [Section 2 — KEEP; complement with x^(2/c−1) labeled knob]
- ATR trailing stop [mentioned in Executive Overview as existing]
- Walk-forward backtester gated on pooled t > 3 [Section 1 — UPGRADE to CPCV + DSR]
- Monte-Carlo ruin sim [Section 2 — KEEP + feed CPCV path distribution]

PLANNED / NEW (explicitly "NEW" in the build checklist)

- Tier 1: Trial logging of every variant [Checklist #1 — prerequisite for DSR/FDR/PBO]
- Tier 1: Beta calibration replacing isotonic/PAV as primary stage [Checklist #2 — highest calibration-impact change]
- Tier 1: SE(SR_hat) direct computation + moment-corrected t-stat [Checklist #4]
- Tier 1: Walk-backward robustness check [Checklist #6]
- Tier 2: Deflated Sharpe Ratio gate (DSR > 0.95) above pooled-t bar [Checklist #7 — depends on #1]
- Tier 2: CPCV as primary backtest engine with purge + embargo [Checklist #8]
- Tier 2: Pooled-t bar as rising floor (start t ≥ 3.18, DSR-escalated) [Checklist #9]
- Tier 2: Regime layer rewired to filtered probabilities + t+1 execution delay + vol-state keying [Checklist #10]
- Tier 2: Regime-conditioned correlation haircut (stress floor, one-directional) [Checklist #11]
- Tier 3: CPCV path distribution fed into MC ruin sim [Checklist #12]
- Tier 3: Hard sizing cap at ≤ 1× estimated Kelly fraction [Checklist #13]
- Tier 3: Regime benefit budgeted as volatility/drawdown cut, cost gate applied to every regime-driven trade [Checklist #14]
- Tier 3: Online Beta Scaling (OPS/OBS + calibeating) for live recalibration under drift [Checklist #15]
- Tier 3: Sample-size-gated calibrator selection (beta below ~1000; isotonic only above) via walk-forward OOS log-loss and Brier [Checklist #16]
- Tier 3: Implied-Sharpe framing (g(f*)=r+S²/2) surfaced next to pooled t-stat; x^(2/c−1) as labeled lifetime drawdown knob [Checklist #17]

EXTEND (re-wire / upgrade of existing components)

- Wilson lower bound: KEEP AND LEAN ON as explicit small-sample safeguard; use to drive adaptive Kelly shrinkage (#5)
- Kelly fraction: EXTEND to adaptive shrinkage tied to calibration uncertainty
- Regime sizing bias: RE-WIRE from return-direction signal to volatility-state down-sizing signal
- Pooled-t bar: UPGRADE from fixed ≥ 3 to rising floor starting at ≥ 3.18, escalating via DSR

### Open items
1. Effective independent trial count estimation: the document recommends clustering trial-return series to approximate independence and using the effective (not raw) count in SR0. No specific clustering method is prescribed — this is left to implementation. Over-deflation is stated as the safer error direction.

2. CPCV N and k selection: the document gives the φ[N,k] formula and notes that "larger N shrinks each group's sample" as a power tradeoff, but does not prescribe specific N and k values for StockSage's own data length.

3. Embargo h calibration for StockSage's label/feature memory: h = ceil(0.01·T) is the default; raise if label-formation horizon or feature memory exceeds ~1% of the sample. The document does not specify StockSage's label horizons, so the raise condition must be assessed against actual feature memory.

4. Online Beta Scaling hyperparameter: the "no tuning" claim means one fixed hyperparameter set exists for OPS/OBS; the document does not specify what that set is. Must be sourced from Gupta & Ramdas 2023 directly.

5. CPCV path distribution → MC ruin sim integration: Checklist #12 says "feed the CPCV path distribution into the MC ruin sim so tail estimates reflect path variance" but does not specify the mechanics of how the path distribution is consumed by the MC sim.

6. Calibration reliability diagram: before locking a calibrator, plot the conviction-score reliability diagram OOS. The score shape (S-shaped vs skewed-to-extremes) determines whether log-odds Platt suffices or beta is needed. This diagnostic is not automated — it requires a manual/visual step or a formalized OOS Brier/log-loss comparison.

7. Re-estimation of regime edge magnitudes for StockSage's own universe: the document explicitly warns that the 18.5 bp S&P figure, ~25-day latency, and ~2× switch-count numbers are study-, asset-, frequency-, and threshold-specific. These MUST be re-estimated for StockSage's actual traded assets before the cost gate is applied to regime-driven trades.

8. HLZ M=316 calibration does not directly apply to strategy-level pooled-t: the document notes HLZ's t-ratios are per-factor cross-sectional tests with M=316 as the academic factor universe; StockSage's pooled-t is strategy-level with its own trial count. The on-point tools are Harvey & Liu (2015) and DSR/PSR. This leaves a gap: HLZ t ≥ 3.18 is borrowed as a heuristic floor, not a calibrated number.

9. Forbes & Rigobon (2002) bias correction for bear-regime correlations: the document flags that naive high-vol slicing biases correlations upward (conditioning on extreme returns). The "bias-aware/stress floor" approach is recommended but the specific correction method is not prescribed.

10. Temperature scaling for modern neural-net-style scores: the document notes classic nets were well-calibrated; overconfident modern nets require temperature scaling (Guo et al. 2017, single-parameter Platt variant). This is a conditional open item — relevant only if StockSage's conviction score is ever produced by a deep neural network.

11. Practical isotonic/beta blend in the 200–1000 ambiguous band: the document says the crossover is "genuinely ambiguous 300–1000" and recommends a soft band, but does not specify a blending scheme for that range.

12. Per-period return autocorrelation check: PSR/DSR assumes serially uncorrelated returns. If StockSage's per-period returns exhibit autocorrelation, Lo's HAC adjustment is needed but is NOT in the PSR/DSR formula. The document flags this as making reported PSR optimistic but defers the HAC implementation.

### Gotchas / forbidden approaches
FORBIDDEN / REFUTED APPROACHES

1. NEVER use smoothed (full-sample / Kim 1994 backward-pass) probabilities in the backtester for regime detection — they use future data and inflate the pooled t-stat. Filtered/online probabilities with a t+1 execution delay are the only valid choice.

2. NEVER use a fixed t > 3 bar once trial count N is large — the no-skill expected maximum Sharpe alone reaches t ≈ 3 near N ≈ 1000. The bar must be a function of recorded N via DSR/SR0.

3. NEVER treat a single walk-forward Sharpe as the verdict — sequence-biased, warm-up-wasting. "As easy to overfit a walk-forward as a walk-backward."

4. NEVER log only the winning variant — discarding losing trials destroys both N and V[SR_n]; this is the practice the ASA warns against and makes DSR/FDR/PBO/PBO uncomputable.

5. NEVER plug an annualized Sharpe with a per-period T into PSR/DSR — SR_hat, T, and moments must all be at the same NON-annualized frequency.

6. NEVER use excess kurtosis in the PSR/DSR denominator — the (g4−1)/4 term assumes g4=3 for normal (non-excess). The Fisher/excess default (normal=0) overstates PSR.

7. NEVER conflate CPCV path count φ[N,k] with the DSR trial count N — paths measure ONE strategy's sampling variance; N is the number of independent configurations searched. Using path count for deflation is a category error.

8. NEVER claim Kelly/log "never blows up" — 700 favorable bets can turn $1,000 into $18 (full Kelly) or $145 (half-Kelly). "Never risks ruin" is a narrow measure-zero / no-leverage statement.

9. NEVER size above 1× Kelly — strictly growth-security dominated; estimation error already biases the measured fraction high; overbetting the estimate is the LTCM failure mode.

10. NEVER present x^(2/c−1) as a guaranteed or peak-to-trough bound — it is a lifetime fall-from-initial-capital figure under continuous-time, r=0, no-jump, known-parameter, infinite-horizon idealized assumptions. Conflating it with the heat-cap metric is a category error.

11. NEVER state "75% growth at 50% vol" without the r=0 / continuous-time / excess-return scoping — for r > 0 (e.g., S&P: m=0.11, s=0.15, r=0.06) it is approximately ~88% of absolute growth at half-Kelly.

12. NEVER treat isotonic/PAV as the default calibrator below ~1000 trades — its flexibility is a liability; stepwise output collapses distinct conviction scores (destroys half-Kelly bet-sizing resolution); gives NaN/flat-clamp outside observed support.

13. NEVER treat Platt on the raw score as the safe small-sample default over beta — plain Platt cannot represent the identity map and "can easily uncalibrate a perfectly calibrated classifier."

14. NEVER confuse the beta a=b sub-family with classic Platt scaling — a=b is a logistic recalibrator on the LOG-ODDS of the score; classic Platt is a sigmoid on the RAW score. They coincide ONLY when Platt is fed log-odds inputs.

15. NEVER group all "boosting-style" scores as sigmoidal — AdaBoost belongs with skewed-to-extremes (Naive-Bayes-like), where logistic/Platt can make calibration WORSE.

16. NEVER default neural-net-style scores to beta — classic nets were among the best-calibrated; modern overconfident deep nets require temperature scaling (Guo et al. 2017).

17. NEVER fit any logistic calibrator to hard 0/1 labels on a tiny/separable set — probabilities will saturate at 0/1. Use Platt smoothed targets.

18. NEVER treat the online calibration guarantee (OPS/OBS + calibeating) as finite-sample or as predictive edge — it is an asymptotic adversarial-calibration guarantee (~T^−1/4 to T^−1/3 L1/ECE decay); the TOPS/TOBS tracking variant has no proven bound.

19. NEVER model the regime layer as an alpha generator — the documented OOS payoff is predominantly vol/drawdown reduction. The 201.6 bp Nikkei figure is loss-avoidance on a still-negative return stream, NOT alpha.

20. NEVER compute bear-regime correlations by naively slicing the high-volatility sample — conditioning on extreme returns biases correlation upward even under stationary normality (Forbes & Rigobon 2002).

21. NEVER apply bear-regime correlations/maximum haircuts unconditionally in calm regimes — perpetually over-haircuts and turns hedges into directional bets.

22. NEVER import regime study constants (18.5 bp S&P, ~25-day latency, ~2× switch counts) as universal constants — they are study-, asset-, frequency-, and threshold-specific.

23. NEVER add regime-specific parameters without paying the multiple-testing tax — extra parameters and the latency/false-positive tradeoff (lower threshold = faster but more spurious switches and turnover) are exactly the overfitting surface the DSR / t > 3 bar polices.

24. NEVER rely on the regime MEAN estimate as a return-forecasting edge — the mean estimate is partly a mechanical artifact of fitting negative skewness (Kirby 2023).

25. NEVER over-model variance/covariance at the expense of edge calibration for single-bet Kelly — mean error is ~20× covariance error (~100:3:1 for the log/Kelly investor). The calibration pipeline is where the growth payoff is won.

26. NEVER treat HLZ's t ≥ 3.18 as a direct calibration of StockSage's strategy-level pooled-t — HLZ uses M=316 as the academic factor universe for cross-sectional tests; the on-point tools for strategy-level evaluation are Harvey & Liu (2015) and DSR/PSR.

27. NEVER treat the False Strategy Theorem / DSR as exact — SR0 is an asymptotic extreme-value approximation assuming independent, roughly Gaussian trial Sharpes; naive raw N misstates it. Label all estimates as estimates.

28. NEVER assume PSR/DSR corrects for serial correlation — it uses the IID non-normal SE. Autocorrelated returns make reported PSR/DSR optimistic; Lo's HAC is a separate term not included in the formula.

---

## RESEARCH_2026-06-27_quant_engine_II.md

### Core verdicts
1. CALIBRATION — CONDITIONAL ADOPT: Add full 3-parameter Beta calibration (Kull, Silva Filho & Flach, AISTATS 2017) as a *candidate* alongside incumbent isotonic and a no-op identity map. Do NOT hard-replace isotonic. Let the existing purged/embargoed OOS Brier + log-loss-vs-baseline harness select the map per refit. "CONDITIONAL" not "ADOPT" for three reasons: (a) the ~200–1000 crossover was measured for Platt-vs-isotonic, NOT Beta-vs-isotonic — the Beta threshold is an inferred prior, not a demonstrated crossover; (b) on Brier, the point estimate non-significantly favors isotonic — the Beta win is concentrated on log-loss; (c) "Beta is best for small data" is a 41-UCI-dataset average, not a guarantee for one noisy autocorrelated trade journal.

2. EXITS — RETAIN ATR TRAILING STOP, REFRAME: Keep the ATR trailing stop but reframe it as regime-gated drawdown insurance, NOT a free expectancy booster. The academic record shows stops are process-dependent: negative expected-return under a random walk (Kaminski & Lo), positive only under momentum/positive autocorrelation or a low-return regime. Where stops help, the gain comes almost entirely from left-tail truncation, not improving the typical winner. Verdict: wide trailing stop, regime-gated on ρ ≥ Sharpe hurdle, not tight stops.

3. CRYPTO EDGES — REWEIGHT TO TIME-SERIES/ATR MOMENTUM: Re-weight crypto momentum to make absolute-trend/ATR (time-series) the primary input weighted at least as heavily as cross-sectional rank; suppress lookbacks ≥ 8 weeks. Cross-sectional momentum is real GROSS but fragile NET (largely eroded by weekly turnover and illiquid-alt frictions). The crypto stop-loss evidence (Sadaqat & Butt) does NOT validate ATR-trailing or a long-only sleeve — the gain is short-leg-driven. A 2025 follow-up finds risk-managed crypto momentum can be significantly negative.

4. EXECUTION COST — KEEP FLAT-BPS MODEL + ADD NEAR-ZERO IMPACT TERM: Keep the existing flat-bps spread/slippage model as the binding retail cost. Add a temporary-impact term with a linear→square-root crossover (near-zero at retail Q/ADV). Fix δ=0.5 everywhere; recalibrate only the prefactor Y per liquidity tier (0.5 default → 1.0 bound); present as a labeled range. At retail Q/ADV near zero, the choice between β=0.5 and β=0.6 is practically immaterial.

### Quantified claims
CALIBRATION:
- Beta 3-param vs. isotonic on log-loss: significantly better on 41 UCI datasets; Friedman p=6.9e-17 (Naive Bayes), p=1.0e-12 (AdaBoost variants), 10×5-fold CV. [Kull et al. AISTATS 2017]
- Beta 3-param vs. isotonic on Brier: point estimate non-significantly tilts to isotonic — the Beta win is concentrated on log-loss. [Kull et al. 2017]
- Beta identity safety: a=1, b=1, c=0 returns scores unchanged. Platt cannot represent identity. [Kull et al. 2017]
- Calibration crossover threshold: ~200–1000 samples is where parametric beats unconstrained isotonic — BUT this was measured for Platt-vs-isotonic (Niculescu-Mizil & Caruana ICML 2005, Fig 7, sizes 32–8192), NOT Beta-vs-isotonic. No Kull paper runs a size sweep. [Niculescu-Mizil & Caruana 2005]
- Beta LR regularization: use C ≈ 1e11 (near-unregularized MLE); default L2 shrinks a,b toward 0 and degrades the map. [Kull et al. 2017; netcal reference impl]
- s clamping: clamp to (1e-6, 1-1e-6) — conviction of exactly 0 or 1 produces infinite features (ln(0) = -inf). [Kull et al. 2017]

EXITS:
- Kaminski & Lo: under i.i.d. random walk, Δμ = p₀·(r_f − μ) ≤ 0 — stops always reduce expected return for any strategy with μ > r_f. [Kaminski & Lo, J. Financial Markets 2014]
- Kaminski-Lo Proposition 2 autocorrelation hurdle: per-period autocorrelation ρ ≥ π/σ (per-period Sharpe) required for stopping premium to turn positive. [Kaminski & Lo 2014]
- Kaminski & Lo regime contribution: ~50–100 bps/month added during stop-out periods (US equity, 1950–2004) via flight-to-quality rotation into long-term government bonds (~−17% correlation), at monthly+ frequency. NOT portable to intraday ATR stop on single names or to crypto. [Kaminski & Lo 2014]
- Han, Zhou & Zhu (US momentum 1926–2013): daily 10% stop cut worst monthly loss from −49.79% → −11.36% (EW) / −64.97% → −23.28% (VW); raised mean monthly return ~1.0% → ~1.73%; cut monthly stdev ~6.0% → 4.67%; more than doubled the Sharpe. Gross of costs; break-even ~4.0–4.8%/month. [Han, Zhou & Zhu, JFQA]
- Sadaqat & Butt crypto (147 coins, 2015–2022): stop-loss momentum raised average monthly return to 9.13% (t=4.05), cut monthly vol to 21.36%, flipped skewness to +1.683. Gain driven almost entirely by short/loser leg: loser leg +14.2% → −1.4%; long leg barely moves 6.19% → 7.70%. Fixed ~30% within-month stop (not ATR-trailing). Gross of fees/slippage/short-borrow; strongest in small-caps. [Sadaqat & Butt, JBEF 2023]
- 2025 follow-up: equity-style risk-managed crypto momentum can be significantly negative. [2025 crypto follow-up]
- Snorrason & Yusupov (OMX Stockholm 30, 1998–2009): 20% trailing best mean quarterly (1.71%); 15% trailing best cumulative (73.91%); best fixed (15%, 1.47%) clearly worse than trailing at every level except tightest; 5% stop was the only outright loser (−0.12%). One unpublished thesis, one market, no costs, no significance testing. [Snorrason & Yusupov, Lund thesis]
- Chandelier Exit default: Long stop = 22-day high − 3·ATR(22); StockCharts recommends raising multiplier to 5.0 for volatile names (HPQ example). No risk-adjusted-return data behind the specific multiplier — it is a PRIOR, not an optimum. [LeBeau's Chandelier Exit; StockCharts]
- Stop sweep deflation: Bailey & López de Prado illustrative example — backtest Sharpe ~2.0 from ~1,000 stop configs deflates to ~1.2. Use exact Gumbel form, not crude √(2 ln N). [Bailey & López de Prado, Deflated Sharpe]

CRYPTO / EQUITY EDGES:
- Liu, Tsyvinski & Wu (1,707 coins >$1M cap, 2014–2018): value-weighted top-minus-bottom weekly L/S returns of 2.7%/3.3%/4.1%/2.5% at t=1.99/2.44/2.74/2.00 for 1/2/3/4-week momentum; 8/16/50/100-week insignificant. Gross, in-sample, weekly-rebalanced; no net-of-cost figure. [Liu, Tsyvinski & Wu, J. Finance 2022 / NBER w25882]
- Above-median-size crypto momentum: significant 4.2%/week gross. Below-median-size: insignificant 0.6%/week. [LTW, w25882 l.138–141]
- Crypto taker cost: round-trip ~25–30 bps (Binance base spot taker 0.1%/side → ~0.2% fees + 0.05–0.15%/side L2 spread). The BNB-discounted 0.075% maker rate is NOT the correct baseline. [Liu/Tsyvinski/Wu w25882 l.264; cost measurement sources]
- Moskowitz, Ooi & Pedersen (58 futures, 12-month-lookback/1-month-hold vol-scaled trend): gross annualized Sharpe "greater than one" (~1.1), ~2.5× equity-market Sharpe; positive for all 58 contracts; effect "persists for about a year and then partially reverses" (lookbacks beyond ~12 months invert the signal). [MOP, JFE 2012]
- Huang, Li, Wang & Zhou (JFE 2020): pooled TSMOM t-stat 12.53/4.83 > 4.34 (parametric/nonparametric bootstrap critical values) — "not statistically reliable." TSM is profitable but "virtually the same as" a strategy based on the historical sample mean needing no predictability. Weak result is about predictability, NOT profitability. [HLWZ, JFE 2020]
- McLean & Pontiff (97 predictors, J. Finance 2016): returns 26% lower OOS (post-sample, pre-publication); 58% lower post-publication; incremental ~32% is publication-informed arbitrage. [McLean & Pontiff, J. Finance 2016]
- Chen & Zimmermann: pure data-mining component only ~12.3% (SE 1.7pp); most realized decay is genuine arbitrage, not mining bias. [Chen & Zimmermann, RAPS / arXiv:2209.13623]
- Decay concentration: post-publication decline greater for large/liquid/high-dividend-yield/low-idiosyncratic-risk stocks. Reliable only for US equities (Jacobs & Müller, JFE 2020 — non-US factors largely persist). [McLean & Pontiff 2016; Jacobs & Müller 2020]

EXECUTION:
- Square-root law exponent: 0.489±0.0015 across 2,299 Tokyo Stock Exchange stocks (Sato & Kanazawa 2024, arXiv:2411.13965); ⟨δ⟩=0.500±0.002 (σ≈0.07), essentially universal. The broad cross-study spread [0.4,0.7] (LSE~0.62, BME~0.71) is largely estimation error, not structural uncertainty. [Bucci/Mastromatteo/Bouchaud arXiv:1905.04569; Sato & Kanazawa 2024]
- Small-order crossover: Bucci, Benzaquen, Lillo, Bouchaud (PRL 2019) document crossover to a linear, T-dependent regime for very small Q/ADV — pure √ is wrong at retail sizes. [Bucci et al. PRL 2019]
- Empirical prefactor Y ≈ 0.5–1 (Bucci et al. arXiv:1602.03043); honest defaults with daily σ and full ADV: Y=0.5 → 25% ADV at σ=2% gives 50 bps; Y=1.0 → 100 bps. Bias-corrected estimates lower: 2026 AAPL study raw c=0.69 but bias-corrected c_eff≈0.34; EuroStoxx futures ≈0.5. [Bucci et al. 1602.03043]
- Almgren, Thum, Hauptmann & Li (2005, ~700,000 Citigroup US equity orders 2001–2003): reject pure √ temporary impact at 95%; fit 3/5 (0.6) power law; η=0.142±0.006 (t=23). Pre-Reg-NMS — η must be recalibrated. Validated only up to ~10% of daily volume. [Almgren et al. 2005]
- Almgren permanent impact: ~linear in trade rate with turnover-based liquidity factor; α=0.891±0.10 (≈linear), liquidity exponent δ≈0.267±0.22 (≈1/4), γ=0.314±0.041 (t=7.7); low-turnover/small-cap names carry materially higher permanent impact. [Almgren et al. 2005]
- Bitcoin impact (Donier & Bonart arXiv:1412.4503, >1M metaorders): δ≈0.5, Ỹ≈4.5×10⁻² (differently normalized; NOT comparable to equity Y). [Donier & Bonart 2014]
- Options: δ≈0.40–0.43. [various]
- Chen & Velikov equity anomaly net returns: 2020 Fed FEDS WP (120 anomalies): avg net ~8 bps/month, strongest 10–20 bps after data-mining adjustment. 2023 JFQA (204 anomalies): ~4 bps/month, strongest "at best 10 bps", combination methods ~20 bps. Omit price impact → upper bound. SE only ~5 bps (statistically near zero). Net spreads survive mainly below ~50% one-sided monthly turnover (Novy-Marx & Velikov 2016). [Chen & Velikov 2020 FEDS WP; 2023 JFQA]

### Engine mappings
CALIBRATION (#1, #2, #16 in build checklist):
- Calibration candidate selector {isotonic, beta-3param, identity}: ALREADY IMPLEMENTED as of iter7 (2026-06-27). `StockSageConvictionCalibration` with `candidateSelectorEnabled` flag (default false), `BetaCalibration` type, `fitBeta` (IRLS, 3×3 Cramer, drop-and-refit monotonicity), `selectCalibration` (chronological 70/30 split + 1-row embargo). 10 new test cases in `StockSageCalibrationSelectorTests`. Ridge-logistic plan subsumed by selector. [Research INDEX.md iter7 entry; doc §1 + DECISION BOX] **UPDATE 2026-07-09: stale — the flag shipped ACTIVATED (`= true`), owner-approved 2026-06-27; "default false" describes the pre-activation state only. Verified live in `StockSageConvictionCalibration.swift`.**
- Wilson lower bound as separate conservative floor on TOP of chosen map: ALREADY (Wilson) / NEW = bootstrap floor for Beta (no bins → bootstrap Beta's lower predicted quantile). Do NOT feed Wilson-shrunk targets into the Beta fit (double-shrinkage compresses high-conviction tail). [doc §1, checklist #2]
- Optional AICc/LR gate falling back to Beta[a=b] (Platt-on-log-odds) for very small n: labeled defense-in-depth (NOT a paper finding), lowest priority. [doc §1, checklist #16]

EXITS (#3, #6, #9, #11, #12, #15 in build checklist):
- ATR trailing stop: ALREADY in engine. Reframe reporting as realized left-tail/drawdown truncation NET of NetEdge costs, per-regime — NOT a higher-average-R promise. [doc §2, checklist #3]
- Regime-gating on ρ ≥ Sharpe hurdle (Kaminski-Lo Prop 2): NEW. Gate ATR stop by momentum/autocorrelation regime; widen/disable in mean-reversion. Reuse regime signal already in the Kelly allocator. [doc §2, checklist #6]
- Multiplier sweep → Deflated-Sharpe/FST machinery: ALREADY (DSR/FST) / NEW = apply to stop sweeps + fix Chandelier PRIOR (ATR(22)·3.0, 4–5× for high-vol/crypto). Count configs as trials; use exact Gumbel form. [doc §2, checklist #9]
- De-duplicate ATR stop vs. trend-change exit (Clare et al. 2012): NEW. Make ATR stop the crash backstop, not a parallel exit. [doc §2, checklist #11]
- Own regime-conditional stopping premium estimate from backtest+journal: NEW. Thread that ONE estimate everywhere (as win-prob is); do NOT port other-dataset magnitudes (50–100 bps/mo; 9.13%/mo crypto). [doc §2, checklist #12]
- Hard loss cap for crypto sleeve + liquidation check on trend book: NEW. Deploy cap as crash-tail insurance, flag it is long-short/short-leg-driven in published work. Pair ATR stop with Monte-Carlo ruin sim (ALREADY). [doc §2/#15; doc §3]

CRYPTO / EDGES (#4, #5, #8, #10, #15 in build checklist):
- Crypto momentum re-weight to short-lookback (1–4 wk) time-series/ATR (absolute trend) primary, cross-sectional ≤ 0.65 trend-family cap, gated on positive after-cost EV: NEW (re-weight) / ALREADY (cap + gate). Suppress/down-weight 8-week+ lookbacks. [doc §3, checklist #4]
- Live liquidity gate (spread + depth + recent volume) in crypto momentum path: NEW. Feed measured per-asset spread/slippage (12–36 bps liquid alts; 100–600 bps thin alts) into NetEdge; taker round-trip ~25–30 bps. [doc §3, checklist #5]
- Equity publication-decay haircut conditional and US-scoped: NEW. ~50–58% of in-sample Sharpe for crowded/liquid/large-cap/low-idio US signals; less for illiquid/high-idio; ~12% ONLY when isolating pure data-mining bias; reduce/disable for non-US. [doc §3, checklist #8]
- Bootstrap preserving cross-sectional correlation + no-predictability historical-mean benchmark + reactivate dormant full DSR for momentum: NEW (bootstrap, mean-benchmark) / DORMANT→ACTIVATE (full DSR). [doc §3, checklist #10]
- For TradFi: ~12-month/1-month-hold lookback; force selector to invert/disable beyond ~12 months. [doc §3]

EXECUTION (#7, #13, #14, #17 in build checklist):
- Flat-bps spread/slippage model: KEEP as binding cost for liquid retail base case. Do not replace. [doc §4, checklist #7]
- Add temporary-impact term (linear→√ crossover): NEW. Near-zero at retail Q/ADV; I≈Y·σ·√(Q/ADV) when participation is non-negligible. Fix δ=0.5; recalibrate only Y per liquidity tier (0.5 default → 1.0 bound); present as labeled range. [doc §4, checklist #7]
- Permanent-impact term increasing with inverse turnover (Θ/ADV), Almgren form: NEW. Labels: γ≈0.314, δ≈0.25, α→1 as US-large-cap extrapolations needing recalibration. Penalize low-turnover Saudi/small-cap names. [doc §4, checklist #13]
- Flag/penalize orders >10% ADV as out-of-model: NEW. Justification: unreliability + tail/partial-fill risk (NOT convex mean cost). Integrate with existing heat cap. [doc §4, checklist #14]
- Partial fill modeling for thin/illiquid tier: NEW. Fill probability/fraction tied to participation; charge unfilled intent against missed-edge/extra spread-crossing. [doc §4, checklist #14]
- Chen & Velikov ~4–8 bps/month named justification for after-cost gate and honesty floor: NEW designation. [doc §4, checklist text]
- β≈0.6 as optional dataset-specific alternative: NEW but lowest priority; practically immaterial at retail Q/ADV. Do NOT hard-code η=0.142. [doc §4, checklist #17]

EXISTING INFRASTRUCTURE (ALREADY confirmed in-engine):
- Purged/embargoed OOS selector: ALREADY
- NetEdge cost model: ALREADY
- Deflated-Sharpe / FST penalties: ALREADY (StockSageDeflatedSharpe)
- Wilson lower bound: ALREADY
- Half-Kelly allocator: ALREADY
- ATR trailing stop: ALREADY
- Monte-Carlo ruin sim: ALREADY
- Regime-bias machinery / regime signal in Kelly allocator: ALREADY
- Trend-family cap (0.65): ALREADY
- After-cost EV gate: ALREADY
- Correlation haircut: ALREADY
- Heat cap: ALREADY

### Open items
1. WHETHER BETA BEATS ISOTONIC ON STOCKSAGE'S OWN JOURNAL: The 41-UCI result and the crossover threshold are priors. The OOS selector (checklist #1) must make this call per refit — no hard decision can be made in advance. Track, per refit, which map the OOS selector picks and its OOS Brier/log-loss delta vs incumbent isotonic.

2. THE STOPPING PREMIUM'S SIGN AND SIZE ON STOCKSAGE'S OWN DATA: Published magnitudes (50–100 bps/mo Kaminski-Lo; 9.13%/mo Sadaqat-Butt crypto) do not port. A long-biased crypto sleeve may see negligible or negative net benefit. Estimate from StockSage's own backtest+journal (checklist #12).

3. PREFACTOR Y CALIBRATION: Y and all Almgren coefficients (η=0.142, γ=0.314, δ=0.25) are calibration-dependent estimates from pre-Reg-NMS US large-cap data. Y is presented as a range (0.5–1.0); permanent-impact constants flagged as extrapolations requiring recalibration for the actual assets traded (Saudi/small-cap/crypto).

4. CRYPTO LONG-ONLY SLEEVE NET BENEFIT: The 2025 follow-up finds risk-managed crypto momentum can be significantly negative; the published positive evidence is long-short with short-leg-driven gains. Net benefit for a long-biased sleeve is unproven and possibly negligible — explicitly deferred to empirical measurement.

5. OPTIONAL AICC/LR GATE (checklist #16): Whether to add a gate falling back to Beta[a=b] (Platt-on-log-odds) for very small n. Labeled defense-in-depth, not a paper finding. Lower priority; the Kull default is full 3-param Beta regardless of n.

6. β≈0.6 ALMGREN ALTERNATIVE (checklist #17): Whether to add β≈0.6 as a dataset-specific equity alternative. Practically immaterial at retail Q/ADV. Lowest priority.

7. RECONCILIATION OF RIDGE-LOGISTIC PLAN WITH BETA-CANDIDATE-SELECTOR: Research INDEX.md (iter7 entry) notes the ridge-logistic plan from the OPEN #2 calibration item was SUBSUMED by the selector. Confirmed resolved (iter7 shipped selector). No remaining open item here.

8. HONESTY FLOOR THREADING: Every headline academic return number (3%/week crypto, 9.13%/mo, 50–100 bps/mo) must never be surfaced as achievable — they must route through NetEdge. This is a standing constraint, not a discrete deliverable, but must be verified in any UI-facing iteration.

9. BOOTSTRAP DESIGN FOR CROSS-SECTIONAL CORRELATION (checklist #10): The exact bootstrap design preserving cross-sectional correlation for momentum inference is unspecified in the document — implementation details deferred to the iteration that activates the dormant full DSR.

### Gotchas / forbidden approaches
CALIBRATION — DO NOT:
- Do NOT hard-replace isotonic with Beta based on the crossover number alone. The ~200–1000 threshold is a Platt-vs-isotonic result (Niculescu-Mizil & Caruana 2005); treating it as proof for Beta-vs-isotonic is a category substitution.
- Do NOT use the "a fortiori" argument that Beta is stronger than Platt for small data. Beta is RICHER (less constrained) than Platt, so it RETAINS MOST (not more) of Platt's small-sample edge.
- Do NOT trust a vanilla unconstrained, default-regularized LR fit. Non-negativity on a,b is required; default L2 penalty (C=1.0) shrinks a,b toward 0 and degrades the map.
- Do NOT feed Wilson-shrunk targets into the Beta fit — double-shrinkage compresses the high-conviction tail.
- Do NOT claim "Beta strictly generalizes Platt" without the log-odds qualifier (it generalizes Platt-on-log-odds, not vanilla Platt).
- Do NOT cite Alasalmi et al. 2020 as evidence FOR Beta. It motivates small-n safeguards generally and proposes a data-generation method for isotonic; it neither tests nor endorses Beta.
- Do NOT ignore the Brier reversal — track both Brier and log-loss; weight log-loss for the win-prob/EV/Kelly application, but do not ignore that Beta's point estimate on Brier is slightly worse than isotonic.
- Do NOT expect a large gain if conviction is already roughly calibrated.

EXITS — DO NOT:
- Do NOT claim "a stop protects your edge for free" — false under a random walk (Kaminski & Lo).
- Do NOT claim "stops clip winners and lower returns" — this is backwards for momentum (the real cost is whipsaw/transaction cost on tight trails).
- Do NOT claim "tight stops protect capital best" — the 5% tight stop was the only outright loser in Snorrason & Yusupov.
- Do NOT treat any specific multiplier (2× or 3×) as an established optimum.
- Do NOT port the 50–100 bps/month or crypto 9.13%/positive-skew numbers onto StockSage's ATR stop.
- Do NOT assume the crypto stop-loss result validates ATR-trailing or a long-only sleeve. Sadaqat & Butt used a fixed ~30% within-month stop (not ATR-trailing), long-short, short-leg-driven.
- Do NOT run the ATR stop redundantly on top of a signal that already exits on trend change (double counting, unnecessary turnover).
- Do NOT optimize the stop level on in-sample Sharpe without deflation — use exact Gumbel form, NOT the crude √(2 ln N).
- Do NOT port the Kaminski-Lo 50–100 bps/month figure to intraday ATR stops or crypto (no safe-asset leg, 24/7, monthly+ frequency regime assumption does not apply).

CRYPTO / EQUITY EDGES — DO NOT:
- Do NOT give cross-sectional quintile-ranking crypto momentum heavy default weight. Treating the 2.7–4.1%/week numbers as a live edge is the central trap.
- Do NOT surface any headline academic return as achievable.
- Do NOT treat TSMOM as a near-certain edge (pooled t-stat over-rejects) — but also do NOT overcorrect into "TSM makes no money" (it is profitable, just not via predictability).
- Do NOT quote "Sharpe ~1.28 vs 0.38" for Moskowitz-Ooi-Pedersen — those are a t-stat and a correlation cell, not a Sharpe comparison from that paper.
- Do NOT use a static market-cap median as the liquidity filter, and do NOT conflate large-cap momentum concentration with the crypto SIZE factor.
- Do NOT apply a flat publication-decay haircut or apply it to non-US factors. The ~12% is the pure-mining component (Chen & Zimmermann); total post-publication decay is ~58% (McLean & Pontiff) and concentrated in crowded/liquid/large-cap/low-idio US signals.
- Do NOT exempt the trend book from cost/liquidation checks — TSMOM robustness is RELATIVE (relative to cross-sectional), not absolute.
- Do NOT use BNB-discounted 0.075% maker fee as the cost baseline; use taker 0.1%/side (~25–30 bps round-trip).

EXECUTION — DO NOT:
- Do NOT use a flat, size-independent slippage constant as the only cost — impact is universally concave.
- Do NOT apply pure √ form at retail sizes — use linear→√ crossover; √-everywhere overstates tiny-order cost.
- Do NOT let δ float per tier — it is universal at 0.500±0.002; floating it overfits sparse backtests.
- Do NOT treat the [0.4,0.7] cross-study spread as genuine structural uncertainty — it is largely estimation error centered on 0.5 (Tokyo study: ⟨δ⟩=0.500±0.002).
- Do NOT commit the arithmetic slip: with Y=1, σ=2%, Q/ADV=25%, impact = 100 bps, NOT 50 bps (50 bps is Y=0.5).
- Do NOT hard-code Almgren's η=0.142 or γ=0.314/δ=0.25 as current/universal — pre-Reg-NMS US large-caps only.
- Do NOT claim Almgren "validates" √ — they REJECT β=1/2 at 95% and use β=0.6.
- Do NOT infer that √-extrapolation to large participation under-estimates cost — it tends to OVER-estimate; no evidence for a steeper-than-√ mean regime.
- Do NOT transfer raw prefactors across studies — Bitcoin's Ỹ≈0.045 is differently normalized from equity Y.
- Do NOT attribute the wide [0.4,0.7] range to the Tokyo universality paper — it argues the OPPOSITE (universality at 0.5).
- Do NOT attribute Bitcoin δ/Ỹ to the Emilio Said theory paper — it is Donier & Bonart (arXiv:1412.4503).
- Do NOT attribute the 8 bps/month figure to the 2023 JFQA — it is the 2020 Fed FEDS WP (120 anomalies); the 2023 JFQA gives 4 bps/month (204 anomalies).
- Do NOT assume complete instantaneous fills in illiquid backtests.

GENERAL HONESTY FLOOR (applies to ALL items):
- No guaranteed profit; every number is an estimate with stated assumptions.
- All headline academic returns are GROSS. Never surface as achievable without routing through NetEdge.
- The engine's job is to REDUCE OVERSTATEMENT and REPORT RISK TRUTHFULLY — not to promise returns.

---

## RESEARCH_2026-06-27_money_fast_conviction.md

### Core verdicts
FINDING 1 — ADOPT (conditional): Concentration in genuine "best ideas" beats diversification. [HIGH confidence, 3-0 adversarial verification on claims [0],[1],[2]]
Justification: Antón-Cohen-Polk (RFS) show managers' highest-conviction holdings outperform market and own portfolio by ~2.8–4.5%/yr. This is real but narrowly scoped: only the top few picks matter; beyond those, remaining holdings alpha ≈ 0 (6 bps, insignificant). Do NOT adopt the stronger variants:
- REFUTED (0-3): "Concentration doubles Sharpe" — did not survive adversarial verification.
- REFUTED (0-3): "High Active Share predicts performance net of costs" — Frazzini-Friedman-Pomorski (AQR, "Deactivating Active Share") shows Active Share loses predictive power after controlling for benchmark choice.

FINDING 2 — REJECT: Felt "conviction" predicts retail win-rate. [HIGH confidence, 3-0 on claims [7],[8],[9],[10],[11],[12],[16],[17],[18]]
Justification: Barber-Odean and Taiwan studies show felt conviction is mostly overconfidence and is self-defeating. The more investors trade on conviction, the worse they do. REJECT any signal-weighting based on stated or self-assessed conviction levels.

FINDING 3 — CONDITIONAL ADOPT: A tiny elite (<1%) has genuine, persistent skill — but it is identified only by PAST REALIZED PERFORMANCE, not stated conviction. [HIGH confidence, 3-0 on claims [4],[5],[6],[13],[14],[15]]
Justification: Taiwan data (360,000 traders): top 500 by prior-year returns go on to earn 49.5 bps/day gross / 28.1 bps/day net. Skill is real but rare and retrospectively identifiable only. REJECT any forward-looking conviction-to-skill mapping that is not grounded in verified track record.

FINDING 4 — ADOPT: Fractional-Kelly (half-Kelly, 0.5x) sizing for compounding without ruin. [HIGH confidence, 3-0 on claims [19],[20],[21]]
Justification: MacLean-Thorp-Ziemba (Quantitative Finance 2010) establishes that full Kelly maximizes long-run growth but is dangerously volatile; overbetting at ≥2x Kelly drives growth to risk-free rate and then negative (ruin). Half-Kelly trades lower upside for much reduced variance. REJECT any "all-in" or conviction-scaled oversized bets.

FINDING 5 — ADOPT (flank, MEDIUM confidence): Low-conviction closet-indexing is also a loser. [3-0 on claim [3] only; companion claims refuted 0-3]
Justification: Cremers-Petajisto (RFS 2009) show lowest-Active-Share funds underperform their benchmark by −1.41% to −1.76%/yr after expenses. CONDITIONAL: the broader inference "high Active Share pays net of costs" was REFUTED (0-3). Adopt only the mechanical closet-indexer-underperforms conclusion.

### Quantified claims
All numbers below are sourced from /Users/saleh/Salehman-AI/RESEARCH_2026-06-27_money_fast_conviction.md unless otherwise noted.

--- FINDING 1: Best-ideas concentration ---
- Best ideas beat market and own portfolio: ~2.8 to 4.5%/yr GROSS (Antón, Cohen & Polk, "Best Ideas," RFS)
- "All Ideas" six-factor alpha: 6 bps/yr — INSIGNIFICANT (same paper)
- Fund holdings beat market: ~1.3%/yr GROSS (same paper)
- Net fund returns to investors: ~−1%/yr (same paper; investor does not capture the gross edge)
- Verification: 3-0 on [0],[1],[2]; stronger variants 0-3 (refuted)

--- FINDING 2: Felt conviction / overtrading ---
- Retail bought stocks underperform sold stocks: 3.2 pp over 1yr, 3.6 pp over 2yr (market-adjusted, GROSS of costs) — Barber & Odean
- Purely speculative conviction-driven trades: gap widens to 5.1 pp (1yr) and 8.6 pp (2yr) — same
- Round-trip transaction cost: ~5.9% — Barber & Odean
- Highest-turnover quintile net return: 11.4%/yr
- Lowest-turnover quintile net return: 18.5%/yr → 7.1 pp penalty from trading
- Market benchmark return (comparison period): 17.9%/yr
- Average household gross return: ~18.7% (close to market 17.9%) — net falls below par entirely due to costs, not skill
- Men trade 45% more than women; net return penalty: 2.65 pp (men) vs 1.72 pp (women) — "Boys Will Be Boys" (Barber & Odean)
- Single men trade 67% more than single women; extra penalty: 1.44 pp/yr — same
- Verification: 3-0 on [7],[8],[9],[10],[11],[12],[16],[17],[18]

--- FINDING 3: Day-trading base rates ---
- Day traders losing money in a typical 6-month period: >80% (Barber, Lee, Liu & Odean, Taiwan 1992–2006)
- Day traders earning positive NET abnormal returns in an average year: ~13–15%
- Day traders showing persistent, consistent year-over-year skill: <1% (≈1,000 of 360,000 traders)
- Top-500 traders by prior-year performance: 49.5 bps/day GROSS, 28.1 bps/day NET (revised 2014 published numbers)
- Bottom traders: −17.5 bps/day gross, −34.2 bps/day net
- Spread between top and bottom: >60 bps/day
- Heavy traders: earn gross profits, but NOT sufficient to cover transaction costs (cost = binding constraint)
- Verification: 3-0 on [4],[5],[6],[13],[14],[15]

--- FINDING 4: Kelly math of ruin ---
- 700 favorable wagers with 14% edge (edge case): full Kelly can turn $1,000 into as low as $18 (worst-case path outcome cited by MacLean-Thorp-Ziemba)
- Full Kelly turns $1,000 into ≥$100,000 only 16.6% of the time (same)
- Half-Kelly lifts worst case to ~$145 from $18 (much better floor; sharply cuts upside)
- Overbetting at exactly 2x Kelly: growth = risk-free rate (continuous-time approximation; Kelly 1956 / Breiman 1961)
- Overbetting beyond 2x Kelly: growth becomes negative (ruin pathway)
- LTCM cited as illustrative real-world instance (note: more precisely leverage + mis-estimated tail correlations, not pure overbetting — but math-of-ruin consequence is uncontested)
- Verification: 3-0 on [19],[20],[21]; source: MacLean, Thorp & Ziemba, "Good and bad properties of the Kelly criterion," Quantitative Finance 2010

--- FINDING 5: Closet-indexer underperformance ---
- Lowest-Active-Share funds pre-expense benchmark-adjusted return: +0.06% to −0.66%/yr
- After expenses: underperformance of −1.41% to −1.76%/yr (Cremers & Petajisto, RFS 2009)
- NYU draft version: −1.42% to −1.83%/yr (slightly different draft)
- "High Active Share predicts performance net of costs": REFUTED 0-3 (Frazzini-Friedman-Pomorski)
- Verification: 3-0 on claim [3] only

### Engine mappings
All mappings reference the StockSage engine (Salehman AI project at /Users/saleh/Salehman-AI/). Sourced from the document itself and the research INDEX.md cross-references.

1. HALF-KELLY 0.5x SIZING (already implemented):
   - Research directly validates the app's current 0.5x Kelly multiplier.
   - Mandate: Do NOT raise the Kelly fraction. The math of ruin from overbetting (≥2x → risk-free, then negative) and the half-Kelly ruin-of-halving math justify keeping it bounded.
   - maxWeight cap (0.20) also validated: raw Kelly can exceed 1 (leverage); 0.5x + cap prevents that.
   - Maps to: ITER1 (calibrated win-prob → half-Kelly = highest-leverage improvement), capital allocator (`StockSageCapitalAllocator`), sizing stack generally.

2. SIZING > SIGNAL QUALITY (architecture principle):
   - The research confirms "worse model + better sizing beats better model + worse sizing" (2-1 adversarial vote in quant_engine research).
   - Maps to: Overall ITER1–6 architecture priority order.

3. COST DISCIPLINE / NET-OF-COST EV (ITER6 and forward):
   - Research shows the ENTIRE retail underperformance gap is COSTS, not skill: gross returns match market, net falls below. Transaction costs are the binding constraint for heavy traders.
   - Relevant to: `NetEdge` module (ITER6), break-even win-rate gate p* = 1/(1+netRR), cost floor.
   - Post-iter6 follow-up: make floor cost-relative (still open per INDEX.md).

4. CONVICTION AS SIGNAL — EXPLICITLY REJECTED:
   - Do NOT wire self-reported or stated conviction into win-probability or position sizing. Felt conviction is overconfidence and is self-defeating per 3-0 verified evidence. The engine must derive conviction-equivalent scores ONLY from quantitative signal calibration (iter7 calibration selector), NOT from user-stated or heuristic conviction.

5. CALIBRATION PIPELINE (ITER7, planned):
   - The finding that skill is predicted by PAST REALIZED PERFORMANCE (not conviction) directly motivates the calibration-selector approach: {identity, Beta-3param, isotonic} OOS-Brier-picked. The calibrator acts as the engine's operationalization of "measured skill from track record."
   - `StockSageConvictionCalibration`: `candidateSelectorEnabled` flag (default false, byte-identical off). This is the iter7 module. **UPDATE 2026-07-09: stale — flag shipped ACTIVATED (`= true`), owner-approved 2026-06-27; the identity floor still guarantees byte-identical output when the OOS selector picks identity.**
   - Reconcile note: the research (quant_engine_II) recommends Beta calibration as a candidate alongside isotonic + no-op identity, OOS-selected per refit. The ridge-logistic (plain Platt) plan must be reconciled with this Beta-candidate-selector before iter7 ships.

6. CONCENTRATION / BEST-IDEAS LOGIC (if implemented):
   - If the engine ever ranks and concentrates into "best ideas," the research cap is: only the TOP FEW picks earn excess alpha. Beyond those, diversification adds no alpha (6 bps, insignificant). Any multi-name allocation beyond the top ideas should not be expected to contribute outperformance.
   - Active Share as a selection criterion: REJECTED. Frazzini-Friedman-Pomorski refuted its net-of-cost predictive power.

7. DAY-TRADING / SHORT HOLDING PERIOD GUARD:
   - Base rate: >80% of day traders lose money net of costs. <1% have persistent skill, identified by track record only.
   - Maps to: The week-horizon velocity research (2026-07-02) extends this finding to 1–5 day holds. The engine should apply a cost gate / refuse-list for short-hold names (see RESEARCH_2026-07-02_week_horizon_velocity.md).

8. TSMOM VARIANCE SCALING (ITER3, already shipped):
   - Indirectly supported: scale trend by targetVol/realizedVol (Barroso & Santa-Clara 2015). Research supports vol-targeted sizing over binary crash vetoes.

9. PER-SYMBOL VOL-REGIME BRAKE (EDGE_RESEARCH #1, shipped):
   - `StockSageVolRegime`: sizingMultiplier applied in `buildIdeas` + `StockSageCapitalAllocator`. Validated by the general Kelly-and-ruin framework in this research document.

10. LEFT-TAIL / DOWNSIDE-SKEW READ (ITER4, shipped):
    - `StockSageReturnShape.returnShape(closes:)`: flags isLeftTailed (skew < −0.5), appended as ⚠ note in idea rationale. Grounded in the research's emphasis on ruin-avoidance and variance awareness.

### Open items
1. ITER7 CALIBRATION RECONCILIATION (explicit open item from INDEX.md cross-ref):
   The ridge-logistic (plain Platt MLE) plan is subsumed by / must be reconciled with the Beta-candidate-selector ({identity, Beta-3param, isotonic} OOS-Brier-picked). The research flags this as: "OPEN #2: Platt path is plain MLE not conservative → ITER7 ridge-logistic (reconcile w/ Beta-candidate-selector)." Must resolve before iter7 ships.

2. NET-OF-COST FLOOR: Make the EV/cost floor cost-RELATIVE (not a fixed bps number). Currently ITER6 sets a floor; the research implies it should scale with actual transaction cost estimates per symbol. Flagged in INDEX.md as a follow-up to ITER6.

3. SKILL IDENTIFICATION IN PRACTICE: The research establishes that genuine skill is identified by PAST REALIZED PERFORMANCE in the cross-section, but does not prescribe exactly how many trades / what lookback are needed for reliable ranking. The quant_engine_II research sets thresholds (~200–300 trades for Beta/Platt, ~1,000+ for isotonic) but the conviction-research document leaves the "minimum track record" question open for the engine's specific context.

4. CONCENTRATION MECHANICS (top-N selection): The research establishes that only the top few "best ideas" carry excess alpha and diversification adds none. The engine has not yet implemented a formal top-N selector or "best ideas" concentration rule. The weekly-cycle / top-3 concentration mechanics from the 2026-07-02 week-horizon research were flagged as getting ZERO verified claims — still rests on this (06-27) research only.

5. LTCM-STYLE TAIL-CORRELATION RISK: The document flags that LTCM's collapse is more precisely leverage plus mis-estimated tail correlations, not pure overbetting. The engine's current correlation-aware heat caps address this partially (quant_engine_I research), but explicit tail-correlation estimation is not implemented.

6. SURVIVORSHIP BIAS QUANTIFICATION: The doc raises survivorship bias as a concern for "get rich fast" strategies but does not produce a specific adjustment factor. The Deflated Sharpe (backtest harness, `StockSageDeflatedSharpe`) is the current mitigation; no further quantification is given in this document.

7. REPLICATION CAVEAT (Cueva et al. 2019): A 2019 replication questions whether overconfidence is the EXACT mechanism behind trading-lowers-returns, though the trading-lowers-returns facts themselves are not disputed. If future iteration wants to use overconfidence as a causal framing in UI copy or advice text, this is an open methodological question.

### Gotchas / forbidden approaches
THINGS THE DOC SAYS NOT TO DO — maintainers must not violate these:

1. DO NOT use the 2.8–4.5%/yr best-ideas figure as a NET return estimate. It is GROSS. Fund holdings beat market only ~1.3%/yr gross; net fund returns are ~−1%/yr. Investors do not capture the gross edge.

2. DO NOT adopt "Active Share predicts performance net of costs" as a design principle. This was EXPLICITLY REFUTED 0-3 (Frazzini-Friedman-Pomorski). Only the closet-indexer-underperforms-after-fees mechanical claim survived (3-0).

3. DO NOT raise Kelly fraction above 0.5x. At exactly 2x Kelly, growth = risk-free rate. Above 2x Kelly, growth goes negative. The half-Kelly bound is non-negotiable per the math of ruin. ("DO NOT raise it" is verbatim in INDEX.md.)

4. DO NOT wire stated or felt conviction into sizing or win-probability. Conviction is a proxy for overconfidence, not skill. The buying-minus-selling gap WIDENS for purely speculative conviction-driven trades (8.6 pp over 2 years). The more a trade reflects active stock-picking conviction, the worse it does.

5. DO NOT claim or imply that the engine can "make money fast." The research demolished the "get rich fast" framing. Best-ideas concentration is real but takes time and high holding costs at the retail level.

6. DO NOT diversify indiscriminately into many names expecting diversification benefit. Beyond the top few "best ideas," additional holdings add ~0 alpha. Overdiversification is a known failure mode (four documented reasons: regulatory/"Prudent man" rule, litigation risk, fee/asset-gathering incentives).

7. DO NOT use a single-year winner as evidence of persistent skill. <1% of traders (1,000 of 360,000) show persistent year-over-year skill. Most single-year winners are luck. Past realized performance predicts future performance ONLY for the top cross-sectional rank — not for any individual year-winner.

8. DO NOT use isotonic calibration with fewer than ~1,000 samples. Isotonic binning is unreliable below ~1,000 (Niculescu-Mizil & Caruana). Use Beta-3param or Platt (ridge-logistic) at small sample sizes (<200–300 trades).

9. DO NOT re-research items already in the INDEX. The index is the permanent record; re-research wastes compute and may contradict settled findings. Extend existing entries instead.

10. DO NOT read SOURCE_BUNDLE.md (~530k tokens, generated output). Read real source files. (CLAUDE.md standing directive, relevant for any maintainer using Claude Code in this repo.)

---
