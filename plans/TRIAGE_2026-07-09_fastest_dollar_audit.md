# TRIAGE — fastest-dollar audit findings (wf_28dbe2ff-f00, recovered from the usage-limit session)

**Source:** 2-lens audit (account-size honesty / velocity truth) + 1 adversarial verification per finding: 10 findings, 5 CONFIRMED / 5 REVISED / 0 REFUTED. Raw payloads: the workflow journal (session d5fc417d) + scratchpad extract. Re-triaged against main @ f626f52 (2026-07-09 late): every finding below re-verified live by grep before inclusion.

## Wave A — display-honesty fixes (SHIP NOW; no cost value, gate math, sizing, or ranking change)

| # | Finding (post-verification) | Fix shape |
|---|---|---|
| F1/F3 | Whole-share flooring makes top-velocity ideas unfundable-as-recommended at small accounts (crypto rows size to 0 shares at $10k) while still holding #1 slots — silent | Fundability disclosure: when the sized order at the CURRENT account/risk floors to 0 shares, the idea card sized-line + Today row say so explicitly ("below 1-share minimum at your account size") — reuse the existing sized-order/refusal-line machinery (EXPORT-W4-1 precedent). NO demotion (that would be a ranking change). |
| F4 | "≈ +$N/week" header dollarizes weekly R with acct × risk% and no fundability check — overstates ~3–4× when the fast lane holds unfundable rows | Header keeps its number (byte-identical math) but gains the honest qualifier when ANY contributing top-row is unfundable at the current account size — extend the F03/F44 net-headline disclosure pattern. |
| F5 | allocate() silently drops 0-share positions; Deploy card hides entirely when all drop | Deploy card empty/degraded state names the reason ("all N positions below 1-share minimum at this account size") instead of vanishing — same nil-gate honesty pattern as F04 (0c58648). |
| F7 | `calibrationNote` (StockSageExpectedValue) is dead code — zero external callers | DELETE (audit D-2 dead-code precedent: delete rather than wire; wiring would be a new display decision). |
| F8 | Global "Do this now" CTA and Today-plan "#1 first" can name DIFFERENT symbols with no cross-reference | When they diverge, each surface discloses the other's pick in its existing sub-line ("Today's plan leads with X — different lens"). Copy-only. |
| F9 | Money-velocity card pairs "net X (gross Y)" where net and gross are summed over potentially DIFFERENT top-3 baskets | Correctness fix in `summary()`: compute BOTH sums over the SAME basket (the displayed one). This is display-string math only — no rank key, no gate. Hand-derived fixture required (straddle: baskets differ → old strings differ, new strings same-basket). |
| F10 | Short financing note uses the default hold estimator even when the owner's journal carries measured holds | Disclosure-only: financing note gains "(assumed hold)" qualifier — matches the honesty floor's "estimates labeled assumed". NOT re-plumbing EV inputs (that changes netEVR = ranking-adjacent). |

## Staged — ranking/cost-model class (NOT in this wave; evidence attached for the owner/validation path)
- **F6 (REVISED):** Today's plan crowns #1 with a RAW/gross EV-day tiebreak while net velocity is computed and discarded (`StockSageTodayPlan` `.equityExecutableFirst`, sort note "fastest raw EV/day"). Flipping the order to net = ranking change → needs empirical validation or explicit owner order (honesty-floor rule; RANKING #10 disposition precedent). Wave A adds NO order change; the sort-explainer copy already truthfully says "raw".
- **F2 (CONFIRMED):** NetEdge is pure-bps; flat per-order commission minimums (52–120bps RT on small orders, per the cost research) are invisible — the gate can pass trades whose true cost is dominated by minimums at small accounts. Cost-MODEL shape change → staged; the fundability disclosures (F1/F3/F4) carry the honest signal meanwhile.

## Order of work
Single Sonnet implementer in a worktree (WIP commits) → Fable review → fix pass → my independent gate on merged tree → ship via pipeline → pixel QA (fixtures: markets_ideas + blocked + nilrisk + journal as touched).
