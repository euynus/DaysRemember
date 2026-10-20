import Foundation

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
