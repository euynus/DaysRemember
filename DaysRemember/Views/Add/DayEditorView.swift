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
    @State private var categoryID: String
    @State private var photo: PhotoStyle
    @State private var photoData: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
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
    @State private var dragStartX: Double?
    @State private var dragStartY: Double?
    @State private var showDatePicker = false
    @State private var confirmDiscard = false
    @State private var saveError: String?

    private static let pickerOptions: [PhotoStyle] = [
        .systemDefault, .birthday, .japan, .study, .home,
    ]

    init(day: Day? = nil) {
        editingDay = day
        let initial = day ?? Day(id: "", title: "", date: Today.date, recurring: true,
                                 category: .life, photo: .systemDefault)
        _initialDay = State(initialValue: initial)
        _title = State(initialValue: initial.title)
        _categoryID = State(initialValue: initial.categoryID)
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
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingPhoto
    }

    private var hasUnsavedChanges: Bool {
        isLoadingPhoto || title != initialDay.title || categoryID != initialDay.categoryID
            || photo != initialDay.photo || photoData != initialDay.photoData
            || recurring != initialDay.recurring || solar != !initialDay.lunar
            || !CNDate.calendar.isDate(selectedDate, inSameDayAs: initialDay.date)
            || note != initialDay.note || location != initialDay.location
            || coverFocusX != initialDay.coverFocusX || coverFocusY != initialDay.coverFocusY
            || reminderOffsets != initialDay.reminderOffsets
            || reminderTime != initialDay.reminderTime
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    titleField.padding(.top, 12).padding(.bottom, 22)
                    formCard.padding(.bottom, 22)
                    livePreview
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    coverPicker.padding(.bottom, 28)

                    SectionHeader("分类").padding(.bottom, 10)
                    categoryPills.padding(.bottom, 22)

                    SectionHeader("心情笔记").padding(.bottom, 10)
                    notesCard
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .interactiveDismissDisabled(hasUnsavedChanges)
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
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

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button("取消") {
                if hasUnsavedChanges { confirmDiscard = true }
                else { dismiss() }
            }
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .buttonStyle(PressScale())

            Spacer()
            Text(editingDay == nil ? "新的日子" : "编辑日子")
                .font(Theme.sans(16, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer()

            PillButton(title: "保存", style: .dark, height: 44, action: saveDay)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    // MARK: - Cover preview

    private var livePreview: some View {
        PhotoTile(style: photo, imageData: photoData,
                  focusX: coverFocusX, focusY: coverFocusY,
                  flat: true, cornerRadius: 3)
            .frame(height: 200)
            .gesture(focusDrag)
            .accessibilityElement()
            .accessibilityLabel("封面取景")
            .accessibilityHint(photoData != nil ? "上下轻扫调整照片裁剪位置" : "封面预览")
            .accessibilityAdjustableAction { direction in
                guard photoData != nil else { return }
                switch direction {
                case .increment: coverFocusY = clamp(coverFocusY - 0.1)
                case .decrement: coverFocusY = clamp(coverFocusY + 0.1)
                @unknown default: break
                }
            }
    }

    private var focusDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard photoData != nil else { return }
                if dragStartX == nil {
                    dragStartX = coverFocusX
                    dragStartY = coverFocusY
                }
                let startX = dragStartX ?? coverFocusX
                let startY = dragStartY ?? coverFocusY
                coverFocusX = clamp(startX - Double(value.translation.width / 200))
                coverFocusY = clamp(startY - Double(value.translation.height / 200))
            }
            .onEnded { _ in
                dragStartX = nil
                dragStartY = nil
            }
    }

    // MARK: - Title

    private var titleField: some View {
        TextField("", text: $title,
                  prompt: Text("给这一天起个名字").foregroundStyle(Theme.muted))
            .font(Theme.sans(25, weight: .medium))
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
            .submitLabel(.done)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) { RowDivider() }
            .accessibilityLabel("日子名称")
    }

    // MARK: - Cover picker

    private var coverPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.pickerOptions, id: \.self) { preset in
                    let selected = photoData == nil && photo.assetName == preset.assetName
                    Button {
                        pickerItem = nil
                        photo = preset
                        photoData = nil
                        resetFocus()
                    } label: {
                        miniPolaroid(selected: selected) {
                            PhotoTile(style: preset, flat: true, cornerRadius: 8, maximumPixelSize: 192)
                                .frame(width: 50, height: 50)
                        }
                    }
                    .buttonStyle(PressScale(scale: 0.95))
                    .accessibilityLabel("选择\(preset.displayName)封面")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
                photosPickerTile
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 1)
        }
    }

    /// Compact cover swatch with an explicit selection outline.
    private func miniPolaroid<Content: View>(selected: Bool,
                                             @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Theme.hairline, lineWidth: selected ? 2 : 1)
            }
    }

    private var photosPickerTile: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            Group {
                if let data = photoData {
                    miniPolaroid(selected: true) {
                        PhotoTile(style: photo, imageData: data, focusX: coverFocusX, focusY: coverFocusY,
                                  flat: true, cornerRadius: 8, maximumPixelSize: 192)
                            .frame(width: 50, height: 50)
                    }
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 58, height: 58)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
                        .shadow(color: Color(hex: 0x15171C).opacity(0.05), radius: 1, x: 0, y: 1)
                }
            }
        }
        .accessibilityLabel("选择相册封面")
        .overlay { if isLoadingPhoto { ProgressView() } }
        .task(id: pickerItem) {
            guard let item = pickerItem else { isLoadingPhoto = false; return }
            isLoadingPhoto = true
            defer { if !Task.isCancelled { isLoadingPhoto = false } }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try Task.checkCancellation()
                let compressed = await Task.detached(priority: .userInitiated) {
                    autoreleasepool { PhotoDecodeCache.compressedJPEG(from: data) }
                }.value
                try Task.checkCancellation()
                guard let compressed else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                photoData = compressed
                resetFocus()
            } catch {
                guard !Task.isCancelled else { return }
                photoError = "照片未能加载，原封面已保留。请重新选择。"
            }
        }
    }

    // MARK: - Form list

    private var formCard: some View {
        CardList {
            // 日期 → opens the date picker sheet.
            Button {
                draftDate = selectedDate
                showDatePicker = true
            } label: {
                HStack(spacing: 14) {
                    Text("日期").font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(CNDate.full(selectedDate))
                            .font(Theme.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        if !solar {
                            Text("农历 \(Lunar.fmt(selectedDate))")
                                .font(Theme.sans(12, weight: .medium))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .cardRow()
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale(scale: 0.99))
            .accessibilityIdentifier("dayDatePickerButton")

            RowDivider()
            formRawRow(label: "日历") {
                SegPicker(options: [(true, "公历"), (false, "农历")], selection: $solar)
            }

            RowDivider()
            formRawRow(label: "类型") {
                SegPicker(options: [(false, "一次"), (true, "每年")], selection: $recurring)
            }

            RowDivider()
            Button {
                showReminderSettings = true
            } label: {
                formRawRow(label: "提醒") {
                    HStack(spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(reminderSummary)
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.ink2)
                            if let reminderTime, reminderOffsets != [] {
                                Text(String(format: "%02d:%02d", reminderTime.hour, reminderTime.minute))
                                    .font(Theme.sans(12, weight: .medium))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale(scale: 0.99))
            .accessibilityIdentifier("dayReminderSettingsButton")

            RowDivider()
            HStack(spacing: 14) {
                Text("地点").font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                TextField("可选", text: $location)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tint(Theme.ink)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .accessibilityLabel("地点")
            }
            .cardRow()
        }
    }

    private func formRawRow<Content: View>(label: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 14))
        return layout {
            Text(label).font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            content()
        }
        .cardRow()
    }

    // MARK: - Category pills

    private var categoryPills: some View {
        FlowLayout(spacing: 8) {
            ForEach(store.categories) { category in
                Chip(category.name, selected: categoryID == category.id) {
                    Image(systemName: category.symbolName)
                        .font(.system(size: 14))
                } action: {
                    categoryID = category.id
                }
                .accessibilityLabel("分类 \(category.name)")
                .accessibilityAddTraits(categoryID == category.id ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Notes card (lined paper)

    private var notesCard: some View {
        ZStack(alignment: .topLeading) {
            if note.isEmpty {
                Text("写下这一天的心情…")
                    .font(Theme.sans(16))
                    .foregroundStyle(Theme.muted)
                    .padding(16)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $note)
                .font(Theme.sans(16))
                .foregroundStyle(Theme.ink)
                .tint(Theme.ink)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, minHeight: 92)
                .padding(12)
                .accessibilityLabel("心情笔记")
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.card)
        )
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.hairline, lineWidth: 1) }
    }

    // MARK: - Date picker sheet

    private var datePickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { showDatePicker = false }
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                Spacer()
                Text(solar ? "选择日期" : "选择农历日期")
                    .font(Theme.sans(16, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("完成") {
                    selectedDate = draftDate
                    showDatePicker = false
                }
                    .font(Theme.sans(15, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            if solar {
                DatePicker("选择日期", selection: $draftDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Theme.ink)
                    .labelsHidden()
                    .padding(.horizontal, 16)
            } else {
                LunarDatePicker(selection: $draftDate)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    // MARK: - Save

    private var reminderSummary: String {
        guard let offsets = reminderOffsets else { return "跟随全局设置" }
        let selected = Set(offsets)
        if selected.isEmpty { return "不提醒" }
        if selected.count == 1, let offset = selected.first {
            return offset == 0 ? "当天" : "提前 \(offset) 天"
        }
        return "自定义（\(selected.count)次）"
    }

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

    private func saveDay() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let category = store.category(for: categoryID)
        let new = Day(
            id: editingDay?.id ?? UUID().uuidString,
            title: cleanTitle,
            date: selectedDate,
            recurring: recurring,
            lunar: !solar,
            category: DayCategory(rawValue: category.id) ?? .life,
            photo: photo,
            photoData: photoData,
            categoryID: category.id,
            coverFocusX: coverFocusX,
            coverFocusY: coverFocusY,
            reminderOffsets: reminderOffsets,
            reminderTime: reminderTime,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            pinned: editingDay?.pinned ?? false,
            categoryLabel: category.name
        )

        if editingDay == nil {
            store.add(new)
        } else {
            store.update(new)
        }
        guard store.loadError == nil else {
            saveError = store.loadError
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

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

}
