import XCTest
@testable import DaysRemember

final class MilestoneTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        CNDate.calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func sample(_ id: String) -> Day {
        SampleData.days.first { $0.id == id }!
    }

    func testRoundDaysComeEveryHundredBelowAThousand() throws {
        let milestone = try XCTUnwrap(Milestone.next(after: date(2026, 7, 20), today: date(2026, 10, 16)))
        XCTAssertEqual(milestone.kind, .days(100))
        XCTAssertEqual(milestone.date, date(2026, 10, 28))
        XCTAssertEqual(milestone.daysUntil, 12)
        XCTAssertEqual(milestone.progress, 0.88, accuracy: 0.001)
    }

    func testAWholeYearWinsWhenItComesFirst() throws {
        let moved = try XCTUnwrap(Milestone.next(after: date(2024, 11, 5), today: date(2026, 10, 16)))
        XCTAssertEqual(moved.kind, .years(2))
        XCTAssertEqual(moved.daysUntil, 20)

        let met = try XCTUnwrap(Milestone.next(after: date(2017, 3, 8), today: date(2026, 10, 16)))
        XCTAssertEqual(met.kind, .years(10))
        XCTAssertEqual(met.date, date(2027, 3, 8))
        XCTAssertEqual(met.daysUntil, 143)
    }

    func testRoundDaysStepByFiveHundredFromAThousand() throws {
        // 1,480 days in, just after the fourth anniversary: 1,500 days comes first.
        let milestone = try XCTUnwrap(Milestone.next(after: date(2022, 6, 1), today: date(2026, 6, 20)))
        XCTAssertEqual(milestone.kind, .days(1500))
        XCTAssertEqual(milestone.daysUntil, 20)

        let baby = try XCTUnwrap(Milestone.next(after: date(2023, 2, 14), today: date(2026, 10, 16)))
        XCTAssertEqual(baby.kind, .years(4))
        XCTAssertEqual(baby.daysUntil, 121)
    }

    func testAMilestoneLandingTodayIsKept() throws {
        let milestone = try XCTUnwrap(Milestone.next(after: date(2026, 7, 8), today: date(2026, 10, 16)))
        XCTAssertEqual(milestone.kind, .days(100))
        XCTAssertEqual(milestone.daysUntil, 0)
    }

    /// February 29 has its anniversary on March 1 in a common year, as the countdown, the calendar and
    /// the yearly memory reminder have it, and on February 29 again in a leap year.
    func testLeapDayAnniversaryFallsOnMarchFirstInACommonYear() throws {
        let leap = date(2024, 2, 29)
        let first = try XCTUnwrap(Milestone.next(after: leap, today: date(2025, 2, 28)))
        XCTAssertEqual(first.kind, .years(1))
        XCTAssertEqual(first.date, date(2025, 3, 1))
        XCTAssertEqual(first.daysUntil, 1)
        let yearly = Day(id: "leap", title: "闰日", date: leap, recurring: true, category: .life, photo: .home)
        XCTAssertEqual(DayInfo.occurrences(of: yearly, inGregorianYear: 2025), [first.date])

        let fourth = try XCTUnwrap(Milestone.next(after: leap, today: date(2028, 2, 1)))
        XCTAssertEqual(fourth.kind, .years(4))
        XCTAssertEqual(fourth.date, date(2028, 2, 29))
    }

    func testFutureDaysHaveNoMilestone() {
        XCTAssertNil(Milestone.next(after: date(2026, 12, 20), today: date(2026, 10, 16)))
    }

    func testRecentAnniversaryStaysForAWeek() throws {
        let wedding = sample("wedding")
        let recent = try XCTUnwrap(RecentOccurrence.of(wedding, today: date(2026, 10, 16)))
        XCTAssertEqual(recent.daysAgo, 4)
        XCTAssertEqual(recent.number, 7)
        XCTAssertEqual(recent.date, date(2026, 10, 12))
        XCTAssertNil(RecentOccurrence.of(wedding, today: date(2026, 10, 20)))
        XCTAssertNil(RecentOccurrence.of(wedding, today: date(2026, 10, 12)), "the day itself shows as today")
    }

    func testRecentLunarAnniversaryCountsLunarYears() throws {
        let midAutumn = sample("midautumn")
        let recent = try XCTUnwrap(RecentOccurrence.of(midAutumn, today: date(2026, 9, 28)))
        XCTAssertEqual(recent.date, date(2026, 9, 25))
        XCTAssertEqual(recent.daysAgo, 3)
        XCTAssertEqual(recent.number, 1)
    }

    func testCountdownRestatesDaysInEachUnit() {
        let today = date(2026, 10, 16)
        let exam = date(2026, 12, 20)
        XCTAssertEqual(CountdownBreakdown.make(.days, between: today, and: exam), .init(value: 65, remainderDays: nil))
        XCTAssertEqual(CountdownBreakdown.make(.weeks, between: today, and: exam), .init(value: 9, remainderDays: 2))
        XCTAssertEqual(CountdownBreakdown.make(.months, between: today, and: exam), .init(value: 2, remainderDays: 4))
        XCTAssertEqual(CountdownBreakdown.make(.hours, between: today, and: exam), .init(value: 1_560, remainderDays: nil))
        // Order doesn't matter: count-up days pass the start first.
        XCTAssertEqual(CountdownBreakdown.make(.months, between: date(2026, 7, 20), and: today),
                       .init(value: 2, remainderDays: 26))
    }

    /// The hero's label stands in for everything on the card, so VoiceOver hears the milestone too.
    func testPastHeroLabelReadsItsMilestone() throws {
        let today = date(2026, 10, 16)
        let moved = Day(id: "moved", title: "搬进新家", date: date(2024, 11, 5), category: .family, photo: .home)
        let info = DayInfo.compute(moved, today: today)
        let milestone = try XCTUnwrap(Milestone.next(after: moved.date, today: today))
        let label = DayCardText.heroAccessibilityLabel(moved, info: info, milestone: milestone)
        XCTAssertTrue(label.hasPrefix(DayCardText.accessibilityLabel(moved, info: info)))
        XCTAssertTrue(label.contains(DayCardText.milestone(milestone)), label)
        XCTAssertEqual(DayCardText.heroAccessibilityLabel(moved, info: info, milestone: nil),
                       DayCardText.accessibilityLabel(moved, info: info))

        let exam = Day(id: "exam", title: "考研", date: date(2026, 12, 20), category: .work, photo: .study)
        let ahead = DayCardText.heroAccessibilityLabel(exam, info: DayInfo.compute(exam, today: today), milestone: nil)
        XCTAssertTrue(ahead.contains("考研"))
        XCTAssertFalse(ahead.contains(DayCardText.milestone(milestone)))
    }

    /// A one-time day's detail shows its round numbers from the day itself; that day reads 今天,
    /// matching the count above it, rather than 已过 0 天.
    func testOneTimeDayReadsTodayOnTheDay() {
        let trip = Day(id: "trip", title: "北海道旅行", date: date(2026, 7, 20), category: .travel, photo: .voyage)
        let onTheDay = DayInfo.compute(trip, today: date(2026, 7, 20))
        XCTAssertTrue(onTheDay.isToday)
        XCTAssertEqual(DetailView.sinceTheDay(onTheDay),
                       String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        let after = DayInfo.compute(trip, today: date(2026, 7, 23))
        XCTAssertTrue(DetailView.sinceTheDay(after).contains("3"))
    }

    func testOneTimeDaysAreNeverRecentAnniversaries() {
        XCTAssertNil(RecentOccurrence.of(sample("japan"), today: date(2026, 7, 22)))
    }
}
