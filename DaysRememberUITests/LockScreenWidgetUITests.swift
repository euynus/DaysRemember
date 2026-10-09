import XCTest

final class LockScreenWidgetUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLockScreenGalleryStylesAndPastSelection() {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--seed-sample-data", "--tab", "home"]
        app.launch()
        app.buttons["home.settings"].tap()
        let widgets = app.buttons["settings.widgets"]
        XCTAssertTrue(widgets.waitForExistence(timeout: 5))
        widgets.tap()
        app.segmentedControls.buttons["锁定屏幕"].tap()
        app.buttons["widgetPreviewDayPicker"].tap()
        app.buttons["小年糕出生"].tap()
        let preview = app.descendants(matching: .any)["accessoryWidgetPreview"].firstMatch
        for style in ["圆形", "矩形", "行内"] {
            let button = app.segmentedControls.buttons[style]
            button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertTrue(preview.waitForExistence(timeout: 5))
            XCTAssertTrue(preview.label.contains("小年糕出生"), preview.label)
            XCTAssertTrue(preview.label.contains("天前"), preview.label)
            XCTAssertGreaterThan(preview.frame.width, 0)
            XCTAssertLessThanOrEqual(preview.frame.maxX, app.frame.maxX)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Lock Screen gallery " + style
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.segmentedControls.buttons["主屏幕"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["中"].isSelected)
        XCTAssertFalse(preview.exists)
    }

    func testEmptyLockScreenGalleryAtLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["--empty-library", "--screen", "widgets",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let lockScreen = app.segmentedControls.buttons["锁定屏幕"]
        XCTAssertTrue(lockScreen.waitForExistence(timeout: 5))
        XCTAssertTrue(lockScreen.isHittable)
        lockScreen.tap()
        let preview = app.descendants(matching: .any)["accessoryWidgetPreview"].firstMatch
        for style in ["圆形", "矩形", "行内"] {
            let button = app.segmentedControls.buttons[style]
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertEqual(preview.label, "还没有日子")
            XCTAssertLessThanOrEqual(preview.frame.maxX, app.frame.maxX)
            XCTAssertLessThanOrEqual(preview.frame.maxY, app.frame.maxY)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Empty Lock Screen gallery at largest text size"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
