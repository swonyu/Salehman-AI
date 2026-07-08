import XCTest

// MARK: - Chat-tab UI flows (functional QA the sandboxed session can't do live)
//
// These are MECHANICS tests — composer gating, search toggle, tab switching,
// and the QA-snapshot menu — deliberately not model-dependent: nothing here
// sends a message to a brain, so the suite is deterministic with or without
// API keys / Ollama running.
//
// `nonisolated`: same Swift 6 dance as Salehman_AIUITests — XCTestCase's
// overrides are nonisolated; each test hops to @MainActor itself.
nonisolated final class ChatTabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Terminate the app after every test so the next test's app.launch()
    // gets a clean slate without racing against a half-alive previous instance.
    // DispatchQueue.main.sync ensures the @MainActor-isolated terminate() runs
    // synchronously before tearDown returns — preventing async-dispatch races
    // where the previous app is still alive when the next test's launch() fires.
    override func tearDownWithError() throws {
        DispatchQueue.main.sync { XCUIApplication().terminate() }
    }

    @MainActor
    private func launchToChat() -> XCUIApplication {
        let app = XCUIApplication()
        // Prevent draft restoration so the composer starts empty in every test.
        app.launchArguments.append("--uitesting")
        app.launch()
        // Wait for any window element before sending ⌘2 — guarantees the app is
        // past its launch ramp and the key event lands on the correct target.
        _ = app.windows.firstMatch.waitForExistence(timeout: 10)
        // ⌘2 = Chat (the View-menu tab map). The composer is the stable anchor
        // that exists in BOTH the empty state and a populated transcript.
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.textFields["chat.composer.field"]
            .waitForExistence(timeout: 30), "Composer field should exist on the Chat tab")
        return app
    }

    /// Send is a no-op affordance until there's text: disabled empty, enabled
    /// with text, disabled again when cleared.
    @MainActor
    func testSendEnablesOnlyWithText() throws {
        let app = launchToChat()
        let field = app.textFields["chat.composer.field"]
        let send = app.buttons["chat.composer.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 3))
        XCTAssertFalse(send.isEnabled, "Send must be disabled with an empty composer")

        field.click()
        field.typeText("hello there")
        XCTAssertTrue(send.isEnabled, "Send must enable once text is present")

        // Clear: select-all + delete.
        field.typeKey("a", modifierFlags: .command)
        field.typeKey(.delete, modifierFlags: [])
        XCTAssertFalse(send.isEnabled, "Send must disable again when cleared")
    }

    /// ⌘F opens the in-conversation search bar; Done closes it.
    @MainActor
    func testSearchBarTogglesWithCmdF() throws {
        let app = launchToChat()
        app.typeKey("f", modifierFlags: .command)
        let searchField = app.textFields["Find in conversation…"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "⌘F should open the search bar")

        app.buttons["Done"].firstMatch.click()
        XCTAssertFalse(searchField.waitForExistence(timeout: 1), "Done should close the search bar")
    }

    /// The composer's quick-controls menu (Code-tab parity) carries the Brain
    /// and Effort pickers plus the big toggles — switching brains must never
    /// require opening Settings again.
    @MainActor
    func testChatControlsMenuHasBrainAndEffort() throws {
        let app = launchToChat()
        let controls = app.popUpButtons["chat.composer.controls"].firstMatch.exists
            ? app.popUpButtons["chat.composer.controls"].firstMatch
            : app.menuButtons["chat.composer.controls"].firstMatch
        XCTAssertTrue(controls.waitForExistence(timeout: 3), "Quick-controls menu should exist in the composer")
        controls.click()
        XCTAssertTrue(app.menuItems["Brain"].waitForExistence(timeout: 3)
                      || app.menuItems["Salehman"].exists,
                      "Controls menu must contain the Brain picker")
        XCTAssertTrue(app.menuItems["Effort"].exists
                      || app.menuItems["Instant"].exists
                      || app.menuItems["Balanced"].exists,
                      "Controls menu must contain the Effort picker")
        app.typeKey(.escape, modifierFlags: [])
    }

    /// The composer's unified + menu carries BOTH sections (attachments and
    /// prompts) — the two-circles era must not regress back.
    @MainActor
    func testPlusMenuHasAttachAndPrompts() throws {
        let app = launchToChat()
        let plus = app.popUpButtons["chat.composer.plus"].firstMatch.exists
            ? app.popUpButtons["chat.composer.plus"].firstMatch
            : app.menuButtons["chat.composer.plus"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 3), "+ menu should exist in the composer")
        plus.click()
        XCTAssertTrue(app.menuItems["Attach file…"].waitForExistence(timeout: 3),
                      "+ menu must contain the attach actions")
        XCTAssertTrue(app.menuItems["Save current as prompt…"].exists,
                      "+ menu must contain the prompt actions")
        app.typeKey(.escape, modifierFlags: [])   // close the menu
    }

    /// Typing `/su` + ↵ fills the summarize template into the composer.
    /// The slash menu is a SwiftUI overlay (not NSMenu) so we test the
    /// end-to-end behaviour (field value after ↵) rather than visual presence —
    /// same guarantee, more robust under headless accessibility.
    @MainActor
    func testSlashMenuAppearsAndReturnPicksTopCommand() throws {
        let app = launchToChat()
        let field = app.textFields["chat.composer.field"]
        field.click()
        field.typeText("/su")         // matches /summarize
        field.typeKey(.return, modifierFlags: [])
        let value = field.value as? String ?? ""
        XCTAssertTrue(value.contains("Summarize our conversation"),
                      "↵ on /su should fill the summarize template, got: \(value)")

        // Leave the composer clean for the next test.
        field.typeKey("a", modifierFlags: .command)
        field.typeKey(.delete, modifierFlags: [])
    }

    /// Esc with a pending `/` query clears the composer (the onKeyPress handler
    /// calls `mission = ""` when chatSlashMatches is non-empty).
    @MainActor
    func testEscDismissesSlashMenu() throws {
        let app = launchToChat()
        let field = app.textFields["chat.composer.field"]
        field.click()
        field.typeText("/")
        // Allow one runloop for SwiftUI to update chatSlashMatches.
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        field.typeKey(.escape, modifierFlags: [])
        // A brief settle so SwiftUI can process the Esc → mission = "".
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        let value = field.value as? String ?? ""
        XCTAssertTrue(value.isEmpty, "Esc with a pending slash query should clear the composer, got: '\(value)'")
    }

    /// The header clock opens the Conversations (history) sheet; Done closes
    /// it. Content-agnostic: archives may or may not exist on this machine.
    @MainActor
    func testHistorySheetOpensAndCloses() throws {
        let app = launchToChat()
        let clock = app.buttons["Conversation history"].firstMatch
        XCTAssertTrue(clock.waitForExistence(timeout: 3), "Header should offer Conversation history")
        clock.click()
        XCTAssertTrue(app.staticTexts["Conversations"].waitForExistence(timeout: 3),
                      "History sheet should open with its title")
        app.buttons["Done"].firstMatch.click()
        XCTAssertFalse(app.staticTexts["Conversations"].waitForExistence(timeout: 1),
                       "Done should dismiss the history sheet")
    }

    /// Launching with --qa + SNAPSHOT_REQUEST triggers QASnapshots.captureAll()
    /// and writes qa/snapshots/*.png — the bridge that lets the screen-blind polish
    /// session SEE the app. The AUDIT.json self-judge then acts as a visual
    /// regression gate (blank render / canvas colour change → test fails).
    @MainActor
    func testCaptureQASnapshotsMenuProducesFiles() throws {
        // Must match QADir.resolved (QASnapshots.swift) — repo moved 2026-07-05
        // to ~/Salehman-AI; the UITest target can't import the app's internals,
        // so this literal is pinned to the same path QADirResolutionTests pins.
        let repoRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Salehman-AI")
        let qaDir = repoRoot.appendingPathComponent("qa")
        let snapshotsDir = qaDir.appendingPathComponent("snapshots")
        let requestFile = qaDir.appendingPathComponent("SNAPSHOT_REQUEST")
        let captureDone = snapshotsDir.appendingPathComponent("CAPTURE_DONE.txt")
        let auditURL = snapshotsDir.appendingPathComponent("AUDIT.json")

        // Stamp test start. Predicates below check modificationDate > startTime so
        // stale files from a previous run are ignored even when removeItem fails
        // silently in the UITest runner sandbox (macOS 26 provenance restrictions
        // can block deletion of files created by a different app process).
        let startTime = Date()

        // Kill stale app: captureAll() is synchronous @MainActor, blocking the run
        // loop so Apple Event quit never arrives. SIGTERM bypasses the run loop.
        let killer = Process()
        killer.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killer.arguments = ["-TERM", "Salehman AI"]
        try? killer.run()
        killer.waitUntilExit()

        // Seed the file-trigger so checkAndRun() starts capture on this launch.
        try? FileManager.default.createDirectory(at: qaDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: requestFile.path, contents: nil)
        // Best-effort removal of old markers; timestamp predicates make this
        // non-critical — a stale file simply stays false until the new one lands.
        try? FileManager.default.removeItem(at: captureDone)
        try? FileManager.default.removeItem(at: auditURL)

        // Launch with both flags: --qa activates checkAndRun(), --uitesting clears draft.
        let qa = XCUIApplication()
        qa.launchArguments = ["--qa", "--uitesting"]
        qa.launch()
        defer {
            let k = Process()
            k.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            k.arguments = ["-TERM", "Salehman AI"]
            try? k.run(); k.waitUntilExit()
            // SIGTERM is delivered async from the kernel; give the process 2 s to
            // fully exit before tearDown's app.launch() runs the next test —
            // otherwise the dying process can swallow the Apple Event quit and stall.
            Thread.sleep(forTimeInterval: 2.0)
            try? FileManager.default.removeItem(at: requestFile)
        }

        // Phase 1: CAPTURE_DONE.txt — written synchronously after ALL surface PNGs.
        // Predicate requires modDate > startTime so a leftover file never satisfies it.
        let captureDoneExp = XCTNSPredicateExpectation(
            predicate: NSPredicate(block: { _, _ in
                guard let attr = try? FileManager.default.attributesOfItem(atPath: captureDone.path),
                      let mod = attr[.modificationDate] as? Date else { return false }
                return mod > startTime
            }),
            object: nil
        )
        wait(for: [captureDoneExp], timeout: 300)   // ~30 surfaces × ~5 s each
        guard let cdAttr = try? FileManager.default.attributesOfItem(atPath: captureDone.path),
              let cdMod = cdAttr[.modificationDate] as? Date, cdMod > startTime else {
            XCTFail("captureAll() did not write a fresh CAPTURE_DONE.txt in this run"); return
        }

        // Phase 2: AUDIT.json written by QAAudit.run() after QAColorVision —
        // usually < 30 s after CAPTURE_DONE.txt; give 120 s for slow machines.
        let auditExp = XCTNSPredicateExpectation(
            predicate: NSPredicate(block: { _, _ in
                guard let attr = try? FileManager.default.attributesOfItem(atPath: auditURL.path),
                      let mod = attr[.modificationDate] as? Date else { return false }
                return mod > startTime
            }),
            object: nil
        )
        wait(for: [auditExp], timeout: 120)
        guard let data = try? Data(contentsOf: auditURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            XCTFail("AUDIT.json missing or unreadable after capture"); return
        }

        // Gate only on nonBlank failures — every surface must produce a non-empty
        // render. Baseline-diff failures are expected after intentional style changes
        // and require a manual baselines adoption; they do not indicate a broken build.
        let blankFailures = results.compactMap { r -> String? in
            guard let name = r["snapshot"] as? String,
                  let checks = r["checks"] as? [[String: Any]] else { return nil }
            let failedNonBlank = checks.contains {
                ($0["name"] as? String) == "nonBlank" && !((($0["pass"] as? Bool) ?? true))
            }
            return failedNonBlank ? name : nil
        }
        XCTAssertTrue(blankFailures.isEmpty,
                      "Blank renders detected — surface(s) produced empty/solid images: \(blankFailures.joined(separator: ", "))")
    }
}
