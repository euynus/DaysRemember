import SwiftUI
import PhotosUI

struct DayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DayStore

    private let editingDay: Day?
    @State private var title: String
    @State private var categoryID: String
    @State private var photo: PhotoStyle
    @State private var photoData: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var recurring: Bool
    @State private var solar: Bool
    @State private var remindIndex: Int
    @State private var selectedDate: Date
    @State private var note: String
    @State private var location: String
    @State private var coverFocusX: Double
    @State private var coverFocusY: Double
    @State private var coverPreview: CoverPreview = .home
    @State private var dragStartX: Double?
    @State private var dragStartY: Double?

    private static let pickerOptions: [PhotoStyle] = [
        .wedding, .baby, .birthday, .japan, .study, .work, .pet, .home,
    ] + PhotoStyle.categorySketchPresets
    private static let reminders: [(label: String, offset: Int)] = [
        ("当天", 0), ("1天", 1), ("3天", 3), ("7天", 7)
    ]

    private enum CoverPreview: String, CaseIterable {
        case home, detail, share

        var label: String {
            switch self {
            case .home: return "首页"
            case .detail: return "详情"
            case .share: return "分享"
            }
        }

        var aspect: CGFloat {
            switch self {
            case .home: return 1.55
            case .detail: return 0.78
            case .share: return 0.80
            }
        }
    }

    init(day: Day? = nil) {
        editingDay = day
        _title = State(initialValue: day?.title ?? "")
        _categoryID = State(initialValue: day?.categoryID ?? DayCategory.life.rawValue)
        _photo = State(initialValue: day?.photo ?? .study)
        _photoData = State(initialValue: day?.photoData)
        _recurring = State(initialValue: day?.recurring ?? true)
        _solar = State(initialValue: !(day?.lunar ?? false))
        _selectedDate = State(initialValue: day?.date ?? Today.date)
        _note = State(initialValue: day?.note ?? "")
        _location = State(initialValue: day?.location ?? "")
        _coverFocusX = State(initialValue: day?.coverFocusX ?? 0.5)
        _coverFocusY = State(initialValue: day?.coverFocusY ?? 0.5)
        // -1 means "follow the global reminder settings" (no per-day override).
        let offset = day?.reminderOffsets?.first
        let index = offset.flatMap { value in Self.reminders.firstIndex(where: { $0.offset == value }) } ?? -1
        _remindIndex = State(initialValue: index)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    coverEditor.padding(.bottom, 14)
                    coverPreviewPicker.padding(.bottom, 18)
                    photoStrip.padding(.bottom, 22)
                    formCard.padding(.bottom, 16)
                    SectionLabel(text: "提醒").padding(.bottom, 10)
                    reminderPicker.padding(.bottom, 22)
                    SectionLabel(text: "分类").padding(.bottom, 10)
                    categoryPills.padding(.bottom, 22)
                    SectionLabel(text: "心情笔记").padding(.bottom, 10)
                    notesCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var navBar: some View {
        HStack {
            Button("取消") { dismiss() }
                .font(Theme.sans(15, weight: .medium, relativeTo: .body))
                .foregroundStyle(Theme.ink2)
                .buttonStyle(.plain)
                .navTextButton()
            Spacer()
            Text(editingDay == nil ? "新的日子" : "编辑日子")
                .font(Theme.serif(17, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button("保存", action: saveDay)
                .font(Theme.sans(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(Theme.terracotta)
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .navTextButton()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var coverEditor: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoTile(style: photo, imageData: photoData,
                      focusX: coverFocusX, focusY: coverFocusY,
                      cornerRadius: 22)
                .aspectRatio(coverPreview.aspect, contentMode: .fit)
                .overlay(alignment: .center) {
                    if photoData != nil {
                        Circle()
                            .strokeBorder(.white.opacity(0.8), lineWidth: 1)
                            .background(Circle().fill(.black.opacity(0.18)))
                            .frame(width: 18, height: 18)
                            .allowsHitTesting(false)
                    }
                }
                .gesture(focusDrag)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.category(for: categoryID).name.uppercased())
                    .font(Theme.sans(10, relativeTo: .caption))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.8))
                TextField("日子名称", text: $title,
                          prompt: Text("日子名称").foregroundStyle(.white.opacity(0.55)))
                    .font(Theme.serif(22, weight: .semibold, relativeTo: .title2))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .submitLabel(.done)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.4))
                            .frame(height: 1)
                            .offset(y: 4)
                    }
            }
            .padding(16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("封面预览")
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
                coverFocusX = clamp(startX - Double(value.translation.width / 240))
                coverFocusY = clamp(startY - Double(value.translation.height / 240))
            }
            .onEnded { _ in
                dragStartX = nil
                dragStartY = nil
            }
    }

    private var coverPreviewPicker: some View {
        HStack(spacing: 6) {
            ForEach(CoverPreview.allCases, id: \.self) { preview in
                Button {
                    if coverPreview != preview { Haptics.selection() }
                    coverPreview = preview
                } label: {
                    Text(preview.label)
                        .font(Theme.sans(12, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(coverPreview == preview ? Theme.terracotta : Theme.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(coverPreview == preview ? Theme.terracottaSoft : Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(coverPreview == preview ? Theme.terracotta.opacity(0.2) : Theme.hairline,
                                              lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preview.label)封面比例")
                .accessibilityAddTraits(coverPreview == preview ? [.isSelected] : [])
            }
        }
    }

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "封面")
            ScrollView(.horizontal, showsIndicators: false) {
                // Reserve the same 62×62 cell every item so the selected ring renders
                // on all four sides — earlier the ring was an overlay with padding(-3)
                // that the HStack/ScrollView clipped on top and bottom.
                HStack(spacing: 8) {
                    ForEach(Self.pickerOptions, id: \.self) { preset in
                        Button {
                            if photo != preset || photoData != nil { Haptics.selection() }
                            photo = preset
                            photoData = nil
                            resetFocus()
                        } label: {
                            coverChoiceTile {
                                PhotoTile(style: preset, flat: true, cornerRadius: 14)
                                    .frame(width: 56, height: 56)
                            } selected: {
                                photo == preset && photoData == nil
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("选择\(preset.displayName)封面")
                        .accessibilityAddTraits(photo == preset && photoData == nil ? [.isSelected] : [])
                    }
                    photosPickerTile
                }
                .padding(.vertical, 3)
            }
        }
    }

    /// 62×62 cell that wraps a 56×56 thumbnail and renders the selected-state ring
    /// on all four edges without overflowing into the parent layout.
    private func coverChoiceTile<Content: View>(@ViewBuilder content: () -> Content,
                                                 selected: () -> Bool) -> some View {
        ZStack {
            content()
            if selected() {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(Theme.terracotta, lineWidth: 2.5)
            }
        }
        .frame(width: 62, height: 62)
    }

    private var photosPickerTile: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            coverChoiceTile {
                if let data = photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Theme.hairlineStrong)
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(width: 56, height: 56)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } selected: {
                photoData != nil
            }
        }
        .accessibilityLabel("选择相册封面")
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                photoData = compressedJPEGData(from: data) ?? data
                resetFocus()
            }
        }
    }

    private var formCard: some View {
        InsetCard(radius: 18) {
            FormRow(label: "日期") {
                VStack(alignment: .trailing, spacing: 4) {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("农历 \(Lunar.fmt(selectedDate))")
                        .font(Theme.sans(11, relativeTo: .caption))
                        .foregroundStyle(Theme.muted)
                }
            }
            FormRow(label: "日历") {
                SegBtnPair(leftLabel: "公历", rightLabel: "农历", leftSelected: $solar)
            }
            FormRow(label: "类型") {
                SegBtnPair(leftLabel: "一次", rightLabel: "每年", leftSelected: Binding(
                    get: { !recurring },
                    set: { recurring = !$0 }
                ))
            }
            FormRow(label: "地点", isLast: true) {
                TextField("可选", text: $location)
                    .font(Theme.sans(14, relativeTo: .body))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .accessibilityLabel("地点")
            }
        }
    }

    /// Reminder offsets as wrapping chips (so 5 options never overflow), with a
    /// leading "默认" that follows the global reminder settings (remindIndex -1).
    private var reminderPicker: some View {
        FlowLayout(spacing: 8) {
            reminderChip(label: "默认", selected: remindIndex < 0) { remindIndex = -1 }
            ForEach(Self.reminders.indices, id: \.self) { index in
                reminderChip(label: Self.reminders[index].label, selected: remindIndex == index) {
                    remindIndex = index
                }
            }
        }
    }

    private func reminderChip(label: String, selected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button {
            if !selected { Haptics.selection() }
            action()
        } label: {
            Text(label)
                .font(Theme.sans(13, weight: .medium, relativeTo: .body))
                .foregroundStyle(selected ? Theme.terracotta : Theme.ink2)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? Theme.terracottaSoft : Theme.card)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(selected ? Theme.terracotta.opacity(0.24) : Theme.hairline,
                                           lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label == "默认" ? "默认提醒，跟随全局设置" : "提醒\(label)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var categoryPills: some View {
        FlowLayout(spacing: 8) {
            ForEach(store.categories) { category in
                Button {
                    if categoryID != category.id { Haptics.selection() }
                    categoryID = category.id
                } label: {
                    Label(category.name, systemImage: category.icon)
                        .font(Theme.sans(13, weight: .medium, relativeTo: .body))
                        .foregroundStyle(categoryID == category.id ? category.colorToken.color : Theme.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(categoryID == category.id ? category.colorToken.soft : Theme.card)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(categoryID == category.id ? category.colorToken.color.opacity(0.24) : Theme.hairline,
                                              lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("分类 \(category.name)")
                .accessibilityAddTraits(categoryID == category.id ? [.isSelected] : [])
            }
        }
    }

    private var notesCard: some View {
        ZStack(alignment: .topLeading) {
            if note.isEmpty {
                Text("写下这一天的心情…")
                    .font(Theme.serif(14, relativeTo: .body).italic())
                    .foregroundStyle(Theme.muted)
                    .padding(16)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $note)
                .font(Theme.serif(14, relativeTo: .body).italic())
                .lineSpacing(14 * 0.7)
                .foregroundStyle(Theme.ink2)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, minHeight: 90)
                .padding(12)
                .accessibilityLabel("心情笔记")
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
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
            reminderOffsets: remindIndex < 0 ? nil : [Self.reminders[remindIndex].offset],
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
