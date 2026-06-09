//
//  Salehman_AIUITests.swift
//  Salehman AIUITests
//
//  Created by saleh alayed on 18/12/1447 AH.
//

import XCTest

// `nonisolated`: this target is MainActor-default (mirrors the app), but XCTestCase's
// init/setUpWithError/… are nonisolated — overriding them from a MainActor-isolated
// class is a Swift 6 error. The per-test methods keep their own `@MainActor`.
nonisolated final class Salehman_AIUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
