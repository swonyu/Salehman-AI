# AUDIT — StockSage math red-team ROUND 2 (2026-07-03)

**Author:** Opus 4.8 xhigh parallel session (Opus lane, task **O5**), issued by Fable 5.
**Type:** READ-ONLY adversarial audit of the code that shipped to `main` overnight 2026-07-02→03. **No fixes** — findings only; Fable triages.
**Method provenance:** workflow `wf_03ccddbc-a7c` — 10 module-audit agents (Opus, effort xhigh), each re-deriving every formula/threshold/boolean-gate from first principles against its research citation, then every claimed discrepancy routed through an independent adversarial refute-verifier (default-refute under uncertainty). 12 agents, ~0.89M tokens, ~5 min. The two fixes-to-my-own-Round-1-findings (calibration D-1 re-anchor; NetCostSim per-side cost) were **additionally re-verified by the Opus main loop against source** (lines cited below), per `incident-ledger` IL-15.

## Scope (tonight's new/changed code)
`StockSageRefuseList`, the crypto-risk trio (`StockSageCryptoLiquidityGate` / `CryptoHonesty` / `CryptoFunding`), the `StockSageNetEdge` tier-aware crypto cost accessor (+ D-2 `allInCost` deletion), `StockSageGapRisk` worstCase/clamp, `StockSageLossLimit` fail-closed window, `MarketsView` `BacktestVerdict.metricColor` gating, `StockSageNetCostSim` (post-review `b366ec6` per-side costs), and the `StockSageConvictionCalibration` D-1/D-1b re-anchor.

---

## Executive summary

| | Count |
|---|---|
| Modules audited | **10** |
| Formulas / gates examined | **66** |
| Discrepancies surviving adversarial verify | **0** |
| Candidate discrepancies raised then refuted | 2 |

**Bottom line: tonight's new code is mathematically sound — zero surviving discrepancies.** Every refuse-list anti-edge matches its research citation with the correct (net-negative) direction and no fail-open; every crypto gate suppresses in the safe direction; GapRisk, LossLimit (fail-closed), and the significance-gated verdict color are all correct. **Both fixes to my Round-1 findings are verified correct** (details in §3). The two candidate discrepancies were a dormant doc-comment wording nit and a funding-formula term that is in fact correct — both refuted.

---

## §1 — Confirmed discrepancies

**None.** No claimed discrepancy survived adversarial verification. (Contrast Round 1: 3 survived. Tonight's code — much of it implementing Round-1's own findings — is clean.)

---

## §2 — Candidate discrepancies raised then refuted (2)

| # | Module | Claim | Why refuted |
|---|---|---|---|
| R-1 | refuse_list | `StockSageRefuseList.swift:52` doc-comment calls `outOfSampleDecay`/`postPublicationDecay` "the mandatory haircut," but the research prescribes a 50–60% haircut while the constants are the *decay* fractions 0.26/0.58 | The **constants are numerically correct** vs spec (26% OOS / 58% post-pub, `week_horizon:16`); the complaint is a pure documentation-wording nuance. Critically the constants are **dormant** — `grep` confirms no production math reads them (only a literal-value test), so no under-haircut can occur. Not a math error. *(Residual: line-52 comment could tighten "decay" vs "haircut" wording — cosmetic.)* |
| R-2 | crypto_funding | `dragR` includes a `· leverage` term (`StockSageCryptoFunding.swift:44`) — alleged double-count | The `· leverage` term is **correct**, not a double-count: funding accrues on notional = equity × leverage, and `riskFractionOfNotional` is defined per-notional, so the two conventions differ by exactly `leverage` and the term is required. The L=1 test pin cannot disambiguate (both conventions coincide at L=1), but the derivation confirms the term belongs. Not a math error. |

---

## §3 — Verified confirmations of note (the two fixes to Round-1 Opus findings)

### C-1 · Calibration D-1/D-1b re-anchor — **CORRECT** (fix of my Round-1 D-1 HIGH)
- `StockSageConvictionCalibration.swift:366-368`: the intercept-only fit now inits `c = ln(nPos/nNeg)` — the **exact** base-rate MLE (I re-derived: intercept-only `p=σ(c)`, `dL/dc = nPos − n·σ(c) = 0 ⇒ σ(c*)=nPos/n ⇒ c*=ln(nPos/nNeg)`). This is the D-1b fix: even the undamped 25-iter Newton lands correctly because it starts *at* the MLE.
- `:470-472` (dropA, `b1 <= 0`) and `:482-484` (dropB, `a1 <= 0`): when the surviving slope clamps, the branch now **refits intercept-only** (`irls(false,false)`) and returns `.interceptOnly` with the honest base-rate `c` — exactly the re-anchor my D-1 finding said was missing, mirroring the Platt A-clamp/B-re-anchor and the `.interceptOnly` sibling.
- The audit's independent Python enumeration (all 44,850 `(n,nPos)` pairs, `2≤n≤300`) found worst-deviation **0** from the honest base rate, and reproduced the commit's D-1b counts (12,948 previously non-anchored, 6,474 overstating) exactly. My original inverted-sample failing input now yields the honest base rate. **My Round-1 HIGH finding was real and is correctly closed.**

### C-2 · NetCostSim per-side cost — **CORRECT** (Fable review of my Round-1 O3)
- `b366ec6` changed the cost accounting to `perSideCost = max(0, roundTripBps)/2/10_000; net = gross − turnover·perSideCost`. Re-derivation: `turnover = Σ|Δw|` counts **each leg once**; a full round trip (enter + exit) = 2 turnover units, so charging `roundTripBps/2` per unit ⇒ `roundTripBps` per round trip — **correct**.
- This means my Round-1 O3 had a latent **2× cost over-charge** (I applied full `roundTripBps` to one-way turnover). Fable's review caught it; the per-side fix is right, and `clearsNetOfCost` still resolves **false** for the IRRX overlay (the verdict is unchanged; it was over-pessimistic before, honest now). The review pipeline worked as intended.

### Scope-notes (NOT discrepancies — surfaced for Fable's awareness)
- **BacktestVerdict color scope:** the significance gate covers *backtest* metrics; **realized-journal metrics (`journal.stats`) are colored by SIGN without a significance gate**. This is defensible (realized journal = actual money, not a backtest estimate, so sign-coloring is honest) — flagged only so the asymmetry is a conscious choice, not an oversight.
- **Crypto-honesty inherited caveat:** `CryptoNetEdgeHonesty` composes `StockSageBacktester.run`, which charges the exit-side cost at the *entry* price (a pre-existing Backtester modeling choice, not a defect in tonight's file). Noted for completeness.
- **GapRisk short leg is intentionally UNBOUNDED:** short `lossPerShare = gapFill − entry` has no clamp — correct (a short's gap loss is genuinely unbounded); it does not hide the worst case. Honest.

---

## §4 — Confirmed-correct coverage (66 items, per module)

- **refuse_list (9/10):** all 7 anti-edges match `week_horizon`'s cited numbers with correct net-negative direction (naive reversal −1.28%/mo net t=−6.02; PEAD 70–100% cost; 90%-turnover; overnight-roundtrip vs the real premium; funding-seasonality 2.5bps<4–10bps/side; illiquid-anomaly; decay 26/58 + 50–60% haircut); `outOfSampleDecay/postPublicationDecay` values correct + dormant; `policyNote` assembly. *(10th = R-1, refuted.)*
- **crypto_liquidity_gate (6/6):** ADV$ = Σ(close·vol)/n; overnight-gap%; `isThin` below 5M floor → skip; unknown-depth → fails to "limit-only, size down" (conservative); `-USD`-suffix guard; `thinNote` suppression.
- **crypto_honesty (7/7):** 3-leg net-edge composition; classify() gate order (thin→<20 trades→gross≤0→netMid≤0→…); `thinNote` forces "unproven"; `frictionDragR`; significance floor 20; honesty-floor strings exclude "guaranteed".
- **crypto_funding (5/6):** `dailyFunding = annualBps/10 000/365`; cost fraction; band monotonicity (`high≥mid`); input guards; note formatting. *(6th = R-2, refuted.)*
- **netedge_crypto_costs (6/6):** tier `roundTripBps = 2·halfSpread + slippage + 2·takerPerSide`; band containment; tier thresholds (BTC/ETH→major, nil→mid, <2M→thin, ≥50M→large); `asCostAssumption` bridge; worst-leg monotonicity; **D-2 allInCost deletion clean (no dangling refs)**.
- **gaprisk (7/7):** long `gapFill=max(0,stop(1−gap))`; short `gapFill=stop(1+gap)` (unbounded, correct); `exceedsAccount` uncapped; `blowsThroughStop`; input guards; `worstCase` ascending ladder; `rMultiple`.
- **losslimit (7/7):** week-start with fail-closed 7-day fallback; realized window `[from, now]`; `gate` loss≥limit→halt (fail-closed, `guard lim>0`); `lossRun`; `standDown`; status precedence.
- **backtest_verdict_color (5/5):** `metricColor(positive,significant) = significant ? (positive?green:danger) : neutral`; significance = trades≥20; positive = winRate≥1/3 (2:1 break-even p*); neutral rendering path.
- **netcostsim_perside (6/6):** per-side cost (C-2); fail-closed gate; IRRX reversal weight sign; walk-forward purge/embargo; `verdict` n−1 sample var + nil guards; `nonisolated` purity.
- **calibration_reanchor (6/6):** intercept-only MLE init (C-1); init routing preserves converged fits; D-1b enumeration; extreme-base-rate witness; clamp boolean direction; `winProb` σ(+z) convention consistency.

---

## §5 — Method & provenance
- Every CONFIRMED-CORRECT verdict rests on an agent's own first-principles derivation checked against the cited `file:line`; every discrepancy passed an adversarial refuter; C-1/C-2 were re-read by the Opus main loop against source.
- No fabricated numbers: every constant read from code or a research doc; dormancy claims proven by `grep`.
- **Deliverable status:** NEW root file, Opus lane, left for Fable's review. Tonight's code needs no math fixes; the two refuted items are cosmetic (a doc-comment word) / non-issues (a correct funding term). No merge, no edits to existing files.
