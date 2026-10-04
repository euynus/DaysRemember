import XCTest

final class LocalizationUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testEnglishOnboardingAndDayPersistAfterTraditionalChineseRelaunch() {
        let app = launch(language: "en", arguments: ["--empty-library", "--show-onboarding"])
        let start = app.buttons["Get started"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        capture("English onboarding", app: app)
        start.tap()
        let title = "L10n-100% My Day"
        let field = app.textFields["dayTitleField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["saveDayButton"].label, "Save")
        XCTAssertTrue(app.buttons["dayDatePickerButton"].label.contains("April 23, 2026"))
        field.tap()
        field.typeText(title)
        app.buttons["saveDayButton"].tap()
        XCTAssertTrue(app.buttons["home.addDay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
        capture("English home with user title", app: app)

        app.terminate()
        configure(app, language: "zh-Hant", arguments: ["--show-onboarding"])
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["日曆"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["開始記錄"].exists)
        let day = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        capture("Traditional Chinese detail preserves user title", app: app)
        app.buttons["detail.moreActions"].tap()
        app.buttons["pencil"].firstMatch.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, title)
        XCTAssertTrue(app.buttons["dayDatePickerButton"].label.contains("2026年4月23日"))
        XCTAssertEqual(app.buttons["saveDayButton"].label, "儲存")
    }

    func testEnglishCustomCategoryNameIsNotTranslatedOnRelaunch() {
        let app = launch(language: "en", arguments: ["--empty-library", "--tab", "categories"])
        let add = app.buttons["addCategoryButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let field = app.textFields["categoryNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Calendar 100%")
        XCTAssertEqual(app.buttons["category-icon-heart"].label, "Icon: Heart")
        app.buttons["saveCategoryButton"].tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        app.terminate()
        configure(app, language: "zh-Hant", arguments: ["--tab", "categories"])
        app.launch()
        let edit = app.buttons["編輯Calendar 100%"]
        reveal(edit, in: app)
        edit.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Calendar 100%")
        XCTAssertEqual(app.buttons["category-icon-heart"].label, "圖示 愛心")
        capture("Traditional Chinese custom category editor", app: app)
    }

    func testEnglishGregorianLunarAndReminderEditors() {
        let app = launch(language: "en", arguments: ["--empty-library", "--screen", "add"])
        let date = app.buttons["dayDatePickerButton"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        date.tap()
        XCTAssertTrue(app.buttons["confirmDayDatePicker"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["confirmDayDatePicker"].label, "Done")
        capture("English Gregorian picker", app: app)
        app.buttons["confirmDayDatePicker"].tap()
        let lunar = app.segmentedControls.buttons["Lunar"]
        reveal(lunar, in: app)
        lunar.tap()
        date.tap()
        let year = app.buttons["lunarYearPicker"]
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        XCTAssertTrue(year.label.contains("Lunar Year"))
        XCTAssertTrue(app.staticTexts["lunarSolarDate"].label.contains("April 23, 2026"))
        capture("English lunar picker", app: app)
        app.buttons["confirmDayDatePicker"].tap()
        let reminder = app.buttons["dayReminderSettingsButton"]
        reveal(reminder, in: app)
        reminder.tap()
        XCTAssertTrue(app.navigationBars["Day Reminders"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Custom"].tap()
        XCTAssertTrue(app.switches["dayReminderOffset1"].label.contains("1 day before"))
        XCTAssertTrue(app.switches["dayReminderOffset7"].label.contains("7 days before"))
        capture("English reminder editor", app: app)
    }

    func testEnglishCalendarShareAndWidgetGalleryAtLargestTextSize() {
        let app = launch(language: "en", arguments: ["--seed-sample-data", "--tab", "calendar"])
        XCTAssertTrue(app.staticTexts["April"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Thu"].exists)
        capture("English calendar", app: app)
        app.terminate()
        configure(app, language: "en", arguments: ["--screen", "share", "--day", "wedding"], largeText: true)
        app.launch()
        let share = app.buttons["Share Image"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertTrue(share.isHittable)
        XCTAssertLessThanOrEqual(share.frame.maxX, app.frame.maxX)
        XCTAssertEqual(app.switches["share.includeNote"].value as? String, "0")
        capture("English share at largest text size", app: app)
        app.terminate()
        configure(app, language: "en", arguments: ["--screen", "widgets"], largeText: true)
        app.launch()
        let lock = app.segmentedControls.buttons["Lock Screen"]
        XCTAssertTrue(lock.waitForExistence(timeout: 5))
        lock.tap()
        let preview = app.descendants(matching: .any)["accessoryWidgetPreview"].firstMatch
        for style in ["Circular", "Rectangular", "Inline"] {
            let button = app.segmentedControls.buttons[style]
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertTrue(preview.waitForExistence(timeout: 5))
            XCTAssertTrue(preview.label.contains("days"))
            XCTAssertLessThanOrEqual(preview.frame.maxX, app.frame.maxX)
            capture("English " + style + " widget at largest text size", app: app)
        }
    }

    func testEnglishEditorActionsFitAtLargestTextSize() {
        let app = XCUIApplication()
        configure(app, language: "en", arguments: ["--empty-library", "--screen", "add"], largeText: true)
        app.launch()
        let cancel = app.buttons["cancelDayButton"]
        let save = app.buttons["saveDayButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable)
        XCTAssertGreaterThanOrEqual(cancel.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(save.frame.maxX, app.frame.maxX)
        XCTAssertFalse(save.isEnabled)
        let date = app.buttons["dayDatePickerButton"]
        reveal(date, in: app)
        XCTAssertLessThanOrEqual(date.frame.maxX, app.frame.maxX)
        capture("English editor at largest text size", app: app)
        date.tap()
        let done = app.buttons["confirmDayDatePicker"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        XCTAssertLessThanOrEqual(done.frame.maxX, app.frame.maxX)
        let title = app.staticTexts["dayDatePickerTitle"]
        let sheetCancel = app.buttons["cancelDayDatePicker"]
        XCTAssertGreaterThanOrEqual(title.frame.minY, app.frame.minY)
        XCTAssertLessThan(done.frame.maxY, app.frame.height * 0.25)
        XCTAssertGreaterThan(title.frame.minX, sheetCancel.frame.maxX)
        XCTAssertLessThan(title.frame.maxX, done.frame.minX)
        capture("English date sheet at largest text size", app: app)
        done.tap()
        let lunar = app.segmentedControls.buttons["Lunar"]
        reveal(lunar, in: app)
        lunar.tap()
        date.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Choose Lunar Date")
        XCTAssertLessThan(done.frame.maxY, app.frame.height * 0.25)
        XCTAssertGreaterThan(title.frame.minX, sheetCancel.frame.maxX)
        XCTAssertLessThan(title.frame.maxX, done.frame.minX)
        capture("English lunar sheet at largest text size", app: app)
    }

    private func launch(language: String, arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        configure(app, language: language, arguments: arguments)
        app.launch()
        return app
    }

    private func configure(_ app: XCUIApplication, language: String, arguments: [String], largeText: Bool = false) {
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = arguments + ["-AppleLanguages", "(\(language))", "-AppleLocale",
            language == "en" ? "en_US" : "zh_TW", "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
