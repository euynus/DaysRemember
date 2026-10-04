import CloudKit
import XCTest
@testable import DaysRemember

@MainActor
final class CloudLibrarySyncTests: XCTestCase {
    private func day(_ id: String = "day", title: String = "Local", photo: Data? = nil) -> Day {
        Day(id: id, title: title, date: Date(timeIntervalSince1970: 1_700_000_000),
            category: .life, photo: .home, photoData: photo)
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func record(_ day: Day, directory: URL, revision: String = UUID().uuidString) throws -> CKRecord {
        try CloudLibraryRecord.day(day).makeRecord(systemFields: nil, revision: revision, assetDirectory: directory)
    }

    func testPhotoLargerThanKVSUsesAssetAndRoundTripsAllDayFields() throws {
        try withDirectory { directory in
            var original = day(photo: Data(repeating: 0xA5, count: 2_000_000))
            original.note = "Private note"
            original.location = "Home"
            original.recurring = true
            original.lunar = true
            original.pinned = true
            original.reminderOffsets = []
            original.coverFocusX = 0.25
            original.categoryID = "custom.remote"
            original.categoryLabel = "Remote category"
            let encoded = try record(original, directory: directory)
            let metadata = try XCTUnwrap(encoded["payload"] as? Data)
            XCTAssertLessThan(metadata.count, 10_000)
            XCTAssertNil(try JSONDecoder().decode(Day.self, from: metadata).photoData)
            XCTAssertNotNil(encoded["photo"] as? CKAsset)
            XCTAssertEqual(try CloudLibraryRecord.decode(encoded), .day(original))

            let fields = CloudLibraryRecord.systemFields(of: encoded)
            let restored = try CloudLibraryRecord.restoreSystemFields(fields)
            XCTAssertEqual(restored.recordID, encoded.recordID)
            XCTAssertEqual(restored.recordType, encoded.recordType)
            XCTAssertNil(restored["payload"])
        }
    }

    func testMissingPhotoInvalidIdentityAndFutureSchemaAreRejected() throws {
        try withDirectory { directory in
            let encoded = try record(day(photo: Data([1, 2, 3])), directory: directory)
            encoded["photo"] = nil
            XCTAssertThrowsError(try CloudLibraryRecord.decode(encoded))
            encoded["schemaVersion"] = 2 as NSNumber
            XCTAssertThrowsError(try CloudLibraryRecord.decode(encoded))

            let mismatched = try record(day("first"), directory: directory)
            mismatched["payload"] = try JSONEncoder().encode(day("other")) as NSData
            XCTAssertThrowsError(try CloudLibraryRecord.decode(mismatched))
            let poisoned = try record(day(), directory: directory)
            poisoned["payload"] = try JSONEncoder().encode(day(title: " ")) as NSData
            XCTAssertThrowsError(try CloudLibraryRecord.decode(poisoned))
        }
    }

    func testBootstrapServerWinsSameIDAndPreservesLocalRecoveryPhoto() throws {
        try withDirectory { directory in
            let local = day(photo: Data([7, 8, 9]))
            let remote = day(title: "Server", photo: Data([4, 5, 6]))
            let unrelated = day("local-only")
            var state = CloudLibraryState()
            try state.updateLocal(days: [local, unrelated], categories: [], inferDeletions: false)
            try state.receive(record(remote, directory: directory))
            XCTAssertEqual(state.records[CloudLibraryRecord.day(local).recordName]?.value, .day(remote))
            XCTAssertEqual(state.pendingRemoteUpdate.recoveryDays, [local])
            XCTAssertEqual(state.pendingRemoteUpdate.upsertedDays, [remote])
            XCTAssertEqual(state.records[CloudLibraryRecord.day(unrelated).recordName]?.value, .day(unrelated))
            XCTAssertTrue(state.records[CloudLibraryRecord.day(unrelated).recordName]?.dirty == true)
        }
    }

    func testUnchangedServerVersionPreservesDirtyOfflineEditAcrossRestart() throws {
        try withDirectory { directory in
            let original = day()
            let edited = day(title: "Offline edit", photo: Data([3, 2, 1]))
            let server = try record(original, directory: directory)
            let name = CloudLibraryRecord.day(original).recordName
            var state = CloudLibraryState()
            try state.receive(server)
            state.acknowledgeRemoteUpdate()
            state.hasFetched = true
            try state.updateLocal(days: [edited], categories: [], inferDeletions: true)
            let stateURL = directory.appendingPathComponent("state.json")
            try state.write(to: stateURL)
            state = try CloudLibraryState.read(from: stateURL)
            try state.receive(server)
            XCTAssertEqual(state.records[name]?.value, .day(edited))
            XCTAssertTrue(state.records[name]?.dirty == true)
            XCTAssertTrue(state.pendingRemoteUpdate.isEmpty)
            XCTAssertNotNil(state.records[name]?.systemFields)

            let changed = day(title: "Concurrent server edit")
            try state.receive(record(changed, directory: directory))
            XCTAssertEqual(state.pendingRemoteUpdate.recoveryDays, [edited])
            XCTAssertEqual(state.pendingRemoteUpdate.upsertedDays, [changed])
            XCTAssertFalse(state.records[name]?.dirty ?? true)
        }
    }

    func testAcknowledgingOldUploadDoesNotDiscardNewerLocalEdit() throws {
        try withDirectory { directory in
            let first = day()
            let newer = day(title: "Edited during upload")
            let value = CloudLibraryRecord.day(first)
            var state = CloudLibraryState()
            try state.updateLocal(days: [first], categories: [], inferDeletions: false)
            let revision = try XCTUnwrap(state.records[value.recordName]?.revision)
            state.records[value.recordName]?.sentRevision = revision
            state.records[value.recordName]?.sentFingerprint = try value.fingerprint()
            let sent = try record(first, directory: directory, revision: revision)
            try state.updateLocal(days: [newer], categories: [], inferDeletions: true)
            try state.acknowledgeSave(sent)
            XCTAssertEqual(state.records[value.recordName]?.value, .day(newer))
            XCTAssertTrue(state.records[value.recordName]?.dirty == true)
            try state.receive(sent)
            XCTAssertEqual(state.records[value.recordName]?.value, .day(newer))
            XCTAssertTrue(state.pendingRemoteUpdate.isEmpty)
        }
    }

    func testPendingEventsCoalesceByIDAndRemoteDeleteKeepsUnrelatedLocalRecord() throws {
        try withDirectory { directory in
            let first = day()
            let other = day("unrelated")
            var state = CloudLibraryState()
            try state.updateLocal(days: [first, other], categories: [], inferDeletions: false)
            try state.receive(record(day(title: "Server changed"), directory: directory))
            state.receiveDeletion(CloudLibraryRecord.day(first).recordID)
            XCTAssertTrue(state.pendingRemoteUpdate.upsertedDays.isEmpty)
            XCTAssertEqual(state.pendingRemoteUpdate.deletedDayIDs, [first.id])
            XCTAssertEqual(state.records[CloudLibraryRecord.day(other).recordName]?.value, .day(other))
            try state.receive(record(first, directory: directory))
            XCTAssertTrue(state.pendingRemoteUpdate.deletedDayIDs.isEmpty)
            XCTAssertEqual(state.pendingRemoteUpdate.upsertedDays, [first])

            let category = CategoryDefinition(id: "custom", name: "Custom", icon: "tag", colorToken: .sage, isSystem: false)
            state.pendingRemoteUpdate.upsert(.category(category))
            state.pendingRemoteUpdate.delete(id: category.id, recordType: "LibraryCategory")
            XCTAssertTrue(state.pendingRemoteUpdate.upsertedCategories.isEmpty)
            state.pendingRemoteUpdate.upsert(.category(category))
            XCTAssertTrue(state.pendingRemoteUpdate.deletedCategoryIDs.isEmpty)
        }
    }

    func testLocalSnapshotOnlyQueuesActualChangesAndKnownDeletions() throws {
        try withDirectory { directory in
            let first = day()
            var state = CloudLibraryState()
            try state.receive(record(first, directory: directory))
            state.acknowledgeRemoteUpdate()
            let name = CloudLibraryRecord.day(first).recordName
            let revision = state.records[name]?.revision
            try state.updateLocal(days: [first], categories: [], inferDeletions: true)
            XCTAssertFalse(state.hasPendingChanges)
            XCTAssertEqual(state.records[name]?.revision, revision)
            try state.updateLocal(days: [], categories: [], inferDeletions: false)
            XCTAssertFalse(state.hasPendingChanges, "An initial empty snapshot is not a mass deletion")
            try state.updateLocal(days: [], categories: [], inferDeletions: true)
            XCTAssertTrue(state.records[name]?.dirty == true)
            XCTAssertNil(state.records[name]?.value)

            var unsent = CloudLibraryState()
            try unsent.updateLocal(days: [first], categories: [], inferDeletions: false)
            try unsent.updateLocal(days: [], categories: [], inferDeletions: true)
            XCTAssertFalse(unsent.hasPendingChanges)
        }
    }

    func testAccountChangeIsStickyAcrossRestartAndRequiresConfirmation() throws {
        try withDirectory { directory in
            var state = CloudLibraryState()
            XCTAssertTrue(state.acceptAccount("previous-account"))
            try state.receive(record(day(), directory: directory))
            state.acknowledgeRemoteUpdate()
            state.hasFetched = true
            XCTAssertFalse(state.acceptAccount("new-account"))
            let url = directory.appendingPathComponent("state.json")
            try state.write(to: url)
            state = try CloudLibraryState.read(from: url)
            XCTAssertFalse(state.acceptAccount("previous-account"), "Sign-out/switch must not silently resume")
            XCTAssertTrue(state.acceptAccount("new-account", confirmed: true))
            XCTAssertFalse(state.hasFetched)
            XCTAssertTrue(state.hasPendingChanges)
            XCTAssertNil(state.records.values.first?.systemFields)
            XCTAssertNil(state.lastSentAt)
        }
    }

    func testFailedRemoteApplyRetainsDurablePendingAndRetryReplaysBeforeLocalSnapshot() throws {
        enum ApplyError: Error { case diskFull }
        try withDirectory { directory in
            let local = day()
            let remote = day(title: "Remote")
            var state = CloudLibraryState()
            try state.updateLocal(days: [local], categories: [], inferDeletions: false)
            try state.receive(record(remote, directory: directory))
            state.accountChangePending = true // No test is allowed to create a CloudKit connection.
            let url = directory.appendingPathComponent("state.json")
            try state.write(to: url)
            let sync = CloudLibrarySync(stateURL: url)
            sync.start(days: [local], categories: []) { _ in throw ApplyError.diskFull }
            XCTAssertNotNil(sync.errorMessage)
            XCTAssertEqual(try CloudLibraryState.read(from: url).pendingRemoteUpdate.upsertedDays, [remote])
            var applied: [Day] = []
            sync.start(days: [local], categories: []) { applied = $0.upsertedDays }
            let persisted = try CloudLibraryState.read(from: url)
            XCTAssertEqual(applied, [remote])
            XCTAssertTrue(persisted.pendingRemoteUpdate.isEmpty)
            XCTAssertEqual(persisted.records[CloudLibraryRecord.day(local).recordName]?.value, .day(remote))
            XCTAssertFalse(persisted.hasPendingChanges)
            XCTAssertEqual(sync.status, .accountChanged)
        }
    }

    func testLocalQueueDoesNotReportSyncSuccessAndCorruptCheckpointIsPreserved() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("state.json")
            let sync = CloudLibrarySync(stateURL: url)
            sync.updateLocal(days: [day()], categories: [])
            XCTAssertEqual(sync.status, .pending)
            XCTAssertNil(sync.lastSentAt)
            XCTAssertNil(sync.lastFetchedAt)
            XCTAssertFalse(sync.isSyncing)
            let corrupt = Data("not a checkpoint".utf8)
            try corrupt.write(to: url)
            let failed = CloudLibrarySync(stateURL: url)
            failed.updateLocal(days: [], categories: [])
            XCTAssertEqual(failed.status, .failed)
            XCTAssertNotNil(failed.errorMessage)
            XCTAssertEqual(try Data(contentsOf: url), corrupt)
        }
    }

    func testAssetCleanupKeepsDirtyAndInFlightRevisions() throws {
        try withDirectory { directory in
            let value = CloudLibraryRecord.day(day(photo: Data([1, 2, 3])))
            let sent = try value.makeRecord(systemFields: nil, revision: "sent", assetDirectory: directory)
            let dirty = try value.makeRecord(systemFields: nil, revision: "dirty", assetDirectory: directory)
            let uploading = try value.makeRecord(systemFields: nil, revision: "in-flight", assetDirectory: directory)
            let sentURL = try XCTUnwrap((sent["photo"] as? CKAsset)?.fileURL)
            let dirtyURL = try XCTUnwrap((dirty["photo"] as? CKAsset)?.fileURL)
            let uploadingURL = try XCTUnwrap((uploading["photo"] as? CKAsset)?.fileURL)
            try CloudLibraryRecord.removeUnusedAssets(in: directory, keeping: [dirtyURL, uploadingURL])
            XCTAssertFalse(FileManager.default.fileExists(atPath: sentURL.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: dirtyURL.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: uploadingURL.path))
        }
    }

}
