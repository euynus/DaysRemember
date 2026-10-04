import XCTest

final class WidgetHomeUITests: XCTestCase {
    func testWidgetOnHomeScreen() throws {
        guard #available(iOS 18, *) else {
            throw XCTSkip("The Home Screen resize shortcut requires iOS 18 or newer.")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--seed-sample-data", "--tab", "home"]
        app.launch()
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = home.icons["时光"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 10), home.debugDescription)
        icon.press(forDuration: 1.2)
        let small = home.buttons["Small widget"]
        XCTAssertTrue(small.waitForExistence(timeout: 10), home.debugDescription)
        if small.isSelected {
            XCUIDevice.shared.press(.home)
        } else {
            small.tap()
        }
        let content = home.staticTexts.matching(NSPredicate(format: "label IN %@", ["天后", "天前", "今天"])).firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 30), home.debugDescription)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Widget on Home Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
        icon.tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 10), app.debugDescription)
        XCUIDevice.shared.press(.home)
        icon.press(forDuration: 1.2)
        let edit = home.buttons["Edit Widget"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), home.debugDescription)
        edit.tap()
        let configuration = XCUIApplication(bundleIdentifier: "com.apple.WorkflowUI.WidgetConfigurationExtension")
        let choose = configuration.tables.buttons.firstMatch
        XCTAssertTrue(choose.waitForExistence(timeout: 10), configuration.debugDescription)
        choose.tap()
        let pastDay = configuration.buttons["小年糕出生"].firstMatch
        XCTAssertTrue(pastDay.waitForExistence(timeout: 10), configuration.debugDescription)
        pastDay.tap()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(home.staticTexts["小年糕出生"].waitForExistence(timeout: 30), home.debugDescription)
        XCTAssertTrue(home.staticTexts["天前"].exists)
        let configured = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        configured.name = "Configured past day on Home Screen"
        configured.lifetime = .keepAlways
        add(configured)
    }
}
