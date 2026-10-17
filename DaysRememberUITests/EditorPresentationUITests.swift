import XCTest

/// An editor for an existing day must keep editing that day, with its draft, while the view it
/// was opened from changes or goes away: the hero card moving to another day, a row becoming the
/// hero, or a link to another day replacing the open detail.
final class EditorPresentationUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// On 2026-07-20 the hero is 北海道旅行 (`japan`); a simulated midnight makes it 入职周年 (`work`).
    private func launchAcrossMidnight(after seconds: Int) -> (XCUIApplication, Date) {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "2026-07-20"
        app.launchEnvironment["DR_ADVANCE_DAY_AFTER_SECONDS"] = String(seconds)
        app.launchArguments = ["--tab", "home", "--seed-sample-data"]
        app.launch()
        return (app, Date())
    }

    private func day(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func edit(_ element: XCUIElement, in app: XCUIApplication, appending text: String) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        element.press(forDuration: 1.0)
        let edit = app.buttons["编辑"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let title = app.textFields["日子名称"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(text)
        return title
    }

    /// Opens the link as the widget does; `XCUIApplication.open` would relaunch the app.
    private func open(_ link: String) {
        XCUIDevice.shared.system.open(URL(string: link)!)
    }

    private func wait(until deadline: Date, in app: XCUIApplication) {
        expectation(for: NSPredicate { _, _ in Date() >= deadline }, evaluatedWith: app)
        waitForExpectations(timeout: deadline.timeIntervalSinceNow + 10)
    }

    private func save(_ title: XCUIElement, in app: XCUIApplication) {
        app.buttons["saveDayButton"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: title)
        waitForExpectations(timeout: 5)
    }

    func testHeroEditorSavesIntoItsOwnDayAfterTheHeroChanges() {
        let (app, launched) = launchAcrossMidnight(after: 15)
        let title = edit(day("upcomingDay.japan", in: app), in: app, appending: " edited")
        wait(until: launched.addingTimeInterval(18), in: app)
        XCTAssertTrue(day("upcomingDay.work", in: app).exists, "the hero moved on under the editor")

        save(title, in: app)
        XCTAssertTrue(day("upcomingDay.work", in: app).label.contains("入职周年"), day("upcomingDay.work", in: app).label)
        // Past midnight the trip has gone by, so it counts up on 已过.
        app.buttons["home.face.past"].tap()
        let japan = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier IN %@", ["dayRow.japan", "pastHero.japan"])).firstMatch
        XCTAssertTrue(japan.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0..<4 where !japan.isHittable { app.swipeUp() }
        XCTAssertTrue(japan.label.contains("北海道旅行 edited"), japan.label)
    }

    func testRowEditorKeepsItsDraftWhenTheRowBecomesTheHero() {
        let (app, launched) = launchAcrossMidnight(after: 20)
        let row = day("dayRow.work", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        for _ in 0..<4 where !row.isHittable { app.swipeUp() }
        let title = edit(row, in: app, appending: " draft")
        wait(until: launched.addingTimeInterval(23), in: app)
        XCTAssertTrue(title.exists, "the editor closed when its row left the feed")
        XCTAssertEqual(title.value as? String, "入职周年 draft")

        save(title, in: app)
        XCTAssertTrue(day("upcomingDay.work", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(day("upcomingDay.work", in: app).label.contains("入职周年 draft"), day("upcomingDay.work", in: app).label)
    }

    func testDetailEditorKeepsItsDraftWhenALinkOpensAnotherDay() {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--tab", "home", "--seed-sample-data"]
        app.launch()
        let wedding = day("dayRow.wedding", in: app)
        XCTAssertTrue(wedding.waitForExistence(timeout: 10))
        for _ in 0..<4 where !wedding.isHittable { app.swipeUp() }
        wedding.tap()
        let more = app.buttons["detail.moreActions"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        app.buttons["编辑"].firstMatch.tap()
        let title = app.textFields["日子名称"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(" draft")

        open("daysremember://day/baby")
        XCTAssertTrue(title.waitForExistence(timeout: 5), "the editor closed when its detail was replaced")
        XCTAssertEqual(title.value as? String, "结婚纪念日 draft")
        save(title, in: app)
        XCTAssertTrue(app.staticTexts["小年糕出生"].waitForExistence(timeout: 5), "the link's day is open")
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(day("dayRow.wedding", in: app).label.contains("结婚纪念日 draft") ||
                      day("upcomingDay.wedding", in: app).label.contains("结婚纪念日 draft"))
    }

    func testLinkClosesSettingsToShowItsDay() {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--tab", "me", "--seed-sample-data"]
        app.launch()
        let data = app.buttons["settings.data"]
        XCTAssertTrue(data.waitForExistence(timeout: 10))
        for _ in 0..<4 where !data.isHittable { app.swipeUp() }
        data.tap()
        let sheet = app.navigationBars["数据与同步"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        open("daysremember://day/baby")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheet)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["detail.moreActions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["小年糕出生"].exists)
    }

    /// The empty widget links to `daysremember://home`, which has no day to open but must
    /// still bring 日子 forward from another tab.
    func testHomeLinkReturnsToTheDaysTab() {
        let app = XCUIApplication()
        app.launchEnvironment["DR_PIN_TODAY"] = "1"
        app.launchArguments = ["--tab", "me", "--seed-sample-data"]
        app.launch()
        XCTAssertTrue(app.buttons["settings.data"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["home.addDay"].exists)

        open("daysremember://home")
        XCTAssertTrue(app.buttons["home.addDay"].waitForExistence(timeout: 5))
    }
}
