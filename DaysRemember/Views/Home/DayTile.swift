import SwiftUI

/// A pastel card in the two-column day grid: art in the corner, the count at the bottom.
struct BentoDayCard: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let info = DayInfo.compute(day, today: today)
        let category = store.category(for: day)
        Button { onOpen(day) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 8) {
                    if day.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(category.tintInk)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 0)
                    if !dynamicTypeSize.isAccessibilitySize {
                        CoverArt(day: day, photoCornerRadius: 14, maximumPixelSize: 256,
                                 decodesAsynchronously: true)
                            .frame(width: 64, height: 64)
                    }
                }
                Spacer(minLength: 8)
                if !info.isToday { CountLabel(info: info) }
                CountValue(info: info, size: 36)
                Text(verbatim: day.title)
                    .font(Theme.sans(15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)
                Text(DayCardText.meta(day, info: info, category: category))
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.onPastel)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .background(category.tint, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityLabel(DayCardText.accessibilityLabel(day, info: info))
        .accessibilityHint("长按可置顶、编辑或分享")
        .accessibilityIdentifier("dayRow.\(day.id)")
    }
}

/// The large card at the top of each face: the nearest day ahead, or the past day
/// closest to a round number.
struct HeroDayCard: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    /// Page dots when the card sits in a pager.
    var position: (index: Int, count: Int)? = nil
    var milestone: Milestone? = nil
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let info = DayInfo.compute(day, today: today)
        let category = store.category(for: day)
        let tint = info.isPast ? Theme.memory : category.tint
        let ink = info.isPast ? Theme.memoryInk : category.tintInk
        let compact = dynamicTypeSize.isAccessibilitySize
        Button { onOpen(day) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(info.isPast ? category.displayName
                         : String(localized: "下一个 · \(category.displayName)", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                        .font(Theme.sans(12, weight: .bold))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.72), in: Capsule())
                    Spacer(minLength: 0)
                    if let position, position.count > 1 {
                        PageDots(index: position.index, count: position.count, color: ink)
                    }
                }
                Text(verbatim: day.title)
                    .font(Theme.sans(24, weight: .heavy, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(compact ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 6)
                    .padding(.trailing, compact ? 0 : 110)
                Text(DayCardText.heroDate(day, info: info))
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.onPastel)
                    .lineLimit(compact ? nil : 2)
                    .padding(.trailing, compact ? 0 : 110)
                Spacer(minLength: 10)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if !info.isToday { CountLabel(info: info) }
                    CountValue(info: info, size: 68)
                }
                if let milestone {
                    MilestoneProgress(milestone: milestone, ink: ink)
                        .padding(.top, 6)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(alignment: .bottomTrailing) {
                if !compact {
                    CoverArt(day: day, photoCornerRadius: 18, maximumPixelSize: 512)
                        .frame(width: 150, height: 150)
                        .padding(.trailing, 14)
                        .padding(.bottom, milestone == nil ? 14 : 44)
                }
            }
            .background(tint, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityLabel(DayCardText.heroAccessibilityLabel(day, info: info, milestone: milestone))
        .accessibilityHint("长按可置顶、编辑或分享")
        .accessibilityIdentifier(info.isPast ? "pastHero.\(day.id)" : "upcomingDay.\(day.id)")
    }
}

/// 还有 / 已经 above a count. Today has no label: the value says 今天.
struct CountLabel: View {
    let info: DayInfo

    var body: some View {
        Text(info.isPast ? String(localized: "countdown.since", defaultValue: "已经", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
             : String(localized: "countdown.ahead", defaultValue: "还有", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            .font(Theme.sans(13, weight: .bold))
            .foregroundStyle(Theme.onPastel)
    }
}

/// The rounded count and its unit, or 今天.
struct CountValue: View {
    let info: DayInfo
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if info.isToday {
                Text("今天")
                    .numberFont(size * 0.62)
            } else {
                Text(info.days, format: .number)
                    .numberFont(size)
                    .monospacedDigit()
                Text(String(localized: "countdown.days", defaultValue: "\(info.days)天", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(14, weight: .bold))
            }
        }
        .foregroundStyle(Theme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

struct PageDots: View {
    let index: Int
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(color.opacity(i == index ? 1 : 0.3))
                    .frame(width: i == index ? 16 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A thin bar toward the next round number, with when it lands.
struct MilestoneProgress: View {
    let milestone: Milestone
    let ink: Color

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(Color.white.opacity(0.8))
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule().fill(ink)
                            .frame(width: max(8, proxy.size.width * milestone.progress))
                    }
                }
                .accessibilityHidden(true)
            Text(DayCardText.milestone(milestone))
                .font(Theme.sans(12, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// A recurring day that just passed, kept on the feed for a week with a prompt to write it down.
struct RecentOccurrenceBanner: View {
    @Environment(DayStore.self) private var store
    @Environment(\.editDay) private var editDay
    let day: Day
    let occurrence: RecentOccurrence
    var onOpen: (Day) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let category = store.category(for: day)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            Button { onOpen(day) } label: {
                HStack(spacing: 10) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        CoverArt(day: day, photoCornerRadius: 12, maximumPixelSize: 192, decodesAsynchronously: true)
                            .frame(width: 48, height: 48)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(occurrence.daysAgo) 天前 · 第 \(occurrence.number) 周年")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.onPastel)
                        Text(verbatim: day.title)
                            .font(Theme.sans(15, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableTileStyle())
            Button { editDay(day) } label: {
                Text("写下这一天")
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(category.tintInk)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recentOccurrence.write")
        }
        .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 14 : 8)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(category.tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("recentOccurrence.\(day.id)")
    }
}

/// Copy shared by the cards.
enum DayCardText {
    static func countdown(_ info: DayInfo) -> String {
        info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : info.isPast ? String(localized: "\(info.days) 天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(info.days) 天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    static func accessibilityLabel(_ day: Day, info: DayInfo) -> String {
        let countdown = countdown(info)
        return day.pinned
            ? String(localized: "\(day.title)，\(countdown)，已置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(day.title)，\(countdown)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    /// The hero card's label replaces its children's, so it carries the milestone it shows.
    static func heroAccessibilityLabel(_ day: Day, info: DayInfo, milestone: Milestone?) -> String {
        guard info.isPast else {
            return String(localized: "即将到来，\(day.title)，\(countdown(info))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        let label = accessibilityLabel(day, info: info)
        guard let milestone else { return label }
        return String(localized: "\(label)，\(Self.milestone(milestone))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    /// Short date and category under a grid card's title; past days show when they began.
    static func meta(_ day: Day, info: DayInfo, category: CategoryDefinition) -> String {
        if info.isPast { return CNDate.full(day.date) }
        let date = day.lunar ? "\(CNDate.short(info.displayDate)) · \(Lunar.fmt(info.displayDate))"
            : CNDate.short(info.displayDate)
        return String(localized: "\(date) · \(category.displayName)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    static func heroDate(_ day: Day, info: DayInfo) -> String {
        if info.isPast {
            let location = day.location.trimmingCharacters(in: .whitespacesAndNewlines)
            return location.isEmpty ? CNDate.full(day.date)
                : String(localized: "\(CNDate.full(day.date)) · \(location)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        let date = String(localized: "\(CNDate.short(info.displayDate)) \(CNDate.weekday(info.displayDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        return String(localized: "\(date) · \(Lunar.fmt(info.displayDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    static func milestone(_ milestone: Milestone) -> String {
        milestone.daysUntil == 0
            ? String(localized: "今天\(milestone.title)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(milestone.daysUntil) 天后\(milestone.title)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }
}

/// The two-column grid of day cards, one column at accessibility text sizes.
struct DayGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let days: [Day]
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(days) { day in
                BentoDayCard(day: day, onOpen: onOpen)
                    .dayContextMenu(day: day)
            }
        }
    }
}

struct PressableTileStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Long-press context menu for a day tile — quick pin / edit / share / delete
/// without opening Detail. Self-contained: owns its sheet + dialog state and reads
/// the live `Day` back from the store so the actions reflect the latest edit.
struct DayContextMenu: ViewModifier {
    @Environment(DayStore.self) private var store
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.editDay) private var editDay
    let day: Day
    // Each action keeps the day it was chosen for: after midnight the hero card shows another day.
    @State private var sharing: Day?
    @State private var deleting: Day?

    private var current: Day { store.days.first { $0.id == day.id } ?? day }

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    var updated = current
                    updated.pinned.toggle()
                    store.update(updated)
                } label: {
                    Label(current.pinned ? String(localized: "取消置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                          systemImage: current.pinned ? "pin.slash" : "pin")
                }
                Button { editDay(current) } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button { sharing = current } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive) { deleting = current } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .sheet(item: $sharing) { ShareCardView(day: $0) }
            .confirmationDialog("删除这个日子？", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }
            ), titleVisibility: .visible, presenting: deleting) { day in
                Button("删除", role: .destructive) {
                    Haptics.warning()
                    store.delete(day)
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text("删除后会取消它的待提醒；30 天内可在「我的 › 数据与同步 › 最近删除」中恢复。")
            }
            .onChange(of: router.linkOpenCount) {
                sharing = nil
                deleting = nil
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: current.pinned)
    }
}

extension View {
    /// Attach the quick day-actions context menu (pin / edit / share / delete).
    func dayContextMenu(day: Day) -> some View {
        modifier(DayContextMenu(day: day))
    }
}
