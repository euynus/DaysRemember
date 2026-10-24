import XCTest
@testable import DaysRemember

/// Within the 30-day retention for recently deleted days and sync versions.
private let recentDate = Date(timeIntervalSinceReferenceDate: (Date.now.timeIntervalSinceReferenceDate - 86400).rounded())

@MainActor
final class BackupRecoveryTests: XCTestCase {
    func testFreshInstallationIsEmptyWithoutWritingSampleData() throws {
        try withDefaults { defaults, _ in
            let store = DayStore(defaults: defaults)
            XCTAssertNil(store.loadError)
            XCTAssertTrue(store.days.isEmpty)
            XCTAssertTrue(store.deletedDays.isEmpty)
            XCTAssertEqual(store.categories, CategoryDefinition.system)
            XCTAssertFalse(store.hasRecoveryBackup)
            XCTAssertFalse(store.hasMigrationBackup)

            let exported = try DayBackup.decode(store.exportBackup())
            XCTAssertTrue(exported.days.isEmpty)
            XCTAssertTrue(exported.deletedDays.isEmpty)
            XCTAssertEqual(exported.categories, CategoryDefinition.system)
            for key in ["days.v1", "categories.v1", "deletedDays.v1"] {
                XCTAssertNil(defaults.object(forKey: key), key)
            }
        }
    }

    func testMigrationBackupIsDecidedOnceAndSkippedForAnEmptyLibrary() throws {
        try withDefaults { defaults, _ in
            let fresh = DayStore(defaults: defaults)
            try fresh.keepMigrationBackup()
            XCTAssertFalse(fresh.hasMigrationBackup)
            // Days added once CloudKit runs are not pre-migration data.
            XCTAssertTrue(fresh.add(day("Added after CloudKit started")))
            try DayStore(defaults: defaults).keepMigrationBackup()
            XCTAssertFalse(DayStore(defaults: defaults).hasMigrationBackup)
        }
        try withDefaults { defaults, _ in
            let original = backup()
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(original)
            try store.keepMigrationBackup()
            XCTAssertEqual(try DayBackup.decode(store.exportMigrationBackup()).days, original.days)
            store.delete(original.days[0])
            try store.keepMigrationBackup()
            XCTAssertEqual(try DayBackup.decode(store.exportMigrationBackup()).days, original.days)
        }
    }

    func testBackupRoundTripPreservesPhotosCategoriesAndTrashAfterRelaunch() throws {
        try withDefaults { defaults, _ in
            let original = backup()
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(DayBackup.decode(original.encoded()))

            let exported = try DayBackup.decode(store.exportBackup())
            XCTAssertEqual(exported.days, original.days)
            XCTAssertEqual(exported.categories, original.categories)
            XCTAssertEqual(exported.deletedDays, original.deletedDays)
            XCTAssertNotNil(exported.days.first?.photoData)
            XCTAssertEqual(exported.days.first?.photoData, original.days.first?.photoData)
            XCTAssertEqual(exported.deletedDays.first?.day.photoData, original.deletedDays.first?.day.photoData)
            assertLibrary(DayStore(defaults: defaults), matches: original)
        }
    }

    func testDeleteRestoreAndPermanentDeletePersistCurrentRecord() throws {
        try withDefaults { defaults, _ in
            let store = DayStore(defaults: defaults)
            let original = day("Original")
            store.add(original)
            var edited = original
            edited.title = "Edited before deletion"
            store.update(edited)
            store.delete(original)

            XCTAssertTrue(store.days.isEmpty)
            let deleted = try XCTUnwrap(store.deletedDays.first)
            XCTAssertEqual(deleted.day, edited)
            XCTAssertEqual(store.deletedDays.count, 1)
            let reloaded = DayStore(defaults: defaults)
            XCTAssertEqual(reloaded.deletedDays, [deleted])
            reloaded.restoreDeletedDay(id: original.id)
            XCTAssertEqual(reloaded.days, [edited])
            XCTAssertTrue(reloaded.deletedDays.isEmpty)
            XCTAssertEqual(DayStore(defaults: defaults).days, [edited])

            reloaded.delete(edited)
            reloaded.permanentlyDeleteDay(id: edited.id)
            reloaded.restoreDeletedDay(id: edited.id)
            let final = DayStore(defaults: defaults)
            XCTAssertNil(final.loadError)
            XCTAssertTrue(final.days.isEmpty)
            XCTAssertTrue(final.deletedDays.isEmpty)
        }
    }

    func testInvalidAndDuplicateBackupImportsLeaveAllStoredValuesUnchanged() throws {
        try withDefaults { defaults, suite in
            let original = backup()
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(original)
            let before = persisted(defaults, suite: suite)
            var blankTitle = original
            blankTitle.days[0].title = " \n"
            var duplicateDays = original
            duplicateDays.days.append(original.days[0])
            var duplicateCategories = original
            duplicateCategories.categories.append(original.categories[0])
            var duplicateTrash = original
            duplicateTrash.deletedDays.append(original.deletedDays[0])
            var activeInTrash = original
            activeInTrash.deletedDays.append(DeletedDay(day: original.days[0], deletedAt: original.createdAt))
            var unsupported = original
            unsupported.version = 99

            for invalid in [blankTitle, duplicateDays, duplicateCategories, duplicateTrash, activeInTrash, unsupported] {
                let data = try JSONEncoder().encode(invalid)
                XCTAssertThrowsError(try store.restoreBackup(DayBackup.decode(data)))
                XCTAssertThrowsError(try store.restoreBackup(invalid))
                XCTAssertEqual(persisted(defaults, suite: suite), before)
                assertLibrary(store, matches: original)
            }
            XCTAssertThrowsError(try store.restoreBackup(DayBackup.decode(Data("not JSON".utf8))))
            XCTAssertEqual(persisted(defaults, suite: suite), before)
            assertLibrary(DayStore(defaults: defaults), matches: original)
        }
    }

    func testCorruptDataIsPreservedUntilExplicitRecoveryAndRemainsExportable() throws {
        for key in ["days.v1", "categories.v1", "deletedDays.v1", "syncConflicts.v1", "pendingRestore.v1"] {
            try withDefaults { defaults, suite in
                let original = backup()
                try DayStore(defaults: defaults).restoreBackup(original)
                let corrupt = Data("corrupt \(key)".utf8)
                defaults.set(corrupt, forKey: key)
                let before = persisted(defaults, suite: suite)
                let store = DayStore(defaults: defaults)
                XCTAssertNotNil(store.loadError, key)
                XCTAssertThrowsError(try store.exportBackup())
                let raw = try JSONDecoder().decode([String: Data].self, from: store.exportOriginalData())
                XCTAssertEqual(raw[key], corrupt)

                store.add(day("Blocked addition"))
                store.delete(original.days[0])
                store.permanentlyDeleteDay(id: original.deletedDays[0].id)
                store.resetToSamples()
                store.save()
                store.saveCategories()
                XCTAssertEqual(persisted(defaults, suite: suite), before, key)

                try store.restoreBackup(original)
                assertLibrary(store, matches: original)
                let retained = try XCTUnwrap(defaults.data(forKey: "unreadableData.v1"))
                XCTAssertEqual(try JSONDecoder().decode([String: Data].self, from: retained), raw)
                assertLibrary(DayStore(defaults: defaults), matches: original)
            }
        }
    }

    /// Restoring over an unreadable library keeps its raw data rather than a recovery backup. That
    /// copy must stay reachable after the restore clears the error, and the older recovery backup,
    /// which the raw data contains, must not pose as the library just replaced.
    func testRestoreOverUnreadableLibraryKeepsReachableRawCopy() throws {
        try withDefaults { defaults, _ in
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(backup())
            try store.restoreBackup(backup())
            let staleRecovery = try XCTUnwrap(defaults.data(forKey: "recoveryBackup.v1"))
            defaults.set(Data("corrupt".utf8), forKey: "days.v1")
            let damaged = DayStore(defaults: defaults)
            XCTAssertNotNil(damaged.loadError)

            try damaged.restoreBackup(backup())
            XCTAssertNil(damaged.loadError)
            XCTAssertTrue(damaged.hasUnreadableDataCopy)
            XCTAssertFalse(damaged.hasRecoveryBackup)
            let raw = try JSONDecoder().decode([String: Data].self, from: damaged.exportUnreadableDataCopy())
            XCTAssertEqual(raw["days.v1"], Data("corrupt".utf8))
            XCTAssertEqual(raw["recoveryBackup.v1"], staleRecovery)
        }
    }

    /// Each raw copy replaces the last instead of containing it, and can be deleted.
    func testRawCopyDoesNotNestAndCanBeDeleted() throws {
        try withDefaults { defaults, _ in
            for _ in 0..<2 {
                defaults.set(Data("corrupt".utf8), forKey: "days.v1")
                try DayStore(defaults: defaults).restoreBackup(backup())
            }
            let store = DayStore(defaults: defaults)
            let raw = try JSONDecoder().decode([String: Data].self, from: store.exportUnreadableDataCopy())
            XCTAssertEqual(raw["days.v1"], Data("corrupt".utf8))
            XCTAssertNil(raw["unreadableData.v1"])

            store.deleteUnreadableDataCopy()
            XCTAssertFalse(store.hasUnreadableDataCopy)
            XCTAssertNil(try JSONDecoder().decode([String: Data].self, from: store.exportOriginalData())["unreadableData.v1"])
        }
    }

    /// 最近删除 and 同步保留版本 keep entries for 30 days; a restored backup's older entries expire.
    func testRestoreDropsEntriesPastRetention() throws {
        try withDefaults { defaults, _ in
            let expired = Date.now.addingTimeInterval(-40 * 24 * 60 * 60)
            var source = backup()
            let recent = source.deletedDays
            source.deletedDays.append(DeletedDay(day: day("Deleted long ago"), deletedAt: expired))
            source.syncConflicts = [SyncConflict(createdAt: expired, record: .day(day("Replaced long ago")))]
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(source)
            XCTAssertEqual(store.deletedDays, recent)
            XCTAssertTrue(store.syncConflicts.isEmpty)

            try store.restoreBackup(backup())
            try store.restorePreviousBackup()
            XCTAssertEqual(store.deletedDays, recent)
        }
    }

    /// An export over the import limit is refused as an export, with a way to make it smaller,
    /// not reported as a backup that can't be read.
    func testOversizedExportSaysTheExportWasRefused() throws {
        var large = backup()
        large.days[0].photoData = Data(count: 76 * 1024 * 1024)
        XCTAssertThrowsError(try large.encoded()) { error in
            XCTAssertEqual(error.localizedDescription,
                           "备份超过 100 MB，未能导出。清理「最近删除」和「同步保留版本」，或减少照片封面后再试。")
        }
        XCTAssertEqual(DayBackup.BackupError.tooLarge.localizedDescription, "备份超过 100 MB，无法读取。")
    }

    /// The date on the device's clock, not in UTC or Beijing.
    func testBackupFilenameUsesTheDevicesDate() throws {
        let moment = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-11T23:30:00Z"))
        XCTAssertEqual(DataManagementView.filename("时光备份", on: moment, in: try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))),
                       "时光备份-2026-10-12")
        XCTAssertEqual(DataManagementView.filename("时光备份", on: moment, in: try XCTUnwrap(TimeZone(identifier: "America/New_York"))),
                       "时光备份-2026-10-11")
    }

    func testPendingRestoreReplaysBeforeLoadingPartialDataAndOnlyOnce() throws {
        try withDefaults { defaults, suite in
            let target = backup()
            let recovery = try backup().encoded()
            defaults.set(try JSONEncoder().encode(target.days), forKey: "days.v1")
            defaults.set(Data("interrupted categories write".utf8), forKey: "categories.v1")
            defaults.set(try JSONEncoder().encode([DeletedDay]()), forKey: "deletedDays.v1")
            defaults.set(recovery, forKey: "recoveryBackup.v1")
            defaults.set(try target.encoded(), forKey: "pendingRestore.v1")

            assertLibrary(DayStore(defaults: defaults), matches: target)
            XCTAssertNil(defaults.object(forKey: "pendingRestore.v1"))
            XCTAssertEqual(defaults.data(forKey: "recoveryBackup.v1"), recovery)
            let afterReplay = persisted(defaults, suite: suite)
            assertLibrary(DayStore(defaults: defaults), matches: target)
            XCTAssertEqual(persisted(defaults, suite: suite), afterReplay)
        }
    }

    func testPreRestoreCopyCanRollBackAfterRelaunchAndPreservesReplacedLibrary() throws {
        try withDefaults { defaults, _ in
            let original = backup()
            let incoming = backup()
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(original)
            try store.restoreBackup(incoming)
            assertLibrary(store, matches: incoming)
            XCTAssertTrue(store.hasRecoveryBackup)

            let reloaded = DayStore(defaults: defaults)
            try reloaded.restorePreviousBackup()
            assertLibrary(reloaded, matches: original)
            assertLibrary(DayStore(defaults: defaults), matches: original)
            try reloaded.restorePreviousBackup()
            assertLibrary(reloaded, matches: incoming)
        }
    }

    func testCloudUpdateMergesByIDWithoutDeletingUnrelatedDaysOrCategories() throws {
        try withDefaults { defaults, _ in
            var original = backup()
            let unrelated = day("Unrelated local day")
            let deleted = day("Remotely deleted day")
            original.days += [unrelated, deleted]
            let deletedCategory = CategoryDefinition(id: "removed.\(UUID().uuidString)", name: "Removed",
                                                     icon: "tag", colorToken: .sage, isSystem: false)
            original.categories.append(deletedCategory)
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(original)
            var updated = original.days[0]
            updated.title = "Remote revision"
            let added = day("Remote addition")
            let addedCategory = CategoryDefinition(id: "remote.\(UUID().uuidString)", name: "Remote category",
                                                   icon: "tag", colorToken: .rose, isSystem: false)
            try store.applyCloudUpdate(CloudLibraryUpdate(
                upsertedDays: [updated, added], deletedDayIDs: [deleted.id],
                upsertedCategories: [addedCategory], deletedCategoryIDs: [deletedCategory.id]))

            XCTAssertEqual(store.days, [updated, unrelated, added])
            XCTAssertEqual(store.categories, original.categories.filter { $0.id != deletedCategory.id } + [addedCategory])
            XCTAssertEqual(store.deletedDays.first, original.deletedDays.first)
            XCTAssertEqual(store.deletedDays.map(\.day), original.deletedDays.map(\.day) + [deleted])
            let reloaded = DayStore(defaults: defaults)
            XCTAssertNil(reloaded.loadError)
            XCTAssertEqual(reloaded.days, store.days)
            XCTAssertEqual(reloaded.categories, store.categories)
            XCTAssertEqual(reloaded.deletedDays, store.deletedDays)
            let recovery = defaults.data(forKey: "recoveryBackup.v1")
            try reloaded.applyCloudUpdate(CloudLibraryUpdate())
            XCTAssertEqual(defaults.data(forKey: "recoveryBackup.v1"), recovery)
        }
    }

    func testCloudConflictsRetainRollbackCopyEvenWhenTheSameUpdateIsReplayed() throws {
        try withDefaults { defaults, _ in
            let original = backup()
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(original)
            var remoteDay = original.days[0]
            remoteDay.title = "Cloud winner"
            remoteDay.photoData = nil
            var remoteCategory = try XCTUnwrap(original.categories.last)
            remoteCategory.name = "Cloud category"
            let update = CloudLibraryUpdate(upsertedDays: [remoteDay], upsertedCategories: [remoteCategory],
                                            recoveryDays: original.days,
                                            recoveryCategories: [try XCTUnwrap(original.categories.last)])
            try store.applyCloudUpdate(update)
            XCTAssertEqual(store.days, [remoteDay])
            XCTAssertEqual(store.category(for: remoteCategory.id), remoteCategory)

            let reloaded = DayStore(defaults: defaults)
            try reloaded.applyCloudUpdate(update)
            try reloaded.restorePreviousBackup()
            assertLibrary(reloaded, matches: original)
        }
    }

    func testCloudConflictReplayCanRollBackNewerLocalEdits() throws {
        try withDefaults { defaults, _ in
            let original = backup()
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(original)
            var remoteDay = original.days[0]
            remoteDay.title = "Pending cloud winner"
            var remoteCategory = try XCTUnwrap(original.categories.last)
            remoteCategory.name = "Pending cloud category"
            let pending = CloudLibraryUpdate(upsertedDays: [remoteDay], upsertedCategories: [remoteCategory],
                                             recoveryDays: original.days,
                                             recoveryCategories: [try XCTUnwrap(original.categories.last)])

            // Local edits may arrive after a remote apply failed but before its retry.
            var newerCategory = try XCTUnwrap(original.categories.last)
            newerCategory.name = "Newer local category"
            store.updateCategory(newerCategory)
            var newerDay = original.days[0]
            newerDay.title = "Newer local title"
            newerDay.categoryLabel = newerCategory.name
            store.update(newerDay)
            try store.applyCloudUpdate(pending)
            XCTAssertEqual(store.days, [remoteDay])
            try store.restorePreviousBackup()
            XCTAssertEqual(store.days, [newerDay])
            XCTAssertEqual(store.category(for: newerCategory.id), newerCategory)
            // The local rename also renamed the category's day in 最近删除.
            let renamedTrash = original.deletedDays.map { entry in
                var day = entry.day
                if day.categoryID == newerCategory.id { day.categoryLabel = newerCategory.name }
                return DeletedDay(day: day, deletedAt: entry.deletedAt)
            }
            XCTAssertNotEqual(renamedTrash, original.deletedDays)
            XCTAssertEqual(store.deletedDays, renamedTrash)
        }
    }

    func testInvalidRemoteChangesAndRecoveryRecordsLeaveLocalValuesUnchanged() throws {
        try withDefaults { defaults, suite in
            let original = backup()
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(original)
            let before = persisted(defaults, suite: suite)
            let valid = day("Valid remote addition")
            var invalidDay = original.days[0]
            invalidDay.title = " \n"
            var invalidCategory = try XCTUnwrap(original.categories.last)
            invalidCategory.name = " \n"
            let updates = [
                CloudLibraryUpdate(upsertedDays: [valid, invalidDay]),
                CloudLibraryUpdate(deletedDayIDs: original.days.map(\.id), upsertedCategories: [invalidCategory]),
                CloudLibraryUpdate(upsertedDays: [valid], recoveryDays: [invalidDay]),
                CloudLibraryUpdate(upsertedDays: [valid], recoveryCategories: [invalidCategory])
            ]
            for update in updates {
                XCTAssertThrowsError(try store.applyCloudUpdate(update))
                XCTAssertEqual(persisted(defaults, suite: suite), before)
                assertLibrary(store, matches: original)
            }
            assertLibrary(DayStore(defaults: defaults), matches: original)
        }
    }

    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let suite = "BackupRecoveryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults, suite)
    }

    private func persisted(_ defaults: UserDefaults, suite: String) -> NSDictionary {
        (defaults.persistentDomain(forName: suite) ?? [:]) as NSDictionary
    }

    private func day(_ title: String) -> Day {
        Day(id: "backup-test.\(UUID().uuidString)", title: title,
            date: Date(timeIntervalSince1970: 1_700_000_000), category: .life, photo: .home)
    }

    private func backup() -> DayBackup {
        let category = CategoryDefinition(id: "backup-test.\(UUID().uuidString)", name: "Custom category",
                                          icon: "tag", colorToken: .dusty, isSystem: false)
        var active = day("Photo day")
        active.recurring = true
        active.lunar = true
        active.photoData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=")
        active.categoryID = category.id
        active.categoryLabel = category.name
        active.coverFocusX = 0.2
        active.coverFocusY = 0.8
        active.reminderOffsets = [7, 0]
        active.note = "Private note"
        active.location = "Home"
        active.pinned = true
        var deleted = active
        deleted.id = "backup-test.\(UUID().uuidString)"
        deleted.title = "Deleted photo day"
        return DayBackup(createdAt: active.date, days: [active], categories: CategoryDefinition.system + [category],
                         deletedDays: [DeletedDay(day: deleted, deletedAt: recentDate)])
    }

    private func assertLibrary(_ store: DayStore, matches expected: DayBackup,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(store.loadError, file: file, line: line)
        XCTAssertEqual(store.days, expected.days, file: file, line: line)
        XCTAssertEqual(store.categories, expected.categories, file: file, line: line)
        XCTAssertEqual(store.deletedDays, expected.deletedDays, file: file, line: line)
    }
}
