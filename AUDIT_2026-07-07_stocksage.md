# AUDIT — StockSage not-recently-verified surface (2026-07-07)

Owner-directed ("audit and review the code then improve stocksage"), 24h autonomous run.
Fleet: 5 read-only lenses (2 Opus / 2 Fable / 1 Sonnet, all xhigh) over the last-24h diffs +
Store/concurrency + non-money seams + honesty surfaces + test gaps; every MED+ finding
adversarially verified by TWO refute-by-default agents (Opus + Fable). Money-math core EXCLUDED
(3-way blind-verified clean earlier this cycle). Plan: `plans/PLAN_2026-07-07_stocksage_audit_improve_wave.md`.
Fixes shipped in the same-day dev-log entry; this is the disposition ledger.

## FIXED (both verifiers CONFIRMED; shipped 2026-07-07)
| ID | Sev | File | Bug | Fix |
|----|-----|------|-----|-----|
| L4-1 / F2 | HIGH | StockSageExpectedValue.swift netExpectedWeeklyR | 0.70 concentration haircut computed on the UNDEMOTED lane while the net velocities are summed over the earnings/liquidity-DEMOTED top-N → haircut decided by a different top-3 than the one summed | forward `earnings:`/`liquidity:` to the `fastLaneConcentration` call (its own contract requires the same demoted top-3) |
| L2-01 | MED | MarketsTodayActionsCard.swift | "Today's plan" a11y label dropped entry/stop/target + shares/$-at-risk — VoiceOver heard the verdict but never the order | append the order levels + size to the label (mirrors bestOpportunityCard) |
| L2-02 | MED (Opus) / LOW (Fable) | MarketsTodayActionsCard.swift | Entry/Stop/Target + size rows could truncate a shown money figure under Dynamic Type / narrow width | `.fixedSize(horizontal:false, vertical:true)` on both rows (wrap, not truncate) |
| L3-01 | MED | StockSageStore.swift refresh() | `newListings` assigned BEFORE the two non-destructive bail guards → a failed/partial refresh wiped the new-listing honesty flags while keeping old rows (cached IPO placeholder-flat then read as a real 0.00% move) | move the assignment to just before `replaceAll`, after both bails |
| L3-02 | MED | StockSageStore.swift runBacktest() | `backtestSymbol` set before the ToolPolicy early-return but result cleared after → with web off, prior symbol's backtest shown under the new symbol's name | move the `backtest/backtestTrail/underwater = nil` clears above the early-return |
| L3-05 | MED | StockSageHistoryCache.swift panel(from:) | offline net-cost sim panel intersected EXACT bar timestamps; Yahoo stamps each 1d bar at its exchange session-open instant → any mixed-market universe shared 0 dates → null/degenerate panel | bucket by UTC dayKey (same `Int(ts/86400)` the engine's `alignByDate` uses) |
| F1 (test-gap) | MED | StockSageExpectedValueTests.swift | `fastLaneConcentration`'s earnings/liquidity params were never exercised by a test | new `fastLaneConcentrationRespectsEarningsAndLiquidityDemotion` (also covers L4-1's mechanism); + `panelBucketsByUTCDayAcrossExchangeSessionOffsets` for L3-05 |

## PARKED (owner-gated — refuse, don't proceed)
- **L4-2 (MED)** — `expectedWeeklyR` (GROSS) and its dependents (`expectedWeeklyDollars`,
  `assumedWeeklyRoundTrips`, `weeklyTurnoverNote`, `summary`.weeklyR) have no earnings/liquidity
  params, so the gross weekly figure sums the UNDEMOTED lane while adjacent surfaces show the
  demoted top-3. Opus: "internally self-consistent, NOT internally wrong" — the display diverges.
  Whether the gross weekly-R should reflect earnings/liquidity demotion is a product choice on the
  **F03/F44 weekly-rollup surface (owner-gated)**. **BLOCKED: owner call** — fixing L4-1 (the net
  figure's internal inconsistency) is independent and was shipped; the gross-lane alignment waits.

## DOWNGRADED / REFUTED (recorded, not fixed — no live user-visible defect)
- **L3-06 (SPLIT → REFUTED)** — Opus flagged `refreshRiskParity` writing a pre-await positions
  snapshot post-await with no reconcile; Fable refuted with evidence. VERIFIED: MarketsView.swift:1257
  suppresses the plan with a refresh notice when `liveSymbols != sizedSymbols` (the two books differ),
  so the stale-plan-attributed-to-wrong-book scenario never reaches the user. Engine-layer reconcile
  = defense-in-depth, not a live bug. Note only.
- **L3-03 (Opus DOWNGRADE / Fable CONFIRMED)** — `mergeLiveQuotes`/`addSymbol` drop
  `LiveQuote.isNewListing`; in watchlist-only mode refresh() (the only `newListings` writer) is paused,
  so the flag can't appear on those paths. Narrow (watchlist-only + a brand-new listing); honesty-soft
  (a missing badge, not a fabricated number). Candidate for a later newListings-integrity pass.
- **L3-04 (Opus DOWNGRADE / Fable CONFIRMED)** — the detached history-cache save wholesale-replaces
  the file with only the just-fetched histories, so a rate-limited partial scan drops previously-cached
  candles. Self-heals on the next full scan; matters mainly to the offline-panel research axis.
  Candidate for a merge-into-existing-cache fix when that axis is worked.
- **L2-02** — fixed (cheap defensive modifier) despite Fable's LOW.
- **F2 (test-gap, both DOWNGRADE→LOW)** — `signalBlocks(_:color:)` round(value*5) mapping untested;
  trivial, UI-cosmetic. Low priority.
- **L3-07..L3-10 (LOW)** — portfolio-analytics stale-book (same class as L3-06, display-guarded),
  `parseChart` previousClose>0 (LOW honesty edge), monitor cancellation double-push, retryFailedIdeas
  skipping side-effects. Recorded; none is a live money-surface defect.

## CLEAN (lenses reported sound)
Recorded in the audit fleet output — honesty-floor label duties on the shipped surfaces, paper-trader
store isolation, alert dedup/freshness gates, the brake-chain order, and the earnings/liquidity
threading through the fastLane/rank surfaces (the two gaps above excepted) all verified sound.
