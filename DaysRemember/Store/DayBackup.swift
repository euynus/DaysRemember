import Foundation

struct DeletedDay: Codable, Identifiable, Equatable {
    var day: Day
    var deletedAt: Date
    var id: String { day.id }
}

struct SyncConflict: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var createdAt = Date()
    var record: CloudLibraryRecord
}

struct DayBackup: Codable {
    static let maximumBytes = 100 * 1024 * 1024

    var version = 2
    var createdAt = Date()
    var days: [Day]
    var categories: [CategoryDefinition]
    var deletedDays: [DeletedDay]
    var syncConflicts: [SyncConflict]

    init(version: Int = 2, createdAt: Date = Date(), days: [Day],
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
        case tooLarge, unsupportedVersion, invalidRecords, unreadable

        var errorDescription: String? {
            switch self {
            case .tooLarge: return "备份超过 100 MB，无法读取。"
            case .unsupportedVersion: return "此备份来自更新版本的时光，请先更新 App。"
            case .invalidRecords: return "备份包含无效或重复的记录，原有数据未更改。"
            case .unreadable: return "无法读取此备份，原有数据未更改。"
            }
        }
    }

    func encoded() throws -> Data {
        try validate()
        let data = try JSONEncoder().encode(self)
        guard data.count <= Self.maximumBytes else { throw BackupError.tooLarge }
        return data
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
              }) else { throw BackupError.invalidRecords }
    }
}
