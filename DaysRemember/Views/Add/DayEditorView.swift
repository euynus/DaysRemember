import SwiftUI
import PhotosUI

// Shared add/edit form. Changes remain local until Save.
struct DayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DayStore.self) var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let editingDay: Day?
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
    @State private var selectedDate: Date
    @State private var draftDate: Date
    @State private var note: String
    @State private var location: String
    @State private var coverFocusX: Double
    @State private var coverFocusY: Double
    @State private var dragStartX: Double?
    @State private var dragStartY: Double?
    @State private var showDatePicker = false

    private static let pickerOptions: [PhotoStyle] = [
        .systemDefault, .birthday, .japan, .study, .home,
    ]
    private static let reminders: [(label: String, offset: Int)] = [
        ("当天", 0), ("1天", 1), ("3天", 3), ("7天", 7)
    ]

    init(day: Day? = nil) {
        editingDay = day
        _title = State(initialValue: day?.title ?? "")
        _categoryID = State(initialValue: day?.categoryID ?? DayCategory.life.rawValue)
        _photo = State(initialValue: day?.photo ?? .systemDefault)
        _photoData = State(initialValue: day?.photoData)
        _recurring = State(initialValue: day?.recurring ?? true)
        _solar = State(initialValue: !(day?.lunar ?? false))
        _selectedDate = State(initialValue: day?.date ?? Today.date)
        _draftDate = State(initialValue: day?.date ?? Today.date)
        _note = State(initialValue: day?.note ?? "")
        _location = State(initialValue: day?.location ?? "")
        _coverFocusX = State(initialValue: day?.coverFocusX ?? 0.5)
        _coverFocusY = State(initialValue: day?.coverFocusY ?? 0.5)
        _reminderOffsets = State(initialValue: day?.reminderOffsets)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingPhoto
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    titleField.padding(.top, 12).padding(.bottom, 22)
                    livePreview
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    coverPicker.padding(.bottom, 28)

                    formCard.padding(.bottom, 22)

                    SectionHeader("分类").padding(.bottom, 10)
                    categoryPills.padding(.bottom, 22)

                    SectionHeader("心情笔记").padding(.bottom, 10)
                    notesCard
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
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
            Button("取消") { dismiss() }
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
                            PhotoTile(style: preset, flat: true, cornerRadius: 8)
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
                if let data = photoData, let ui = UIImage(data: data) {
                    miniPolaroid(selected: true) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                guard let data = try await item.loadTransferable(type: Data.self),
                      let compressed = compressedJPEGData(from: data) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try Task.checkCancellation()
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

            RowDivider()
            formRawRow(label: "日历") {
                SegPicker(options: [(true, "公历"), (false, "农历")], selection: $solar)
            }

            RowDivider()
            formRawRow(label: "类型") {
                SegPicker(options: [(false, "一次"), (true, "每年")], selection: $recurring)
            }

            RowDivider()
            formRawRow(label: "提醒") {
                Picker("提醒", selection: $reminderOffsets) {
                    Text("跟随全局设置").tag(Optional<[Int]>.none)
                    Text("不提醒").tag(Optional<[Int]>([]))
                    ForEach(Self.reminders.indices, id: \.self) { index in
                        Text(index == 0 ? "当天" : "提前 \(Self.reminders[index].offset) 天")
                            .tag(Optional([Self.reminders[index].offset]))
                    }
                    if let offsets = reminderOffsets, !offsets.isEmpty,
                       offsets.count != 1 || !Self.reminders.contains(where: { $0.offset == offsets[0] }) {
                        Text("自定义（\(offsets.count)次）").tag(Optional(offsets))
                    }
                }
                .tint(Theme.accent)

            }

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
                Text("选择日期").font(Theme.sans(16, weight: .bold)).foregroundStyle(Theme.ink)
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

            DatePicker("选择日期", selection: $draftDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.ink)
                .labelsHidden()
                .padding(.horizontal, 16)

            if !solar {
                Text("农历 \(Lunar.fmtFull(draftDate))")
                    .font(Theme.sans(13, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    // MARK: - Save

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
        Haptics.success()
        dismiss()
    }

    private func resetFocus() {
        coverFocusX = 0.5
        coverFocusY = 0.5
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    /// Re-encode HEIC/PNG to a reasonably sized JPEG so the Day record stays small.
    private func compressedJPEGData(from data: Data, maxDimension: CGFloat = 1600,
                                    quality: CGFloat = 0.82) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        if scale >= 1 {
            return image.jpegData(compressionQuality: quality)
        }
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
