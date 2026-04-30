import Foundation

struct Day: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var date: Date
    var recurring: Bool
    var lunar: Bool
    var category: DayCategory
    var categoryLabel: String
    var photo: PhotoStyle
    /// Optional user-picked image. When present, takes precedence over the gradient.
    var photoData: Data?
    var note: String
    var location: String
    var pinned: Bool

    init(id: String, title: String, date: Date, recurring: Bool = false, lunar: Bool = false,
         category: DayCategory, photo: PhotoStyle, photoData: Data? = nil,
         note: String = "", location: String = "",
         pinned: Bool = false, categoryLabel: String? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.recurring = recurring
        self.lunar = lunar
        self.category = category
        self.categoryLabel = categoryLabel ?? category.label
        self.photo = photo
        self.photoData = photoData
        self.note = note
        self.location = location
        self.pinned = pinned
    }
}
