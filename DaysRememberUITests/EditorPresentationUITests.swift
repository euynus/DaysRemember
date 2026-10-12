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
        let japan = day("dayRow.japan", in: app)
        for _ in 0..<4 where !japan.isHittable { app.swipeUp() }
        XCTAssertTrue(japan.label.contains("北海道旅行 edited"), japan.label)
    }
}
