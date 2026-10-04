import XCTest
@testable import DaysRemember

final class CalendarSelectionTests: XCTestCase {
    func testSelectionIdentityUsesTheShanghaiCalendarDay() throws {
        let midnight = try date(2026, 4, 23)
        let morning = CalendarDaySelection(date: midnight.addingTimeInterval(3600))
        let evening = CalendarDaySelection(date: midnight.addingTimeInterval(23 * 3600))
        XCTAssertEqual(morning.id, midnight)
        XCTAssertEqual(evening.id, morning.id)
    }

    func testSelectionReadsUpdatedRecordsAndExcludesDeletedOrMovedDays() throws {
        let selectedDate = try date(2026, 4, 23)
        let selection = CalendarDaySelection(date: selectedDate)
        let first = day("first", date: selectedDate)
        let second = day("second", date: selectedDate)
        XCTAssertEqual(selection.events(in: [first, second]).map(\.id), ["first", "second"])

        var changed = first
        changed.title = "Updated title"
        changed.categoryID = "custom.updated"
        changed.categoryLabel = "Updated category"
        let current = selection.events(in: [changed])
        XCTAssertEqual(current, [changed])
        XCTAssertEqual(current.first?.title, "Updated title")
        XCTAssertEqual(current.first?.categoryLabel, "Updated category")

        changed.date = try date(2026, 4, 24)
        XCTAssertTrue(selection.events(in: [changed]).isEmpty)
        XCTAssertTrue(selection.events(in: []).isEmpty)
    }

    func testSelectionMatchesGregorianAndLunarOccurrencesWithoutMovingFutureStarts() throws {
        let selectedDate = try date(2026, 4, 23)
        let selection = CalendarDaySelection(date: selectedDate)
        let once = day("once", date: selectedDate)
        let yearly = day("yearly", date: try date(2020, 4, 23), recurring: true)
        let futureStart = day("future", date: try date(2027, 4, 23), recurring: true)
        let anotherDay = day("other", date: try date(2026, 4, 24))
        let lunarDate = Lunar.solarToLunar(selectedDate)
        let originalLunarDate = Lunar.lunarToSolar(year: lunarDate.year - 1, month: lunarDate.month,
                                                 day: lunarDate.day, isLeap: lunarDate.isLeap)
        let lunar = day("lunar", date: originalLunarDate, recurring: true, lunar: true)

        XCTAssertEqual(selection.events(in: [once, yearly, futureStart, anotherDay, lunar]).map(\.id),
                       ["once", "yearly", "lunar"])
    }

    func testLeapDayAnniversaryUsesTheSameMarchFirstNormalizationAsCalendar() throws {
        let leapDay = day("leap", date: try date(2024, 2, 29), recurring: true)
        XCTAssertTrue(CalendarDaySelection(date: try date(2025, 2, 28)).events(in: [leapDay]).isEmpty)
        XCTAssertEqual(CalendarDaySelection(date: try date(2025, 3, 1)).events(in: [leapDay]).map(\.id),
                       ["leap"])
    }

    private func day(_ id: String, date: Date, recurring: Bool = false, lunar: Bool = false) -> Day {
        Day(id: id, title: id, date: date, recurring: recurring, lunar: lunar,
            category: .life, photo: .home)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try XCTUnwrap(CNDate.calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }
}
