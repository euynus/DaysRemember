import SwiftUI

struct DetailView: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let dayID: String
    /// The last value shown, so a pop animation after deletion never renders an empty screen.
    @State private var snapshot: Day?
    @State private var showShare = false
    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var deletedHere = false

    init(dayID: String) {
        self.dayID = dayID
    }

    init(day: Day) {
        dayID = day.id
        _snapshot = State(initialValue: day)
    }

    private var liveDay: Day? {
        store.days.first(where: { $0.id == dayID })
    }

    var body: some View {
        if let day = liveDay ?? snapshot {
            content(day)
                .onAppear { snapshot = liveDay ?? snapshot }
                .onChange(of: liveDay) { _, live in
                    if let live { snapshot = live }
                }
                // A sync from another device can delete the day while it is open here.
                .onChange(of: liveDay == nil) { _, missing in
                    if missing && !deletedHere { dismiss() }
                }
        } else {
            ContentUnavailableView("日子已删除", systemImage: "calendar")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg.ignoresSafeArea())
        }
    }

    private var currentDay: Day {
        liveDay ?? snapshot ?? Day(id: dayID, title: "", date: Today.date, category: .life, photo: .systemDefault)
    }

    @ViewBuilder
    private func content(_ day: Day) -> some View {
        let info = DayInfo.compute(day, today: today)

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .aspectRatio(1.5, contentMode: .fit)
                        .overlay { PhotoTile(day: day, flat: true, cornerRadius: 0) }
                    VStack(alignment: .leading, spacing: 20) {
                        titleBlock(day: day)
                        hero(day: day, info: info)
                        RowDivider()
                        if !day.note.isEmpty { linedNote(day.note) }
                        infoChips(day: day, info: info)
                        Button { showShare = true } label: {
                            Label("分享这一天", systemImage: "square.and.arrow.up")
                                .font(Theme.sans(15, weight: .medium))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                    }
                    .padding(24)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        // The native bar keeps the system back button, and with it the edge swipe.
        .toolbar { toolbarItems(day: day) }
        .toolbarRole(.editor)
        .navigationBarTitleDisplayMode(.inline)
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
                deletedHere = true
                store.delete(currentDay)
                if liveDay == nil { dismiss() } else { deletedHere = false }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后会取消它的待提醒；30 天内可在「最近删除」中恢复。")
        }
    }

    // MARK: - Toolbar (pin + more)

    @ToolbarContentBuilder
    private func toolbarItems(day: Day) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: togglePinned) {
                Label(day.pinned ? String(localized: "取消置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                          : String(localized: "置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                      systemImage: day.pinned ? "star.fill" : "star")
            }
            .accessibilityAddTraits(day.pinned ? .isSelected : [])
            Menu {
                Button("编辑", systemImage: "pencil") { showEditor = true }
                Button("分享", systemImage: "square.and.arrow.up") { showShare = true }
                Button("删除", systemImage: "trash", role: .destructive) { showDeleteConfirm = true }
            } label: {
                Label("更多操作", systemImage: "ellipsis")
            }
            .accessibilityIdentifier("detail.moreActions")
        }
    }

    private func togglePinned() {
        var updated = currentDay
        updated.pinned.toggle()
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) {
            _ = store.update(updated)
        }
    }

    // MARK: - Title + meta

    private func titleBlock(day: Day) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: day.title)
                .font(Theme.sans(28, weight: .medium, relativeTo: .title))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("detail.title")
            MetaRow(metaItems(day: day))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaItems(day: Day) -> [String] {
        let date = CNDate.full(day.date)
        var items = [day.recurring ? String(localized: "原始日期 \(date)", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : date, CNDate.weekday(day.date)]
        if day.recurring { items.append(String(localized: "每年", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) }
        return items
    }

    private func hero(day: Day, info: DayInfo) -> some View {
        let countdownLabel = info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : info.isPast ? String(localized: "\(info.days) 天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(info.days) 天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        return VStack(alignment: .leading, spacing: 14) {
            if day.recurring {
                VStack(alignment: .leading, spacing: 6) {
                    if let number = info.anniversaryNumber, number > 0 {
                        Text(info.isToday ? String(localized: "本次 · 第\(number)周年", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                             : String(localized: "下一次 · 第\(number)周年", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    } else {
                        Text("起始日")
                    }
                    Text(CNDate.full(info.displayDate))
                }
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink2)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : info.days.formatted())
                    .font(info.isToday ? Theme.sans(44) : Theme.number(92))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !info.isToday {
                    Text(info.countdownUnit)
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(countdownLabel)
            .accessibilityIdentifier("detail.countdown")
            if day.recurring, let elapsedDays = info.elapsedDays {
                Text("已过 \(elapsedDays) 天")
                    .font(Theme.sans(16, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func linedNote(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("记忆", systemImage: "text.alignleft")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.accent)
            Text(verbatim: text)
                .font(Theme.sans(16))
                .lineSpacing(6)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
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
            if day.lunar {
                InfoChip(systemName: "moon", text: String(localized: "农历重复", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            }
        }
    }

}
