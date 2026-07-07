# Kelly / sizing invariants reference

Standalone reference for every Kelly and position-sizing invariant in the StockSage
money engine. Each invariant: the statement, its one-line derivation, and why it
matters for capital safety. Formulas verified 2026-07-07 against three independent
blind derivations (Opus 4.8, Fable 5, Gemini) and the shipped Swift; the parametric
sweeps in `StockSageMoneyInvariantSweepTests.swift` pin 1–4 (hand-derived in
`scratchpad/derive_invariants.swift`). Source of truth is always the `.swift` file
cited — this doc is a map (F46).

## 1. Half-Kelly fraction
- **Statement:** `fUsed = f*/2`, where `f* = p − (1−p)/R`.
- **Derivation:** maximize `g(f) = p·ln(1+fR) + (1−p)·ln(1−f)`; `g'(f)=0 ⇒ pR/(1+fR) = (1−p)/(1−f) ⇒ f* = p − (1−p)/R`. Half-Kelly scales by ½.
- **Capital safety:** delivers ≈75 % of maximum log-growth at ≈half the variance (**exact only in the small-edge limit** `f*→0`; the true ratio drifts — measured 0.7517–0.7741 across the test grid). Cuts drawdown depth and ruin probability. Enforced: `StockSageKelly.compute` (`half = fStar/2`).

## 2. Hard maximum cap
- **Statement:** `suggestedFraction ≤ maxFraction = 0.20`.
- **Derivation:** `suggestedFraction = min(maxFraction, fUsed)`.
- **Capital safety:** raw Kelly can exceed 1.0 (implied leverage) for high-edge setups; the cap keeps the book unleveraged. Enforced: `StockSageKelly.swift` `suggested = Swift.min(maxFraction, half)`; `maxFraction = 0.20` mirrors `StockSageAdvisor.maxWeight`.

## 3. Non-negativity floor
- **Statement:** `suggestedFraction ≥ 0`; `fullKelly ∈ [0, 1]`.
- **Derivation:** `fStar = max(0, min(1, w − (1−w)/netR))`; a non-positive edge ⇒ `fStar = 0`.
- **Capital safety:** a losing edge sizes strictly to 0 — never a short, never negative allocation. Enforced: `StockSageKelly.swift` clamp on `fStar`.

## 4. Risk-budget floor
- **Statement:** `dollarsAtRisk = shares·(entry−stop) ≤ account·riskFraction`.
- **Derivation:** `shares = floor(account·riskFraction / (entry−stop))`; flooring only ever *reduces* shares, so `shares·(entry−stop) ≤ account·riskFraction`. Holds even when `shares` floors to 0 (`dollarsAtRisk = 0`).
- **Capital safety:** the absolute dollar loss on a stop-out never exceeds the pre-allocated budget, whatever Kelly suggests. Enforced: `StockSagePositionSizer.size` (rounds shares DOWN). Note: this bounds *loss*, not *notional* — `notional` can exceed `account` (implicit leverage) for tight stops; that is by design (size by the loss, not the deployed capital).

## 5. Crypto risk scaler
- **Statement:** `weightNew = weightOld / cryptoRiskScaler`, `cryptoRiskScaler ≥ 1`.
- **Derivation:** `cryptoRiskScaler = max(1, realizedVol/target…) ⇒ 1/scaler ≤ 1 ⇒ weightNew ≤ weightOld`.
- **Capital safety:** the crypto vol adjustment can only attenuate or hold risk, never inflate it. Enforced: `StockSageExpectedValue.cryptoRiskScaler` `return Swift.max(1, …)`; pinned by `StockSageExpectedValueTests.cryptoRiskScalerOnlyShrinks…`.

## 6. Variance scalar
- **Statement:** `varianceScalar ≤ 1`.
- **Derivation:** `varianceScalar = min(1, targetVol/realizedVol)`; missing/NaN/≤0 vol ⇒ 1.0 (no-op).
- **Capital safety:** calm markets never amplify size above the baseline model. Enforced: `StockSageAdvisor.swift` `return Swift.min(1.0, …)`; pinned by `StockSageMathInvariantTests`.

## 7. Regime sizing bias (bounds)
- **Statement:** `sizingBias ∈ [0.40, 1.25]`, or `0.25` in the crisis regime.
- **Capital safety:** bounds how far regime detection can move size in either direction; crisis clamps hardest. Enforced: `StockSageRegime.swift`. Crisis 0.25 is pinned (`StockSageRegimeTests`); the [0.40, 1.25] band is **only partially pinned** — see the 2026-07-07 dev-log follow-up.
