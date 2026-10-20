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
