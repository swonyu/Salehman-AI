# 🔧 GROK_FIXES — review-gate → implementer hand-off queue

**Protocol (owner-directed 2026-06-27):** The **REFINE Claude session** (review gate, does NOT edit `Views/*`) posts every real **Grok-agent mistake** it catches here as an actionable fix-ticket. The **Markets-UI Claude session** (the implementer in the `Views/*` lane) picks tickets up, fixes them, build-verifies, and marks them `✅ DONE`. This is the unattended-safe channel (file-based — works while the owner is away; `send_message` needs live confirmation and can't be used unattended).

**Ticket format:**
```
### [ ] <id> — <one-line title>   (found <time>)
- File(s): <path:line>
- The mistake: <what the agent did wrong, traced to the call site>
- The fix: <exactly what to change>
- Verify: <build / a specific test / a value>
- Lane: Views/* (Markets-UI session) — refine session won't touch it
```
Implementer: flip `[ ]`→`[x]`, append `✅ DONE <commit> <time>` when fixed + build-green.

---

## Standing context (mistakes caught so far this session)

- **`#12` handoff diff (relayed Grok) — 2 bugs, caught pre-commit.** Fire-and-forget broke the awaited velocity-record caller (`MarketsView:164-168`); removing the `defer` re-broke the stuck spinner. Refine session shipped the corrected version itself (`5d3e071`) — *already fixed, no action.*
- **Agent-1 ideas extraction — broken intermediate state, self-reverted.** It rewired `MarketsView.swift:2333` `ideasSection` to call `MarketsIdeasSection(...)` but left the old `VStack { ideasHeader; … }` body **dangling** (orphan) AND `MarketsIdeasSection.swift` was **empty (0 lines)** → wouldn't compile. The agents reverted it before it persisted. *Currently clean.* **WATCH:** if they re-attempt this extraction and stall mid-way again, a ticket lands below.

---

## Open tickets

_(none yet — tree is clean at `5d3e071`. The refine session's cron appends here when it catches a real, persisting break.)_
Fixed orphaned gpPerHour in glossary per backlog #32 (moved comment to RuneScape context).
