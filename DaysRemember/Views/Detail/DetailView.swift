import SwiftUI

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

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock(day: day, info: info)
                        .padding(.bottom, 24)
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
        .padding(.top, 12)
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
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            MetaRow(metaItems(day: day, info: info))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func metaItems(day: Day, info: DayInfo) -> [String] {
        var items = [CNDate.full(info.displayDate), CNDate.weekday(info.displayDate)]
        if day.recurring { items.append("每年") }
        return items
    }

    private func hero(day: Day, info: DayInfo) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(info.isToday ? "今天" : "\(info.days)")
                    .font(Theme.sans(info.isToday ? 48 : 72, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !info.isToday {
                    Text(info.isPast ? "天前" : "天后")
                        .font(Theme.sans(18))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 0)
            }
            PhotoTile(day: day, flat: true, cornerRadius: 8)
                .frame(height: 260)
        }
    }

    private func linedNote(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("记忆", systemImage: "text.alignleft")
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(Theme.sans(17))
                .lineSpacing(6)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 16)
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
