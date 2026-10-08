import XCTest
@testable import DaysRemember

/// Within the 30-day retention for recently deleted days and sync versions.
private let recentDate = Date(timeIntervalSinceReferenceDate: (Date.now.timeIntervalSinceReferenceDate - 86400).rounded())

@MainActor
final class SyncConflictTests: XCTestCase {
    func testConflictSurvivesUnrelatedCloudAdditionAndRelaunchRestoringOnlyItsDay() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let localA = day("A")
            store.add(localA)
            var remoteA = localA
            remoteA.title = "Cloud winner A"
            remoteA.photoData = nil
            remoteA.note = "Cloud note"
            try store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remoteA], recoveryDays: [localA]))
            XCTAssertEqual(store.days, [remoteA])
            XCTAssertEqual(store.syncConflicts.count, 1)
            let conflict = try XCTUnwrap(store.syncConflicts.first)
            XCTAssertEqual(conflict.record, .day(localA))

            let remoteB = day("B", note: "Unrelated cloud addition", photo: Data([9, 8, 7]))
            try store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remoteB]))
            let relaunched = DayStore(defaults: defaults)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, [remoteA, remoteB])
            XCTAssertEqual(relaunched.syncConflicts, [conflict])
            guard case .day(let retainedA) = try XCTUnwrap(relaunched.syncConflicts.first).record else {
                return XCTFail("Expected a recoverable day")
            }
            XCTAssertEqual(retainedA.photoData, localA.photoData)
            XCTAssertEqual(retainedA.note, localA.note)

            try relaunched.restoreSyncConflict(id: conflict.id)
            XCTAssertEqual(relaunched.days, [localA, remoteB])
            XCTAssertTrue(relaunched.syncConflicts.isEmpty)
            let restored = DayStore(defaults: defaults)
            XCTAssertNil(restored.loadError)
            XCTAssertEqual(restored.days, [localA, remoteB])
            XCTAssertTrue(restored.syncConflicts.isEmpty)
        }
    }

    func testSameDayIDRetainsDistinctNoteAndPhotoVersionsAndRestoresOnlySelectedVersion() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let original = day("same-id")
            var noteRevision = original
            noteRevision.note = "Later private note"
            var photoRevision = noteRevision
            photoRevision.photoData = Data([4, 5, 6])
            let versions = [original, noteRevision, photoRevision]
            var remote = original
            remote.note = "Cloud winner"
            remote.photoData = nil
            store.add(original)

            for version in versions {
                store.update(version)
                try store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remote], recoveryDays: [version]))
            }
            XCTAssertEqual(store.syncConflicts.count, versions.count)
            XCTAssertEqual(Set(store.syncConflicts.map(\.id)).count, versions.count)
            for version in versions {
                XCTAssertEqual(store.syncConflicts.filter { $0.record == .day(version) }.count, 1)
            }

            let relaunched = DayStore(defaults: defaults)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.syncConflicts, store.syncConflicts)
            let selected = try XCTUnwrap(relaunched.syncConflicts.first { $0.record == .day(original) })
            let remaining = relaunched.syncConflicts.filter { $0.id != selected.id }
            try relaunched.restoreSyncConflict(id: selected.id)
            XCTAssertEqual(relaunched.days, [original])
            XCTAssertEqual(relaunched.syncConflicts, remaining)
            XCTAssertEqual(remaining.count, 2)
            let restored = DayStore(defaults: defaults)
            XCTAssertNil(restored.loadError)
            XCTAssertEqual(restored.days, [original])
            XCTAssertEqual(restored.syncConflicts, remaining)
        }
    }

    func testPendingUpdateReplayDoesNotDuplicateDayOrCategoryConflicts() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let local = day("pending")
            let category = CategoryDefinition(id: "custom.pending", name: "Local category",
                                              icon: "tag", colorToken: .sage, isSystem: false)
            try store.restoreBackup(DayBackup(days: [local], categories: CategoryDefinition.system + [category],
                                              deletedDays: []))
            var remote = local
            remote.note = "Cloud note"
            remote.photoData = nil
            var remoteCategory = category
            remoteCategory.name = "Cloud category"
            let pending = CloudLibraryUpdate(upsertedDays: [remote], upsertedCategories: [remoteCategory],
                                             recoveryDays: [local], recoveryCategories: [category])
            try store.applyCloudUpdate(pending)
            let conflicts = store.syncConflicts
            XCTAssertEqual(conflicts.count, 2)
            XCTAssertTrue(conflicts.contains { $0.record == .day(local) })
            XCTAssertTrue(conflicts.contains { $0.record == .category(category) })
            try store.applyCloudUpdate(pending)
            XCTAssertEqual(store.syncConflicts, conflicts)

            let relaunched = DayStore(defaults: defaults)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.syncConflicts, conflicts)
            try relaunched.applyCloudUpdate(pending)
            XCTAssertEqual(relaunched.syncConflicts, conflicts)
            XCTAssertEqual(relaunched.days, [remote])
            XCTAssertEqual(relaunched.categories, CategoryDefinition.system + [remoteCategory])
            XCTAssertEqual(DayStore(defaults: defaults).syncConflicts, conflicts)
        }
    }

    func testPendingReplayPreservesNewerLocalEditAlongsideOriginalConflict() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let original = day("pending-edit")
            store.add(original)
            var remote = original
            remote.note = "Pending cloud winner"
            remote.photoData = nil
            let pending = CloudLibraryUpdate(upsertedDays: [remote], recoveryDays: [original])
            try store.applyCloudUpdate(pending)
            let originalConflict = try XCTUnwrap(store.syncConflicts.first)

            var newer = original
            newer.note = "Edited while delivery was pending"
            newer.photoData = Data([7, 8, 9])
            store.update(newer)
            let relaunched = DayStore(defaults: defaults)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, [newer])
            try relaunched.applyCloudUpdate(pending)
            XCTAssertEqual(relaunched.days, [remote])
            XCTAssertEqual(relaunched.syncConflicts.count, 2)
            XCTAssertTrue(relaunched.syncConflicts.contains(originalConflict))
            XCTAssertEqual(relaunched.syncConflicts.filter { $0.record == .day(newer) }.count, 1)
            let conflicts = relaunched.syncConflicts
            try relaunched.applyCloudUpdate(pending)
            XCTAssertEqual(relaunched.syncConflicts, conflicts)
            XCTAssertEqual(DayStore(defaults: defaults).syncConflicts, conflicts)
        }
    }

    func testExportImportPreservesConflictVersionsMetadataPhotosAndNotesAcrossSuites() throws {
        try withDefaults { sourceDefaults in
            let source = DayStore(defaults: sourceDefaults)
            let local = day("exported-conflict")
            var older = local
            older.note = "Older note for the same day"
            older.photoData = Data([6, 5, 4])
            var remote = local
            remote.note = "Active cloud note"
            remote.photoData = nil
            let category = CategoryDefinition(id: "custom.export", name: "Local category",
                                              icon: "tag", colorToken: .dusty, isSystem: false)
            var remoteCategory = category
            remoteCategory.name = "Active cloud category"
            let conflicts = [SyncConflict(record: .day(older)), SyncConflict(record: .day(local)),
                             SyncConflict(record: .category(category))]
            let deleted = DeletedDay(day: day("exported-trash"), deletedAt: recentDate)
            let original = DayBackup(days: [remote], categories: CategoryDefinition.system + [remoteCategory],
                                     deletedDays: [deleted], syncConflicts: conflicts)
            try source.restoreBackup(original)
            let exported = try DayBackup.decode(source.exportBackup())
            XCTAssertEqual(exported.version, 2)
            XCTAssertEqual(exported.days, original.days)
            XCTAssertEqual(exported.categories, original.categories)
            XCTAssertEqual(exported.deletedDays, original.deletedDays)
            XCTAssertEqual(exported.syncConflicts, conflicts)

            try withDefaults { destinationDefaults in
                let destination = DayStore(defaults: destinationDefaults)
                try destination.restoreBackup(exported)
                let relaunched = DayStore(defaults: destinationDefaults)
                XCTAssertNil(relaunched.loadError)
                XCTAssertEqual(relaunched.days, original.days)
                XCTAssertEqual(relaunched.categories, original.categories)
                XCTAssertEqual(relaunched.deletedDays, original.deletedDays)
                XCTAssertEqual(relaunched.syncConflicts, conflicts)
                XCTAssertEqual(try DayBackup.decode(relaunched.exportBackup()).syncConflicts, conflicts)

                let selected = try XCTUnwrap(conflicts.first { $0.record == .day(older) })
                try relaunched.restoreSyncConflict(id: selected.id)
                XCTAssertEqual(relaunched.days, [older])
                XCTAssertEqual(relaunched.syncConflicts, conflicts.filter { $0.id != selected.id })
                XCTAssertEqual(source.syncConflicts, conflicts)
                XCTAssertEqual(DayStore(defaults: sourceDefaults).days, [remote])
                XCTAssertEqual(DayStore(defaults: sourceDefaults).syncConflicts, conflicts)
            }
        }
    }

    func testFailedEqualDeliveryRetainsEditsMadeBeforeRetryWithoutRecoveryHints() throws {
        try withDefaults { defaults in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("SyncConflictTests.\(UUID().uuidString)")
            try Data("blocked photo directory".utf8).write(to: directory)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            let category = CategoryDefinition(id: "custom.equal", name: "Original category",
                                              icon: "tag", colorToken: .sage, isSystem: false)
            store.categories.append(category)
            var original = day("equal-before-failure", photo: nil)
            original.categoryID = category.id
            original.categoryLabel = category.name
            store.add(original)
            let other = day("other-batch-record", photo: Data([4, 5, 6]))
            let pending = CloudLibraryUpdate(upsertedDays: [original, other], upsertedCategories: [category])
            XCTAssertTrue(pending.recoveryDays.isEmpty)
            XCTAssertTrue(pending.recoveryCategories.isEmpty)
            XCTAssertThrowsError(try store.applyCloudUpdate(pending))
            XCTAssertEqual(store.days, [original])
            XCTAssertTrue(store.syncConflicts.isEmpty)
            XCTAssertNil(defaults.data(forKey: "pendingRestore.v1"))

            var editedCategory = category
            editedCategory.name = "Edited while sync was paused"
            store.updateCategory(editedCategory)
            var edited = try XCTUnwrap(store.days.first)
            edited.note = "Local draft saved after the failed delivery"
            XCTAssertTrue(store.update(edited))
            try FileManager.default.removeItem(at: directory)

            let relaunched = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertEqual(relaunched.days, [edited])
            try relaunched.applyCloudUpdate(pending)
            XCTAssertEqual(relaunched.days, [original, other])
            XCTAssertEqual(relaunched.category(for: category.id), category)
            XCTAssertEqual(relaunched.syncConflicts.count, 2)
            XCTAssertEqual(relaunched.syncConflicts.filter { $0.record == .day(edited) }.count, 1)
            XCTAssertEqual(relaunched.syncConflicts.filter { $0.record == .category(editedCategory) }.count, 1)

            let conflicts = relaunched.syncConflicts
            try relaunched.applyCloudUpdate(pending)
            XCTAssertEqual(relaunched.syncConflicts, conflicts)
            let unrelated = day("later-remote-addition", photo: nil)
            try relaunched.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [unrelated]))
            let final = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertEqual(final.syncConflicts, conflicts)
            XCTAssertEqual(final.days, [original, other, unrelated])
            let selected = try XCTUnwrap(conflicts.first { $0.record == .day(edited) })
            try final.restoreSyncConflict(id: selected.id)
            XCTAssertEqual(final.days, [edited, other, unrelated])
            XCTAssertEqual(final.syncConflicts, conflicts.filter { $0.id != selected.id })
        }
    }

    func testDiscardRemovesOnlySelectedConflictAndPersistsWithoutChangingLibrary() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let localA = day("discard-A")
            var otherVersionA = localA
            otherVersionA.note = "Another version of A"
            let localB = day("discard-B")
            let category = CategoryDefinition(id: "custom.discard", name: "Recoverable category",
                                              icon: "tag", colorToken: .rose, isSystem: false)
            try store.applyCloudUpdate(CloudLibraryUpdate(
                upsertedDays: [day(localA.id, note: "Cloud A"), day(localB.id, note: "Cloud B")],
                recoveryDays: [localA, otherVersionA, localB], recoveryCategories: [category]))
            XCTAssertEqual(store.syncConflicts.count, 4)
            let selected = try XCTUnwrap(store.syncConflicts.first { $0.record == .day(localA) })
            let remaining = store.syncConflicts.filter { $0.id != selected.id }
            let days = store.days
            let categories = store.categories
            let deletedDays = store.deletedDays

            try store.discardSyncConflict(id: selected.id)
            XCTAssertEqual(store.syncConflicts, remaining)
            XCTAssertEqual(store.days, days)
            XCTAssertEqual(store.categories, categories)
            XCTAssertEqual(store.deletedDays, deletedDays)
            let relaunched = DayStore(defaults: defaults)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.syncConflicts, remaining)
            XCTAssertEqual(relaunched.days, days)
            XCTAssertEqual(relaunched.categories, categories)
            XCTAssertEqual(relaunched.deletedDays, deletedDays)
        }
    }

    func testRestoringCategoryChangesOnlyMatchingDayLabelsAndKeepsOtherConflicts() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let localCategory = CategoryDefinition(id: "custom.restore", name: "Local label",
                                                   icon: "tag", colorToken: .sage, isSystem: false)
            var remoteCategory = localCategory
            remoteCategory.name = "Shared cloud label"
            remoteCategory.icon = "star"
            remoteCategory.colorToken = .rose
            let otherCategory = CategoryDefinition(id: "custom.unrelated", name: remoteCategory.name,
                                                   icon: "heart", colorToken: .dusty, isSystem: false)
            var first = day("category-first", note: "Latest note after conflict")
            first.categoryID = localCategory.id
            first.categoryLabel = remoteCategory.name
            var second = day("category-second", photo: Data([2, 4, 6]))
            second.categoryID = localCategory.id
            second.categoryLabel = remoteCategory.name
            var unrelated = day("category-unrelated")
            unrelated.categoryID = otherCategory.id
            unrelated.categoryLabel = otherCategory.name
            let categoryConflict = SyncConflict(record: .category(localCategory))
            let dayConflict = SyncConflict(record: .day(day(unrelated.id, note: "Older unrelated note")))
            let deleted = DeletedDay(day: day("category-trash"), deletedAt: recentDate)
            try store.restoreBackup(DayBackup(
                days: [first, second, unrelated], categories: CategoryDefinition.system + [remoteCategory, otherCategory],
                deletedDays: [deleted], syncConflicts: [categoryConflict, dayConflict]))

            try store.restoreSyncConflict(id: categoryConflict.id)
            first.categoryLabel = localCategory.name
            second.categoryLabel = localCategory.name
            let expectedDays = [first, second, unrelated]
            let expectedCategories = CategoryDefinition.system + [localCategory, otherCategory]
            XCTAssertEqual(store.days, expectedDays)
            XCTAssertEqual(store.categories, expectedCategories)
            XCTAssertEqual(store.deletedDays, [deleted])
            XCTAssertEqual(store.syncConflicts, [dayConflict])
            let relaunched = DayStore(defaults: defaults)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, expectedDays)
            XCTAssertEqual(relaunched.categories, expectedCategories)
            XCTAssertEqual(relaunched.deletedDays, [deleted])
            XCTAssertEqual(relaunched.syncConflicts, [dayConflict])
        }
    }

    func testVersionOneBackupWithoutConflictFieldDecodesAndImportsWithNoConflicts() throws {
        let active = day("legacy-active")
        let deleted = DeletedDay(day: day("legacy-trash"), deletedAt: recentDate)
        let original = DayBackup(version: 1, createdAt: active.date, days: [active],
                                 categories: CategoryDefinition.system, deletedDays: [deleted])
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        payload.removeValue(forKey: "syncConflicts")
        let decoded = try DayBackup.decode(JSONSerialization.data(withJSONObject: payload))
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.days, original.days)
        XCTAssertEqual(decoded.categories, original.categories)
        XCTAssertEqual(decoded.deletedDays, original.deletedDays)
        XCTAssertTrue(decoded.syncConflicts.isEmpty)

        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            try store.restoreBackup(decoded)
            let relaunched = DayStore(defaults: defaults)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, original.days)
            XCTAssertEqual(relaunched.categories, original.categories)
            XCTAssertEqual(relaunched.deletedDays, original.deletedDays)
            XCTAssertTrue(relaunched.syncConflicts.isEmpty)
            let exported = try DayBackup.decode(relaunched.exportBackup())
            XCTAssertEqual(exported.version, 2)
            XCTAssertTrue(exported.syncConflicts.isEmpty)
        }
    }

    func testNewBackupDefaultsToVersionTwoAndEmptyConflicts() throws {
        let backup = DayBackup(days: [], categories: CategoryDefinition.system, deletedDays: [])
        XCTAssertEqual(backup.version, 2)
        XCTAssertTrue(backup.syncConflicts.isEmpty)
        let decoded = try DayBackup.decode(backup.encoded())
        XCTAssertEqual(decoded.version, 2)
        XCTAssertTrue(decoded.syncConflicts.isEmpty)
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "SyncConflictTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    private func day(_ id: String, note: String = "Private local note", photo: Data? = Data([1, 2, 3])) -> Day {
        Day(id: id, title: "Day \(id)", date: Date(timeIntervalSince1970: 1_700_000_000),
            recurring: true, category: .life, photo: .home, photoData: photo,
            coverFocusX: 0.2, coverFocusY: 0.8, reminderOffsets: [7, 0],
            note: note, location: "Home", pinned: true)
    }
}
