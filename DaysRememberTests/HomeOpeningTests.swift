import XCTest
@testable import DaysRemember

final class HomeOpeningTests: XCTestCase {
    private func day(_ id: String, pinned: Bool = false) -> Day {
        Day(id: id, title: id, date: Date(timeIntervalSince1970: 1_700_000_000), category: .life, photo: .home,
            pinned: pinned)
    }

    func testTheFeedOpensOnThePinnedDaysFace() {
        XCTAssertEqual(HomeFace.opening(upcoming: [day("ahead")], past: [day("behind", pinned: true)]), .past)
        XCTAssertEqual(HomeFace.opening(upcoming: [day("ahead", pinned: true)], past: [day("behind", pinned: true)]), .upcoming)
        XCTAssertEqual(HomeFace.opening(upcoming: [day("ahead")], past: [day("behind")]), .upcoming)
        XCTAssertEqual(HomeFace.opening(upcoming: [], past: [day("behind")]), .past, "Only 已过 has days")
        XCTAssertEqual(HomeFace.opening(upcoming: [], past: []), .upcoming)
    }

    func testARatingIsAskedForOncePerVersionAfterAWeekWithAFewDays() throws {
        let suite = "HomeOpeningTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let weekLater = start.addingTimeInterval(ReviewPrompt.minimumUse)

        ReviewPrompt.noteUse(defaults: defaults, now: start)
        XCTAssertFalse(ReviewPrompt.takeTurn(dayCount: 9, defaults: defaults, now: start.addingTimeInterval(3600), version: "1.0"),
                       "Not in the first week")
        XCTAssertFalse(ReviewPrompt.takeTurn(dayCount: 4, defaults: defaults, now: weekLater, version: "1.0"),
                       "Not with only a few days")
        XCTAssertTrue(ReviewPrompt.takeTurn(dayCount: 5, defaults: defaults, now: weekLater, version: "1.0"))
        XCTAssertFalse(ReviewPrompt.takeTurn(dayCount: 6, defaults: defaults, now: weekLater, version: "1.0"),
                       "Once per version")
        XCTAssertTrue(ReviewPrompt.takeTurn(dayCount: 6, defaults: defaults, now: weekLater, version: "1.1"))
    }
}
