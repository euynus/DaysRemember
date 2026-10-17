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

    func testOneTimeDaysAreNeverRecentAnniversaries() {
        XCTAssertNil(RecentOccurrence.of(sample("japan"), today: date(2026, 7, 22)))
    }
}
