import SwiftUI
import AppKit

/// **Self-snapshot QA harness** — the app photographs its own surfaces.
///
/// Why: the sandboxed AI session that polishes this UI cannot see the screen
/// (`screencapture` and AppleScript are both blocked there), but it CAN read
/// files in the repo. `ImageRenderer` renders SwiftUI views to PNG entirely
/// in-process — no Screen Recording permission, no window server involvement —
/// so the app can hand that session real pictures of every tab.
///
/// Two triggers:
/// * **File request:** drop a file named `SNAPSHOT_REQUEST` in `<repo>/qa/`,
///   relaunch (or foreground) the app → snapshots appear in
///   `<repo>/qa/snapshots/*.png` and the request file is consumed. This lets
///   a headless session request pictures and a normal launch fulfill them.
/// * **Menu:** View ▸ “Capture QA Snapshots” runs the same capture on demand.
///
/// Determinism: alongside the LIVE views (whatever state the stores hold),
/// `ChatSampleGallery` renders a fixed set of message/composer states so
/// before/after comparisons don't depend on the owner's real chat history.
///
/// Limits (by design): `ImageRenderer` draws static view trees — no hover,
/// focus, or sheet states. Those stay covered by the UI-test flows; this
/// harness is for LAYOUT/STYLE eyes.
/// SINGLE source of truth for the `<repo>/qa` directory. `QASnapshots`,
/// `QAAudit`, and `QACapture` ALL resolve through here. They used to carry
/// per-file copies ("kept self-contained so the files never block on each
/// other's in-flight edits") — that split is exactly what broke on the
/// 2026-07-05 repo move: only QASnapshots' copy was repointed, so captures
/// landed in the live repo while baseline adoption (QAAudit) wrote/read the
/// dead Desktop copy and the pixel-diff tripwire silently compared against
/// nothing. Same-module files block each other at compile time anyway, so
/// the self-contained copies bought nothing. QADirResolutionTests pins this.
enum QADir {
    /// Repo root: this is a personal app pinned to the owner's machine layout
    /// (same assumption the training scripts make). Overridable for safety
    /// via `QA_SNAPSHOT_DIR`.
    static var resolved: URL {
        if let custom = ProcessInfo.processInfo.environment["QA_SNAPSHOT_DIR"] {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        // Repo moved 2026-07-05: ~/Desktop/Salehman AI → ~/Salehman-AI. The old Desktop copy
        // still exists — captures must land in the LIVE repo or tools/qa.sh waits forever.
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Salehman-AI/qa", isDirectory: true)
    }
}

@MainActor
enum QASnapshots {

    /// Shared repo-root resolution — see `QADir.resolved`.
    private static var qaDir: URL { QADir.resolved }

    /// Launch hook: capture if `qa/SNAPSHOT_REQUEST` is present. The request
    /// file is consumed AFTER a successful capture — a launch that quits
    /// mid-render (e.g. a quick UI-test run) leaves the request in place so
    /// the NEXT launch retries instead of silently eating it. Small delay
    /// lets the singleton stores finish their first load.
    static func checkAndRun() {
        // Baseline adoption trigger (QAAudit): promote the CURRENT snapshots
        // to qa/baselines so future captures diff against them.
        let adopt = qaDir.appendingPathComponent("ADOPT_BASELINES")
        if FileManager.default.fileExists(atPath: adopt.path) {
            QAAudit.adoptBaselinesDefault()
            try? FileManager.default.removeItem(at: adopt)
        }
        let request = qaDir.appendingPathComponent("SNAPSHOT_REQUEST")
        guard FileManager.default.fileExists(atPath: request.path) else { return }
        // Owner-launch protection: a pending request used to make EVERY launch
        // (Dock, Spotlight…) render ~30 surfaces + run the pixel audit on the main
        // thread ≈1s in — a big slice of "the app always lags when launched".
        // Captures now run only on QA-initiated launches (`open … --args --qa`,
        // which tools/qa.sh passes). A request seen WITHOUT the flag is left in
        // place, so the next qa.sh launch still fulfills it — never silently eaten.
        guard ProcessInfo.processInfo.arguments.contains("--qa") else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            // The owner's PERSISTED board-preference @AppStorage keys (sort/filter/min-strength/
            // sizer) can filter the deterministic QA fixture ideas down to zero cards ("No ideas
            // at ≥ 60% signal strength") — @AppStorage just reads UserDefaults, it doesn't know
            // this render is a QA capture. NSArgumentDomain launch-arg overrides were tried and
            // are INERT for these keys (confirmed; do not retry that path). Neutralize them in
            // UserDefaults for the duration of this capture, then restore — --qa path ONLY, never
            // the View-menu manual capture (that stays live-state, same as seedQAIdeas above).
            let restore = neutralizeIdeaBoardPrefsForQA()
            defer { restore() }
            // Scan-deltas seam (PLAN_2026-07-07_scan_deltas.md): seed a previous-scan baseline
            // BEFORE seedQAIdeas so it reads a deterministic baseline — BTC-USD is ABSENT (→ its
            // card renders "New") and AAPL's previous action was "Hold" (→ AAPL renders "was
            // Hold"; AAPL's card is earnings+extreme+EV = 4 chips, so the delta chip is its 5th,
            // still inside the density cap). In-memory only via StockSageScanSnapshotStore.qaSeed
            // — never touches the real stocksage.prevscan.v1 UserDefaults key. seedQAIdeas reads
            // this baseline but never calls save() on it.
            let restoreScanSnapshot = seedQAScanSnapshot()
            defer { restoreScanSnapshot() }
            // Neutral prefs BEFORE seeding so every render (fixtures included) sees them.
            await StockSageStore.shared.seedQAIdeas()
            // "Own it" awareness (ideas card/sheet held-position chip): seed ONE fake NVDA lot
            // so the QA capture actually exercises the Held chip/line. NVDA (not AAPL — 2026-
            // 07-07 fix round issue #2): NVDA's card has chip headroom (strongBuy + at-extreme
            // + combined + EV = 4-5 chips) AND NVDA is the seeded qaDetailSymbol, i.e. an
            // actually-captured sheet surface — so the combined chip, Held line, and Journal
            // line all get real pixels instead of AAPL's uncaptured card. In-memory only —
            // qaSeed assigns StockSagePortfolio.positions directly, bypassing save(), so
            // nothing is written to the owner's real UserDefaults. Restored (also in-memory
            // only) in the same defer as the board prefs above, mirroring
            // neutralizeIdeaBoardPrefsForQA's save→restore-exact shape even though persistence
            // was never touched here.
            let restorePortfolio = seedQAPortfolio()
            defer { restorePortfolio() }
            // "Your history with this name" (2026-07-07 assessment gap #2): seed 2 fake CLOSED
            // NVDA trades so the QA capture exercises the "Traded Nx" chip / Journal sheet line
            // on the same NVDA fixture symbol seedQAPortfolio uses (moved off AAPL alongside
            // it — see seedQAPortfolio's doc comment). In-memory REPLACE, same seam shape as
            // seedQAPortfolio (StockSageJournalStore.qaSeed bypasses save()).
            // MONEY-CRITICAL: 3 trades keeps StockSageConvictionCalibration.fit(fromJournal:)'s
            // minSamples=30 floor un-crossed (fit returns nil during the capture window) —
            // see qaSeed's doc comment in StockSageJournal.swift for the full seam analysis.
            let restoreJournal = seedQAJournal()
            defer { restoreJournal() }
            captureAll()
            try? FileManager.default.removeItem(at: request)
        }
    }

    /// Save the CURRENT value of every board-filter/sizer @AppStorage key, then overwrite
    /// each with its neutral value so the QA fixture ideas aren't filtered out by whatever
    /// the owner last left the board set to. Returns a restore closure — call it (via `defer`
    /// in the caller) to put every key back exactly as found, `nil` → removed, not merely unset.
    ///
    /// Defaults chosen to match the app's shipped defaults (never implying a different
    /// permanent default — RANKING #10 is owner-gated): "EV / day" is `IdeaSort.velocity`'s
    /// rawValue, "All" is `IdeaFilter.all`'s rawValue.
    ///
    /// Crash-safety: restoration runs in the caller's `defer`, so any thrown/early-return path
    /// out of the capture Task restores. A hard process kill mid-capture (SIGKILL, force-quit)
    /// cannot run any Swift code including `defer` — that residual risk is accepted, not
    /// silently swallowed: qa.sh's flow quits the app right after `captureAll()` returns, so the
    /// only way to leak neutral prefs into the owner's real UserDefaults is a kill in that
    /// narrow window, not an ordinary crash/throw.
    private static func neutralizeIdeaBoardPrefsForQA() -> () -> Void {
        let neutral: [String: Any] = [
            "marketsIdeaSort": "EV / day",
            "marketsIdeaFilter": "All",
            "marketsIdeaMinConv": 0.0,
            "marketsSizerAccount": "10000",
            "marketsSizerRiskPct": "1",
        ]
        let defaults = UserDefaults.standard
        let saved: [String: Any?] = neutral.keys.reduce(into: [:]) { acc, key in
            acc[key] = defaults.object(forKey: key)
        }
        for (key, value) in neutral { defaults.set(value, forKey: key) }
        return {
            for (key, original) in saved {
                if let original {
                    defaults.set(original, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
    }

    /// Seed ONE fake position (NVDA, 30 sh @ $100.00) so the QA capture actually exercises
    /// the "own it" Held chip (ideaCard badge row) and Held line (detail sheet) on a real
    /// fixture symbol — `qaFixtureDefs()` includes NVDA (strongBuy/bullTrend, and the seeded
    /// qaDetailSymbol so the sheet actually renders — 2026-07-07 fix round issue #2, moved off
    /// AAPL, whose card/sheet were never captured). `qaSeed` is an in-memory-only assign
    /// (StockSagePortfolio.qaSeed bypasses save()), so this never reaches UserDefaults; the
    /// returned closure restores whatever real positions were loaded (owner's actual holdings,
    /// or none), same save→restore-exact shape as `neutralizeIdeaBoardPrefsForQA` above.
    ///
    /// Residual risk, same acceptance as `neutralizeIdeaBoardPrefsForQA`'s documented SIGKILL
    /// window: a hard process kill mid-capture skips the restore closure entirely (in-memory
    /// state just dies with the process — no UserDefaults write, so nothing persists). The
    /// second, narrower residual specific to this seam: the owner clicking Add/Remove position
    /// on the real UI during the ~1-2s seeded window would `save()` the fake NVDA lot into real
    /// UserDefaults (StockSagePortfolio.add/remove both persist), overwriting whatever
    /// `seedQAPortfolio` captured to restore. Accepted, not silently swallowed: qa.sh's flow
    /// runs unattended (owner isn't clicking through the app during a capture run).
    private static func seedQAPortfolio() -> () -> Void {
        let portfolio = StockSagePortfolio.shared
        let saved = portfolio.positions
        portfolio.qaSeed([
            PortfolioPosition(symbol: "NVDA", shares: 30, costBasis: 100.00),
            // QA-3 (2026-07-07 fix round): 1120.SR is the sell-family/bearTrend fixture — seeding
            // a held position exercises the Held-only chip on a SHORT-plan card (NVDA/7010.SR only
            // cover the long side). Verify 1120.SR's total conditional-chip count stays ≤
            // IdeaChipPlan.cap after this seed — see the derivation in the fix-round report.
            PortfolioPosition(symbol: "1120.SR", shares: 50, costBasis: 80.00),
        ])
        return { portfolio.qaSeed(saved) }
    }

    /// Seed 3 fake CLOSED trades (2 NVDA + 1 7010.SR) (realizedR +0.8 and −0.3 → "Traded 2x" chip / "+0.5R total"
    /// sheet line, hand-derived) so the QA capture exercises the "your history with this name"
    /// chip/line on the same NVDA fixture symbol seedQAPortfolio holds. In-memory REPLACE via
    /// `StockSageJournalStore.qaSeed` — bypasses `save()`, never touches UserDefaults.
    ///
    /// MONEY-CRITICAL (why REPLACE, not append): `trades` feeds `StockSageStore.
    /// convictionCalibration` through a fit memoized on the trades array's VALUE. Appending one
    /// fake trade to the owner's REAL journal could cross `StockSageConvictionCalibration.
    /// fit(fromJournal:)`'s minSamples=30 floor (StockSageConvictionCalibration.swift:99) mid-
    /// capture and silently change what calibration the rest of the capture renders. A REPLACE
    /// with exactly 2 fake trades keeps outcomes.count (2) < 30 ⇒ fit(fromJournal:) returns nil
    /// ⇒ convictionCalibration falls back to the backtest fit / prior — the same "win% assumed"
    /// path the fixtures already render, deterministic and boundary-safe. The restore below is
    /// itself a qaSeed replace, so the VALUE-keyed memo cache invalidates and recomputes the
    /// owner's real calibration on the very next post-capture read — nothing leaks.
    ///
    /// Same residual-risk acceptance as `seedQAPortfolio`: a hard kill mid-capture skips the
    /// restore (in-memory only, nothing persists); qa.sh's flow runs unattended.
    private static func seedQAJournal() -> () -> Void {
        let store = StockSageJournalStore.shared
        let saved = store.trades
        let now = Date()
        store.qaSeed([
            TradeRecord(symbol: "NVDA", side: .long, entry: 190, stop: 185, target: 200,
                        shares: 10, openedAt: now.addingTimeInterval(-86_400 * 10),
                        exitPrice: 194, closedAt: now.addingTimeInterval(-86_400 * 5)),   // realizedR = +0.8
            TradeRecord(symbol: "NVDA", side: .long, entry: 190, stop: 185, target: 200,
                        shares: 10, openedAt: now.addingTimeInterval(-86_400 * 4),
                        exitPrice: 188.5, closedAt: now.addingTimeInterval(-86_400 * 2)),  // realizedR = -0.3
            // QA-1 (2026-07-07 fix round): one hand-derived LOSING closed 7010.SR trade — long
            // entry 100 / stop 95 / exit 98. riskPerShare = |100-95| = 5; perShare = (98-100) =
            // -2; realizedR = -2/5 = -0.4R. Exercises the Traded-only chip on 7010.SR (the
            // vol-brake fixture, no held position) and the brake sheet's dangerSoft negative
            // Journal line. Keeps total seeded trades at 3 — still < the calibration
            // minSamples=30 floor (see this function's MONEY-CRITICAL doc above); conviction
            // stays nil (not an idea-sourced trade), so it never feeds the calibration fit.
            TradeRecord(symbol: "7010.SR", side: .long, entry: 100, stop: 95, target: nil,
                        shares: 20, openedAt: now.addingTimeInterval(-86_400 * 8),
                        exitPrice: 98, closedAt: now.addingTimeInterval(-86_400 * 3)),   // realizedR = -0.4
        ])
        return { store.qaSeed(saved) }
    }

    /// Seed a deterministic previous-scan baseline (PLAN_2026-07-07_scan_deltas.md) so the
    /// capture exercises both delta chips: BTC-USD is ABSENT from the baseline (→ "New") and
    /// AAPL's previous action was "Hold" (→ "was Hold"). NVDA/1120.SR/7010.SR are seeded at
    /// their OWN current fixture action so they render no delta chip (unchanged), keeping the
    /// capture focused on the two symbols the plan calls out. In-memory REPLACE via
    /// StockSageScanSnapshotStore.qaSeed — bypasses save(), never touches the real
    /// stocksage.prevscan.v1 UserDefaults key.
    private static func seedQAScanSnapshot() -> () -> Void {
        let store = StockSageScanSnapshotStore.shared
        let saved = store.entries
        store.qaSeed([
            "NVDA": "Strong Buy",
            "AAPL": "Hold",
            "1120.SR": "Sell",
            "7010.SR": "Reduce",
            // BTC-USD deliberately absent → renders "New".
        ])
        return { store.qaSeed(saved) }
    }

    /// Render every main surface + the deterministic chat gallery, then write
    /// a `CAPTURE_DONE.txt` marker (timestamp + file list) so a remote session
    /// can verify completion without listing PNGs.
    /// One captured surface, recorded for the manifest + contact sheet.
    private struct Shot { let name: String; let desc: String; let w: Int; let h: Int; let ok: Bool; let ms: Int }
    private static var shots: [Shot] = []

    /// Structural results (layout geometry + accessibility tree) per surface —
    /// written to STRUCTURE.json for `QAAudit` to fold into the verdict.
    private static var structure: [String: QASurfaceStructure] = [:]

    static func captureAll() {
        let dir = qaDir.appendingPathComponent("snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        shots.removeAll()
        structure.removeAll()
        QAGeometry.enabled = true
        defer { QAGeometry.enabled = false }

        // ── Code tab ─────────────────────────────────────────────────────────
        snap(CodeView(),           "code_tab",     "Code tab — live (welcome, file tree, composer, collapsed panels)", .init(width: 1180, height: 820), in: dir)
        snap(CodeSampleGallery(),  "code_samples", "Code tab — deterministic states (blocks, code, table, Arabic RTL, streaming, agent strip, refusal)", .init(width: 860, height: 1560), in: dir)
        // ── Main chat ────────────────────────────────────────────────────────
        // The chat renders also feed the GEOMETRY probe: ContentView reports
        // its reading-column + composer frames, and the audit asserts the
        // 780pt-centered invariants at both widths.
        QAGeometry.reset()
        snap(ContentView(),        "chat_live",    "Main chat — LIVE (owner's real history; gitignored)", .init(width: 1000, height: 780), in: dir)
        structure["chat_live", default: .init()].geo = QAGeometry.chatAssertions(rootWidth: 1000)
        snap(ContentView(qaForceEmptyState: true),
                                   "chat_empty",   "Main chat — first-impression welcome (QA-forced empty state)", .init(width: 1000, height: 780), in: dir)
        snap(ChatSampleGallery(),  "chat_samples", "Main chat — deterministic message/streaming/agent/hover/approval states", .init(width: 820, height: 1780), in: dir)
        // ── Responsive — narrow widths catch layout breaks (centered column, composer wrap) ──
        QAGeometry.reset()
        snap(ContentView(),        "chat_narrow",  "Main chat @ 560pt — responsive / layout-break check", .init(width: 560, height: 760), in: dir)
        structure["chat_narrow", default: .init()].geo = QAGeometry.chatAssertions(rootWidth: 560)
        snap(CodeView(),           "code_narrow",  "Code tab @ 640pt — responsive / layout-break check", .init(width: 640, height: 760), in: dir)
        // ── Every other tab — flat-canvas restyle spot-check ────────────────
        snap(TodayView(),          "today",        "Today dashboard", .init(width: 1000, height: 740), in: dir)
        snap(AgentsView(),         "agents",       "Agents tab", .init(width: 1000, height: 740), in: dir)
        snap(ScratchpadView(),     "notes",        "Notes / scratchpad", .init(width: 1000, height: 700), in: dir)
        snap(KnowledgeView(),      "knowledge",    "Knowledge tab", .init(width: 1000, height: 700), in: dir)
        snap(MarketsView(qaSection: .watchlist), "markets",  "Markets tab", .init(width: 1000, height: 740), in: dir)
        snap(MarketsView(qaSection: .heatmap), "markets_heatmap", "Markets — heatmap sub-section (tile colour-contrast)", .init(width: 1000, height: 640), in: dir)
        // Ideas board — QA-seeded fixture ideas (real buildIdeas pipeline on synthetic
        // histories; sample-bannered). Tall frame: the board sits below header/velocity/
        // CTA/best-opportunity/fast-lane/backtest panels — 740pt would show zero cards.
        snap(MarketsView(qaSection: .ideas), "markets_ideas", "Markets — Ideas board (seeded fixtures: strongBuy/buy/sell/crypto/⚠vol + earnings chip)", .init(width: 1000, height: 2400), in: dir)
        // Full-height board: the 2400pt frame above cuts the last two fixture cards (1120.SR,
        // 7010.SR) below the fold, leaving their chip states (Held-only on 1120.SR — the one
        // context-chip form with no owned pixel) unverifiable. 3400pt reaches all five cards.
        snap(MarketsView(qaSection: .ideas), "markets_ideas_full", "Markets — Ideas board FULL height (all five fixture cards incl. the sell-family tail)", .init(width: 1000, height: 3400), in: dir)
        // 2026-07-09 (window #3): the day's new branches — BLOCKED gate chips on the
        // prescriptive cards, strike-through rows, copy auto-skip, and the honest-nil
        // gate states — previously had only the happy CAUTION fixture in pixels; these two
        // deterministic states make every future QA pass cover them. Same in-capture
        // override discipline as neutralizeIdeaBoardPrefsForQA: values restored to the
        // NEUTRAL set right after (the outer restore closure then puts the owner's own
        // values back at the end of captureAll).
        let qaStateDefaults = UserDefaults.standard
        qaStateDefaults.set("3", forKey: "marketsSizerRiskPct")   // > 2% cap ⇒ every buy gate BLOCKED
        snap(MarketsView(qaSection: .ideas), "markets_ideas_blocked", "Markets — Ideas board, risk% ABOVE the 2% cap (every gate BLOCKED: DO-NOT-TRADE chips, struck rows, copy auto-skip)", .init(width: 1000, height: 2400), in: dir)
        qaStateDefaults.set("", forKey: "marketsSizerRiskPct")    // no inputs ⇒ honest-nil gates
        qaStateDefaults.set("", forKey: "marketsSizerAccount")
        snap(MarketsView(qaSection: .ideas), "markets_ideas_nilrisk", "Markets — Ideas board, no account/risk set (honest-nil gates: set-risk badges, nil-gate empty state, no fabricated verdicts)", .init(width: 1000, height: 2400), in: dir)
        qaStateDefaults.set("1", forKey: "marketsSizerRiskPct")     // back to the neutral set
        qaStateDefaults.set("10000", forKey: "marketsSizerAccount")
        // Idea-detail SHEET content, rendered inline (no .sheet presentation) via the
        // qaDetailSymbol QA seam — NVDA is the seeded strongBuy fixture with resolvable
        // US costs, so the Evidence gross→net fused lines render. Sheet frame caps at
        // maxWidth 680, so 700 captures it fully unclipped.
        snap(MarketsView(qaDetailSymbol: "NVDA"), "markets_idea_detail", "Markets — idea detail sheet content (NVDA strongBuy fixture)", .init(width: 700, height: 1600), in: dir)
        snap(MarketsView(qaDetailSymbol: "NVDA"), "markets_idea_detail_narrow", "Markets — idea detail sheet @ 460pt — responsive / layout-break check", .init(width: 460, height: 1600), in: dir)
        // 7010.SR is the vol-brake fixture (293 bars → volRegime resolves, brake < 0.85):
        // with QA's nil market-regime it is the ONLY seeded idea where ≥2 sizing stages
        // resolve, i.e. the positive-path proof for the sizing-brake waterfall (NVDA's
        // 250 bars < 273 → volRegime nil → waterfall correctly renders nothing there).
        snap(MarketsView(qaDetailSymbol: "7010.SR"), "markets_idea_detail_brake", "Markets — idea detail sheet (7010.SR vol-brake fixture: sizing waterfall positive path)", .init(width: 700, height: 1600), in: dir)
        // QA-2 (2026-07-07 fix round): the sizing waterfall's only narrow-width surface — every
        // other narrow snapshot uses the NVDA fixture, whose 250 bars can't resolve volRegime
        // (see the comment above), so the waterfall itself was never checked for narrow-width
        // wrap/clip.
        snap(MarketsView(qaDetailSymbol: "7010.SR"), "markets_idea_detail_brake_narrow", "Markets — idea detail sheet (7010.SR vol-brake fixture) @ 460pt — the waterfall's only narrow-width surface", .init(width: 460, height: 1600), in: dir)
        // Memory is a SHEET (round-1 audit caught it floating in a 1000×700
        // frame with uncomposited margins) — capture at its natural sheet size.
        snap(MemoryView(),         "memory",       "Memory sheet", .init(width: 500, height: 620), in: dir)
        // History sheet renders its EMPTY state offscreen (onAppear never
        // fires, so the archive list never loads) — deterministic by accident,
        // and exactly the first-impression surface worth baselining.
        snap(ChatHistoryView(onRestore: { _ in }), "chat_history", "Conversation-history sheet (empty state)", .init(width: 520, height: 560), in: dir)
        snap(SettingsView(),       "settings",     "Settings sheet", .init(width: 560, height: 640), in: dir)
        // ── Readability probe — every text-style/surface pairing the design
        // language uses, in fixed bands the audit measures for CONTRAST (the
        // invisible-code-text class of bug, caught by eyes in round 1, is now
        // caught by arithmetic every capture).
        snap(ContrastProbe(),      "contrast_probe", "Readability probe — text/surface contrast bands (audited vs WCAG-style ratios)", .init(width: 600, height: CGFloat(ContrastProbe.bands.count) * ContrastProbe.bandHeight), in: dir)
        // ── QA v6 (Chat C): previously-uncaptured sheets ─────────────────────
        snap(OnboardingView(onDone: {}),  "onboarding",      "Onboarding — first-run welcome (page 1)", .init(width: 540, height: 600), in: dir)
        snap(AboutView(onClose: {}),      "about",           "About sheet — identity + capabilities", .init(width: 460, height: 560), in: dir)
        snap(ShortcutsView(onClose: {}),  "shortcuts",       "Keyboard-shortcuts cheat sheet (⌘/)", .init(width: 380, height: 470), in: dir)
        snap(CommandPalette(onClose: {}), "command_palette", "Command palette (⌘K)", .init(width: 560, height: 520), in: dir)
        // VoiceModeView is intentionally NOT captured: its .onAppear runs
        // session.start() (the mic) — an offscreen QA render must not trigger it.
        // ── Responsive: narrow widths catch layout breaks on the flexible tabs ──
        snap(TodayView(),     "today_narrow",     "Today @ 560pt — responsive / layout-break check", .init(width: 560, height: 760), in: dir)
        snap(MarketsView(qaSection: .watchlist), "markets_narrow", "Markets @ 560pt — responsive / layout-break check", .init(width: 560, height: 760), in: dir)
        snap(MarketsView(qaSection: .ideas), "markets_ideas_narrow", "Markets Ideas board @ 560pt — responsive / chip-wrap check", .init(width: 560, height: 2800), in: dir)
        snap(KnowledgeView(), "knowledge_narrow", "Knowledge @ 560pt — responsive / layout-break check", .init(width: 560, height: 760), in: dir)

        // Bridge layout + accessibility findings to the audit. MERGE, don't
        // overwrite: `captureLiveWindows` contributes window_* entries (the
        // only place AX trees are real), and a fresh offscreen capture was
        // clobbering them (caught when window_0_live lost its axLabels check).
        let url = dir.appendingPathComponent("STRUCTURE.json")
        var merged: [String: QASurfaceStructure] =
            (try? Data(contentsOf: url))
                .flatMap { try? JSONDecoder().decode([String: QASurfaceStructure].self, from: $0) } ?? [:]
        merged = merged.filter { $0.key.hasPrefix("window_") }   // keep only live-window entries
        for (k, v) in structure { merged[k] = v }
        if let data = try? JSONEncoder().encode(merged) {
            try? data.write(to: url)
        }

        writeManifest(in: dir)
        buildContactSheet(in: dir)
        // Keep the simple completion marker too (the other session's watcher reads it).
        let names = shots.map(\.name).sorted()
        let marker = "captured \(shots.filter(\.ok).count)/\(shots.count) snapshots at \(Date())\n"
            + names.joined(separator: "\n") + "\n"
        try? marker.write(to: dir.appendingPathComponent("CAPTURE_DONE.txt"), atomically: true, encoding: .utf8)

        // Self-judge the pictures: AUDIT.json (nonBlank / canvasFlat / baseline
        // diff + heat-maps). The UI-test gate asserts failures == [].
        // Color-vision pass (Chat C, QA v6): deuteranopia/protanopia previews +
        // red-green "merge" detection. Runs BEFORE the audit so its cvd.json is
        // fresh when the audit folds CVD status into report.html.
        QAColorVision.run(snapshotsDir: dir)

        QAAudit.run(snapshotsDir: dir,
                    baselinesDir: qaDir.appendingPathComponent("baselines"))
    }

    /// ONE render path: host the view offscreen in an `NSHostingView` and cache
    /// its layer to a bitmap. Round-1 evidence (see qa history): plain
    /// `ImageRenderer` silently produced blank/placeholder PNGs for everything
    /// wrapping AppKit or lazy/scroll containers — Settings was a flat panel,
    /// Today pure white, the live transcript empty, TextField/Menu drew yellow
    /// "unsupported" boxes. Hosting gives every view a real AppKit context, so
    /// scroll views populate and controls draw. Slightly heavier per shot;
    /// correctness wins.
    private static func snap<V: View>(_ view: V, _ name: String, _ desc: String, _ size: CGSize, in dir: URL) {
        let start = Date()
        let host = NSHostingView(rootView:
            view.frame(width: size.width, height: size.height)
                .preferredColorScheme(.dark)
                .tint(DS.Palette.accent)
        )
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        var ok = false
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            rep.size = host.bounds.size
            host.cacheDisplay(in: host.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                ok = (try? png.write(to: dir.appendingPathComponent("\(name).png"))) != nil
            }
        }
        // Accessibility sweep on the laid-out tree: count interactive elements
        // and collect the UNLABELED ones (icon-only buttons that lost their
        // .accessibilityLabel/.help — the audit fails on any).
        let ax = axScan(host)
        structure[name, default: .init()].axInteractive = ax.interactive
        structure[name, default: .init()].axUnlabeled = ax.unlabeled
        structure[name, default: .init()].axTargets = ax.targets
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        structure[name, default: .init()].renderMs = ms
        shots.append(Shot(name: name, desc: desc, w: Int(size.width), h: Int(size.height), ok: ok, ms: ms))
    }

    /// Recursive accessibility-tree walk. Interactive roles must carry a label,
    /// title, or help text — VoiceOver users get nothing otherwise.
    static func axScan(_ root: NSView) -> (interactive: Int, unlabeled: [String], targets: [Double]) {
        var interactive = 0
        var unlabeled: [String] = []
        var targets: [Double] = []
        let interactiveRoles: Set<NSAccessibility.Role> = [
            .button, .popUpButton, .menuButton, .checkBox, .radioButton, .slider, .link,
        ]
        func walk(_ node: Any, depth: Int) {
            guard depth < 60 else { return }
            guard let ax = node as? any NSAccessibilityProtocol else { return }
            if let role = ax.accessibilityRole(), interactiveRoles.contains(role) {
                interactive += 1
                let label = (ax.accessibilityLabel() ?? "").trimmingCharacters(in: .whitespaces)
                let title = (ax.accessibilityTitle() ?? "").trimmingCharacters(in: .whitespaces)
                let help = (ax.accessibilityHelp() ?? "").trimmingCharacters(in: .whitespaces)
                if label.isEmpty && title.isEmpty && help.isEmpty {
                    unlabeled.append(role.rawValue)
                }
                let f = ax.accessibilityFrame()
                if f.width > 0, f.height > 0 { targets.append(Double(min(f.width, f.height))) }
            }
            for child in ax.accessibilityChildren() ?? [] { walk(child, depth: depth + 1) }
        }
        walk(root, depth: 0)
        return (interactive, unlabeled, targets)
    }

    /// Markdown manifest: what each PNG shows, its size, render status + time, the
    /// commit it was captured at — so the blind session reading the PNGs has full context.
    private static func writeManifest(in dir: URL) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")          // force Gregorian (owner's locale renders Hijri)
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let okN = shots.filter(\.ok).count
        var md = """
        # QA snapshots — Salehman AI
        **\(f.string(from: Date()))** · commit `\(gitHead())` · **\(okN)/\(shots.count)** surfaces OK · \
        see `contact_sheet.png` for a one-glance montage.

        In-process `ImageRenderer` captures (no Screen-Recording permission). Static layout/style only —
        hover/focus/sheet states stay on the manual checklist. Re-capture: View ▸ Capture QA Snapshots,
        or `touch qa/SNAPSHOT_REQUEST` and launch.

        | file | shows | size | status | render |
        |---|---|---|---|---|

        """
        for s in shots {
            md += "| `\(s.name).png` | \(s.desc) | \(s.w)×\(s.h) | \(s.ok ? "✅" : "❌ FAILED") | \(s.ms) ms |\n"
        }
        try? md.write(to: dir.appendingPathComponent("INDEX.md"), atomically: true, encoding: .utf8)
    }

    /// Montage of every captured surface (thumbnail + label) into one PNG — lets the
    /// remote session eyeball the WHOLE app in a single image before drilling in.
    private static func buildContactSheet(in dir: URL) {
        let cols = 4
        let thumbs: [(String, NSImage)] = shots.filter(\.ok).compactMap { s in
            NSImage(contentsOf: dir.appendingPathComponent("\(s.name).png")).map { (s.name, $0) }
        }
        guard !thumbs.isEmpty else { return }
        let rows = stride(from: 0, to: thumbs.count, by: cols).map { Array(thumbs[$0..<min($0+cols, thumbs.count)]) }
        let sheet = VStack(alignment: .leading, spacing: 14) {
            Text("Salehman AI — QA contact sheet").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 5) {
                            Image(nsImage: item.1).resizable().aspectRatio(contentMode: .fit)
                                .frame(width: 250, height: 170)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.12)))
                            Text(item.0).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        .frame(width: 250)
                    }
                }
            }
        }
        .padding(20).background(DS.Palette.codeSurfaceSide)
        let r = ImageRenderer(content: sheet.frame(width: CGFloat(cols) * 264 + 40).fixedSize()
            .preferredColorScheme(.dark).tint(DS.Palette.accent))
        r.scale = 1.5
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("contact_sheet.png"))
        }
    }

    /// Best-effort short git SHA (reads `.git` directly, no shell-out).
    private static func gitHead() -> String {
        let g = qaDir.deletingLastPathComponent().appendingPathComponent(".git")
        guard let head = try? String(contentsOf: g.appendingPathComponent("HEAD"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return "unknown" }
        guard head.hasPrefix("ref: ") else { return String(head.prefix(8)) }
        let ref = String(head.dropFirst(5))
        if let sha = try? String(contentsOf: g.appendingPathComponent(ref), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) { return String(sha.prefix(8)) }
        if let packed = try? String(contentsOf: g.appendingPathComponent("packed-refs"), encoding: .utf8) {
            for l in packed.split(separator: "\n") where l.hasSuffix(ref) { return String(l.prefix(8)) }
        }
        return "ref:" + (ref.split(separator: "/").last.map(String.init) ?? "?")
    }
}

/// Deterministic chat states for stable before/after comparison: a short user
/// block, a long user paste (wrap-measure check), an assistant markdown
/// document, a follow-up burst, the streaming row, the typing dots, and the
/// agent strip — everything the heavy-polish passes touched.
/// Fixed contrast bands: each row is one text-style/surface pairing at a known
/// fractional y-position, so `QAAudit` can measure glyph-vs-background contrast
/// without OCR — band i's center line sits at (i + 0.5) / bands.count of the
/// image height. Order here MUST match `QAAudit.contrastBands`.
struct ContrastProbe: View {
    static let bandHeight: CGFloat = 56

    /// (label, text style, foreground, background, minimum contrast, enforced).
    /// `enforced=false` = advisory: measured + reported in AUDIT.json/report
    /// but doesn't fail the gate — used while a fix needs the other session's
    /// lane. MainActor like the DS tokens it reads; both consumers
    /// (`captureAll`, `QAAudit.contrastChecks`) are MainActor too.
    static var bands: [(String, CGFloat, Color, Color, Double, Bool)] {
        [
            ("body on canvas",        14,   Color.white.opacity(0.92),      DS.Palette.codeSurface,     4.5, true),
            ("secondary on canvas",   11,   DS.Palette.textSecondary,       DS.Palette.codeSurface,     3.0, true),
            ("body on panel",         14,   Color.white.opacity(0.92),      DS.Palette.codeSurfaceSide, 4.5, true),
            ("secondary on panel",    11,   DS.Palette.textSecondary,       DS.Palette.codeSurfaceSide, 3.0, true),
            ("body on user block",    13.5, .white,                         Color(white: 0.125 + 0.09), 4.5, true),
            ("white on accent (send)", 13,  .white,                         DS.Palette.accent,          3.0, true),
            // v4's first run flagged this at 2.21:1 — root cause was the AUDIT
            // computing luma in gamma space; with proper sRGB linearization the
            // true ratio is ≈4.3:1. Enforced with correct math. (The advisory
            // flag stays available for genuine cross-lane waits.)
            ("accent on canvas",      13,   DS.Palette.accent,              DS.Palette.codeSurface,     3.0, true),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.bands.enumerated()), id: \.offset) { _, band in
                ZStack {
                    band.3
                    // Heavy glyph coverage across the scan line → the sampler
                    // reliably hits glyph cores despite anti-aliasing.
                    Text("HHHH \(band.0) — 0123 السلام HHHH")
                        .font(.system(size: band.1, weight: .medium))
                        .foregroundStyle(band.2)
                        .lineLimit(1)
                }
                .frame(height: Self.bandHeight)
            }
        }
    }
}

private struct ChatSampleGallery: View {
    private let now = Date(timeIntervalSince1970: 1_781_200_000)   // fixed clock

    private var samples: [ChatMessage] {
        [
            ChatMessage(id: UUID(), text: "hi", isUser: true, timestamp: now),
            ChatMessage(id: UUID(),
                        text: "Hello Saleh — ready when you are. What should we work on?",
                        isUser: false, timestamp: now.addingTimeInterval(4)),
            ChatMessage(id: UUID(),
                        text: "Summarize this long requirements paragraph I pasted so we can sanity-check the user block's 480pt wrap measure, padding, and corner radius against the design language.",
                        isUser: true, timestamp: now.addingTimeInterval(60)),
            ChatMessage(id: UUID(),
                        text: """
                        Here's the summary:

                        **Key points**
                        - The composer uses the Claude text-over-controls layout
                        - Assistant replies are flush-left *documents* — no bubbles
                        - Hover actions float on a panel pill

                        ```swift
                        let rhythm = (burst: 10, speakers: 24)
                        ```

                        Want me to apply this to the remaining views?
                        """,
                        isUser: false, timestamp: now.addingTimeInterval(75)),
            ChatMessage(id: UUID(), text: "yes — and keep the motion subtle.",
                        isUser: true, timestamp: now.addingTimeInterval(95)),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            gallerySection("Messages — rhythm, blocks, document flow") {
                // Plain VStack on purpose: round-1 evidence showed a Lazy stack
                // misplacing a sample row below later sections in static renders.
                VStack(spacing: 10) {
                    ForEach(samples) { msg in MessageBubble(message: msg) }
                }
            }
            gallerySection("Streaming row — dot above, leading edge final") {
                StreamingBubble(text: "Streaming a reply right now — the text's left edge must already be at its committed position…")
            }
            gallerySection("Typing dots — pre-stream") {
                TypingIndicator()
            }
            gallerySection("Agent strip — flat panel, live counter, tool round note") {
                AgentRunView(steps: [
                    .init(name: "Reasoning Strategist", icon: "brain.head.profile",
                          status: .running, adapted: "Reasoning Strategist · tool round 3/8"),
                    .init(name: "Final Output Quality Owner", icon: "checkmark.seal.fill",
                          status: .pending),
                ])
            }
            // States a static render can't reach naturally — forced visible so
            // they get eyes + baseline protection like everything else.
            gallerySection("Hover state — floating action pill + reply timing (QA-forced)") {
                MessageBubble(message: ChatMessage(id: UUID(),
                                                   text: "Hover actions float on a panel pill — timing, speak, copy, regenerate — without reserving layout.",
                                                   isUser: false,
                                                   timestamp: now.addingTimeInterval(120),
                                                   duration: 4.2),
                              onRegenerate: { _ in },
                              onQuote: { _ in },
                              qaShowActions: true)
                    .padding(.top, 14)   // room for the pill's -4 offset above the row
            }
            gallerySection("Failure row — inline retry under the unavailable message") {
                MessageBubble(message: ChatMessage(id: UUID(),
                                                   text: LocalLLM.offMessage,
                                                   isUser: false,
                                                   timestamp: now.addingTimeInterval(140)),
                              onRegenerate: { _ in })
            }
            gallerySection("User row hover — edit & resend + copy (QA-forced)") {
                MessageBubble(message: ChatMessage(id: UUID(),
                                                   text: "Edit this message and resend it — the turn re-opens in the composer.",
                                                   isUser: true,
                                                   timestamp: now.addingTimeInterval(150)),
                              onEdit: { _ in },
                              qaShowActions: true)
                    .padding(.top, 14)
            }
            gallerySection("Time separator — burst boundary") {
                TimeSeparator(date: now)
            }
            gallerySection("Approval card — the command gate") {
                ApprovalCard(command: "ls -la ~/Desktop", onRun: {}, onCancel: {}, onAlways: {})
                    .frame(height: 300)
                    .clipped()
            }
            gallerySection("Scroll-to-latest — solid accent pill") {
                ScrollToLatestButton(unreadCount: 3) {}
            }
        }
        .padding(28)
        // Pin to the TOP of the fixed snapshot frame — round 1 centered the
        // content vertically, wasting a third of the picture as dead space.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.Palette.codeSurface)
    }

    private func gallerySection<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold)).tracking(1.2)
                .foregroundStyle(DS.Palette.textSecondary)
            content()
        }
    }
}
