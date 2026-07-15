# PRE-REGISTRATION — ACCRUALS (Sloan 1996) LONG tilt on the survivorship-free panel

(written 2026-07-15, committed BEFORE any test statistic. The FOURTH fundamentals-side ablation, after GP/A quality
[NULL], value B/M+E/P [NULL], and investment/issuance CMA+ISS [NULL]. The 2026-07-09 non-price survey explicitly
REFUSED accruals "as a decision, not an oversight" — short-leg-concentrated + long-dead post-publication. This ablation
converts that ARGUED refuse into a MEASURED long-leg null, following the exact precedent of the investment/issuance
run: that factor was ALSO refused-by-analogy on the same short-leg reasoning, and running its long leg produced a
clean measured null strictly more valuable than the argument. Accruals is the LAST canonical fundamental anomaly with
no measured null on this population.)

**Honest prior, stated up front:** a DSR>0.95 pass is UNLIKELY — (a) the tradable alpha of the accruals anomaly is
SHORT-concentrated (the overpriced HIGH-accruals firms), so the LONG leg (low accruals = high earnings quality =
Sloan's long portfolio) is thin; (b) accruals is the MOST-decayed classic anomaly post-publication (Green-Hand-Soliman
2011: the accrual premium ~disappeared after 2003; Sloan's own 1996 sample ended 1991); (c) the generic
fundamentals-decay pattern (GP/A, value, investment/issuance all NULL on this exact population); (d) 2010-2026 is
entirely post-decay. BUT "unlikely" is not "measured null" — accruals' long leg has never been run on this population,
a measured null > an argued refuse, and it CLOSES the last canonical fundamental anomaly. This is DISTINCT from the
prior nulls: accruals is an EARNINGS-QUALITY axis (the cash-vs-accrual composition of earnings), orthogonal to
value (price ratio), quality (profitability level), and investment/issuance (balance-sheet growth).

## Data (pull launched 2026-07-15 before this prereg — acquisition only)
- Prices: the frozen survivorship-free panel `5ce314475941a0cd` (5,135 clean names); GSPC.INDX master.
- Fundamentals: `edgar_pull_accruals.py` (this session) → `edgar_facts_accruals/`, the working-capital line items the
  GP/A + value pulls did NOT save: `AssetsCurrent`, `CashAndCashEquivalentsAtCarryingValue` (+restricted-cash
  fallback), `LiabilitiesCurrent`, `LongTermDebtCurrent`/`DebtCurrent`, `AccruedIncomeTaxesCurrent`,
  `DepreciationDepletionAndAmortization`/`Depreciation`, and `Assets`. Same 4,288-name CIK map, same window.
- Sloan needs BOTH FY_t and FY_{t-1} working-capital items (a Δ) → smaller eligible universe than the single-FY runs
  (census reports per-year eligible counts + the coverage cost of requiring all 5 balance-sheet roles).

## Signal (mechanical, as-of; Sloan 1996 balance-sheet accruals)
- **Accruals(t) = [(ΔCA − ΔCash) − (ΔCL − ΔSTD − ΔTP) − Dep(t)] / avg(Assets_t, Assets_{t-1})**, where Δ = FY_t −
  FY_{t-1} of the instant balance-sheet item, Dep(t) = the FY_t depreciation flow, and each role uses its pinned-priority
  tag (cash: CashAndCashEquivalents > restricted-cash variant; STD: LongTermDebtCurrent > DebtCurrent). Missing TP or
  STD roles default to 0 (Sloan's method permits it — those terms are minor); AssetsCurrent, Cash, LiabilitiesCurrent,
  Assets(both FYs), and Dep are REQUIRED (a name missing any required role at either FY is ineligible, censused).
- Cohort = **BOTTOM tercile Accruals long** (low accruals = high earnings quality = Sloan's long leg). Stored as the
  NEGATED signal (−Accruals) so the invest runner's top-tercile-by-signal sort = bottom-tercile-by-accruals = the long
  leg — IDENTICAL construction to the investment/issuance runner (reused verbatim).
- **Pair-interval guard (inherited FIX 1):** the Δ is annual ONLY if `end_t − end_{t-1} ∈ [340,380] days`.
- **Availability (inherited FIX C):** first master bar STRICTLY AFTER max(`filed`) JOINTLY over ALL ingredient records
  actually used across BOTH FYs; freshness = most-recent usable FY_t whose max-filed ≤ trailing 378 bars.
- **PRICE-EXOGENOUS (inherited):** the signal is balance-sheet-only — NO price. Fed through the invest runner's
  dedicated `_invest_run_leg` (sig = scalar directly), so the value run's 1/price placebo-leak structurally cannot
  arise. The price-exogenous scalar-shuffle placebo IS a true null.

## Books, scopes, arms — INHERITED from the investment/issuance runner
- Panel-freeze filters + integrity screen; entry open[p+1]; exit last valid print ≤ p+1+H (death-blocks BOOKED). No
  warmup. Eligibility at p: valid entry print AND a fresh Accruals signal AND ≥1 dv print in [p−62..p]. ONE EQW book
  per (scope,H). Cohort = BOTTOM-tercile Accruals long (via negated signal). Scopes FULL / LOWLIQ. H ∈ {63,126,252};
  <30-eligible blocks skipped and counted; H252 underpowered by construction.
- **Decision arms = 1 signal × 3 H × 2 scopes = 6.** (Only one signal — Accruals — unlike the 2-signal value/invest
  runs.) Costs 13/60bps by scope, levels only (cost cancels in the paired diff; ~annual turnover).

## Statistics — INHERITED
- Per arm: paired block diff d = COHORT − EQW; mean, t; DSR (`StockSageDeflatedSharpe` port); GROSS t/DSR both books.
- **Trials = 6 (this run) + 0 prior EMPIRICAL accruals-family arms (ledger census: zero `accrual` records — VERIFIED
  before this prereg) = 6 primary.** Registry-informed print at 6 + (current ledger line count) for cross-family
  deflation (over-deflates = safe). varTrialSharpe = sample variance of the 6 arm Sharpes, floored at 0.0343, BINDING.
- Sensitivity legs (VETO/context-only): **S1′ lag +126** (pass conjunct, sign-agreement); **S1″ signal-shuffle
  placebo** + **S1‴ returns-shuffle placebo** (3 seeds each; either clearing DSR>0.95 → run INVALID); **S2a**
  winsorized; **S2b** no-screen+winsorized; **S4** Shumway −30%; **S5** freshness 504 (context).
- **Mandatory censuses:** (i) staleness-excised names still showing valid prints; (ii) per-role coverage (how many
  names have all 5 required balance-sheet roles at both FYs — the Δ + multi-role cost); (iii) usable-rate split
  DELISTED vs ACTIVE; (iv) per-year eligible counts; (v) Accruals cross-sectional distribution per year (sanity:
  centered near a small negative, per Sloan — total accruals average slightly negative due to depreciation).

## Decision rule (committed now; coded with ALL conjuncts on the CLOSED 6-arm set)
An arm PASSES iff ALL of: diff_mean > 0 (low-accruals cohort beat EQW = the published long premium) AND diff DSR >
0.95 at trials=6 AND DSR > 0.95 under the variance floor AND S2a DSR > 0.95 AND S2b DSR > 0.95 AND S1′ sign-agreement
— AND the run is valid (neither placebo cleared). Any pass → owner-presented promotion CANDIDATE only. Anything else →
**NULL on the 2010-2026 XBRL-era (POST-DECAY) survivorship-free (retail-inclusive) population — the LONG leg of the
accruals anomaly (thin by construction; the alpha is short-concentrated AND the whole anomaly is long-dead
post-2003); the accruals ASSUMPTION becomes a long-leg MEASUREMENT, NOT a refutation of the (pre-decay) academic
anomaly.** **Symmetric negative pre-commitment:** a significantly NEGATIVE paired diff (DSR>0.95 on −d, surviving
S1′/S2a/S2b) — HIGH-accruals names OUTperforming, the opposite of the published sign — is reported as an anti-edge
flag, never improvised. Partial passes are beta/artifact flags, never findings.

## Disclosed limits (decided now, before results)
- 2010-2026 is ENTIRELY post-decay (the accrual premium ~vanished after 2003, Green-Hand-Soliman 2011) — a null here
  is the EXPECTED outcome and does NOT refute the pre-decay academic anomaly. This is the strongest a-priori-null of
  all four fundamental runs.
- LONG-leg only; the tradable alpha is short-concentrated → thin long leg → modal null.
- d = cohort − EQW is a LOWER BOUND on the long-leg premium (EQW contains ~1/3 cohort; conservative).
- The 5-required-role balance-sheet requirement shrinks the eligible universe (census ii) more than the single-item
  GP/A/value/AG runs — a coverage caveat, not a bias.
- Price-return-only basis; cost approximately (not exactly) cancels in the diff (residual overstates net, bounded small).
- Block machinery = the twice-verified sibling code (imported; fixes propagate).

## Sequencing
1. THIS document commits BEFORE any statistic (the running `edgar_pull_accruals.py` is data acquisition only).
2. Pull completes → coverage reconciliation print (censuses i–v; still no test statistic).
3. Runner = extend `investment_issuance.py` with `accruals_events` (the Sloan formula) → PASS-BLOCKING selfcheck
   (reproduce one name-FY accruals from raw balance-sheet items; assert the sign convention and the interval guard) →
   detached run → 2-lens verification (conjunct audit vs THIS document + independent re-implementation of ≥1 arm incl.
   one name-FY accruals from raw companyfacts) → index + ship; ledger family `accruals` (+6 arms).
