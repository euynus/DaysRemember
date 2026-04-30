import SwiftUI

struct AddDayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DayStore

    @State private var title: String = "毕业十周年"
    @State private var category: DayCategory = .life
    @State private var photo: PhotoStyle = .study
    @State private var recurring: Bool = true
    @State private var solar: Bool = true
    @State private var remindIndex: Int = 3
    @State private var selectedDate: Date = {
        var c = DateComponents(); c.year = 2027; c.month = 6; c.day = 20
        return CNDate.calendar.date(from: c) ?? Date()
    }()

    private let pickerOptions: [PhotoStyle] = [.wedding, .baby, .birthday, .japan, .study, .work, .pet, .home]
    private let reminders = ["当天", "1天", "3天", "7天"]

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
            Button("保存") {
                let new = Day(id: UUID().uuidString, title: title, date: selectedDate,
                              recurring: recurring, lunar: !solar, category: category,
                              photo: photo)
                store.add(new)
                dismiss()
            }
            .font(Theme.sans(15, weight: .semibold))
            .foregroundStyle(Theme.terracotta)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var coverEditor: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoTile(style: photo, cornerRadius: 22)
                .frame(height: 180)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.label.uppercased())
                    .font(Theme.sans(10))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.8))
                TextField("", text: $title)
                    .font(Theme.serif(22, weight: .semibold))
                    .foregroundStyle(.white)
                    .tint(.white)
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
                        Button { photo = p } label: {
                            PhotoTile(style: p, flat: true, cornerRadius: 14)
                                .frame(width: 56, height: 56)
                                .overlay {
                                    if photo == p {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Theme.terracotta, lineWidth: 2.5)
                                            .padding(-3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    addPhotoTile
                }
            }
        }
    }

    private var addPhotoTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(Theme.hairlineStrong)
            Text("+").font(.system(size: 22)).foregroundStyle(Theme.muted)
        }
        .frame(width: 56, height: 56)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var formCard: some View {
        InsetCard(radius: 18) {
            FormRow(label: "日期") {
                Text("2027 年 6 月 20 日 · 农历 五月十六")
                    .font(Theme.sans(14)).foregroundStyle(Theme.ink2)
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
            FormRow(label: "提醒", isLast: true) {
                HStack(spacing: 6) {
                    ForEach(reminders.indices, id: \.self) { i in
                        Button {
                            remindIndex = i
                        } label: {
                            Text(reminders[i])
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
        Text("写下这一天的心情…")
            .font(Theme.serif(14).italic())
            .lineSpacing(14 * 0.7)
            .foregroundStyle(Theme.ink2)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .padding(16)
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
