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

    func testSampleAnniversary() {
        // 妈妈生日 — 1962-06-18 lunar 五月十七.
        let l = Lunar.solarToLunar(date(1962, 6, 18))
        XCTAssertEqual(l.month, 5)
        XCTAssertEqual(l.day, 17)
    }

    func testFullTableRoundTrip() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let base = calendar.date(from: DateComponents(year: 1900, month: 1, day: 31))!
        let end = base.addingTimeInterval(73412 * 86400)
        XCTAssertEqual(Lunar.lunarToSolar(year: 2101, month: 1, day: 1), end)
        var solar = base
        while solar < end {
            let lunar = Lunar.solarToLunar(solar)
            XCTAssertTrue((1900...2100).contains(lunar.year))
            XCTAssertTrue((1...12).contains(lunar.month))
            XCTAssertTrue((1...30).contains(lunar.day))
            XCTAssertEqual(Lunar.lunarToSolar(year: lunar.year, month: lunar.month,
                                             day: lunar.day, isLeap: lunar.isLeap), solar)
            solar = solar.addingTimeInterval(86400)
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
