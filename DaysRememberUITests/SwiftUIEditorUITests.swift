import XCTest

final class SwiftUIEditorUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testGregorianPickerKeepsTheStoredDayOutsideShanghaiTimeZone() {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchEnvironment["TZ"] = "America/Los_Angeles"
        app.launchArguments = ["--seed-sample-data", "--tab", "home"]
        app.launch()
        app.buttons["添加日子"].tap()

        let dateButton = app.buttons["dayDatePickerButton"]
        XCTAssertTrue(dateButton.waitForExistence(timeout: 5))
        XCTAssertTrue(dateButton.label.contains("2026年4月23日"))
        dateButton.tap()
        let originalDay = app.buttons["4月23日 星期四"]
        XCTAssertTrue(originalDay.waitForExistence(timeout: 5))
        XCTAssertTrue(originalDay.isSelected)
        app.buttons["完成"].tap()
        XCTAssertTrue(dateButton.label.contains("2026年4月23日"))

        dateButton.tap()
        let selectedDay = app.buttons["4月1日 星期三"]
        XCTAssertTrue(selectedDay.waitForExistence(timeout: 5))
        selectedDay.tap()
        app.buttons["完成"].tap()
        XCTAssertTrue(dateButton.label.contains("2026年4月1日"))

        let title = "Timezone-" + UUID().uuidString.prefix(8)
        app.textFields["日子名称"].tap()
        app.textFields["日子名称"].typeText(title)
        app.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["添加日子"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["--tab", "home"]
        app.launch()
        app.buttons["搜索日子"].tap()
        app.textFields["搜索日子"].tap()
        app.textFields["搜索日子"].typeText(title)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch.tap()
        app.buttons["更多操作"].tap()
        app.buttons["pencil"].firstMatch.tap()
        XCTAssertTrue(dateButton.waitForExistence(timeout: 5))
        XCTAssertTrue(dateButton.label.contains("2026年4月1日"))
        dateButton.tap()
        XCTAssertTrue(selectedDay.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedDay.isSelected)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Gregorian day preserved with Los Angeles process time zone"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
