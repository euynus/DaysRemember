import XCTest
@testable import DaysRemember

@MainActor
final class StoreRegressionTests: XCTestCase {
    private func withRestoredDefaults(_ body: () throws -> Void) rethrows {
        let standard = UserDefaults.standard
        let sharedKeys = ["days.v2", "categories.v1", "deletedDays.v1", "syncConflicts.v1",
                          "pendingRestore.v1", "icloud.localTimestamp.icloud.settings.v1"]
        let settingsKeys = ["hasOnboarded", "notif.pre7", "notif.pre3", "notif.pre1", "notif.day0",
                            "notif.memory", "notif.moments", "notif.hour", "notif.minute",
                            "notif.greeting.hour", "notif.greeting.minute"]
        let savedShared = SharedLibrarySnapshot(keys: sharedKeys)
        let savedSettings = settingsKeys.map { ($0, standard.object(forKey: $0)) }
        defer {
            savedShared.restore()
            for (key, value) in savedSettings { standard.set(value, forKey: key) }
        }
        try body()
    }

    private func withSuite(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "StoreRegressionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    /// An unreadable library loads as empty; syncing that would cancel every pending reminder.
    func testUnreadableLibraryLeavesRemindersAlone() throws {
        try withSuite { defaults in
            defaults.set(Data("corrupt".utf8), forKey: "days.v1")
            let store = DayStore(defaults: defaults)
            XCTAssertNotNil(store.loadError)
            store.settings = AppSettings()
            store.rescheduleNotifications()
            XCTAssertNil(store.rescheduleTask)

            try store.restoreBackup(DayBackup(days: [], categories: CategoryDefinition.system, deletedDays: []))
            XCTAssertNotNil(store.rescheduleTask, "a restored library schedules its reminders again")
        }
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

    /// A category deleted on another device while its editor is open can't be changed here; the
    /// store says so, so the editor can keep the draft instead of reporting success.
    func testChangingACategoryDeletedElsewhereReportsFailure() throws {
        try withSuite { defaults in
            let store = DayStore(defaults: defaults)
            let gone = store.addCategory(name: "Gone", icon: "tag", colorToken: .dusty)
            var kept = store.addCategory(name: "Kept", icon: "tag", colorToken: .sage)
            try store.applyCloudUpdate(CloudLibraryUpdate(deletedCategoryIDs: [gone.id]))
            var renamed = gone
            renamed.name = "Renamed"
            XCTAssertFalse(store.updateCategory(renamed))
            XCTAssertFalse(store.deleteCategory(id: gone.id, migrateTo: DayCategory.life.rawValue))

            kept.name = "Kept and renamed"
            XCTAssertTrue(store.updateCategory(kept))
            XCTAssertTrue(store.deleteCategory(id: kept.id, migrateTo: DayCategory.life.rawValue))
        }
    }

    /// Copies in 最近删除 and 同步保留版本 move with the category's days, or a restored copy
    /// would point at a category that no longer exists.
    func testDeletingCategoryMovesRecoverableCopies() throws {
        try withSuite { defaults in
            let store = DayStore(defaults: defaults)
            let category = store.addCategory(name: "Trips", icon: "tag", colorToken: .dusty)
            let trashed = Day(id: "trashed", title: "Trashed", date: Date(), category: .life,
                              photo: .home, categoryID: category.id)
            let replaced = Day(id: "replaced", title: "Replaced", date: Date(), category: .life,
                               photo: .home, categoryID: category.id)
            try store.restoreBackup(DayBackup(days: [], categories: store.categories,
                                              deletedDays: [DeletedDay(day: trashed, deletedAt: .now)],
                                              syncConflicts: [SyncConflict(record: .day(replaced))]))

            store.deleteCategory(id: category.id, migrateTo: DayCategory.travel.rawValue)
            XCTAssertEqual(store.deletedDays.map(\.day.categoryID), [DayCategory.travel.rawValue])
            guard case .day(let kept) = store.syncConflicts.first?.record else { return XCTFail("conflict kept") }
            XCTAssertEqual(kept.categoryID, DayCategory.travel.rawValue)
            XCTAssertEqual(kept.category, .travel)

            store.restoreDeletedDay(id: "trashed")
            XCTAssertEqual(store.days(in: DayCategory.travel.rawValue).map(\.id), ["trashed"])
            XCTAssertEqual(DayStore(defaults: defaults).deletedDays, store.deletedDays)
        }
    }

    /// An editor opened before a sync saves onto the synced day: what it left alone keeps the synced
    /// value, and where both changed the same thing its edit wins with the replaced version kept.
    func testEditorSaveMergesWithChangesThatSyncedMeanwhile() throws {
        try withSuite { defaults in
            let store = DayStore(defaults: defaults)
            let base = Day(id: "shared", title: "Trip", date: Date(timeIntervalSince1970: 1_700_000_000),
                           category: .travel, photo: .voyage, note: "Pack light")
            store.add(base)
            @MainActor func sync(_ change: (inout Day) -> Void) throws {
                var remote = try XCTUnwrap(store.days.first)
                change(&remote)
                try store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remote]))
            }

            // Another device changes the note while this one edits only the title.
            try sync { $0.note = "Bring the passport" }
            let keptBySync = store.syncConflicts.count
            var titled = base
            titled.title = "Trip to Hokkaido"
            XCTAssertTrue(store.update(titled, editedFrom: base))
            XCTAssertEqual(store.days.first?.title, "Trip to Hokkaido")
            XCTAssertEqual(store.days.first?.note, "Bring the passport")
            XCTAssertEqual(store.syncConflicts.count, keptBySync, "nothing was overwritten")

            // Both change the note: the edit wins and the synced note stays restorable.
            let opened = try XCTUnwrap(store.days.first)
            try sync { $0.note = "Book the ryokan" }
            var noted = opened
            noted.note = "Take the night train"
            XCTAssertTrue(store.update(noted, editedFrom: opened))
            XCTAssertEqual(store.days.first?.note, "Take the night train")
            XCTAssertTrue(store.syncConflicts.contains { conflict in
                if case .day(let day) = conflict.record { return day.note == "Book the ryokan" }
                return false
            })
            XCTAssertEqual(DayStore(defaults: defaults).days.first?.note, "Take the night train")

            // A date belongs with its calendar: a synced switch to lunar doesn't pair with an edited date.
            let beforeDate = try XCTUnwrap(store.days.first)
            try sync { $0.lunar = true }
            var dated = beforeDate
            dated.date = Date(timeIntervalSince1970: 1_710_000_000)
            XCTAssertTrue(store.update(dated, editedFrom: beforeDate))
            XCTAssertEqual(store.days.first?.date, dated.date)
            XCTAssertEqual(store.days.first?.lunar, false)

            // With nothing synced meanwhile it is an ordinary update.
            let unchanged = try XCTUnwrap(store.days.first)
            var retitled = unchanged
            retitled.title = "Hokkaido"
            let conflicts = store.syncConflicts
            XCTAssertTrue(store.update(retitled, editedFrom: unchanged))
            XCTAssertEqual(store.days.first, retitled)
            XCTAssertEqual(store.syncConflicts, conflicts)
        }
    }

    /// Renaming a category renames it on the copies in 最近删除 and 同步保留版本 too, so a
    /// restored copy comes back under the current name.
    func testRenamingCategoryRelabelsRecoverableCopies() throws {
        try withSuite { defaults in
            let store = DayStore(defaults: defaults)
            var category = store.addCategory(name: "Trips", icon: "tag", colorToken: .dusty)
            let trashed = Day(id: "trashed", title: "Trashed", date: Date(), category: .life,
                              photo: .home, categoryID: category.id, categoryLabel: "Trips")
            let replaced = Day(id: "replaced", title: "Replaced", date: Date(), category: .life,
                               photo: .home, categoryID: category.id, categoryLabel: "Trips")
            try store.restoreBackup(DayBackup(days: [], categories: store.categories,
                                              deletedDays: [DeletedDay(day: trashed, deletedAt: .now)],
                                              syncConflicts: [SyncConflict(record: .day(replaced))]))

            category.name = "Trip plans"
            XCTAssertTrue(store.updateCategory(category))
            XCTAssertEqual(store.deletedDays.map(\.day.categoryLabel), ["Trip plans"])
            guard case .day(let kept) = store.syncConflicts.first?.record else { return XCTFail("conflict kept") }
            XCTAssertEqual(kept.categoryLabel, "Trip plans")
            XCTAssertEqual(DayStore(defaults: defaults).deletedDays, store.deletedDays)

            try store.restoreSyncConflict(id: try XCTUnwrap(store.syncConflicts.first).id)
            XCTAssertEqual(store.days.first(where: { $0.id == "replaced" })?.categoryLabel, "Trip plans")
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

    /// Finishing onboarding is not a settings edit. On a new device it would stamp the defaults as
    /// newer than the account's own settings, which haven't downloaded yet, and push them.
    func testFinishingOnboardingLeavesTheSettingsTimestampAlone() {
        withRestoredDefaults {
            let cloud = ICloudSyncStore.shared
            cloud.noteLocalWrite(for: ICloudSyncStore.Key.settings, updatedAt: 0)
            UserDefaults.standard.removeObject(forKey: "hasOnboarded")
            let settings = AppSettings()
            settings.hasOnboarded = true
            XCTAssertEqual(cloud.localTimestamp(for: ICloudSyncStore.Key.settings), 0)

            var account = AppSettingsSnapshot(settings: settings)
            account.notificationHour = 21
            account.hasOnboarded = false
            XCTAssertTrue(settings.applyRemoteSettingsIfNewer(.init(value: account, updatedAt: 1000, deviceID: "other")))
            XCTAssertEqual(settings.notificationHour, 21)
            XCTAssertTrue(settings.hasOnboarded, "a synced snapshot never brings onboarding back")
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
