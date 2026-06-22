# Money-decisiveness sweep (wk3ls81vm, 2026-06-23)

12 verified signal-to-dollars gaps (33 agents). #4 earnings-gate bestOpportunity DONE. RE-VERIFY rest.

### ✅ DONE #1 [high] — Best-opportunity card omits entry/stop/target — the three levels a broker order needs
**file:** Salehman AI/Views/MarketsView.swift:2431-2448
**fix:** After the metric HStack at line 2440, add a price row mirroring the ideaCard pattern (lines 2305-2311): ideaMetric(Entry, format idea.price); when idea.advice.stopPrice non-nil ideaMetric(Stop, color danger); when targetPrice non-nil ideaMetric(Target, color successSoft). Puts ticker+side+entry+stop+target+shares+$risk on one card, no tap-through.
**$:** Turns 'this is your best bet' into a placeable order on its face — entry, stop, and target appear on the action card instead of only inside the detail sheet or an unseen clipboard blob.

### ✅ DONE #2 [high] — Open positions only show a verdict when stop/target is already hit — near-stop / in-profit / hold calls are computed then discarded
**file:** Salehman AI/Views/MarketsView.swift:1354-1362; journalOpenRow 1534-1589
**fix:** Stop filtering openActions to .isUrgent. Render the full per-position verdict — inline in journalOpenRow as a one-line act.detail colored by kind (danger=stopHit, warning=nearStop, success=inProfit/targetHit, secondary=holding), or as a non-filtered list above the rows. Model already sorts urgent-first then by |R| (StockSageJournal.swift:616-619); dropping the filter surfaces nearStop/inProfit without reordering. Every string is already an action verb (advisory only).
**$:** Surfaces the exact 'act now' calls that protect capital and lock gains: a position at -0.8R (one tick from the stop) or +2R (begging to be trailed) currently shows a number with no instruction.

### ⬜ #3 [high] — EV-ranked Ideas board (the 0-tap landing surface) shows size as an abstract % weight, never shares/$
**file:** Salehman AI/Views/MarketsView.swift:2304-2316
**fix:** In the idea-row body after Price/Stop/Target/Size, add the same one-liner the best-opportunity card uses (lines 2441-2447): when a.stopPrice, Double(sizerAccount)>0, Double(sizerRiskPct)>0 resolve, call StockSagePositionSizer.size(...) and render StockSagePositionSizer.summaryLine(ps, riskPct: rp). Keep the % weight; add the actionable share/$ count beside it. Sizer + account input already exist in this view.
**$:** The first surface the owner sees becomes directly actionable — share count + $ at risk per idea without a tap, instead of a portfolio weight they must mentally convert.

### ✅ DONE #4 [high] — Best-opportunity card is earnings-blind — boards demote an imminent-earnings name, the card/Today tile/summary still crown it
**file:** Salehman AI/Salehman AI/StockSage/StockSageExpectedValue.swift:260-273; MarketsView.swift:2418; TodayView.swift:260
**fix:** Add earnings:[String:EarningsProximity]=[:] to bestOpportunity's signature; in the .max comparator (line 271) subtract earningsRankPenalty(for:earnings:) from each side's qualityAdjustedEVR, mirroring rankByEV/rankByVelocity (keep displayed EV unchanged). Thread store.earnings through bestOpportunityCard (2418), summary() (339 + call sites 145/2542), and the Today tile (260). Default [:] keeps existing tests byte-identical. Add a regression test asserting bestOpportunity([higherEV_imminent, lowerEV_clean], earnings:)?.idea.symbol == the clean one.
**$:** Stops the four surfaces naming a different #1 on the same state: an imminent-earnings name can no longer be crowned 'Best opportunity now' when the EV board demoted it for overnight-gap risk where the stop is least likely to hold.

### ⬜ #5 [high] — Gate verdict (go/no-go) is invisible on the best-opportunity card — only a tap or a paste away
**file:** Salehman AI/Views/MarketsView.swift:2417-2477
**fix:** Compute the same StockSageTradeGate.evaluate the detail sheet uses (lines 3079-3090) and render a one-line badge (decision rawValue + fails/warns count, colored like tradeGateView at 3007-3010) directly under the metric row, so the Clear/Caution/Blocked verdict sits next to the EV that motivates acting.
**$:** Puts the discipline verdict on the same surface as the profit estimate, so a blocked/cautioned setup (no stop, risk over the 2% cap) can't be acted on as if it were clear.

### ⬜ #6 [high] — TrailingStop.recompute (the ratcheting trail) has zero callers — the stop is never re-lifted as price runs
**file:** Salehman AI/Salehman AI/StockSage/StockSageTrailingStop.swift:44-64; MarketsView.swift:1534-1589
**fix:** Wire recompute into the open-trade surface. In journalOpenRow for each open LONG, reuse the symbol's 6mo OHLC (store fetches highs/lows/closes via StockSageQuoteService.fetchHistory), map trade.openedAt to the entry bar index, call StockSageTrailingStop.recompute(highs:lows:closes:entryIndex:), and render 'Trail stop up to X.XX (was Y.YY)' only when the returned level sits above the trade's current stop. Advisory only, long-gated.
**$:** Converts every winner from a fixed-stop give-back into a ratcheted lock-in — the single highest-$ open-position action, currently computed nowhere so banked profit is surrendered on the next pullback.

### ⬜ #7 [high] — Money-velocity 'Copy plan' (playbook) — the broker-paste artifact — carries only R/weekly-R, no shares or $ at risk
**file:** Salehman AI/StockSage/StockSageExpectedValue.swift:358-380; call site MarketsView.swift:2638-2640
**fix:** Thread the owner's account/riskFraction into playbook (same values used at 2566) and, for the best-bet symbol, append concrete size via StockSagePositionSizer.size — 'Best bet now: SYM ... — N shares ~ $X at risk (Y% of acct)', mirroring StockSageTodayPlan.build (TodayPlan.swift:44-47).
**$:** The clipboard plan the owner actually pastes into a broker gains share count + $ at risk, closing the gap between 'here's the best bet' and an executable order.

### ⬜ #8 [medium] — Account size silently defaults to a phantom $10,000 — concrete shares/$ shown against an account the owner never confirmed
**file:** Salehman AI/Views/MarketsView.swift:68-69; consumed at 2441,2484,2567,2690,2930
**fix:** Mark the default unconfirmed: either start sizerAccount = empty string and gate the concrete dollar/share surfaces behind a real entry (positiveAmount returns nil on empty, so the capital card at 2484 hides correctly), or keep the $10k seed but render a persistent 'example $10,000 — set yours' tag on every $-denominated readout until the owner edits the field.
**$:** Prevents the owner acting on share counts and $-at-risk figures silently computed against a $10k account they never set — ties honest sizing to their real capital.

### ⬜ #9 [medium] — No single on-screen view carries a COMPLETE placeable order — the full ticket lives only in the clipboard
**file:** Salehman AI/StockSage/StockSageTodayPlan.swift:36-54
**fix:** Render the same StockSageTodayPlan.build output (or a compact order ticket: ticker, side, entry, stop, target, N shares, $X at risk, gate verdict) visibly on the best-opportunity card or top of the detail sheet, not only into NSPasteboard. Ranks 1+5 largely subsume this on the card; this is the consolidated 'show what you copy' framing if a single ticket block is preferred over separate rows.
**$:** Lets the owner read the full order before placing it instead of pasting an unseen clipboard string or reconstructing it from a long detail scroll.

### ⬜ #10 [medium] — Conviction — the headline action-strength number — carries no estimate/uncertainty cue while every sibling stat does
**file:** Salehman AI/Views/MarketsView.swift:3062-3064, 2295, 2339
**fix:** Surface the model's existing honesty one-liner where conviction is shown, matching the EV/velocity/regime sibling pattern. In the detail sheet append ' — signal-confluence strength, not a win probability' to line 3063 and add .help(StockSageAdvisor.caveat). On the idea card give the conviction meter the same .help(StockSageAdvisor.caveat) the EV pill already has, and add ', a rules-based estimate' to the accessibility label at 2339. Reuses StockSageAdvisor.caveat — no new numbers.
**$:** Keeps the single most-acted-on number honest: conviction stops reading as a promise at the moment of commitment, matching the estimate-not-forecast framing its sibling stats already carry.

### ⬜ #11 [medium] — Fast Lane / weekly-$ estimate are not regime-gated — a risk-off tape still presents sized 'fastest-compounding' buys after the best-bet card went dark
**file:** Salehman AI/Salehman AI/StockSage/StockSageExpectedValue.swift:279-308; MarketsView.swift:2690-2694, fastLaneStrip 2128
**fix:** Add optional regime: to fastLane/expectedWeeklyR/expectedWeeklyDollars and, when bannedFromTopRank(.buyFamily, regime:) is true, return []/nil so the fast-lane strip and weekly-$ go quiet in a risk-off tape — consistent with bestOpportunity and summary.bestSymbol. Thread store.regime at the call sites; caveats stay.
**$:** Removes the buy-side surfaces that contradict the honest sit-out — a softer version of the same 'no best bet, but here, act on this' contradiction.

### ⬜ #12 [low] — No explicit 'no good setup — sit out' state; honesty is conveyed only by absence, which the allocator/fast-lane cards visually contradict
**file:** Salehman AI/Views/MarketsView.swift:2417-2477
**fix:** Add an empty-state to bestOpportunityCard: an else-if !store.ideas.isEmpty branch stating why there's no #1 buy — 'No positive-EV buy clears the conviction/cost gate', or when store.regime is .crisis/.trendingBear 'Risk-off tape — no best buy; an intraday stop can gap. The honest move is to sit out.' Purely additive; promises no returns. Best landed with rank 11 so the sit-out message and the silenced fast-lane are consistent.
**$:** Converts honesty-by-absence into a legible call, removing the read that a lower sized card is the recommendation when the engine actually says stand aside.
