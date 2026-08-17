import XCTest

final class WeektableUITests: XCTestCase {
    func testPrimaryPlanningJourney() {
        let app = XCUIApplication()
        app.launch()

        if app.buttons["Plan my first week"].waitForExistence(timeout: 2) {
            app.buttons["Plan my first week"].tap()
            XCTAssertTrue(app.staticTexts["Where are you shopping?"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.buttons["Find stores"].exists)
        } else {
            XCTAssertTrue(app.tabBars.buttons["Week"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.tabBars.buttons["Groceries"].exists)
        }
    }
}
