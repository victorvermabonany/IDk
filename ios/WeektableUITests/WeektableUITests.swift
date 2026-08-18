import XCTest

final class WeektableUITests: XCTestCase {
    func testWelcomeCompletesOnceAndRelaunchesIntoPlanner() {
        let app = XCUIApplication()
        app.launchArguments = ["-cove-ui-test-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Your week, planned."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Plan my first week"].exists)

        app.buttons["Plan my first week"].tap()
        XCTAssertTrue(app.staticTexts["Where do you shop?"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Find stores"].exists)
        XCTAssertFalse(app.buttons["Close"].exists)

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.staticTexts["Where do you shop?"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Plan my first week"].exists)
        XCTAssertFalse(app.buttons["Close"].exists)
    }

    func testActivePlanRelaunchesIntoWeek() {
        let app = XCUIApplication()
        app.launchArguments = ["-cove-ui-test-reset", "-cove-ui-test-active-plan"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Week"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons["Groceries"].exists)
        XCTAssertFalse(app.buttons["Plan my first week"].exists)
    }
}
