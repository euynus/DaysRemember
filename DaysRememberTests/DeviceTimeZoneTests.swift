import XCTest
@testable import DaysRemember

/// Days are stored on the app calendar; the device's time zone decides which day is today and
/// when reminders arrive.
final class DeviceTimeZoneTests: XCTestCase {
    private let newYork = TimeZone(identifier: "America/New_York")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func instant(_ iso: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso))
    }

    private func appDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        CNDate.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testTodayIsTheDateOnTheDevicesClock() throws {
        // 22:30 on 23 April in New York is already 24 April in Beijing.
        let evening = try instant("2026-04-24T02:30:00Z")
        let appTime = CNDate.appTime(evening, in: newYork)
        XCTAssertEqual(appTime, appDate(2026, 4, 23, 22, 30))
        XCTAssertEqual(CNDate.calendar.startOfDay(for: appTime), appDate(2026, 4, 23))
        XCTAssertEqual(CNDate.instant(appTime, in: newYork), evening)
        XCTAssertEqual(CNDate.appTime(evening, in: tokyo), appDate(2026, 4, 24, 11, 30))
    }

    func testCountdownTurnsOverAtLocalMidnight() throws {
        let day = Day(id: "trip", title: "Trip", date: appDate(2026, 4, 25), category: .travel, photo: .systemDefault)
        let beforeMidnight = CNDate.appTime(try instant("2026-04-24T03:59:00Z"), in: newYork)
        let afterMidnight = CNDate.appTime(try instant("2026-04-24T04:01:00Z"), in: newYork)
        XCTAssertEqual(DayInfo.compute(day, today: beforeMidnight).days, 2)
        XCTAssertEqual(DayInfo.compute(day, today: afterMidnight).days, 1)
    }

    func testWidgetDaysStartAtLocalMidnightsAcrossDaylightSaving() throws {
        // Daylight saving begins in New York on 8 March 2026.
        let starts = CNDate.localDayStarts(after: try instant("2026-03-07T20:00:00Z"), count: 3, in: newYork)
        XCTAssertEqual(starts, [try instant("2026-03-08T05:00:00Z"), try instant("2026-03-09T04:00:00Z"),
                                try instant("2026-03-10T04:00:00Z")])
    }

    func testRemindersArriveAtTheChosenLocalTime() throws {
        let config = try JSONDecoder().decode(AppSettingsSnapshot.self, from: Data("""
        {"hasOnboarded":true,"notifPre7":false,"notifPre3":false,"notifPre1":false,"notifDay0":true,
         "memoryEnabled":false,"momentsEnabled":false,"notificationHour":9,"notificationMinute":0}
        """.utf8))
        let day = Day(id: "event", title: "Event", date: appDate(2026, 7, 20), category: .life, photo: .systemDefault,
                      reminderOffsets: [0])
        // 07:00 in New York, two hours before the reminder there and long after 09:00 in Beijing.
        let now = CNDate.appTime(try instant("2026-07-20T11:00:00Z"), in: newYork)
        let plan = NotificationManager.plan(days: [day], settings: config, now: now)
        XCTAssertEqual(plan.map(\.date), [appDate(2026, 7, 20, 9)])
        XCTAssertEqual(CNDate.instant(try XCTUnwrap(plan.first).date, in: newYork), try instant("2026-07-20T13:00:00Z"))
    }
}
