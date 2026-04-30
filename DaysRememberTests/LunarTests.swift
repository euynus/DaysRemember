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

    func testFormatting() {
        let s = Lunar.fmt(date(2026, 4, 23))
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.contains("月"))
    }
}
