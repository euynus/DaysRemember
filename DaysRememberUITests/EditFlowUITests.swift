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

    func testRestoreSingleSyncVersionKeepsItsNoteAfterRelaunch() {
        let app = launchApp(arguments: ["--seed-sample-data", "--seed-sync-conflicts"])
        openSettingsRow("settings.data", in: app)
        let versions = app.buttons["同步保留版本（1）"]
        XCTAssertTrue(versions.waitForExistence(timeout: 5))
        versions.tap()
        let restore = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@",
                                                       "恢复", "的本机保留版本")).firstMatch
        for _ in 0..<3 where !restore.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Local note retained before sync"].exists)
        XCTAssertTrue(restore.isHittable)
        restore.tap()
        app.buttons["恢复并同步"].tap()
        XCTAssertTrue(app.staticTexts["没有本机保留版本"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["--tab", "home"]
        app.launch()
        let wedding = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "结婚纪念日")).firstMatch
        XCTAssertTrue(wedding.waitForExistence(timeout: 5))
        wedding.tap()
        for _ in 0..<3 where !app.staticTexts["Local note retained before sync"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Local note retained before sync"].exists)
        XCTAssertFalse(app.staticTexts["Remote note"].exists)
    }

    func testDayChangeUpdatesCountdownWithoutLeavingDetail() {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchEnvironment["DR_ADVANCE_DAY_AFTER_SECONDS"] = "6"
        app.launchArguments = ["--tab", "home", "--seed-sample-data"]
        app.launch()
        let wedding = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "结婚纪念日")).firstMatch
        XCTAssertTrue(wedding.waitForExistence(timeout: 5))
        wedding.tap()
        let tomorrowCount = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "171")).firstMatch
        XCTAssertTrue(tomorrowCount.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["更多操作"].exists)
        app.buttons["返回"].tap()
        let tomorrowHeader = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "4月24日")).firstMatch
        XCTAssertTrue(tomorrowHeader.waitForExistence(timeout: 5))
    }

    func testDayChangeDoesNotDiscardAnOpenEditorDraft() {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchEnvironment["DR_ADVANCE_DAY_AFTER_SECONDS"] = "6"
        app.launchArguments = ["--screen", "add"]
        app.launch()
        let title = app.textFields["日子名称"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Midnight draft")
        // A delayed predicate waits through the clock tick without changing system time.
        let deadline = Date().addingTimeInterval(7)
        let afterTick = NSPredicate { _, _ in Date() >= deadline }
        expectation(for: afterTick, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(title.value as? String, "Midnight draft")
        XCTAssertTrue(app.buttons["保存"].exists)
    }

    func testEditorConfirmsDiscardAndKeepsDraftWhenContinuing() {
        let app = launchApp()
        app.buttons["添加日子"].tap()
        let title = app.textFields["日子名称"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Unsaved draft")
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["放弃修改"].waitForExistence(timeout: 5))
        app.buttons["继续编辑"].tap()
        XCTAssertEqual(title.value as? String, "Unsaved draft")
        app.buttons["取消"].tap()
        app.buttons["放弃修改"].tap()
        expectation(for: NSPredicate { _, _ in !title.exists }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(title.exists)
        XCTAssertTrue(app.buttons["添加日子"].isHittable)
    }

    func testEditorSwipeDismissesOnlyWithoutChanges() {
        let app = launchApp()
        func dragSheetDown() {
            let header = app.staticTexts["新的日子"]
            let start = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        app.buttons["添加日子"].tap()
        XCTAssertTrue(app.textFields["日子名称"].waitForExistence(timeout: 5))
        dragSheetDown()
        XCTAssertFalse(app.textFields["日子名称"].exists)

        app.buttons["添加日子"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["一次"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["一次"].tap()
        dragSheetDown()
        XCTAssertTrue(app.textFields["日子名称"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["一次"].isSelected)
        app.buttons["取消"].tap()
        app.buttons["放弃修改"].tap()
        expectation(for: NSPredicate { _, _ in app.buttons["添加日子"].isHittable }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["添加日子"].isHittable)
    }

    func testLunarLeapDateCanBeSelectedAndPersistsAfterRelaunch() {
        let app = launchApp()
        app.buttons["添加日子"].tap()
        app.segmentedControls.buttons["农历"].tap()
        app.buttons["dayDatePickerButton"].tap()
        XCTAssertTrue(app.staticTexts["选择农历日期"].waitForExistence(timeout: 5))
        app.buttons["lunarYearPicker"].tap()
        app.buttons["2023年"].tap()
        app.buttons["lunarMonthPicker"].tap()
        app.buttons["闰二月"].tap()
        app.buttons["lunarDayPicker"].tap()
        app.buttons["初一"].tap()
        XCTAssertTrue(app.staticTexts["公历 2023年3月22日"].exists, app.debugDescription)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Direct lunar leap-month entry"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["完成"].tap()
        let title = "Lunar-" + UUID().uuidString.prefix(8)
        app.textFields["日子名称"].tap()
        app.textFields["日子名称"].typeText(title)
        app.buttons["保存"].tap()
        app.terminate()
        app.launchArguments.removeAll { $0 == "--seed-sample-data" }
        app.launch()
        app.buttons["搜索日子"].tap()
        app.textFields["搜索日子"].tap()
        app.textFields["搜索日子"].typeText(title)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch.tap()
        app.buttons["更多操作"].tap()
        app.buttons["pencil"].firstMatch.tap()
        app.buttons["dayDatePickerButton"].tap()
        XCTAssertTrue(app.buttons["lunarMonthPicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["公历 2023年3月22日"].exists)
    }

    func testCancellingLunarDateSelectionKeepsOriginalDate() {
        let app = launchApp()
        app.buttons["添加日子"].tap()
        app.segmentedControls.buttons["农历"].tap()
        app.buttons["dayDatePickerButton"].tap()
        let before = app.staticTexts["lunarSolarDate"].label
        app.buttons["lunarDayPicker"].tap()
        app.buttons["初一"].tap()
        app.buttons["取消"].firstMatch.tap()
        app.buttons["dayDatePickerButton"].tap()
        XCTAssertEqual(app.staticTexts["lunarSolarDate"].label, before)
    }

    func testMultipleRemindersAndCustomTimePersistAfterRelaunch() {
        let app = launchApp()
        app.buttons["添加日子"].tap()
        app.buttons["dayReminderSettingsButton"].tap()
        XCTAssertTrue(app.buttons["confirmDayReminders"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["自定义"].tap()
        for offset in [7, 3, 1, 0] {
            let toggle = app.switches["dayReminderOffset\(offset)"]
            let expected = offset == 3 ? "0" : "1"
            if toggle.value as? String != expected {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
            XCTAssertEqual(toggle.value as? String, expected)
        }
        let globalTime = app.switches["dayReminderUsesGlobalTime"]
        if globalTime.value as? String == "1" {
            globalTime.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        app.buttons["时间选择器"].tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "14")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "35")
        app.buttons["PopoverDismissRegion"].tap()
        XCTAssertEqual(app.buttons["时间选择器"].value as? String, "14:35")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Multiple day reminders and Beijing time"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["confirmDayReminders"].tap()
        XCTAssertTrue(app.buttons["dayReminderSettingsButton"].label.contains("自定义（3次）"))
        XCTAssertTrue(app.buttons["dayReminderSettingsButton"].label.contains("14:35"))
        let title = "Reminders-" + UUID().uuidString.prefix(8)
        app.textFields["日子名称"].tap()
        app.textFields["日子名称"].typeText(title)
        app.buttons["保存"].tap()

        app.terminate()
        app.launchArguments.removeAll { $0 == "--seed-sample-data" }
        app.launch()
        app.buttons["搜索日子"].tap()
        app.textFields["搜索日子"].tap()
        app.textFields["搜索日子"].typeText(title)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch.tap()
        app.buttons["更多操作"].tap()
        app.buttons["pencil"].firstMatch.tap()
        app.buttons["dayReminderSettingsButton"].tap()
        XCTAssertTrue(app.switches["dayReminderOffset7"].waitForExistence(timeout: 5))
        for offset in [7, 3, 1, 0] {
            XCTAssertEqual(app.switches["dayReminderOffset\(offset)"].value as? String,
                           offset == 3 ? "0" : "1")
        }
        XCTAssertEqual(app.switches["dayReminderUsesGlobalTime"].value as? String, "0")
        XCTAssertEqual(app.buttons["时间选择器"].value as? String, "14:35")
    }

    func testCancellingReminderChangesKeepsAnUnchangedEditorClean() {
        let app = launchApp()
        app.buttons["添加日子"].tap()
        app.buttons["dayReminderSettingsButton"].tap()
        app.segmentedControls.buttons["自定义"].tap()
        app.switches["dayReminderUsesGlobalTime"].tap()
        app.buttons["cancelDayReminders"].tap()
        XCTAssertTrue(app.buttons["dayReminderSettingsButton"].label.contains("跟随全局设置"))
        XCTAssertFalse(app.buttons["dayReminderSettingsButton"].label.contains("09:00"))
        app.buttons["dayReminderSettingsButton"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["跟随全局"].isSelected)
        app.buttons["confirmDayReminders"].tap()
        app.buttons["取消"].tap()
        XCTAssertTrue(app.textFields["日子名称"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["放弃修改"].exists)
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

    /// The detail screen hides the navigation bar, but the edge swipe must still go back.
    func testEdgeSwipeReturnsFromPushedDetail() {
        let app = launchApp()
        let wedding = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "结婚纪念日")).firstMatch
        XCTAssertTrue(wedding.waitForExistence(timeout: 10))
        wedding.tap()
        let title = app.staticTexts["detail.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "Edge swipe should pop the detail screen")
        XCTAssertTrue(wedding.waitForExistence(timeout: 5))
    }

    func testDeletingADayOffersUndo() {
        let app = launchApp()
        let wedding = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "结婚纪念日")).firstMatch
        XCTAssertTrue(wedding.waitForExistence(timeout: 10))
        wedding.tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 5))
        app.buttons["更多操作"].tap()
        app.buttons["trash"].firstMatch.tap()
        app.buttons["删除"].firstMatch.tap()

        let undo = app.buttons["undoDelete"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertTrue(wedding.waitForNonExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Undo banner after deletion"
        attachment.lifetime = .keepAlways
        add(attachment)
        undo.tap()
        XCTAssertTrue(wedding.waitForExistence(timeout: 5))
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5))
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

        let loveCategory = app.descendants(matching: .any).matching(identifier: "category-love").firstMatch
        XCTAssertTrue(loveCategory.waitForExistence(timeout: 5), app.debugDescription)
        loveCategory.tap()
        let loveDay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "结婚纪念日")).firstMatch
        XCTAssertTrue(loveDay.waitForExistence(timeout: 5))
        loveDay.tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 5))
        // The system back button is labelled with the previous screen's title (爱情).
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(loveDay.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

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

    func testCalendarTodayButtonAndEmptyDayStartsANewDay() {
        let app = launchApp()
        app.tabBars.buttons["日历"].tap()
        let today = app.buttons["calendar.today"]
        XCTAssertFalse(today.exists)
        app.buttons["下个月"].tap()
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        XCTAssertTrue(today.waitForNonExistence(timeout: 5))

        let emptyDay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "2026年4月9日")).firstMatch
        XCTAssertTrue(emptyDay.waitForExistence(timeout: 5), app.debugDescription)
        emptyDay.tap()
        let date = app.buttons["dayDatePickerButton"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2026年4月9日"].exists, app.debugDescription)
        app.buttons["cancelDayButton"].tap()
        XCTAssertTrue(date.waitForNonExistence(timeout: 5))
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
        let cell = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND label MATCHES %@", "2026年4月23日", ".*[^0-9]2 个日子"
        )).firstMatch
        for _ in 0..<3 where !cell.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(cell.waitForExistence(timeout: 5), app.debugDescription)
        cell.tap()
        XCTAssertTrue(app.staticTexts["2026年4月23日"].waitForExistence(timeout: 5))
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", titles[0])).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.isHittable)
        XCTAssertGreaterThan(first.frame.width, 250)
        app.buttons["取消"].tap()
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        XCTAssertTrue(app.staticTexts["2026年4月23日"].waitForExistence(timeout: 5))
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Accessible calendar event picker"
        attachment.lifetime = .keepAlways
        add(attachment)
        first.tap()
        XCTAssertTrue(app.buttons["更多操作"].waitForExistence(timeout: 5))
        app.buttons["更多操作"].tap()
        app.buttons["trash"].firstMatch.tap()
        app.buttons["删除"].firstMatch.tap()
        let remaining = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND label MATCHES %@", "2026年4月23日", ".*[^0-9]1 个日子"
        )).firstMatch
        XCTAssertTrue(remaining.waitForExistence(timeout: 5), app.debugDescription)
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
        openSettingsRow("settings.widgets", in: app)
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

        openSettingsRow("settings.data", in: app)
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
            openSettingsRow("settings.data", in: app)
            XCTAssertTrue(app.navigationBars["数据与同步"].waitForExistence(timeout: 5))
        }

        openDataManagement()
        app.buttons["导出备份"].tap()
        let save = app.buttons["DOCPicker.actionButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), app.debugDescription)
        // A unique directory keeps the default export name from overwriting an older backup.
        app.buttons["OverflowBarButtonItem"].tap()
        let newFolder = app.buttons["新建文件夹"]
        XCTAssertTrue(newFolder.waitForExistence(timeout: 5), app.debugDescription)
        newFolder.tap()
        let folderName = app.textViews["DOC.inlineRenameField"]
        XCTAssertTrue(folderName.waitForExistence(timeout: 5), app.debugDescription)
        let initialFolderName = folderName.value as? String ?? ""
        folderName.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: initialFolderName.count) + title + "\n")
        XCTAssertTrue(folderName.waitForNonExistence(timeout: 5), app.debugDescription)
        let folderTitle = app.navigationBars.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@", title, title + ", "
        )).firstMatch
        XCTAssertTrue(folderTitle.waitForExistence(timeout: 5), app.debugDescription)
        save.tap()
        XCTAssertTrue(app.staticTexts["备份已导出。"].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["好"].tap()
        app.buttons["关闭"].tap()
        app.buttons["settings.done"].tap()

        reveal(entry, in: app)
        entry.tap()
        app.buttons["更多操作"].tap()
        app.buttons["trash"].firstMatch.tap()
        app.buttons["删除"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["这里还没有日子"].waitForExistence(timeout: 5))

        openDataManagement()
        app.buttons["从文件恢复"].tap()
        if !folderTitle.waitForExistence(timeout: 2) {
            let folder = app.cells.matching(NSPredicate(format: "label == %@", title)).firstMatch
            XCTAssertTrue(folder.waitForExistence(timeout: 10), app.debugDescription)
            folder.images.firstMatch.tap()
        }
        XCTAssertTrue(folderTitle.waitForExistence(timeout: 5), app.debugDescription)
        let file = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "时光备份-")).firstMatch
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

    private func openSettingsRow(_ identifier: String, in app: XCUIApplication) {
        let settings = app.buttons["home.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let row = app.buttons[identifier]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
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
