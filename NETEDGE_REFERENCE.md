# Net-edge cost model reference

Standalone reference for `StockSageNetEdge` — the cost-adjusted edge and the shipped
cost table. Formulas verified 2026-07-07 against three independent blind derivations
(Opus 4.8, Fable 5, Gemini) and the shipped Swift. Source of truth is
`Salehman AI/StockSage/StockSageNetEdge.swift` (F46); this doc is a map.

## 1. Mathematical model

The model is cleanest in **R units** (below); the code computes the algebraically
identical thing in **dollar space** — see §1.1.

- **Cost in R units:** `costR = (costBps/10000) · entry / (entry − stop)` — round-trip bps of notional converted to risk units.
- **Net reward:** `netReward = grossReward − costR`
- **Net risk:** `netRisk = grossRisk + costR`
- **Net RR:** `netRR = netReward / netRisk`

**Break-even probability** (net EV = 0):

`p* = 1/(1 + netRR) = netRisk / (netReward + netRisk)`

Proof `netEV = 0` at `p*`: `netEV = p·netReward − (1−p)·netRisk`. Substitute `p* = netRisk/(netReward+netRisk)`, `(1−p*) = netReward/(netReward+netRisk)`:
`netEV = [netRisk·netReward − netReward·netRisk] / (netReward+netRisk) = 0`. ∎

### 1.1 How the code actually computes it (dollar space + 50:1 cap)

`StockSageNetEdge.evaluate` works in dollars and applies the same 50:1 reward cap
`StockSageExpectedValue.ev()` uses:

```
grossReward   = |target − entry|           grossRisk = |entry − stop|
cost($)       = (spreadBps+slippageBps+takerFeeBps)/10_000 · entry
                + commissionPerShare + financing          // financing = entry·annualRate·holdDays/365
cappedGrossReward = min(grossRR, 50) · grossRisk          // grossRR = grossReward/grossRisk
netReward = cappedGrossReward − cost($)     netRisk = grossRisk + cost($)
netRR     = netReward / netRisk
```

Dividing numerator and denominator by `grossRisk` recovers the R-space form above, so
`netRR` is identical — the dollar form just carries the honest per-share cost fields.
**The 50:1 cap is load-bearing:** a hair-thin stop (`grossRisk → 0`) would otherwise
make `grossRR` unbounded, inflate `netRR` ~20× past the properly-capped gross figure,
and collapse `breakEvenWinRate` toward 0 — making the `clearsCost` gate toothless for
exactly the degenerate setups it exists to catch. `grossRR` itself stays the true
uncapped ratio (still useful for display). Invariant `grossRR ≥ netRR` for any positive
cost is pinned by `StockSageMoneyInvariantSweepTests.grossRRneverBelowNetRR_costSweep`.

## 2. Shipped cost assumptions (default round-trip, bps of notional)

Owner-gated, research-informed, current-era-revalidated 2026-07-03
(`research/INDEX.md` → `RESEARCH_2026-07-03_current_era_costs.md`). Changing the table
is an **owner decision** — research informs, it does not edit.

| Suffix | Asset class | Round-trip (bps) | Revalidation note (2026-07-03) |
| :--- | :--- | ---: | :--- |
| US | US equities | 13 | accurate-to-slightly-high (effective ~0.5–9 bps post-PFOF) |
| intl | International equities | 30 | accurate for liquid; **too low** for small/illiquid/EM |
| crypto | Cryptocurrencies | 70 | venue-spanning 4–400 bps |
| FX | Foreign exchange | 7 | conservative (~1.5 bps real EUR/USD) |
| index-ETF | Index ETFs | 8 | conservative (~0.5 bps SPY/IVV/VOO) |

Only the DANGEROUS-direction errors (gate passes losers) are small/illiquid-intl and
casual-retail crypto; the other three err SAFE (over-refuse).

## 3. Honesty floor
- **Labeling:** gross metrics always labeled "gross", net always "net". The engine never
  relabels a gross number as net (F03/F44 weekly netting stays gross-labeled — owner-gated).
- **Visibility:** costs **demote** viability (rank penalty / `clearsCost=false`), they never
  hide an idea. `nil` stays `nil` (unknown, never a fabricated cost).
