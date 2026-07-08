# PLAN_2026-07-08_burrow_engine_ideas_card

## Scope
Adopt proven open-source architecture patterns (Freqtrade/Lean/OpenBB/Ghostfolio class) for StockSage engine + Ideas surfaces.

Guardrails:
- No code copy/paste from external repos.
- Preserve current math outputs unless a step explicitly changes behavior.
- Enforce parity across Ideas card, detail sheet, Today card, and exported text.

## 1-Page Implementation Spec (line-mapped)

### A. Decision Snapshot Contract (single source of truth)
Goal: one composed model feeds all views so gate/size/net-vs-gross/warnings cannot drift.

Target files:
- Salehman AI/StockSage/StockSageExpectedValue.swift:453, 520, 741
- Salehman AI/StockSage/StockSageTradeGate.swift:45
- Salehman AI/StockSage/StockSagePositionSizer.swift:22
- Salehman AI/StockSage/StockSageNetEdge.swift:67

Implementation:
1. Add an immutable decision snapshot struct (symbol, action, evGross/net, velocityGross/net, gate verdict, size, rank reasons, calibration provenance).
2. Build snapshot in one place after ranking/decorate and before UI.
3. Replace ad-hoc repeated computations in views with snapshot reads.

Acceptance:
- Same verdict text/value across all consumers for same symbol and input state.

### B. Ranking Reasons + Demotion Explainability
Goal: every ranking/demotion is legible and testable.

Target files:
- Salehman AI/StockSage/StockSageExpectedValue.swift:303, 361, 656, 1014, 949, 984

Implementation:
1. Standardize rank reason codes: earnings_demote, liquidity_demote, floor_demote, low_conviction_demote, concentration_haircut.
2. Attach reasons into snapshot and summary/playbook output.
3. Keep current ranking math; expose reason metadata only.

Acceptance:
- For top-N and Today plan rows, reason list explains ordering and any demotion.

### C. Ideas Board/Sheet Parity via Shared ViewModel
Goal: board and sheet render identical decision facts.

Target files:
- Salehman AI/Views/MarketsView.swift:2989, 3174, 4838, 4993
- Salehman AI/Views/MarketsView.swift:2979 (shared earningsWarningRow)

Implementation:
1. Add IdeaCardViewModel and IdeaDetailViewModel adapters from the same snapshot.
2. Ensure trade gate panel and warning chips consume snapshot only.
3. Keep existing layout; replace data wiring.

Acceptance:
- No board/sheet mismatch in gate verdict, R:R label semantics, net/gross tag, warning severity.

### D. Today Plan as Pure Projection of Fast Lane
Goal: Today list stays a deterministic projection (no hidden second ranking system).

Target files:
- Salehman AI/StockSage/StockSageTodayPlan.swift:21, 127, 216
- Salehman AI/Views/MarketsTodayActionsCard.swift:13, 76, 182

Implementation:
1. rankedActions consumes snapshot output (or same composer) not independent recomputation.
2. copyAllText uses same gate/size/reason/provenance fields as row render.
3. Preserve existing wording contracts (blocked/floor/low conviction tags).

Acceptance:
- Today card, copy export, and sheet show byte-identical decision semantics.

### E. Calibration Provenance Contract Everywhere EV Appears
Goal: measured/fitted/assumed status visible and consistent.

Target files:
- Salehman AI/StockSage/StockSageConvictionCalibration.swift:98, 529, 705, 715
- Salehman AI/Views/MarketsView.swift:24, 2843

Implementation:
1. Require provenance token with every EV display payload.
2. Route chip title/help from calibration single-source fields only.
3. Prevent any identity-path value from being labeled measured.

Acceptance:
- All EV surfaces include aligned provenance text and tooltip semantics.

### F. Alerts as State Transitions (not opaque events)
Goal: alert rows explain what changed, not just current state.

Target files:
- Salehman AI/Views/MarketsView.swift:624, 3650

Implementation:
1. Add transition fields to alert payload: from_state, to_state, trigger_type.
2. Render transition + confidence context in alerts row/details.
3. Keep existing color semantics (dangerSoft/successSoft) and warning icon behavior.

Acceptance:
- Each alert can answer: what changed, why now, and confidence posture.

## Delivery Slices (safe sequence)
1. Slice A: snapshot struct/composer only (no UI changes).
2. Slice B: Ideas board + sheet rewire to snapshot.
3. Slice C: Today plan + copy export rewire to snapshot.
4. Slice D: calibration provenance enforcement sweep.
5. Slice E: alert transition model + UI wiring.

## Verification Map
- Salehman AITests/StockSageTodayPlanRankedTests.swift:34, 75, 315
- Salehman AITests/StockSageExpectedValueTests.swift:281, 663
- Salehman AITests/StockSageCalibrationSelectorTests.swift:10

Add/extend tests:
1. Parity test: same symbol/state -> board/sheet/today/export share gate + labels.
2. Demotion reason test: each reason code emitted where expected.
3. Provenance test: identity path never labeled measured.
4. Transition test: alert emits from->to and trigger deterministically.

## Done Criteria
- Typecheck/build green.
- Target tests green + new parity/provenance/transition tests green.
- No behavior drift in ranking math unless explicitly approved.
- MARKETS_TAB_MAP updated with new snapshot/parity invariants.
