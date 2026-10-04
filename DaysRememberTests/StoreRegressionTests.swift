import XCTest
@testable import DaysRemember

@MainActor
final class StoreRegressionTests: XCTestCase {
    private func withRestoredDefaults(_ body: () throws -> Void) rethrows {
        let shared = SharedStorage.defaults
        let standard = UserDefaults.standard
        let sharedKeys = ["days.v1", "days.v2", "categories.v1", "icloud.localTimestamp.icloud.days.v1",
                          "icloud.localTimestamp.icloud.categories.v1", "icloud.localTimestamp.icloud.settings.v1"]
        let settingsKeys = ["hasOnboarded", "notif.pre7", "notif.pre3", "notif.pre1", "notif.day0",
                            "notif.memory", "notif.moments", "notif.quiet", "notif.hour", "notif.minute"]
        let savedShared = sharedKeys.map { ($0, shared.object(forKey: $0)) }
        let savedSettings = settingsKeys.map { ($0, standard.object(forKey: $0)) }
        defer {
            for (key, value) in savedShared { shared.set(value, forKey: key) }
            for (key, value) in savedSettings { standard.set(value, forKey: key) }
        }
        try body()
    }

    func testUnknownCategorySurvivesAddAndUpdateUntilDefinitionArrives() throws {
        try withRestoredDefaults {
            let store = DayStore()
            store.days = []
            store.categories = CategoryDefinition.system
            var day = Day(id: "unresolved", title: "test", date: Date(), category: .travel,
                          photo: .home, categoryID: "custom.pending", categoryLabel: "Remote label")
            day.coverFocusX = -2
            day.coverFocusY = 3
            store.add(day)

            var saved = try XCTUnwrap(store.days.first)
            XCTAssertEqual(saved.categoryID, day.categoryID)
            XCTAssertEqual(saved.categoryLabel, "Remote label")
            XCTAssertEqual(saved.category, .travel)
            XCTAssertEqual(saved.coverFocusX, 0)
            XCTAssertEqual(saved.coverFocusY, 1)
            saved.title = "edited"
            store.update(saved)
            let persisted = SharedStorage.loadDays()
            XCTAssertEqual(persisted.first?.categoryID, day.categoryID)
            XCTAssertEqual(persisted.first?.categoryLabel, "Remote label")

            store.categories.append(CategoryDefinition(id: day.categoryID, name: "Resolved label",
                                                        icon: "tag", colorToken: .dusty, isSystem: false))
            store.update(saved)
            XCTAssertEqual(store.days.first?.categoryID, day.categoryID)
            XCTAssertEqual(store.days.first?.categoryLabel, "Resolved label")
            XCTAssertEqual(store.days.first?.category, .life)
        }
    }

    func testCategoryAppearanceDoesNotPersistDaysButRenameDoes() {
        withRestoredDefaults {
            let store = DayStore()
            store.days = []
            var category = store.addCategory(name: "Original", icon: "tag", colorToken: .dusty)
            store.add(Day(id: "member", title: "test", date: Date(), category: .life,
                          photo: .home, categoryID: category.id))
            let persisted = SharedStorage.defaults.data(forKey: "days.v2")

            category.icon = "star"
            category.colorToken = .sage
            store.updateCategory(category)
            XCTAssertEqual(store.category(for: category.id).icon, "star")
            XCTAssertEqual(store.category(for: category.id).colorToken, .sage)
            XCTAssertEqual(SharedStorage.defaults.data(forKey: "days.v2"), persisted)

            category.name = "Renamed"
            store.updateCategory(category)
            XCTAssertEqual(store.days.first?.categoryLabel, "Renamed")
            XCTAssertNotEqual(SharedStorage.defaults.data(forKey: "days.v2"), persisted)
        }
    }

    func testRenamingUnusedCategoryDoesNotPersistDays() {
        withRestoredDefaults {
            let store = DayStore()
            store.days = []
            var category = store.addCategory(name: "Unused", icon: "tag", colorToken: .dusty)
            let persisted = SharedStorage.defaults.data(forKey: "days.v2")
            category.name = "Renamed"
            store.updateCategory(category)
            XCTAssertEqual(store.category(for: category.id).name, "Renamed")
            XCTAssertEqual(SharedStorage.defaults.data(forKey: "days.v2"), persisted)
        }
    }

    func testMemoryAndMomentsDefaultOffAndPreserveOptInAfterReload() {
        withRestoredDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "notif.memory")
            defaults.removeObject(forKey: "notif.moments")
            let settings = AppSettings()
            XCTAssertFalse(settings.memoryEnabled)
            XCTAssertFalse(settings.momentsEnabled)

            settings.memoryEnabled = true
            settings.momentsEnabled = true
            let reloaded = AppSettings()
            XCTAssertTrue(reloaded.memoryEnabled)
            XCTAssertTrue(reloaded.momentsEnabled)
        }
    }

    func testLocalSettingIsTimestampedImmediatelyAndRejectsOlderRemote() {
        withRestoredDefaults {
            let settings = AppSettings()
            let oldSnapshot = AppSettingsSnapshot(settings: settings)
            let cloud = ICloudSyncStore.shared
            cloud.noteLocalWrite(for: ICloudSyncStore.Key.settings, updatedAt: 1)

            settings.notifPre7.toggle()
            let localTimestamp = cloud.localTimestamp(for: ICloudSyncStore.Key.settings)
            XCTAssertGreaterThan(localTimestamp, 1)
            XCTAssertFalse(settings.applyRemoteSettingsIfNewer(.init(
                value: oldSnapshot, updatedAt: localTimestamp - 1, deviceID: "remote")))
            XCTAssertEqual(settings.notifPre7, !oldSnapshot.notifPre7)
            XCTAssertEqual(cloud.localTimestamp(for: ICloudSyncStore.Key.settings), localTimestamp)
        }
    }

    func testNewerRemoteSettingsPreserveRemoteTimestampAndRejectEqualVersion() {
        withRestoredDefaults {
            let settings = AppSettings()
            settings.notifPre7.toggle()
            let cloud = ICloudSyncStore.shared
            let timestamp = cloud.localTimestamp(for: ICloudSyncStore.Key.settings) + 1
            var remote = AppSettingsSnapshot(settings: settings)
            remote.notifPre7.toggle()
            remote.notificationHour = 99
            remote.notificationMinute = -1

            XCTAssertTrue(settings.applyRemoteSettingsIfNewer(.init(
                value: remote, updatedAt: timestamp, deviceID: "remote")))
            XCTAssertEqual(settings.notifPre7, remote.notifPre7)
            XCTAssertEqual(settings.notificationHour, 23)
            XCTAssertEqual(settings.notificationMinute, 0)
            XCTAssertEqual(cloud.localTimestamp(for: ICloudSyncStore.Key.settings), timestamp)
            remote.notifPre7.toggle()
            XCTAssertFalse(settings.applyRemoteSettingsIfNewer(.init(
                value: remote, updatedAt: timestamp, deviceID: "remote")))
            XCTAssertEqual(settings.notifPre7, !remote.notifPre7)
        }
    }
}
