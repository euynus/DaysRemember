import CloudKit
import XCTest
@testable import DaysRemember

@MainActor
final class DayReminderTests: XCTestCase {
    func testMultipleOffsetsUseOverrideTimeWithoutDuplicateRequests() throws {
        let event = day("event", date(2026, 7, 20), offsets: [0, 7, 3, 7, 0, 3],
                        time: DayReminderTime(hour: 14, minute: 35))
        let plan = NotificationManager.plan(days: [event], settings: try settings(), now: date(2026, 7, 1))

        XCTAssertEqual(plan.map(\.date), [date(2026, 7, 13, 14, 35), date(2026, 7, 17, 14, 35),
                                          date(2026, 7, 20, 14, 35)])
        XCTAssertEqual(Set(plan.map(\.id)).count, 3)
        XCTAssertTrue(plan.allSatisfy { $0.dayID == event.id && !$0.repeats })
    }

    func testNilTimeInheritsGlobalTimeForOrdinaryAndMemoryReminders() throws {
        var config = try settings()
        config.memoryEnabled = true
        let event = day("event", date(2026, 7, 20), offsets: [3, 0])
        let memory = day("memory", date(2020, 7, 22))
        let plan = NotificationManager.plan(days: [event, memory], settings: config, now: date(2026, 7, 1))

        XCTAssertEqual(plan.filter { $0.dayID == event.id }.map(\.date),
                       [date(2026, 7, 17, 9), date(2026, 7, 20, 9)])
        let memories = plan.filter { $0.dayID == memory.id }
        XCTAssertEqual(memories.map(\.date), (2026...2030).map { date($0, 7, 22, 9) })
        XCTAssertTrue(memories.allSatisfy { $0.id.hasPrefix("dr.memory.") })
    }

    func testLateOverrideTimeAppliesToOrdinaryRemindersAndAnnualMemories() throws {
        var config = try settings()
        config.memoryEnabled = true
        let time = DayReminderTime(hour: 23, minute: 15)
        let event = day("event", date(2026, 7, 20), offsets: [0], time: time)
        let memory = day("memory", date(2020, 7, 20), offsets: [0], time: time)
        let plan = NotificationManager.plan(days: [event, memory], settings: config, now: date(2026, 7, 1))

        XCTAssertEqual(plan.filter { $0.dayID == event.id }.map(\.date), [date(2026, 7, 20, 23, 15)])
        let memories = plan.filter { $0.dayID == memory.id }
        XCTAssertEqual(memories.map(\.date), (2026...2030).map { date($0, 7, 20, 23, 15) })
        XCTAssertTrue(memories.allSatisfy { $0.id.hasPrefix("dr.memory.") && !$0.repeats })
    }

    func testEmptyOffsetsRemainOptedOutDespiteTimeOverrideAndMemories() throws {
        var config = try settings()
        config.notifPre7 = true
        config.notifPre3 = true
        config.notifPre1 = true
        config.memoryEnabled = true
        let time = DayReminderTime(hour: 14, minute: 35)
        let event = day("event", date(2026, 7, 20), offsets: [], time: time)
        let memory = day("memory", date(2020, 7, 20), offsets: [], time: time)
        let annual = day("annual", date(2020, 7, 20), recurring: true, offsets: [], time: time)

        XCTAssertTrue(NotificationManager.plan(days: [event, memory, annual], settings: config,
                                               now: date(2026, 7, 1)).isEmpty)
        var inherited = event
        inherited.reminderOffsets = nil
        XCTAssertEqual(NotificationManager.plan(days: [inherited], settings: config,
                                                now: date(2026, 7, 1)).count, 4)
    }

    func testInvalidReminderTimeJSONIsRejectedAloneAndInsideDay() throws {
        for (hour, minute) in [(-1, 35), (24, 35), (14, -1), (14, 60)] {
            let time = ["hour": hour, "minute": minute]
            let timeJSON = try JSONSerialization.data(withJSONObject: time)
            XCTAssertThrowsError(try JSONDecoder().decode(DayReminderTime.self, from: timeJSON),
                                 "Invalid time: \(hour):\(minute)")
            let dayJSON = try JSONSerialization.data(withJSONObject: [
                "id": "invalid", "title": "Invalid", "date": 0, "reminderTime": time
            ] as [String: Any])
            XCTAssertThrowsError(try JSONDecoder().decode(Day.self, from: dayJSON),
                                 "Invalid nested time: \(hour):\(minute)")
        }
    }

    func testConstructedInvalidTimesFailValidationAndAreExcludedFromPlanning() throws {
        var config = try settings()
        config.memoryEnabled = true
        let valid = day("valid", date(2026, 7, 20), offsets: [0], time: DayReminderTime(hour: 14, minute: 35))

        for time in [DayReminderTime(hour: 24, minute: 35), DayReminderTime(hour: 14, minute: 60)] {
            XCTAssertFalse(time.isValid)
            let event = day("invalid", date(2026, 7, 20), offsets: [0], time: time)
            let memory = day("invalid-memory", date(2020, 7, 20), offsets: [0], time: time)
            XCTAssertThrowsError(try DayBackup.validateDays([event])) { error in
                guard case DayBackup.BackupError.invalidRecords = error else {
                    return XCTFail("Unexpected validation error: \(error)")
                }
            }
            XCTAssertThrowsError(try JSONEncoder().encode(event))
            let plan = NotificationManager.plan(days: [event, memory, valid], settings: config, now: date(2026, 7, 1))
            XCTAssertEqual(plan.map(\.dayID), [valid.id])
            XCTAssertEqual(plan.map(\.date), [date(2026, 7, 20, 14, 35)])
        }
    }

    func testLegacyDayJSONWithoutReminderTimeDecodesNil() throws {
        let json = Data("""
        {"id":"legacy","title":"Legacy day","date":0,"reminderOffsets":[7,3,0]}
        """.utf8)
        let decoded = try JSONDecoder().decode(Day.self, from: json)

        XCTAssertEqual(decoded.id, "legacy")
        XCTAssertEqual(decoded.reminderOffsets, [7, 3, 0])
        XCTAssertNil(decoded.reminderTime)
    }

    func testBackupAndFileBackedRelaunchPreserveRemindersAndPersistResetToNil() throws {
        let suite = "DayReminderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        try withDirectory { directory in
            let photos = directory.appendingPathComponent("photos", isDirectory: true)
            var original = day("stored", date(2026, 7, 20), offsets: [7, 3, 0],
                               time: DayReminderTime(hour: 14, minute: 35))
            original.photoData = Data([1, 2, 3])
            let backup = DayBackup(createdAt: date(2026, 7, 1), days: [original],
                                   categories: CategoryDefinition.system, deletedDays: [])
            let decoded = try DayBackup.decode(backup.encoded())
            XCTAssertEqual(decoded.days, [original])

            let store = DayStore(defaults: defaults, photoDirectory: photos)
            try store.restoreBackup(decoded)
            XCTAssertNil(store.loadError)
            let metadata = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            let records = try XCTUnwrap(JSONSerialization.jsonObject(with: metadata) as? [[String: Any]])
            let record = try XCTUnwrap(records.first)
            let photoFile = try XCTUnwrap(record["photoFile"] as? String)
            XCTAssertNil(record["photoData"])
            XCTAssertEqual(try Data(contentsOf: photos.appendingPathComponent(photoFile)), original.photoData)

            let relaunched = DayStore(defaults: defaults, photoDirectory: photos)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, [original])
            XCTAssertEqual(try DayBackup.decode(relaunched.exportBackup()).days, [original])

            var reset = try XCTUnwrap(relaunched.days.first)
            reset.reminderOffsets = nil
            reset.reminderTime = nil
            relaunched.update(reset)
            XCTAssertNil(relaunched.loadError)
            let afterReset = DayStore(defaults: defaults, photoDirectory: photos)
            XCTAssertNil(afterReset.loadError)
            XCTAssertEqual(afterReset.days, [reset])
            XCTAssertNil(afterReset.days.first?.reminderOffsets)
            XCTAssertNil(afterReset.days.first?.reminderTime)
            XCTAssertEqual(try DayBackup.decode(afterReset.exportBackup()).days, [reset])
        }
    }

    func testCloudMetadataAndAssetRoundTripPreserveTimeAndFingerprintTracksTimeChanges() throws {
        try withDirectory { directory in
            var original = day("cloud", date(2026, 7, 20), offsets: [7, 3, 0],
                               time: DayReminderTime(hour: 14, minute: 35))
            original.photoData = Data([4, 5, 6])
            let value = CloudLibraryRecord.day(original)
            let record = try value.makeRecord(systemFields: nil, revision: UUID().uuidString, assetDirectory: directory)
            let payload = try XCTUnwrap(record["payload"] as? Data)
            let metadata = try JSONDecoder().decode(Day.self, from: payload)
            XCTAssertEqual(metadata.reminderOffsets, original.reminderOffsets)
            XCTAssertEqual(metadata.reminderTime, original.reminderTime)
            XCTAssertNil(metadata.photoData)
            let assetURL = try XCTUnwrap((record["photo"] as? CKAsset)?.fileURL)
            XCTAssertEqual(try Data(contentsOf: assetURL), original.photoData)
            let decoded = try CloudLibraryRecord.decode(record)
            XCTAssertEqual(decoded, value)

            let fingerprint = try value.fingerprint()
            XCTAssertEqual(try decoded.fingerprint(), fingerprint)
            var edited = original
            edited.reminderTime = DayReminderTime(hour: 14, minute: 36)
            XCTAssertEqual(CloudLibraryRecord.day(edited).recordID, value.recordID)
            XCTAssertNotEqual(try CloudLibraryRecord.day(edited).fingerprint(), fingerprint)
            edited.reminderTime = nil
            XCTAssertNotEqual(try CloudLibraryRecord.day(edited).fingerprint(), fingerprint)
        }
    }

    private func settings() throws -> AppSettingsSnapshot {
        try JSONDecoder().decode(AppSettingsSnapshot.self, from: Data("""
        {"hasOnboarded":true,"notifPre7":false,"notifPre3":false,"notifPre1":false,"notifDay0":true,
         "memoryEnabled":false,"momentsEnabled":false,"quietHours":true,"notificationHour":9,"notificationMinute":0}
        """.utf8))
    }

    private func day(_ id: String, _ date: Date, recurring: Bool = false, offsets: [Int]? = nil,
                     time: DayReminderTime? = nil) -> Day {
        Day(id: id, title: id, date: date, recurring: recurring, category: .life, photo: .home,
            reminderOffsets: offsets, reminderTime: time)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        CNDate.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try body(directory)
    }
}
