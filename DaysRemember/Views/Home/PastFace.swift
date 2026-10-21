import SwiftUI

/// 已过: a pinned day or the one nearest a round number, the next few milestones, then every day behind.
struct PastFace: View {
    @Environment(\.currentDay) private var today
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let days: [Day]
    let heroHeight: CGFloat
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        if days.isEmpty {
            FeedEmptyState(title: String(localized: "还没有走过的日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                           symbol: "moon",
                           detail: String(localized: "不重复的日子过去以后，会在这里一天天记着。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        } else {
            let milestones = days.compactMap { day in Milestone.next(after: day.date, today: today).map { (day, $0) } }
                .sorted { $0.0.pinned != $1.0.pinned ? $0.0.pinned : $0.1.daysUntil < $1.1.daysUntil }
            if let hero = milestones.first {
                HeroDayCard(day: hero.0, milestone: hero.1, onOpen: onOpen)
                    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? nil : heroHeight)
                    .dayContextMenu(day: hero.0)
            }
            if milestones.count > 1 {
                MilestoneStrip(items: Array(milestones.dropFirst().prefix(5)), onOpen: onOpen)
            }
            let rest = days.filter { $0.id != milestones.first?.0.id }
            if !rest.isEmpty {
                FeedSectionTitle(title: String(localized: "走过的日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale), count: rest.count)
                DayGrid(days: rest, onOpen: onOpen)
            }
        }
    }
}
