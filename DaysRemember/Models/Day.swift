import Foundation

struct Day: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var date: Date
    var recurring: Bool
    var lunar: Bool
    var category: DayCategory
    var categoryLabel: String
    var categoryID: String
    var photo: PhotoStyle
    /// Optional user-picked image. When present, takes precedence over the gradient.
    var photoData: Data?
    /// Normalized cover focus point in the image, where 0.5/0.5 is centered.
    var coverFocusX: Double
    var coverFocusY: Double
    /// Optional per-day reminder offsets, in days before the event.
    /// `nil` means the global reminder settings are used.
    var reminderOffsets: [Int]?
    /// `nil` uses the global notification time; an override remains subject to quiet hours.
    var reminderTime: DayReminderTime?
    var note: String
    var location: String
    var pinned: Bool

    init(id: String, title: String, date: Date, recurring: Bool = false, lunar: Bool = false,
         category: DayCategory, photo: PhotoStyle, photoData: Data? = nil,
         categoryID: String? = nil, coverFocusX: Double = 0.5, coverFocusY: Double = 0.5,
         reminderOffsets: [Int]? = nil, reminderTime: DayReminderTime? = nil,
         note: String = "", location: String = "",
         pinned: Bool = false, categoryLabel: String? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.recurring = recurring
        self.lunar = lunar
        self.category = category
        self.categoryLabel = categoryLabel ?? category.label
        self.categoryID = categoryID ?? category.rawValue
        self.photo = photo
        self.photoData = photoData
        self.coverFocusX = Self.clampFocus(coverFocusX)
        self.coverFocusY = Self.clampFocus(coverFocusY)
        self.reminderOffsets = reminderOffsets
        self.reminderTime = reminderTime
        self.note = note
        self.location = location
        self.pinned = pinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, date, recurring, lunar, category, categoryLabel, categoryID, photo, photoData, photoFile
        case coverFocusX, coverFocusY, reminderOffsets, reminderTime, note, location, pinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        recurring = try container.decodeIfPresent(Bool.self, forKey: .recurring) ?? false
        lunar = try container.decodeIfPresent(Bool.self, forKey: .lunar) ?? false
        category = try container.decodeIfPresent(DayCategory.self, forKey: .category) ?? .life
        categoryLabel = try container.decodeIfPresent(String.self, forKey: .categoryLabel) ?? category.label
        categoryID = try container.decodeIfPresent(String.self, forKey: .categoryID) ?? category.rawValue
        photo = try container.decodeIfPresent(PhotoStyle.self, forKey: .photo) ?? .home
        if let reference = try container.decodeIfPresent(String.self, forKey: .photoFile) {
            guard let files = decoder.userInfo[PhotoFileStore.codingKey] as? PhotoFileStore else {
                throw DecodingError.dataCorruptedError(forKey: .photoFile, in: container,
                                                       debugDescription: "Local photo references are not portable.")
            }
            photoData = try files.data(for: reference, id: id)
        } else {
            photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        }
        coverFocusX = Self.clampFocus(try container.decodeIfPresent(Double.self, forKey: .coverFocusX) ?? 0.5)
        coverFocusY = Self.clampFocus(try container.decodeIfPresent(Double.self, forKey: .coverFocusY) ?? 0.5)
        reminderOffsets = try container.decodeIfPresent([Int].self, forKey: .reminderOffsets)
        reminderTime = try container.decodeIfPresent(DayReminderTime.self, forKey: .reminderTime)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(recurring, forKey: .recurring)
        try container.encode(lunar, forKey: .lunar)
        try container.encode(category, forKey: .category)
        try container.encode(categoryLabel, forKey: .categoryLabel)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encode(photo, forKey: .photo)
        if let photoData, let files = encoder.userInfo[PhotoFileStore.codingKey] as? PhotoFileStore {
            let repair = encoder.userInfo[PhotoFileStore.repairKey] as? Bool ?? false
            try container.encode(files.reference(for: photoData, id: id, repairCorruptFiles: repair), forKey: .photoFile)
        } else {
            try container.encodeIfPresent(photoData, forKey: .photoData)
        }
        try container.encode(coverFocusX, forKey: .coverFocusX)
        try container.encode(coverFocusY, forKey: .coverFocusY)
        try container.encodeIfPresent(reminderOffsets, forKey: .reminderOffsets)
        try container.encodeIfPresent(reminderTime, forKey: .reminderTime)
        try container.encode(note, forKey: .note)
        try container.encode(location, forKey: .location)
        try container.encode(pinned, forKey: .pinned)
    }

    private static func clampFocus(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
