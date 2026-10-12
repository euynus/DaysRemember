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
        XCTAssertNil(info.anniversaryNumber)
        XCTAssertNil(info.elapsedDays)
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
        XCTAssertEqual(info.elapsedDays, 0)
    }

    // MARK: - Recurring Gregorian

    func testRecurringOriginalDayStartsAtZeroInBothCalendars() {
        let today = date(2026, 5, 9)
        for lunar in [false, true] {
            let day = makeDay(date: today.addingTimeInterval(18 * 3600), recurring: true, lunar: lunar)
            let info = DayInfo.compute(day, today: today)

            XCTAssertEqual(info.displayDate, today)
            XCTAssertEqual(info.days, 0)
            XCTAssertTrue(info.isToday)
            XCTAssertEqual(info.elapsedDays, 0)
            XCTAssertEqual(info.anniversaryNumber, 0)

            let tomorrow = DayInfo.compute(day, today: date(2026, 5, 10))
            XCTAssertEqual(tomorrow.elapsedDays, 1)
            XCTAssertEqual(tomorrow.anniversaryNumber, 1)
            XCTAssertFalse(tomorrow.isToday)
        }
    }

    func testFutureRecurringStartDoesNotCreateAnEarlierAnniversary() {
        for lunar in [false, true] {
            let day = makeDay(date: date(2028, 5, 9), recurring: true, lunar: lunar)
            let info = DayInfo.compute(day, today: date(2026, 5, 9))

            XCTAssertEqual(info.displayDate, day.date)
            XCTAssertEqual(info.days, 731)
            XCTAssertFalse(info.isPast)
            XCTAssertFalse(info.isToday)
            XCTAssertNil(info.elapsedDays)
            XCTAssertEqual(info.anniversaryNumber, 0)
            XCTAssertTrue(DayInfo.occurrences(of: day, inGregorianYear: 2026).isEmpty)
        }
    }

    func testRecurringGregorianTargetsThisYearWhenStillUpcoming() {
        let day = makeDay(date: date(2020, 12, 25), recurring: true)
        let info = DayInfo.compute(day, today: date(2026, 5, 9))

        XCTAssertEqual(cal.component(.year, from: info.displayDate), 2026)
        XCTAssertEqual(cal.component(.month, from: info.displayDate), 12)
        XCTAssertEqual(cal.component(.day, from: info.displayDate), 25)
        XCTAssertFalse(info.isPast)
        XCTAssertEqual(info.yearsAgo, 6)
        // Upcoming this year → 6th anniversary (not 7).
        XCTAssertEqual(info.anniversaryNumber, 6)
        XCTAssertEqual(info.elapsedDays, 1961)
    }

    func testRecurringGregorianRollsToNextYearAfterAnniversary() {
        let day = makeDay(date: date(2020, 3, 8), recurring: true)
        let info = DayInfo.compute(day, today: date(2026, 5, 9))

        XCTAssertEqual(cal.component(.year, from: info.displayDate), 2027)
        XCTAssertEqual(cal.component(.month, from: info.displayDate), 3)
        XCTAssertEqual(cal.component(.day, from: info.displayDate), 8)
        XCTAssertFalse(info.isPast)
        // Already passed this year → rolled to 2027 → 7th anniversary.
        XCTAssertEqual(info.anniversaryNumber, 7)
        XCTAssertEqual(info.elapsedDays, 2253)
    }

    func testRecurringGregorianOnAnniversaryIsToday() {
        let day = makeDay(date: date(2020, 5, 9), recurring: true)
        let info = DayInfo.compute(day, today: date(2026, 5, 9))

        XCTAssertEqual(info.days, 0)
        XCTAssertTrue(info.isToday)
        XCTAssertFalse(info.isPast)
        XCTAssertEqual(info.yearsAgo, 6)
        // The anniversary is today → 6th occurrence.
        XCTAssertEqual(info.anniversaryNumber, 6)
    }

    // MARK: - Recurring lunar

    func testLateLunarAnniversaryInJanuaryUsesPreviousLunarYear() {
        let day = makeDay(date: date(2025, 1, 7), recurring: true, lunar: true)
        let info = DayInfo.compute(day, today: date(2026, 1, 1))

        XCTAssertEqual(info.displayDate, date(2026, 1, 26))
        XCTAssertEqual(info.days, 25)
        XCTAssertEqual(info.anniversaryNumber, 1)
        XCTAssertEqual(info.elapsedDays, 359)
        XCTAssertFalse(info.isPast)
        XCTAssertTrue(DayInfo.compute(day, today: date(2026, 1, 26)).isToday)
    }

    /// A 三十 recurs on the last day of a 29-day month, as 除夕 does, instead of rolling into the
    /// next month: lunar 2023 腊月 has 30 days and lunar 2024 腊月 has 29.
    func testLunarThirtiethFallsOnLastDayOfShortMonth() {
        let eve = makeDay(date: date(2024, 2, 9), recurring: true, lunar: true)
        XCTAssertEqual(Lunar.solarToLunar(eve.date), Lunar.LunarDate(year: 2023, month: 12, day: 30, isLeap: false))

        XCTAssertEqual(DayInfo.occurrences(of: eve, inGregorianYear: 2025), [date(2025, 1, 28)])
        let info = DayInfo.compute(eve, today: date(2024, 6, 1))
        XCTAssertEqual(info.displayDate, date(2025, 1, 28))
        XCTAssertEqual(info.anniversaryNumber, 1)

        // 八月三十 2020 (2020-10-16); lunar 2021 八月 has 29 days, ending on 2021-10-05.
        let autumn = makeDay(date: date(2020, 10, 16), recurring: true, lunar: true)
        XCTAssertEqual(Lunar.solarToLunar(autumn.date).day, 30)
        XCTAssertEqual(DayInfo.compute(autumn, today: date(2021, 9, 1)).displayDate, date(2021, 10, 5))
    }

    /// The lunar table starts on 1900-01-31. An earlier lunar yearly day has no lunar date to recur
    /// on, and the reminders already skip it; it must not count down to every 春节.
    func testLunarDayBeforeTableDoesNotRecur() {
        let day = makeDay(date: date(1899, 8, 10), recurring: true, lunar: true)
        XCTAssertTrue(DayInfo.occurrences(of: day, inGregorianYear: 2027).isEmpty)
        let info = DayInfo.compute(day, today: date(2026, 10, 11))
        XCTAssertEqual(info.displayDate, date(1899, 8, 10))
        XCTAssertTrue(info.isPast)
        XCTAssertNil(info.anniversaryNumber)
    }

    func testLunarCalendarOccurrencesStayInVisibleGregorianYear() {
        let day = makeDay(date: date(2025, 1, 7), recurring: true, lunar: true)
        XCTAssertEqual(DayInfo.occurrences(of: day, inGregorianYear: 2025), [date(2025, 1, 7)])
        XCTAssertEqual(DayInfo.occurrences(of: day, inGregorianYear: 2026), [date(2026, 1, 26)])
        XCTAssertEqual(DayInfo.occurrences(of: day, inGregorianYear: 2027), [date(2027, 1, 15)])
        XCTAssertEqual(DayInfo.compute(day, today: date(2026, 1, 27)).displayDate, date(2027, 1, 15))
    }

    func testGregorianYearCanContainTwoLunarAnniversaries() {
        let day = makeDay(date: date(2021, 1, 20), recurring: true, lunar: true)
        XCTAssertEqual(DayInfo.occurrences(of: day, inGregorianYear: 2022),
                       [date(2022, 1, 10), date(2022, 12, 30)])
        XCTAssertEqual(DayInfo.compute(day, today: date(2022, 1, 11)).displayDate, date(2022, 12, 30))
    }

    func testGregorianLeapDayUsesSameNormalizedDateInCountdownAndCalendar() {
        let day = makeDay(date: date(2024, 2, 29), recurring: true)
        XCTAssertEqual(DayInfo.occurrences(of: day, inGregorianYear: 2024), [date(2024, 2, 29)])
        XCTAssertEqual(DayInfo.occurrences(of: day, inGregorianYear: 2025), [date(2025, 3, 1)])
        XCTAssertEqual(DayInfo.compute(day, today: date(2025, 2, 28)).displayDate, date(2025, 3, 1))
        XCTAssertTrue(DayInfo.compute(day, today: date(2025, 3, 1)).isToday)
        XCTAssertEqual(DayInfo.compute(day, today: date(2025, 3, 2)).displayDate, date(2026, 3, 1))
    }

    func testNonRecurringCalendarOccurrenceRemainsInOriginalYear() {
        let day = makeDay(date: date(2025, 1, 7), lunar: true)
        XCTAssertEqual(DayInfo.occurrences(of: day, inGregorianYear: 2025), [date(2025, 1, 7)])
        XCTAssertTrue(DayInfo.occurrences(of: day, inGregorianYear: 2026).isEmpty)
    }

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
