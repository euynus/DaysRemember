import Foundation

/// The editor's working copy of a day. Nothing reaches the store until it is saved.
struct DayDraft: Equatable {
    /// The day as the editor opened it, or a new day's starting values.
    let original: Day
    var title: String
    /// The chosen category; nil while the day's own hasn't resolved on this device.
    var selectedCategory: CategoryDefinition?
    var photo: PhotoStyle
    var photoData: Data?
    /// New days follow the selected category's cover until a template or photo is picked.
    var coverChosen: Bool
    var recurring: Bool
    var solar: Bool
    var reminderOffsets: [Int]?
    var reminderTime: DayReminderTime?
    var date: Date
    var note: String
    var location: String
    var coverFocusX: Double
    var coverFocusY: Double

    /// Edits `day`, or starts a new day on `date`.
    init(editing day: Day?, date: Date) {
        let original = day ?? Self.newDay(date: date)
        self.original = original
        title = original.title
        photo = original.photo
        photoData = original.photoData
        coverChosen = day != nil
        recurring = original.recurring
        solar = !original.lunar
        reminderOffsets = original.reminderOffsets
        reminderTime = original.reminderTime
        self.date = original.date
        note = original.note
        location = original.location
        coverFocusX = original.coverFocusX
        coverFocusY = original.coverFocusY
    }

    /// A new day starts in 生活, with the cover choosing 生活 would give it.
    static func newDay(date: Date) -> Day {
        Day(id: "", title: "", date: date, recurring: true, category: .life,
            photo: PhotoStyle.defaultCover(forCategoryID: DayCategory.life.rawValue) ?? .systemDefault)
    }

    var categoryID: String { selectedCategory?.id ?? original.categoryID }

    func canSave(isLoadingPhoto: Bool) -> Bool {
        Self.canSave(title: title, isLoadingPhoto: isLoadingPhoto, lunar: !solar, date: date)
    }

    /// A lunar day needs a date the lunar table covers; the date row says so otherwise.
    static func canSave(title: String, isLoadingPhoto: Bool, lunar: Bool, date: Date) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingPhoto
            && (!lunar || Lunar.supportedLunarDate(for: date) != nil)
    }

    /// Whether closing the editor would lose anything. Another time on the same day isn't a change.
    var hasChanges: Bool {
        title != original.title || categoryID != original.categoryID
            || photo != original.photo || photoData != original.photoData
            || recurring != original.recurring || solar != !original.lunar
            || !CNDate.calendar.isDate(date, inSameDayAs: original.date)
            || note != original.note || location != original.location
            || coverFocusX != original.coverFocusX || coverFocusY != original.coverFocusY
            || Self.remindersDiffer(reminderOffsets, from: original.reminderOffsets)
            || reminderTime != original.reminderTime
    }

    /// The reminder sheet hands back offsets sorted and without repeats, so order and repeats in a
    /// stored day's offsets aren't a change.
    static func remindersDiffer(_ offsets: [Int]?, from stored: [Int]?) -> Bool {
        offsets.map(Set.init) != stored.map(Set.init)
    }

    // MARK: - Cover

    func isTemplateSelected(_ preset: PhotoStyle) -> Bool {
        Self.isTemplateSelected(preset, photo: photo, photoData: photoData)
    }

    /// A template is chosen while no photo covers it; legacy aliases match by their asset.
    static func isTemplateSelected(_ preset: PhotoStyle, photo: PhotoStyle, photoData: Data?) -> Bool {
        photoData == nil && photo.assetName == preset.assetName
    }

    /// Picking a template, even the current one, stops the cover following the category.
    mutating func selectTemplate(_ preset: PhotoStyle) {
        coverChosen = true
        guard !isTemplateSelected(preset) else { return }
        photo = preset
        photoData = nil
        resetFocus()
    }

    mutating func usePhoto(_ data: Data) {
        photoData = data
        coverChosen = true
        resetFocus()
    }

    /// Until a template or photo is chosen, a new day's cover follows its category.
    mutating func selectCategory(_ category: CategoryDefinition) {
        selectedCategory = category
        if !coverChosen, photoData == nil,
           let cover = PhotoStyle.defaultCover(forCategoryID: category.id) {
            photo = cover
        }
    }

    mutating func resetFocus() {
        coverFocusX = 0.5
        coverFocusY = 0.5
    }

    // MARK: - Save

    /// The day to save, with trimmed text and the original's category, which
    /// `applyingCategory(to:selectedCategory:categories:)` then resolves; nil for an empty title.
    func day(id: String, pinned: Bool) -> Day? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        return Day(
            id: id,
            title: cleanTitle,
            date: date,
            recurring: recurring,
            lunar: !solar,
            category: original.category,
            photo: photo,
            photoData: photoData,
            categoryID: original.categoryID,
            coverFocusX: coverFocusX,
            coverFocusY: coverFocusY,
            reminderOffsets: reminderOffsets,
            reminderTime: reminderTime,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            pinned: pinned,
            categoryLabel: original.categoryLabel
        )
    }

    /// A nil selection preserves an original category that has not yet resolved locally.
    static func applyingCategory(to draft: Day, selectedCategory: CategoryDefinition?,
                                 categories: [CategoryDefinition]) -> Day? {
        let id = selectedCategory?.id ?? draft.categoryID
        guard let category = categories.first(where: { $0.id == id }) else {
            return selectedCategory == nil ? draft : nil
        }
        var day = draft
        day.categoryID = category.id
        day.categoryLabel = category.name
        day.category = DayCategory(rawValue: category.id) ?? .life
        return day
    }
}
