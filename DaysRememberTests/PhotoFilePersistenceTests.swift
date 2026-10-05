import CryptoKit
import XCTest
@testable import DaysRemember

@MainActor
final class PhotoFilePersistenceTests: XCTestCase {
    func testLegacyTitleEditMigratesPhotosWithoutChangingLegacyBytes() throws {
        try withStorage { defaults, _, directory in
            let original = day("Legacy photo")
            let legacy = try JSONEncoder().encode([original])
            defaults.set(legacy, forKey: "days.v1")

            let store = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertNil(store.loadError)
            XCTAssertEqual(store.days, [original])
            var edited = original
            edited.title = "Edited title"
            store.update(edited)

            XCTAssertNil(store.loadError)
            XCTAssertEqual(defaults.data(forKey: "days.v1"), legacy)
            let metadata = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            let reference = try photoReference(in: metadata, for: edited)
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(reference)), original.photoData)
            let relaunched = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, [edited])
        }
    }

    func testDefaultsOnlyStoreKeepsInlineLegacyPersistence() throws {
        try withStorage { defaults, _, _ in
            let original = day("Isolated photo")
            let store = DayStore(defaults: defaults)
            store.add(original)

            XCTAssertNil(store.loadError)
            XCTAssertNil(defaults.object(forKey: "days.v2"))
            let data = try XCTUnwrap(defaults.data(forKey: "days.v1"))
            XCTAssertEqual(try JSONDecoder().decode([Day].self, from: data), [original])
            let record = try photoRecord(in: data, id: original.id)
            XCTAssertEqual(record["photoData"] as? String, original.photoData?.base64EncodedString())
            XCTAssertNil(record["photoFile"])
            XCTAssertEqual(DayStore(defaults: defaults).days, [original])
        }
    }

    func testTitleOnlyEditDoesNotRewritePhotoBytesOrModificationDate() throws {
        try withStorage { defaults, _, directory in
            let original = day("Original title")
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            store.add(original)
            XCTAssertNil(store.loadError)
            let before = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            let reference = try photoReference(in: before, for: original)
            let url = directory.appendingPathComponent(reference)
            let bytes = try Data(contentsOf: url)
            // Backdate the file so the assertion cannot pass because of timestamp resolution.
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_600_000_000)],
                                                  ofItemAtPath: url.path)
            let modified = try modificationDate(of: url)

            let relaunched = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertNil(relaunched.loadError)
            var edited = original
            edited.title = "Title-only edit"
            relaunched.update(edited)

            XCTAssertNil(relaunched.loadError)
            let after = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            XCTAssertEqual(try photoReference(in: after, for: edited), reference)
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            XCTAssertEqual(try modificationDate(of: url), modified)
            XCTAssertEqual(DayStore(defaults: defaults, photoDirectory: directory).days, [edited])
        }
    }

    func testPhotoChangeSurvivesRelaunchAndExportsCompleteInlineBackup() throws {
        try withStorage { defaults, _, directory in
            var expected = backup()
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            try store.restoreBackup(expected)
            let oldMetadata = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            let oldReference = try photoReference(in: oldMetadata, for: expected.days[0])
            expected.days[0].photoData = Data([10, 11, 12, 13])
            store.update(expected.days[0])

            XCTAssertNil(store.loadError)
            let metadata = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            let reference = try photoReference(in: metadata, for: expected.days[0])
            XCTAssertNotEqual(reference, oldReference)
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(reference)), expected.days[0].photoData)
            let relaunched = DayStore(defaults: defaults, photoDirectory: directory)
            assertLibrary(relaunched, matches: expected)

            let encoded = try relaunched.exportBackup()
            let exported = try DayBackup.decode(encoded)
            XCTAssertEqual(exported.days, expected.days)
            XCTAssertEqual(exported.categories, expected.categories)
            XCTAssertEqual(exported.deletedDays, expected.deletedDays)
            XCTAssertEqual(exported.syncConflicts, expected.syncConflicts)
            XCTAssertEqual(try JSONDecoder().decode(DayBackup.self, from: encoded).days, expected.days)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            let records = try XCTUnwrap(object["days"] as? [[String: Any]])
            let record = try XCTUnwrap(records.first { $0["id"] as? String == expected.days[0].id })
            XCTAssertEqual(record["photoData"] as? String, expected.days[0].photoData?.base64EncodedString())
            XCTAssertNil(record["photoFile"])
        }
    }

    func testPlainCodersKeepPhotosInlineAndRejectLocalReferences() throws {
        try withStorage { defaults, _, directory in
            let original = day("Portable photo")
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            store.add(original)
            XCTAssertNil(store.loadError)
            let metadata = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            _ = try photoReference(in: metadata, for: original)
            XCTAssertThrowsError(try JSONDecoder().decode([Day].self, from: metadata))

            let portable = try JSONEncoder().encode(store.days)
            let record = try photoRecord(in: portable, id: original.id)
            XCTAssertEqual(record["photoData"] as? String, original.photoData?.base64EncodedString())
            XCTAssertNil(record["photoFile"])
            XCTAssertEqual(try JSONDecoder().decode([Day].self, from: portable), [original])
        }
    }

    func testMissingPhotoBlocksMutationAndExportsRemainingOriginalData() throws {
        try assertUnreadablePhoto(replacement: nil)
    }

    func testAlteredPhotoBlocksMutationAndExportsAlteredOriginalBytes() throws {
        try assertUnreadablePhoto(replacement: Data([99, 98, 97]))
    }

    func testCorruptV2DoesNotFallBackToLegacyData() throws {
        try withStorage { defaults, suite, directory in
            let original = day("Stale legacy photo")
            let legacy = try JSONEncoder().encode([original])
            let corrupt = Data("corrupt days.v2".utf8)
            defaults.set(legacy, forKey: "days.v1")
            defaults.set(corrupt, forKey: "days.v2")
            let before = persisted(defaults, suite: suite)

            let store = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertNotNil(store.loadError)
            XCTAssertTrue(store.days.isEmpty)
            XCTAssertThrowsError(try store.exportBackup())
            store.add(day("Blocked addition"))
            store.save()
            XCTAssertTrue(store.days.isEmpty)
            XCTAssertEqual(persisted(defaults, suite: suite), before)
            XCTAssertTrue(SharedStorage.loadDays(defaults: defaults, photoDirectory: directory).isEmpty)
            let raw = try JSONDecoder().decode([String: Data].self, from: store.exportOriginalData())
            XCTAssertEqual(raw["days.v2"], corrupt)
            XCTAssertEqual(raw["days.v1"], legacy)
        }
    }

    func testPendingRestoreReplayReconstructsPhotoFilesAndMetadata() throws {
        try withStorage { defaults, _, directory in
            let target = backup()
            defaults.set(try JSONEncoder().encode([day("Stale legacy photo")]), forKey: "days.v1")
            defaults.set(Data("interrupted metadata write".utf8), forKey: "days.v2")
            defaults.set(Data("interrupted categories write".utf8), forKey: "categories.v1")
            defaults.set(try target.encoded(), forKey: "pendingRestore.v1")

            let store = DayStore(defaults: defaults, photoDirectory: directory)
            assertLibrary(store, matches: target)
            XCTAssertNil(defaults.object(forKey: "pendingRestore.v1"))
            let metadata = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            let reference = try photoReference(in: metadata, for: target.days[0])
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(reference)), target.days[0].photoData)
            let relaunched = DayStore(defaults: defaults, photoDirectory: directory)
            assertLibrary(relaunched, matches: target)

            var edited = target.days[0]
            edited.title = "Edit after replay"
            relaunched.update(edited)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(DayStore(defaults: defaults, photoDirectory: directory).days, [edited])
        }
    }

    func testSharedWidgetLoaderPrefersV2PhotoAndSupportsLegacyData() throws {
        try withStorage { defaults, _, directory in
            let original = day("Legacy widget photo")
            let legacy = try JSONEncoder().encode([original])
            defaults.set(legacy, forKey: "days.v1")
            XCTAssertEqual(SharedStorage.loadDays(defaults: defaults, photoDirectory: directory), [original])

            let store = DayStore(defaults: defaults, photoDirectory: directory)
            var edited = original
            edited.title = "Current widget photo"
            edited.photoData = Data([20, 21, 22])
            store.update(edited)

            XCTAssertNil(store.loadError)
            XCTAssertNotNil(defaults.data(forKey: "days.v2"))
            XCTAssertEqual(defaults.data(forKey: "days.v1"), legacy)
            XCTAssertEqual(SharedStorage.loadDays(defaults: defaults, photoDirectory: directory), [edited])
        }
    }

    func testFailedPhotoWritePreservesInMemoryLibraryAndLegacyBytes() throws {
        try withStorage { defaults, suite, directory in
            let original = day("Original photo")
            let legacy = try JSONEncoder().encode([original])
            defaults.set(legacy, forKey: "days.v1")
            let obstruction = Data("A regular file, not a photo directory".utf8)
            let blockedDirectory = URL(fileURLWithPath: directory.path, isDirectory: false)
            try obstruction.write(to: blockedDirectory)
            let store = DayStore(defaults: defaults, photoDirectory: blockedDirectory)
            XCTAssertNil(store.loadError)
            XCTAssertEqual(store.days, [original])
            let before = persisted(defaults, suite: suite)
            var edited = original
            edited.title = "Unsaved title"
            edited.photoData = Data([30, 31, 32])
            store.update(edited)

            XCTAssertNil(store.loadError)
            XCTAssertNotNil(store.saveError)
            XCTAssertEqual(store.days, [original])
            XCTAssertEqual(persisted(defaults, suite: suite), before)
            XCTAssertEqual(defaults.data(forKey: "days.v1"), legacy)
            XCTAssertNil(defaults.object(forKey: "days.v2"))
            XCTAssertEqual(try Data(contentsOf: blockedDirectory), obstruction)
            store.add(day("Blocked after failure"))
            store.save()
            XCTAssertEqual(store.days, [original])
            XCTAssertEqual(persisted(defaults, suite: suite), before)
            let relaunched = DayStore(defaults: defaults, photoDirectory: blockedDirectory)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, [original])
        }
    }

    func testFailedRestoreNeverReplaysOverLaterSuccessfulEdits() throws {
        try withStorage { defaults, _, directory in
            var original = day("Original without photo")
            original.photoData = nil
            defaults.set(try JSONEncoder().encode([original]), forKey: "days.v1")
            try Data("blocked directory".utf8).write(to: directory)
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            let incoming = DayBackup(days: [day("Failed incoming photo")],
                                     categories: CategoryDefinition.system, deletedDays: [])
            XCTAssertThrowsError(try store.restoreBackup(incoming))
            XCTAssertNil(defaults.data(forKey: "pendingRestore.v1"))
            XCTAssertEqual(store.days, [original])

            original.title = "Later successful edit"
            store.update(original)
            XCTAssertNil(store.loadError)
            try FileManager.default.removeItem(at: directory)
            let relaunched = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, [original])
        }
    }

    func testCachedPhotoDamageBlocksSaveAndExplicitRestoreRetainsDamagedBytes() throws {
        for damage in [Data([99, 98, 97]), nil] as [Data?] {
            try withStorage { defaults, _, directory in
                let original = day("Original photo")
                let store = DayStore(defaults: defaults, photoDirectory: directory)
                store.add(original)
                let metadata = try XCTUnwrap(defaults.data(forKey: "days.v2"))
                let url = directory.appendingPathComponent(try photoReference(in: metadata, for: original))
                if let damage { try damage.write(to: url, options: .atomic) }
                else { try FileManager.default.removeItem(at: url) }
                var edited = original
                edited.title = "Must not save an unreadable reference"
                store.update(edited)
                XCTAssertNil(store.loadError)
                XCTAssertNotNil(store.saveError)
                XCTAssertEqual(store.days, [original])
                XCTAssertEqual(defaults.data(forKey: "days.v2"), metadata)
                if let damage { XCTAssertEqual(try Data(contentsOf: url), damage) }

                try store.restoreBackup(DayBackup(days: [original], categories: CategoryDefinition.system, deletedDays: []))
                XCTAssertNil(store.loadError)
                XCTAssertNil(store.saveError)
                XCTAssertEqual(DayStore(defaults: defaults, photoDirectory: directory).days, [original])
                if let damage {
                    let raw = try JSONDecoder().decode([String: Data].self, from: store.exportOriginalData())
                    XCTAssertTrue(raw.contains { $0.key.hasPrefix("photos/unreadable/") && $0.value == damage })
                }
            }
        }
    }

    func testFailedCategoryRenameAndDeletionKeepBothCollectionsUnchanged() throws {
        for deleting in [false, true] {
            try withStorage { defaults, suite, directory in
                var category = CategoryDefinition(id: "custom", name: "Original", icon: "tag",
                                                  colorToken: .sage, isSystem: false)
                var original = day("Category member")
                original.categoryID = category.id
                original.categoryLabel = category.name
                let categories = CategoryDefinition.system + [category]
                defaults.set(try JSONEncoder().encode([original]), forKey: "days.v1")
                defaults.set(try JSONEncoder().encode(categories), forKey: "categories.v1")
                try Data("blocked directory".utf8).write(to: directory)
                let store = DayStore(defaults: defaults, photoDirectory: directory)
                let before = persisted(defaults, suite: suite)
                if deleting { store.deleteCategory(id: category.id, migrateTo: DayCategory.life.rawValue) }
                else { category.name = "Renamed"; store.updateCategory(category) }
                XCTAssertNil(store.loadError)
                XCTAssertNotNil(store.saveError)
                XCTAssertEqual(store.days, [original])
                XCTAssertEqual(store.categories, categories)
                XCTAssertEqual(persisted(defaults, suite: suite), before)
                XCTAssertNil(defaults.data(forKey: "pendingRestore.v1"))

                try FileManager.default.removeItem(at: directory)
                if deleting {
                    store.deleteCategory(id: category.id, migrateTo: DayCategory.life.rawValue)
                    XCTAssertFalse(store.categories.contains { $0.id == category.id })
                    XCTAssertEqual(store.days.first?.categoryID, DayCategory.life.rawValue)
                } else {
                    store.updateCategory(category)
                    XCTAssertEqual(store.category(for: category.id).name, "Renamed")
                    XCTAssertEqual(store.days.first?.categoryLabel, "Renamed")
                }
                XCTAssertNil(store.loadError)
                XCTAssertNil(store.saveError)
                let reloaded = DayStore(defaults: defaults, photoDirectory: directory)
                XCTAssertEqual(reloaded.days, store.days)
                XCTAssertEqual(reloaded.categories, store.categories)
            }
        }
    }

    func testPendingLocalMetadataJournalReplaysPhotosAndCategoryTogether() throws {
        try withStorage { defaults, _, directory in
            let target = backup()
            let encoded = try PhotoFileStore(directory: directory).encoder().encode(target)
            defaults.set(encoded, forKey: "pendingRestore.v1")
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            assertLibrary(store, matches: target)
            XCTAssertNil(defaults.data(forKey: "pendingRestore.v1"))
        }
    }

    func testAutomaticCloudUpdateDoesNotRepairDamagedLocalFiles() throws {
        try withStorage { defaults, _, directory in
            let original = day("Original photo")
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            store.add(original)
            let metadata = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            let url = directory.appendingPathComponent(try photoReference(in: metadata, for: original))
            let damaged = Data([99, 98, 97])
            try damaged.write(to: url, options: .atomic)
            let remote = day("Unrelated remote addition", photo: Data([4, 5, 6]))
            XCTAssertThrowsError(try store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remote])))
            XCTAssertEqual(store.days, [original])
            XCTAssertEqual(defaults.data(forKey: "days.v2"), metadata)
            XCTAssertEqual(try Data(contentsOf: url), damaged)
            XCTAssertNil(defaults.data(forKey: "pendingRestore.v1"))
        }
    }

    func testLocalRecoverySnapshotRetainsActiveDeletedAndConflictPhotos() throws {
        try withStorage { defaults, _, directory in
            let original = backup()
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            try store.restoreBackup(original)
            var remote = original.days[0]
            remote.photoData = Data([10, 11, 12])
            try store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remote]))

            let recovery = try XCTUnwrap(defaults.data(forKey: "recoveryBackup.v1"))
            XCTAssertThrowsError(try JSONDecoder().decode(DayBackup.self, from: recovery))
            let decoded = try PhotoFileStore(directory: directory).decoder().decode(DayBackup.self, from: recovery)
            XCTAssertEqual(decoded.days, original.days)
            XCTAssertEqual(decoded.deletedDays, original.deletedDays)
            XCTAssertEqual(decoded.syncConflicts, original.syncConflicts)
            let reloaded = DayStore(defaults: defaults, photoDirectory: directory)
            try reloaded.restorePreviousBackup()
            assertLibrary(reloaded, matches: original)
            assertLibrary(DayStore(defaults: defaults, photoDirectory: directory), matches: original)
        }
    }

    func testLocalMigrationSnapshotExportsPortablePhotosAfterRelaunch() throws {
        try withStorage { defaults, _, directory in
            let original = backup()
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            try store.restoreBackup(original)
            let imported = day("Legacy addition", photo: Data([10, 11, 12]))
            XCTAssertEqual(try store.importLegacyData(days: [imported], categories: []), 1)

            let migration = try XCTUnwrap(defaults.data(forKey: "preCloudKitBackup.v1"))
            XCTAssertThrowsError(try JSONDecoder().decode(DayBackup.self, from: migration))
            let portable = try store.exportMigrationBackup()
            let decoded = try DayBackup.decode(portable)
            XCTAssertEqual(decoded.days, original.days)
            XCTAssertEqual(decoded.categories, original.categories)
            XCTAssertEqual(decoded.deletedDays, original.deletedDays)
            XCTAssertEqual(decoded.syncConflicts, original.syncConflicts)
            XCTAssertEqual(try DayStore(defaults: defaults, photoDirectory: directory).exportMigrationBackup(), portable)
        }
    }

    func testPreviousInlineRecoverySnapshotsRemainReadable() throws {
        for version in [1, 2] {
            try withStorage { defaults, _, directory in
                var original = backup()
                original.version = version
                if version == 1 { original.syncConflicts = [] }
                defaults.set(try original.encoded(), forKey: "recoveryBackup.v1")

                let store = DayStore(defaults: defaults, photoDirectory: directory)
                try store.restorePreviousBackup()

                assertLibrary(store, matches: original)
                assertLibrary(DayStore(defaults: defaults, photoDirectory: directory), matches: original)
            }
        }
    }

    func testFailedCloudPhotoStagingKeepsPreviousRecoverySnapshot() throws {
        try withStorage { defaults, suite, directory in
            var original = day("Current without photo")
            original.photoData = nil
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            store.add(original)
            let recovery = try DayBackup(days: [], categories: CategoryDefinition.system, deletedDays: []).encoded()
            defaults.set(recovery, forKey: "recoveryBackup.v1")
            try Data("blocked directory".utf8).write(to: directory)
            let before = persisted(defaults, suite: suite)
            var remote = original
            remote.photoData = Data([10, 11, 12])

            XCTAssertThrowsError(try store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remote])))

            XCTAssertEqual(store.days, [original])
            XCTAssertEqual(persisted(defaults, suite: suite), before)
            XCTAssertEqual(defaults.data(forKey: "recoveryBackup.v1"), recovery)
            XCTAssertNil(defaults.data(forKey: "pendingRestore.v1"))
        }
    }

    func testCloudUpdateAndRecoveryWorkBeyondPortableBackupLimit() throws {
        try withStorage { defaults, _, directory in
            let photo = Data(repeating: 0x5a, count: 1024 * 1024)
            let original = (0..<80).map { day("Large library \($0)", photo: photo) }
            XCTAssertGreaterThan(original.count * photo.count * 4 / 3, DayBackup.maximumBytes)
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            store.days = original
            XCTAssertNil(store.saveError)
            var remote = original[0]
            remote.title = "Small remote title change"

            try store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remote]))

            var expected = original
            expected[0] = remote
            XCTAssertEqual(store.days, expected)
            let recovery = try XCTUnwrap(defaults.data(forKey: "recoveryBackup.v1"))
            XCTAssertLessThan(recovery.count, 100_000)
            let snapshot = try PhotoFileStore(directory: directory).decoder().decode(DayBackup.self, from: recovery)
            XCTAssertEqual(snapshot.days, original)
            try store.applyCloudUpdate(CloudLibraryUpdate())
            XCTAssertEqual(defaults.data(forKey: "recoveryBackup.v1"), recovery)

            let reloaded = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertNil(reloaded.loadError)
            XCTAssertEqual(reloaded.days, expected)
            XCTAssertEqual(reloaded.syncConflicts.map(\.record), [.day(original[0])])
            XCTAssertThrowsError(try reloaded.exportBackup()) { error in
                guard case DayBackup.BackupError.tooLarge = error else {
                    return XCTFail("Portable exports must retain their size limit: \(error)")
                }
            }
            try reloaded.restorePreviousBackup()
            XCTAssertEqual(reloaded.days, original)
            XCTAssertTrue(reloaded.syncConflicts.isEmpty)
            try reloaded.restorePreviousBackup()
            XCTAssertEqual(reloaded.days, expected)
            XCTAssertEqual(reloaded.syncConflicts.map(\.record), [.day(original[0])])
            XCTAssertEqual(DayStore(defaults: defaults, photoDirectory: directory).days, expected)

            let conflict = try XCTUnwrap(reloaded.syncConflicts.first)
            try reloaded.restoreSyncConflict(id: conflict.id)
            XCTAssertEqual(reloaded.days, original)
            XCTAssertTrue(reloaded.syncConflicts.isEmpty)
            XCTAssertEqual(DayStore(defaults: defaults, photoDirectory: directory).days, original)
        }
    }

    private func assertUnreadablePhoto(replacement: Data?) throws {
        try withStorage { defaults, suite, directory in
            let original = day("Affected photo")
            let survivor = day("Unaffected photo", photo: Data([4, 5, 6]))
            let legacy = try JSONEncoder().encode([original, survivor])
            defaults.set(legacy, forKey: "days.v1")
            let writer = DayStore(defaults: defaults, photoDirectory: directory)
            var edited = original
            edited.title = "Migrated title"
            writer.update(edited)
            XCTAssertNil(writer.loadError)
            let metadata = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            let reference = try photoReference(in: metadata, for: edited)
            let survivorReference = try photoReference(in: metadata, for: survivor)
            let url = directory.appendingPathComponent(reference)
            if let replacement {
                try replacement.write(to: url, options: .atomic)
            } else {
                try FileManager.default.removeItem(at: url)
            }
            let before = persisted(defaults, suite: suite)

            let store = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertNotNil(store.loadError)
            XCTAssertThrowsError(try store.exportBackup())
            let raw = try JSONDecoder().decode([String: Data].self, from: store.exportOriginalData())
            XCTAssertEqual(raw["days.v2"], metadata)
            XCTAssertEqual(raw["days.v1"], legacy)
            XCTAssertEqual(raw["photos/" + reference], replacement)
            XCTAssertEqual(raw["photos/" + survivorReference], survivor.photoData)
            let days = store.days
            let deleted = store.deletedDays
            let categories = store.categories

            store.add(day("Blocked addition"))
            store.update(original)
            store.delete(survivor)
            store.resetToSamples()
            store.save()
            store.saveCategories()
            XCTAssertNotNil(store.loadError)
            XCTAssertEqual(store.days, days)
            XCTAssertEqual(store.deletedDays, deleted)
            XCTAssertEqual(store.categories, categories)
            XCTAssertEqual(persisted(defaults, suite: suite), before)
            XCTAssertEqual(try JSONDecoder().decode([String: Data].self, from: store.exportOriginalData()), raw)
        }
    }

    private func withStorage(_ body: (UserDefaults, String, URL) throws -> Void) throws {
        let suite = "PhotoFilePersistenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try body(defaults, suite, root.appendingPathComponent("photos", isDirectory: true))
    }

    private func persisted(_ defaults: UserDefaults, suite: String) -> NSDictionary {
        (defaults.persistentDomain(forName: suite) ?? [:]) as NSDictionary
    }

    private func day(_ title: String, photo: Data = Data([1, 2, 3])) -> Day {
        Day(id: "photo-test.\(UUID().uuidString)", title: title,
            date: Date(timeIntervalSince1970: 1_700_000_000), category: .life, photo: .home, photoData: photo)
    }

    private func backup() -> DayBackup {
        let category = CategoryDefinition(id: "photo-category.\(UUID().uuidString)", name: "Photo category",
                                          icon: "tag", colorToken: .dusty, isSystem: false)
        var active = day("Active photo")
        active.categoryID = category.id
        active.categoryLabel = category.name
        active.note = "Private note"
        active.coverFocusX = 0.2
        active.coverFocusY = 0.8
        let deleted = day("Deleted photo", photo: Data([4, 5, 6]))
        var conflict = active
        conflict.title = "Earlier photo version"
        conflict.photoData = Data([7, 8, 9])
        return DayBackup(createdAt: active.date, days: [active], categories: CategoryDefinition.system + [category],
                         deletedDays: [DeletedDay(day: deleted, deletedAt: active.date)],
                         syncConflicts: [SyncConflict(createdAt: active.date, record: .day(conflict))])
    }

    private func photoRecord(in data: Data, id: String) throws -> [String: Any] {
        let records = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        return try XCTUnwrap(records.first { $0["id"] as? String == id })
    }

    private func photoReference(in metadata: Data, for day: Day,
                                file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let record = try photoRecord(in: metadata, id: day.id)
        let reference = try XCTUnwrap(record["photoFile"] as? String, file: file, line: line)
        let photo = try XCTUnwrap(day.photoData, file: file, line: line)
        let digest = SHA256.hash(data: photo).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(reference, digest + ".photo", file: file, line: line)
        XCTAssertNil(record["photoData"], file: file, line: line)
        return reference
    }

    private func modificationDate(of url: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.modificationDate] as? Date)
    }

    private func assertLibrary(_ store: DayStore, matches expected: DayBackup,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(store.loadError, file: file, line: line)
        XCTAssertEqual(store.days, expected.days, file: file, line: line)
        XCTAssertEqual(store.categories, expected.categories, file: file, line: line)
        XCTAssertEqual(store.deletedDays, expected.deletedDays, file: file, line: line)
        XCTAssertEqual(store.syncConflicts, expected.syncConflicts, file: file, line: line)
    }
}
