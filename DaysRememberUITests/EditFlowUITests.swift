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

    private func launchApp(arguments: [String] = ["--seed-sample-data"]) -> XCUIApplication {
        let app = XCUIApplication()
        // DR_PIN_TODAY both pins "today" to the prototype reference date and marks
        // the run as automated; --show-onboarding opts into the real first-run flow.
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--tab", "home"] + arguments
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
        // The fixture resets on every launch; persistence must use the saved library.
        app.launchArguments.removeAll { $0 == "--seed-sample-data" }
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
        app.launchArguments = ["--seed-sample-data", "--tab", "home", "-UIPreferredContentSizeCategoryName",
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
        app.launchArguments = ["--seed-sample-data", "--screen", "share", "--day", "wedding"]
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
        app.launchArguments = ["--seed-sample-data", "--tab", "home", "-UIPreferredContentSizeCategoryName",
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
        app.launchArguments = ["--seed-sample-data", "--screen", "detail", "--day", "wedding"]
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
        app.launchArguments = ["--seed-sample-data", "--screen", "share", "-UIPreferredContentSizeCategoryName",
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

    func testFreshOnboardingCreatesAndPersistsFirstDay() {
        let app = launchApp(arguments: ["--empty-library", "--show-onboarding"])
        let start = app.buttons["开始记录"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(start.isHittable)
        start.tap()

        let titleField = app.textFields["日子名称"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Real onboarding should open the first-day editor")
        XCTAssertFalse(app.buttons["保存"].isEnabled)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["这里还没有日子"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "即将到来")).firstMatch.exists)

        let title = "UITest-First-" + UUID().uuidString.prefix(8)
        let entry = createFirstDay(title, in: app)
        XCTAssertTrue(entry.isHittable)

        app.terminate()
        app.launchArguments.removeAll { $0 == "--empty-library" }
        // Keep --show-onboarding: persisted completion, not automation, should skip it.
        app.launch()
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertFalse(start.exists)
        XCTAssertFalse(app.buttons["记录第一个日子"].exists)
    }

    func testDeletedDayCanBeRestoredThroughHomeDataManagement() {
        let app = launchApp(arguments: ["--empty-library"])
        XCTAssertTrue(app.staticTexts["这里还没有日子"].waitForExistence(timeout: 10))
        let title = "UITest-Restore-" + UUID().uuidString.prefix(8)
        let entry = createFirstDay(title, in: app)
        reveal(entry, in: app)
        entry.tap()
        let more = app.buttons["更多操作"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let deleteItem = app.buttons["trash"].firstMatch
        XCTAssertTrue(deleteItem.waitForExistence(timeout: 5))
        deleteItem.tap()
        let confirm = app.buttons["删除"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["这里还没有日子"].waitForExistence(timeout: 5))

        app.buttons["日子选项"].tap()
        let dataManagement = app.buttons["externaldrive"].firstMatch
        XCTAssertTrue(dataManagement.waitForExistence(timeout: 5))
        dataManagement.tap()
        XCTAssertTrue(app.navigationBars["数据与同步"].waitForExistence(timeout: 5))
        let recentlyDeleted = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "最近删除（")).firstMatch
        reveal(recentlyDeleted, in: app)
        recentlyDeleted.tap()
        XCTAssertTrue(app.navigationBars["最近删除"].waitForExistence(timeout: 5))
        let restore = app.buttons["恢复" + title]
        reveal(restore, in: app)
        restore.tap()
        XCTAssertTrue(restore.waitForNonExistence(timeout: 5))

        app.terminate()
        app.launchArguments.removeAll { $0 == "--empty-library" }
        app.launch()
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "The restored day should persist on Home")
        reveal(entry, in: app)
        entry.tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].exists)
    }

    func testShareNotesDefaultOffAndDetailShowsElapsedDays() {
        let app = launchApp()
        let wedding = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "结婚纪念日")).firstMatch
        reveal(wedding, in: app)
        wedding.tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 5))
        // 2019-10-12 to pinned 2026-04-23 is 2385 elapsed calendar days, not the countdown.
        let elapsed = app.staticTexts["已过 2,385 天"]
        reveal(elapsed, in: app)
        let share = app.buttons["分享这一天"]
        reveal(share, in: app)
        share.tap()

        let includeNote = app.switches["share.includeNote"]
        XCTAssertTrue(includeNote.waitForExistence(timeout: 5))
        XCTAssertTrue(includeNote.isHittable)
        XCTAssertEqual(includeNote.value as? String, "0", "Notes must be opt-in for each share")
        includeNote.switches.firstMatch.tap()
        XCTAssertEqual(includeNote.value as? String, "1")
        includeNote.switches.firstMatch.tap()
        XCTAssertEqual(includeNote.value as? String, "0")
    }

    func testBackupFileCanRestoreDeletedDay() {
        let app = launchApp(arguments: ["--empty-library"])
        let title = "UITest-Backup-" + UUID().uuidString.prefix(8)
        let entry = createFirstDay(title, in: app)

        func openDataManagement() {
            app.buttons["日子选项"].tap()
            app.buttons["externaldrive"].firstMatch.tap()
            XCTAssertTrue(app.navigationBars["数据与同步"].waitForExistence(timeout: 5))
        }

        openDataManagement()
        app.buttons["导出备份"].tap()
        let save = app.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10), app.debugDescription)
        let filename = app.textFields["DOCPicker.filenameTextField"]
        filename.tap()
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 100) + title)
        XCTAssertEqual(filename.value as? String, title)
        save.tap()
        XCTAssertTrue(app.staticTexts["备份已导出。"].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["好"].tap()
        app.buttons["关闭"].tap()

        reveal(entry, in: app)
        entry.tap()
        app.buttons["更多操作"].tap()
        app.buttons["trash"].firstMatch.tap()
        app.buttons["删除"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["这里还没有日子"].waitForExistence(timeout: 5))

        openDataManagement()
        app.buttons["从文件恢复"].tap()
        let file = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 10), app.debugDescription)
        file.images.firstMatch.tap()
        let restore = app.buttons["恢复备份"].firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 10), app.debugDescription)
        restore.tap()
        XCTAssertTrue(app.staticTexts["数据已恢复。"].waitForExistence(timeout: 5))
        app.buttons["好"].tap()

        app.terminate()
        app.launchArguments.removeAll { $0 == "--empty-library" }
        app.launch()
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
    }

    private func createFirstDay(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let create = app.buttons["记录第一个日子"]
        reveal(create, in: app)
        create.tap()
        let field = app.textFields["日子名称"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(title)
        app.buttons["保存"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["这里还没有日子"].exists)
        return entry
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        // Short content-area drags avoid Home's separate horizontal category scroller.
        for _ in 0..<8 where !element.isHittable {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }
}
