# RESEARCH 2026-07-11 — news-sentiment as a retail equity signal (survey-grade, 3-vote verified) — REFUSED at survey stage

**Verdict: REFUSE — do not build, do not even pre-register an ablation.** News sentiment is a REAL gross signal, but on
this project's data and at retail costs it fails on two *independent, disqualifying* grounds before an ablation is worth
running — so the honest disposition is refuse-and-index, not the usual "prereg → measured null." The signal survives
only in exactly the corner where (a) our sentiment DATA is blindest and (b) retail costs are highest, and its daily
form horse-races to ≈0 against the price signals we have already measured null.

## Provenance
30-agent workflow `wf_0c79324b-c47` (4 finder angles → 3-vote adversarial verification, verifiers read primary PDFs).
**Honesty note:** the workflow hit the Fable-5 weekly usage limit partway through the Verify phase — 20/32 agents
completed (all 4 finders + the load-bearing academic-core verifications); 12 agents (some duplicate verify votes + the
synthesis agent) errored on the limit. This synthesis was completed directly (Opus 4.8) from the recovered journal
(`…/wf_0c79324b-c47/journal.jsonl`); no claim below rests on an un-returned agent. Verification tally on returned
votes: heavily CONFIRMED, a few REVISED (all strengthening/refining), **zero REFUTED**.

## Acceptance (measured before the survey, EODHD sentiment endpoint, args symbols/start_date/end_date)
- Depth: AAPL 2,140 daily rows back to 2016-02 (~10y) — real depth. GE 838 rows/5y ≈ **46% daily coverage** (sparse).
- **Survivorship on the SIGNAL side is UNFIXABLE:** delisted names carry near-zero sentiment history — TUPBQ.US /
  BBBYQ.US = **0 rows** 2019-2023; YRCW.US stops at its ticker rename. The frozen panel's whole point is
  survivorship-free PRICES; sentiment coverage re-introduces survivorship bias on the signal exactly for the
  small/dying names where the effect lives (below). Unlike prices, there is no reconstruction path.
- Documented ABSENCE (verified): no peer-reviewed evaluation of EODHD-class daily aggregated feeds exists.

## What the literature actually says (29 claims, 4 angles — the load-bearing verified ones)
**The gross signal is real** (pro-signal, confirmed): SESTM (Ke-Kelly-Xiu, NBER 26186, OOS 2004-2017) day-ahead
long-short gross annualized Sharpe **4.29 equal-weighted**. LLM headlines (Lopez-Lira & Tang, accepted JFE, genuinely
OOS Oct-2021→May-2024) **34bps/day gross**, Sharpe 2.97. These are not in dispute.

**But every path to a retail net edge is walled off — four overlapping walls, all confirmed against primary sources:**

1. **The cost wall sits AT the app's own ratified tier.** Tetlock-Saar-Tsechansky-Macskassy ("More Than Words", JF
   2008): daily negative-word strategy **21.1%/yr gross → ≈0 at 10bps RT → ≈−13%/yr at 13bps RT** (the app's ratified
   US cost). Lopez-Lira LLM: **alive at 5-10bps, DEAD at 20bps RT**; authors say it is "only feasible for market
   participants whose transaction costs are sufficiently low, such as market makers." SESTM net is shown ONLY at
   institutional 10bps-DAILY costs and only after a turnover-throttled redesign — **net-at-retail-costs is never
   demonstrated in any of these papers.** Turnover is 90-190%/day.

2. **Liquidity scoping = a coverage-cost double bind.** The tradable drift concentrates in SMALL / illiquid / negative-
   news names: large-cap day-1 news response is **11bps (< the 13bps cost)** and large-caps show **NO drift after
   negative news** (SESTM Figs 8-10; Lopez-Lira size terciles; Chen-Kelly-Xiu 16 markets). So the signal lives
   precisely where **our sentiment coverage → 0** (the delisted small names) AND where **retail cost is 60bps not 13**
   (the ratified EM/illiquid tier). It cannot be both seen and afforded.

3. **Real-time decay, measured not inferred.** LLM Sharpe **6.54 → 1.22 in ~2.5 years (−81%)** within its own OOS
   window; the implementable intraday variant goes statistically INSIGNIFICANT by Jan-May 2024. RavenPack's commercial
   daily-strategy slope flattens post-2014 as subscriptions grew (McLean-Pontiff mechanism on a data product). Deploying
   today = the flat end of the curve, gross.

4. **Endogeneity — the disqualifier for OUR specific data.** Tetlock (2007) VAR: media sentiment measurably FOLLOWS
   prices (+5.8% of 1σ pessimism per −1% prior-day return, p=0.003). The horse-race against price controls: with 5 lags
   of returns + volume + volatility, daily sentiment nets to **−1.3bps over a week ≈ 0 (n.s.)**. Antweiler-Frank (2004):
   message sentiment adds volatility/volume info, **not return info**. Stale-news contamination (Tetlock 2011;
   Fedyk-Hodson 2023) persists in modern feeds. **A DAILY AGGREGATED score ≈ f(recent returns, attention, stale
   reprints)** — so an ablation of EODHD's daily score would largely re-derive the price-momentum/reversal signals this
   corpus has ALREADY measured null (crash-2008 through the composite, all NULL). It is not an independent test.

The one surviving corner (scoping): low-frequency WEEKLY aggregation (Heston-Sinha) persists ~13 weeks at ~12
rebalances/yr (~1.6%/yr cost) — but its effect concentrates in **earnings-announcement weeks**, i.e. it is PEAD, which
this corpus already REFUSED at the monthly horizon (absence + cost pincer), and it still needs the small-cap names
where coverage fails.

## Why REFUSE at survey stage (not "prereg → measured null")
Two disqualifiers, each sufficient, both structural — this is the `gated-scope` principle (a test blocked on a data
limitation is refused, not shipped with a warning), not defeatism:
- **(D1) The signal-side survivorship bias is UNFIXABLE.** Delisted names have ≈0 sentiment. Any ablation would be
  survivorship-LITE on the signal exactly where the effect concentrates (small/dying names) — and unlike prices there
  is no reconstruction. A "null" from such a test would be corpus pollution (an un-disentanglable mix of "no edge" and
  "no data"), not a clean win.
- **(D2) The daily score is not incremental to signals already measured null.** The endogeneity horse-race (claim 4)
  shows daily aggregated sentiment adds ≈0 over lagged returns/volume; an ablation re-derives the price nulls rather
  than testing something new. Running it burns the ablation budget to re-confirm a known result under a worse data
  regime.

## What this survey did NOT establish
- It did NOT test EODHD's specific feed empirically (refused per D1/D2). A survivorship-free evaluation of a low-cost
  daily feed remains a documented ABSENCE — but one that cannot be filled with this data source.
- It does NOT refute the ACADEMIC signal (real, gross, in small stocks at institutional speed/cost) — it refuses the
  RETAIL implementation on this project's data.
- It leaves the low-frequency weekly corner formally un-ablated (folded into the already-refused PEAD family + the
  coverage wall). A future purpose-built survivorship-free intraday-sentiment dataset (not available) would be the only
  way to reopen.

## Disposition
REFUSE-and-index. No prereg, no ablation, no engine change. The measured-edge search adds one more closed class: news
sentiment joins price (all families/substrates), fundamentals quality, insider transactions, and the composite as a
measured/adjudicated dead end at retail — here on a DATA-plus-cost-plus-endogeneity basis rather than a run DSR. The
engine's forward machinery (owner fills → calibration + realized costs) remains the only live edge-detector; new data
classes require both a signal that is incremental to price AND survivorship-free coverage — a bar this class fails on
both counts. Fenced (refuse-list extension): daily aggregated vendor news-sentiment as a standalone retail signal.
