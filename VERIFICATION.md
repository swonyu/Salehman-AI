# 🔬 VERIFICATION — turning estimates into measured evidence

The session-time code reviews include numbers (perf "high-impact" gains, WCAG
contrast ratios, accessibility scores). Some of those are computed math
(contrast); the rest are *informed estimates* that can only become real evidence
by running Instruments and Accessibility Inspector on the live app — tools that
need a human-driven macOS session. This file is the printable checklist to do
that and capture the results.

---

## A. Performance — capture an Instruments trace

The app emits `OSSignposter` intervals around every brain call. Filtering by
those in Instruments turns "estimated gains" into measured `μs`/`ms` per brain.

**Subsystem:** `com.salehman.ai` · **Category:** `Brain` · **Names:**
- `freeAuto` — wraps `generateFreeAuto` (the parallel race; includes local backstop)
- `ensemble` — wraps `generateEnsemble` (the all-brains fan-out)

(Per-brain intervals inside the race would let you see *which* brain won by how much. They aren't wired yet — would need to add a `signposter.beginInterval("freeAuto.brain")` around each `entry.run()` call site, tagged with the brain name. Bounded follow-up.)

**Steps:**
1. Build a **Debug** build (signpost overhead is negligible but Debug keeps line numbers): `xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build`
2. Launch the app: `open ".../Salehman AI.app"`
3. Open **Xcode → Open Developer Tool → Instruments**.
4. Choose the **Logging** template (signposts) or **Points of Interest**.
5. In the target chooser pick the running **Salehman AI** process.
6. Click ⏺ Record. In the app, send a message that exercises the path you want to measure (e.g. pin Free · Auto + send "hi").
7. Stop after ~5 s. In the trace, set the filter to `subsystem == "SA.Salehman-AI"`.
8. Inspect interval durations per name (and per brain for `freeAuto.brain`). Compare across brains, paid vs. free, race-winner vs. losers, before/after a change.

**Worth measuring first:**
- Free · Auto race latency vs. each brain alone (does the race add wall-time vs. Groq solo?).
- Ensemble fan-out (how much of the total is the slowest brain?).
- The `AgentPipeline` per-phase intervals once added (which phase dominates a 15-agent run?).

## B. Accessibility — Accessibility Inspector + VoiceOver audit

Wave 1 closed the color-only WCAG failure (labeled brain status) and added
VoiceOver labels to the tab bar, bubbles, action buttons, and approval modal.
These need a real screen-reader pass to verify.

### B.1 Accessibility Inspector — automated audit
1. **Xcode → Open Developer Tool → Accessibility Inspector**.
2. Top-left target picker → choose **Salehman AI** (running).
3. Switch to the **Audit** tab → **Run Audit**.
4. Expected: zero issues on the chat, the brain grid, and the approval modal.
   Common things the audit flags (and what they mean for this app):
   - *"Element has no accessibility label"* → an icon-only button missed `.accessibilityLabel`. Wave 1 added labels to known buttons; report any new offender.
   - *"Low contrast"* → the auditor reports a ratio. The hairlines are decorative (~1.4:1) by design — see `DesignSystem.swift` comment. Text and status indicators should clear 4.5:1/3:1 (computed: secondary text 8.5:1, status 9.8:1).
   - *"Hit area too small"* → flagged if <44 pt. The brain grid cells are large; tab pills are ~44 high; flag any small icon-only control.

### B.2 VoiceOver — manual sweep
1. **⌘F5** to toggle VoiceOver (or System Settings → Accessibility → VoiceOver).
2. With Salehman AI focused, navigate with **VO + arrow keys** (`VO` = Control + Option by default).
3. Expected announcements:
   - **Tab bar pill:** "Chat, tab, selected" / "Agents, tab" — announces label + selection.
   - **Brand:** announces "Salehman AI" (the sparkles logo is hidden as decorative).
   - **Market dot:** "Market, Open" or "Market, Closed".
   - **Brain grid cell:** "Apple Intelligence, Connected, button, selected" (or "Offline").
   - **Message bubble:** "You said: <your text>" or "Assistant replied: <reply>" — single utterance.
   - **Composer text field:** announces the placeholder when empty.
   - **Approval modal:** "Run this command? Command to run: <command>" then buttons: "Cancel", "Run, runs the command shown above on your Mac", "Always run without asking, disables the approval prompt for all future commands".
4. Test **reduce-motion**: System Settings → Accessibility → Display → **Reduce motion** → ON. Send a message — entrance animations should be calmer/absent.
5. Test **Dynamic Type** (planned, not yet wired): System Settings → Displays → set Larger Text. The current hardcoded font sizes (`Font.system(size: 14)` etc.) **will not** scale until `@ScaledMetric` is plumbed in (Wave 2 follow-up).

### B.3 Color-contrast verification (independent of the math)
The `DesignSystem.swift` comments quote *computed* ratios (sRGB alpha-blend
math). To verify against a real renderer:
1. Take a screenshot of the app's chat with a message visible (⇧⌘4).
2. In **Accessibility Inspector → Color Contrast** (top-right "🎨" icon), eyedrop a foreground/background pair (e.g. secondary text on canvas).
3. Confirm the reported ratio is in the same neighborhood as the computed value.

---

## C. Reporting back

If you run any of these and find divergences from the computed claims, add a
dated entry to `DEVELOPMENT_LOG.md` (per `CLAUDE.md`):

```
## <date> · A11y/perf audit results (Accessibility Inspector / Instruments)
**Files:** (none, evidence only)
**What & why:** ran <which audit>. Found <discrepancy or confirmation>.
**Result:** updated the <comment / code> to match measured reality.
```

Measured evidence beats inferred — and we'd rather correct a wrong number than
ship one with confidence.
