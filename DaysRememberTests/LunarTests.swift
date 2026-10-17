import XCTest
@testable import DaysRemember

final class LunarTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal.date(from: c)!
    }

    func testRoundTrip() {
        for (y, m, d) in [(2019, 10, 12), (2026, 4, 23), (1962, 6, 18), (2000, 1, 1)] {
            let solar = date(y, m, d)
            let lunar = Lunar.solarToLunar(solar)
            let back = Lunar.lunarToSolar(year: lunar.year, month: lunar.month,
                                          day: lunar.day, isLeap: lunar.isLeap)
            // Day-precision equality (HMS may differ).
            let cal = CNDate.calendar
            XCTAssertEqual(cal.component(.day, from: solar), cal.component(.day, from: back))
            XCTAssertEqual(cal.component(.month, from: solar), cal.component(.month, from: back))
        }
    }

    /// Month boundaries from the Hong Kong Observatory's 公曆與農曆日期對照表 for the years whose
    /// table words were wrong; the round-trip tests only check the table against itself.
    func testTableMatchesHongKongObservatory() {
        let cases: [(solar: (Int, Int, Int), month: Int, day: Int, isLeap: Bool)] = [
            ((1933, 7, 22), 5, 30, true), ((1933, 7, 23), 6, 1, false),
            ((1933, 8, 20), 6, 29, false), ((1933, 8, 21), 7, 1, false),
            ((1996, 7, 15), 5, 30, false), ((1996, 7, 16), 6, 1, false),
            ((1996, 9, 12), 7, 30, false), ((1996, 9, 27), 8, 15, false),
            ((1996, 10, 11), 8, 29, false), ((1996, 10, 12), 9, 1, false),
            ((2057, 9, 28), 9, 1, false), ((2057, 10, 27), 9, 30, false),
            ((2060, 4, 30), 4, 1, false), ((2060, 5, 29), 4, 30, false),
        ]
        for c in cases {
            let lunar = Lunar.solarToLunar(date(c.solar.0, c.solar.1, c.solar.2))
            XCTAssertEqual([lunar.month, lunar.day], [c.month, c.day], "\(c.solar)")
            XCTAssertEqual(lunar.isLeap, c.isLeap, "\(c.solar)")
        }
        XCTAssertEqual(Lunar.dayCount(year: 1996, month: 5), 30)
        XCTAssertEqual(Lunar.dayCount(year: 1933, month: 5, isLeap: true), 30)
    }

    /// Asia/Shanghai kept daylight saving in 1919, 1940–1949 and 1986–1991, so a midnight then
    /// is 23:00 the day before in UTC+8; the conversion must still use that calendar day.
    func testConversionUsesBeijingDaysDuringDaylightSaving() {
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        for (y, m, d) in [(1919, 6, 1), (1941, 6, 1), (1988, 6, 15), (1988, 7, 15), (1991, 9, 1)] {
            let solar = date(y, m, d)
            let lunar = Lunar.solarToLunar(solar)
            let expected = chinese.dateComponents([.month, .day], from: solar)
            XCTAssertEqual([lunar.month, lunar.day], [expected.month!, expected.day!], "\(y)-\(m)-\(d)")
            XCTAssertEqual(Lunar.lunarToSolar(year: lunar.year, month: lunar.month, day: lunar.day,
                                              isLeap: lunar.isLeap), solar, "\(y)-\(m)-\(d)")
        }
        // 端午 1988 is 1988-06-18.
        XCTAssertEqual(SolarTerms.lunarHoliday(for: date(1988, 6, 18)), "端午")
    }

    func testSampleAnniversary() {
        // 妈妈生日 — 1962-06-18 lunar 五月十七.
        let l = Lunar.solarToLunar(date(1962, 6, 18))
        XCTAssertEqual(l.month, 5)
        XCTAssertEqual(l.day, 17)
    }

    func testFullTableRoundTrip() {
        let calendar = CNDate.calendar
        let base = date(1900, 1, 31)
        let end = calendar.date(byAdding: .day, value: 73412, to: base)!
        XCTAssertEqual(Lunar.lunarToSolar(year: 2101, month: 1, day: 1), end)
        XCTAssertEqual(Lunar.supportedSolarDates, base..<end)
        var solar = base
        while solar < end {
            let lunar = Lunar.solarToLunar(solar)
            XCTAssertTrue((1900...2100).contains(lunar.year))
            XCTAssertTrue((1...12).contains(lunar.month))
            XCTAssertTrue((1...30).contains(lunar.day))
            XCTAssertEqual(Lunar.lunarToSolar(year: lunar.year, month: lunar.month,
                                             day: lunar.day, isLeap: lunar.isLeap), solar)
            // Some daylight-saving changes skipped midnight; those days start at 01:00.
            solar = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: solar)!)
        }
    }

    func testConversionBenchmark() {
        let base = date(2026, 1, 1)
        let dates = (0..<2000).map { base.addingTimeInterval(Double($0) * 86400) }
        var timings: [Double] = []
        for _ in 0..<5 {
            let start = CFAbsoluteTimeGetCurrent()
            for solar in dates {
                let lunar = Lunar.solarToLunar(solar)
                let back = Lunar.lunarToSolar(year: lunar.year, month: lunar.month,
                                             day: lunar.day, isLeap: lunar.isLeap)
                XCTAssertEqual(back, solar)
            }
            timings.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
        }
        let summary = "LUNAR_BENCH round_trips=2000 median_ms=\(timings.sorted()[2])"
        print(summary)
        let attachment = XCTAttachment(string: summary)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Published equinox, solstice and 立春 instants (UTC) for recent years.
    func testSolarTermInstantsMatchPublishedTimes() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let published: [(year: Int, index: Int, month: Int, day: Int, hour: Int, minute: Int)] = [
            (2024, 2, 2, 4, 8, 27), (2024, 5, 3, 20, 3, 6), (2024, 11, 6, 20, 20, 51),
            (2024, 17, 9, 22, 12, 44), (2024, 23, 12, 21, 9, 21),
            (2025, 2, 2, 3, 14, 10), (2025, 5, 3, 20, 9, 1), (2025, 11, 6, 21, 2, 42),
            (2025, 17, 9, 22, 18, 19), (2025, 23, 12, 21, 15, 3),
            (2026, 2, 2, 3, 20, 2), (2026, 5, 3, 20, 14, 46), (2026, 11, 6, 21, 8, 24),
            (2026, 17, 9, 23, 0, 5), (2026, 23, 12, 21, 20, 50),
        ]
        for term in published {
            let expected = try XCTUnwrap(utc.date(from: DateComponents(
                year: term.year, month: term.month, day: term.day, hour: term.hour, minute: term.minute)))
            let computed = SolarTerms.instants(in: term.year)[term.index]
            XCTAssertLessThan(abs(computed.timeIntervalSince(expected)), 120, "\(term)")
        }
    }

    /// Terms are dated in Beijing time; these differ from the old fixed Gregorian table.
    func testSolarTermNamesUseBeijingDates() {
        XCTAssertEqual(SolarTerms.name(for: date(2025, 2, 3)), "立春")
        XCTAssertNil(SolarTerms.name(for: date(2025, 2, 4)))
        XCTAssertEqual(SolarTerms.name(for: date(2025, 12, 21)), "冬至") // 23:03 Beijing
        XCTAssertEqual(SolarTerms.name(for: date(2026, 3, 20)), "春分")
        XCTAssertNil(SolarTerms.name(for: date(2026, 3, 21)))
        XCTAssertEqual(SolarTerms.name(for: date(2026, 10, 8)), "寒露")
        XCTAssertEqual(SolarTerms.name(for: date(2026, 9, 23)), "秋分")
    }

    func testEverySupportedYearHasTwentyFourOrderedTerms() {
        var beijing = Calendar(identifier: .gregorian)
        beijing.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        for year in 1900...2100 {
            let instants = SolarTerms.instants(in: year)
            XCTAssertEqual(instants.count, 24)
            XCTAssertEqual(instants.map { beijing.component(.year, from: $0) }, Array(repeating: year, count: 24))
            for (earlier, later) in zip(instants, instants.dropFirst()) {
                let gap = later.timeIntervalSince(earlier) / 86400
                XCTAssertTrue((14...16.5).contains(gap), "\(year): \(gap) days between terms")
            }
        }
    }

    /// A leap month repeats its month number but not its festivals.
    func testLunarHolidaysSkipLeapMonths() {
        let doubled = [
            ("端午", date(2028, 5, 28), date(2028, 6, 27)),  // 闰五月初五
            ("龙抬头", date(2023, 2, 21), date(2023, 3, 23)), // 闰二月初二
        ]
        for (name, regular, leap) in doubled {
            XCTAssertEqual(SolarTerms.lunarHoliday(for: regular), name)
            XCTAssertTrue(Lunar.solarToLunar(leap).isLeap)
            XCTAssertNil(SolarTerms.lunarHoliday(for: leap))
        }
    }

    /// 除夕 falls on the last day of the twelfth month, whether it has 29 or 30 days.
    func testLunarNewYearsEve() {
        for (eve, newYear) in [(date(2026, 2, 16), date(2026, 2, 17)),
                               (date(2025, 1, 28), date(2025, 1, 29))] {
            XCTAssertEqual(SolarTerms.lunarHoliday(for: eve), "除夕")
            XCTAssertEqual(SolarTerms.lunarHoliday(for: newYear), "春节")
        }
        XCTAssertNil(SolarTerms.lunarHoliday(for: date(2026, 2, 15)))
    }

    /// The calendar can page past the table. Before it the conversion clamps to its first day,
    /// which once made every day 春节; after it, it ran on into festivals that don't exist.
    func testNoLunarHolidaysOutsideTheTable() {
        let cal = CNDate.calendar
        let table = Lunar.supportedSolarDates
        // Lunar 2100 runs into early 2101, so the table ends at its 除夕, not on 2100-12-31.
        let outside = [(cal.date(byAdding: .day, value: -60, to: table.lowerBound)!, table.lowerBound),
                       (table.upperBound, cal.date(byAdding: .day, value: 90, to: table.upperBound)!)]
        for (start, end) in outside {
            var day = start
            while day < end {
                XCTAssertNil(SolarTerms.lunarHoliday(for: day), "\(day)")
                day = cal.date(byAdding: .day, value: 1, to: day)!
            }
        }
        XCTAssertEqual(SolarTerms.lunarHoliday(for: table.lowerBound), "春节")
        XCTAssertEqual(SolarTerms.lunarHoliday(for: cal.date(byAdding: .day, value: -1, to: table.upperBound)!), "除夕")
        let after = Lunar.solarToLunar(cal.date(byAdding: .day, value: 90, to: table.upperBound)!)
        XCTAssertTrue((1...12).contains(after.month) && (1...30).contains(after.day), "\(after)")
    }

    func testFormatting() {
        let s = Lunar.fmt(date(2026, 4, 23))
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.contains("月"))
    }

    /// solarToLunar must always yield month 1...12 and day 1...30 — the formatters
    /// index fixed-size arrays (CN_MONTH / CN_DAY_PREFIX / CN_NUM), so any out-of-range
    /// month/day would trap. Sweep day-by-day across years including new-year boundaries.
    /// (Verified exhaustively over the full 1900–2100 table; this guards the boundaries.)
    func testConversionStaysInRangeAcrossYearBoundaries() {
        let cal = CNDate.calendar
        for year in [1900, 1901, 1984, 2000, 2033, 2099, 2100] {
            // January–February brackets every Spring Festival transition.
            var day = date(year, 1, 1)
            let end = date(year, 3, 1)
            while day < end {
                let l = Lunar.solarToLunar(day)
                XCTAssertTrue((1...12).contains(l.month), "month \(l.month) out of range for \(day)")
                XCTAssertTrue((1...30).contains(l.day), "day \(l.day) out of range for \(day)")
                _ = Lunar.fmtFull(day) // would trap on an out-of-range index
                day = cal.date(byAdding: .day, value: 1, to: day)!
            }
        }
    }
}
