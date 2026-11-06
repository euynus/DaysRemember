import Foundation

/// Computed display info for a Day — port of `data.jsx`'s `dayInfo()`.
struct DayInfo {
    var days: Int
    var isPast: Bool
    var isToday: Bool
    var displayDate: Date
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
        guard recurs(day) else {
            let cal = CNDate.calendar
            return cal.component(.year, from: day.date) == year ? [cal.startOfDay(for: day.date)] : []
        }
        return annualOccurrences(of: day, inGregorianYear: year)
    }

    /// Where the day falls in a Gregorian year as a yearly day, whether or not it repeats:
    /// reminders ask this for a one-off day's 时光回忆. None for a lunar day outside the table.
    static func annualOccurrences(of day: Day, inGregorianYear year: Int) -> [Date] {
        let cal = CNDate.calendar
        let original = cal.startOfDay(for: day.date)
        guard year >= cal.component(.year, from: original) else { return [] }
        if day.lunar {
            guard Lunar.supportedLunarDate(for: day.date) != nil else { return [] }
            let source = Lunar.solarToLunar(day.date)
            // Late lunar months cross into the next Gregorian year; a Gregorian
            // year can contain occurrences from both adjacent lunar years.
            // Outside the 1900–2100 table there are no real lunar months to convert.
            return ((year - 1)...year).filter { Lunar.supportedYears.contains($0) }.map { lunarYear in
                cal.startOfDay(for: Lunar.lunarToSolar(year: lunarYear, month: source.month,
                                                     day: source.day, isLeap: source.isLeap))
            }.filter { cal.component(.year, from: $0) == year && $0 >= original }
        }
        guard let occurrence = gregorianAnniversary(of: day.date, inYear: year) else { return [] }
        return occurrence >= original ? [occurrence] : []
    }

    /// The Gregorian anniversary of `date` in `year`. February 29 falls on March 1 in a common year,
    /// for the countdown, the calendar, reminders and milestones alike.
    static func gregorianAnniversary(of date: Date, inYear year: Int) -> Date? {
        let cal = CNDate.calendar
        let source = cal.dateComponents([.month, .day], from: date)
        // The calendar is lenient: February 29 of a common year becomes March 1.
        return cal.date(from: DateComponents(year: year, month: source.month, day: source.day))
            .map { cal.startOfDay(for: $0) }
    }

    /// The latest occurrence since the original date and before `todayStart`, in the last two
    /// Gregorian years: the one a yearly day has just had.
    static func previousOccurrence(of day: Day, before todayStart: Date) -> Date? {
        let cal = CNDate.calendar
        let year = cal.component(.year, from: todayStart)
        let original = cal.startOfDay(for: day.date)
        return ((year - 1)...year)
            .flatMap { occurrences(of: day, inGregorianYear: $0) }
            .filter { $0 < todayStart && $0 > original }
            .max()
    }

    /// Which anniversary falls on `date`, an occurrence of the day: zero on the original date.
    /// A lunar day counts lunar years, as a 冬月 or 腊月 anniversary can land in the next
    /// Gregorian year, which a Gregorian difference would count one too many.
    static func anniversaryNumber(of day: Day, at date: Date) -> Int {
        let cal = CNDate.calendar
        return day.lunar
            ? Lunar.solarToLunar(date).year - Lunar.solarToLunar(day.date).year
            : cal.component(.year, from: date) - cal.component(.year, from: day.date)
    }

    /// A lunar day outside the lunar table has no lunar date to recur on, so it counts like a
    /// one-off day, as its reminders do.
    private static func recurs(_ day: Day) -> Bool {
        day.recurring && (!day.lunar || Lunar.supportedLunarDate(for: day.date) != nil)
    }

    static func compute(_ d: Day, today: Date = Today.date) -> DayInfo {
        let cal = CNDate.calendar
        let todayStart = CNDate.startOfDay(today)
        let key = CacheKey(
            dayID: d.id,
            dateRef: d.date.timeIntervalSinceReferenceDate,
            recurring: d.recurring,
            lunar: d.lunar,
            todayStartRef: todayStart.timeIntervalSinceReferenceDate
        )
        return cache.value(for: key, on: key.todayStartRef) { uncached(d, todayStart: todayStart, calendar: cal) }
    }

    private static func uncached(_ d: Day, todayStart: Date, calendar cal: Calendar) -> DayInfo {
        var displayDate = cal.startOfDay(for: d.date)
        let recurring = recurs(d)

        if recurring && displayDate < todayStart {
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
        // Years between the original date and the upcoming occurrence.
        let anniversary = recurring ? max(0, anniversaryNumber(of: d, at: displayDate)) : nil

        return DayInfo(
            days: abs(diff),
            isPast: diff < 0,
            isToday: diff == 0,
            displayDate: displayDate,
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

    private static let cache = DailyCache<CacheKey, DayInfo>()
}
