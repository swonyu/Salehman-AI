# Research: Re-validation of StockSage NetEdge round-trip cost assumptions — current-era (2024–2026)

<!-- Deep-research artifact. 2026-07-03, autonomous (owner: "work autonomously 12h"). Opus 4.8
     successor session, workflow wf_ce45a7b4-860 (wiz8qrfl8): 7-domain fan-out WebSearch/WebFetch
     → 3-vote adversarial verification per load-bearing number → synthesis. 56 agents, ~3.1M tokens,
     413 tool calls. 33 candidate claims → 13 survived 3-vote (12 CONFIRMED, 1 PARTIAL). This CLOSES
     the OPEN FRONTIER item "Current-era retail cost levels" as an indexed research input (NOT a code
     change — every cost-table revision remains OWNER-GATED, see §Owner-gate). -->

## Question

The five per-asset-class round-trip friction assumptions in `StockSageNetEdge.defaultCosts` rest on
2013–2021 samples (**pre** zero-commission / **pre** PFOF-transparency). Current shipped values
(round-trip bps of entry, for a solo retail trader at small size): **US large-cap 13** (8 spread + 5
slippage) · **international/ADR 30** (20+10) · **spot crypto -USD 70** (30 spread + 20 slippage + 20
taker, both fills) · **FX majors =X 7** (4+3) · **index ETF ^ 8** (5+3). Are these still realistic in
the 2024–2026 zero-commission/PFOF era?

**Two cost concepts kept distinct throughout:** GROSS/quoted spread (displayed NBBO, before price
improvement) vs EFFECTIVE cost (what a retail order actually pays after price improvement). US equity
is zero-commission + PFOF-routed, so effective ≪ quoted; **crypto has no PFOF offset — the explicit
taker fee IS the effective cost.**

## Executive summary (verified, 3-vote adversarially voted)

| Class | Shipped | Current-era verified | Verdict | Conf. | Gate error direction |
|---|---|---|---|---|---|
| US large-cap | 13 bps | ~0.5–9 bps RT effective (Fidelity 605; JFE'25; JF'25) | ACCURATE-to-slightly-HIGH; keep or trim to ~10 | HIGH (3×3/3) | over-refuses (SAFE) |
| International/ADR | 30 bps | liquid ~25–35; small/illiquid/EM 50–120+ | ACCURATE for liquid, **TOO LOW** for small/illiquid/EM | HIGH (3/3) | **passes losers (DANGER)** for illiquid/EM |
| Spot crypto | 70 bps | 4 (Binance.US) · 20 (Binance) · 80 (Kraken Pro) · 120–400 (Coinbase) | VENUE-DEPENDENT (100× range); 70 = Kraken-class midpoint | HIGH (3/3 per venue) | **passes losers (DANGER)** on casual-retail (Coinbase) |
| FX majors | 7 bps | ~1.1–2.8 bps RT (EUR/USD 0.6–0.8 pip all-in) | **TOO HIGH** (3–6× overstated for EUR/USD) | MEDIUM (aggregators, no tick study) | over-refuses (SAFE) |
| Index ETF | 8 bps | ~0.4–0.8 bps RT (SPY/IVV/VOO); thin ETFs 5–10+ | **TOO HIGH** for broad ETFs (~10×) | HIGH (issuer + search) | over-refuses (SAFE) |

**Bottom line:** three assumptions (US equity, FX, index-ETF) err on the *safe* side (a conservative
gate that occasionally skips a marginal winner — consistent with the app's honesty-floor/half-Kelly
posture). The **only dangerous-direction (gate wrongly PASSES losers) errors are (a) small/illiquid/EM
international and (b) casual-retail crypto (Coinbase Simple ~400 bps vs shipped 70)** — those are the
priority for owner review. **No code change follows from this document** (§Owner-gate).

---

## Per-class detail (every figure sourced + dated)

### 1. US large-cap equity — shipped 13 bps RT
- Fidelity / S&P Global Rule-605 audit (2025 data, accessed 2026-07-03): **~0.46 bps RT** ($0.0046/sh
  effective spread ÷ ~$200 px × 2; ~0.9 bps at a $100 anchor). EFFECTIVE, PFOF-adjusted; 94.3%
  price-improved, 98.82% within NBBO. `fidelity.com/trading/execution-quality/overview`. **CONFIRMED 3/3.**
- Dyhrberg, Shkilko & Werner, "The Retail Execution Quality Landscape," *JFE* 2025 (sample 2020–2022):
  **~9.2 bps RT** (4.62 bps one-way effective, wholesaler route; PI ≈ 47% of quoted). **CONFIRMED 3/3.**
- Schwarz et al., "The Actual Retail Price of Equity Trades," *J. Finance* 2025 (~85k live orders):
  **7–46 bps RT** all-stock band, S&P 500 subset materially lower, ex-commission. **CONFIRMED 3/3.**
- **Verdict: ACCURATE-to-slightly-HIGH (HIGH).** 13 bps sits above the two large-cap-specific effective
  estimates and near the bottom of the all-stock band — conservative for genuine large-caps, not too low.
  Keep, or trim toward ~10 bps; do not raise.

### 2. International / ADR equity — shipped 30 bps RT
- IBKR fee schedule (BankerOnWheels, 2025): 5 bps/side rate but **per-order minimums dominate at small
  size** (€500 XETRA = 26 bps Tiered / 60 bps Fixed one-way; RT commission alone ~52–120 bps on €500,
  → ~10 bps RT only at ~€2,500+). **CONFIRMED 2/3.**
- Tadawul (Saudi .SR) all-in (cleartax, 2025/26): ~12–18 bps/side fees → **~24–36 bps RT in fees alone,
  before spread.** **CONFIRMED 3/3.**
- **Verdict: ACCURATE for liquid default; TOO LOW for small-order / illiquid / EM (HIGH).** Evidence
  supports a two-tier structure (keep ~30 liquid, add ~60–100 bps small/illiquid/EM tier). Note: the
  Saudi-first universe (2222.SR etc.) is exactly the EM case the 30 bps understates on fees alone.

### 3. Spot crypto (-USD) — shipped 70 bps RT
- Binance.US (2026-04): 2 bps/side → **~4 bps RT.** Binance Global (2026-07-03): 10 bps/side (7.5 w/
  BNB) → **~20 bps RT (15 w/ BNB).** Kraken Pro lowest tier (2026-07-03): 40 bps/side → **~80 bps RT.**
  Coinbase Advanced sub-$10k (2026-04): 60 bps/fill → **~120 bps RT.** Coinbase Simple/app bank-funded
  (2026-04): ~200 bps/side effective (0.5% spread + 1.49% fee) → **~400 bps RT** (debit-card ~900 bps).
  All **CONFIRMED 3/3 per venue.**
- **Verdict: VENUE-DEPENDENT — 70 bps is a defensible Kraken-class midpoint spanning a 100× range
  (HIGH).** No PFOF offset in crypto — taker fee IS the cost. 70 bps badly understates the modal
  *casual-retail* path (Coinbase) and overstates a fee-optimized path (Binance.US). Least-honest single
  number of the five; a venue-aware input would be the highest-magnitude revision.

### 4. FX majors (=X) — shipped 7 bps RT
- ForexBrokers.com zero-spread guide (2026): EUR/USD avg 0.23–0.7 pips standard; raw+commission all-in
  ~0.6–0.8 pips. 1.0 pip @ EUR/USD 1.08 = **0.93 bps one-way** → realistic **~1.1–1.5 bps RT** tight,
  ~2.8 bps RT at a 1.5-pip spread.
- **Verdict: TOO HIGH (MEDIUM).** 7 bps RT overstates EUR/USD friction ~3–6×; conservative (safe
  direction). MEDIUM because sourced from broker aggregators, not a primary tick-data study; more
  defensible for cross-pairs / less-liquid majors / non-ECN accounts.

### 5. Index ETF (^) — shipped 8 bps RT
- SSGA SPY Liquidity (as-of 2025-06-30): SPY spread cost from NBBO-mid **0.04 bps** (institutional $25M);
  avg quoted spread ~$0.01 ≈ 0.2 bps; held <1 bp even on the 2025-04-02 tariff-shock day. Liquid ETF
  generally 1–2 bps quoted. **CONFIRMED (issuer data + search).**
- **Verdict: TOO HIGH (HIGH)** for broad flagship ETFs (SPY/IVV/VOO ~0.4–0.8 bps RT, ~10× below 8 bps).
  8 bps becomes reasonable only for thin/niche/low-AUM index ETFs.

---

## What this round did NOT establish (mandatory)

- **No primary tick-level FX study** — the FX verdict rests on broker-comparison aggregators, not a
  microstructure dataset or the owner's fills (hence MEDIUM); cross-pairs not separately measured.
- **No spread component for EM equity** — Tadawul figures are FEES ONLY; the true EM round-trip is
  higher than the 24–36 bps fee floor by an unmeasured bid-ask amount.
- **Order-size sensitivity not modeled continuously** — the international commission-minimum-binding
  size was shown at discrete points only.
- **Slippage/market-impact beyond spread not independently re-measured** — validated via effective-spread
  proxies; genuine impact for larger/fast-market retail orders not estimated. The 2020–2022 academic
  windows include elevated-volatility periods that may inflate equity effective spreads vs a calm 2026 tape.
- **The app's spread/slippage/taker DECOMPOSITION not verified** — this round validated round-trip
  TOTALS per class, not the internal split (US 8+5, crypto 30+20+20).
- **Amended Rule 605** (compliance 2025-12-15) will sharpen the effective-cost picture after a full
  post-amendment year (mid-2026+); no complete standardized dataset yet.
- **Top-3 weekly concentration mechanics, IRRX net-of-cost, and the proven-edge milestone remain open**
  (this round addressed only the cost-levels frontier item).

## Owner-gate note — this research INFORMS, it does not change code

Any modification to `StockSageNetEdge.defaultCosts` (or new liquid/illiquid tiers, venue-aware crypto
inputs, FX/ETF trims) is **OWNER-GATED** under the open-frontier item "Current-era retail cost levels":
the suffix-bps assumptions may only be **re-ratified or revised through the shipping pipeline** with
owner approval — exactly as confluence/RS and the IRRX overlay are gated. This document is the research
*input* to that decision. **No code, no cost-table edit, no gate-behavior change** was made. Correct
next step: owner reviews → ratify-as-is vs tiered revision → if revising, it goes through the normal
wave/QA/test-green pipeline with a `DEVELOPMENT_LOG` entry and an INDEX open-frontier UPDATE.

## Key sources (all fetched + 3-vote verified this round)

- Fidelity execution quality (S&P Global Rule-605 audit) — https://www.fidelity.com/trading/execution-quality/overview
- Dyhrberg, Shkilko & Werner, "The Retail Execution Quality Landscape," JFE 2025 — https://www.sciencedirect.com/science/article/pii/S0304405X25000595
- Schwarz et al., "The Actual Retail Price of Equity Trades," J. Finance 2025
- Kraken / Binance / Binance.US / Coinbase fee schedules (venue pages, 2026)
- ForexBrokers.com EUR/USD spread comparison (2026); SSGA SPY Liquidity (2025-06-30)
