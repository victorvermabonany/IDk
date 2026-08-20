import XCTest

final class WeektableUITests: XCTestCase {
    func testWelcomeCompletesOnceAndRelaunchesIntoHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-cove-ui-test-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Your week of food,\nfigured out."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Continue as guest"].exists)

        app.buttons["Continue as guest"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Plan a new week"].exists)

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Continue as guest"].exists)
    }

    func testActivePlanRelaunchesIntoWeek() {
        let app = XCUIApplication()
        app.launchArguments = ["-cove-ui-test-reset", "-cove-ui-test-active-plan"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Week"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["Groceries"].exists)
        XCTAssertTrue(app.tabBars.buttons["Pantry"].exists)
        XCTAssertFalse(app.buttons["Continue as guest"].exists)
    }

    func testGenerationShowsCurrentBackendStageAndRealMetadata() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cove-ui-test-reset",
            "-cove-ui-test-generation",
            "-cove-ui-test-pause-generation",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Checking your store"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Matching ingredients to available products and prices."].exists)
        XCTAssertTrue(app.staticTexts["18 ingredients combined"].exists)
        XCTAssertTrue(app.staticTexts["16 products matched"].exists)
        XCTAssertFalse(app.progressIndicators.firstMatch.exists)
    }
}
