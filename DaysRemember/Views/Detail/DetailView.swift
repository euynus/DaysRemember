import SwiftUI

struct DetailView: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.editDay) private var editDay
    let dayID: String
    /// The last value shown, so a pop animation after deletion never renders an empty screen.
    @State private var snapshot: Day?
    @State private var showShare = false
    @State private var showDeleteConfirm = false
    @State private var deletedHere = false
    @State private var unit: CountdownUnit = .days

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
                .background(Theme.bg)
        }
    }

    private var currentDay: Day {
        liveDay ?? snapshot ?? Day(id: dayID, title: "", date: Today.date, category: .life, photo: .systemDefault)
    }

    @ViewBuilder
    private func content(_ day: Day) -> some View {
        let info = DayInfo.compute(day, today: today)
        let category = store.category(for: day)
        let tint = info.isPast ? Theme.memory : category.tint
        let ink = info.isPast ? Theme.memoryInk : category.tintInk

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    cover(day: day, tint: tint)
                    titleBlock(day: day, info: info, category: category, tint: tint, ink: ink)
                    DetailCountdown(day: day, info: info, unit: $unit)
                    DetailFacts(day: day, info: info)
                    DetailTimeline(day: day, info: info, tint: tint, ink: ink)
                    DetailMemory(day: day, onWrite: { editDay(currentDay) })
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            DetailActionBar(onEdit: { editDay(currentDay) }, onShare: { showShare = true })
        }
        // The native bar keeps the system back button, and with it the edge swipe.
        .toolbar { toolbarItems(day: day) }
        .toolbarRole(.editor)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: day.pinned)
        .sensoryFeedback(.selection, trigger: unit)
        .sheet(isPresented: $showShare) {
            ShareCardView(day: currentDay)
        }
        .onChange(of: router.linkOpenCount) {
            showShare = false
            showDeleteConfirm = false
        }
        .onChange(of: dayID) { unit = .days }
    }

    // MARK: - Toolbar (pin + more)

    @ToolbarContentBuilder
    private func toolbarItems(day: Day) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: togglePinned) {
                Label(day.pinned ? String(localized: "取消置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                          : String(localized: "置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                      systemImage: day.pinned ? "pin.fill" : "pin")
            }
            .accessibilityAddTraits(day.pinned ? .isSelected : [])
            Menu {
                Button("编辑", systemImage: "pencil") { editDay(currentDay) }
                Button("分享", systemImage: "square.and.arrow.up") { showShare = true }
                Button("删除", systemImage: "trash", role: .destructive) { showDeleteConfirm = true }
            } label: {
                Label("更多操作", systemImage: "ellipsis")
            }
            .confirmationDialog("删除这个日子？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive, action: deleteDay)
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后会取消它的待提醒；30 天内可在「我的 › 数据与同步 › 最近删除」中恢复。")
            }
            .accessibilityIdentifier("detail.moreActions")
        }
    }

    private func deleteDay() {
        Haptics.warning()
        deletedHere = true
        store.delete(currentDay)
        if liveDay == nil { dismiss() } else { deletedHere = false }
    }

    private func togglePinned() {
        var updated = currentDay
        updated.pinned.toggle()
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) {
            _ = store.update(updated)
        }
    }

    // MARK: - Cover and title

    private func cover(day: Day, tint: Color) -> some View {
        CoverArt(day: day, photoCornerRadius: 24, maximumPixelSize: 1600)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 160 : 240,
                   maxHeight: dynamicTypeSize.isAccessibilitySize ? 160 : 240)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(tint, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func titleBlock(day: Day, info: DayInfo, category: CategoryDefinition, tint: Color, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.displayName)
                .font(Theme.sans(12, weight: .bold))
                .foregroundStyle(ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(tint, in: Capsule())
            Text(verbatim: day.title)
                .font(Theme.sans(30, weight: .heavy, relativeTo: .title))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("detail.title")
            MetaRow(metaItems(day: day, info: info))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    private func metaItems(day: Day, info: DayInfo) -> [String] {
        var items = [String(localized: "\(CNDate.full(info.displayDate)) \(CNDate.weekday(info.displayDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)]
        if day.recurring, let number = info.anniversaryNumber, number > 0 {
            items.append(String(localized: "第\(number)周年", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        }
        if let term = SolarTerms.name(for: info.displayDate) { items.append(term) }
        return items
    }
}
