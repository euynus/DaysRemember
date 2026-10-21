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

    /// A record as a newer version might write it, with a cover this version doesn't know.
    private func recordWithUnknownCover(_ day: Day, directory: URL) throws -> CKRecord {
        let record = try record(day, directory: directory)
        let payload = try XCTUnwrap(record["payload"] as? Data)
        var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        fields["photo"] = "aurora"
        record["payload"] = try JSONSerialization.data(withJSONObject: fields) as NSData
        XCTAssertThrowsError(try CloudLibraryRecord.decode(record))
        return record
    }

    private func futureSchemaRecord(_ day: Day, directory: URL) throws -> CKRecord {
        let record = try record(day, directory: directory)
        record["schemaVersion"] = 2 as NSNumber
        return record
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

    func testLegacyCheckpointMigratesToPhotoFilesWithoutReplacingOriginal() throws {
        let identifier = "iCloud.tests.\(UUID().uuidString)"
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CloudLibrarySync").appendingPathComponent(identifier)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = day(photo: Data([3, 2, 1]))
        var legacy = CloudLibraryState()
        try legacy.updateLocal(days: [original], categories: [], inferDeletions: false)
        let oldData = try JSONEncoder().encode(legacy)
        let oldURL = directory.appendingPathComponent("state-v1.json")
        try oldData.write(to: oldURL)

        let sync = CloudLibrarySync(containerIdentifier: identifier)
        sync.start(days: [original], categories: []) { _ in }
        let newURL = directory.appendingPathComponent("state-v2.json")
        let migrated = try CloudLibraryState.read(from: newURL)
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(migrated.records[CloudLibraryRecord.day(original).recordName]?.value, .day(original))
        XCTAssertEqual(try Data(contentsOf: oldURL), oldData)
        XCTAssertLessThan(try Data(contentsOf: newURL).count, 2000)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("Photos").path).isEmpty)
    }

    /// The checkpoint is the only record of the photos beside it; one it no longer uses is deleted.
    func testCheckpointDeletesPhotosItNoLongerUses() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("state.json")
            let photos = directory.appendingPathComponent("Photos")
            var state = CloudLibraryState()
            try state.updateLocal(days: [day(photo: Data([1, 2, 3]))], categories: [], inferDeletions: false)
            try state.write(to: url)
            try state.updateLocal(days: [day(photo: Data([4, 5, 6]))], categories: [], inferDeletions: false)
            try state.write(to: url)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: photos.path).count, 1)
            XCTAssertEqual(try CloudLibraryState.read(from: url).records.values.first?.value, .day(day(photo: Data([4, 5, 6]))))

            try state.updateLocal(days: [], categories: [], inferDeletions: true)
            try state.write(to: url)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: photos.path), [])
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

    /// Signing out and back into the same account keeps edits and deletions made in between:
    /// the server copies fetched again must not replace them.
    func testReconfirmingTheSameAccountKeepsOfflineChanges() throws {
        try withDirectory { directory in
            let kept = day("kept")
            let removed = day("removed")
            var state = CloudLibraryState()
            XCTAssertTrue(state.acceptAccount("account"))
            try state.receive(record(kept, directory: directory))
            try state.receive(record(removed, directory: directory))
            state.acknowledgeRemoteUpdate()
            state.hasFetched = true
            var edited = kept
            edited.title = "Edited offline"
            try state.updateLocal(days: [edited], categories: [], inferDeletions: true)
            state.accountChangePending = true

            XCTAssertTrue(state.acceptAccount("account", confirmed: true))
            try state.receive(record(kept, directory: directory))
            try state.receive(record(removed, directory: directory))
            XCTAssertTrue(state.pendingRemoteUpdate.isEmpty)
            XCTAssertEqual(state.records[CloudLibraryRecord.day(edited).recordName]?.value, .day(edited))
            let deletion = state.records[CloudLibraryRecord.day(removed).recordName]
            XCTAssertNil(deletion?.value)
            XCTAssertEqual(deletion?.dirty, true)
        }
    }

    /// A deleted zone pauses sync until the user asks to upload this device's library again.
    func testDeletedZoneCanBeUploadedAgain() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let local = day()
        var state = CloudLibraryState()
        XCTAssertTrue(state.acceptAccount("account"))
        try state.receive(record(local, directory: directory))
        state.acknowledgeRemoteUpdate()
        state.hasFetched = true
        state.zoneExists = true
        state.zoneWasDeleted = true
        let url = directory.appendingPathComponent("state.json")
        try state.write(to: url)

        let sync = CloudLibrarySync(stateURL: url)
        XCTAssertEqual(sync.status, .zoneDeleted)
        sync.start(days: [local], categories: []) { _ in }
        await sync.reuploadAfterZoneDeletion()
        let persisted = try CloudLibraryState.read(from: url)
        XCTAssertFalse(persisted.zoneWasDeleted)
        XCTAssertFalse(persisted.zoneExists)
        let entry = persisted.records[CloudLibraryRecord.day(local).recordName]
        XCTAssertEqual(entry?.dirty, true)
        XCTAssertNil(entry?.systemFields)
    }

    private func withLanguage(_ language: String, _ body: () throws -> Void) rethrows {
        let defaults = SharedStorage.defaults
        let previous = defaults.object(forKey: AppLocalization.languageKey)
        defaults.set(language, forKey: AppLocalization.languageKey)
        defer { defaults.set(previous, forKey: AppLocalization.languageKey) }
        try body()
    }

    /// The status, the CloudKit error and its code are joined with the language's punctuation.
    func testCloudKitErrorUsesTheLanguagesPunctuation() throws {
        try withDirectory { directory in
            let sync = CloudLibrarySync(stateURL: directory.appendingPathComponent("state.json"))
            try withLanguage("en") {
                sync.fail(CKError(.networkFailure))
                let message = try XCTUnwrap(sync.errorMessage)
                XCTAssertTrue(message.hasPrefix("Sync incomplete; local data preserved: "), message)
                XCTAssertTrue(message.hasSuffix(" (\(CKError.Code.networkFailure.rawValue))"), message)
            }
            try withLanguage("zh-Hans") {
                sync.fail(CKError(.networkFailure))
                let message = try XCTUnwrap(sync.errorMessage)
                XCTAssertTrue(message.hasPrefix("同步未完成，本机数据已保留："), message)
                XCTAssertTrue(message.hasSuffix("（\(CKError.Code.networkFailure.rawValue)）"), message)
            }
        }
    }

    /// An error is kept as a value, not as text, so a language change reaches its message too.
    func testErrorMessageFollowsTheAppLanguage() throws {
        try withDirectory { directory in
            let sync = CloudLibrarySync(stateURL: directory.appendingPathComponent("state.json"))
            withLanguage("zh-Hans") { sync.fail(CKError(.networkFailure)) }
            try withLanguage("en") {
                let message = try XCTUnwrap(sync.errorMessage)
                XCTAssertTrue(message.hasPrefix("Sync incomplete; local data preserved: "), message)
            }
        }
    }

    /// The engine retries CloudKit errors itself; a fetch that then succeeds clears the old error.
    /// Problems that need the user stay.
    func testSuccessfulFetchClearsAnEarlierCloudKitError() throws {
        try withDirectory { directory in
            let sync = CloudLibrarySync(stateURL: directory.appendingPathComponent("state.json"))
            sync.fail(CKError(.networkFailure))
            XCTAssertEqual(sync.status, .failed)
            sync.zoneFetchFinished(error: nil)
            XCTAssertNil(sync.errorMessage)
            XCTAssertNotEqual(sync.status, .failed)

            sync.fail(CloudLibraryRecord.RecordError.metadataTooLarge)
            sync.zoneFetchFinished(error: nil)
            XCTAssertNotNil(sync.errorMessage)
        }
    }

    /// A day with more text than a CloudKit record holds stays pending without holding back the rest.
    func testOversizedRecordDoesNotHoldBackOthers() throws {
        try withDirectory { directory in
            var big = day("big", title: "Long notes")
            big.note = String(repeating: "长", count: 310_000)
            let small = day("small")
            var state = CloudLibraryState()
            try state.updateLocal(days: [big, small], categories: [], inferDeletions: false)
            let changes = [big, small].map { CKSyncEngine.PendingRecordZoneChange.saveRecord(CloudLibraryRecord.day($0).recordID) }

            let batch = try state.prepareBatch(changes, assetDirectory: directory)
            XCTAssertEqual(batch.saves.map(\.recordID), [CloudLibraryRecord.day(small).recordID])
            XCTAssertEqual(batch.tooLarge, [.day(big)])
            let pending = try XCTUnwrap(state.records[CloudLibraryRecord.day(big).recordName])
            XCTAssertTrue(pending.dirty)
            XCTAssertNil(pending.sentRevision)

            let sync = CloudLibrarySync(stateURL: directory.appendingPathComponent("state.json"))
            sync.reportTooLarge(batch.tooLarge)
            let message = try XCTUnwrap(sync.errorMessage)
            XCTAssertTrue(message.contains("Long notes"), message)
        }
    }

    /// A batch holds `limit` records that can be sent: a run of oversized ones at the front of the
    /// queue can't take every place and leave later changes, deletions included, unsent.
    func testOversizedRecordsDoNotFillTheBatch() throws {
        try withDirectory { directory in
            let big = (1...3).map { index -> Day in
                var day = day("big\(index)", title: "Long notes \(index)")
                day.note = String(repeating: "长", count: 310_000)
                return day
            }
            let small = day("small")
            let gone = day("gone")
            var state = CloudLibraryState()
            try state.updateLocal(days: big + [small, gone], categories: [], inferDeletions: false)
            // Sent once, so deleting it here has to reach the server.
            _ = try state.prepareBatch([.saveRecord(CloudLibraryRecord.day(gone).recordID)], assetDirectory: directory)
            try state.updateLocal(days: big + [small], categories: [], inferDeletions: true)
            let changes = big.map { CKSyncEngine.PendingRecordZoneChange.saveRecord(CloudLibraryRecord.day($0).recordID) }
                + [.saveRecord(CloudLibraryRecord.day(small).recordID), .deleteRecord(CloudLibraryRecord.day(gone).recordID)]

            let batch = try state.prepareBatch(changes, limit: 2, assetDirectory: directory)
            XCTAssertEqual(batch.saves.map(\.recordID), [CloudLibraryRecord.day(small).recordID])
            XCTAssertEqual(batch.deletions, [CloudLibraryRecord.day(gone).recordID])
            XCTAssertEqual(batch.tooLarge, big.map(CloudLibraryRecord.day))
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

    /// A record this version can't read, from a newer schema or with a value it doesn't know, is set
    /// aside rather than failing its batch, which would keep the change token from ever advancing.
    func testUnreadableRecordsAreSetAsideWhileTheRestArrive() throws {
        try withDirectory { directory in
            let known = day("known", title: "Known")
            let knownName = CloudLibraryRecord.day(known).recordName
            var state = CloudLibraryState()
            try state.receive(record(known, directory: directory))
            state.acknowledgeRemoteUpdate()

            let future = try futureSchemaRecord(day("future"), directory: directory)
            let readable = day("readable", title: "Readable")
            for fetched in [try recordWithUnknownCover(day("known", title: "Newer"), directory: directory),
                            future, try record(readable, directory: directory)] {
                try state.receiveIfReadable(fetched, appVersion: "1.0 (376)")
            }

            XCTAssertEqual(state.pendingRemoteUpdate.upsertedDays, [readable])
            XCTAssertTrue(state.pendingRemoteUpdate.recoveryDays.isEmpty)
            // The known day keeps the version it was based on.
            XCTAssertEqual(state.records[knownName]?.value, .day(known))
            XCTAssertEqual(state.records[knownName]?.serverFingerprint, try CloudLibraryRecord.day(known).fingerprint())
            XCTAssertNil(state.records[future.recordID.recordName])
            XCTAssertEqual(state.unreadable, [knownName: "1.0 (376)", future.recordID.recordName: "1.0 (376)"])
        }
    }

    /// A photo that hasn't finished downloading still fails the batch, so the next fetch reads it.
    func testPhotoStillDownloadingIsNotSetAside() throws {
        try withDirectory { directory in
            let downloading = try record(day(photo: Data([1, 2, 3])), directory: directory)
            downloading["photo"] = nil
            var state = CloudLibraryState()
            XCTAssertThrowsError(try state.receiveIfReadable(downloading, appVersion: "1.0 (376)"))
            XCTAssertTrue(state.unreadable.isEmpty)
        }
    }

    /// An edit isn't sent over a version this one can't read, even once a refused save hands that
    /// version back; deleting the day is still sent, as the user asked.
    func testEditToAnUnreadableRecordWaitsUnsent() throws {
        try withDirectory { directory in
            let edited = day("known", title: "Edited here")
            let id = CloudLibraryRecord.day(edited).recordID
            var state = CloudLibraryState()
            try state.receive(record(day("known", title: "Known"), directory: directory))
            state.acknowledgeRemoteUpdate()
            try state.updateLocal(days: [edited], categories: [], inferDeletions: true)
            XCTAssertEqual(try state.prepareBatch([.saveRecord(id)], assetDirectory: directory).saves.count, 1)

            try state.receiveIfReadable(recordWithUnknownCover(day("known", title: "Newer"), directory: directory),
                                        forceServer: true, appVersion: "1.0 (376)")
            XCTAssertEqual(state.records[id.recordName]?.value, .day(edited))
            XCTAssertTrue(state.records[id.recordName]?.dirty == true)
            XCTAssertTrue(try state.prepareBatch([.saveRecord(id)], assetDirectory: directory).saves.isEmpty)

            try state.updateLocal(days: [], categories: [], inferDeletions: true)
            XCTAssertEqual(try state.prepareBatch([.deleteRecord(id)], assetDirectory: directory).deletions, [id])
            state.acknowledgeDeletion(id)
            XCTAssertTrue(state.unreadable.isEmpty)
        }
    }

    /// A record set aside that is then deleted remotely no longer counts, though this device never
    /// read it.
    func testRemoteDeletionClearsAnUnreadableRecord() throws {
        try withDirectory { directory in
            let future = try futureSchemaRecord(day("future"), directory: directory)
            var state = CloudLibraryState()
            try state.receiveIfReadable(future, appVersion: "1.0 (376)")
            state.receiveDeletion(future.recordID)
            XCTAssertTrue(state.unreadable.isEmpty)
            XCTAssertTrue(state.pendingRemoteUpdate.isEmpty)
        }
    }

    /// The first engine of an updated app fetches the whole zone again, once, so records an earlier
    /// version set aside are read by one that may understand them.
    func testAnUpdateFetchesUnreadableRecordsAgain() throws {
        try withDirectory { directory in
            let newer = try recordWithUnknownCover(day("known"), directory: directory)
            var state = CloudLibraryState()
            try state.receiveIfReadable(newer, appVersion: "1.0 (376)")
            XCTAssertFalse(state.retryUnreadable(appVersion: "1.0 (376)"))

            let url = directory.appendingPathComponent("state.json")
            try state.write(to: url)
            state = try CloudLibraryState.read(from: url)
            XCTAssertEqual(state.unreadable, [newer.recordID.recordName: "1.0 (376)"])
            XCTAssertTrue(state.retryUnreadable(appVersion: "1.1 (400)"))
            XCTAssertFalse(state.retryUnreadable(appVersion: "1.1 (400)"))

            // Still unreadable: set aside again, without fetching everything on every launch.
            try state.receiveIfReadable(newer, appVersion: "1.1 (400)")
            XCTAssertFalse(state.retryUnreadable(appVersion: "1.1 (400)"))
            try state.receiveIfReadable(record(day("known"), directory: directory), appVersion: "1.1 (400)")
            XCTAssertTrue(state.unreadable.isEmpty)
            XCTAssertEqual(state.pendingRemoteUpdate.upsertedDays, [day("known")])
        }
    }

    /// 数据与同步 counts the records set aside, in the app's language.
    func testUnreadableRecordsAreCountedInTheAppsLanguage() throws {
        try withDirectory { directory in
            var state = CloudLibraryState()
            for id in ["first", "second"] {
                try state.receiveIfReadable(futureSchemaRecord(day(id), directory: directory), appVersion: "1.0 (376)")
            }
            let url = directory.appendingPathComponent("state.json")
            try state.write(to: url)
            XCTAssertNil(CloudLibrarySync(stateURL: directory.appendingPathComponent("empty.json")).unreadableMessage)
            let sync = CloudLibrarySync(stateURL: url, appVersion: "1.0 (376)")
            XCTAssertEqual(sync.unreadableCount, 2)
            try withLanguage("en") {
                XCTAssertEqual(sync.unreadableMessage, "2 iCloud records can’t be read by this version and may come from a newer version of Days Remember. They will be read again after you update the app; everything else keeps syncing.")
            }
            try withLanguage("zh-Hant") {
                let message = try XCTUnwrap(sync.unreadableMessage)
                XCTAssertTrue(message.hasPrefix("有 2 筆 iCloud 記錄"), message)
            }
        }
    }

}
