# Research: Execution question-3 remainder — order-type choice (limit vs marketable / auctions) + day-of-week effects

<!-- Deep-research artifact. 2026-07-03, autonomous (owner: "work autonomously 12h, never stop").
     Opus 4.8 successor session, workflow wcwtr59hk (runId wf_8261dc53-548): 5-angle execution-
     microstructure fan-out (WebSearch/WebFetch) → 3-vote adversarial verification per load-bearing
     claim → synthesis. 24 agents, ~1.49M tokens, 254 tool calls. 47 candidate claims → top-6 to
     3-vote (41 lower-relevance dropped from the vote but informed synthesis) → 5 CONFIRMED, 1 REFUTED.
     Discharges the OPEN FRONTIER item "Execution question-3 remainder". Verifiers read primary PDFs
     directly (Anand et al. quoted verbatim); the auction-cheaper-for-retail claim was REFUTED and an
     inflated PFOF magnitude flagged. Changes NO code — any StockSageExecutionTiming / order-advisory
     change is OWNER-GATED (§5). -->

> **Result in one line:** unlike the cost-levels and weekly-concentration NULLs, this round has ONE
> genuinely retail-direct, current-era, net-measured finding — a resting **limit order is ~10 bps cheaper
> net for a patient/uninformed entry (and fills ~65% of the time), but the sign FLIPS to a marketable
> order when the trade is informed/urgent** — plus two refusals (closing-auction-as-retail-venue: refused,
> institutional-only; day-of-week rule: refused, decayed). The order-type finding is at most a FLAG-ONLY
> advisory candidate (like the shipped `sessionNote`), owner-gated, and is NOT wired by this research.

**Research date:** 2026-07-03 · **Method:** 3-vote adversarial adjudication · **Scope:** the OPEN FRONTIER "Execution question-3 remainder" — the two sub-questions the 2026-07-02 execution round (`RESEARCH_2026-07-02_week_horizon_velocity.md`) explicitly did NOT cover: (a) order-type choice (limit vs marketable, auction participation) and (b) day-of-week effects. Session timing + liquidity screens were the ONLY parts of question-3 the earlier round settled.

## 1. Question

Given a decision to trade a name, what order type (marketable/market vs resting limit vs MOC/LOC auction) minimizes retail net-of-cost execution, and is there any day-of-week timing rule tradable net of current-era (zero-commission/PFOF) retail costs?

## 2. Executive summary

| Sub-question | Verdict | Confidence | Retail-direct or borrowed? |
|---|---|---|---|
| **Limit vs marketable (patient/uninformed trader)** | Limit orders ~10 bps cheaper net (IS basis; ~20 bps small-cap); retail limits fill ~65%, far above market-wide myth | **HIGH** (3/3) | **RETAIL-DIRECT** (Anand et al., US, May 2020, zero-comm/PFOF era) |
| **Limit vs marketable (informed/urgent trader)** | Sign FLIPS — marketable is net-cheaper when you have a genuine directional edge/urgency (limit's adverse selection + chase cost dominates) | **HIGH** (3/3) | RETAIL-DIRECT mechanism; sign-flip is cross-paper synthesis (Handa-Schwartz theory + Linnainmaa) |
| **Filled-limit "performance" interpretation** | A filled passive limit is mechanically adversely selected → poor post-fill returns; conflates strategy with fill bias, NOT skill | **HIGH** (3/3) | RETAIL-DIRECT (Linnainmaa, but 2010 Finnish data — pre-current-era) |
| **Closing auction as a cheaper venue** | Institutional price-impact result; **did not survive** as a retail-net claim | n/a (REFUTED 2/3) | **BORROWED / institutional-only** — price impact ≈ 0 at retail size |
| **PFOF routing relevance** | The dominant retail cost lever is broker/wholesaler choice, not the market-vs-limit toggle; marketable orders capture sub-quote price improvement | **HIGH** mechanism / **MEDIUM** on magnitudes | RETAIL-DIRECT (mechanism); some bundled figures unverified (see §4) |
| **Near-close order type (MOC vs LOC vs limit)** | No retail-scale, close-specific net-cost study exists; LOC is the practitioner-recommended cap | n/a (documented absence) | BORROWED / inference only |
| **Day-of-week timing rule** | No tradable net-of-cost rule; effect decayed, reversed by cap/era, and is a few bps/day < costs | HIGH (absence) | RETAIL-DIRECT verdict, but rests on decayed-regime evidence |

## 3. Per-sub-question detail (CONFIRMED findings only)

### 3a. Limit vs marketable — patient/uninformed trader (CONFIRMED, HIGH, 3/3)
- Retail **limit orders incur ~10 bps lower trading cost** than comparable marketable orders on an **implementation-shortfall** basis — and IS explicitly **nets in the opportunity cost of non-execution** (the imputed ~16 bps cost of unfilled shares), so this is a genuine NET, not gross, retail figure. Regression-adjusted ~9 bps; univariate small-cap advantage ~21 bps (7.59 vs −13.43). Robust to stock-day + broker fixed effects. *Source: Anand, Samadi, Sokobin & Venkataraman, "Retail Limit Orders," Review of Finance 30(2):459–488, 2026; FINRA OATS, May 2020, >27M orders, 19 retail brokers, 300 stocks.*
- **Retail limits fill far more often than folklore implies: ~65% fully filled** (≈60% small-cap; ≈50% for orders >5× spread behind the quote) vs a **<3% NYSE market-wide all-order benchmark** (Li-Ye-Zheng 2023). Average limit-order duration ≈ 1,252 s (~20.9 min). This directly refutes the "resting retail limits rarely execute" assumption. *Same source.*
- **Era note:** current-era (zero-commission/PFOF) US data, benchmarked against already-price-improved retail marketable orders — so the ~10 bps is a conservative, current-regime, retail-net number.

### 3b. Sign flip for the informed/urgent trader (CONFIRMED, HIGH, 3/3)
- A **marketable order is net-cheaper when the trader has a genuine directional/short-horizon information edge or urgency**: a passive limit fills mainly when the market moves against it (adverse selection), and if unfilled forces a later, worse chase. The patient/uninformed liquidity supplier net-saves with limits (~10 bps; ~20 bps small-cap); the informed/urgent trader does not. *Source: synthesis of Handa & Schwartz (JF 1996, the sign-flip model), Linnainmaa (JF 2010, adverse-selection/non-execution mechanism), Anand et al. (RoF 2026, the magnitude).*
- **Honesty flag:** the informed-trader leg is a theory-grounded cross-paper inference, not a single within-paper measured retail-net figure. The patient-trader leg IS directly measured.

### 3c. Filled-limit performance is a fill artifact, not skill (CONFIRMED, HIGH, 3/3)
- Because limit orders are price-contingent they **mechanically suffer adverse selection** — they execute preferentially when price moves toward/through them, so filled limits show poor post-trade returns. Individual-investor patterns (poor post-trade returns, contrarian trades, disposition effect, earnings losses) are **"explained in large part" by limit-order use, not necessarily skill deficits.** *Source: Linnainmaa, "Do Limit Orders Alter Inferences About Investor Performance and Behavior?," JF 65(4), 2010 (all Finnish individual investors, 1995–2002).*
- **Regime note:** the mechanism is structural/regime-independent (carries to current era), but the DATA is 1995–2002 Finnish — cite as mechanism, not a current-era magnitude.

### 3d. PFOF routing dominates the cost lever (CONFIRMED mechanism, HIGH; magnitudes MEDIUM, 2/3)
- In the zero-commission/PFOF era, retail **marketable orders routed to wholesalers receive sub-quote price improvement**, so realized marketable cost is **well below the full quoted spread**; effective/quoted spread (EFQ) is the SEC's key metric, added by the **Rule 605 amendments (adopted March 2024)**. *Source: SEC Rule 605 amendments + DERA/PFOF work (2025); UChicago Business Law Review "A Disclosure Gap in the Market for Order Flow."*
- **Confirmed direction (corroboration, consistent):** ~44–47% of retail marketable shares fill at midpoint-or-better; retail pays ~45% of the quoted half-spread; sub-penny price improvement (~0.5 bps typical, up to ~4 bps at DMA benchmarks, ~0 at the worst PFOF brokers) is a structural feature of off-exchange internalization only. The practical upshot: **broker/wholesaler choice, not the market-vs-limit toggle, is the dominant retail cost lever** under PFOF; standing limits are often routed to rebate-selected exchanges (Battalio-Corwin-Jennings JF 2016: rebate-maximizing routing degrades limit fill quality).
- **Honesty flag — MEDIUM / partially unverified:** the bundled "~5× higher reported PI / ~$15B in 2022" sub-claim did NOT clear cleanly (2 confirm, 1 refute; actual 2022 PI ≈ $3B, and the NBBO benchmark tends to OVERSTATE PI, so better measurement generally LOWERS apparent savings — direction of "5×" is disputed). The "effective 2025" date is loose (rule effective June 2024; compliance pushed to Aug 1 2026). Treat the **qualitative mechanism as substantiated; the 5×/$15B figure and precise date as NOT established.**

### 3e. Auctions as a venue — DID NOT SURVIVE for retail
- The claim "closing auction is a genuinely cheaper execution venue than continuous, ranking closing < continuous < opening price impact" was **REFUTED (1 confirm / 2 refute)** as a *retail* statement. The Goyal-Jegadeesh-Wu (JFQA 2026) ranking is real but is an **institutional-size PRICE-IMPACT result** (the auction's edge is absorbing large size with sub-spread impact). **Price impact ≈ 0 for retail-scale orders (<0.01% of ADV)**, so a small retail trader's cost is dominated by effective spread / PFOF price improvement (Schwarz 2025: 7–46 bps round-trip), which the auction does not address. The GJW "2–15 bps" figure is impact-only, low-turnover-anomaly, ex-spread/commission — not an unconditional retail-net round-trip. **Verdict: institutional-only; do not present as a retail venue edge.**
- **Near-close order type:** documented absence — no located primary source gives a retail-scale, net-of-cost head-to-head of marketable vs limit vs MOC/LOC executed *at the close*. Practitioner guidance only: LOC (limit-on-close) caps fill price on illiquid names vs an MOC's guaranteed-execution/unguaranteed-price risk. This is inference from adjacent evidence, not measurement.

### 3f. Day-of-week — no tradable net rule (documented absence, HIGH)
- The classic weekend/Monday effect **decayed and largely disappeared after ~2000** (Olson-Mossman-Chou 2015), **reversed sign** for large caps post-1987 (Mehdian-Perry 2001), and a 2024 meta-analysis of 85 studies (Grebe-Schiereck) finds significance declining over time with index choice driving cross-study variance. Where any pattern persists it is a **few bps/day — below round-trip retail costs** — so sell-Friday/buy-Monday is NOT profitable net of spread/PFOF/financing/slippage. Consistent with the app's own week-horizon research (no 1–5 day equity edge survives retail costs standalone). **DOCUMENTED ABSENCE: no credible day-of-week rule tradable net of current-era retail costs.**

## 4. What this round did NOT establish

- **No retail-scale, close-specific net-cost study** of marketable vs limit vs MOC/LOC. The auction cost evidence is institutional-sized (GJW; NYSE Data Insights); the retail order-type evidence (Anand et al.) is **continuous-session and intraday (avg limit life ~21 min)**, NOT close-specific and NOT multi-day.
- **No retail-isolated order-type evidence at the 1–5 day swing horizon.** The ~10 bps limit advantage is an intraday result; extending it to a swing hold is extrapolation, not measurement.
- **No single controlled study** of the same retail trader's limit-vs-market decision under PFOF vs DMA. The net-cost calculus is assembled from separate literatures (Levy RCT, Ernst-Spatt, Battalio, SEC).
- **PFOF magnitude figures are soft:** the "5×/$15B" price-improvement sub-claim is disputed/likely-backwards; ~$3B (2022) is the better estimate. Rule 605 EFQ compliance date is Aug 2026, not "2025."
- **Auction-for-retail is not measured** — the low-impact benefit is institutional; retail impact ≈ 0, so the auction offers no measured retail edge. Overnight-reversal give-back (Bogousslavsky-Muravyev 2023) and the open being the worst-cost window were noted in the wider literature but were not independently vote-verified this round.
- **Day-of-week is decayed/disputed regime evidence** (French 1980 → Gibbons-Hess 1981 → reversed/vanished by 2000s). The *verdict* (no tradable rule) is robust; any *positive* day-of-week signal would be a stale-regime artifact and must never be presented as current retail-net.

## 5. Owner-gate note

**This research INFORMS; it changes no code.** Any change to `StockSageExecutionTiming` or the net-cost / order-advisory surface is **OWNER-GATED** per the gated-scope registry.

- The app already ships `StockSageExecutionTiming.sessionNote` as a **FLAG-ONLY advisory** (no sizing/rank effect), and the reversal-as-liquidity-screen leg was **deliberately deferred**. This round provides **no basis to wire a new order-type or day-of-week signal** into ranking, sizing, or auto-advice.
- The one genuinely retail-direct, current-era, net-measured result — **limit ~10 bps cheaper for the patient/uninformed trader, sign-flipping to marketable when informed/urgent** — is at most a candidate for a FLAG-ONLY note (same pattern as `sessionNote`), and even that is owner-gated. It is conditional (patient vs informed), intraday-scoped, and its magnitude is dwarfed by the PFOF broker-choice lever, which the app does not control.
- **A documented absence is a valid result.** The correct disposition of this frontier item is: closing-auction-as-retail-venue = refused (institutional-only, did not survive); day-of-week rule = refused (no net-tradable effect, decayed regime); order-type = retail-direct finding recorded but NOT wired. Do not recommend shipping a new signal on any of the three.

**UPDATE 2026-07-09 (owner gate-lift supersedes this section's framing):** the owner lifted
every owner gate ("nothing is owner gated i allow u") — see `research/INDEX.md`'s "Execution
question-3 remainder" frontier row, UPDATE 2026-07-09. The "OWNER-GATED" language above is
superseded: decisions are now evidence-based through the normal shipping pipeline, not held for
separate owner sign-off. Honesty floor and DSR validation bar UNCHANGED. As it happens, the
order-type finding this section called "recorded but NOT wired" WAS subsequently wired: a
flag-only limit-vs-marketable trade-off advisory (incl. the informed/urgent sign-flip this
section documents, plus a 24/7-crypto override) shipped display-only in
`Views/MarketsTodayActionsCard.swift` (2026-07-09 C1 wave) — see the INDEX row for the exact
lines. Auctions and day-of-week remain REFUSED; nothing there was wired.
