import XCTest
import UserNotifications
@testable import DaysRemember

final class NotificationPlanningTests: XCTestCase {
    func testLateAndEarlyRemindersFireAtTheChosenTimeAcrossYearBoundary() {
        let now = date(2026, 12, 31, 22)
        XCTAssertEqual(NotificationManager.triggerDate(displayDate: date(2027, 1, 1), offset: 1,
                                                         hour: 23, minute: 15, now: now),
                       date(2026, 12, 31, 23, 15))
        XCTAssertEqual(NotificationManager.triggerDate(displayDate: date(2027, 1, 1), offset: 0,
                                                         hour: 7, minute: 15, now: now),
                       date(2027, 1, 1, 7, 15))
        XCTAssertNil(NotificationManager.triggerDate(displayDate: date(2026, 12, 31), offset: 0,
                                                      hour: 22, minute: 0, now: now))
        XCTAssertNil(NotificationManager.triggerDate(displayDate: date(2027, 1, 1), offset: -1,
                                                      hour: 9, minute: 0, now: now))
    }

    func testLateReminderTimeKeepsEachReminderOnItsOwnDay() throws {
        var config = try settings()
        XCTAssertFalse(config.quietHours, "Older snapshots no longer enable quiet hours")
        config.notificationHour = 23
        config.notificationMinute = 15
        let event = day("event", date(2026, 7, 20), offsets: [7, 1, 0])
        let plan = NotificationManager.plan(days: [event], settings: config, now: date(2026, 7, 1))

        XCTAssertEqual(plan.map(\.date), [date(2026, 7, 13, 23, 15), date(2026, 7, 19, 23, 15), date(2026, 7, 20, 23, 15)])
        XCTAssertEqual(plan.map(\.body), ["「event」还有 7 天", "「event」就是明天", "今天是「event」"])
        XCTAssertTrue(NotificationManager.plan(days: [event], settings: config, now: date(2026, 7, 21, 1)).isEmpty)
    }

    func testEmptyOverridesExcludeAnnualMemoriesAndOrdinaryReminders() throws {
        var config = try settings()
        config.memoryEnabled = true
        let days = [day("annual", date(2020, 7, 20), recurring: true, offsets: []),
                    day("past", date(2020, 7, 20), offsets: []),
                    day("invalid", date(2020, 7, 20), offsets: [-1]),
                    day("future", date(2026, 7, 20), offsets: [])]
        XCTAssertTrue(NotificationManager.plan(days: days, settings: config, now: date(2026, 1, 1)).isEmpty)
        let inherited = day("inherited", date(2026, 7, 20))
        XCTAssertEqual(NotificationManager.plan(days: [inherited], settings: config, now: date(2026, 1, 1)).count, 1)
    }

    func testGregorianLeapDayPlansSeveralYearsWithUniqueIdentifiers() throws {
        let event = day("leap", date(2024, 2, 29), recurring: true)
        let plan = NotificationManager.plan(days: [event], settings: try settings(), now: date(2025, 1, 1))
        XCTAssertEqual(plan.map(\.date), [date(2025, 3, 1, 9), date(2026, 3, 1, 9), date(2027, 3, 1, 9),
                                          date(2028, 2, 29, 9), date(2029, 3, 1, 9)])
        XCTAssertEqual(Set(plan.map(\.id)).count, plan.count)
        XCTAssertTrue(plan.allSatisfy { !$0.repeats })
    }

    func testLunarJanuaryAnniversariesUseEachLunarYear() throws {
        let event = day("lunar", date(2025, 1, 7), recurring: true, lunar: true)
        let plan = NotificationManager.plan(days: [event], settings: try settings(), now: date(2026, 1, 1))
        XCTAssertEqual(Array(plan.prefix(2)).map(\.date), [date(2026, 1, 26, 9), date(2027, 1, 15, 9)])
        XCTAssertGreaterThanOrEqual(plan.count, 4)
        for item in plan {
            let lunar = Lunar.solarToLunar(item.date)
            XCTAssertEqual(lunar.month, 12)
            XCTAssertEqual(lunar.day, 8)
            XCTAssertFalse(item.repeats)
        }
    }

    func testBothLunarOccurrencesInOneGregorianYearAreRetained() throws {
        let event = day("lunar", date(2021, 1, 20), recurring: true, lunar: true)
        let plan = NotificationManager.plan(days: [event], settings: try settings(), now: date(2022, 1, 1))
        XCTAssertEqual(plan.filter { CNDate.calendar.component(.year, from: $0.date) == 2022 }.map(\.date),
                       [date(2022, 1, 10, 9), date(2022, 12, 30, 9)])
    }

    func testMemoriesHonorLunarDatesAndLateTimesInEveryYear() throws {
        var config = try settings()
        config.memoryEnabled = true
        config.notificationHour = 23
        let event = day("memory", date(2025, 1, 7), lunar: true)
        let plan = NotificationManager.plan(days: [event], settings: config, now: date(2026, 1, 1))
        XCTAssertEqual(Array(plan.prefix(2)).map(\.date), [date(2026, 1, 26, 23), date(2027, 1, 15, 23)])
        XCTAssertTrue(plan.allSatisfy { $0.id.hasPrefix("dr.memory.") && !$0.repeats })
        XCTAssertEqual(plan.first?.body, "想起这一天 · 「memory」 · 2026年1月26日")
    }

    func testGlobalCapacityKeepsEarliestRequestsIncludingDailyGreeting() throws {
        var config = try settings()
        config.momentsEnabled = true
        let days = (0..<80).map { index in
            day("day-\(index)", CNDate.calendar.date(byAdding: .day, value: index, to: date(2026, 1, 1))!)
        }
        let plan = NotificationManager.plan(days: Array(days.reversed()), settings: config, now: date(2026, 1, 1))
        XCTAssertEqual(plan.count, 64)
        XCTAssertEqual(plan.first?.id, "dr.daily.greeting")
        XCTAssertEqual(plan.last?.dayID, "day-62")
        XCTAssertEqual(plan.filter(\.repeats).count, 1)
        XCTAssertEqual(plan.map(\.id), NotificationManager.plan(days: days, settings: config, now: date(2026, 1, 1)).map(\.id))
        XCTAssertEqual(NotificationManager.plan(days: days, settings: config, now: date(2026, 1, 1), capacity: 2).count, 2)
        XCTAssertTrue(NotificationManager.plan(days: days, settings: config, now: date(2026, 1, 1), capacity: -1).isEmpty)
    }

    func testYearBoundaryIncludesUpcomingOffsetsAtLateTimes() throws {
        var config = try settings()
        config.notificationHour = 23
        let upcoming = day("new-year", date(2020, 1, 1), recurring: true, offsets: [7, 0])
        let oldYear = day("old-year", date(2020, 12, 31), recurring: true, offsets: [0])
        let before = NotificationManager.plan(days: [upcoming], settings: config, now: date(2026, 12, 24))
        XCTAssertEqual(before.first?.date, date(2026, 12, 25, 23))
        let after = NotificationManager.plan(days: [oldYear], settings: config, now: date(2027, 1, 1))
        XCTAssertEqual(after.first?.date, date(2027, 12, 31, 23))
    }

    func testHorizonAndOriginalDateAreRespected() throws {
        let config = try settings()
        let future = day("future", date(2028, 7, 1), recurring: true)
        let plan = NotificationManager.plan(days: [future], settings: config, now: date(2026, 1, 1))
        XCTAssertEqual(plan.map(\.date), [date(2028, 7, 1, 9), date(2029, 7, 1, 9), date(2030, 7, 1, 9)])
        XCTAssertTrue(NotificationManager.plan(days: [day("far", date(2032, 1, 1))], settings: config,
                                               now: date(2026, 1, 1)).isEmpty)
        let unsupported = day("unsupported", date(1899, 1, 1), recurring: true, lunar: true)
        XCTAssertTrue(NotificationManager.plan(days: [unsupported], settings: config, now: date(2026, 1, 1)).isEmpty)
    }

    func testPendingPreviewUsesActualTriggerAndContentWithExplicitTimeZone() throws {
        let config = try settings()
        let plans = NotificationManager.plan(days: [day("later", date(2099, 7, 20)), day("first", date(2099, 7, 19))],
                                            settings: config, now: date(2099, 1, 1))
        let requests = plans.reversed().map(\.request)
        let pending = NotificationManager.scheduledReminders(from: requests)
        XCTAssertEqual(pending.first?.dayID, "first")
        XCTAssertEqual(pending.first?.date, date(2099, 7, 19, 9))
        XCTAssertEqual(pending.first?.request.content.body, "今天是「first」")
        let trigger = try XCTUnwrap(pending.first?.request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.timeZone, CNDate.calendar.timeZone)
        XCTAssertEqual(trigger.dateComponents.year, 2099)
        XCTAssertFalse(trigger.repeats)
        let unrelated = UNNotificationRequest(identifier: "another.feature", content: requests[0].content, trigger: trigger)
        XCTAssertTrue(NotificationManager.scheduledReminders(from: [unrelated]).isEmpty)
        XCTAssertTrue(NotificationManager.scheduledReminders(from: []).isEmpty)
        XCTAssertFalse(NotificationManager.canDeliver(.notDetermined))
        XCTAssertFalse(NotificationManager.canDeliver(.denied))
        XCTAssertTrue(NotificationManager.canDeliver(.authorized))
    }

    @MainActor
    func testCancelledInFlightMutationFinishesBeforeDeleteAndReplacement() async {
        let manager = NotificationManager()
        var release: CheckedContinuation<Void, Never>?
        var operations: [String] = []
        let old = manager.enqueueMutation {
            operations.append("old add started")
            await withCheckedContinuation { release = $0 }
            operations.append("old add finished")
        }
        while release == nil { await Task.yield() }
        old.cancel()
        let deletion = manager.enqueueMutation { operations.append("delete") }
        let replacement = manager.enqueueMutation { operations.append("new add") }
        await Task.yield()
        XCTAssertEqual(operations, ["old add started"])
        release?.resume()
        await deletion.value
        await replacement.value
        XCTAssertEqual(operations, ["old add started", "old add finished", "delete", "new add"])
    }

    func testDailyGreetingUsesItsOwnTimeAndMorningWording() throws {
        var config = try settings()
        XCTAssertEqual(config.greetingHour, 8, "Snapshots without a greeting time keep 08:00")
        config.momentsEnabled = true
        config.greetingHour = 20
        config.greetingMinute = 30
        let now = date(2026, 4, 23, 12)
        let evening = try XCTUnwrap(NotificationManager.plan(days: [], settings: config, now: now)
            .first { $0.id == "dr.daily.greeting" })
        XCTAssertTrue(evening.repeats)
        XCTAssertEqual(CNDate.calendar.component(.hour, from: evening.date), 20)
        XCTAssertEqual(CNDate.calendar.component(.minute, from: evening.date), 30)
        XCTAssertFalse(evening.body.hasPrefix("早安"))

        config.greetingHour = 7
        let morning = try XCTUnwrap(NotificationManager.plan(days: [], settings: config, now: now)
            .first { $0.id == "dr.daily.greeting" })
        XCTAssertTrue(morning.body.hasPrefix("早安"))
    }

    private func settings() throws -> AppSettingsSnapshot {
        try JSONDecoder().decode(AppSettingsSnapshot.self, from: Data("""
        {"hasOnboarded":true,"notifPre7":false,"notifPre3":false,"notifPre1":false,"notifDay0":true,
         "memoryEnabled":false,"momentsEnabled":false,"quietHours":true,"notificationHour":9,"notificationMinute":0}
        """.utf8))
    }

    private func day(_ id: String, _ date: Date, recurring: Bool = false, lunar: Bool = false,
                     offsets: [Int]? = nil) -> Day {
        Day(id: id, title: id, date: date, recurring: recurring, lunar: lunar,
            category: .life, photo: .home, reminderOffsets: offsets)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        CNDate.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
