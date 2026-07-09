---
name: ablation-harness
description: How to run an empirical walk-forward / Deflated-Sharpe validation ("ablation") on REAL market data for Salehman AI's StockSage engine — the in-app Swift harness (StockSageBacktester / StockSageStrategyBacktest / StockSageDeflatedSharpe), the standalone-script path used by the shipped precedents, the net-of-cost requirement (StockSageNetEdge), block-level significance, and how a finished run gets indexed. Use when a ranking/signal/sizing change hits the validation gate ("empirical validation or owner sign-off"), when asked to "ablate", "backtest", or "empirically validate" a StockSage signal or exit rule, or when writing up a finished ablation (null results included).
---

# Ablation harness — empirical validation on real data

An **ablation** here means: measure a candidate signal/rule against real historical prices,
with no look-ahead and honest statistics, and let the measurement decide keep/kill.
The validation gate (research-memory §2) says no ranking/signal/sizing change ships on a
story — it ships on (a) this, or (b) explicit owner sign-off. **A null result is a win**:
it closes a "pending ablation" caveat forever and gets indexed like any other finding.

**When NOT to use this — use a sibling instead:**
- Writing/fixing unit tests or fixtures → `testing-discipline` + `spec-fidelity` (an ablation never produces a fixture — see "The evidence/fixture line" below).
- Deciding whether a topic is already researched, or recording the finished run → `research-memory` (this skill defers to its §4 for the write-up format).
- The change touches a decision `gated-scope` §1 governs → that registry is the ONLY source of truth. *(2026-07-09: the owner-gate CLASS is retired — see §1's dispositions; a passing ablation through THIS harness is now exactly the evidence that licenses the change. What still blocks: missing data/measurements and the DSR/PSR promotion bar itself.)*
- Process for shipping the (non-)change afterwards → `shipping-changes`.

## Vocabulary (each defined once)

| Term | Meaning here |
|---|---|
| Walk-forward | Decide at bar `i` using ONLY data through `i`; fill at bar `i+1`'s open. Never peek. |
| Look-ahead | Any use of data after the decision bar. Instantly invalidates a run. |
| R-multiple | Trade result ÷ planned risk (entry−stop). +2 = hit a 2:1 target. |
| PSR | Probabilistic Sharpe Ratio — P(true Sharpe > 0) after haircutting for sample size, skew, fat tails. |
| DSR | Deflated Sharpe Ratio — PSR measured against the expected-max Sharpe of N strategies tried (selection-bias haircut). Honest bar: **DSR > 0.95**. |
| Block-level significance | Average within each independent time block first, then t-test across blocks (Fama-MacBeth style) — never pool symbol×date points as if independent. |
| Purge / embargo / CPCV | Stronger anti-leakage cross-validation from the literature — theory pointers below; NOT implemented in the Swift harness today. |
| Net-of-cost | After round-trip spread + slippage (+ taker fee / financing). Gross figures are banned as verdicts. |

## Choose your path

| Situation | Path |
|---|---|
| Validate the SHIPPED advisor rules (entries, exit modes, cost sensitivity, benchmark term) | **A — Swift harness** (it already parameterizes these) |
| Ablate a CANDIDATE signal not inside `advise()` (a new ranking term, a cross-sectional rank, a tie-break) | **B — standalone script** (the two shipped precedents both used this) |

## Path A — the in-app Swift harness

Entry points (all under `Salehman AI/StockSage/`, repo-relative; signatures verified 2026-07-02 — grep before trusting):

| Symbol | What it does |
|---|---|
| `StockSageBacktester.run(_:warmup:costs:exitMode:benchmark:)` | Walk-forward one symbol's `StockSagePriceHistory` → `BacktestResult`. Defaults: `warmup: 200`, `costs: nil` (frictionless — do NOT leave it nil for a verdict), `exitMode: .allAtTarget`, `benchmark: nil`. |
| `StockSageBacktester.runDetailed(...)` / `runTrades(...)` | Same pass returning the raw `[BacktestTrade]` too (per-trade analysis, conviction calibration). |
| `StockSageBacktester.walkForward(_:warmup:folds:)` | Non-overlapping fold-by-fold results (default 3 folds) — does the edge hold across time or was it one regime? |
| `StockSageStrategyBacktest.aggregate(_:trades:tradeEntryDates:)` | Rolls many symbols into one `StrategyBacktest` with pooled t, moment-corrected t, and the Deflated Sharpe. |
| `StockSageDeflatedSharpe.deflated(observedSharpe:nTrades:skew:kurtosis:trials:varTrialSharpe:)` | PSR + DSR; `Result.passes` = DSR > 0.95. |
| `StockSageNetEdge.defaultCosts(forSymbol:)` | Asset-class round-trip cost estimate — pass it as `costs:`. |

Honesty properties already baked into the backtester (don't re-implement, don't undo):
no look-ahead (decision at close of bar `i`, fill at bar `i+1`'s open), stop wins ties on a
bar that touches both levels, one position at a time, open-at-end trades counted and flagged,
survivorship bias called out in the caveat text.

**How it's actually driven:** `StockSageStore.refreshStrategyBacktest()` (user-triggered,
heavy) fetches ~5y of history for `StockSageStrategyBacktest.sampleSymbols` (a bounded list
of liquid global equities — read the array in source for the current names; never quote a
count) plus the `^GSPC` benchmark, runs `runDetailed` per symbol **with
`StockSageNetEdge.defaultCosts(forSymbol:)` and the benchmark**, then `aggregate(...)`.
The result renders in the Markets tab — anchor by symbol name `strategyBacktestPanel` in
`MarketsView.swift`, never by line number.

**Gate on verdicts, never on counts.** The honest outputs to quote:
- `StrategyBacktest.significanceVerdict` (string) and `passesHonestSignificance` — requires enough pooled trades AND raw t > 3 (Harvey-Liu-Zhu multiple-testing bar, not the textbook 2.0) AND the skew/fat-tail-corrected t > 3 when known.
- `deflatedSharpe?.passes` (DSR > 0.95). The measured DSR for the shipped rules is ≈ 0 — the app itself says "unproven edge"; that is the honesty floor, not a bug.
- Per-symbol: `BacktestResult.significanceVerdict`, `probabilisticSharpe`, `decay?.isRedFlag` (kept < half its in-sample edge OOS on a significant slice → likely overfit).
- `trials:` for DSR comes from `StockSageStrategyBacktest.estimatedStrategyTrials` (a documented, deliberate LOWER bound — currently 12; grep it, and bump it if you enumerate more variants, which can only make an unproven verdict firmer).

To exercise the harness headlessly, run the canonical test gate (the harness math is
unit-tested) — gate on the verdict line, never on test counts:
```bash
cd /Users/saleh/ai && xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
# ** TEST SUCCEEDED ** is the only verdict that counts.
```

## Path B — standalone-script ablation (the precedent recipe)

Both shipped precedents are the template. Read them before running anything new:
- `RESEARCH_2026-07-02_confluence_rs_ablation.md` — 20 liquid US large-caps / 5y daily, two studies, both null → both modules correctly NOT promoted.
- `RESEARCH_2026-06-26_quant_engine.md` §1 — the validation theory this recipe implements.

The recipe (every step is load-bearing; skipping one invalidates the run):
1. **Freeze the universe BEFORE analysis** — pick symbols for liquidity/sector spread, write them down first. Never add/drop a symbol after seeing results.
2. **Real data, same source as the app** — Yahoo's chart endpoint (`query1.finance.yahoo.com/v8/finance/chart/<SYM>?range=5y&interval=1d`, the endpoint `StockSageQuoteService.swift` uses). Verify all symbols share one bar calendar before use.
3. **Port formulas EXACTLY from the live Swift source** — open the file, copy the arithmetic (e.g. `StockSageIndicators.returnOverPeriod` = `(last − closes[n−1−period]) / past × 100`; `StockSageRelativeStrength.rank`'s tie-averaged `avgIdx/(n−1)` percentile). Never re-derive from memory. If a formula is too big to port faithfully (the precedent skipped `advise()`'s full multi-factor daily leg for exactly this reason), SHRINK THE SCOPE and disclose it — a flawed replica makes the whole result meaningless.
4. **No look-ahead** — signal at as-of index `i` from `closes[0...i]` only; entry at `open[i+1]`, exit at `open[i+1+horizon]`.
5. **Two samples** — primary: as-of dates stepped by exactly the horizon (non-overlapping blocks, genuinely independent); secondary: denser weekly stepping for a sign/magnitude cross-check ONLY (overlapping windows are autocorrelated — never use them for the significance claim).
6. **Block-level significance** — one number per block (bucket mean, or that block's Spearman rho), then a paired t-test across blocks. 20 stocks on the same day are correlated; pooling them as independent observations fabricates significance.
7. **Horizon sweep** — rerun at ~5/10/21/42/63 trading-day horizons (non-overlapping at each). A "significant" result at one arbitrary horizon that sign-flips at the neighbors is noise.
8. **Net-of-cost** — see the next section. A gross-only result cannot support promoting anything.
9. **Disclose limitations** — universe, regime coverage, omitted legs, low-power rows, multiple-comparisons count. The precedent's "Honest limitations" section is the format.
10. If no scipy/numpy: implement t-CDF + Spearman from scratch and **verify against textbook critical values before trusting any p** (the precedent checked t=2.228, df=10 → p=0.050 first).

## Worked example — recreate one number from the confluence/RS ablation

Study B's headline: pooled Spearman(RS percentile, 21-day fwd return) = **−0.040 (n=940)**.
Reproduced 2026-07-02 with the stdlib-only script below: `bars=1255 blocks=47 n_pooled=940
pooled_spearman_rho=-0.0402`. (Yahoo's 5y window slides daily and realigns ALL blocks — a
2026-07-03 rerun already produced `bars=1254 blocks=47 pooled_spearman_rho=+0.0099`: the
SIGN flipped one day after authoring. EXPECTED observation: near-zero, |rho| ≲ ~0.05, not
significant; the sign itself may flip with the window. The stable, reproducible claim is
only the CONCLUSION "near-zero, no edge" — never the sign or the decimals.)

```python
# repro_rs_spearman.py — stdlib only. python3 repro_rs_spearman.py
import json, urllib.request
SYMS = ["AAPL","MSFT","GOOGL","AMZN","NVDA","JPM","JNJ","PG","XOM","HD",
        "KO","WMT","CAT","DIS","V","MA","UNH","CVX","PEP","ADBE"]   # frozen in the precedent
WARMUP, H, LOOK = 252, 21, 21
def fetch(s):
    u = f"https://query1.finance.yahoo.com/v8/finance/chart/{s}?range=5y&interval=1d"
    r = json.load(urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent":"Mozilla/5.0"}), timeout=30))
    q = r["chart"]["result"][0]["indicators"]["quote"][0]
    return q["open"], q["close"]
data = {s: fetch(s) for s in SYMS}
n = min(len(v[1]) for v in data.values())
assert max(len(v[1]) for v in data.values()) == n, "unequal calendars — stop"
def pctile(rets):                       # StockSageRelativeStrength.rank, tie-averaged
    it = sorted(rets.items(), key=lambda kv: kv[1]); m = len(it); out = {}; i = 0
    while i < m:
        j = i
        while j+1 < m and it[j+1][1] == it[i][1]: j += 1
        for k in range(i, j+1): out[it[k][0]] = ((i+j)/2)/(m-1)
        i = j+1
    return out
def ranks(v):
    o = sorted(range(len(v)), key=lambda k: v[k]); r = [0.0]*len(v); i = 0
    while i < len(v):
        j = i
        while j+1 < len(v) and v[o[j+1]] == v[o[i]]: j += 1
        for k in range(i, j+1): r[o[k]] = (i+j)/2 + 1
        i = j+1
    return r
X, Y, blocks, i = [], [], 0, WARMUP
while i + 1 + H <= n - 1:               # no look-ahead: signal thru i, entry open[i+1], exit open[i+1+H]
    p = pctile({s: (data[s][1][i]-data[s][1][i-LOOK])/data[s][1][i-LOOK]*100 for s in SYMS})
    for s in SYMS:
        o = data[s][0]; X.append(p[s]); Y.append((o[i+1+H]-o[i+1])/o[i+1])
    blocks += 1; i += H
rx, ry = ranks(X), ranks(Y); mx, my = sum(rx)/len(rx), sum(ry)/len(ry)
rho = sum((a-mx)*(b-my) for a,b in zip(rx,ry)) / (sum((a-mx)**2 for a in rx)*sum((b-my)**2 for b in ry))**0.5
print(f"bars={n} blocks={blocks} n_pooled={len(X)} pooled_spearman_rho={rho:.4f}")
```

Note this reproduces the DESCRIPTIVE pooled rho; the precedent's significance CLAIM came
from the block-averaged rho with a t-test across blocks (recipe step 6) — extend the loop
to keep one rho per block if you need that.

## Net-of-cost is mandatory

Why: the canonical short-term reversal earns +0.37%/mo GROSS but **−1.28%/mo NET**
(t=−6.02; Novy-Marx & Velikov, RFS 2016 — verified 3-0 in
`RESEARCH_2026-07-02_week_horizon_velocity.md`). Gross verdicts promote money-losers.

- **Path A**: pass `costs: StockSageNetEdge.defaultCosts(forSymbol: sym)` — every trade's R is charged the round-trip friction against the planned 1R risk (a loser nets worse than −1R; that's the honest unit).
- **Path B**: subtract `roundTripBps / 10_000 × entry` per round trip before aggregating.
- The break-even bar in one number: `NetEdge.breakEvenWinRate` = p\* = 1/(1+netRR) — if the honest hit rate is below p\*, the setup loses money regardless of gross R:R.
- Cost defaults come from `StockSageNetEdge.defaultCosts(forSymbol:)` by symbol suffix (crypto `-USD` widest at 70bps incl. taker; FX `=X` tightest at 7bps; `^` index 8bps; dotted intl listings 30bps; `.SR` Tadawul 60bps (re-ratified 2026-07-09); bare US large-cap 13bps). **Grep the source before quoting these — this table is a map, not the territory**; all legs are LABELED ESTIMATES, never venue quotes.

## Deeper rigor (theory pointers — candidate upgrades, NOT shipped)

`RESEARCH_2026-06-26_quant_engine.md` §1, for when a single walk-forward pass isn't enough:
- **Purge + embargo**: drop training observations whose label window overlaps test labels; additionally embargo ~`h = ceil(0.01·T)` bars after each test block (raise h to ≥ the label horizon).
- **CPCV** (Combinatorial Purged Cross-Validation): report a Sharpe *distribution* over φ[N,k] = (k/N)·C(N,k) paths instead of one point estimate. The Swift harness implements walk-forward folds + an IS/OOS decay check, NOT CPCV — don't claim otherwise.
- **Never conflate CPCV's path count with the DSR trial count** — paths measure one strategy's sampling variance; DSR's N is how many configurations were searched.
- **Walk-backward check**: reverse the sequence and rerun; a materially flipped result is itself evidence of overfitting.

## The evidence/fixture line (do not cross it)

**Backtester/ablation OUTPUT is research evidence. It is NEVER a test fixture.**

| Legitimate (research evidence) | Forbidden (fixture laundering) |
|---|---|
| Quote `significanceVerdict`, DSR, block-level p in a `RESEARCH_*.md` write-up to justify keep/kill | Paste a harness number into a Swift Testing `#expect(...)` as the expected value |
| Cite an ablation to close a module's "pending ablation" caveat in a source comment | "Fix" a failing test by re-running the harness and updating the assertion to match |
| Feed `runTrades` output to conviction calibration at runtime (shipped behavior) | Derive a threshold test's straddle values by calling the code under test |

The distinction: research evidence answers "is this rule worth having?" — it may drift as
data windows slide, and that's fine because the write-up carries an as-of date. A test
fixture answers "does the code compute what the spec says?" — its expected values must come
from the captured spec or an independent hand-derivation (standalone derive script), per
`spec-fidelity`, or the test proves nothing. An ablation that "confirms" code by asserting
the code's own output is the F40 circular-fixture failure with extra steps.

## Recording the run (null results are wins — they get indexed)

Follow `research-memory` §4 verbatim: detail file `RESEARCH_<YYYY-MM-DD>_<topic>.md` at repo
root (question, method, verdicts with numbers, what was NOT established), ONE dated line
appended to `research/INDEX.md`, DEVELOPMENT_LOG entry, commit **by name**. (When committing:
`tools/test_grok_bridge.py` is a TRACKED file — since commit `713064e`; ignore any older
note claiming it's untracked.) A null result closes a caveat permanently — the confluence/RS
null is cited by the very source comments it validated (see the STANDING NOTE in
`StockSageRelativeStrength.swift`).

## Pre-"done" checklist
1. Owner-gate scan against `gated-scope` §1 — an ablation never unlocks a gated decision.
2. No look-ahead anywhere (signal ≤ i, fill at i+1's open) — state it in the write-up.
3. Significance is block-level, non-overlapping, horizon-swept — not pooled panel points.
4. Net-of-cost applied and labeled (gross figures labeled GROSS wherever shown).
5. Limitations + "did NOT establish" section written; multiple-comparisons count disclosed.
6. Indexed per research-memory §4, even (especially) if null.

## Provenance and maintenance

Authored 2026-07-02 against main @ 0f32d31-era tree. Everything below drifts; re-verify before relying:
- Harness signatures: `grep -n "static func run\|static func walkForward\|struct BacktestResult" "/Users/saleh/ai/Salehman AI/StockSage/StockSageBacktester.swift"`
- Aggregate + trials estimate: `grep -n "static func aggregate\|estimatedStrategyTrials\|passesHonestSignificance" "/Users/saleh/ai/Salehman AI/StockSage/StockSageStrategyBacktest.swift"`
- DSR bar: `grep -n "passes\|0.95\|static func deflated" "/Users/saleh/ai/Salehman AI/StockSage/StockSageDeflatedSharpe.swift"`
- Cost table + p\*: `grep -n "defaultCosts\|breakEvenWinRate" "/Users/saleh/ai/Salehman AI/StockSage/StockSageNetEdge.swift"`
- Driver + UI anchor: `grep -n "refreshStrategyBacktest" "/Users/saleh/ai/Salehman AI/StockSage/StockSageStore.swift"` and `grep -n "strategyBacktestPanel" "/Users/saleh/ai/Salehman AI/Views/MarketsView.swift"`
- Precedent numbers: open `RESEARCH_2026-07-02_confluence_rs_ablation.md` / `RESEARCH_2026-07-02_week_horizon_velocity.md` / `RESEARCH_2026-06-26_quant_engine.md` §1 directly.
- Worked example: rerun the script above; expect the null conclusion to hold (|rho| small, not significant) — the sign and decimals drift with the sliding window.
- Tracked status: `cd /Users/saleh/ai && git ls-files tools/test_grok_bridge.py` (non-empty output = tracked).
