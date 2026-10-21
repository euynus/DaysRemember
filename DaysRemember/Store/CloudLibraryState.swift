import CloudKit
import Foundation

/// One atomic checkpoint binds the native cursor to its payloads and record change tags.
struct CloudLibraryState: Codable {
    struct Entry: Codable {
        var id: String
        var recordType: String
        var value: CloudLibraryRecord?
        var dirty = true
        var revision = UUID().uuidString
        var systemFields: Data?
        var serverFingerprint: String?
        var sentRevision: String?
        var sentFingerprint: String?

        init(_ value: CloudLibraryRecord) {
            id = value.id
            recordType = value.recordType
            self.value = value
        }
    }

    var version = 1
    var records: [String: Entry] = [:]
    var engineState: CKSyncEngine.State.Serialization?
    var accountRecordName: String?
    var accountChangePending = false
    var zoneWasDeleted = false
    var zoneExists = false
    var hasFetched = false
    var lastFetchedAt: Date?
    var lastSentAt: Date?
    var pendingRemoteUpdate = CloudLibraryUpdate()
    /// Optional, so a checkpoint written before it existed still decodes.
    private var unreadableRecords: [String: String]?

    var hasPendingChanges: Bool { records.values.contains(where: \.dirty) }

    /// Fetched records this app version couldn't read, by record name, with the version that tried.
    /// Set aside, they can't stop the rest of the library syncing; see `receiveIfReadable`.
    var unreadable: [String: String] {
        get { unreadableRecords ?? [:] }
        set { unreadableRecords = newValue.isEmpty ? nil : newValue }
    }

    mutating func updateLocal(days: [Day], categories: [CategoryDefinition], inferDeletions: Bool) throws {
        let values = days.map(CloudLibraryRecord.day) + categories.map(CloudLibraryRecord.category)
        guard Set(values.map(\.recordName)).count == values.count else {
            throw CloudLibraryRecord.RecordError.invalidRecord
        }
        for value in values { try value.validate() }
        let names = Set(values.map(\.recordName))
        for value in values where records[value.recordName]?.value != value {
            var entry = records[value.recordName] ?? Entry(value)
            entry.value = value
            entry.dirty = true
            entry.revision = UUID().uuidString
            records[value.recordName] = entry
        }
        if inferDeletions {
            for name in records.keys where !names.contains(name) && records[name]?.value != nil {
                records[name]?.value = nil
                records[name]?.revision = UUID().uuidString
                // A never-sent insertion can be cancelled without deleting anything remotely.
                let needsDeletion = records[name]?.systemFields != nil || records[name]?.sentRevision != nil
                records[name]?.dirty = needsDeletion
            }
        }
    }

    mutating func receive(_ record: CKRecord, forceServer: Bool = false) throws {
        let value = try CloudLibraryRecord.decode(record)
        let fingerprint = try value.fingerprint()
        let name = record.recordID.recordName
        var entry = records[name] ?? Entry(value)
        let isOwnSend = entry.sentRevision == record["revision"] as? String
            && entry.sentFingerprint == fingerprint
        let keepLocalEdit = !forceServer && entry.dirty
            && (entry.serverFingerprint == fingerprint || isOwnSend)
        if !keepLocalEdit {
            if entry.value != value { pendingRemoteUpdate.recover(entry.value) }
            // Deliver even equal records: DayStore may be recovering a previously interrupted apply.
            pendingRemoteUpdate.upsert(value)
            entry.value = value
            entry.dirty = false
        } else if entry.value == value {
            entry.dirty = false
        }
        entry.serverFingerprint = fingerprint
        entry.systemFields = CloudLibraryRecord.systemFields(of: record)
        records[name] = entry
    }

    /// Receives a server record, setting aside one this version can't read (a newer schema, value
    /// or record type) instead of throwing: a failed batch never advances the change token, so the
    /// same record would stop every later sync too. Its entry keeps the version it was based on,
    /// and a local edit to it waits unsent rather than overwriting what it can't read.
    mutating func receiveIfReadable(_ record: CKRecord, forceServer: Bool = false, appVersion: String) throws {
        let name = record.recordID.recordName
        do {
            try receive(record, forceServer: forceServer)
            unreadable[name] = nil
        } catch let error as CloudLibraryRecord.RecordError where error == .missingPhoto {
            // Still downloading: fetching it again can read it.
            throw error
        } catch {
            unreadable[name] = appVersion
        }
    }

    /// After an update, records an earlier version set aside may be readable: forgetting the change
    /// token makes the next engine fetch the whole zone again. Only call it with no engine running,
    /// whose next state update would restore the token.
    mutating func retryUnreadable(appVersion: String) -> Bool {
        guard unreadable.values.contains(where: { $0 != appVersion }) else { return false }
        unreadable = unreadable.mapValues { _ in appVersion }
        engineState = nil
        return true
    }

    mutating func receiveDeletion(_ recordID: CKRecord.ID) {
        guard recordID.zoneID == CloudLibraryRecord.zoneID else { return }
        unreadable[recordID.recordName] = nil
        guard var entry = records[recordID.recordName] else { return }
        pendingRemoteUpdate.recover(entry.value)
        pendingRemoteUpdate.delete(id: entry.id, recordType: entry.recordType)
        entry.value = nil
        entry.dirty = false
        entry.systemFields = nil
        entry.serverFingerprint = nil
        entry.sentRevision = nil
        entry.sentFingerprint = nil
        records[recordID.recordName] = entry
    }

    mutating func acknowledgeSave(_ record: CKRecord) throws {
        guard var entry = records[record.recordID.recordName],
              let revision = record["revision"] as? String,
              revision == entry.sentRevision, let fingerprint = entry.sentFingerprint else {
            throw CloudLibraryRecord.RecordError.corruptState
        }
        entry.systemFields = CloudLibraryRecord.systemFields(of: record)
        entry.serverFingerprint = fingerprint
        if entry.revision == revision { entry.dirty = false }
        records[record.recordID.recordName] = entry
    }

    mutating func acknowledgeDeletion(_ id: CKRecord.ID) {
        unreadable[id.recordName] = nil
        guard var entry = records[id.recordName] else { return }
        entry.systemFields = nil
        entry.serverFingerprint = nil
        entry.sentFingerprint = nil
        entry.sentRevision = nil
        entry.dirty = entry.value != nil
        records[id.recordName] = entry
    }

    mutating func acknowledgeRemoteUpdate() {
        // Local edits made after a failed apply are backed up by the callback before this replay wins.
        for value in pendingRemoteUpdate.upsertedDays.map(CloudLibraryRecord.day)
            + pendingRemoteUpdate.upsertedCategories.map(CloudLibraryRecord.category) {
            records[value.recordName]?.value = value
            records[value.recordName]?.dirty = false
        }
        let deletions = pendingRemoteUpdate.deletedDayIDs.map { ("LibraryDay", $0) }
            + pendingRemoteUpdate.deletedCategoryIDs.map { ("LibraryCategory", $0) }
        for (type, id) in deletions {
            let name = type + "." + CloudLibraryRecord.digest(Data(id.utf8))
            records[name]?.value = nil
            records[name]?.dirty = false
        }
        pendingRemoteUpdate = CloudLibraryUpdate()
    }

    /// The records to send for `changes`, each marked with what was sent. One with more text than a
    /// CloudKit record holds stays pending and comes back in `tooLarge`, so it can't hold back the rest.
    /// Up to `limit` records to send, taken from `changes` in order. Changes that can't be sent (too
    /// large, no longer dirty, or an edit to a record set aside as unreadable) are passed over rather
    /// than counted, so they never hold back the rest. Deleting an unreadable record is still sent.
    mutating func prepareBatch(_ changes: [CKSyncEngine.PendingRecordZoneChange], limit: Int = 100,
                               assetDirectory: URL) throws
        -> (saves: [CKRecord], deletions: [CKRecord.ID], tooLarge: [CloudLibraryRecord]) {
        var saves: [CKRecord] = []
        var deletions: [CKRecord.ID] = []
        var tooLarge: [CloudLibraryRecord] = []
        for change in changes {
            guard saves.count + deletions.count < limit else { break }
            switch change {
            case .saveRecord(let id):
                guard var entry = records[id.recordName], entry.dirty, let value = entry.value,
                      unreadable[id.recordName] == nil else { continue }
                let record: CKRecord
                do {
                    record = try value.makeRecord(systemFields: entry.systemFields, revision: entry.revision,
                                                  assetDirectory: assetDirectory)
                } catch CloudLibraryRecord.RecordError.metadataTooLarge {
                    tooLarge.append(value)
                    continue
                }
                entry.sentRevision = entry.revision
                entry.sentFingerprint = try value.fingerprint()
                records[id.recordName] = entry
                saves.append(record)
            case .deleteRecord(let id):
                guard var entry = records[id.recordName], entry.dirty, entry.value == nil else { continue }
                entry.sentRevision = entry.revision
                entry.sentFingerprint = nil
                records[id.recordName] = entry
                deletions.append(id)
            @unknown default: break
            }
        }
        return (saves, deletions, tooLarge)
    }

    /// A sign-out is sticky even if the next launch sees an available account again.
    mutating func acceptAccount(_ recordName: String, confirmed: Bool = false) -> Bool {
        if !confirmed && (accountChangePending || (accountRecordName != nil && accountRecordName != recordName)) {
            accountChangePending = true
            return false
        }
        if confirmed && accountRecordName != recordName {
            forgetServer()
        } else if confirmed && accountChangePending {
            // The same account again: each record keeps the server version it was based on, so an
            // edit or deletion made meanwhile still wins over that version when it is fetched again.
            engineState = nil
        }
        accountRecordName = recordName
        accountChangePending = false
        return true
    }

    /// Treats the server as holding nothing of this device's: every local record is uploaded again.
    mutating func forgetServer() {
        engineState = nil
        hasFetched = false
        zoneExists = false
        zoneWasDeleted = false
        lastFetchedAt = nil
        lastSentAt = nil
        unreadable = [:]
        for name in records.keys {
            records[name]?.systemFields = nil
            records[name]?.serverFingerprint = nil
            records[name]?.sentRevision = nil
            records[name]?.sentFingerprint = nil
            let hasLocalValue = records[name]?.value != nil
            records[name]?.dirty = hasLocalValue
            records[name]?.revision = UUID().uuidString
        }
    }

    func write(to url: URL, photoFiles: PhotoFileStore? = nil) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let files = photoFiles ?? PhotoFileStore(directory: url.deletingLastPathComponent().appending(path: "Photos", directoryHint: .isDirectory))
        var checkpoint = self
        checkpoint.version = 2
        let data = try files.encoder().encode(checkpoint)
        try data.write(to: url, options: .atomic)
        // The checkpoint is the only record of the photos beside it.
        try? files.removeFiles(unreferencedBy: [data])
    }

    static func read(from url: URL, photoFiles: PhotoFileStore? = nil) throws -> CloudLibraryState {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return CloudLibraryState() }
        let files = photoFiles ?? PhotoFileStore(directory: url.deletingLastPathComponent().appending(path: "Photos", directoryHint: .isDirectory))
        let state = try files.decoder().decode(Self.self, from: Data(contentsOf: url))
        guard (1...2).contains(state.version) else { throw CloudLibraryRecord.RecordError.corruptState }
        for (name, entry) in state.records {
            guard name == entry.recordType + "." + CloudLibraryRecord.digest(Data(entry.id.utf8)),
                  ["LibraryDay", "LibraryCategory"].contains(entry.recordType) else {
                throw CloudLibraryRecord.RecordError.corruptState
            }
            if let value = entry.value {
                try value.validate()
                guard value.recordName == name else { throw CloudLibraryRecord.RecordError.corruptState }
            }
            if let data = entry.systemFields {
                let record = try CloudLibraryRecord.restoreSystemFields(data)
                guard record.recordID.recordName == name, record.recordID.zoneID == CloudLibraryRecord.zoneID,
                      record.recordType == entry.recordType else { throw CloudLibraryRecord.RecordError.corruptState }
            }
        }
        return state
    }
}
