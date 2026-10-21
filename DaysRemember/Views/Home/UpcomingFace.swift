import SwiftUI
import TipKit

/// 将至: a pager of the pinned and nearest days, a day that just recurred, then the rest of the days ahead.
struct UpcomingFace: View {
    @Environment(DayStore.self) private var store
    @Environment(\.currentDay) private var today
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let days: [Day]
    /// Owned by the feed, so the pager keeps its page while 已过 is shown.
    @Binding var heroPage: String?
    let heroHeight: CGFloat
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        if days.isEmpty {
            FeedEmptyState(title: String(localized: "没有将至的日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                           symbol: "sun.max",
                           detail: String(localized: "每年重复的日子和未来的日子会出现在这里。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        } else {
            let heroes = days.map { ($0, DayInfo.compute($0, today: today).days) }
                .sorted { $0.0.pinned != $1.0.pinned ? $0.0.pinned : $0.1 < $1.1 }.prefix(5).map(\.0)
            heroPager(heroes)
            TipView(DayMenuTip())
                .tint(Theme.accent)
            if let recent = recentOccurrence {
                RecentOccurrenceBanner(day: recent.day, occurrence: recent.occurrence, onOpen: onOpen)
                    .dayContextMenu(day: recent.day)
            }
            let rest = days.filter { $0.id != heroes.first?.id }
            if !rest.isEmpty {
                FeedSectionTitle(title: String(localized: "接下来", bundle: AppLocalization.bundle, locale: AppLocalization.locale), count: rest.count)
                DayGrid(days: rest, onOpen: onOpen)
            }
        }
    }

    @ViewBuilder
    private func heroPager(_ heroes: [Day]) -> some View {
        if dynamicTypeSize.isAccessibilitySize || heroes.count == 1 {
            if let first = heroes.first {
                HeroDayCard(day: first, onOpen: onOpen)
                    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? nil : heroHeight)
                    .dayContextMenu(day: first)
            }
        } else {
            TabView(selection: Binding(get: { heroPage ?? heroes.first?.id }, set: { heroPage = $0 })) {
                ForEach(heroes.enumerated(), id: \.element.id) { index, day in
                    HeroDayCard(day: day, position: (index, heroes.count), onOpen: onOpen)
                        .dayContextMenu(day: day)
                        .tag(Optional(day.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: heroHeight)
            .onChange(of: heroes.map(\.id)) { _, ids in
                if let page = heroPage, !ids.contains(page) { heroPage = nil }
            }
        }
    }

    /// The most recent recurring day that passed within the last week.
    private var recentOccurrence: (day: Day, occurrence: RecentOccurrence)? {
        store.days
            .compactMap { day in RecentOccurrence.of(day, today: today).map { (day, $0) } }
            .min { $0.1.daysAgo < $1.1.daysAgo }
    }
}
