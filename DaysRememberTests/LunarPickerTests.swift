import XCTest
@testable import DaysRemember

final class LunarPickerTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testMonthOptionsIncludeOnlyTheYearsLeapMonthInOrder() {
        XCTAssertEqual(Lunar.supportedYears, 1900...2100)
        XCTAssertEqual(Lunar.months(in: 2024), (1...12).map {
            Lunar.Month(number: $0, isLeap: false)
        })

        let months = Lunar.months(in: 2023)
        XCTAssertEqual(months.count, 13)
        XCTAssertEqual(Array(months.prefix(4)), [
            Lunar.Month(number: 1, isLeap: false),
            Lunar.Month(number: 2, isLeap: false),
            Lunar.Month(number: 2, isLeap: true),
            Lunar.Month(number: 3, isLeap: false)
        ])
        XCTAssertEqual(months.filter(\.isLeap), [Lunar.Month(number: 2, isLeap: true)])
        XCTAssertEqual(Lunar.months(in: 2025).filter(\.isLeap), [
            Lunar.Month(number: 6, isLeap: true)
        ])
    }

    func testRegularAndLeapMonthDayCounts() {
        XCTAssertEqual(Lunar.dayCount(year: 2023, month: 2), 30)
        XCTAssertEqual(Lunar.dayCount(year: 2023, month: 3), 29)
        XCTAssertEqual(Lunar.dayCount(year: 2023, month: 2, isLeap: true), 29)
        XCTAssertEqual(Lunar.dayCount(year: 2017, month: 6, isLeap: true), 30)
        XCTAssertEqual(Lunar.dayCount(year: 2025, month: 6, isLeap: true), 29)
    }

    func testInvalidYearsAndMonthsAreRejected() {
        for year in [Int.min, 1899, 2101, Int.max] {
            XCTAssertTrue(Lunar.months(in: year).isEmpty)
            XCTAssertNil(Lunar.dayCount(year: year, month: 1))
            XCTAssertNil(Lunar.solarDate(for: .init(year: year, month: 1, day: 1, isLeap: false)))
        }
        for month in [Int.min, 0, 13, Int.max] {
            XCTAssertNil(Lunar.dayCount(year: 2023, month: month))
            XCTAssertNil(Lunar.solarDate(for: .init(year: 2023, month: month, day: 1, isLeap: false)))
        }
        XCTAssertNil(Lunar.dayCount(year: 2024, month: 2, isLeap: true))
        XCTAssertNil(Lunar.dayCount(year: 2023, month: 3, isLeap: true))
    }

    func testMonthSwitchClampsDayWithoutRollingIntoNextMonth() {
        XCTAssertEqual(Lunar.clamped(.init(year: 2023, month: 3, day: 30, isLeap: false)),
                       .init(year: 2023, month: 3, day: 29, isLeap: false))
        XCTAssertEqual(Lunar.clamped(.init(year: 2023, month: 2, day: 30, isLeap: true)),
                       .init(year: 2023, month: 2, day: 29, isLeap: true))
    }

    func testYearSwitchDropsMissingLeapMonthAndClampsDay() {
        // 2023 has a leap second month; 2025 has a leap sixth month instead.
        XCTAssertEqual(Lunar.clamped(.init(year: 2025, month: 2, day: 30, isLeap: true)),
                       .init(year: 2025, month: 2, day: 29, isLeap: false))
        XCTAssertEqual(Lunar.clamped(.init(year: 2024, month: 2, day: 29, isLeap: true)),
                       .init(year: 2024, month: 2, day: 29, isLeap: false))
        // The same leap month can have a different length after a year switch.
        XCTAssertEqual(Lunar.clamped(.init(year: 2025, month: 6, day: 30, isLeap: true)),
                       .init(year: 2025, month: 6, day: 29, isLeap: true))
    }

    func testClampingHandlesExtremeComponentsAndPreservesValidDates() {
        XCTAssertEqual(Lunar.clamped(.init(year: Int.min, month: Int.min, day: Int.min, isLeap: true)),
                       .init(year: 1900, month: 1, day: 1, isLeap: false))
        XCTAssertEqual(Lunar.clamped(.init(year: Int.max, month: Int.max, day: Int.max, isLeap: true)),
                       .init(year: 2100, month: 12, day: 29, isLeap: false))
        let valid = Lunar.LunarDate(year: 2017, month: 6, day: 30, isLeap: true)
        XCTAssertEqual(Lunar.clamped(valid), valid)
    }

    func testKnownGregorianCounterpartsAndRoundTrips() throws {
        let cases: [(Lunar.LunarDate, Date)] = [
            (.init(year: 1900, month: 1, day: 1, isLeap: false), date(1900, 1, 31)),
            (.init(year: 2023, month: 2, day: 1, isLeap: false), date(2023, 2, 20)),
            (.init(year: 2023, month: 2, day: 1, isLeap: true), date(2023, 3, 22)),
            (.init(year: 2023, month: 2, day: 29, isLeap: true), date(2023, 4, 19)),
            (.init(year: 2024, month: 1, day: 1, isLeap: false), date(2024, 2, 10)),
            (.init(year: 2100, month: 12, day: 29, isLeap: false), date(2101, 1, 28))
        ]
        for (lunar, expected) in cases {
            let solar = try XCTUnwrap(Lunar.solarDate(for: lunar))
            XCTAssertEqual(solar, expected)
            XCTAssertEqual(Lunar.supportedLunarDate(for: solar), lunar)
            XCTAssertEqual(Lunar.pickerDate(for: solar), lunar)
        }
    }

    func testSolarConversionRejectsInvalidDaysAndLeapFlags() {
        for day in [Int.min, 0, 30, Int.max] {
            XCTAssertNil(Lunar.solarDate(for: .init(year: 2023, month: 2, day: day, isLeap: true)))
        }
        XCTAssertNil(Lunar.solarDate(for: .init(year: 2024, month: 2, day: 1, isLeap: true)))
        XCTAssertNil(Lunar.solarDate(for: .init(year: 2023, month: 3, day: 1, isLeap: true)))
    }

    func testSupportedRangeIncludesEntireLastLunarDay() {
        let first = date(1900, 1, 31)
        let end = date(2101, 1, 29)
        XCTAssertEqual(Lunar.supportedSolarDates, first..<end)
        XCTAssertNil(Lunar.supportedLunarDate(for: first.addingTimeInterval(-1)))
        XCTAssertEqual(Lunar.supportedLunarDate(for: first),
                       .init(year: 1900, month: 1, day: 1, isLeap: false))
        XCTAssertEqual(Lunar.supportedLunarDate(for: end.addingTimeInterval(-1)),
                       .init(year: 2100, month: 12, day: 29, isLeap: false))
        XCTAssertNil(Lunar.supportedLunarDate(for: end))
    }

    func testPickerProjectionSafelyClampsOutOfRangeDates() {
        for solar in [Date.distantPast, date(1900, 1, 30)] {
            XCTAssertEqual(Lunar.pickerDate(for: solar),
                           .init(year: 1900, month: 1, day: 1, isLeap: false))
        }
        for solar in [date(2101, 1, 29), Date.distantFuture] {
            XCTAssertEqual(Lunar.pickerDate(for: solar),
                           .init(year: 2100, month: 12, day: 29, isLeap: false))
        }
    }

    func testOutOfRangeDatesHaveSafeDisplayLabels() {
        for date in [Date.distantPast, Date.distantFuture] {
            XCTAssertEqual(Lunar.fmt(date), "日期超出范围")
            XCTAssertEqual(Lunar.fmtFull(date), "农历日期超出范围")
        }
    }
}
