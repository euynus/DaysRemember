import Foundation

struct SyncConflict: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var createdAt = Date.now
    var record: CloudLibraryRecord
}

extension SyncConflict {
    /// The day this is a version of; nil for a category.
    var dayID: String? {
        if case .day(let day) = record { return day.id }
        return nil
    }
}
