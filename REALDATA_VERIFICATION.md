# Only-real-data verification sweep (wtexg5a6u, 2026-06-22)

4 remaining honesty findings (surfaces heavily hardened, NOT perfectly clean). #1 (trade-gate self-contradiction, risk%=0) DONE. RE-VERIFY rest vs source.

### ✅ DONE #1 [medium] — Trade GATE self-contradicts: detail sheet says BLOCKED while the copied broker plan says clear, for the same idea (Risk % = 0)
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:2989 (vs 2411-2416 → StockSageTodayPlan.swift:27)
**fix:** Floor the detail-sheet riskFraction the same way TodayPlan.build does. Change MarketsView.swift:2989 from `let rf = Double(sizerRiskPct).map { $0 / 100 } ?? 0.01` to `let rf = StockSageInput.positiveAmount(sizerRiskPct).map { $0 / 100 } ?? 0.01` (or match the sibling pattern at lines 1167/2491: `Double(sizerRiskPct).flatMap { $0 > 0 ? $0 / 100 : nil } ?? 0.01`). This makes 0/negative/garbage fall back to 0.01 on both surfaces so StockSageTradeGate.evaluate sees the same riskFraction and the go/no-go verdict can no longer disagree. Belt-and-suspenders: validate sizerRiskPct positive-only at the journalField input (line 2832).

### ⬜ #2 [medium] — OSRS flips strip + budget optimizer rank a phantom edge from mismatched-age legs with no staleness label
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/StockSage/StockSageGEFlip.swift:79-91 (rendered RuneScapeMarketView.swift:206-269)
**fix:** StockSageGEFlip.flips builds margins from l.price.low/l.price.high and discards highTime/lowTime, so the gp/hour-ranked Fastest-flips strip and the With-N-gp budget optimizer can present a stale-leg margin as a fresh, fillable edge — the per-row chip/gp-hr is already stale-guarded, but these two surfaces are not. Have flips read l.price.isStale (or |highTime − lowTime| over a freshness window) and either drop the flip or tag it; then dim and add a "one leg last traded Nh ago — margin may be stale" caveat to fastestFlipsStrip and bestFlipsForBudget, matching the per-row stale treatment already shipped in listingRow.

### ⬜ #3 [low] — Portfolio P&L percent renders a fabricated +0.0% when all cost bases are 0 but holdings are priced
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:638,656
**fix:** When t.cost == 0 but t.value > 0 the true return is undefined (infinite), yet line 656 prints a fake "(+0.0%)" beside a correct dollar P&L — unlike the rest of the view, which shows honest placeholders. Gate the percent on t.cost > 0: render the dollar P&L always and the percent only when defined, e.g. Text((up ? "+" : "") + String(format: "$%.2f", pl)) + Text(t.cost > 0 ? String(format: " (%+.1f%%)", plPct) : " (—%)"). Reachable because the add form passes `Double(newCost) ?? 0` and StockSagePortfolio.add guards only costBasis >= 0, so 0-cost holdings are storable.

### ⬜ #4 [low] — Money-velocity summary card's Est./week R projection lacks its own high-variance/not-a-promise caveat
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:2511-2513 (caveat at 2563)
**fix:** The Est./week R projection at line 2512 carries no variance/promise qualifier; the only always-on card caveat (MoneyVelocityCopy.summary, 2563) speaks to the EV ranking, not this weekly figure — while the two parallel surfaces (fastLaneStrip R at 2626, $/week at 2518) both say "high variance… Not a promise." Append the hedge to the Est./week sub at 2512 (e.g. "if you run top 3 — high variance, not a promise") or add a dedicated caveat line reusing the line-2626 copy, so all three weekly-projection surfaces are caveat-consistent.
