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
}
