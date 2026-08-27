import XCTest

final class NCOMAIUITests: XCTestCase {
    func testNCOMPrimarySurface() {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING"]
        app.launch()

        XCTAssertTrue(app.staticTexts["NCOM AI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Apple Foundation Models + NCOM Engine"].exists)
        XCTAssertTrue(app.staticTexts["CHAT"].exists)
        XCTAssertTrue(app.textFields["chatInput"].exists)
        XCTAssertTrue(app.buttons["sendButton"].exists)
    }

    func testChatInputAcceptsText() {
        let app = XCUIApplication()
        app.launch()
        let input = app.textFields["chatInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Hello NCOM")
        XCTAssertEqual(input.value as? String, "Hello NCOM")
    }

    func testRootNavigationSurfaces() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Chat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Apps"].exists)
        XCTAssertTrue(app.tabBars.buttons["Devices"].exists)
        XCTAssertTrue(app.tabBars.buttons["Desktop"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
}
