import CloudKit
import CryptoKit
import Foundation

struct CloudLibraryUpdate: Codable {
    var upsertedDays: [Day] = []
    var deletedDayIDs: [String] = []
    var upsertedCategories: [CategoryDefinition] = []
    var deletedCategoryIDs: [String] = []
    var recoveryDays: [Day] = []
    var recoveryCategories: [CategoryDefinition] = []

    var isEmpty: Bool {
        upsertedDays.isEmpty && deletedDayIDs.isEmpty && upsertedCategories.isEmpty
            && deletedCategoryIDs.isEmpty && recoveryDays.isEmpty && recoveryCategories.isEmpty
    }

    mutating func recover(_ value: CloudLibraryRecord?) {
        switch value {
        case .day(let day): recoveryDays.append(day)
        case .category(let category): recoveryCategories.append(category)
        case nil: break
        }
    }

    mutating func upsert(_ value: CloudLibraryRecord) {
        switch value {
        case .day(let day):
            deletedDayIDs.removeAll { $0 == day.id }
            upsertedDays.removeAll { $0.id == day.id }
            upsertedDays.append(day)
        case .category(let category):
            deletedCategoryIDs.removeAll { $0 == category.id }
            upsertedCategories.removeAll { $0.id == category.id }
            upsertedCategories.append(category)
        }
    }

    mutating func delete(id: String, recordType: String) {
        if recordType == "LibraryDay" {
            upsertedDays.removeAll { $0.id == id }
            deletedDayIDs.removeAll { $0 == id }
            deletedDayIDs.append(id)
        } else {
            upsertedCategories.removeAll { $0.id == id }
            deletedCategoryIDs.removeAll { $0 == id }
            deletedCategoryIDs.append(id)
        }
    }
}

/// CloudKit metadata never contains image bytes; the original photo is a CKAsset.
enum CloudLibraryRecord: Codable, Equatable {
    case day(Day)
    case category(CategoryDefinition)

    static let zoneID = CKRecordZone.ID(zoneName: "DaysRememberLibrary")
    static let maximumMetadataBytes = 900_000

    enum RecordError: LocalizedError {
        case invalidRecord, unsupportedVersion, missingPhoto, metadataTooLarge, corruptState

        var errorDescription: String? {
            switch self {
            case .invalidRecord: return String(localized: "iCloud 记录无效，未覆盖本机数据。")
            case .unsupportedVersion: return String(localized: "iCloud 数据来自更新版本，请先更新 App。")
            case .missingPhoto: return String(localized: "iCloud 照片未完整下载，未覆盖本机数据。")
            case .metadataTooLarge: return String(localized: "单条记录的文字数据过大，尚未上传。")
            case .corruptState: return String(localized: "同步状态无法读取，原文件已保留；同步已暂停。")
            }
        }
    }

    var id: String {
        switch self {
        case .day(let day): return day.id
        case .category(let category): return category.id
        }
    }

    var recordType: String {
        switch self {
        case .day: return "LibraryDay"
        case .category: return "LibraryCategory"
        }
    }

    var recordName: String { recordType + "." + Self.digest(Data(id.utf8)) }
    var recordID: CKRecord.ID { CKRecord.ID(recordName: recordName, zoneID: Self.zoneID) }

    private var photoData: Data? {
        guard case .day(let day) = self else { return nil }
        return day.photoData
    }

    func validate() throws {
        guard !id.isEmpty else { throw RecordError.invalidRecord }
        switch self {
        case .day(let day):
            try DayBackup.validateDays([day])
        case .category(let category):
            guard !category.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecordError.invalidRecord
            }
        }
    }

    private func metadata() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data: Data
        switch self {
        case .day(var day):
            day.photoData = nil
            data = try encoder.encode(day)
        case .category(let category): data = try encoder.encode(category)
        }
        guard data.count <= Self.maximumMetadataBytes else { throw RecordError.metadataTooLarge }
        return data
    }

    func fingerprint() throws -> String {
        var hash = SHA256()
        hash.update(data: try metadata())
        // Distinguish no photo from an explicitly present, empty asset.
        hash.update(data: Data([photoData == nil ? 0 : 1]))
        if let photoData { hash.update(data: photoData) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func makeRecord(systemFields: Data?, revision: String, assetDirectory: URL) throws -> CKRecord {
        let record = try systemFields.map(Self.restoreSystemFields)
            ?? CKRecord(recordType: recordType, recordID: recordID)
        guard record.recordID == recordID, record.recordType == recordType else {
            throw RecordError.corruptState
        }
        record["schemaVersion"] = 1 as NSNumber
        record["payload"] = try metadata() as NSData
        record["revision"] = revision as NSString
        record["hasPhoto"] = (photoData == nil ? 0 : 1) as NSNumber
        if let photoData {
            try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
            let url = Self.assetURL(recordName: recordName, revision: revision, directory: assetDirectory)
            // Each revision gets an immutable file while CloudKit may still be reading it.
            if !FileManager.default.fileExists(atPath: url.path) {
                try photoData.write(to: url, options: .atomic)
            }
            record["photo"] = CKAsset(fileURL: url)
        } else {
            record["photo"] = nil
        }
        return record
    }

    static func decode(_ record: CKRecord) throws -> CloudLibraryRecord {
        guard (record["schemaVersion"] as? NSNumber)?.intValue == 1 else {
            throw RecordError.unsupportedVersion
        }
        guard record.recordID.zoneID == zoneID,
              let data = record["payload"] as? Data, data.count <= maximumMetadataBytes,
              let revision = record["revision"] as? String, !revision.isEmpty else {
            throw RecordError.invalidRecord
        }
        let result: CloudLibraryRecord
        switch record.recordType {
        case "LibraryDay":
            var day = try JSONDecoder().decode(Day.self, from: data)
            guard day.photoData == nil, let hasPhoto = record["hasPhoto"] as? NSNumber,
                  [0, 1].contains(hasPhoto.intValue) else { throw RecordError.invalidRecord }
            if hasPhoto.boolValue {
                guard let asset = record["photo"] as? CKAsset, let url = asset.fileURL else {
                    throw RecordError.missingPhoto
                }
                do { day.photoData = try Data(contentsOf: url) }
                catch { throw RecordError.missingPhoto }
            }
            result = .day(day)
        case "LibraryCategory":
            result = .category(try JSONDecoder().decode(CategoryDefinition.self, from: data))
        default: throw RecordError.invalidRecord
        }
        try result.validate()
        guard result.recordID == record.recordID else { throw RecordError.invalidRecord }
        return result
    }

    static func systemFields(of record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    static func restoreSystemFields(_ data: Data) throws -> CKRecord {
        let coder = try NSKeyedUnarchiver(forReadingFrom: data)
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        guard let record = CKRecord(coder: coder) else { throw RecordError.corruptState }
        return record
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func assetURL(recordName: String, revision: String, directory: URL) -> URL {
        directory.appendingPathComponent(recordName + "." + digest(Data(revision.utf8)))
    }

    static func removeUnusedAssets(in directory: URL, keeping referenced: Set<URL>) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) {
            guard url.lastPathComponent.hasPrefix("LibraryDay."), !referenced.contains(url),
                  try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            try FileManager.default.removeItem(at: url)
        }
    }
}

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

    var hasPendingChanges: Bool { records.values.contains(where: \.dirty) }

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

    mutating func receiveDeletion(_ recordID: CKRecord.ID) {
        guard recordID.zoneID == CloudLibraryRecord.zoneID,
              var entry = records[recordID.recordName] else { return }
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

    /// A sign-out is sticky even if the next launch sees an available account again.
    mutating func acceptAccount(_ recordName: String, confirmed: Bool = false) -> Bool {
        if !confirmed && (accountChangePending || (accountRecordName != nil && accountRecordName != recordName)) {
            accountChangePending = true
            return false
        }
        if confirmed && (accountChangePending || accountRecordName != recordName) {
            engineState = nil
            hasFetched = false
            zoneExists = false
            zoneWasDeleted = false
            lastFetchedAt = nil
            lastSentAt = nil
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
        accountRecordName = recordName
        accountChangePending = false
        return true
    }

    func write(to url: URL, photoFiles: PhotoFileStore? = nil) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let files = photoFiles ?? PhotoFileStore(directory: url.deletingLastPathComponent().appendingPathComponent("Photos"))
        var checkpoint = self
        checkpoint.version = 2
        try files.encoder().encode(checkpoint).write(to: url, options: .atomic)
    }

    static func read(from url: URL, photoFiles: PhotoFileStore? = nil) throws -> CloudLibraryState {
        guard FileManager.default.fileExists(atPath: url.path) else { return CloudLibraryState() }
        let files = photoFiles ?? PhotoFileStore(directory: url.deletingLastPathComponent().appendingPathComponent("Photos"))
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
