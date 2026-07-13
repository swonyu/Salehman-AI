# Options ORDER-FLOW / GEX-DEX as a retail equity signal — survey-grade (3-vote)

**Date:** 2026-07-13 · **Disposition: REFUSE-and-index (STRUCTURAL, not power).** ·
**Method:** Workflow `wf_c1704d3c-187`, 10 agents (3 Find angles → 3-vote adversarial Verify per
load-bearing claim → completeness-critic synthesis). Verifiers read PRIMARY sources (JFE/RFS papers,
SqueezeMetrics whitepaper, the retail-option-cost literature) + a LIVE data-access probe. 2
load-bearing claims, both REVISED-but-held → net REFUTE; 0 promoted.

## The question

Options **order-flow / dealer gamma-delta exposure (GEX/DEX) / net-gamma positioning / 0DTE-flow** —
the class the 2026-07-12 completeness survey EXPLICITLY listed as UNSURVEYED (its "NOT surveyed here"
scoping boundary). This is a SURVEY (literature + retail access + the three-part bar), NOT an ablation
— so it needs no survivorship-free backtest, and it is DISTINCT from the already-refused options
IV-SURFACE class (IV skew/PC-parity/ΔIV, Muravyev-Pearson-Pollet 2025). Judged against the bar:
(1) incremental-to-price, (2) survivorship-free coverage, (3) retail-cost-survivable; 58%
McLean-Pontiff post-pub haircut applied first.

## Disposition — REFUSE-and-index (structural, same grave as IV-surface)

A genuinely DISTINCT class in MECHANISM (hedge-rebalancing pressure, not IV skew) that dies on the
SAME TWO structural walls. A prereg is NOT warranted: it would be survivorship-lite untestable (wall
2) and net-negative by cost arithmetic before it started (wall 3). Milestone (measured net-of-cost
DSR>0.95) UNMET and unchanged.

| Bar part | Clears? | Killing number / reason |
|---|---|---|
| **(1) Incremental-to-price** | **Split — the only leg that partly clears.** | The CROSS-SECTIONAL net-gamma sort (Soebhag 2023, J.Empirical Finance 74 / SSRN 4256259) IS distinct from price/size/value/momentum via a hedge-rebalancing mechanism: GROSS ~10%/yr (~83bps/mo). BUT the rigorous return content of GEX/DEX itself (Baltussen-Da-Lammers-Martens, JFE 142 (2021) 377-403) is last-30-min intraday momentum that FULLY REVERTS over 1-3 days (their Table 11) and is DEAD past 4pm settlement (Table 12, r_ROD t=−0.37, R²=0.05%) — spanned by intraday momentum/reversal, not a daily edge. The index-level SqueezeMetrics result is a VOLATILITY FUNNEL, non-directional (high-GEX next-day SD 0.55% vs 0.85%; returns centered at 0% across all GEX levels; its lone return claim self-flagged "for further investigation"). Barbon-Buraschi "Gamma Fragility" (SSRN 3725454) extends to single names as a FRAGILITY/VOL predictor, strongest in the LEAST-liquid stocks. |
| **(2) Survivorship-free** | **NO — structural, unfixable (IV-surface twin).** | The academic result rests on OptionMetrics IvyDB US (survivorship-free, institutional WRDS license the app cannot touch). Every RETAIL-accessible per-name options feed is CURRENT-UNIVERSE only — confirmed by direct MEASUREMENT this session: a delisted name (SIVB, failed Mar-2023) returns "Options data not available" on the live GEX tool (~615 current liquid tickers, no history); EODHD options are keyed to currently-optionable underlyings, so delisted/bankrupt names have ZERO retail per-name GEX/DEX history and it is NOT reconstructable. Any app-side ablation is survivorship-lite untestably — the exact IV-surface disqualifier. |
| **(3) Retail-cost-survivable** | **NO.** | OPTIONS expression: the ~10%/yr (83bps/mo) gross is entirely erased by the retail single-stock option bid-ask — 12.6% retail (Bogousslavsky-Muravyev 2025 "An Anatomy of Retail Option Trading") / 17.2% quoted S&P-500 (Muravyev-Pearson 2020, RFS 33(11) "Options Trading Costs Are Lower Than You Think"; 40-60% effectively paid) — i.e. ~60-100× the 13bps equity tier, the wall that killed IV-surface. EQUITY expression on the gamma signal: ~10%/yr gross → ~4.2%/yr (~35bps/mo) after the 58% McLean-Pontiff US haircut, then eroded by 13bps equity cost + short-leg/low-liquidity concentration + borrow → ~0 tradable at retail, concentrated in a hard-to-access short leg of low-liquidity high-net-gamma names. The directional GEX/DEX intraday leg (few bps/day) is an order of magnitude below the combined haircut+cost and needs a last-30-min round-trip retail can't occupy at 13bps + churn. |

## Distinctness from the already-refused IV-SURFACE class

Genuinely a DISTINCT class in MECHANISM — order-flow / dealer positioning (hedge-rebalancing
pressure), NOT IV skew/term-structure. It does not collapse to the same signal. But it dies on the
SAME TWO structural walls: (a) the options-chain survivorship wall (no delisted per-name options data
anywhere retail can reach — SIVB probe = "not available"), and (b) the ~60-100× retail option-spread
cost wall. IV-surface was refused because power ∝ borrow-fee ≈0 net + the 60-100× option-spread wall;
order-flow adds a genuinely different mechanism AND a cross-sectional gross edge, yet arrives at the
same net-≈0-or-negative through the same two structural gates. **Distinct class, identical structural
grave.**

## Verified-vote corrections folded in (both claims REVISED-but-held)

The retail option-spread numbers are 12.6% (Bogousslavsky-Muravyev 2025) and 17.2% quoted S&P-500
(Muravyev-Pearson 2020) — earlier drafts misattributed/overstated these; the disposition, direction
(access/anti-signal), and barPart (survivorship + retail-cost) are unchanged. The 23.5% micro-retail
figure is a size-conditional quote, not the headline.

## What this survey did NOT establish

- **NOT an ablation.** No prereg, no walk-forward, no net-of-cost DSR run — refused at survey stage.
  Nothing measured on the survivorship-free panel; nothing wired.
- **Did NOT disprove the academic effect.** Soebhag's ~10%/yr cross-sectional net-gamma gross premium
  and Baltussen et al.'s intraday-momentum R²=2.88% are taken as real on IvyDB — the refuse is a
  retail-accessibility + cost + survivorship verdict, NOT a claim the anomaly is fake.
- **Did NOT test whether a delisting-inclusive options substrate exists at any price.** The refuse
  rests on MEASURED retail feeds (Stocks-Intelligence GEX ~615 current tickers; EODHD
  current-optionable-only). An institutional IvyDB/WRDS license would change wall (2) — an owner /
  data-purchase question, not surveyed here. (Even unblocked, wall (3) cost still stands for the
  options expression.)
- **0DTE-flow / sweeps** were folded into the order-flow angle rather than measured separately; the
  survivorship + cost walls apply identically (0DTE data is current-universe, and trading it is an
  options expression at the ~60-100× spread).

**Net:** REFUSE-and-index. Options order-flow / GEX-DEX is a distinct-mechanism class that fails the
survivorship + retail-cost walls exactly as IV-surface did. This closes the last "options" escape
hatch the milestone row cites (both IV-surface AND order-flow now surveyed and structurally refused).
Milestone unchanged; fences stand. One survey agent hit a terminal API error and dropped; both
load-bearing claims rest on the surviving 3-vote panels.
