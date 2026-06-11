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

    @MainActor
    private func launchToChat() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        // ⌘2 = Chat (the View-menu tab map). The composer is the stable anchor
        // that exists in BOTH the empty state and a populated transcript.
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.textFields["chat.composer.field"]
            .waitForExistence(timeout: 5), "Composer field should exist on the Chat tab")
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

    /// View ▸ Capture QA Snapshots renders every surface to qa/snapshots/*.png —
    /// the bridge that lets the screen-blind polish session SEE the app. This
    /// test both verifies the menu item and (as a side effect of running in
    /// the gate) delivers fresh snapshots to that session.
    @MainActor
    func testCaptureQASnapshotsMenuProducesFiles() throws {
        let app = launchToChat()
        let snapshotsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Salehman AI/qa/snapshots")
        let marker = snapshotsDir.appendingPathComponent("chat_samples.png")
        try? FileManager.default.removeItem(at: marker)

        app.menuBars.menuBarItems["View"].click()
        let item = app.menuBars.menuItems["Capture QA Snapshots"]
        XCTAssertTrue(item.waitForExistence(timeout: 3), "View menu should offer Capture QA Snapshots")
        item.click()

        // Rendering ~13 surfaces takes a moment; poll for the marker file.
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline, !FileManager.default.fileExists(atPath: marker.path) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path),
                      "Snapshot capture should write qa/snapshots/chat_samples.png")

        // The capture self-judges (QAAudit → AUDIT.json). A visual regression —
        // blank render, canvas losing the flat grey — fails THIS test, i.e.
        // fails the gate, exactly like a broken unit test would.
        let auditURL = snapshotsDir.appendingPathComponent("AUDIT.json")
        let auditDeadline = Date().addingTimeInterval(10)
        while Date() < auditDeadline, !FileManager.default.fileExists(atPath: auditURL.path) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        guard let data = try? Data(contentsOf: auditURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let failures = json["failures"] as? [String] else {
            XCTFail("AUDIT.json missing or unreadable after capture"); return
        }
        XCTAssertTrue(failures.isEmpty, "Visual audit failures: \(failures.joined(separator: ", "))")
    }
}
