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
    @ScaledMetric(relativeTo: .caption) private var coverSwatchWidth: CGFloat = 80
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

    init(day: Day? = nil) {
        editingDay = day
        let initial = day ?? Day(id: "", title: "", date: Today.date, recurring: true,
                                 category: .life, photo: .systemDefault)
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
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingPhoto
    }

    private var categoryID: String { selectedCategory?.id ?? initialDay.categoryID }

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

                    SectionHeader(String(localized: "分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    categoryPills.padding(.bottom, 22)

                    SectionHeader(String(localized: "心情笔记", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    notesCard
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("dayEditorScroll")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onChange(of: store.categories, initial: true) { _, categories in
            // Remember a resolved selection so its later deletion cannot look like pending sync.
            if let category = categories.first(where: { $0.id == categoryID }) {
                selectedCategory = category
            }
        }
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
        .sheet(isPresented: $showTemplateGallery) { templateGallery }
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
                .accessibilityIdentifier("cancelDayButton")

            Spacer()
            Text(editingDay == nil ? String(localized: "新的日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "编辑日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                .font(Theme.sans(16, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer()

            PillButton(title: String(localized: "保存", bundle: AppLocalization.bundle, locale: AppLocalization.locale), style: .dark, height: 44, action: saveDay)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .accessibilityIdentifier("saveDayButton")
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
            .accessibilityHint(photoData != nil
                ? String(localized: "上下轻扫调整照片裁剪位置", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : String(localized: "封面预览", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
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
                photosPickerTile
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(PhotoStyle.pickerOptions, id: \.self) { preset in
                            let selected = isTemplateSelected(preset)
                            Button {
                                selectTemplate(preset)
                            } label: {
                                VStack(spacing: 7) {
                                    miniPolaroid(selected: selected) {
                                        PhotoTile(style: preset, flat: true, cornerRadius: 4, maximumPixelSize: 192)
                                            .frame(width: 64, height: 64)
                                    }
                                    Text(preset.displayName)
                                        .font(Theme.sans(12, weight: .medium, relativeTo: .caption))
                                        .foregroundStyle(selected ? Theme.accent : Theme.ink2)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(width: coverSwatchWidth)
                            }
                            .buttonStyle(PressScale(scale: 0.95))
                            .accessibilityLabel("选择\(preset.displayName)封面")
                            .accessibilityIdentifier("cover-quick-template.\(preset.rawValue)")
                            .accessibilityAddTraits(selected ? [.isSelected] : [])
                            .id(preset.assetName)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 1)
                }
                .accessibilityIdentifier("dayCoverQuickTemplates")
                .onChange(of: photoData == nil ? photo.assetName : nil, initial: true) { _, asset in
                    if let asset { proxy.scrollTo(asset, anchor: .center) }
                }
            }
        }
    }

    private var templateGallery: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("模板插图")
                    .font(Theme.sans(18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("dayCoverTemplateGalleryTitle")
                Spacer(minLength: 8)
                Button {
                    showTemplateGallery = false
                } label: {
                    Label("关闭", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                .accessibilityIdentifier("closeDayCoverTemplateGallery")
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 10)

            RowDivider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                              alignment: .leading, spacing: 22) {
                        ForEach(PhotoStyle.pickerOptions, id: \.self) { preset in
                            galleryTemplate(preset)
                                .id(preset.assetName)
                        }
                    }
                    .padding(22)
                }
                .accessibilityIdentifier("dayCoverTemplateGallery")
                .onAppear {
                    if photoData == nil {
                        proxy.scrollTo(photo.assetName, anchor: .center)
                    }
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func galleryTemplate(_ preset: PhotoStyle) -> some View {
        let selected = isTemplateSelected(preset)
        return Button {
            selectTemplate(preset)
            showTemplateGallery = false
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                PhotoTile(style: preset, flat: true, cornerRadius: 6, maximumPixelSize: 1024)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(selected ? Theme.accent : Theme.hairline,
                                          lineWidth: selected ? 2 : 1)
                    }
                HStack(alignment: .top, spacing: 8) {
                    Text(preset.displayName)
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Theme.accent)
                        .opacity(selected ? 1 : 0)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.98))
        .accessibilityLabel("选择\(preset.displayName)封面")
        .accessibilityIdentifier("cover-template.\(preset.rawValue)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func isTemplateSelected(_ preset: PhotoStyle) -> Bool {
        photoData == nil && photo.assetName == preset.assetName
    }

    private func selectTemplate(_ preset: PhotoStyle) {
        pickerItem = nil
        guard !isTemplateSelected(preset) else { return }
        photo = preset
        photoData = nil
        resetFocus()
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
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Theme.accent)
                        .padding(2)
                        .accessibilityHidden(true)
                }
            }
    }

    private var photosPickerTile: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            HStack(spacing: 8) {
                if let data = photoData {
                    miniPolaroid(selected: true) {
                        PhotoTile(style: photo, imageData: data, focusX: coverFocusX, focusY: coverFocusY,
                                  flat: true, cornerRadius: 4, maximumPixelSize: 192)
                            .frame(width: 32, height: 32)
                    }
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                }
                Text("照片")
                    .font(Theme.sans(14, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.ink2)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("选择相册封面")
        .accessibilityIdentifier("dayCoverPhotoPicker")
        .accessibilityAddTraits(photoData != nil ? [.isSelected] : [])
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
                photoError = String(localized: "照片未能加载，原封面已保留。请重新选择。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
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
            formRawRow(label: String(localized: "日历", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) {
                SegPicker(options: [(true, String(localized: "公历", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
                                    (false, String(localized: "农历", bundle: AppLocalization.bundle, locale: AppLocalization.locale))], selection: $solar)
            }

            RowDivider()
            formRawRow(label: String(localized: "类型", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) {
                SegPicker(options: [(false, String(localized: "一次", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
                                    (true, String(localized: "每年", bundle: AppLocalization.bundle, locale: AppLocalization.locale))], selection: $recurring)
            }

            RowDivider()
            Button {
                showReminderSettings = true
            } label: {
                formRawRow(label: String(localized: "提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) {
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
                    .accessibilityIdentifier("dayLocationField")
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
            if !store.categories.contains(where: { $0.id == categoryID }) {
                let name = selectedCategory?.displayName ?? initialDay.categoryDisplayName
                let label = name.isEmpty ? String(localized: "未知分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : name
                let status = selectedCategory == nil
                    ? String(localized: "未同步", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "不可用", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                Chip(String(localized: "\(label)（\(status)）", bundle: AppLocalization.bundle, locale: AppLocalization.locale), selected: true, leading: {
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 14))
                })
                .disabled(true)
                .accessibilityLabel("分类 \(label)，\(status)")
                .accessibilityIdentifier("unavailableDayCategory")
            }
            ForEach(store.categories) { category in
                Chip(category.displayName, selected: categoryID == category.id) {
                    Image(systemName: category.symbolName)
                        .font(.system(size: 14))
                } action: {
                    selectedCategory = category
                }
                .accessibilityLabel("分类 \(category.displayName)")
                .accessibilityIdentifier("dayCategory-\(category.id)")
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
                .accessibilityIdentifier("dayNoteEditor")
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
                    .accessibilityIdentifier("cancelDayDatePicker")
                Spacer()
                Text(solar ? String(localized: "选择日期", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "选择农历日期", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(16, weight: .bold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dayDatePickerTitle")
                Spacer()
                Button("完成") {
                    selectedDate = draftDate
                    showDatePicker = false
                }
                    .font(Theme.sans(15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("confirmDayDatePicker")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            if solar {
                DatePicker("选择日期", selection: $draftDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, AppLocalization.locale)
                    .environment(\.calendar, CNDate.calendar)
                    .environment(\.timeZone, CNDate.calendar.timeZone)
                    .tint(Theme.ink)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("daySolarDatePicker")
            } else {
                LunarDatePicker(selection: $draftDate)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents(dynamicTypeSize > .large ? [.large] : [.medium, .large])
    }

    // MARK: - Save

    private var reminderSummary: String {
        guard let offsets = reminderOffsets else { return String(localized: "跟随全局设置", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        let selected = Set(offsets)
        if selected.isEmpty { return String(localized: "不提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        if selected.count == 1, let offset = selected.first {
            return offset == 0 ? String(localized: "当天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "提前 \(offset) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        return String(localized: "自定义（\(selected.count)次）", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
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

        let saved = editingDay == nil ? store.add(new) : store.update(new)
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

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

}
