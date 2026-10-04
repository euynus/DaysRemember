import XCTest

final class LanguagePreferencesUITests: XCTestCase {
    private var application: XCUIApplication?
    private let languages = ["system", "zh-Hans", "zh-Hant", "en"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        defer { super.tearDown() }
        guard let app = application else { return }
        app.terminate()
        // Recover from any open editor/sheet without reseeding or retaining large text.
        configure(app)
        app.launch()
        restoreSystemLanguage(in: app)
        app.terminate()
        application = nil
    }

    func testLiveSwitchingRequiresConfirmationAndCancelDiscardsTheDraft() {
        let app = launchFixture()
        applyLanguage("en", in: app)
        openLanguageSettings(in: app, title: "Language")
        assertSelection("en", in: app)
        XCTAssertEqual(app.buttons["language.option.system"].label, "System Default")
        XCTAssertEqual(app.buttons["language.option.zh-Hans"].label, "简体中文")
        XCTAssertEqual(app.buttons["language.option.zh-Hant"].label, "繁體中文")
        XCTAssertEqual(app.buttons["language.option.en"].label, "English")

        selectLanguage("zh-Hans", in: app)
        XCTAssertTrue(app.navigationBars["Language"].exists)
        XCTAssertEqual(app.buttons["language.cancel"].label, "Cancel")
        XCTAssertEqual(app.buttons["language.done"].label, "Done")
        closeLanguageSettings(using: "language.cancel", in: app)
        assertHomeLanguage("en", in: app)

        var selected = "en"
        var title = "Language"
        for (language, nextTitle) in [("zh-Hans", "语言"), ("zh-Hant", "語言"),
                                      ("en", "Language"), ("system", "Language")] {
            openLanguageSettings(in: app, title: title)
            assertSelection(selected, in: app)
            selectLanguage(language, in: app)
            closeLanguageSettings(using: "language.done", in: app)
            assertHomeLanguage(language, in: app)
            selected = language
            title = nextTitle
        }
        openLanguageSettings(in: app, title: "Language")
        assertSelection("system", in: app)
        closeLanguageSettings(using: "language.cancel", in: app)
    }

    func testAppliedLanguageAndUserContentSurviveSwitchingAndRelaunchWithoutReseeding() {
        let app = launchFixture()
        let title = "L10n-100% My Day"
        let categoryName = "Calendar 100%"
        app.tabBars.buttons["Categories"].tap()
        let addCategory = app.buttons["addCategoryButton"]
        XCTAssertTrue(addCategory.waitForExistence(timeout: 5))
        addCategory.tap()
        let categoryField = app.textFields["categoryNameField"]
        XCTAssertTrue(categoryField.waitForExistence(timeout: 5))
        categoryField.tap()
        categoryField.typeText(categoryName)
        app.buttons["saveCategoryButton"].tap()
        XCTAssertTrue(addCategory.waitForExistence(timeout: 5))
        let editCategory = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@", "editCategory-", "Edit " + categoryName
        )).firstMatch
        reveal(editCategory, in: app)
        let categoryIdentifier = editCategory.identifier
        XCTAssertTrue(categoryIdentifier.hasPrefix("editCategory-"))

        app.tabBars.buttons["Days"].tap()
        app.buttons["home.addDay"].tap()
        let titleField = app.textFields["dayTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        app.buttons["saveDayButton"].tap()
        XCTAssertTrue(app.buttons["home.options"].waitForExistence(timeout: 5))

        // Keep the seed argument during the live switch: rerunning bootstrap would erase both edits.
        XCTAssertTrue(app.launchArguments.contains("--seed-sample-data"))
        applyLanguage("zh-Hant", in: app)
        assertCreatedContent(title: title, categoryName: categoryName,
                             categoryIdentifier: categoryIdentifier, in: app)

        app.terminate()
        configure(app)
        XCTAssertFalse(app.launchArguments.contains("--seed-sample-data"))
        XCTAssertFalse(app.launchArguments.contains("--empty-library"))
        app.launch()
        assertHomeLanguage("zh-Hant", in: app)
        openLanguageSettings(in: app, title: "語言")
        assertSelection("zh-Hant", in: app)
        closeLanguageSettings(using: "language.cancel", in: app)
        assertCreatedContent(title: title, categoryName: categoryName,
                             categoryIdentifier: categoryIdentifier, in: app)
        dayButton(title, in: app).tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    func testLanguageEntryAndAllSheetControlsAreHittableAtLargestTextSize() {
        let app = launchFixture(largeText: true)
        openLanguageSettings(in: app, title: "Language")
        assertSelection("system", in: app)
        for language in languages {
            let row = app.buttons["language.option." + language]
            assertHittableInsideApp(row, in: app)
            row.tap()
            XCTAssertTrue(row.isSelected, language)
        }
        assertSelection("en", in: app)
        assertHittableInsideApp(app.buttons["language.cancel"], in: app)
        assertHittableInsideApp(app.buttons["language.done"], in: app)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Language settings at largest Dynamic Type size"
        attachment.lifetime = .keepAlways
        add(attachment)
        closeLanguageSettings(using: "language.done", in: app)
        assertHomeLanguage("en", in: app)
    }

    private func launchFixture(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        application = app
        configure(app, arguments: ["--seed-sample-data"], largeText: largeText)
        app.launch()
        restoreSystemLanguage(in: app)
        assertHomeLanguage("system", in: app)
        return app
    }

    private func configure(_ app: XCUIApplication, arguments: [String] = [], largeText: Bool = false) {
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--tab", "home"] + arguments + [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"
        ]
    }

    private func restoreSystemLanguage(in app: XCUIApplication) {
        openLanguageSettings(in: app)
        if app.buttons["language.option.system"].isSelected {
            closeLanguageSettings(using: "language.cancel", in: app)
        } else {
            selectLanguage("system", in: app)
            closeLanguageSettings(using: "language.done", in: app)
        }
        assertHomeLanguage("system", in: app)
    }

    private func openLanguageSettings(in app: XCUIApplication, title: String? = nil) {
        let options = app.buttons["home.options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        assertHittableInsideApp(options, in: app)
        options.tap()
        let entry = app.buttons["home.language"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        assertHittableInsideApp(entry, in: app)
        entry.tap()
        XCTAssertTrue(app.buttons["language.done"].waitForExistence(timeout: 5))
        if let title { XCTAssertTrue(app.navigationBars[title].exists) }
    }

    private func selectLanguage(_ language: String, in app: XCUIApplication) {
        app.buttons["language.option." + language].tap()
        assertSelection(language, in: app)
    }

    private func assertSelection(_ selected: String, in app: XCUIApplication) {
        for language in languages {
            XCTAssertEqual(app.buttons["language.option." + language].isSelected,
                           language == selected, language)
        }
    }

    private func closeLanguageSettings(using identifier: String, in app: XCUIApplication) {
        app.buttons[identifier].tap()
        let done = app.buttons["language.done"]
        expectation(for: NSPredicate { _, _ in !done.exists }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["home.options"].isHittable)
    }

    private func applyLanguage(_ language: String, in app: XCUIApplication) {
        openLanguageSettings(in: app)
        selectLanguage(language, in: app)
        closeLanguageSettings(using: "language.done", in: app)
        assertHomeLanguage(language, in: app)
    }

    private func assertHomeLanguage(_ language: String, in app: XCUIApplication) {
        let calendar: String
        let search: String
        switch language {
        case "zh-Hans": (calendar, search) = ("日历", "搜索日子")
        case "zh-Hant": (calendar, search) = ("日曆", "搜尋日子")
        default: (calendar, search) = ("Calendar", "Search Days")
        }
        XCTAssertTrue(app.tabBars.buttons[calendar].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.search"].label, search)
    }

    private func assertCreatedContent(title: String, categoryName: String,
                                      categoryIdentifier: String, in app: XCUIApplication) {
        XCTAssertTrue(dayButton(title, in: app).waitForExistence(timeout: 5))
        app.tabBars.buttons["分類"].tap()
        let edit = app.buttons[categoryIdentifier]
        reveal(edit, in: app)
        XCTAssertEqual(edit.label, "編輯" + categoryName)
        app.tabBars.buttons["日子"].tap()
    }

    private func dayButton(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
    }

    private func assertHittableInsideApp(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.isHittable, element.identifier)
        XCTAssertGreaterThanOrEqual(element.frame.minX, app.frame.minX)
        XCTAssertGreaterThanOrEqual(element.frame.minY, app.frame.minY)
        XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX)
        XCTAssertLessThanOrEqual(element.frame.maxY, app.frame.maxY)
    }
}
