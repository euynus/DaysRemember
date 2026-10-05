import XCTest

final class WidgetHomeUITests: XCTestCase {
    func testWidgetOnHomeScreen() throws {
        guard #available(iOS 18, *) else {
            throw XCTSkip("The Home Screen resize shortcut requires iOS 18 or newer.")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--seed-sample-data", "--seed-widget-photo", "--tab", "home"]
        app.launch()
        XCTAssertTrue(app.buttons["home.addDay"].waitForExistence(timeout: 10), app.debugDescription)
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = home.icons.matching(NSPredicate(format: "label IN %@", ["时光", "時光", "Days Remember"])).firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 10), home.debugDescription)
        icon.press(forDuration: 1.2)
        let small = home.buttons["Small widget"]
        XCTAssertTrue(small.waitForExistence(timeout: 10), home.debugDescription)
        if small.isSelected {
            XCUIDevice.shared.press(.home)
        } else {
            small.tap()
        }
        let content = icon.staticTexts.matching(NSPredicate(
            format: "label IN %@", ["天后", "天前", "今天", "d left", "d ago", "Today"]
        )).firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 30), home.debugDescription)
        // Reset an existing widget's selection before testing a configuration change.
        selectDay("结婚纪念日", in: home, widget: icon)
        XCTAssertTrue(icon.staticTexts["结婚纪念日"].waitForExistence(timeout: 30), home.debugDescription)
        let upcoming = icon.staticTexts.matching(NSPredicate(
            format: "label IN %@", ["天后", "今天", "d left", "Today"]
        )).firstMatch
        XCTAssertTrue(upcoming.waitForExistence(timeout: 30), home.debugDescription)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Widget on Home Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
        icon.tap()
        XCTAssertTrue(app.buttons["detail.moreActions"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(app.staticTexts["detail.title"].label, "结婚纪念日")
        XCUIDevice.shared.press(.home)
        selectDay("小年糕出生", in: home, widget: icon)
        XCTAssertTrue(icon.staticTexts["小年糕出生"].waitForExistence(timeout: 30), home.debugDescription)
        let past = icon.staticTexts.matching(NSPredicate(format: "label IN %@", ["天前", "d ago"])).firstMatch
        XCTAssertTrue(past.waitForExistence(timeout: 30), home.debugDescription)
        let configured = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        configured.name = "Configured past day on Home Screen"
        configured.lifetime = .keepAlways
        add(configured)
        icon.tap()
        XCTAssertTrue(app.buttons["detail.moreActions"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(app.staticTexts["detail.title"].label, "小年糕出生")
    }

    private func selectDay(_ title: String, in home: XCUIApplication, widget: XCUIElement) {
        widget.press(forDuration: 1.2)
        let edit = home.buttons["com.apple.springboardhome.application-shortcut-item.configure-widget"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), home.debugDescription)
        edit.tap()
        let configuration = XCUIApplication(bundleIdentifier: "com.apple.WorkflowUI.WidgetConfigurationExtension")
        let choose = configuration.tables.buttons.firstMatch
        XCTAssertTrue(choose.waitForExistence(timeout: 10), configuration.debugDescription)
        choose.tap()
        let day = configuration.buttons[title].firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 10), configuration.debugDescription)
        day.tap()
        XCUIDevice.shared.press(.home)
    }
}
