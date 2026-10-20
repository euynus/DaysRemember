import Foundation

struct DeletedDay: Codable, Identifiable, Equatable {
    var day: Day
    var deletedAt: Date
    var id: String { day.id }
}
