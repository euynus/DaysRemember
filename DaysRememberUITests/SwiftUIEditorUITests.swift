import XCTest

final class SwiftUIEditorUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTemplateGallerySelectsLateOptionAndKeepsSelectionAfterSave() {
        let app = launchTemplateEditor()
        let title = app.textFields["dayTitleField"]
        let initialTitle = title.value as? String ?? ""
        let draftTitle = "Template gallery draft"
        title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: initialTitle.count))
        title.typeText(draftTitle)
        openTemplateGallery(in: app)

        let original = revealTemplate("systemDefault", in: app, scrollingDown: true)
        // The wedding fixture uses a legacy raw value for the same bundled artwork.
        XCTAssertTrue(original.isSelected)
        let gallery = app.scrollViews["dayCoverTemplateGallery"]
        XCTAssertLessThan(original.frame.width, gallery.frame.width * 0.6)

        let voyage = revealTemplate("voyage", in: app)
        XCTAssertFalse(voyage.isSelected)
        voyage.tap()
        waitUntilGone(app.buttons["closeDayCoverTemplateGallery"])
        XCTAssertEqual(title.value as? String, draftTitle)
        let quickSelection = app.buttons["cover-quick-template.voyage"]
        let editor = app.scrollViews["dayEditorScroll"]
        for _ in 0..<4 {
            if quickSelection.isHittable { break }
            editor.swipeUp()
        }
        attach(app, name: "Quick selection after choosing the final template")
        XCTAssertTrue(quickSelection.isHittable)
        XCTAssertTrue(quickSelection.isSelected)

        openTemplateGallery(in: app)
        XCTAssertTrue(voyage.isHittable)
        XCTAssertFalse(revealTemplate("systemDefault", in: app, scrollingDown: true).isSelected)
        XCTAssertTrue(revealTemplate("voyage", in: app).isSelected)
        app.buttons["closeDayCoverTemplateGallery"].tap()
        waitUntilGone(app.buttons["closeDayCoverTemplateGallery"])
        app.buttons["saveDayButton"].tap()
        waitUntilGone(app.buttons["saveDayButton"])

        // Reopen within this launch because each isolated fixture launch gets a new store.
        openEditor(in: app)
        XCTAssertEqual(title.value as? String, draftTitle)
        openTemplateGallery(in: app)
        XCTAssertFalse(revealTemplate("systemDefault", in: app, scrollingDown: true).isSelected)
        XCTAssertTrue(revealTemplate("voyage", in: app).isSelected)
        attach(app, name: "Saved template selection in gallery")
        app.buttons["closeDayCoverTemplateGallery"].tap()
        waitUntilGone(app.buttons["closeDayCoverTemplateGallery"])
        app.buttons["cancelDayButton"].tap()
        waitUntilGone(app.buttons["saveDayButton"])
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    func testAccessibleTemplateGalleryCloseAndDiscardPreserveOriginalCover() {
        let app = launchTemplateEditor(accessible: true)
        openTemplateGallery(in: app)

        let original = revealTemplate("systemDefault", in: app, scrollingDown: true)
        XCTAssertTrue(original.isSelected)
        let gallery = app.scrollViews["dayCoverTemplateGallery"]
        XCTAssertGreaterThan(original.frame.width, gallery.frame.width * 0.8)
        let close = app.buttons["closeDayCoverTemplateGallery"]
        XCTAssertTrue(close.isHittable)
        XCTAssertGreaterThanOrEqual(close.frame.width, 44)
        XCTAssertGreaterThanOrEqual(close.frame.height, 44)
        attach(app, name: "Single-column accessible template gallery")

        original.tap()
        waitUntilGone(close)
        app.buttons["cancelDayButton"].tap()
        waitUntilGone(app.buttons["saveDayButton"])
        XCTAssertFalse(app.alerts.firstMatch.exists)

        openEditor(in: app)
        openTemplateGallery(in: app)
        revealTemplate("companionship", in: app).tap()
        waitUntilGone(close)
        app.buttons["cancelDayButton"].tap()
        let discard = app.alerts["放弃未保存的修改？"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.buttons["放弃修改"].tap()
        waitUntilGone(app.buttons["saveDayButton"])

        openEditor(in: app)
        openTemplateGallery(in: app)
        XCTAssertTrue(revealTemplate("systemDefault", in: app, scrollingDown: true).isSelected)
        close.tap()
        waitUntilGone(close)
        app.buttons["cancelDayButton"].tap()
        waitUntilGone(app.buttons["saveDayButton"])
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    func testEnglishTemplateGalleryTitleFitsAtAccessibilitySize() {
        let app = launchTemplateEditor(accessible: true, language: "en")
        openTemplateGallery(in: app)
        let heading = app.staticTexts["dayCoverTemplateGalleryTitle"]
        let close = app.buttons["closeDayCoverTemplateGallery"]
        XCTAssertEqual(heading.label, "Illustrations")
        XCTAssertTrue(heading.isHittable)
        XCTAssertLessThanOrEqual(heading.frame.maxX, close.frame.minX)
        XCTAssertLessThan(heading.frame.height, close.frame.height * 1.5)
        attach(app, name: "English template gallery at maximum text size")
        close.tap()
        waitUntilGone(close)
        app.buttons["cancelDayButton"].tap()
        waitUntilGone(app.buttons["saveDayButton"])
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    private func launchTemplateEditor(accessible: Bool = false, language: String = "zh-Hans") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--ui-polish-fixture", "--screen", "detail", "--day", "wedding",
                               "-app.language.v1", language, "-AppleLanguages", "(\(language))",
                               "-UIPreferredContentSizeCategoryName",
                               accessible ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        openEditor(in: app)
        return app
    }

    private func openEditor(in app: XCUIApplication) {
        let more = app.buttons["detail.moreActions"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        app.buttons["pencil"].firstMatch.tap()
        XCTAssertTrue(app.textFields["dayTitleField"].waitForExistence(timeout: 5))
    }

    private func openTemplateGallery(in app: XCUIApplication) {
        let open = app.buttons["openDayCoverTemplateGallery"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        let editor = app.scrollViews["dayEditorScroll"]
        let photos = app.buttons["dayCoverPhotoPicker"]
        for _ in 0..<8 {
            if open.isHittable && photos.isHittable { break }
            editor.swipeUp()
        }
        XCTAssertTrue(open.isHittable)
        XCTAssertTrue(photos.isHittable)
        open.tap()
        XCTAssertTrue(app.buttons["closeDayCoverTemplateGallery"].waitForExistence(timeout: 5))
    }

    private func revealTemplate(_ rawValue: String, in app: XCUIApplication,
                                scrollingDown: Bool = false) -> XCUIElement {
        let template = app.buttons["cover-template." + rawValue]
        let gallery = app.scrollViews["dayCoverTemplateGallery"]
        for _ in 0..<12 {
            if template.exists && template.isHittable { break }
            if scrollingDown { gallery.swipeDown() }
            else { gallery.swipeUp() }
        }
        XCTAssertTrue(template.waitForExistence(timeout: 5), rawValue)
        XCTAssertTrue(template.isHittable, rawValue)
        return template
    }

    private func waitUntilGone(_ element: XCUIElement) {
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFailedPhotoSaveKeepsEditorDraft() {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--simulate-photo-save-failure", "--tab", "home"]
        app.launch()
        let day = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Save failure fixture")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), app.debugDescription)
        day.tap()
        app.buttons["detail.moreActions"].tap()
        app.buttons["pencil"].firstMatch.tap()

        let title = app.textFields["dayTitleField"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Save failure fixture".count))
        let draft = "Draft survives failed save"
        title.typeText(draft)
        app.buttons["saveDayButton"].tap()

        let alert = app.alerts["未能保存"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["好"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, draft)
        XCTAssertTrue(app.buttons["saveDayButton"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Editor draft retained after photo write failure"
        attachment.lifetime = .keepAlways
        add(attachment)
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
