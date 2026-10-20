import Foundation

/// A recurring day whose latest occurrence fell within the last week, so the feed can
/// keep it around for a memory instead of jumping straight to next year.
struct RecentOccurrence: Equatable {
    let date: Date
    let daysAgo: Int
    /// The anniversary that just passed; one or more.
    let number: Int

    static func of(_ day: Day, today: Date = Today.date, within window: Int = 7) -> RecentOccurrence? {
        guard day.recurring else { return nil }
        let todayStart = CNDate.startOfDay(today)
        // The home feed asks for every day on each update; the answer changes only with the day.
        let key = CacheKey(date: day.date.timeIntervalSinceReferenceDate, lunar: day.lunar,
                           todayStart: todayStart.timeIntervalSinceReferenceDate, window: window)
        return cache.value(for: key, on: key.todayStart) { uncached(day, todayStart: todayStart, window: window) }
    }

    private struct CacheKey: Hashable {
        let date: TimeInterval
        let lunar: Bool
        let todayStart: TimeInterval
        let window: Int
    }

    private static let cache = DailyCache<CacheKey, RecentOccurrence?>()

    private static func uncached(_ day: Day, todayStart: Date, window: Int) -> RecentOccurrence? {
        let cal = CNDate.calendar
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
