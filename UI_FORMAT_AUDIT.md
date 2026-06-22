# UI display-honesty audit (w3r6h3yl5, 2026-06-22)

9 CONFIRMED display bugs. #2/#3/#4 (sub-dollar P&L %+.0f→%+.2f) DONE. #1 (cost-basis-as-value launder, HIGH) + #5-#9 (polish/width) left. RE-VERIFY vs source.

### ⬜ #1 [high] — Portfolio summary launders cost basis into "Portfolio value (USD)" and shows green +$0.00 P&L when holdings have no live price
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:582 (value fold), 628/643/645 (fabricated green P&L), 635 (headline)
**fix:** In portfolioTotals (576-585) stop substituting cost basis into market value: for each position get `guard let px = currentPrice(p.symbol) else { unpriced.append(p.symbol); continue }` and only add `holdingValue(p.symbol, perShare: px, shares: p.shares) * rate` to `value` (return an `unpriced:[String]`). In portfolioSummary (626-655), when `unpriced` is non-empty render the value as a priced-only subtotal (label it "priced holdings only") and replace the colored `+$0.00 (+0.0%)` at line 643 with a neutral "P&L unavailable — N holdings have no live price" note, mirroring the per-row "— no price" honesty at line 720/724 and the cachedBanner pattern. Do not let `up = pl >= 0` paint green at pl==0 when coverage is incomplete.

### ✅ DONE #2 [high] — Open-trade unrealized P&L uses %+.0f — a real sub-dollar loss prints as red "-0" (and VoiceOver says "unrealized +0")
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:1469 (and accessibility label 1510)
**fix:** Change line 1469 to `Text(String(format: "%+.2f", pnl))` and the accessibility label at line 1510 to `pnl.map { String(format: ", unrealized %+.2f", $0) }`. pnl = trade.profit(at:) is a raw (price-entry)*shares Double with shares typed Double, so sub-$1 deltas are routine; %.0f maps -0.30 to "-0" while the color test keeps it red.

### ✅ DONE #3 [high] — Closed-trade realized P&L uses %+.0f — a real sub-dollar realized win/loss prints as signed zero in the per-trade ledger
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:1520 (and accessibility label 1532)
**fix:** Change line 1520 to `Text(String(format: "%+.2f", pnl))` and the label at line 1532 to `realized \(String(format: "%+.2f", pnl))`, matching the %.2f entry/exit prices at line 1518. realizedProfit is a full-precision Double; -0.45 currently renders red "-0" — misleading per-trade data the user reconciles against a broker.

### ✅ DONE #4 [medium] — Journal headline "Realized P&L" uses %+.0f — sub-dollar total realized P&L shown as colored "+0"/"-0"
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:1075
**fix:** Change to `String(format: "%+.2f", s.totalProfit)` to match this file's dollar convention (line 635 $%.2f; adjacent Total R/Avg R use %+.2f). s.totalProfit is a continuous Double sum; with the color keyed off `s.totalProfit >= 0`, a true +0.40 reads green "+0" and -0.40 reads red "-0". Bounded to |P&L|<$0.50 but it is the trusted headline figure.

### ⬜ #5 [low] — Total-P&L percent uses %+.1f%% — a real sub-0.05% move reads as a signed "-0.0%" while the line is colored down/up
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:643
**fix:** Use `String(format: "$%.2f (%+.2f%%)", pl, plPct)` (2-decimal percent), or apply the same ±0.05% flat band the watchlist signalCard uses at lines 1883-1884 and render "flat"/secondary color when abs(plPct) is within band, instead of a signed "-0.0%". The dollar part (.2f) is already honest; only the percent decimal flattens sub-0.05% moves.

### ⬜ #6 [low] — Avg win / Avg loss render a hardcoded sign on a legitimately-zero value → "+0.00R" / "−0.00R"
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:1084-1085 (guarded by edge.closedWithR > 0 at 1080)
**fix:** Gate each metric on a non-zero magnitude with a "—" fallback, mirroring the adjacent Payoff/PF metrics (1086-1088): `ideaMetric("Avg win", edge.avgWinR > 0 ? String(format: "+%.2fR", edge.avgWinR) : "—", color: DS.Palette.successSoft)` and `ideaMetric("Avg loss", edge.avgLossR > 0 ? String(format: "−%.2fR", edge.avgLossR) : "—", color: DS.Palette.danger)`. avgWinR/avgLossR are `wins/losses.isEmpty ? 0` (StockSageJournal.swift:492-493), so an all-wins (or all-losses) early journal prints a sign+color on a zero the trader never had. Magnitude shown is 0.00 (no false quantity).

### ⬜ #7 [low] — gp/hour velocity uses Int() truncation toward zero — a sub-1-gp/hr positive edge truncates to "0"
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:219, 248, 299
**fix:** Round instead of truncate at all three call sites: `RSFormat.gp(Int(flip.gpPerHour.rounded()))` (219), `RSFormat.gp(Int(plan.totalGpPerHour.rounded()))` (248), `RSFormat.gp(Int(gph.rounded()))` (299). gpPerHour is a Double = profit*buyLimit/4h; Int() floors 999.7→999 and a (0,1) edge (e.g. 0.25) →0 = "0". Strictly non-negative so no sign flip and ranking uses the raw Double; gp() itself is honest.

### ⬜ #8 [low] — ideaMetric value Text has no minimumScaleFactor — unbounded % acct / Notional / dollar metrics can clip on narrow layouts
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:3251 (covers the % acct call site at 2798-2799)
**fix:** Add `.lineLimit(1).minimumScaleFactor(0.7)` to the value Text at line 3251 (matching line 1726's existing usage). pctOfAccount (notional/account*100) is unbounded — a tight stop yields four-digit "%" and the sibling Notional prints "$200000"; one fix protects every ideaMetric call site. The value is honestly colored red + paired with leverage warnings (2814-2821), so this is width-fit only, not misleading.

### ⬜ #9 [low] — RSFormat.gp default/negative-margin branch prints up to 7-8 glyphs into fixed 64pt/70pt columns with no scale-down
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:347-357 (priceColumn width 64), 313-318 (margin chip width 70)
**fix:** Add `.lineLimit(1).minimumScaleFactor(0.7)` to the priceColumn value Text (line ~355) and the margin-chip Text (line ~313), or widen the frames (64→72, 70→80). priceColumn renders only non-negative prices (worst case '99,999'/'999.99M', 6-7 glyphs); the sign-prefixed margin chip can be '-999.9K'/'+999.99M' (7-8 glyphs) and touches/overflows the fixed width with no minimumScaleFactor. Cosmetic crowding only — the digits are correct.
