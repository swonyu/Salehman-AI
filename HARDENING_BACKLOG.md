# Hardening backlog (salehman-hardening-sweep wg68kzyx6, 2026-06-22)

50 agents · 2.4M tokens · 71 raw findings → 20 confirmed bugs → 33 ranked items. Adversarially verified against source.

## Summary
Merged and deduplicated the two input lists (18 bugs/honesty items + 24 features/test-gaps) into one value-to-effort ranked backlog of 33 items. I verified the top-ranked claims against source: the playbook 1%-label drift (StockSageExpectedValue.swift:186/202 — playbook() takes no fraction, hardcodes "1%/trade" while summary() accepts a variable fraction at :168), the monitor dedup leak (StockSageMonitor.swift:89/94 — line 89 already guards NEW-or-FLIPPED so consecutive-poll same-state IS deduped, but line 94's `lastAlerted = nowStrong` drops symbols that left strong, so strongBuy→hold→strongBuy re-alerts; downgraded from high to medium), and the breakeven-trade exclusion (StockSageJournal.swift:370-371 — realizedProfit==0 trades match neither wins>0 nor losses<0 and vanish from holdingPeriod). I corrected several reported line numbers that had drifted (MarketsView weekly-$ lines, QuoteService :117 new-listing fallback) but the underlying facts hold. Ranking principle: confirmed label-vs-math honesty bugs and silent data-exclusion bugs first (they violate the honesty floor and bias real metrics), then high-value risk safeguards that are cheap to add (PortfolioHeat, TimeStop), then the color/caveat honesty UI polish (batchable), then the GE/OSRS money features, then the boundary test-gaps (high value, small effort, can be done as one sweep), with speculative/lagging-signal features (sector rotation, relative strength, pyramiding) ranked last. Dedup notes: the three PortfolioHeat entries (engine + honesty-gap + UI) collapsed to one ranked item; the partial-profit ladder honesty-gap and feature collapsed to one; the GE-glossary-volume honesty item and the volume-aware fill-confidence feature are kept separate (one is a one-line copy fix, the other needs a data source) but cross-referenced.

## Top actions
- Fix the playbook 1%-label-vs-math drift: thread riskFraction through StockSageExpectedValue.summary()→playbook() and render Int(riskFraction*100) instead of hardcoded "1%/trade" at line 202 (honesty-floor violation, ~15 min).
- Stop the holdingPeriod metric from silently dropping breakeven trades (StockSageJournal.swift:370-371): count realizedProfit==0 separately or fold into the non-win bucket so avgWinDays isn't biased by an invisible sample.
- Fix the monitor alert dedup so a strongBuy→hold→strongBuy round-trip does not re-fire (StockSageMonitor.swift:94): persist last-alerted per symbol across non-strong states instead of overwriting with only currently-strong symbols.
- Add the PortfolioHeat engine + Markets header gauge (sum open $-at-risk ÷ account, green<5% / yellow<10% / red>10%) — the single highest-value missing risk safeguard; a trader can stack 10×1% trades and not see 10% live exposure.
- Batch the StockSage boundary test-gap sweep (Kelly R=1 edge, RewardRisk 1.4999/2.4999, NetEdge cost==reward, PositionSizer rounds-to-0-shares, Journal profitFactor==1.0, RiskOfRuin fraction→0.99, etc.) — all small, all high-value, one PR.

## Backlog
### ✅ DONE #1 — Playbook hardcodes "1%/trade" but summary() uses a variable fraction  [high/small, honesty]
**File:** Salehman AI/StockSage/StockSageExpectedValue.swift
**What:** summary() (line 168) accepts fraction:Double=0.01 and computes worstRunDrawdownPct from it, but playbook() (line 186) takes no fraction and hardcodes "(losses) at 1%/trade ≈ -X%" at line 202. Called with fraction=0.02 the drawdown is computed at 2% while the label says 1%.
**Why:** Direct label-vs-math drift on a RISK number — the exact honesty-floor violation the owner forbids. Confirmed in source.

### ✅ DONE #2 — holdingPeriod silently excludes breakeven (realizedProfit==0) trades  [high/small, bug]
**File:** Salehman AI/StockSage/StockSageJournal.swift
**What:** Lines 370-371 filter wins as profit>0 and losses as profit<0; a closed trade with realizedProfit==0 matches neither and vanishes from avgWinDays/avgLossDays and the win/loss counts. Confirmed in source.
**Why:** Biases the discipline metric by dropping a real holding-period sample invisibly. Add an avgBreakEvenDays bucket or fold breakeven into the non-win average.

### ✅ DONE #3 — Alert dedup re-fires on strongBuy→hold→strongBuy round-trip  [high/small, bug]
**File:** Salehman AI/StockSage/StockSageMonitor.swift
**What:** Line 89 already guards so the SAME strong state on consecutive polls does NOT re-alert (severity is therefore medium, not high). But line 94 `lastAlerted = nowStrong` drops any symbol that left strong, so a symbol that goes strong→hold→strong fires the identical alert again. Persist last-alerted per symbol across non-strong states; only reset on a genuine flip.
**Why:** Repeats an alert the user already saw — erodes trust in the notification, the one push surface.

### ✅ DONE #4 — PortfolioHeat: live open-risk exposure gauge (engine + Markets header)  [high/medium, feature]
**File:** Salehman AI/StockSage/StockSagePortfolioHeat.swift (new) + Views/MarketsView.swift
**What:** New nonisolated StockSagePortfolioHeat.compute(openTrades:accountSize:) summing shares·|entry-stop| ÷ account → heatPct + verdict + caveat. Render on Markets header: green<5%, yellow<10%, red>10%, tap for per-trade breakdown. Dedup: merges the three input entries (engine, honesty-gap, UI).
**Why:** Highest-value missing safeguard: 10 trades @1% = 10% live exposure that a gap hits all at once, with no current surface showing it. Caveat must note correlated gaps.

### ✅ DONE #5 — StockSage engine boundary test-gap sweep  [high/medium, test-gap]
**File:** Salehman AITests/StockSageTests.swift
**What:** One PR adding the missing boundary tests: Kelly W=0.70/R=1→edge=0.40 (R=1≠zero edge); RewardRisk 1.4999→poor & 2.4999→fair (>= not >); NetEdge cost==grossReward→netRR=0; PositionSizer tiny account→0 shares; Journal profitFactor==1.0 & breakeven expectancy≈0; classifyHealth PF==1.5 boundary; RiskOfRuin fraction=0.99 near-wipeout; rMultiple exact +1R; Rebalance negative-holding→0; VelocityHistory maxDays<=0→keeps 1; Currency all-zero→nil; GEFlip budget==one-flip-capital.
**Why:** All are silent off-by-one / sign-flip risks on money math, each tiny, batchable into a single green sweep. High value per minute.

### ✅ DONE #6 — MoneyVelocitySummary should expose the riskFraction it used  [medium/small, honesty]
**File:** Salehman AI/StockSage/StockSageExpectedValue.swift
**What:** Add riskFraction:Double to MoneyVelocitySummary (return block lines 174-181) so callers/UI can verify which fraction produced worstRunDrawdownPct, and pass it into playbook() (pairs with rank 1).
**Why:** Removes opacity behind the brake estimate; small follow-on to the rank-1 fix.

### ✅ DONE #7 — TimeStop engine (age-based exit / dead-money flag)  [high/medium, feature]
**File:** Salehman AI/StockSage/StockSageTimeStop.swift (new) + StockSageAdvisor.swift
**What:** nonisolated static func suggest(openedAt:now:daysToHold:) -> TimeStopSuggestion?(shouldExit,daysHeld,daysRemaining,rationale). Add TradeRecord.daysHeld computed prop; flag in RiskFlags when isOpen && daysHeld>daysToHold. Test exact day boundaries, nil dates, same-day=0.
**Why:** Directly serves "make money faster": frees capital from stale positions. Pure discipline rule, not a signal — honest by construction.

### ✅ DONE #8 — Weekly-$ velocity estimate rendered in success-green overstates confidence  [medium/small, honesty]
**File:** Salehman AI/Views/MarketsView.swift
**What:** The "≈ +$X/week … NOT income" line (and the fast-lane strip twin) renders in DS.Palette.successSoft green, visually reading as a guaranteed win. Move the $ figure to .secondary, lead with the hedge, keep green only for labeled risk warnings. (Reported line numbers drifted; locate by the format string "+$%.0f/week".)
**Why:** Green + plus-sign on a money estimate conflates risk with reward — undercuts the inline caveat.

### ✅ DONE #9 — GE flip gp/hour glossary caveat understates volume dependency  [medium/small, honesty]
**File:** Salehman AI/StockSage/StockSageGlossary.swift
**What:** Line 67 says "assumes you fill the limit; real fills depend on volume." For an item trading 50/day, trying to move 500 makes gp/hour off by ~90%. Extend the copy: for <100 trades/day actual gp/hour may be 10-50% of the estimate; re-check after each flip. One-line copy change.
**Why:** Cheapest honesty fix in the set; the gp/hour number is the OSRS headline metric and is most wrong exactly where it looks best (illiquid items).

### ✅ DONE #10 — Growth/what-if projections color-coded as warning/danger over-dramatize a neutral estimate  [medium/small, honesty]
**File:** Salehman AI/Views/MarketsView.swift
**What:** "What-if (HYPOTHETICAL) … 100 trades ≈ ×Z" renders in warningSoft yellow when multiple>=1 and danger red when <1, reading as "this will lose" rather than a variance path. Render the line in .secondary; the strong NOT-a-prediction caveat already carries the weight.
**Why:** Color over-emphasizes a neutral compounding estimate as a forecast. Batch with rank 8 (same file, same fix pattern).

### ⬜ #11 — Caveat-presence regression test (MoneyVelocityCopy strings used in views)  [medium/small, test-gap]
**File:** Salehman AI/StockSage/StockSageGlossary.swift
**What:** No automated check that the honesty caveats in MoneyVelocityCopy actually appear in a view. Add a test that greps the view sources for each constant name so a future refactor that drops a caveat fails CI.
**Why:** The caveats ARE the honesty floor; their silent removal is a compliance bug. Cheap insurance.

### ⬜ #12 — Velocity-hold calibration note vs journal actuals  [medium/medium, honesty]
**File:** Salehman AI/StockSage/StockSageExpectedValue.swift
**What:** Add calibrationNote(journalTrades:assumes:VelocityHoldDays)->String? computing actual avg hold by asset class from closed trades and returning a note when it diverges >20% from the tuned assumption (crypto 3d, equity 12d). Surface on the velocity card.
**Why:** If the owner actually holds crypto 5d vs the assumed 3d, every velocity rank is silently off ~67%. Closes a real drift between assumption and measured behavior.

### ⬜ #13 — Buy-limit-aware ROI%/capital-efficiency ranking for GE flips  [high/medium, feature]
**File:** Salehman AI/StockSage/StockSageGEFlip.swift
**What:** Add GEFlipMetric{gpPerHour,roiPercent,gpPerHourPerCapital}, roiPercent(buy:sell:rate:), gpPerHourPerCapital(=profitPerItem/buyPrice), and bestFlipsForBudgetByROI(budget:). Make fastestFlipsStrip sort toggle (default gp/hour). Tests for roiPercent + ROI-sorted budget.
**Why:** For a fixed account capital is the bottleneck; pure gp/hour picks capital-hungry flips with worse efficiency. Surfaces fast-recycling flips. Caveat: assumes 4h tie-up.

### ⬜ #14 — Volume-aware fill-confidence badge for GE flips  [high/medium, feature]
**File:** Salehman AI/RuneScape/RuneScapeMarketService.swift
**What:** When volume data is available, add VolumeProfile{crisis<10,thin<100,liquid<1000,deep} and fillConfidence(margin:volumePerDay:buyLimit:)->(score,caveat); show ⚠ "Low volume — may not fill in 4h" when <0.5. Until volume data exists, add a manual "Known thin market?" toggle on listingRow.
**Why:** gp/hour with no liquidity notion is the single most misleading OSRS surface. Pairs with rank 9's caveat fix. Larger effort because it needs a volume source (RuneLite/official API).

### ✅ DONE #15 — Partial-profit ladder (scale-out) engine + journal wiring  [high/medium, feature]
**File:** Salehman AI/StockSage/StockSageProfitLadder.swift (new) + Views/MarketsView.swift
**What:** struct ProfitLadder/ProfitLevel; StockSageProfitLadder.suggest(entry:stop:target:accountRisk:) returning rungs (e.g. 33% at +1R/+2R/+3R) with caveat "reduces variance, sacrifices extreme winners." Wire into trade-plan export + journal (planned vs actual rungs). Dedup: merges the honesty-gap + feature entries.
**Why:** Without a ladder the UI silently nudges binary all-or-nothing exits; scale-out enforces discipline. Caveat is load-bearing.

### ⬜ #16 — Tax-aware NET margin chip everywhere in the OSRS UI  [medium/small, feature]
**File:** Salehman AI/Views/RuneScapeMarketView.swift
**What:** listingRow shows gross margin (high-low) with a pre-tax tooltip but the number itself is gross. Add a second "(net: +Xk)" chip = margin-2% tax, color green if margin>tax, yellow if <2×tax, red at breakeven. Test netMarginAfterTax.
**Why:** Casual players read 100k margin as 100k profit, not 98k. Concrete honesty improvement, small.

### ⬜ #17 — Compounding curve clamped at 0 needs wipeout labeling  [medium/small, bug]
**File:** Salehman AI/StockSage/StockSageJournal.swift
**What:** Line 236 `mult = max(0, mult*(1+fraction*r))` correctly stops compounding but freezes silently at 0. Either return Double? with nil=wipeout, or add caveat "a value of 0 means the account was wiped out on this or an earlier trade." Math is fine; UI honesty only.
**Why:** A flat-at-0 curve reads as "stuck" rather than "ruined"; mislabels the most important outcome.

### ⬜ #18 — New-listing 0%-move quote needs an isNewListing flag surfaced in UI  [medium/small, correctness]
**File:** Salehman AI/StockSage/StockSageQuoteService.swift
**What:** Line 117 falls back to current price as previousClose for brand-new listings (→0% move→hold). Add LiveQuote.isNewListing (previousClose==price) and render "N/A (newly listed)" instead of "0% (hold)" on the ideas board. Confirmed at :114-118.
**Why:** A freshly-IPO'd stock shows as flat when it's actually unevaluated — the user mistakes no-data for a real hold signal.

### ⬜ #19 — Kelly position sizing: optional cost/slippage haircut  [medium/medium, feature]
**File:** Salehman AI/StockSage/StockSageKelly.swift
**What:** Add optional CostProfile(commissionPct,slippagePct,bidAskPct); compute()? reduces suggested fraction by net-of-cost edge and exposes costAdjustment + updated caveat; costs>edge → zero size. Test cost cuts fraction and zero-edge case.
**Why:** 10-50bps round-trip costs quietly eat a 1% edge; forcing the owner to name them is honest and changes sizing.

### ⬜ #20 — Closed trades with entry==stop (no R) silently dropped from edge stats  [low/small, bug]
**File:** Salehman AI/StockSage/StockSageJournal.swift
**What:** Line 469 compactMaps realizedR; a CLOSED trade with entry==stop has realizedR=nil and vanishes, shrinking sample size invisibly. Count no-defined-risk closed trades and flag them, or reject entry==stop at TradeRecord.init.
**Why:** Lowers the edge sample without telling the user; for a closed trade zero-risk is anomalous and should be flagged not hidden.

### ⬜ #21 — Fast-lane concentration warning lacks a concrete sizing rule  [low/small, honesty]
**File:** Salehman AI/Views/MarketsView.swift
**What:** "closer to ONE bet, not N" asserts correlation without a rule. Strengthen: "...likely correlated; size all N TOGETHER at 1-2% total, not per symbol." Applies to summary card + fast-lane strip.
**Why:** Turns an alarming-but-vague warning into an actionable risk rule; cheap copy change batchable with ranks 8/10.

### ⬜ #22 — Conviction meter needs an "estimate, not probability" label  [low/small, honesty]
**File:** Salehman AI/Views/MarketsView.swift
**What:** convictionMeter renders a 0-1 fill with no label; users read 70% fill as 70% win probability. Add label/tooltip mapping conviction→estimated win-prob (per winProbEstimate ~35-58%) with "not a forecast."
**Why:** Prevents conflating a rules-based conviction with a real probability. Small.

### ⬜ #23 — Idea detail: stop/target are quote-time and drift intraday  [low/small, honesty]
**File:** Salehman AI/Views/MarketsView.swift
**What:** Stop/Target shown as fixed numbers against the current quote; viewing an hour later changes R:R silently. Add note "Stop & Target computed at <generatedAt> — recalculate before entry."
**Why:** Stale R:R can quietly violate the user's intended risk. Small note.

### ⬜ #24 — Realized P&L green number needs a "record, not promise" label  [low/small, honesty]
**File:** Salehman AI/Views/MarketsView.swift
**What:** ideaMetric "Realized P&L" renders green when positive with the caveat buried elsewhere. Prefix "✓ Realized" or add tooltip "Closed trades only — a record, not a promise of future results."
**Why:** Quick-scan green number reads as a forward fact. Trivial, batch with the other MarketsView honesty polish.

### ⬜ #25 — GE tax cap (5M) is undated and not parameterized  [low/small, honesty]
**File:** Salehman AI/StockSage/StockSageGEFlip.swift
**What:** Line 48 hardcodes taxCap=5_000_000; line 50 dates the 2% rate but not the cap. Add "capped at 5M/item since <date>; verify vs current OSRS rules" and/or parameterize the cap alongside rate.
**Why:** If Jagex changes the cap the estimate goes silently wrong. One comment + optional param.

### ⬜ #26 — R-distribution skew/kurtosis (fragile vs robust shape)  [low/small, feature]
**File:** Salehman AI/StockSage/StockSageJournal.swift
**What:** Add skew + kurtosis to RDistribution (standard 3rd/4th moments) with UI note "left skew = fragile, right skew = robust." Test all-equal→skew0/kurt3.
**Why:** Tells the owner whether the edge is fat-tailed-robust or choppy-fragile. Low value but small.

### ⬜ #27 — OSRS multi-flip rotation under a time budget  [medium/medium, feature]
**File:** Salehman AI/StockSage/StockSageGEFlip.swift
**What:** Add RotationPlan + flipsPerSession(hours)=floor(hours/4) + chainFlips(flips:startingCapital:hours:) greedily reinvesting profit into the next flip. Collapsible strip section. Test chaining + loss-streak shrink.
**Why:** Models how players actually chain flips across a session; turns static allocation into a realistic plan. Caveat: ignores GE-clearing delays/partial fills.

### ⬜ #28 — OSRS capital-growth projection over N cycles  [low/medium, feature]
**File:** Salehman AI/StockSage/StockSageGEFlip.swift
**What:** CapitalGrowthProjection + projectGrowth(plan:cycles:) reinvesting profit; expandable section with a 1-50 cycle slider. Caveat: assumes every fill hits margin and all profit reinvested. Test + negative-margin cycle.
**Why:** Shows compounding from flipping; motivational but overlaps the chain-flips feature (rank 27) — sequence after it.

### ⬜ #29 — OSRS margin-decay age-weighting of stale quotes  [medium/medium, feature]
**File:** Salehman AI/RuneScape/RuneScapeModels.swift
**What:** Add ageSeconds + marginFreshness=exp(-age/3600) + discountedMargin on RuneScapePrice; apply to ROI/gp/hour rankings, show age badges + tooltip. Test decay + stale-lowers-ranking.
**Why:** A 2h-old quote can disguise a dead margin; freshness weighting de-risks the ranking. Explicitly an ESTIMATE (API refresh varies by item).

### ⬜ #30 — OSRS alch-vs-flip comparison  [medium/large, feature]
**File:** Salehman AI/Views/RuneScapeMarketView.swift
**What:** Add RuneScapeItem.alchValue:Int? (curate top ~50), AlchVsFlipComparison + shouldAlchVsFlip(alchValue:flipProfit:) (alch wins if >10% better), badge + sortable Alch tab. Test alchedGpPerHour vs flipped.
**Why:** Real bypass: alch is instant + no GE tax for many items. Large because it needs an external alch-value data source/curation.

### ⬜ #31 — Sector-rotation confirmation signal  [medium/medium, feature]
**File:** Salehman AI/StockSage/StockSageSectorRotation.swift (new)
**What:** SectorRotationSignal + analyze(allTrades:minTrades:) grouping closed trades by sector, ranking realized R/trade; top-3 = rotating in. Apply ±0.10 conviction nudge. Test stable ranking, nil on too-few, lag caveat.
**Why:** Real but LAGGING (half-priced-in by the time it fires) — a confirmation aid, not a standalone edge. Ranked below safeguards.

### ⬜ #32 — Relative-strength ranking across the book  [low/medium, feature]
**File:** Salehman AI/StockSage/StockSageRelativeStrength.swift (new)
**What:** RelativeStrength + rank(holdings:) on 1-month returns, percentile 0-1; strongest +0.10 / weakest -0.10 conviction nudge. Test monotonic rank, percentile bounds, single-holding edge.
**Why:** A tiebreaker when signals conflict, not a primary edge; both momentum and mean-reversion exist so value is modest.

### ⬜ #33 — Pyramiding (scale-in) rule engine  [low/medium, feature]
**File:** Salehman AI/StockSage/StockSagePyramiding.swift (new)
**What:** PyramidLevel + suggest(initialSize:account:riskCap:): tier1 full, tier2 50% at +0.5R, tier3 50%-of-tier2 at +1.5R, total risk<=cap. Test shrinking sizes, ordered triggers, cap respected, caveat present.
**Why:** Locks early risk but needs more capital and assumes the trend holds (false in chop). Most speculative/dangerous of the features — last. Caveat "only if it runs, never force it" is load-bearing.
