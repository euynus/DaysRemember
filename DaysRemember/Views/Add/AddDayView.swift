import SwiftUI
import PhotosUI

struct AddDayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DayStore

    @State private var title: String = ""
    @State private var category: DayCategory = .life
    @State private var photo: PhotoStyle = .study
    @State private var photoData: Data? = nil
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var recurring: Bool = true
    @State private var solar: Bool = true
    @State private var remindIndex: Int = 3
    @State private var selectedDate: Date = Today.date
    @State private var note: String = ""
    @State private var location: String = ""

    private let pickerOptions: [PhotoStyle] = [.wedding, .baby, .birthday, .japan, .study, .work, .pet, .home]
    private let reminders: [(label: String, offset: Int)] = [
        ("当天", 0), ("1天", 1), ("3天", 3), ("7天", 7)
    ]

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    coverEditor.padding(.bottom, 18)
                    photoStrip.padding(.bottom, 22)
                    formCard.padding(.bottom, 16)
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
                .font(Theme.sans(15, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .buttonStyle(.plain)
            Spacer()
            Text("新的日子").font(Theme.serif(17, weight: .semibold)).foregroundStyle(Theme.ink)
            Spacer()
            Button("保存", action: saveDay)
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.terracotta)
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private func saveDay() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let new = Day(
            id: UUID().uuidString,
            title: cleanTitle,
            date: selectedDate,
            recurring: recurring,
            lunar: !solar,
            category: category,
            photo: photo,
            photoData: photoData,
            reminderOffsets: [reminders[remindIndex].offset],
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        store.add(new)
        dismiss()
    }

    private var coverEditor: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoTile(style: photo, imageData: photoData, cornerRadius: 22)
                .frame(height: 180)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.label.uppercased())
                    .font(Theme.sans(10))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.8))
                TextField("日子名称", text: $title)
                    .font(Theme.serif(22, weight: .semibold))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .submitLabel(.done)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.4))
                            .frame(height: 1)
                            .offset(y: 4)
                    }
            }
            .padding(16)
        }
    }

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "封面")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pickerOptions, id: \.self) { p in
                        Button {
                            photo = p
                            photoData = nil // reverting to a preset clears any picked image
                        } label: {
                            PhotoTile(style: p, flat: true, cornerRadius: 14)
                                .frame(width: 56, height: 56)
                                .overlay {
                                    if photo == p && photoData == nil {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Theme.terracotta, lineWidth: 2.5)
                                            .padding(-3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    photosPickerTile
                }
            }
        }
    }

    private var photosPickerTile: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let data = photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.terracotta, lineWidth: 2.5)
                                .padding(-3)
                        }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Theme.hairlineStrong)
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Theme.muted)
                    }
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .frame(width: 56, height: 56)
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        photoData = compressedJPEGData(from: data) ?? data
                    }
                }
            }
        }
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

    private var formCard: some View {
        InsetCard(radius: 18) {
            FormRow(label: "日期") {
                VStack(alignment: .trailing, spacing: 4) {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("农历 \(Lunar.fmt(selectedDate))")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.muted)
                }
            }
            FormRow(label: "日历") {
                SegBtnPair(leftLabel: "公历", rightLabel: "农历", leftSelected: $solar)
            }
            FormRow(label: "类型") {
                let recurringBinding = Binding<Bool>(
                    get: { !recurring }, set: { recurring = !$0 }
                )
                SegBtnPair(leftLabel: "一次", rightLabel: "每年", leftSelected: recurringBinding)
            }
            FormRow(label: "地点") {
                TextField("可选", text: $location)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
            }
            FormRow(label: "提醒", isLast: true) {
                HStack(spacing: 6) {
                    ForEach(reminders.indices, id: \.self) { i in
                        Button {
                            remindIndex = i
                        } label: {
                            Text(reminders[i].label)
                                .font(Theme.sans(12, weight: .medium))
                                .foregroundStyle(remindIndex == i ? Theme.bg : Theme.ink2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(remindIndex == i ? Theme.ink : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var categoryPills: some View {
        FlowLayout(spacing: 8) {
            ForEach(DayCategory.allCases, id: \.self) { c in
                Button { category = c } label: {
                    Text(c.label)
                        .font(Theme.sans(13, weight: .medium))
                        .foregroundStyle(category == c ? Theme.bg : Theme.ink2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(category == c ? Theme.ink : Theme.card)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notesCard: some View {
        ZStack(alignment: .topLeading) {
            if note.isEmpty {
                Text("写下这一天的心情…")
                    .font(Theme.serif(14).italic())
                    .foregroundStyle(Theme.muted)
                    .padding(16)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $note)
                .font(Theme.serif(14).italic())
                .lineSpacing(14 * 0.7)
                .foregroundStyle(Theme.ink2)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, minHeight: 90)
                .padding(12)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Minimal flow layout for wrap-on-overflow chip rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxW, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x - bounds.minX + s.width > maxW {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
