import Foundation

/// A new day's editor: `categoryID` and `date` start it in that category or on that date, and the
/// day it saves gets `id`, so whoever opened it can tell afterwards whether it added that day.
struct NewDayRequest: Identifiable, Equatable {
    let id = UUID().uuidString
    var categoryID: String?
    var date: Date?
}
