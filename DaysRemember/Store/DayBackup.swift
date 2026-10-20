import Foundation

struct DayBackup: Codable {
    static let maximumBytes = 100 * 1024 * 1024

    var version = 2
    var createdAt = Date.now
    var days: [Day]
    var categories: [CategoryDefinition]
    var deletedDays: [DeletedDay]
    var syncConflicts: [SyncConflict]

    init(version: Int = 2, createdAt: Date = Date.now, days: [Day],
         categories: [CategoryDefinition], deletedDays: [DeletedDay],
         syncConflicts: [SyncConflict] = []) {
        self.version = version
        self.createdAt = createdAt
        self.days = days
        self.categories = categories
        self.deletedDays = deletedDays
        self.syncConflicts = syncConflicts
    }

    private enum CodingKeys: String, CodingKey {
        case version, createdAt, days, categories, deletedDays, syncConflicts
    }

    /// False for a fresh library: no days, trash, sync versions or custom categories.
    var holdsUserData: Bool {
        !days.isEmpty || !deletedDays.isEmpty || !syncConflicts.isEmpty || categories.contains { !$0.isSystem }
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(version: try values.decode(Int.self, forKey: .version),
                  createdAt: try values.decode(Date.self, forKey: .createdAt),
                  days: try values.decode([Day].self, forKey: .days),
                  categories: try values.decode([CategoryDefinition].self, forKey: .categories),
                  deletedDays: try values.decode([DeletedDay].self, forKey: .deletedDays),
                  syncConflicts: try values.decodeIfPresent([SyncConflict].self, forKey: .syncConflicts) ?? [])
    }

    enum BackupError: LocalizedError {
        case tooLarge, tooLargeToExport, unsupportedVersion, invalidRecords, unreadable

        var errorDescription: String? {
            switch self {
            case .tooLarge: return String(localized: "备份超过 100 MB，无法读取。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            // Each entry in 最近删除 and 同步保留版本 carries its own copy of its photo.
            case .tooLargeToExport: return String(localized: "备份超过 100 MB，未能导出。清理「最近删除」和「同步保留版本」，或减少照片封面后再试。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .unsupportedVersion: return String(localized: "此备份来自更新版本的时光，请先更新 App。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .invalidRecords: return String(localized: "备份包含无效或重复的记录，原有数据未更改。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .unreadable: return String(localized: "无法读取此备份，原有数据未更改。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            }
        }
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        let data = try encoder.encode(self)
        // A larger file couldn't be restored, so it isn't written.
        guard data.count <= Self.maximumBytes else { throw BackupError.tooLargeToExport }
        return data
    }

    /// Reads a picked backup file off the main actor, refusing one too large to restore.
    @concurrent static func load(from url: URL) async throws -> DayBackup {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= maximumBytes else { throw BackupError.tooLarge }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> DayBackup {
        guard data.count <= maximumBytes else { throw BackupError.tooLarge }
        let backup: DayBackup
        do {
            backup = try JSONDecoder().decode(DayBackup.self, from: data)
        } catch {
            throw BackupError.unreadable
        }
        try backup.validate()
        return backup
    }

    func validate() throws {
        guard (1...2).contains(version) else { throw BackupError.unsupportedVersion }
        guard createdAt.timeIntervalSinceReferenceDate.isFinite,
              Set(categories.map(\.id)).count == categories.count,
              categories.allSatisfy({ !$0.id.isEmpty && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              deletedDays.allSatisfy({ $0.deletedAt.timeIntervalSinceReferenceDate.isFinite }) else {
            throw BackupError.invalidRecords
        }
        try Self.validateDays(days)
        try Self.validateDays(deletedDays.map(\.day))
        guard Set(days.map(\.id)).isDisjoint(with: deletedDays.map(\.id)) else {
            throw BackupError.invalidRecords
        }
        guard Set(syncConflicts.map(\.id)).count == syncConflicts.count,
              syncConflicts.allSatisfy({ !$0.id.isEmpty && $0.createdAt.timeIntervalSinceReferenceDate.isFinite }) else {
            throw BackupError.invalidRecords
        }
        for conflict in syncConflicts { try conflict.record.validate() }
    }

    static func validateDays(_ days: [Day]) throws {
        guard Set(days.map(\.id)).count == days.count,
              days.allSatisfy({ day in
                  !day.id.isEmpty && !day.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && day.date.timeIntervalSinceReferenceDate.isFinite
                      && (1...9999).contains(CNDate.calendar.component(.year, from: day.date))
                      && day.coverFocusX.isFinite && day.coverFocusY.isFinite
                      && (day.reminderOffsets?.allSatisfy { (0...365).contains($0) } ?? true)
                      && (day.reminderTime?.isValid ?? true)
              }) else { throw BackupError.invalidRecords }
    }
}
