import SwiftUI

struct DetailView: View {
    @EnvironmentObject var store: DayStore
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

        ZStack {
            Color.black.ignoresSafeArea()

            // Background photo + scrim
            ZStack {
                PhotoTile(day: day, flat: true, cornerRadius: 0)
                LinearGradient(
                    colors: [
                        .black.opacity(0.35),
                        .black.opacity(0.10),
                        .black.opacity(0.85),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topControls
                Spacer()
                counter(day: day, info: info)
                Spacer()
                infoCard(day: day, info: info)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 46)
            }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showShare) {
            ShareCardView(day: currentDay)
        }
        .sheet(isPresented: $showEditor) {
            DayEditorView(day: currentDay)
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

    private var topControls: some View {
        HStack {
            GlassButton(accessibilityLabel: "返回") { dismiss() } content: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
            }
            Spacer()
            HStack(spacing: 8) {
                GlassButton(accessibilityLabel: currentDay.pinned ? "取消置顶" : "置顶", action: togglePinned) {
                    Image(systemName: currentDay.pinned ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .semibold))
                }
                Menu {
                    Button("编辑", systemImage: "pencil") { showEditor = true }
                    Button("分享", systemImage: "square.and.arrow.up") { showShare = true }
                    Button("删除", systemImage: "trash", role: .destructive) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .glassCircle()
                }
                .accessibilityLabel("更多操作")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 62)
    }

    private func togglePinned() {
        var updated = currentDay
        updated.pinned.toggle()
        Haptics.impact(.soft)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            store.update(updated)
        }
    }

    private func counter(day: Day, info: DayInfo) -> some View {
        VStack(spacing: 0) {
            Text(day.categoryLabel.uppercased())
                .font(Theme.sans(11))
                .tracking(3.3)
                .foregroundStyle(Color.white.opacity(0.8))
                .padding(.bottom, 10)
            Text(day.title)
                .font(Theme.serif(28, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text("\(info.days)")
                .font(Theme.serif(120, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 28)
                .padding(.bottom, 6)
            Text("\(info.label) · 天")
                .font(Theme.sans(14))
                .tracking(3.5)
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        // Read the whole counter as one natural sentence instead of four fragments
        // ("category", "title", "132", "还有 · 天").
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(day.title)，\(day.categoryLabel)，"
            + (info.isToday ? "就是今天" : "\(info.label) \(info.days) 天")
        )
    }

    private func infoCard(day: Day, info: DayInfo) -> some View {
        VStack(spacing: 0) {
            InfoRow(label: "日期",
                    value: "\(CNDate.full(info.displayDate)) · \(CNDate.weekday(info.displayDate))")
            InfoRow(label: "农历", value: Lunar.fmtFull(info.displayDate))
            if let term = SolarTerms.name(for: info.displayDate) {
                InfoRow(label: "节气", value: term)
            }
            if let h = SolarTerms.lunarHoliday(for: info.displayDate) {
                InfoRow(label: "传统节日", value: h)
            }
            if day.lunar {
                InfoRow(label: "按农历重复", value: "每年农历相同日期")
            }
            if !day.location.isEmpty {
                InfoRow(label: "地点", value: day.location)
            }
            if day.recurring {
                let n = (info.yearsAgo ?? 0) + (info.isPast ? 0 : 1)
                InfoRow(label: "重复", value: "每年 · 第 \(n) 次")
            }
            if !day.note.isEmpty {
                Divider().background(Color.white.opacity(0.2)).padding(.top, 12)
                Text("\u{201C}\(day.note)\u{201D}")
                    .font(Theme.serif(14).italic())
                    .lineSpacing(14 * 0.7)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.32))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.sans(13))
                .foregroundStyle(Color.white.opacity(0.65))
            Spacer()
            Text(value)
                .font(Theme.sans(13, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 5)
    }
}
