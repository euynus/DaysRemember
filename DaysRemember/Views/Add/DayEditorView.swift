import SwiftUI
import PhotosUI

// Scrapbook add/edit composer — a faithful port of `screens/Add.jsx`. DayEditorView
// is the shared form; AddDayView wraps it. Every wire from the previous version is
// preserved: title, category, cover (preset PhotoStyle + PhotosPicker + focus drag),
// date, solar/lunar, recurring, per-day reminder offset, note, location, save / cancel.
struct DayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DayStore.self) var store

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
    @State private var dragStartX: Double?
    @State private var dragStartY: Double?
    @State private var showDatePicker = false

    private static let pickerOptions: [PhotoStyle] = [
        .wedding, .baby, .birthday, .japan, .study, .work, .pet, .home,
    ] + PhotoStyle.categorySketchPresets
    private static let reminders: [(label: String, offset: Int)] = [
        ("当天", 0), ("1天", 1), ("3天", 3), ("7天", 7)
    ]

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

    // Preview-only countdown for the live polaroid sticky note.
    private var previewInfo: DayInfo {
        DayInfo.compute(Day(
            id: editingDay?.id ?? "preview",
            title: title,
            date: selectedDate,
            recurring: recurring,
            lunar: !solar,
            category: .life,
            photo: photo
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    livePreview
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 26)

                    SectionHeader("标题").padding(.bottom, 10)
                    titleField.padding(.bottom, 22)

                    SectionHeader("封面").padding(.bottom, 10)
                    coverPicker.padding(.bottom, 22)

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
        .sensoryFeedback(.selection, trigger: photo)
        .sensoryFeedback(.selection, trigger: remindIndex)
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

            PillButton(title: "保存", style: .dark, height: 38, action: saveDay)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    // MARK: - Live preview polaroid

    private var livePreview: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                PhotoTile(style: photo, imageData: photoData,
                          focusX: coverFocusX, focusY: coverFocusY,
                          flat: true, cornerRadius: 12)
                    .frame(width: 194, height: 200)
                    .overlay(alignment: .center) {
                        if photoData != nil {
                            Circle()
                                .strokeBorder(.white.opacity(0.85), lineWidth: 1)
                                .background(Circle().fill(.black.opacity(0.18)))
                                .frame(width: 18, height: 18)
                                .allowsHitTesting(false)
                        }
                    }
                    .gesture(focusDrag)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title.isEmpty ? "新的日子" : title)
                        .font(Theme.sans(16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(enDate(previewInfo.displayDate))
                        .font(Theme.hand(20))
                        .foregroundStyle(Theme.ink2)
                }
                .frame(width: 194, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 10)
                .padding(.bottom, 2)
            }
            .polaroidCard(rotation: -1.5)
            .overlay(alignment: .bottomLeading) {
                Sticker(name: stickerForCurrentCategory, size: 36, rotate: -10)
                    .offset(x: 14, y: 6)
            }

            // Countdown sticky note, clipped top-right (Add.jsx: note-blue, rotate 7).
            countdownNote
                .offset(x: 92, y: -6)
        }
        .frame(width: 240, height: 280)
    }

    private var countdownNote: some View {
        StickyNote(color: Theme.noteBlue, ink: Theme.noteBlueInk, rotate: 7, clip: true, size: .s) {
            VStack(spacing: 0) {
                Text("\(abs(previewInfo.days))")
                    .font(Theme.sans(26, weight: .bold))
                    .monospacedDigit()
                Text(previewInfo.isToday ? "今天" : (previewInfo.isPast ? "天前" : "天后"))
                    .font(Theme.handCN(15))
            }
            .foregroundStyle(Theme.noteBlueInk)
        }
    }

    private var stickerForCurrentCategory: StickerName {
        if let cat = DayCategory(rawValue: categoryID) {
            return StickerMap.byCategory[cat] ?? .star
        }
        return .star
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
            .font(Theme.sans(17, weight: .bold))
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
            .submitLabel(.done)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
            .shadow(color: Color(hex: 0x15171C).opacity(0.05), radius: 1, x: 0, y: 1)
            .accessibilityLabel("日子名称")
    }

    // MARK: - Cover picker

    private var coverPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.pickerOptions, id: \.self) { preset in
                    Button {
                        photo = preset
                        photoData = nil
                        resetFocus()
                    } label: {
                        miniPolaroid(selected: photo == preset && photoData == nil) {
                            PhotoTile(style: preset, flat: true, cornerRadius: 8)
                                .frame(width: 50, height: 50)
                        }
                    }
                    .buttonStyle(PressScale(scale: 0.95))
                    .accessibilityLabel("选择\(preset.displayName)封面")
                    .accessibilityAddTraits(photo == preset && photoData == nil ? [.isSelected] : [])
                }
                photosPickerTile
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 1)
        }
    }

    /// White mini polaroid card (~58 wide) with a 3pt ink outline when selected.
    private func miniPolaroid<Content: View>(selected: Bool,
                                             @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Theme.ink : Color.clear, lineWidth: 3)
            }
            .shadow(color: Color(hex: 0x15171C).opacity(0.06), radius: 2, x: 0, y: 2)
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
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                        .shadow(color: Color(hex: 0x15171C).opacity(0.05), radius: 1, x: 0, y: 1)
                }
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

    // MARK: - Form list

    private var formCard: some View {
        CardList {
            // 日期 → opens the date picker sheet.
            Button { showDatePicker = true } label: {
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
                HStack(spacing: 6) {
                    reminderChip(label: "默认", selected: remindIndex < 0) { remindIndex = -1 }
                    ForEach(Self.reminders.indices, id: \.self) { index in
                        reminderChip(label: Self.reminders[index].label,
                                     selected: remindIndex == index) { remindIndex = index }
                    }
                }
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
        HStack(spacing: 14) {
            Text(label).font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            content()
        }
        .cardRow()
    }

    /// Small selectable reminder chip (ink fill when selected, like the JSX seg buttons).
    private func reminderChip(label: String, selected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.sans(12, weight: .bold))
                .foregroundStyle(selected ? Color.white : Theme.ink2)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? Theme.ink : Theme.bg2)
                )
        }
        .buttonStyle(PressScale(scale: 0.94))
        .accessibilityLabel(label == "默认" ? "默认提醒，跟随全局设置" : "提醒\(label)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Category pills

    private var categoryPills: some View {
        FlowLayout(spacing: 8) {
            ForEach(store.categories) { category in
                Chip(category.name, selected: categoryID == category.id) {
                    Sticker(name: stickerForCategory(category), size: 18)
                } action: {
                    categoryID = category.id
                }
                .accessibilityLabel("分类 \(category.name)")
                .accessibilityAddTraits(categoryID == category.id ? [.isSelected] : [])
            }
        }
    }

    private func stickerForCategory(_ category: CategoryDefinition) -> StickerName {
        if let cat = DayCategory(rawValue: category.id) {
            return StickerMap.byCategory[cat] ?? .star
        }
        return .star
    }

    // MARK: - Notes card (lined paper)

    private var notesCard: some View {
        ZStack(alignment: .topLeading) {
            if note.isEmpty {
                Text("写下这一天的心情…")
                    .font(Theme.handCN(20))
                    .foregroundStyle(Theme.muted)
                    .padding(16)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $note)
                .font(Theme.handCN(20))
                .foregroundStyle(Theme.ink)
                .tint(Theme.ink)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, minHeight: 92)
                .padding(12)
                .accessibilityLabel("心情笔记")
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0xFFFDF6))
                .overlay(LinedPaper().clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
        )
        .shadow(color: Color(hex: 0x15171C).opacity(0.06), radius: 1, x: 0, y: 1)
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
                Button("完成") { showDatePicker = false }
                    .font(Theme.sans(15, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.ink)
                .labelsHidden()
                .padding(.horizontal, 16)

            if !solar {
                Text("农历 \(Lunar.fmtFull(selectedDate))")
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

/// Repeating ruled lines for the mood-note card (Add.jsx repeating-linear-gradient).
private struct LinedPaper: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 28
            var y: CGFloat = spacing
            let line = Color(hex: 0x15171C).opacity(0.06)
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(line), lineWidth: 1)
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
