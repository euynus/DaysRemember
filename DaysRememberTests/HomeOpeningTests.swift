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

final class AppEntryPointTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        CNDate.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testNewDayAndDayLinksRoute() {
        XCTAssertEqual(DeepLink(PendingLink.newDay), .newDay)
        XCTAssertEqual(DeepLink(DeepLink.url(forDayID: "wedding")), .day("wedding"))
    }

    func testAPendingLinkIsTakenOnce() throws {
        let suite = "AppEntryPointTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(PendingLink.take(defaults: defaults))
        PendingLink.request(PendingLink.newDay, defaults: defaults)
        XCTAssertEqual(PendingLink.take(defaults: defaults), PendingLink.newDay)
        XCTAssertNil(PendingLink.take(defaults: defaults))
    }

    func testListWidgetShowsPinnedThenNearestThenRecent() {
        let today = date(2026, 10, 2)
        let soon = Day(id: "soon", title: "soon", date: date(2026, 10, 5), category: .life, photo: .home)
        let later = Day(id: "later", title: "later", date: date(2026, 12, 1), category: .life, photo: .home)
        let past = Day(id: "past", title: "past", date: date(2026, 9, 1), category: .life, photo: .home)
        var pinned = Day(id: "pinned", title: "pinned", date: date(2027, 3, 1), category: .life, photo: .home)
        pinned.pinned = true
        XCTAssertEqual(WidgetDay.list(in: [past, later, soon, pinned], today: today, limit: 3).map(\.id),
                       ["pinned", "soon", "later"])
        XCTAssertEqual(WidgetDay.list(in: [past, soon], today: today, limit: 6).map(\.id), ["soon", "past"])
    }

    func testTheShortcutSaysHowManyDaysAreLeftOrHavePassed() {
        let day = Day(id: "trip", title: "北海道旅行", date: date(2026, 10, 5), category: .travel, photo: .japan)
        XCTAssertEqual(DaysUntilIntent.sentence(for: day, info: DayInfo.compute(day, today: date(2026, 10, 2))),
                       "「北海道旅行」还有 3 天")
        XCTAssertEqual(DaysUntilIntent.sentence(for: day, info: DayInfo.compute(day, today: date(2026, 10, 15))),
                       "「北海道旅行」已经过去 10 天")
        XCTAssertEqual(DaysUntilIntent.sentence(for: day, info: DayInfo.compute(day, today: date(2026, 10, 5))),
                       "今天是「北海道旅行」")
    }
}
