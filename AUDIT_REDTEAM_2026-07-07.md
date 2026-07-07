# AUDIT — Red-team + universe-lane run, 2026-07-07

**Repo:** `/Users/saleh/ai` · **HEAD at run:** `0416f79` (main) · **Tree at run:** DIRTY (one pre-existing
`M skills/opus-operating/SKILL.md` — untouched; left exactly as found).
**As-of:** 2026-07-07. Every stat below carries its source + date inline.

Durable audit record. The audited run itself modified no repo file; afterwards the orchestrator landed
exactly three docs (this file, a DEVELOPMENT_LOG entry, one dated research/INDEX.md UPDATE) — no code.
The one gate-adjacent survivor is routed to the owner (§5), not fixed.

Run shape (multi-model fleet, workflow `wf_07df3e3d-003`, 15 agents): recon + throttle probe (Haiku),
4 red-team lenses (2× Fable-max: math, spec/contracts; 2× Opus-xhigh: honesty-floor display,
boundaries/runtime), 3 adversarial verification votes per finding (Sonnet-xhigh, refute-by-default,
≥2-of-3 to survive), conditional universe-verification lane (Fable-max), synthesis (Opus-xhigh).

---

## 1. Lenses run

| Lens | Scope | Result |
|---|---|---|
| **Repo-state recon** | git log/status, branches, worktrees, COORDINATION tail | Clean baseline confirmed at `0416f79`; last activity 2026-07-03/04; `ideas-card/ux-wave-3` present local+remote (WIP F04 fix, unmerged). |
| **Campaign-state recon** | research/INDEX.md (105 lines), StockSage module inventory, OPEN FRONTIER items | Engine state unchanged: **NO PROVEN EDGE (DSR ≈ 0)**; 71 StockSage files; refuse-list module present; Phase-2 greps green (`sessionNote`, `defaultShortBorrowRate`, `dsr > 0.95`). |
| **Yahoo throttle probe** | v8 `chart` HTTP status, 5 intl symbols, 1 req/2s | CLEARED at probe time for AAPL, 000660.KS, 005930.KS, 0700.HK, 7203.T — all HTTP 200. (Did NOT hold for `.SR` at universe-lane execution minutes later — see §4.) |
| **Red-team lens: math (Fable-max)** | Hand-derived formula checks across the money engine | 1 candidate (L1-01, survived). Everything else CLEAN — see §2 tail. |
| **Red-team lens: spec/contracts (Fable-max)** | nil-contracts, flag defaults vs ratifying docs, UNWIRED registry, test provenance | **Zero findings.** |
| **Red-team lens: honesty-floor display (Opus-xhigh)** | Every card/sheet/rollup/gate number's label vs its provenance | 1 candidate (L3-01, REFUTED — see §3). |
| **Red-team lens: boundaries/runtime (Opus-xhigh)** | Window-boundary off-by-ones, NaN/÷0 paths, thin-journal, Store concurrency, HistoryCache, PaperTrader isolation | **Zero findings.** |
| **Universe lane (§0.5 verify, Fable-max)** | 1,024-row intl universe verification + timing | HARD-ABORT-429 — 0/1,024 rows verified; lane data-blocked (see §4). |

---

## 2. Findings — CONFIRMED survivor

### L1-01 — MAJOR, gate-adjacent — sizer/gate parse split shows two contradictory go/no-go verdicts on the same screen

**File:** `Salehman AI/Views/MarketsView.swift` (multiple sites) · **Confirmed at HEAD `0416f79`.**

**Defect (with the verifier-3 scoping correction adopted).** Two parse families read the SAME shared
`@AppStorage` sizer fields (`sizerRiskPct` / `sizerAccount`):

- **Sheet family — raw `Double()`** (9 sites): the idea-detail sheet's gate/verdict chip, its
  Position-size panel, the `fullPlanText(for:)` "Copy plan" output (used by BOTH the sheet's Copy-plan
  button and the card's copy action), the survival-drawdown brake. `Double("2,5")` → `nil` →
  `?? 0.01` floors risk to **1.0%** — a number the user never typed.
- **Today family — F10 comma-aware `StockSageInput.percent`/`.positiveAmount`**: the Today-actions
  card and the board's "Copy today's plan" output via `StockSageTodayPlan.build`/`rankedActions`.
  `StockSageInput.percent("2,5")` → **2.5%**.

With `StockSageTradeGate.evaluate`'s default `maxRiskFraction = 0.02` (`StockSageTradeGate.swift:48`;
any `.fail` → `.blocked`), the owner's documented decimal-comma input `"2,5"` yields, for the SAME
idea on the same screen: sheet gate + sheet/card "Copy plan" say **"Risk 1.0% within the 2.0% cap →
Clear to trade"** while the Today-actions card + board "Copy today's plan" say **"Risk 2.5% EXCEEDS
the 2.0% cap → DO NOT TRADE"**. Within each family the surfaces agree (the in-source invariant at
`MarketsView.swift:4570–71` — gate must not disagree with the copied plan — holds sheet-internally);
the contradiction is **across the two families**, which the invariant's intent equally forbids. The
sheet's Position-size panel (4264) and copied-plan size line (4400) also go blank/nil for comma inputs
the board sizes, and the survival-drawdown brake (1601, 3563) computes at 1% while the user's real
risk parses at 2.5% elsewhere.

**Verified evidence (pasted, at HEAD `0416f79`, 2026-07-07):**

Raw-parse sites — `git grep 'Double(sizerRiskPct)\|Double(sizerAccount)'`:
```
MarketsView.swift:1601  let riskFrac = Double(sizerRiskPct).flatMap { $0 > 0 ? $0 / 100 : nil } ?? 0.01
MarketsView.swift:3563  let rf = (Double(sizerRiskPct).flatMap { $0 > 0 ? $0 / 100 : nil }) ?? 0.01
MarketsView.swift:4264  if let acct = Double(sizerAccount), let rp = Double(sizerRiskPct),
MarketsView.swift:4400  guard let acct = Double(sizerAccount), let rp = Double(sizerRiskPct) else { return nil }
MarketsView.swift:4450  let rf = (Double(sizerRiskPct).flatMap { $0 > 0 ? $0 / 100 : nil }) ?? 0.01
MarketsView.swift:4571  let rf = (Double(sizerRiskPct).flatMap { $0 > 0 ? $0 / 100 : nil }) ?? 0.01
MarketsView.swift:4962  if let stop = a.stopPrice, let acct = Double(sizerAccount), let rp = Double(sizerRiskPct),
MarketsView.swift:4972  sizedNotional: sizedNotional, account: Double(sizerAccount), bookTotal: bookTotal)
MarketsView.swift:5160  let rf = (Double(sizerRiskPct).flatMap { $0 > 0 ? $0 / 100 : nil }) ?? 0.01
```
Comma-aware sites — `git grep 'StockSageInput.percent(sizerRiskPct)'`: 3382, 3437, 3459, 3606, 3706, 3740, 3811, 3920.

Gate cap — `StockSageTradeGate.swift:48` `maxRiskFraction: Double = 0.02`; :63–66 pass/fail labels.

In-source invariant — `MarketsView.swift:4570–71` (verbatim):
```
// Floor 0/negative risk to 1% (matches TodayPlan.build + the velocity sibling at
// 2491) so the on-screen gate and the COPIED broker plan can't disagree on go/no-go.
```
TodayPlan.build's call sites (3459/3740) now parse via `StockSageInput.percent` (`"2,5"→2.5`) while
this gate parses `Double("2,5")→nil→0.01` — the "matches TodayPlan.build" premise of that comment is
no longer true.

**Provenance / why it re-opened.**
- Fixed once before in a narrower shape — DEVELOPMENT_LOG.md:7204 (finding `wtexg5a6u #1`): risk%="0"
  gave `rf=0.0` (the `.map`-not-`.flatMap` bug), same contradiction class, fixed with the
  `flatMap { $0 > 0 … } ?? 0.01` sibling pattern.
- Re-opened when the copy paths migrated to `StockSageInput` — DEVELOPMENT_LOG.md:9073 #3 switched
  `bestOpportunityCTA`/`bestOpportunityCard` to comma-aware parse **without** the sheet sites.
- Widened by F10 — commit `5aa3207` ("F10 closed (owner-approved): grouping-aware comma policy — fix
  the silent 10x risk-input error") made `StockSageInput` grouping-aware **specifically because
  `"2,5"` is the owner's documented input pattern**. The sheet sizer/gate sites bypass it.

**Independent corroboration (strong).** The repo's own maintainers already identified this exact bug
and are mid-fix on `ideas-card/ux-wave-3` (verified local + remote):
```
d64650a test: cover StockSageInput.percent's thousands-separator stripping (F04)
2169435 WIP F04: comma-aware sizer parse for detail sheet, copied plan, pinned gate
7d5843f WIP F04: comma-aware sizer parse for journal risk-of-ruin + money-velocity brake
```
That branch patches these raw-parse sites to a shared `parsedAccount`/`parsedRiskFraction` helper and
replaces the `?? 0.01` fabrication with an honest "enter risk % to see the verdict" nil-state.
DEVELOPMENT_LOG.md:10771 lists **"F04 sizer parse unification"** among items explicitly HELD for owner /
NOT YET APPLIED. So: the fix exists but is unmerged and owner-gated. **This survivor is therefore a
routed owner decision, not a fix to apply here** (see §5).

**Vote: 2-of-3 CONFIRMED — survives the ≥2 bar.** Verifiers 1–2 independently re-derived
`Double(String)` vs `StockSageInput.clean/percent` in standalone scripts (witness reproduced exactly:
`"2,5"` → sheet rf=0.01 "Clear to trade" vs Today rf=0.025 "DO NOT TRADE"), verified every cited line
at HEAD `0416f79`, the 0.02 cap, and reachability (`bestOpportunityCTA.onTap` sets `selectedIdea =
idea`, opening the exact diverging sheet; the sizer fields are shared `@AppStorage` keys). Verifier 3
REFUTED the finding **as originally written** — its claim paired "the sheet gate vs the copied broker
plan" as if the sheet's own Copy-plan output diverged from the sheet gate; in fact both use the same
raw parse and always agree. That scoping correction is adopted in the Defect text above; the
cross-family contradiction itself was confirmed by all three verifiers.

**Everything else in the math lens verified CLEAN** (so nobody re-buys it): PSR/DSR vs independent
implementation |d|≤5.8e-10; NetEdge costs/financing/50:1-cap/break-even, crypto tiers 37.5/60/125/300,
Kelly f*/half/cap/portfolioCap exact ≤1e-12; Wilson LCB 0.5424571844, PAV, Platt inverted-sample
clamp→flat 0.5, F01 thin-identity clamp→0.25/0.5225 (n=43 clamped / n=44 split).

---

## 3. Refuted findings (killed at 3-vote — do NOT re-file without NEW evidence clearing fact-discipline §3)

- **L3-01 (honesty-floor lens) — REFUTED 2-of-3.** Claim: the Today-tab "Best bet" tile
  (`TodayView.swift:263`) renders the GROSS `best.ev.evR` as `"+x.xxR EV · estimate"` without the
  `"(gross)"` qualifier and without the calibration-provenance chip that sibling Markets-tab EV
  displays carry (e.g. `MarketsView.swift:3403`). Verifiers confirmed the rendering facts as cited
  (`MoneyVelocityCopy.bestBetTile = "EV · estimate"`, `StockSageGlossary.swift:45`; `evR = p·rewardR −
  (1−p)`, gross, `StockSageExpectedValue.swift:12–16`) but killed the finding as a ratified,
  intentional compact-tile design: "estimate" is the tile's deliberate honesty label, and the full
  gross/provenance treatment lives one tap away on the Markets tab. Recorded so the tile is not
  re-flagged as a defect without new evidence.

---

## 4. Universe lane — HARD-ABORT-429 (0/1,024 rows verified)

**Verdict: BLOCKED (data, not code).** The lane's own mandate caps at 3 total 429s → hard-abort.

**Abort evidence (pasted from the task output):**
```
429 sym=2222.SR total429=1
429 sym=2222.SR total429=2
429 sym=2222.SR total429=3
HARD-ABORT-429
```
Run started 2026-07-07T02:05:27Z, aborted ~02:08Z (initial + 30s-backoff retry + 60s-backoff retry).
Exactly 3 requests sent all session; `first_200_ts = null` (no 200 ever seen); endpoint undisturbed.

**Why the throttle probe and the lane disagree.** The probe (§1) hit `.KS/.HK/.T` and got 200; the
lane died on `2222.SR` (Tadawul). Region-specific throttling or a re-throttle on a different egress.
Matches the persistent-IP-cooldown pattern (handoff 2026-07-03; research/INDEX.md 2026-07-04 entry:
that day even AAPL 429'd). The kept-210 core REQUIRES 33 `.SR` names incl. `2222.SR`; plan §0.6 = any
core failure → STOP-FOR-OWNER; `gen_universe.py` asserts Aramco first.

**Pre-fetch pins — ALL GREEN before abort (read-only, no fabrication):**
- Candidate pool: `research/UNIVERSE_CANDIDATES_2026-07-03.md` counted `CANDIDATE_ROWS = 1413` exactly.
- Current core: `StockSageQuoteService.swift` groups literal → `CORE_NOW = 210`, 35 groups, first
  symbol `2222.SR`, 0 dupes.
- App-path pins: URL `?range=1d&interval=1d` (QuoteService.swift:93); UA byte-identical to plan PF-9;
  parseable price = `meta.regularMarketPrice > 0` (:138).
- Shared-endpoint gate CLEAN before any fetch (no app process running).
- Repo tree untouched throughout (final `git status --short` = only the pre-existing
  `M skills/opus-operating/SKILL.md`).

**Resume playbook (durable):** the resumable verifier + progress state were copied to
`~/.claude/salehman-universe/` (`universe_verify.py` — modes `verify` / `timing6` / `manifest` /
`status`; `universe_progress.json` — **reset `"n429_total": 0` before resuming**, the abort counter
persists). Precondition: a few `.SR` AND `.KS/.HK/.T` core symbols must return 200 via the app path
from this machine (core verifies Saudi-first, so a still-throttled `.SR` fails fast in ≤3 requests).
Expected volume when clear: ~1,070–1,100 sequential requests ≈ 36–40 min, then `timing6`, then
`manifest`. EODHD as a substitute verifier does NOT satisfy plan §0.6's "verified through the app's
OWN v8 path" as written — using it requires a plan amendment (owner/plan-author scoped).

**Mismatches reported (beyond the throttle):**
1. Workflow prompt-template failure: every path placeholder rendered as literal `"undefined"` (the
   Workflow `args` did not interpolate); agents resolved the repo from mandated context and wrote
   artifacts only to the session scratchpad, never the repo.
2. Prompt's URL `?range=1mo&interval=1d` contradicted the plan spec `?range=1d&interval=1d` (§0.6, =
   the app's `fetchOne`). The plan/app value was used; the prompt value was NOT.

**No universe manifest was produced.** 0 rows claimed verified; no p50/p90 reported because none was
measured.

---

## 5. Fixes — verdict lines

- **L1-01 sizer/gate parse split** — **NO FIX APPLIED (owner-gated, and already mid-fix on an unmerged
  branch).** The fix is F04 sizer-parse unification, HELD for owner (DEVELOPMENT_LOG.md:10771) and WIP
  on `ideas-card/ux-wave-3` (7d5843f/2169435/d64650a). Applying a competing fix on main would collide
  with that branch and pre-empt an owner-gated display/behavior decision (the honest nil-state vs the
  1% floor). Routed to the owner as an exact question with options (recorded in the session handoff
  file `~/.claude/salehman-ideas-handoff.md`). **Verdict: BLOCKED — route, do not patch.**
- **Universe lane** — **NO FIX POSSIBLE this run.** Data-blocked (429). No code defect. **Verdict:
  BLOCKED on external throttle / owner data-path (EODHD token or the `.SR` cooldown clearing).**
- **L3-01** — **NO ACTION.** Killed at 3-vote; recorded in §3 so it isn't re-filed.

---

## 6. What this run did NOT establish

- **Did NOT establish any new engine edge.** No signal/ranking/sizing was validated or promoted. DSR
  remains ≈ 0; "no proven edge" stands. Refuse-list unchanged.
- **Did NOT verify the intl universe.** 0 of 1,024 rows; no timing measurement exists. The kept-210
  core is unverified this session; STOP-FOR-OWNER holds on `2222.SR`.
- **Did NOT confirm the throttle is cleared for `.SR`.** The probe's 200s were `.KS/.HK/.T` only; the
  `.SR` egress 429'd minutes later. No claim that Yahoo is usable for the universe run.
- **Did NOT apply the L1-01 fix.** It is owner-gated and already WIP on a branch; this run only
  re-confirmed the bug is live at HEAD `0416f79` and routed it.
- **Did NOT run the app or the test suite.** No `** TEST SUCCEEDED **` was produced by the audited run
  (docs-only landing relies on the CI gate); the L1-01 confirmation is by source-read +
  hand-derivation, not a live-app repro.
- **Did NOT do the standing visual-QA + merge of `ideas-card/ux-wave-3`** — that remains owed.
