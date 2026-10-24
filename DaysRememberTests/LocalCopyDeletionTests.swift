import XCTest
@testable import DaysRemember

/// Deleting permanently, or clearing internal copies, leaves no copy of the deleted data, or of
/// its photos, on the device.
@MainActor
final class LocalCopyDeletionTests: XCTestCase {
    private func withStore(_ body: (DayStore, UserDefaults, URL) throws -> Void) throws {
        let suite = "LocalCopyDeletionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let photos = directory.appendingPathComponent("photos", isDirectory: true)
        try body(DayStore(defaults: defaults, photoDirectory: photos), defaults, photos)
    }

    private func day(_ title: String, photo: Data? = nil) -> Day {
        Day(id: "deletion-test.\(UUID().uuidString)", title: title, date: Date(timeIntervalSince1970: 1_700_000_000),
            category: .life, photo: .home, photoData: photo)
    }

    private func library(_ days: [Day]) -> DayBackup {
        DayBackup(days: days, categories: CategoryDefinition.system, deletedDays: [])
    }

    private func photoFiles(in directory: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    func testPermanentDeletionRemovesTheDayFromEveryLocalCopy() throws {
        try withStore { store, defaults, photos in
            let kept = day("Kept")
            let deleted = day("Deleted", photo: Data((0..<64).map { _ in UInt8.random(in: 0...255) }))
            try store.restoreBackup(library([kept, deleted]))
            try store.keepMigrationBackup()
            // A synced edit leaves the version it replaced in 同步保留版本 and in the recovery copy.
            var remote = deleted
            remote.note = "Edited elsewhere"
            try store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remote], recoveryDays: [deleted]))
            store.delete(remote)
            XCTAssertEqual(store.deletedDays.map(\.id), [deleted.id])
            XCTAssertFalse(store.syncConflicts.isEmpty)
            XCTAssertEqual(photoFiles(in: photos).count, 1)

            store.permanentlyDeleteDay(id: deleted.id)

            XCTAssertTrue(store.deletedDays.isEmpty)
            XCTAssertTrue(store.syncConflicts.isEmpty)
            for key in ["days.v2", "deletedDays.v1", "syncConflicts.v1", "recoveryBackup.v1", "preCloudKitBackup.v1"] {
                let text = defaults.data(forKey: key).map { String(decoding: $0, as: UTF8.self) } ?? ""
                XCTAssertFalse(text.contains(deleted.id), key)
            }
            XCTAssertEqual(photoFiles(in: photos), [])
            XCTAssertEqual(store.days, [kept])

            let relaunched = DayStore(defaults: defaults, photoDirectory: photos)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, [kept])
            XCTAssertTrue(relaunched.deletedDays.isEmpty)
            XCTAssertTrue(relaunched.syncConflicts.isEmpty)
        }
    }

    func testClearingInternalCopiesKeepsTheLibraryAndRemovesPhotosOnlyTheyUsed() throws {
        try withStore { store, defaults, photos in
            let replaced = day("Replaced", photo: Data([1, 2, 3, 4]))
            let current = day("Current", photo: Data([5, 6, 7, 8]))
            try store.restoreBackup(library([replaced]))
            try store.keepMigrationBackup()
            try store.restoreBackup(library([current]))
            defaults.set(Data("raw".utf8), forKey: "unreadableData.v1")
            XCTAssertTrue(store.hasInternalCopies)
            XCTAssertEqual(photoFiles(in: photos).count, 2)

            try store.clearInternalCopies()

            for key in ["recoveryBackup.v1", "preCloudKitBackup.v1", "unreadableData.v1"] {
                XCTAssertNil(defaults.object(forKey: key), key)
            }
            XCTAssertFalse(store.hasInternalCopies)
            XCTAssertEqual(store.days, [current])
            XCTAssertEqual(photoFiles(in: photos).count, 1)
            // The decision stands: turning sync on later doesn't keep a new pre-migration backup.
            try store.keepMigrationBackup()
            XCTAssertFalse(store.hasMigrationBackup)

            let relaunched = DayStore(defaults: defaults, photoDirectory: photos)
            XCTAssertNil(relaunched.loadError)
            XCTAssertEqual(relaunched.days, [current])
        }
    }
}
