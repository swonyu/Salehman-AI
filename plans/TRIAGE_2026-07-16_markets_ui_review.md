# TRIAGE — 2026-07-16 Markets-UI full review (critique fleet wf_e4dcb906-a26)

Owner ask: **full review + improve** the Markets UI (`ideas-card-full-review`, review+fixes mode).
Fleet: 8 finder lenses → 42 raw findings → 18 adversarially verified (18 CONFIRMED / 0 REFUTED),
4 high/med hit the verifier cap (verified in-session by the implementer below), 20 lows.
Baseline HEAD `fa394d7`, tree clean, warm build green. Full finding text:
workflow journal `…/subagents/workflows/wf_e4dcb906-a26/journal.jsonl` (durable) + task output.

Rules applied: honesty floor + empirical-validation bar stand (owner-gate CLASS retired 2026-07-09).
None of the accepted items changes ranking/scoring/sizing; the three FX/currency items are
correctness bug fixes with the ratified `portfolioTotals`/`conversionCurrencyForSymbol` precedent —
display truth, not signal changes.

## FIX NOW (accepted)

| # | Sev | Site | Fix |
|---|-----|------|-----|
| A1 (C3≡C17) | HIGH | moneyVelocityCard "Copy plan" | prepend `⚠ SAMPLE DATA…` line when `store.isSampleData` (byte-identical to D2 allocation-copy prepend) — the LAST export path with no sample flag |
| A2 (C2) | MED | ideas-board Copy CSV (`StockSageIdeasCSV`) | append trailing `priceAsOf` column (ISO date, empty when nil — nil-honest); update pinned header test via pipeline |
| A3 (C4) | MED | `StockSageTodayPlan.build` | add analysis-stale flag (`generatedAt` >4h — mirrors `cardIsStale` analysis axis) beside the existing PRICE-NOT-LIVE flag; test updated |
| B1 (C0) | MED | moneyVelocityCard + fastLaneStrip weekly-$ | stop hardcoding `+$`; sign from value (a negative net week currently renders "≈ +$-42/week") |
| B2 (C12) | MED | lossLimitBanner | drop hardcoded `−` around already-negated values; sign-correct visible + a11y strings |
| C1 (C5) | MED | fastLaneStrip $/week gross parenthetical | pair net with SAME-BASKET gross (existing F9 companion API) — cross-basket pairing can print gross BELOW net |
| D1 (C6+L6) | MED | bestOpportunityCard / Today card crown-divergence | two-sided again after the hierarchy change: add suffix to bestOpportunityCard; fix the today-card caption's referent ("Best opportunity card", it never sees the CTA on Ideas) |
| E1 (C7) | MED | MarketsTodayActionsCard `orderText` | decouple the ~10bps patient-limit saving from the near-close window per the 2026-07-11 MEASURED curve (close = deepest liquidity at slightly wider ranges; midday tightest) |
| F1 (C1≡C8) | MED | `earningsWarningRow` a11y | label was self-referential ("see detail sheet" — spoken INSIDE the sheet) and dropped ep.note; speak `"Earnings risk: \(ep.note)"` |
| G1 (C14) | MED | fastLaneStrip lane-correlation row | permanent "fetching…" fixed via completed/unavailable state (MTF `mtfFetchCompleted` pattern) |
| G2 (C15) | MED | prefillTradeFromIdea | main ScrollViewReader + `scrollTo` journal anchor — "Log trade" currently lands above a below-the-fold form |
| G3 (C16) | MED | addSymbolBar autocomplete | filter suggestions against the SAME union `addSymbol` validates (board ∪ userSymbols ∪ worldwide) — stop offering '+' the engine refuses |
| H1 (C9) | HIGH | rebalancePlanView + allocationPanel | FX-pair (=X) holdings converted by EXPOSURE leg → rate² inflation (~8-27%); use `conversionCurrencyForSymbol` (the ratified portfolioTotals fix), mirror in UNWIRED satellite |
| H2 (C10) | MED | fxRatesToUSD / untrackedFXCurrencies | build rates over exposure∪conversion currencies; key the "Excludes X — no FX rate" disclaimer on the SAME key the exclusion uses (cross pairs currently drop silently) |
| H3 (C13) | MED | tradeJournalPanel Realized P&L | mixed-currency journal sums 1:1 in raw quote units (a .L trade contributes pence) — add explicit "prices as entered; mixed-currency sums not converted" disclosure when journal spans >1 quote currency |
| I1 (O3+L7) | MED | MARKETS_TAB_MAP views domain | refresh factual drift (line counts/refs, obsolete adaptivePrice sync-chore rows) |
| J1 (O2+L19) | MED | BrowseMarketsView | post-promotion catalog≡worldwide ⇒ every row "already tracked", '+' unreachable; reword header/subtitle to directory truth; fix stale comment ref. Dead add-branches left in place (harmless; catalog could diverge again) |
| K1 (O1) | MED | satellite riskParityPanel | port the `fxExcluded` disclosure (satellite silently drops no-rate targets from its rebalance plan) |
| K2 (O0) | MED | satellite riskParityPanel | port `aggregatedParity` multi-lot dedup (duplicate ForEach IDs + combined-vs-per-lot weight mispairing) |
| L-batch | LOW | smalls | L1 stale regime-caveat copy · L2 velocity sign-blind green + spoken gross qualifier · L3 CTA "sizer below" wrong tab · L8 interpolate "~2,400" tooltip · L9 unlabeled clear button · L10 sheet-nav chevron hit targets · L13 journal-reds dangerSoft (recorded deferred, now cheap) · L15 Browse Esc close · L17 alert-row truncation .help |

## VERIFY-THEN-FIX (implementer confirms in source before editing; drop to HOLD if claim fails)
- C11 (store `refreshPortfolioAnalytics` weights: no pence/FX normalization) — fix only if contained; else HOLD to its own pass. **Resolution recorded below after inspection.**
- L0≡L14 (snapshot-builder call sites pass `parsedAccount ?? 10_000` — re-fabricated default the builder's F04 gate refuses) — fix if the honest-nil path is trivially available.
- L11 (alertSignals no as-of cue) · L12 (multi-lot duplicate correlation rows) · L16 (copy-button feedback, MarketsView-local sites only).

## HOLD (not this wave — recorded, no silent drop)
- L4 — blocked-rows idle-velocity proxy hardcodes 5 trading days incl. crypto (needs the engine cadence convention threaded into MarketsTodayActionsCard; small but cross-file plumbing).
- L18 — satellite cosmetic Dynamic-Type token drift (UNWIRED; cosmetic; batch with any future satellite work).
- L16 (partial) — copy feedback for `MarketsTodayActionsCard`/`BestOpportunityActionCard` "Copy" buttons (separate structs need state plumbing; MarketsView-local ones handled in this wave if cheap).

## REJECT
- L5 — dead `StockSageGlossary` entries (.weeklyDollars/.weeklyR): zero consumers; editing dead copy adds churn without user-visible value. Candidate for deletion in an engine-hygiene pass, not a UI wave.

## Notes
- All accepted items are display/copy/a11y/interaction or currency-conversion correctness. Zero ranking/scoring changes; deliberate designs (gross velocity display, F34 asymmetry, chip caps, velocity sort default) untouched.
- Exit: full suite `** TEST SUCCEEDED **` + pixel QA (`bash tools/qa.sh`, adopt after review) + shipping-changes pipeline.
