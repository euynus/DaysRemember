import SwiftUI

// Scrapbook detail page — port of `screens/Detail.jsx`. The cool paper canvas, a
// tilted hero polaroid with a clipped countdown sticky + washi tape, an optional
// lined-paper handwritten note, info chips, and a memories strip. All edit /
// share / pin / delete wiring is preserved from the prior implementation.
struct DetailView: View {
    @Environment(DayStore.self) var store
    @Environment(\.dismiss) private var dismiss
    let day: Day
    @State private var showShare = false
    @State private var showEditor = false
    @State private var showDeleteConfirm = false

    private var currentDay: Day {
        store.days.first(where: { $0.id == day.id }) ?? day
    }

    var body: some View {
        let day = currentDay
        let info = DayInfo.compute(day)

        VStack(spacing: 0) {
            topBar
            titleBlock(day: day, info: info)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero(day: day, info: info)

                    if !day.note.isEmpty {
                        linedNote(day.note)
                            .padding(.top, 26)
                    }

                    infoChips(day: day, info: info)
                        .padding(.top, 22)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .sensoryFeedback(.impact(flexibility: .soft), trigger: day.pinned)
        .sheet(isPresented: $showShare) {
            ShareCardView(day: currentDay)
        }
        .sheet(isPresented: $showEditor) {
            DayEditorView(day: currentDay).environment(store)
        }
        .confirmationDialog("删除这个日子？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                Haptics.warning()
                store.delete(currentDay)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后会同时取消这个日子的待提醒。")
        }
    }

    // MARK: - Top bar (back + pin + more)

    private var topBar: some View {
        HStack(alignment: .top) {
            FAB(systemName: "chevron.left", action: { dismiss() })
                .accessibilityLabel("返回")
            Spacer()
            HStack(spacing: 8) {
                FAB(systemName: currentDay.pinned ? "star.fill" : "star", action: togglePinned)
                    .accessibilityLabel(currentDay.pinned ? "取消置顶" : "置顶")
                Menu {
                    Button("编辑", systemImage: "pencil") { showEditor = true }
                    Button("分享", systemImage: "square.and.arrow.up") { showShare = true }
                    Button("删除", systemImage: "trash", role: .destructive) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.white))
                        .floatShadow()
                }
                .accessibilityLabel("更多操作")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 58)
        .padding(.bottom, 6)
    }

    private func togglePinned() {
        var updated = currentDay
        updated.pinned.toggle()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            store.update(updated)
        }
    }

    // MARK: - Title + meta

    private func titleBlock(day: Day, info: DayInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day.title)
                .font(Theme.sans(32, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            MetaRow(metaItems(day: day, info: info))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func metaItems(day: Day, info: DayInfo) -> [String] {
        var items = [CNDate.full(info.displayDate), CNDate.weekday(info.displayDate)]
        if day.recurring { items.append("每年") }
        return items
    }

    // MARK: - Hero polaroid + countdown sticky + tape

    private func hero(day: Day, info: DayInfo) -> some View {
        let nc = noteColorFor(day.id)
        let countLabel = info.isToday ? "今天" : (info.isPast ? "天前" : "天后")

        return ZStack(alignment: .topLeading) {
            // Polaroid card
            VStack(spacing: 0) {
                PhotoTile(day: day, cornerRadius: 12)
                    .frame(height: 280)
                HStack {
                    Text(enDate(info.displayDate))
                        .font(Theme.hand(26))
                        .foregroundStyle(Theme.ink2)
                    Spacer()
                    Sticker(name: stickerFor(day), size: 42, rotate: 8)
                }
                .padding(.top, 12)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            }
            .polaroidCard(rotation: -1.5)
            .padding(.top, 8)

            // Washi tape (top-left)
            Tape(color: Color(.sRGB, red: 180/255, green: 221/255, blue: 240/255, opacity: 0.75), width: 70)
                .rotationEffect(.degrees(-6))
                .offset(x: 24, y: -2)

            // Countdown sticky (top-right, clipped)
            StickyNote(color: nc.paper, ink: nc.ink, rotate: 6, clip: true, size: .l) {
                VStack(spacing: 0) {
                    Text("\(info.days)")
                        .font(Theme.sans(48, weight: .bold))
                        .monospacedDigit()
                    Text(countLabel)
                        .font(Theme.handCN(18))
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 10)
            .offset(y: -2)
        }
    }

    // MARK: - Lined-paper handwritten note

    private func linedNote(_ text: String) -> some View {
        ZStack(alignment: .top) {
            Text(text)
                .font(Theme.handCN(21))
                .lineSpacing(28 - 21)
                .foregroundStyle(Color(hex: 0x3A3A3A))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .background(
                    RuledLines()
                        .background(Color(hex: 0xFFFDF6))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(hex: 0x15171C).opacity(0.06), radius: 1, x: 0, y: 1)
                .shadow(color: Color(hex: 0x15171C).opacity(0.08), radius: 10, x: 0, y: 8)
                .rotationEffect(.degrees(0.4))

            Paperclip().offset(y: -10)
        }
    }

    // MARK: - Info chips (wrap)

    private func infoChips(day: Day, info: DayInfo) -> some View {
        FlowLayout(spacing: 10) {
            if !day.location.isEmpty {
                InfoChip(systemName: "mappin.and.ellipse", text: day.location)
            }
            InfoChip(systemName: "moon", text: Lunar.fmt(info.displayDate))
            if let term = SolarTerms.name(for: info.displayDate) {
                InfoChip(systemName: "leaf", text: term)
            }
            if day.recurring {
                InfoChip(systemName: "arrow.triangle.2.circlepath", text: "第 \(info.anniversaryNumber ?? 1) 次")
            }
            if day.lunar {
                InfoChip(systemName: "moon", text: "农历重复")
            }
        }
    }

}

/// Repeating horizontal rule lines for the lined-paper note background
/// (the `repeating-linear-gradient` in Detail.jsx).
private struct RuledLines: View {
    var spacing: CGFloat = 28
    var body: some View {
        GeometryReader { geo in
            Path { p in
                var y = spacing
                while y < geo.size.height {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(Color(hex: 0x15171C).opacity(0.06), lineWidth: 1)
        }
    }
}
