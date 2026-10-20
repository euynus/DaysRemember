import SwiftUI
import PhotosUI

// Shared add/edit form. Changes remain local until Save.
struct DayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DayStore.self) var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let editingDay: Day?
    @State private var initialDay: Day
    @State private var title: String
    @State private var selectedCategory: CategoryDefinition?
    @State private var photo: PhotoStyle
    @State private var photoData: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var showTemplateGallery = false
    /// New days follow the selected category's cover until a template or photo is picked.
    @State private var coverChosen: Bool
    @State private var recurring: Bool
    @State private var solar: Bool
    @State private var reminderOffsets: [Int]?
    @State private var reminderTime: DayReminderTime?
    @State private var showReminderSettings = false
    @State private var selectedDate: Date
    @State private var draftDate: Date
    @State private var note: String
    @State private var location: String
    @State private var coverFocusX: Double
    @State private var coverFocusY: Double
    @State private var showDatePicker = false
    @State private var confirmDiscard = false
    @State private var saveError: String?

    /// `date` prefills a new day, e.g. from an empty calendar cell.
    init(day: Day? = nil, date: Date? = nil) {
        editingDay = day
        let initial = day ?? Self.newDraft(date: date ?? Today.date)
        _initialDay = State(initialValue: initial)
        _title = State(initialValue: initial.title)
        _photo = State(initialValue: initial.photo)
        _photoData = State(initialValue: initial.photoData)
        _recurring = State(initialValue: initial.recurring)
        _solar = State(initialValue: !initial.lunar)
        _selectedDate = State(initialValue: initial.date)
        _draftDate = State(initialValue: initial.date)
        _note = State(initialValue: initial.note)
        _location = State(initialValue: initial.location)
        _coverFocusX = State(initialValue: initial.coverFocusX)
        _coverFocusY = State(initialValue: initial.coverFocusY)
        _reminderOffsets = State(initialValue: initial.reminderOffsets)
        _reminderTime = State(initialValue: initial.reminderTime)
        _coverChosen = State(initialValue: day != nil)
    }

    /// A new day starts in 生活, with the cover choosing 生活 would give it.
    static func newDraft(date: Date) -> Day {
        Day(id: "", title: "", date: date, recurring: true, category: .life,
            photo: PhotoStyle.defaultCover(forCategoryID: DayCategory.life.rawValue) ?? .systemDefault)
    }

    private var canSave: Bool {
        Self.canSave(title: title, isLoadingPhoto: isLoadingPhoto, lunar: !solar, date: selectedDate)
    }

    /// A lunar day needs a date the lunar table covers; the date row says so otherwise.
    static func canSave(title: String, isLoadingPhoto: Bool, lunar: Bool, date: Date) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingPhoto
            && (!lunar || Lunar.supportedLunarDate(for: date) != nil)
    }

    /// The reminder sheet hands back offsets sorted and without repeats, so order and repeats in a
    /// stored day's offsets aren't a change.
    static func remindersDiffer(_ offsets: [Int]?, from stored: [Int]?) -> Bool {
        offsets.map(Set.init) != stored.map(Set.init)
    }

    private var categoryID: String { selectedCategory?.id ?? initialDay.categoryID }

    private var hasUnsavedChanges: Bool {
        isLoadingPhoto || title != initialDay.title || categoryID != initialDay.categoryID
            || photo != initialDay.photo || photoData != initialDay.photoData
            || recurring != initialDay.recurring || solar != !initialDay.lunar
            || !CNDate.calendar.isDate(selectedDate, inSameDayAs: initialDay.date)
            || note != initialDay.note || location != initialDay.location
            || coverFocusX != initialDay.coverFocusX || coverFocusY != initialDay.coverFocusY
            || Self.remindersDiffer(reminderOffsets, from: initialDay.reminderOffsets)
            || reminderTime != initialDay.reminderTime
    }

    var body: some View {
        VStack(spacing: 0) {
            DayEditorNavBar(isNew: editingDay == nil, canSave: canSave, onCancel: cancel, onSave: saveDay)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DayEditorPreview(title: title, date: selectedDate, recurring: recurring, solar: solar,
                                     photo: photo, photoData: photoData,
                                     coverFocusX: $coverFocusX, coverFocusY: $coverFocusY, tint: previewTint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    titleField.padding(.bottom, 12)
                    DayEditorForm(selectedDate: selectedDate, solar: $solar, recurring: $recurring,
                                  reminderOffsets: reminderOffsets, reminderTime: reminderTime, location: $location,
                                  onPickDate: {
                                      draftDate = selectedDate
                                      showDatePicker = true
                                  },
                                  onEditReminders: { showReminderSettings = true })
                        .padding(.bottom, 22)

                    SectionHeader(String(localized: "分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    DayEditorCategoryPills(categoryID: categoryID, selectedCategory: selectedCategory,
                                           storedName: initialDay.categoryDisplayName, onSelect: selectCategory)
                        .padding(.bottom, 22)

                    coverPicker.padding(.bottom, 28)

                    SectionHeader(String(localized: "心情笔记", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    DayEditorNotes(note: $note)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("dayEditorScroll")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onChange(of: store.categories, initial: true) { _, categories in
            // Remember a resolved selection so its later deletion cannot look like pending sync.
            if let category = categories.first(where: { $0.id == categoryID }) {
                selectedCategory = category
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DayEditorDatePickerSheet(solar: solar, draftDate: $draftDate,
                                     onCancel: { showDatePicker = false }, onConfirm: confirmDraftDate)
        }
        .sheet(isPresented: $showTemplateGallery) {
            DayEditorTemplateGallery(photo: photo, photoData: photoData, tint: previewTint,
                                     onSelect: { preset in
                                         selectTemplate(preset)
                                         showTemplateGallery = false
                                     },
                                     onClose: { showTemplateGallery = false })
        }
        .sheet(isPresented: $showReminderSettings) {
            DayReminderSettingsView(offsets: reminderOffsets, time: reminderTime,
                                    globalOffsets: globalReminderOffsets, globalTime: globalReminderTime) { offsets, time in
                reminderOffsets = offsets
                reminderTime = time
            }
        }
        .alert("放弃未保存的修改？", isPresented: $confirmDiscard) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        }
        .alert("未能保存", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .alert("无法读取照片", isPresented: Binding(
            get: { photoError != nil },
            set: { if !$0 { photoError = nil } }
        )) {
            Button("好", role: .cancel) { photoError = nil }
        } message: {
            Text(photoError ?? "")
        }
        .sensoryFeedback(.selection, trigger: photo)
        .sensoryFeedback(.selection, trigger: reminderOffsets)
        .sensoryFeedback(.selection, trigger: categoryID)
        .sensoryFeedback(.selection, trigger: solar)
        .sensoryFeedback(.selection, trigger: recurring)
    }

    // MARK: - Actions

    private func cancel() {
        if hasUnsavedChanges { confirmDiscard = true }
        else { dismiss() }
    }

    // MARK: - Cover preview

    private var previewTint: Color {
        store.categories.first(where: { $0.id == categoryID })?.tint ?? Theme.bg2
    }

    /// The framing as VoiceOver reads it.
    static func framingDescription(x: Double, y: Double) -> String {
        String(localized: "水平 \(Int((x * 100).rounded()))%，垂直 \(Int((y * 100).rounded()))%",
               bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    // MARK: - Title

    private var titleField: some View {
        TextField("", text: $title,
                  prompt: Text("给这一天起个名字").foregroundStyle(Theme.muted))
            .font(Theme.sans(22, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
            .submitLabel(.done)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityLabel("日子名称")
            .accessibilityIdentifier("dayTitleField")
    }

    // MARK: - Cover picker

    private var coverPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Button {
                    showTemplateGallery = true
                } label: {
                    Label("模板插图", systemImage: "square.grid.2x2")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                .accessibilityIdentifier("openDayCoverTemplateGallery")

                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                DayEditorPhotoButton(photo: photo, photoData: photoData,
                                     coverFocusX: coverFocusX, coverFocusY: coverFocusY, tint: previewTint,
                                     pickerItem: $pickerItem, isLoadingPhoto: $isLoadingPhoto,
                                     onLoad: { data in
                                         photoData = data
                                         coverChosen = true
                                         resetFocus()
                                     },
                                     onFailure: {
                                         photoError = String(localized: "照片未能加载，原封面已保留。请重新选择。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                                     })
            }

            DayEditorQuickTemplates(photo: photo, photoData: photoData, tint: previewTint,
                                    onSelect: selectTemplate)
        }
    }

    private func isTemplateSelected(_ preset: PhotoStyle) -> Bool {
        Self.isTemplateSelected(preset, photo: photo, photoData: photoData)
    }

    /// A template is chosen while no photo covers it; legacy aliases match by their asset.
    static func isTemplateSelected(_ preset: PhotoStyle, photo: PhotoStyle, photoData: Data?) -> Bool {
        photoData == nil && photo.assetName == preset.assetName
    }

    private func selectTemplate(_ preset: PhotoStyle) {
        coverChosen = true
        pickerItem = nil
        guard !isTemplateSelected(preset) else { return }
        photo = preset
        photoData = nil
        resetFocus()
    }

    // MARK: - Category

    /// A new day's cover follows the category until a template or photo is chosen.
    private func selectCategory(_ category: CategoryDefinition) {
        selectedCategory = category
        if !coverChosen, photoData == nil,
           let cover = PhotoStyle.defaultCover(forCategoryID: category.id) {
            photo = cover
        }
    }

    // MARK: - Date picker sheet

    private func confirmDraftDate() {
        selectedDate = draftDate
        showDatePicker = false
    }

    // MARK: - Save

    private var globalReminderTime: DayReminderTime {
        DayReminderTime(hour: store.settings?.notificationHour ?? 9,
                        minute: store.settings?.notificationMinute ?? 0)
    }

    private var globalReminderOffsets: [Int] {
        guard let settings = store.settings else { return [7, 3, 0] }
        var day = initialDay
        day.reminderOffsets = nil
        return NotificationManager.shared.offsets(for: day, settings: settings)
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

    private func saveDay() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let draft = Day(
            id: editingDay?.id ?? UUID().uuidString,
            title: cleanTitle,
            date: selectedDate,
            recurring: recurring,
            lunar: !solar,
            category: initialDay.category,
            photo: photo,
            photoData: photoData,
            categoryID: initialDay.categoryID,
            coverFocusX: coverFocusX,
            coverFocusY: coverFocusY,
            reminderOffsets: reminderOffsets,
            reminderTime: reminderTime,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            pinned: editingDay?.pinned ?? false,
            categoryLabel: initialDay.categoryLabel
        )
        guard let new = Self.applyingCategory(to: draft, selectedCategory: selectedCategory,
                                             categories: store.categories) else {
            saveError = String(localized: "所选分类已不可用，修改尚未保存。请选择其他分类后重试。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            return
        }

        // The day may have synced while the editor was open; merge onto it rather than overwrite.
        let saved = editingDay.map { store.update(new, editedFrom: $0) } ?? store.add(new)
        guard saved else {
            saveError = store.loadError ?? store.saveError
                ?? String(localized: "这个日子已被删除，修改尚未保存。草稿已保留。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            return
        }
        Haptics.success()
        dismiss()
        Task {
            #if DEBUG
            guard !DebugLaunch.isAutomated, !DebugLaunch.isUnitTesting else { return }
            #endif
            guard let settings = store.settings else { return }
            let needsReminder = !NotificationManager.shared.offsets(for: new, settings: settings).isEmpty
            if needsReminder {
                _ = await NotificationManager.shared.requestAuthorization()
                store.rescheduleNotifications()
            }
        }
    }

    private func resetFocus() {
        coverFocusX = 0.5
        coverFocusY = 0.5
    }
}
