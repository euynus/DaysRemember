import XCTest

final class SwiftUIAccessibilityUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testHomeFiltersKeepMinimumTargetsAndResetScrolledResults() {
        let app = launchPolishFixture()
        let all = app.buttons["全部"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        attach(app, name: "Home filter touch targets")
        XCTAssertGreaterThanOrEqual(all.frame.width, 44)
        XCTAssertGreaterThanOrEqual(all.frame.height, 44)

        let feed = app.scrollViews["home.feed"]
        feed.swipeUp()
        feed.swipeUp()
        app.buttons["已置顶"].tap()
        let firstPinned = app.descendants(matching: .any).matching(identifier: "dayRow.wedding").firstMatch
        XCTAssertTrue(firstPinned.waitForExistence(timeout: 5))
        XCTAssertTrue(firstPinned.isHittable)
        XCTAssertGreaterThanOrEqual(firstPinned.frame.minY, all.frame.maxY - 1)

        all.tap()
        app.buttons["home.search"].tap()
        let search = app.textFields["home.searchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.typeText("Long-term")
        let result = app.descendants(matching: .any).matching(identifier: "dayRow.ui-polish-long").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.isHittable)
        app.buttons["home.clearSearch"].tap()
        XCTAssertEqual(search.value as? String, search.placeholderValue)
        app.buttons["home.search"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "upcomingDay.ui-polish-featured")
            .firstMatch.waitForExistence(timeout: 5))
        attach(app, name: "Home search and filter recovery")
    }

    func testDetailLongTitleRemainsExpandedAtAccessibilitySize() {
        let app = launchPolishFixture(extra: ["--screen", "detail", "--day", "ui-polish-long"], accessible: true)
        let title = app.staticTexts["Long-term memories from a summer journey together, with every little moment kept close to our hearts"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        attach(app, name: "Accessible detail long title")
        XCTAssertGreaterThan(title.frame.height, 200)
        XCTAssertGreaterThanOrEqual(title.frame.minX, 0)
        XCTAssertLessThanOrEqual(title.frame.maxX, app.frame.maxX)
    }

    func testCategoryLongNameAndEditButtonAtAccessibilitySize() {
        let app = launchPolishFixture(extra: ["--tab", "categories"], accessible: true)
        let category = app.descendants(matching: .any).matching(identifier: "category-ui-polish-custom").firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(category.frame.minX, 0)
        XCTAssertLessThanOrEqual(category.frame.maxX, app.frame.maxX)
        let edit = app.buttons["editCategory-ui-polish-custom"]
        for _ in 0..<4 where !edit.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(edit.isHittable)
        XCTAssertGreaterThanOrEqual(edit.frame.width, 44)
        XCTAssertGreaterThanOrEqual(edit.frame.height, 44)
        attach(app, name: "Accessible category cover and edit control")
        edit.tap()
        let name = app.textFields["例如：朋友"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Journeys and the people we meet along the way")
        app.buttons["返回"].tap()
        XCTAssertTrue(category.waitForExistence(timeout: 5))
    }

    private func launchPolishFixture(extra: [String] = [], accessible: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--ui-polish-fixture"] + extra
            + ["-UIPreferredContentSizeCategoryName", accessible ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launchCategoryEditor() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--seed-sample-data", "--tab", "categories",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let addCategory = app.buttons["新建分类"]
        XCTAssertTrue(addCategory.waitForExistence(timeout: 5))
        addCategory.tap()
        XCTAssertTrue(app.textFields["例如：朋友"].waitForExistence(timeout: 5))
        return app
    }

    func testCategoryIconsHaveChineseLabelsAndSelectedTraits() {
        let app = launchCategoryEditor()
        let choices = [
            ("heart", "爱心"), ("house", "房屋"), ("airplane", "飞机"),
            ("graduationcap", "毕业帽"), ("sparkles", "闪光"), ("star", "星星"),
            ("gift", "礼物"), ("birthday.cake", "生日蛋糕"), ("camera", "相机"),
            ("pawprint", "爪印"), ("sun.max", "太阳"), ("moon.stars", "月亮和星星"),
            ("leaf", "叶子"), ("cup.and.saucer", "茶杯"), ("music.note", "音符"),
            ("flag", "旗帜"), ("bell", "铃铛"), ("tag", "标签"),
        ]
        for (symbol, label) in choices {
            let button = app.buttons["category-icon-" + symbol]
            for _ in 0..<3 where !button.isHittable { app.scrollViews.firstMatch.swipeUp() }
            XCTAssertTrue(button.waitForExistence(timeout: 5), symbol)
            XCTAssertEqual(button.label, "图标 " + label, symbol)
            XCTAssertEqual(button.isSelected, symbol == "tag", symbol)
        }

        let tag = app.buttons["category-icon-tag"]
        let teacup = app.buttons["category-icon-cup.and.saucer"]
        XCTAssertTrue(teacup.isHittable)
        teacup.tap()
        XCTAssertTrue(teacup.isSelected)
        XCTAssertFalse(tag.isSelected)
        tag.tap()
        XCTAssertTrue(tag.isSelected)
        XCTAssertFalse(teacup.isSelected)
    }

    func testCategorySaveAcceptsAnEdgeTapInsideItsMinimumHitArea() {
        let app = launchCategoryEditor()
        let name = "QA-Accessibility-" + UUID().uuidString.prefix(6)
        let field = app.textFields["例如：朋友"]
        let save = app.buttons["保存"]
        XCTAssertFalse(save.isEnabled)
        field.tap()
        field.typeText(name)
        XCTAssertTrue(save.isEnabled)
        XCTAssertTrue(save.isHittable)
        XCTAssertGreaterThanOrEqual(save.frame.width, 44)
        XCTAssertGreaterThanOrEqual(save.frame.height, 44)

        // Exercise the label's empty corner, not the text's intrinsic hit area.
        save.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 2, dy: 2))
            .tap()
        expectation(for: NSPredicate { _, _ in !field.exists }, evaluatedWith: app)
        waitForExpectations(timeout: 5)

        let edit = app.buttons["编辑" + name]
        for _ in 0..<3 where !edit.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(edit.isHittable)
        edit.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, name)
    }
}
