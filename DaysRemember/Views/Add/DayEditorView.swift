import SwiftUI
import PhotosUI

// Shared add/edit form. Changes remain local until Save.
struct DayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DayStore.self) var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let editingDay: Day?
    @State private var draft: DayDraft
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var showTemplateGallery = false
    @State private var showReminderSettings = false
    /// The date sheet's choice, which 完成 gives the draft.
    @State private var draftDate: Date
    @State private var showDatePicker = false
    @State private var confirmDiscard = false
    @State private var saveError: String?
    @FocusState private var titleFocused: Bool

    /// `date` and `categoryID` prefill a new day, e.g. from a calendar cell or a category's list.
    init(day: Day? = nil, date: Date? = nil, categoryID: String? = nil) {
        editingDay = day
        let draft = DayDraft(editing: day, date: date ?? Today.date, categoryID: categoryID)
        _draft = State(initialValue: draft)
        _draftDate = State(initialValue: draft.date)
    }

    private var canSave: Bool { draft.canSave(isLoadingPhoto: isLoadingPhoto) }

    private var hasUnsavedChanges: Bool { isLoadingPhoto || draft.hasChanges }

    var body: some View {
        VStack(spacing: 0) {
            DayEditorNavBar(isNew: editingDay == nil, canSave: canSave, onCancel: cancel, onSave: saveDay)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DayEditorPreview(title: draft.title, date: draft.date, recurring: draft.recurring, solar: draft.solar,
                                     photo: draft.photo, photoData: draft.photoData,
                                     coverFocusX: $draft.coverFocusX, coverFocusY: $draft.coverFocusY, tint: previewTint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    titleField.padding(.bottom, 12)
                    DayEditorForm(selectedDate: draft.date, solar: $draft.solar, recurring: $draft.repeats,
                                  reminderOffsets: draft.reminderOffsets, reminderTime: draft.reminderTime,
                                  location: $draft.location,
                                  onPickDate: {
                                      draftDate = draft.date
                                      showDatePicker = true
                                  },
                                  onEditReminders: { showReminderSettings = true })
                        .padding(.bottom, 22)

                    SectionHeader(String(localized: "分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    DayEditorCategoryPills(categoryID: draft.categoryID, selectedCategory: draft.selectedCategory,
                                           storedName: draft.original.categoryDisplayName,
                                           onSelect: { draft.selectCategory($0) })
                        .padding(.bottom, 22)

                    coverPicker.padding(.bottom, 28)

                    SectionHeader(String(localized: "心情笔记", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    DayEditorNotes(note: $draft.note)
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
            if let category = categories.first(where: { $0.id == draft.categoryID }) {
                draft.selectedCategory = category
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DayEditorDatePickerSheet(solar: draft.solar, draftDate: $draftDate,
                                     onCancel: { showDatePicker = false }, onConfirm: confirmDraftDate)
        }
        .sheet(isPresented: $showTemplateGallery) {
            DayEditorTemplateGallery(photo: draft.photo, photoData: draft.photoData, tint: previewTint,
                                     onSelect: { preset in
                                         selectTemplate(preset)
                                         showTemplateGallery = false
                                     },
                                     onClose: { showTemplateGallery = false })
        }
        .sheet(isPresented: $showReminderSettings) {
            DayReminderSettingsView(offsets: draft.reminderOffsets, time: draft.reminderTime,
                                    globalOffsets: globalReminderOffsets, globalTime: globalReminderTime) { offsets, time in
                draft.reminderOffsets = offsets
                draft.reminderTime = time
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
        .sensoryFeedback(.selection, trigger: draft.photo)
        .sensoryFeedback(.selection, trigger: draft.reminderOffsets)
        .sensoryFeedback(.selection, trigger: draft.categoryID)
        .sensoryFeedback(.selection, trigger: draft.solar)
        .sensoryFeedback(.selection, trigger: draft.recurring)
    }

    // MARK: - Actions

    private func cancel() {
        if hasUnsavedChanges { confirmDiscard = true }
        else { dismiss() }
    }

    // MARK: - Cover preview

    private var previewTint: Color {
        store.categories.first(where: { $0.id == draft.categoryID })?.tint ?? Theme.bg2
    }

    /// The framing as VoiceOver reads it.
    static func framingDescription(x: Double, y: Double) -> String {
        String(localized: "水平 \(Int((x * 100).rounded()))%，垂直 \(Int((y * 100).rounded()))%",
               bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    // MARK: - Title

    private var titleField: some View {
        TextField("", text: $draft.title,
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
            .focused($titleFocused)
            // A new day starts with its name; the keyboard goes as the form scrolls.
            .onAppear {
                guard editingDay == nil else { return }
                Task { @MainActor in titleFocused = true }
            }
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
                DayEditorPhotoButton(photo: draft.photo, photoData: draft.photoData,
                                     coverFocusX: draft.coverFocusX, coverFocusY: draft.coverFocusY, tint: previewTint,
                                     pickerItem: $pickerItem, isLoadingPhoto: $isLoadingPhoto,
                                     onLoad: { draft.usePhoto($0) },
                                     onFailure: {
                                         photoError = String(localized: "照片未能加载，原封面已保留。请重新选择。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                                     })
            }

            DayEditorQuickTemplates(photo: draft.photo, photoData: draft.photoData, tint: previewTint,
                                    onSelect: selectTemplate)
        }
    }

    /// A template replaces a photo still loading.
    private func selectTemplate(_ preset: PhotoStyle) {
        pickerItem = nil
        draft.selectTemplate(preset)
    }

    // MARK: - Date picker sheet

    private func confirmDraftDate() {
        draft.date = draftDate
        showDatePicker = false
    }

    // MARK: - Save

    private var globalReminderTime: DayReminderTime {
        DayReminderTime(hour: store.settings?.notificationHour ?? 9,
                        minute: store.settings?.notificationMinute ?? 0)
    }

    private var globalReminderOffsets: [Int] {
        guard let settings = store.settings else { return [7, 3, 0] }
        var day = draft.original
        day.reminderOffsets = nil
        return NotificationManager.shared.offsets(for: day, settings: settings)
    }

    private func saveDay() {
        guard let draftDay = draft.day(id: editingDay?.id ?? UUID().uuidString, pinned: editingDay?.pinned ?? false) else {
            return
        }
        guard let new = DayDraft.applyingCategory(to: draftDay, selectedCategory: draft.selectedCategory,
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
}
