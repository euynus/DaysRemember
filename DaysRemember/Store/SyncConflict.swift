import Foundation

struct SyncConflict: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var createdAt = Date.now
    var record: CloudLibraryRecord
}
