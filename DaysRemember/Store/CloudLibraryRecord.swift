import CloudKit
import CryptoKit
import Foundation

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
            case .invalidRecord: return String(localized: "iCloud 记录无效，未覆盖本机数据。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .unsupportedVersion: return String(localized: "iCloud 数据来自更新版本，请先更新 App。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .missingPhoto: return String(localized: "iCloud 照片未完整下载，未覆盖本机数据。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .metadataTooLarge: return String(localized: "单条记录的文字数据过大，尚未上传。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .corruptState: return String(localized: "同步状态无法读取，原文件已保留；同步已暂停。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
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
            if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
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
        directory.appending(path: recordName + "." + digest(Data(revision.utf8)))
    }

    static func removeUnusedAssets(in directory: URL, keeping referenced: Set<URL>) throws {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) {
            guard url.lastPathComponent.hasPrefix("LibraryDay."), !referenced.contains(url),
                  try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            try FileManager.default.removeItem(at: url)
        }
    }
}
