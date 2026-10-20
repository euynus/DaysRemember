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
                    countdown(day: day, info: info)
                    infoGrid(day: day, info: info)
                    timeline(day: day, info: info, tint: tint, ink: ink)
                    memory(day: day)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .safeAreaBar(edge: .bottom, spacing: 0) { actionBar }
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

    // MARK: - Countdown

    private func countdown(day: Day, info: DayInfo) -> some View {
        let countdownLabel = info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : info.isPast ? String(localized: "\(info.days) 天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(info.days) 天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        let other = info.isPast ? day.date : info.displayDate
        let breakdown = CountdownBreakdown.make(unit, between: today, and: other)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                guard !info.isToday else { return }
                let all = CountdownUnit.allCases
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                    unit = all[(all.firstIndex(of: unit)! + 1) % all.count]
                }
            } label: {
                Group {
                    if info.isToday {
                        Text("今天")
                            .numberFont(64)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                    } else if dynamicTypeSize.isAccessibilitySize {
                        // The number gets a line of its own, so a long count shrinks to fit the width
                        // instead of being cut off beside its label and unit.
                        VStack(alignment: .leading, spacing: 2) {
                            CountLabel(info: info)
                            countNumber(breakdown)
                                .lineLimit(1)
                                .minimumScaleFactor(0.2)
                            Text(unitText(breakdown))
                                .font(Theme.sans(18, weight: .heavy))
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            CountLabel(info: info)
                            countNumber(breakdown)
                            Text(unitText(breakdown))
                                .font(Theme.sans(18, weight: .heavy))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Theme.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(countdownLabel)
            .accessibilityValue(info.isToday ? "" : "\(breakdown.value.formatted(.number.locale(AppLocalization.locale))) \(unitText(breakdown))")
            .accessibilityHint(info.isToday ? "" : String(localized: "轻点切换单位", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            .accessibilityIdentifier("detail.countdown")
            if !info.isToday { unitPicker }
        }
        .padding(.horizontal, 4)
    }

    private func countNumber(_ breakdown: CountdownBreakdown) -> some View {
        Text(breakdown.value, format: .number)
            .numberFont(breakdown.value >= 1_000 ? 84 : 108)
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private var unitPicker: some View {
        HStack(spacing: 6) {
            if !dynamicTypeSize.isAccessibilitySize {
                Text("轻点数字切换")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(CountdownUnit.allCases, id: \.self) { value in
                Button { unit = value } label: {
                    Text(unitName(value))
                        .font(Theme.sans(12, weight: value == unit ? .heavy : .medium))
                        .foregroundStyle(value == unit ? Color.white : Theme.ink2)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 26)
                        .background(value == unit ? Theme.ink : Theme.bg2, in: Capsule())
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(value == unit ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        // Fixed chips, like the editor's action bar, stop growing at XXXL.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func unitName(_ unit: CountdownUnit) -> String {
        switch unit {
        case .days: return String(localized: "detail.unit.days", defaultValue: "天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .weeks: return String(localized: "detail.unit.weeks", defaultValue: "周", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .months: return String(localized: "detail.unit.months", defaultValue: "月", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .hours: return String(localized: "detail.unit.hours", defaultValue: "小时", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    /// The unit after the big number, with leftover days for weeks and months.
    private func unitText(_ breakdown: CountdownBreakdown) -> String {
        let rest = breakdown.remainderDays ?? 0
        switch unit {
        case .days:
            return String(localized: "countdown.days", defaultValue: "\(breakdown.value)天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .weeks:
            return rest == 0 ? String(localized: "detail.weeksOnly", defaultValue: "周", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : String(localized: "周 \(rest) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .months:
            return rest == 0 ? String(localized: "detail.monthsOnly", defaultValue: "个月", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : String(localized: "个月 \(rest) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .hours:
            return String(localized: "detail.hoursUnit", defaultValue: "小时", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    // MARK: - Facts

    private func infoGrid(day: Day, info: DayInfo) -> some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            fact(String(localized: "日期", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                 String(localized: "\(CNDate.short(info.displayDate)) \(CNDate.weekday(info.displayDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            fact(String(localized: "农历", bundle: AppLocalization.bundle, locale: AppLocalization.locale), Lunar.fmt(info.displayDate))
            fact(String(localized: "重复", bundle: AppLocalization.bundle, locale: AppLocalization.locale), repeatText(day))
            fact(String(localized: "提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale), reminderText(day))
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(Theme.sans(15, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func repeatText(_ day: Day) -> String {
        guard day.recurring else { return String(localized: "不重复", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        return day.lunar ? String(localized: "每年 · 按农历", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "每年", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    private func reminderText(_ day: Day) -> String {
        guard let offsets = day.reminderOffsets else {
            return String(localized: "跟随全局设置", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        let selected = Set(offsets)
        if selected.isEmpty { return String(localized: "不提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        if selected.count == 1, let offset = selected.first {
            return offset == 0 ? String(localized: "当天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : String(localized: "提前 \(offset) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        return String(localized: "自定义（\(selected.count)次）", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    // MARK: - Timeline

    private struct Node: Identifiable {
        let id = UUID()
        let title: String
        let date: Date
        let relative: String
    }

    @ViewBuilder
    private func timeline(day: Day, info: DayInfo, tint: Color, ink: Color) -> some View {
        let (title, nodes, progress) = timelineContent(day: day, info: info)
        if !nodes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(Theme.sans(15, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                if let progress {
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule()
                            .fill(tint)
                            .frame(height: 8)
                            .overlay(alignment: .leading) {
                                GeometryReader { proxy in
                                    Capsule().fill(ink).frame(width: max(8, proxy.size.width * progress.fraction))
                                }
                            }
                            .accessibilityHidden(true)
                        HStack {
                            Text(progress.leading)
                            Spacer(minLength: 8)
                            Text(progress.trailing)
                        }
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(nodes) { node in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.title)
                                    .font(Theme.sans(15, weight: .heavy))
                                    .foregroundStyle(Theme.ink)
                                Text(String(localized: "\(CNDate.full(node.date)) \(CNDate.weekday(node.date))", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(node.relative)
                                .font(Theme.sans(13, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.bg, in: Capsule())
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .top) { RowDivider() }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private struct Progress {
        let fraction: Double
        let leading: String
        let trailing: String
    }

    private func relative(_ date: Date) -> String {
        let n = CNDate.daysBetween(today, date)
        if n == 0 { return String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        return n > 0 ? String(localized: "\(n) 天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(-n) 天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    /// The note under 那一天 for a one-time day: how long ago it was, or 今天 on the day itself.
    nonisolated static func sinceTheDay(_ info: DayInfo) -> String {
        info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "已过 \(info.days) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    private func timelineContent(day: Day, info: DayInfo) -> (String, [Node], Progress?) {
        let cal = CNDate.calendar
        let todayStart = cal.startOfDay(for: today)
        if day.recurring {
            var nodes: [Node] = []
            if let elapsed = info.elapsedDays, elapsed > 0 {
                nodes.append(Node(title: String(localized: "那一天", bundle: AppLocalization.bundle, locale: AppLocalization.locale), date: day.date,
                                  relative: String(localized: "已过 \(elapsed) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)))
            }
            let year = cal.component(.year, from: todayStart)
            let previous = ((year - 1)...year)
                .flatMap { DayInfo.occurrences(of: day, inGregorianYear: $0) }
                .filter { $0 < todayStart && $0 > cal.startOfDay(for: day.date) }
                .max()
            if let previous {
                nodes.append(Node(title: String(localized: "上一次", bundle: AppLocalization.bundle, locale: AppLocalization.locale), date: previous, relative: relative(previous)))
            }
            let nextTitle = info.anniversaryNumber.map { $0 > 0 ? String(localized: "第\($0)周年", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : nil } ?? nil
            nodes.append(Node(title: nextTitle ?? String(localized: "这一次", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                              date: info.displayDate, relative: relative(info.displayDate)))
            var progress: Progress?
            if let previous {
                let since = CNDate.daysBetween(previous, todayStart)
                let span = max(1, CNDate.daysBetween(previous, info.displayDate))
                progress = Progress(fraction: Double(since) / Double(span),
                                    leading: String(localized: "距上次 \(since) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                    trailing: nextTitle ?? "")
            }
            return (String(localized: "每一年", bundle: AppLocalization.bundle, locale: AppLocalization.locale), nodes, progress)
        }
        if info.isPast || info.isToday {
            guard let milestone = Milestone.next(after: day.date, today: today) else { return ("", [], nil) }
            let nodes = [
                Node(title: String(localized: "那一天", bundle: AppLocalization.bundle, locale: AppLocalization.locale), date: day.date,
                     relative: Self.sinceTheDay(info)),
                Node(title: milestone.title, date: milestone.date, relative: relative(milestone.date)),
            ]
            let progress = Progress(fraction: milestone.progress, leading: CNDate.full(day.date),
                                    trailing: DayCardText.milestone(milestone))
            return (String(localized: "整数纪念", bundle: AppLocalization.bundle, locale: AppLocalization.locale), nodes, progress)
        }
        // A one-time day ahead: the round numbers left on the way.
        let nodes = [100, 50, 30, 7]
            .filter { info.days > $0 }
            .compactMap { left -> Node? in
                guard let date = cal.date(byAdding: .day, value: -left, to: info.displayDate) else { return nil }
                return Node(title: String(localized: "还剩 \(left) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                            date: date, relative: relative(date))
            }
        return (String(localized: "倒数节点", bundle: AppLocalization.bundle, locale: AppLocalization.locale), Array(nodes.prefix(3)), nil)
    }

    // MARK: - Memory

    @ViewBuilder
    private func memory(day: Day) -> some View {
        let note = day.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = day.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty && location.isEmpty {
            Button { editDay(currentDay) } label: {
                Label("写下这一天的记忆", systemImage: "plus")
                    .font(Theme.sans(15, weight: .heavy))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(PressableTileStyle())
            .accessibilityIdentifier("detail.writeMemory")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("记忆")
                    .font(Theme.sans(12, weight: .heavy))
                    .foregroundStyle(Theme.memoryInk)
                if !note.isEmpty {
                    Text(verbatim: note)
                        .font(Theme.sans(18, weight: .bold))
                        .lineSpacing(5)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                if !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.memoryInk)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.memory, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button { editDay(currentDay) } label: {
                Label("编辑", systemImage: "pencil")
                    .font(Theme.sans(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 54)
                    .background(Theme.card, in: Capsule())
            }
            .accessibilityIdentifier("detail.edit")
            Button { showShare = true } label: {
                Label("分享这一天", systemImage: "square.and.arrow.up")
                    .font(Theme.sans(16, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.ink, in: Capsule())
            }
        }
        .buttonStyle(PressScale(scale: 0.97))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background(Theme.bg.opacity(0.94))
    }
}
