import Foundation

/// The next round number a count-up day reaches: every 100 days up to 1,000, every 500
/// days after that, or a whole year — whichever comes first.
struct Milestone: Equatable {
    enum Kind: Equatable {
        case days(Int)
        case years(Int)
    }

    let kind: Kind
    let date: Date
    /// Zero when the milestone falls today.
    let daysUntil: Int

    var title: String {
        switch kind {
        case .days(let count):
            return String(localized: "满 \(count.formatted(.number.locale(AppLocalization.locale))) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .years(let count):
            return String(localized: "满 \(count) 年", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    /// Progress from the previous round number of the same kind, for a progress bar.
    var progress: Double {
        switch kind {
        case .days(let target):
            let step = target <= 1000 ? 100 : 500
            return min(1, max(0, Double(step - daysUntil) / Double(step)))
        case .years:
            return min(1, max(0, 1 - Double(daysUntil) / 365))
        }
    }

    static func next(after start: Date, today: Date = Today.date) -> Milestone? {
        let cal = CNDate.calendar
        let origin = cal.startOfDay(for: start)
        let todayStart = cal.startOfDay(for: today)
        let elapsed = CNDate.daysBetween(origin, todayStart)
        guard elapsed >= 0 else { return nil }

        let step = elapsed < 1000 ? 100 : 500
        let target = max(step, Int((Double(elapsed) / Double(step)).rounded(.up)) * step)
        guard let dayDate = cal.date(byAdding: .day, value: target, to: origin) else { return nil }
        let byDays = Milestone(kind: .days(target), date: dayDate,
                               daysUntil: CNDate.daysBetween(todayStart, dayDate))

        // Whole years follow the anniversary rule the countdown and reminders use (DayInfo).
        let originYear = cal.component(.year, from: origin)
        var years = max(1, cal.component(.year, from: todayStart) - originYear)
        var yearDate = DayInfo.gregorianAnniversary(of: origin, inYear: originYear + years) ?? dayDate
        if yearDate < todayStart {
            years += 1
            yearDate = DayInfo.gregorianAnniversary(of: origin, inYear: originYear + years) ?? dayDate
        }
        let byYears = Milestone(kind: .years(years), date: yearDate,
                                daysUntil: CNDate.daysBetween(todayStart, yearDate))
        return byYears.daysUntil < byDays.daysUntil ? byYears : byDays
    }
}

/// A recurring day whose latest occurrence fell within the last week, so the feed can
/// keep it around for a memory instead of jumping straight to next year.
struct RecentOccurrence: Equatable {
    let date: Date
    let daysAgo: Int
    /// The anniversary that just passed; one or more.
    let number: Int

    static func of(_ day: Day, today: Date = Today.date, within window: Int = 7) -> RecentOccurrence? {
        guard day.recurring else { return nil }
        let cal = CNDate.calendar
        let todayStart = cal.startOfDay(for: today)
        let year = cal.component(.year, from: todayStart)
        let latest = ((year - 1)...year)
            .flatMap { DayInfo.occurrences(of: day, inGregorianYear: $0) }
            .filter { $0 < todayStart }
            .max()
        guard let latest else { return nil }
        let daysAgo = CNDate.daysBetween(latest, todayStart)
        guard (1...window).contains(daysAgo) else { return nil }
        let number = day.lunar
            ? Lunar.solarToLunar(latest).year - Lunar.solarToLunar(day.date).year
            : cal.component(.year, from: latest) - cal.component(.year, from: day.date)
        guard number >= 1 else { return nil }
        return RecentOccurrence(date: latest, daysAgo: daysAgo, number: number)
    }
}
