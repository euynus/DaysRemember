import XCTest
@testable import DaysRemember

final class DayInfoTests: XCTestCase {
    private let cal = CNDate.calendar

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return cal.date(from: c)!
    }

    private func makeDay(date: Date, recurring: Bool = false, lunar: Bool = false) -> Day {
        Day(id: UUID().uuidString, title: "test", date: date,
            recurring: recurring, lunar: lunar,
            category: .life, photo: .home)
    }

    // MARK: - Non-recurring

    func testNonRecurringFutureCountsDownToOriginal() {
        let day = makeDay(date: date(2027, 1, 1))
        let info = DayInfo.compute(day, today: date(2026, 5, 9))

        XCTAssertEqual(info.days, 237)
        XCTAssertFalse(info.isPast)
        XCTAssertFalse(info.isToday)
        XCTAssertEqual(cal.startOfDay(for: info.displayDate),
                       cal.startOfDay(for: date(2027, 1, 1)))
        XCTAssertNil(info.yearsAgo)
    }

    func testNonRecurringPastIsMarkedPast() {
        let day = makeDay(date: date(2024, 1, 1))
        let info = DayInfo.compute(day, today: date(2026, 5, 9))

        XCTAssertTrue(info.isPast)
        XCTAssertFalse(info.isToday)
        XCTAssertGreaterThan(info.days, 0)
        XCTAssertEqual(cal.startOfDay(for: info.displayDate),
                       cal.startOfDay(for: date(2024, 1, 1)))
    }

    func testNonRecurringTodayHasZeroDiff() {
        let day = makeDay(date: date(2026, 5, 9))
        let info = DayInfo.compute(day, today: date(2026, 5, 9))

        XCTAssertEqual(info.days, 0)
        XCTAssertTrue(info.isToday)
        XCTAssertFalse(info.isPast)
    }

    // MARK: - Recurring Gregorian

    func testRecurringGregorianTargetsThisYearWhenStillUpcoming() {
        let day = makeDay(date: date(2020, 12, 25), recurring: true)
        let info = DayInfo.compute(day, today: date(2026, 5, 9))

        XCTAssertEqual(cal.component(.year, from: info.displayDate), 2026)
        XCTAssertEqual(cal.component(.month, from: info.displayDate), 12)
        XCTAssertEqual(cal.component(.day, from: info.displayDate), 25)
        XCTAssertFalse(info.isPast)
        XCTAssertEqual(info.yearsAgo, 6)
    }

    func testRecurringGregorianRollsToNextYearAfterAnniversary() {
        let day = makeDay(date: date(2020, 3, 8), recurring: true)
        let info = DayInfo.compute(day, today: date(2026, 5, 9))

        XCTAssertEqual(cal.component(.year, from: info.displayDate), 2027)
        XCTAssertEqual(cal.component(.month, from: info.displayDate), 3)
        XCTAssertEqual(cal.component(.day, from: info.displayDate), 8)
        XCTAssertFalse(info.isPast)
    }

    func testRecurringGregorianOnAnniversaryIsToday() {
        let day = makeDay(date: date(2020, 5, 9), recurring: true)
        let info = DayInfo.compute(day, today: date(2026, 5, 9))

        XCTAssertEqual(info.days, 0)
        XCTAssertTrue(info.isToday)
        XCTAssertFalse(info.isPast)
        XCTAssertEqual(info.yearsAgo, 6)
    }

    // MARK: - Recurring lunar

    func testRecurringLunarUsesNextOccurrenceInCurrentYear() {
        // 中秋: lunar 八月十五. Sample 2025-10-06 = lunar 2025-08-15.
        let day = makeDay(date: date(2025, 10, 6), recurring: true, lunar: true)
        let today = date(2026, 5, 9)
        let info = DayInfo.compute(day, today: today)

        let displayed = Lunar.solarToLunar(info.displayDate)
        XCTAssertEqual(displayed.month, 8)
        XCTAssertEqual(displayed.day, 15)
        XCTAssertEqual(displayed.year, 2026)
        XCTAssertGreaterThanOrEqual(info.displayDate, today)
        XCTAssertFalse(info.isPast)
    }

    func testRecurringLunarRollsForwardWhenAnniversaryHasPassed() {
        // Today after 2026's mid-autumn — must walk to 2027.
        let day = makeDay(date: date(2025, 10, 6), recurring: true, lunar: true)
        let today = date(2026, 11, 1)
        let info = DayInfo.compute(day, today: today)

        let displayed = Lunar.solarToLunar(info.displayDate)
        XCTAssertEqual(displayed.month, 8)
        XCTAssertEqual(displayed.day, 15)
        XCTAssertEqual(displayed.year, 2027)
        XCTAssertFalse(info.isPast)
    }
}
