//
//  Salehman_AIUITestsLaunchTests.swift
//  Salehman AIUITests
//
//  Created by saleh alayed on 18/12/1447 AH.
//

import XCTest

// `nonisolated` so the XCTestCase overrides match the superclass's isolation under
// this target's MainActor-default setting (see sibling file). Test methods stay `@MainActor`.
nonisolated final class Salehman_AIUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
