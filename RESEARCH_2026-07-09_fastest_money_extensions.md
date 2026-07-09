# RESEARCH 2026-07-09 — fastest-money extensions: retail leverage economics · option-income (VRP) · delisting-data unblock

**Question.** After the price-signal space closed comprehensively NULL (single-signal sweep, sign space, TOM, non-price survey), three fastest-money frontiers had ZERO corpus coverage: (1) can leverage on the beta base accelerate wealth at 2026 rates, (2) is the option-income / variance-risk-premium family a real retail edge, (3) can the "delisting-inclusive/small-cap substrate (data-blocked)" residual — named by the momentum-sign, TOM, quality/insider/PEAD, and 2008-panel rows as the last genuine shot — actually be unblocked, and at what cost?

**Provenance.** Workflow `fastest-money-extensions` (wf_13a2c2c8-b71, 2026-07-09 evening, 30 agents: 3 survey + 27 vote): 3 surveys (Fable, xhigh, primary-source obligated) → 3-vote adversarial verification per claim (SOURCE / ECONOMICS / FEASIBILITY-DISTINCTNESS lenses), sequential claim-groups. The original session died at its usage limit with 24/27 votes complete (journal: `wf_13a2c2c8-b71/journal.jsonl`); this session recovered all completed results from the journal and ran the 3 remaining votes as continuation workflow wf_145d2b5b-18b with byte-identical RULES/lens/claim prompts. Vote tallies below are per-claim `[SOURCE, ECONOMICS, FEASIBILITY]`-lens outcomes; REVISED = core survives with named corrections (corrections incorporated below and marked **corrected**).

**Corpus placement.** Extends (does not re-run): half-Kelly/no-leverage discipline (RESEARCH_2026-06-27_money_fast_conviction), the DSR≈0 milestone row, and the survivorship caveat carried by every NULL. First corpus coverage of: post-ZIRP margin arithmetic, LETF decay economics, BXM/PUT/VRP, and any named CRSP-alternative vendor. NO crypto (owner directive). Nothing here is an edge claim; no engine change ships from this round.

---

## Frontier 1 — retail leverage: **CLOSED-NEGATIVE** (leverage is not a fastest-money lever at 2026 rates)

| # | Claim (post-correction) | Votes | Outcome |
|---|---|---|---|
| 1 | Margin-loan leverage on a diversified base is wealth-destroying at mainstream brokers, ~breakeven at best at IBKR | R/R/R | REVISED — core confirmed, mainstream case **worse** than first computed |
| 2 | 2x LETF is the cheaper wrapper; nets ~+1.5%/yr expected with −σ² path drag | R/R/R | REVISED — core confirmed, range tightened |
| 3 | Kelly theory caps a no-edge (beta-only) retail book at ≤1.0x | R/R/R | REVISED — conclusion confirmed on **corrected** inputs |

**The verified numbers (all as-of dates in-line):**
- **Rates (verified 2026-07-09):** IBKR Pro tiered 5.14% (<$100k) / 4.64% ($100k–1M), Lite 6.14% (2026-07-04 snapshot; reproduces exactly from EFFR 3.63% [FRED 2026-07-08] + published 1.5/1.0/2.5 markups). Schwab base 10.00% / Fidelity base 10.575% (both eff. 2025-12-12). **Corrected:** sub-$25k accounts pay base **plus** a small-balance markup — Schwab <$25k = 11.825%, Fidelity <$25k = 11.825%; the survey's 9.575/10.075% were wrong-direction tier reads. Fed funds 3.50–3.75% (FOMC 2026-06-17).
- **Expected return input — corrected (misattribution caught by SOURCE lens):** Damodaran's July-2026 page lists implied US ERP **4.18%** (variants 3.63–6.16%); the survey's 4.45% was the US risk-free/country-table figure, not the ERP. Corrected mu ≈ **8.6%** nominal (not 9.0%).
- **Margin arithmetic (hand-derived g(L)=L·mu−(L−1)·r_b−L²σ²/2, σ=16%, mu=8.6%):** unlevered g=7.3%/yr; 1.5x IBKR **+0.1**/yr; 2x IBKR **−0.4**/yr (negative); 1.5–2x at mainstream retail rates **−2 to −5**/yr. The ZIRP-era positive spread is DEAD (flipped when fed funds went 0→3.5%+). Margin interest deductible only if itemizing (IRC 163(d)) — most retail can't; plus the margin-call left tail converts temporary losses into permanent ones.
- **LETF decay (Cheng & Madhavan, JOIM Q4-2009, SSRN 1539120 — the prospectus-standard formula):** (1+R_LETF)=(1+R_idx)^L·exp((L−L²)σ²T/2); L=2 drag = −σ²/yr exactly (−2.25%/yr at σ=15%, −9%/yr at σ=30%). All-in 2x-vs-1x expected edge at 2026 financing ≈ **+1.1 to +2.0%/yr** (central ~+1.5%) vs ~+7%/yr in the ZIRP era — and one 30%-vol year costs ~5 years of expected edge. SSO's 21.2%-vs-14.2% decade (fool.com 2026-04-16) is favorable-path, not expectancy.
- **Kelly ceiling (Thorp 2006 Handbook of ALM v1 ch.9; MacLean-Thorp-Ziemba, Quant. Finance 10(7) 2010, 681–687):** f\*=(mu−r)/σ². **Corrected inputs:** IBKR full-Kelly **1.36** → half-Kelly **0.68x**; LETF-financing 1.42 → **0.71x**; mainstream brokers mu−r_b<0 → optimal borrowed fraction exactly **0**. Every plausible perturbation (σ=20% → 0.44x half; ERP −1pt → 0.49x) keeps half-Kelly **below 1x**. The corpus's validated half-Kelly discipline extends from position sizing to total exposure: **1x diversified beta is at or above the prudent maximum this era.**

**Revisit trigger:** fed funds back under ~2% (flips the IBKR margin sign) or a genuine measured edge (changes the Kelly mu input).

---

## Frontier 2 — option-income / variance-risk premium: **CLOSED** (premium real; edge vs benchmark fully eroded; a preference product, not an edge)

| # | Claim (post-correction) | Votes | Outcome |
|---|---|---|---|
| 1 | VRP real & positive gross-over-cash; risk-adjusted edge vs SPX fully eroded post-publication | C/R/R | REVISED — numbers verified verbatim against both Cboe factsheet PDFs |
| 2 | Tail profile: absorbs ~2/3 of a crash, forfeits V-recoveries; structurally negative skew | C/C/R | **CONFIRMED** |
| 3 | Binding retail constraint is contract granularity (~$75k/contract), not trading costs | R/R/R | REVISED — reframed as a **size-contingent cost cliff**, tier-specific not absolute |

**The verified numbers (Cboe factsheets as-of 2026-06-30, PDFs read by 4 independent agents):**
- BXM since 1986: 8.5%/yr, Sharpe 0.55 vs SPX TR 11.2%/yr, Sharpe 0.56 — indistinguishable over 40 years. PUT since 2007 (= the post-publication window): 7.0%/yr, Sharpe **0.51 vs SPX 0.61** — the put-write index is now *worse* risk-adjusted than its benchmark. Last decade (2016–2025, DERIVED from factsheet calendar tables): PUT/BXM lag SPX TR by ~**7 pts/yr gross**; benchmark beaten in 2 of 11 calendar years (2015, 2022). The 1986–2018 Sharpe advantage (Wilshire 2019: +46%) has **inverted** post-publication — observed decay worse than the standard 58% haircut.
- The premium itself persists: IV>RV in 20 of 21 years through 2025 (WisdomTree 2025-10). This family's failure mode is NEW for the corpus: **costs don't kill it (~3–15bp/yr on SPY/XSP ATM monthlies — cheapest implementation ever surveyed); the benchmark's opportunity cost does.** A 60/40 SPX/T-bill mix replicates PUT's 0.6 beta and ≈its since-2007 return at higher Sharpe, better tax, any account size — the strategy is dominated by its own passive replication.
- Tail: MaxDD PUT −32.7% / BXM −35.8% vs SPX −50.9% (all troughs Jan-2009); 2020 exhibit: PUT +2.1% / BXM −2.8% vs SPX **+18.4%** — won only the slow 2022 bear (−7.7 vs −18.1), echoing the corpus's regime-dependent-defense finding (beta/IVOL). Monthly skew structurally negative (Bondarenko/Cboe 2019) — exactly what the shipped DSR penalizes.
- Retail floor: one cash-secured SPY/XSP contract ≈ **$75k** notional (SPY $747.71 close 2026-07-07, EODHD-verified; XSP is the SAME notional); at $5k–$50k the family is ETF-only, and the flagship wrapper (PUTW, 0.44% ER) **stopped tracking the academic PUT index in 2024** (now a Volos 2.5%-OTM target-premium index). Defined-risk spreads are the only sub-$75k DIY expression and sell far less premium while keeping the negative skew.

**Disposition:** documented absence of net edge vs benchmark; do NOT build an option-income lever into StockSage. Reopen only if the owner's objective changes from growth to income/low-vol preference — then it's a preference product, not an edge.

---

## Frontier 3 — delisting-data unblock: **UNBLOCKED-FOR-$20 (conditional)** — a purchase decision, not a research absence

| # | Claim | Votes | Outcome |
|---|---|---|---|
| 1 | EODHD paid tier ($19.99/mo All World) is the cheapest legitimate, mechanics-verified path to a survivorship-free US panel | C/C/C | **CONFIRMED 3-0** |
| 2 | The FREE path is a measured, documented ABSENCE (4 sources measured-failed same-day) | R/R/R | REVISED — all four legs independently re-measured & reproduced; itemization expanded |
| 3 | Sharadar SEP is the provenance-grade escalation if EODHD fails acceptance (price login-gated) | R/R/R | REVISED — substance verified on every checkable element (continuation run) |

**The verified path (claim 1, 3-0):** the in-session EODHD MCP token (free tier, measured: 20 calls/day, history hard-capped at 1y) upgrades to **EOD Historical Data — All World, $19.99/mo (min 1 month, 100k API calls/day, 30+ yrs)**; vendor states verbatim "Delisted tickers are available in any of our packages", "26,000+ US stock tickers (mostly from Jan 2000)". Full US pull (~37k calls: 26k delisted + ~11k active) fits in ONE day's quota via `exchange-symbol-list/{US}?delisted=1` → `/api/eod/{TICKER}.US`. This is the first substrate that can actually carry the frontier every NULL row names.

**MANDATORY acceptance test before ANY ablation result on it is trusted** (a silently mis-adjusted delisted series would manufacture the exact fake edge this frontier exists to rule out): (a) reverse-split spot-checks on known delisted cases incl. ≥3 pre-2018 delistings hand-checked against SEC filings (vendor caveat: pre-2018 delistings are "EOD data only" — no splits/dividends objects — adjusted_close integrity is THE risk); (b) overlap diff vs the existing Yahoo survivors panel on ~50 common names; (c) delisting-date sanity vs the free AV LISTING_STATUS ledger.

**The free-path absence (claim 2, measured 2026-07-09, re-measured independently same day):** EODHD free = 1y cap (verbatim API warning, measured twice); AV `TIME_SERIES_DAILY_ADJUSTED` = premium-only (rejection measured); AV `LISTING_STATUS` delisted ledger works free (9,330 rows pulled) but collapses pre-~2013 (4 rows ≤2008, 40 in 2009 vs 977–1,064/yr in 2021–23) — cannot anchor a 2000-2012 universe; Stooq CSV endpoint is behind a JS SHA-256 proof-of-work wall (challenge page measured). Definitional fails: EDGAR (no prices), NDL WIKI (unmaintained since 2018-04), SimFin (documented delisted-series gaps), CRSP (no open subset). Dropped candidates: Tiingo (no delisted commitment), Norgate (Windows-only client), dukascopy (not US equity). **Zero dollars buys the cross-check ledger, never the panel.**

**The escalation path (claim 3, verified by the continuation votes):** Sharadar SEP coverage confirmed from the vendor's own (JS-gated, snippet-read) product page: "more than 21,000 active and delisted tickers, with history to the year 1998" — delisting-inclusive by construction, small/micro-cap inclusive; the "nearly completely free from survivorship bias" phrasing is Sharadar's marketing for its fundamentals flagship (sharadar.com + Quandl datasheet, verified 2026-07-09), with SEP the price companion. Pricing-withheld verified verbatim at all three named sources (QuantRocket: "Log in or create account to see pricing" + Professional/Non-Professional certification modal; Datarade: "Sharadar has not published pricing information for their data services"). Quote it only if EODHD flunks the claim-1 acceptance test; the price check is an owner-executed step (account creation off-limits).

**Artifacts persisted this session** (the dead session's scratchpad was volatile): `~/.claude/salehman-universe/av_delisted_now.csv` (9,330 rows, symbol/name/exchange/ipoDate/delistingDate) + `av_delisted_2010.csv` (point-in-time as-of-2010 snapshot, 62 rows — LISTING_STATUS `date` param confirmed point-in-time by measurement).

**Decision (owner-spend, gates lifted 2026-07-09 = decide on evidence):** the evidence says buy ONE month ($19.99), pull the panel in a day, run the acceptance test, and only then run the ablation runners (`tools/momsign_ablation/`, `tools/cap_ablation/`, `tools/altdata_ablation/`) on the first genuinely survivorship-free small-cap-inclusive substrate. On purchase, the 2008-inclusive momentum-crash re-test (its row says "only a delisting-inclusive panel could revisit") and the small-cap-concentrated families (MAX, BAB, IVOL) become runnable.

---

## Refuse-list / fence additions (verified this round)
- **Margin leverage at mainstream brokers (2026 rates)** — wealth-destroying arithmetic (−2 to −5%/yr geometric at 1.5–2x); at the cheapest broker ≈ breakeven with a margin-call left tail. Kelly-inconsistent even at IBKR (half-Kelly 0.68x < 1x).
- **ATM option-income as a growth lever** — dominated by its own 60/40 passive replication since 2007 (Sharpe 0.51 vs 0.61); negative-skew tail absorbs 2/3 of crashes and forfeits V-recoveries.
- Existing fences untouched; NO new tradable edge claimed anywhere in this round.

## Engine mapping
No code change. If the app ever discusses leverage, the honest line is fixture-ready: "2x index LETF is the cheapest retail leverage and still nets ~+1.5%/yr expected with severe path risk; margin at mainstream brokers is negative-sum at 2026 rates; half-Kelly ceiling for a no-edge book is ~0.7x." The Kelly-ceiling paragraph is the citable one-paragraph answer to "why not 2x everything".

## What this round did NOT establish
- No new tradable edge (all three frontiers close negative-or-conditional for the owner's question).
- The EODHD panel's DATA QUALITY is unproven until the acceptance test runs post-purchase — vendor coverage claims were verified as *claims + mechanics*, not as data integrity.
- Whether any small-cap/delisting-inclusive effect actually clears DSR>0.95 — that's the ablation the purchase unblocks, not this round.
- Option-income for an INCOME-preferring objective was not evaluated (only the growth/fastest-money question).
- Sharadar SEP pricing (login-gated; account creation off-limits per 2026-07-08 precedent) — owner-executed step if ever needed.

## Method notes
Sequential claim-groups meant the usage-limit death lost zero completed work (journal-cached). One ESC-recovery earlier in the original run re-issued 3 in-flight votes (duplicate `started` entries, single results — no double-counting). Verifier independence held: 4 separate agents fetched the Cboe PDFs; two independently caught the same Damodaran ERP misattribution; the free-path measurements were reproduced by a different agent with different tickers (GM.US vs AAPL.US vs DRYS.US). Multiple-comparisons: this is a survey round (claims verified for truth), not a strategy sweep — no DSR selection issue arises; any strategy-shaped follow-up goes through the ablation harness + trial registry.
