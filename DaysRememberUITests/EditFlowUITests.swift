import XCTest

/// End-to-end coverage for the core "open a day, then edit it" flow.
///
/// This guards the regression fixed in the swipe-back removal: a pushed
/// `DetailView` whose navigation controller had become unresponsive, so the
/// "更多操作 → 编辑" menu never opened the editor. `--screen detail` probes
/// could not catch it because they render detail as the stack *root*, not pushed.
final class EditFlowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // DR_PIN_TODAY both pins "today" to the prototype reference date and marks
        // the run as automated, which skips onboarding + the notification prompt.
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments += ["--tab", "home"]
        app.launch()
        return app
    }

    /// Tap the "即将到来" spotlight to push a real Detail screen, open its menu,
    /// tap 编辑, and assert the editor sheet actually presents (its 保存 button).
    func testEditFromPushedDetailOpensEditor() {
        let app = launchApp()

        let spotlight = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "即将到来")
        ).firstMatch
        XCTAssertTrue(spotlight.waitForExistence(timeout: 10),
                      "Home spotlight card should be present")
        spotlight.tap()

        let moreButton = app.buttons["更多操作"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 5),
                      "Detail screen should show the 更多操作 menu — if this fails the "
                      + "pushed nav controller is unresponsive")
        moreButton.tap()

        // The menu's 编辑 item carries the SF Symbol name as its identifier; use it
        // to disambiguate from the legacy/modern duplicate accessibility node.
        let editItem = app.buttons["pencil"].firstMatch
        XCTAssertTrue(editItem.waitForExistence(timeout: 5),
                      "Menu should offer 编辑")
        editItem.tap()

        let saveButton = app.buttons["保存"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5),
                      "Editor sheet should present with a 保存 button")

        // Close the editor so the test leaves a clean state.
        let cancel = app.buttons["取消"]
        if cancel.exists { cancel.tap() }
    }

    func testTabsSearchAndCategoryEditor() {
        let app = launchApp()
        app.tabBars.buttons["分类"].tap()
        let addCategory = app.buttons["新建分类"]
        XCTAssertTrue(addCategory.waitForExistence(timeout: 5))
        addCategory.tap()
        XCTAssertTrue(app.textFields["例如：朋友"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["保存"].isEnabled)
        app.buttons["返回"].tap()

        app.buttons["category-love"].tap()
        let loveDay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "结婚纪念日")).firstMatch
        XCTAssertTrue(loveDay.waitForExistence(timeout: 5))
        loveDay.tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 5))
        app.buttons["返回"].tap()
        XCTAssertTrue(loveDay.waitForExistence(timeout: 5))
        app.buttons["返回"].tap()

        app.tabBars.buttons["提醒"].tap()
        XCTAssertTrue(app.switches.firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["日历"].tap()
        XCTAssertTrue(app.buttons["下个月"].waitForExistence(timeout: 5))
        app.buttons["下个月"].tap()
        app.buttons["上个月"].tap()

        app.tabBars.buttons["日子"].tap()
        app.buttons["搜索日子"].tap()
        let search = app.textFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("no-matching-day-384")
        XCTAssertTrue(app.staticTexts["没有找到日子"].waitForExistence(timeout: 5))
        app.buttons["清除"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "即将到来")).firstMatch.exists)
    }

    func testCreatePersistEditAndDeleteDay() {
        let app = launchApp()
        let title = "UITest-" + UUID().uuidString.prefix(8)
        app.buttons["添加日子"].tap()
        let titleField = app.textFields["日子名称"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["保存"].isEnabled)
        titleField.tap()
        titleField.typeText(title)
        app.buttons["保存"].tap()

        app.terminate()
        app.launch()
        app.buttons["搜索日子"].tap()
        let search = app.textFields["搜索日子"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(title)
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        app.buttons["更多操作"].tap()
        app.buttons["pencil"].firstMatch.tap()
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("-edited")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts[title + "-edited"].waitForExistence(timeout: 5))

        app.buttons["更多操作"].tap()
        app.buttons["trash"].firstMatch.tap()
        app.buttons["删除"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["没有找到日子"].waitForExistence(timeout: 5))
    }

    func testWhitespaceSearchKeepsSpotlightAndCanClose() {
        let app = launchApp()
        app.buttons["搜索日子"].tap()
        let search = app.textFields["搜索日子"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.typeText("   ")
        let spotlight = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "即将到来")).firstMatch
        XCTAssertTrue(spotlight.exists)
        app.buttons["关闭搜索"].tap()
        XCTAssertFalse(search.exists)
        XCTAssertTrue(app.buttons["搜索日子"].exists)
        XCTAssertTrue(spotlight.exists)
    }

    func testCalendarMultiEventPickerAtLargestTextSize() {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--tab", "home", "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let suffix = UUID().uuidString.prefix(6)
        let titles = ["UITest-A-\(suffix)", "UITest-B-\(suffix)"]
        for title in titles {
            app.buttons["添加日子"].tap()
            let field = app.textFields["日子名称"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(title)
            app.buttons["保存"].tap()
        }
        app.tabBars.buttons["日历"].tap()
        let cell = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "23日，2 个日子")).firstMatch
        for _ in 0..<3 where !cell.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", titles[0])).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.isHittable)
        XCTAssertGreaterThan(first.frame.width, 250)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Accessible calendar event picker"
        attachment.lifetime = .keepAlways
        add(attachment)
        first.tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 5))
        app.buttons["更多操作"].tap()
        app.buttons["trash"].firstMatch.tap()
        app.buttons["删除"].firstMatch.tap()
        let remaining = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "23日，1 个日子")).firstMatch
        XCTAssertTrue(remaining.waitForExistence(timeout: 5))
        remaining.tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 5))
        app.buttons["更多操作"].tap()
        app.buttons["trash"].firstMatch.tap()
        app.buttons["删除"].firstMatch.tap()
    }

    func testShareTemplatesOpenSystemShareSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "share", "--day", "wedding"]
        app.launch()
        for name in ["手记", "极简", "双栏", "照片"] {
            let template = app.segmentedControls.buttons[name]
            XCTAssertTrue(template.waitForExistence(timeout: 5))
            template.tap()
            XCTAssertTrue(template.isSelected)
        }
        app.buttons["分享图片"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
        let saveImage = app.cells.matching(NSPredicate(
            format: "label == %@ OR label == %@", "保存图像", "Save Image")).firstMatch
        XCTAssertTrue(saveImage.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["header.closeButton"].tap()
    }

    func testCustomCategoryEditAndDelete() {
        let app = launchApp()
        let name = "UITest-Category-" + UUID().uuidString.prefix(6)
        app.tabBars.buttons["分类"].tap()
        app.buttons["新建分类"].tap()
        let field = app.textFields["例如：朋友"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["保存"].tap()
        let edit = app.buttons["编辑" + name]
        for _ in 0..<3 where !edit.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, name)
        field.tap()
        field.typeText("-edited")
        app.buttons["保存"].tap()
        let edited = app.buttons["编辑" + name + "-edited"]
        XCTAssertTrue(edited.waitForExistence(timeout: 5))
        edited.tap()
        let delete = app.buttons["删除分类"]
        for _ in 0..<3 where !delete.isHittable { app.scrollViews.firstMatch.swipeUp() }
        delete.tap()
        app.buttons["迁移到 生活"].tap()
        XCTAssertFalse(edited.waitForExistence(timeout: 2))
    }

    func testWidgetGallerySizes() {
        let app = launchApp()
        app.buttons["日子选项"].tap()
        app.buttons["rectangle.3.group"].firstMatch.tap()
        for size in ["小", "中", "大"] {
            let button = app.segmentedControls.buttons[size]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            XCTAssertTrue(button.isSelected)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Widget gallery " + size
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testLargestAccessibilityTextKeepsNavigationUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["--tab", "home", "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        for tab in ["日子", "日历", "分类", "提醒"] {
            app.tabBars.buttons[tab].tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Accessibility XXXL " + tab
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.tabBars.buttons["日子"].tap()
        XCTAssertTrue(app.buttons["添加日子"].isHittable)
        app.buttons["添加日子"].tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["取消"].isHittable)
        XCTAssertTrue(app.textFields["日子名称"].isHittable)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["添加日子"].waitForExistence(timeout: 5))
    }

    func testLegacyCoverRemainsSelectedInEditor() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "detail", "--day", "wedding"]
        app.launch()
        app.buttons["更多操作"].tap()
        app.buttons["pencil"].firstMatch.tap()
        let cover = app.buttons["选择花与光封面"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5))
        XCTAssertTrue(cover.isSelected)
        app.buttons["取消"].tap()
    }

    func testLargestAccessibilityShareActionsFit() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "share", "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let share = app.buttons["分享图片"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        for button in [share, app.buttons["保存"]] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThan(button.frame.width, 250)
            XCTAssertLessThan(button.frame.height, 150)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Accessible share actions"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
