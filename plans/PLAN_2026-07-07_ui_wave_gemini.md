# PLAN — Ideas-card UI wave (Gemini review, vetted) — 2026-07-07

Source: owner's Gemini 3.1 Pro "StockSage UI Design Review" (Google Doc), vetted against the
real code + honesty floor. Gemini's 10 proposals are all decision-science-grounded and
honesty-preserving; this plan is the executable, gate-aware version. Files: `Views/MarketsView.swift`
(card = "Best opportunity now" block ~L3490, ideas-board card, `ideaDetailSheet`, `ideaMetric`
helper), `DesignSystem/DesignSystem.swift` (append-only tokens), `Views/MarketsTodayActionsCard.swift`.

## Hard gates (do NOT implement without owner's explicit ruling — these are product decisions, not lane)
- **G1 — default sort velocity → RR (Gemini #9).** This IS **RANKING #10** (the parked `@AppStorage("marketsIdeaSort")` default). Owner call only. Gemini's argument (velocity default subliminally endorses fast-money turnover in a zero-alpha app) is sound, but flipping the default is the owner's product decision. HOLD.
- **G2 — replace the N/100 signal-strength display with an ordinal bar (Gemini #1).** F08-adjacent: touches the "Signal strength" term/metaphor the owner already ruled on. The *denominator-neglect* concern is real (a "82/100" reads as 82% P(win)), but changing the metaphor is owner-gated. HOLD (draft both the ordinal-bar and the keep-N/100 variants for the owner to pick).

## Visual-QA gate (repo law-9 + the "UI-merge-without-QA" incident)
Every item below changes the card layout → needs a pixel check at **default + 440pt-narrow** before
merge. No native-screenshot MCP in this session, so each ships either (a) HELD for the owner's
5-sec Xcode glance, or (b) to main with an explicit after-merge-glance note (the F08 `f68bf0e`
precedent) ONLY for the lowest-dimension-risk items. Mark each item's risk below.

## Ship order (non-gated, ranked by decision-value ÷ effort ÷ layout-risk)

| # | Item (Gemini rank) | What | Honesty-floor check | Layout risk | Files |
|---|---|---|---|---|---|
| 1 | Gross→net fusion (#4) | Render resolved gross+net as ONE decayed unit: `3.0R (gross) → 1.8R (net)` in a single capsule; if net nil → gross only, no arrow (nil=nothing) | ✅ gross/net both labeled, adjacency strengthens it; nil→nothing preserved | MED (capsule width in 440pt) | MarketsView (velocity/R:R sites) |
| 2 | Gate verdict at apex (#7) | Move the trade-gate verdict (clear/caution/blocked) to the TOP of the card hierarchy so "DO NOT TRADE" is seen before the reward metrics | ✅ pure reposition, no new claim | MED (VStack reorder) | MarketsView card VStack |
| 3 | Distance-to-invalidation (#8) | Append "(−X.X% to stop)" to the Stop metric (and "· N.N ATR" if the ATR/stopMult is plumbed — it's on Advisor but NOT on the idea; plumbing is a small engine add) | ✅ raw descriptive math, no alpha claim | LOW-MED (adds width to a tight Entry/Stop/Target HStack → 440pt wrap risk) | MarketsView `ideaMetric("Stop",…)`; opt. Advisor→idea ATR plumb |
| 4 | Assumed vs measured styling (#6) | Preattentive encoding: "assumed" win% chip = dashed border + reduced opacity; "measured · n=X" = solid border, full opacity. Text strings unchanged | ✅ text unchanged; style only reinforces the existing honest label | LOW (style modifiers, no dimension change) | MarketsView win% chip; DesignSystem token |
| 5 | Sizing-brake-chain waterfall (#3, detail sheet) | In `ideaDetailSheet`, render the half-Kelly→regime→vol-brake→corr→heat cascade as a small vertical waterfall (bars shrinking) with "Deploy plan is authoritative" | ✅ visualizes existing numbers; no new claim | MED-HIGH (new custom view; detail sheet = more vertical room, lower wrap risk) | MarketsView `ideaDetailSheet` |
| 6 | Net-edge ledger (#4.3, detail sheet) | Explicit ledger: Gross expectancy − slippage − fees = net; negative net → dangerSoft | ✅ reconciles the gross EV honestly | MED | MarketsView `ideaDetailSheet` |
| 7 | Overtrading / correlation brake (#3.3) | Conditional dangerSoft chip on the card when the idea's asset-class/correlation overlaps an OPEN position (portfolio state → card) | ✅ descriptive state check, not a P(loss) | MED (portfolio state wiring + conditional render) | MarketsView card + portfolio state |
| 8 | Uncertainty band for win% (#3.1) | Compact bullet graph plotting the 35–58% prior band with a tick at the point estimate; assumed→blurred/low-opacity; nil→EmptyView | ✅ visualizes the band, implies no guarantee | HIGH (custom 80pt-max graphic in 440pt) | MarketsView + new view |

## Rejected (Gemini's own omissions — correct, keep out)
Historical win-rate per chart pattern; "P(target hit)" metric; social/LLM news on the card — all
manufacture the alpha illusion the DSR≈0 reality forbids. Do NOT add.

## Implementation protocol (per item)
1. Read the exact render site; make the minimal additive change; preserve nil=nothing.
2. Build + test green (`** BUILD/TEST SUCCEEDED **`).
3. Visual-QA: owner glance at default + 440pt (or after-merge note for the LOW-risk items #4).
4. Ship per shipping-changes: dev-log, bundle, MARKETS_TAB_MAP if material, add-by-name, CI.
5. Coordinate: MarketsView is shared with the ideas-card session — pull-rebase, non-overlapping edits.

## Recommended first three (best value, lowest risk): #4 (assumed/measured styling, LOW), then #1
(gross→net fusion), then #3 (distance-to-invalidation). #2 (gate-at-apex) after, as it's a reorder
needing the closest pixel check.
