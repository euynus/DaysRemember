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
        /// The server's version as last seen (`serverFingerprint` names it), which a local edit
        /// is merged from when the server changes underneath it. Nil until the server's version is
        /// known: for a record made here, or after `forgetServer`.
        var base: CloudLibraryRecord?
        /// What the last batch sent, which becomes `base` once the server takes it.
        var sentValue: CloudLibraryRecord?

        init(_ value: CloudLibraryRecord) {
            id = value.id
            recordType = value.recordType
            self.value = value
        }

        /// Forgets everything about the server's copy, as for a record it doesn't hold.
        mutating func forgetServer() {
            systemFields = nil
            serverFingerprint = nil
            sentRevision = nil
            sentFingerprint = nil
            base = nil
            sentValue = nil
        }
    }

    var version = 2
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
    /// Nil when empty, so a checkpoint without any leaves the key out.
    private var unreadableRecords: [String: String]?

    var hasPendingChanges: Bool { records.values.contains(where: \.dirty) }

    /// Fetched records this app version couldn't read, by record name, with the version that tried.
    /// Set aside, they can't stop the rest of the library syncing; see `receiveIfReadable`.
    var unreadable: [String: String] {
        get { unreadableRecords ?? [:] }
        set { unreadableRecords = newValue.isEmpty ? nil : newValue }
    }

    /// `keeping` names records missing from the snapshot whose deletion isn't inferred.
    mutating func updateLocal(days: [Day], categories: [CategoryDefinition], inferDeletions: Bool,
                              keeping: Set<String> = []) throws {
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
            for name in records.keys where !names.contains(name) && !keeping.contains(name) && records[name]?.value != nil {
                records[name]?.value = nil
                records[name]?.revision = UUID().uuidString
                // A never-sent insertion can be cancelled without deleting anything remotely.
                let needsDeletion = records[name]?.systemFields != nil || records[name]?.sentRevision != nil
                records[name]?.dirty = needsDeletion
            }
        }
    }

    /// The records iCloud holds that `days` and `categories` leave out, when they are most of what
    /// it holds: a library that comes up that way was more likely unreadable than emptied on
    /// purpose, so its deletions wait for the user. Empty when the snapshot looks like a library.
    func missingMost(days: [Day], categories: [CategoryDefinition]) -> [String] {
        let names = Set(days.map { CloudLibraryRecord.day($0).recordName }
                        + categories.map { CloudLibraryRecord.category($0).recordName })
        let held = records.filter { $0.value.value != nil && $0.value.systemFields != nil }
        let heldDays = held.filter { $0.value.recordType == "LibraryDay" }.count
        let missing = held.keys.filter { !names.contains($0) }
        let missingDays = missing.filter { held[$0]?.recordType == "LibraryDay" }.count
        let most = days.isEmpty ? missingDays > 0 : missingDays >= 5 && missingDays * 2 >= heldDays
        return most ? missing.sorted() : []
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
            if entry.dirty, let merged = Self.merging(entry.value, from: entry.base, onto: value) {
                // What the local edit changed and the server left alone survives, and goes up again.
                if merged.conflicted { pendingRemoteUpdate.recover(entry.value) }
                pendingRemoteUpdate.upsert(merged.value)
                entry.value = merged.value
                entry.revision = UUID().uuidString
            } else {
                if entry.value != value { pendingRemoteUpdate.recover(entry.value) }
                // Deliver even equal records: DayStore may be recovering a previously interrupted apply.
                pendingRemoteUpdate.upsert(value)
                entry.value = value
                entry.dirty = false
            }
        } else if entry.value == value {
            entry.dirty = false
        }
        entry.serverFingerprint = fingerprint
        entry.base = value
        entry.systemFields = CloudLibraryRecord.systemFields(of: record)
        records[name] = entry
    }

    /// A local day edit, made from `base`, merged onto the server's newer version by the groups
    /// `DayStore.merging` uses; where both changed a group the server's version wins, and
    /// `conflicted` says the local one is kept aside. Nil when nothing of the edit survives, or
    /// there's no base to tell what it changed.
    static func merging(_ local: CloudLibraryRecord?, from base: CloudLibraryRecord?,
                        onto server: CloudLibraryRecord) -> (value: CloudLibraryRecord, conflicted: Bool)? {
        guard case .day(let edit)? = local, case .day(let original)? = base, case .day(let current) = server else { return nil }
        let (merged, conflicted) = DayStore.merging(edit, from: original, onto: current, editWins: false)
        return merged == current ? nil : (.day(merged), conflicted)
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
        entry.forgetServer()
        records[recordID.recordName] = entry
    }

    /// A save the server answered with "unknown item": a record it held was deleted there, but
    /// one it never held is sent again as new.
    mutating func receiveMissing(_ recordID: CKRecord.ID) {
        guard let entry = records[recordID.recordName], entry.systemFields == nil, entry.value != nil else {
            receiveDeletion(recordID)
            return
        }
        records[recordID.recordName]?.forgetServer()
        records[recordID.recordName]?.dirty = true
    }

    mutating func acknowledgeSave(_ record: CKRecord) throws {
        guard var entry = records[record.recordID.recordName],
              let revision = record["revision"] as? String,
              revision == entry.sentRevision, let fingerprint = entry.sentFingerprint else {
            throw CloudLibraryRecord.RecordError.corruptState
        }
        entry.systemFields = CloudLibraryRecord.systemFields(of: record)
        entry.serverFingerprint = fingerprint
        entry.base = entry.sentValue
        entry.sentValue = nil
        if entry.revision == revision { entry.dirty = false }
        records[record.recordID.recordName] = entry
    }

    mutating func acknowledgeDeletion(_ id: CKRecord.ID) {
        unreadable[id.recordName] = nil
        guard var entry = records[id.recordName] else { return }
        entry.forgetServer()
        entry.dirty = entry.value != nil
        records[id.recordName] = entry
    }

    mutating func acknowledgeRemoteUpdate() {
        // Local edits made after a failed apply are backed up by the callback before this replay wins.
        // A value the server doesn't hold yet (a merge, or a day brought back) still goes up.
        for value in pendingRemoteUpdate.upsertedDays.map(CloudLibraryRecord.day)
            + pendingRemoteUpdate.upsertedCategories.map(CloudLibraryRecord.category) {
            guard let serverFingerprint = records[value.recordName]?.serverFingerprint else {
                records[value.recordName]?.value = value
                records[value.recordName]?.dirty = false
                continue
            }
            records[value.recordName]?.value = value
            records[value.recordName]?.dirty = (try? value.fingerprint()) != serverFingerprint
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
                entry.sentValue = value
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
            records[name]?.forgetServer()
            let hasLocalValue = records[name]?.value != nil
            records[name]?.dirty = hasLocalValue
            records[name]?.revision = UUID().uuidString
        }
    }

    func write(to url: URL, photoFiles: PhotoFileStore? = nil) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let files = photoFiles ?? PhotoFileStore(directory: url.deletingLastPathComponent().appending(path: "Photos", directoryHint: .isDirectory))
        let data = try files.encoder().encode(self)
        try data.write(to: url, options: .atomic)
        // The checkpoint is the only record of the photos beside it.
        try? files.removeFiles(unreferencedBy: [data])
    }

    static func read(from url: URL, photoFiles: PhotoFileStore? = nil) throws -> CloudLibraryState {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return CloudLibraryState() }
        let files = photoFiles ?? PhotoFileStore(directory: url.deletingLastPathComponent().appending(path: "Photos", directoryHint: .isDirectory))
        let state = try files.decoder().decode(Self.self, from: Data(contentsOf: url))
        guard state.version == 2 else { throw CloudLibraryRecord.RecordError.corruptState }
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
