import Foundation

/// Computed display info for a Day — port of `data.jsx`'s `dayInfo()`.
struct DayInfo {
    var days: Int
    var isPast: Bool
    var isToday: Bool
    var displayDate: Date
    var yearsAgo: Int?
    /// Years from the original date to `displayDate`; zero on the original date.
    /// `nil` for non-recurring days. Lunar recurrence counts lunar years.
    var anniversaryNumber: Int?
    /// Calendar days since the original date, starting at zero; nil before it starts.
    var elapsedDays: Int? = nil

    var countdownUnit: String {
        isPast ? String(localized: "countdown.daysAgoUnit", defaultValue: "\(days)天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "countdown.daysLeftUnit", defaultValue: "\(days)天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    /// Dates in a visible Gregorian year, shared by the countdown and calendar.
    static func occurrences(of day: Day, inGregorianYear year: Int) -> [Date] {
        let cal = CNDate.calendar
        let original = cal.startOfDay(for: day.date)
        guard year >= cal.component(.year, from: original) else { return [] }
        if !day.recurring {
            return cal.component(.year, from: day.date) == year
                ? [cal.startOfDay(for: day.date)] : []
        }
        if day.lunar {
            let source = Lunar.solarToLunar(day.date)
            // Late lunar months cross into the next Gregorian year; a Gregorian
            // year can contain occurrences from both adjacent lunar years.
            return ((year - 1)...year).filter { $0 >= 1900 }.map { lunarYear in
                cal.startOfDay(for: Lunar.lunarToSolar(year: lunarYear, month: source.month,
                                                     day: source.day, isLeap: source.isLeap))
            }.filter { cal.component(.year, from: $0) == year && $0 >= original }
        }
        let source = cal.dateComponents([.month, .day], from: day.date)
        guard let occurrence = cal.date(from: DateComponents(year: year, month: source.month,
                                                             day: source.day)) else { return [] }
        return occurrence >= original ? [cal.startOfDay(for: occurrence)] : []
    }

    static func compute(_ d: Day, today: Date = Today.date) -> DayInfo {
        let cal = CNDate.calendar
        let todayStart = cal.startOfDay(for: today)
        let key = CacheKey(
            dayID: d.id,
            dateRef: d.date.timeIntervalSinceReferenceDate,
            recurring: d.recurring,
            lunar: d.lunar,
            todayStartRef: todayStart.timeIntervalSinceReferenceDate
        )
        if let hit = Cache.shared.fetch(key) { return hit }
        let result = uncached(d, todayStart: todayStart, calendar: cal)
        Cache.shared.store(key, result)
        return result
    }

    private static func uncached(_ d: Day, todayStart: Date, calendar cal: Calendar) -> DayInfo {
        var displayDate = cal.startOfDay(for: d.date)

        if d.recurring && displayDate < todayStart {
            let baseYear = cal.component(.year, from: todayStart)
            for year in baseYear...(baseYear + 2) {
                if let candidate = occurrences(of: d, inGregorianYear: year).first(where: { $0 >= todayStart }) {
                    displayDate = candidate
                    break
                }
            }
        }

        let diff = CNDate.daysBetween(todayStart, displayDate)
        let elapsed = CNDate.daysBetween(d.date, todayStart)
        let years = d.recurring
            ? (cal.component(.year, from: todayStart) - cal.component(.year, from: d.date))
            : nil
        // Years between the original date and the upcoming occurrence — the anniversary
        // number. (Distinct from yearsAgo, which is measured from today's year and
        // over-counts before the anniversary rolls to next year.)
        let anniversary: Int?
        if !d.recurring {
            anniversary = nil
        } else if d.lunar {
            // Count in LUNAR years: a late-lunar-month anniversary (冬月/腊月) can resolve
            // to a solar date in the next Gregorian year, which a solar-year diff would
            // over-count by one.
            anniversary = max(0, Lunar.solarToLunar(displayDate).year - Lunar.solarToLunar(d.date).year)
        } else {
            anniversary = max(0, cal.component(.year, from: displayDate) - cal.component(.year, from: d.date))
        }

        return DayInfo(
            days: abs(diff),
            isPast: diff < 0,
            isToday: diff == 0,
            displayDate: displayDate,
            yearsAgo: years,
            anniversaryNumber: anniversary,
            elapsedDays: elapsed >= 0 ? elapsed : nil
        )
    }

    /// Memoization key — uses Day.id + date + recurrence + today's day-boundary, so a new
    /// day starts a fresh cache instead of serving yesterday's countdowns.
    /// Avoids hashing Day directly because Day.photoData would make Hashable O(N).
    private struct CacheKey: Hashable {
        let dayID: String
        let dateRef: TimeInterval
        let recurring: Bool
        let lunar: Bool
        let todayStartRef: TimeInterval
    }

    private final class Cache: @unchecked Sendable {
        static let shared = Cache()
        private let lock = NSLock()
        private var entries: [CacheKey: DayInfo] = [:]
        private var day: TimeInterval?

        func fetch(_ key: CacheKey) -> DayInfo? {
            lock.lock(); defer { lock.unlock() }
            return entries[key]
        }

        func store(_ key: CacheKey, _ info: DayInfo) {
            lock.lock(); defer { lock.unlock() }
            // Entries for another day are never hit again; the cap only bounds unusual mixes.
            if key.todayStartRef != day || entries.count >= 4096 {
                entries.removeAll(keepingCapacity: true)
                day = key.todayStartRef
            }
            entries[key] = info
        }
    }

    /// "还有" / "已过去" / "就是今天"
    var label: String {
        if isToday { return String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        return isPast ? String(localized: "已过去", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "还有", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    /// Short "已过" / "还有"
    var labelShort: String {
        if isToday { return String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        return isPast ? String(localized: "已过", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "还有", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }
}
