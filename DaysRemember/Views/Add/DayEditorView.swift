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
    @State private var showPhotoPicker = false
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var showTemplateGallery = false
    /// New days follow the selected category's cover until a template or photo is picked.
    @State private var coverChosen: Bool
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
            navBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    livePreview
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    titleField.padding(.bottom, 12)
                    formCard.padding(.bottom, 22)

                    SectionHeader(String(localized: "分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    categoryPills.padding(.bottom, 22)

                    coverPicker.padding(.bottom, 28)

                    SectionHeader(String(localized: "心情笔记", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    notesCard
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
            Button(action: cancel) {
                Text("取消")
                    .font(Theme.sans(16, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
            }
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

    private func cancel() {
        if hasUnsavedChanges { confirmDiscard = true }
        else { dismiss() }
    }

    // MARK: - Cover preview

    private var previewTint: Color {
        store.categories.first(where: { $0.id == categoryID })?.tint ?? Theme.bg2
    }

    /// The day as it would look on the feed, from the current draft.
    private var previewSummary: some View {
        let draft = Day(id: "editor-preview", title: title, date: selectedDate, recurring: recurring,
                        lunar: !solar, category: .life, photo: photo)
        let info = DayInfo.compute(draft, today: Today.date)
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? String(localized: "给这一天起个名字", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : name)
                    .font(Theme.sans(18, weight: .heavy))
                    .foregroundStyle(name.isEmpty ? Theme.onPastel : Theme.ink)
                    .lineLimit(2)
                Text(recurring ? String(localized: "\(CNDate.short(info.displayDate)) · 每年", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                     : CNDate.full(info.displayDate))
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.onPastel)
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if !info.isToday { CountLabel(info: info) }
                    CountValue(info: info, size: 48)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                FlatCover(style: photo)
                    .frame(width: 112, height: 112)
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var livePreview: some View {
        Group {
            if photoData == nil {
                previewSummary
            } else {
                PhotoTile(style: photo, imageData: photoData,
                          focusX: coverFocusX, focusY: coverFocusY,
                          flat: true, cornerRadius: 26)
                    .frame(height: 200)
            }
        }
            .frame(minHeight: photoData == nil ? 150 : 200)
            .background(previewTint, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            // Lists and square widgets crop a photo narrower than this preview does, so a sideways
            // drag can change only them; the inset shows that crop.
            .overlay(alignment: .bottomTrailing) {
                if photoData != nil {
                    PhotoTile(style: photo, imageData: photoData, focusX: coverFocusX, focusY: coverFocusY,
                              flat: true, cornerRadius: 3, maximumPixelSize: 256)
                        .frame(width: 44, height: 51)
                        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white, lineWidth: 2) }
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
            // Only a photo can be reframed; otherwise the preview must not swallow scrolling.
            .gesture(focusDrag, including: photoData != nil ? .all : .subviews)
            .modifier(CoverFramingAccessibility(hasPhoto: photoData != nil, x: $coverFocusX, y: $coverFocusY))
    }

    /// The framing as VoiceOver reads it.
    static func framingDescription(x: Double, y: Double) -> String {
        String(localized: "水平 \(Int((x * 100).rounded()))%，垂直 \(Int((y * 100).rounded()))%",
               bundle: AppLocalization.bundle, locale: AppLocalization.locale)
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
                photosPickerTile
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(PhotoStyle.pickerOptions, id: \.self) { preset in
                            let selected = isTemplateSelected(preset)
                            Button {
                                selectTemplate(preset)
                            } label: {
                                VStack(spacing: 7) {
                                    miniPolaroid(selected: selected) {
                                        FlatCover(style: preset)
                                            .frame(width: 64, height: 64)
                                    }
                                    Text(preset.displayName)
                                        .font(Theme.sans(12, weight: .medium, relativeTo: .caption))
                                        .foregroundStyle(selected ? Theme.ink : Theme.ink2)
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
                .scrollIndicators(.hidden)
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
        .background(Theme.bg)
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
                Color.clear
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay { FlatCover(style: preset).padding(14) }
                    .background(previewTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(selected ? Theme.ink : .clear, lineWidth: 2.5)
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
        coverChosen = true
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
            .padding(5)
            .background(previewTint, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.ink : .clear, lineWidth: 2.5)
            }
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Theme.ink)
                        .padding(3)
                        .accessibilityHidden(true)
                }
            }
    }

    /// A button presents the picker, since `PhotosPicker`'s own label is a `@Sendable` closure that
    /// can't read the editor's state.
    private var photosPickerTile: some View {
        Button {
            showPhotoPicker = true
        } label: {
            HStack(spacing: 8) {
                if let data = photoData {
                    miniPolaroid(selected: true) {
                        PhotoTile(style: photo, imageData: data, focusX: coverFocusX, focusY: coverFocusY,
                                  flat: true, cornerRadius: 4, maximumPixelSize: 192)
                            .frame(width: 32, height: 32)
                    }
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(Theme.symbol(20))
                        .frame(minWidth: 40, minHeight: 40)
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
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images,
                      photoLibrary: .shared())
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
                coverChosen = true
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
                        .font(Theme.symbol(12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
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
                                Text(CNDate.time(hour: reminderTime.hour, minute: reminderTime.minute))
                                    .font(Theme.sans(12, weight: .medium))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(Theme.symbol(12, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .accessibilityHidden(true)
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
                        .font(Theme.symbol(14))
                })
                .disabled(true)
                .accessibilityLabel("分类 \(label)，\(status)")
                .accessibilityIdentifier("unavailableDayCategory")
            }
            ForEach(store.categories) { category in
                Chip(category.displayName, selected: categoryID == category.id) {
                    Image(systemName: category.symbolName)
                        .font(Theme.symbol(14))
                } action: {
                    selectedCategory = category
                    if !coverChosen, photoData == nil,
                       let cover = PhotoStyle.defaultCover(forCategoryID: category.id) {
                        photo = cover
                    }
                }
                .accessibilityLabel("分类 \(category.displayName)")
                .accessibilityIdentifier("dayCategory-\(category.id)")
                .accessibilityAddTraits(categoryID == category.id ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Notes card (lined paper)

    // A TextEditor rather than a vertical TextField: Return must start a new line in the note.
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
        .background(Theme.card, in: .rect(cornerRadius: 22))
    }

    // MARK: - Date picker sheet

    private func confirmDraftDate() {
        selectedDate = draftDate
        showDatePicker = false
    }

    private var datePickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button { showDatePicker = false } label: {
                    Text("取消")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("cancelDayDatePicker")
                Spacer()
                Text(solar ? String(localized: "选择日期", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "选择农历日期", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(16, weight: .bold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dayDatePickerTitle")
                Spacer()
                Button(action: confirmDraftDate) {
                    Text("完成")
                        .font(Theme.sans(15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(.rect)
                }
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
        .background(Theme.bg)
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

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

}

/// VoiceOver's version of the reframing drag: swipe up or down for the vertical position and use
/// the actions for the horizontal one. A template cover can't be reframed, so it isn't adjustable.
private struct CoverFramingAccessibility: ViewModifier {
    let hasPhoto: Bool
    @Binding var x: Double
    @Binding var y: Double

    private func step(_ value: Double, by delta: Double) -> Double { min(1, max(0, value + delta)) }

    func body(content: Content) -> some View {
        let element = content
            .accessibilityElement()
            .accessibilityLabel("封面取景")
            .accessibilityIdentifier("coverFraming")
        if hasPhoto {
            element
                .accessibilityValue(DayEditorView.framingDescription(x: x, y: y))
                .accessibilityHint(String(localized: "上下轻扫调整照片的垂直位置，用操作调整水平位置", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: y = step(y, by: -0.1)
                    case .decrement: y = step(y, by: 0.1)
                    @unknown default: break
                    }
                }
                .accessibilityAction(named: Text(String(localized: "取景向左", bundle: AppLocalization.bundle, locale: AppLocalization.locale))) {
                    x = step(x, by: -0.1)
                }
                .accessibilityAction(named: Text(String(localized: "取景向右", bundle: AppLocalization.bundle, locale: AppLocalization.locale))) {
                    x = step(x, by: 0.1)
                }
        } else {
            element.accessibilityHint(String(localized: "封面预览", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        }
    }
}
