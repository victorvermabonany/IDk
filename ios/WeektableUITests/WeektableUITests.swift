import XCTest

final class WeektableUITests: XCTestCase {
    func testPrimaryPlanningJourney() {
        let app = XCUIApplication()
        app.launch()

        if app.buttons["Plan my week"].waitForExistence(timeout: 2) {
            app.buttons["Plan my week"].tap()
            XCTAssertTrue(app.staticTexts["Where are you shopping?"].waitForExistence(timeout: 2))
            app.buttons["Continue"].tap()
            XCTAssertTrue(app.staticTexts["How much dinner do you need?"].exists)
        } else {
            XCTAssertTrue(app.tabBars.buttons["Week"].waitForExistence(timeout: 2))
        }
    }
}

