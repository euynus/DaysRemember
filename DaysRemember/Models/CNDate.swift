import Foundation

/// Display follows the app language; day boundaries remain in the stored calendar.
enum CNDate {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }()

    static func full(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        date.formatted(style(locale: locale).year().month(.wide).day())
    }

    static func short(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        date.formatted(style(locale: locale).month(.abbreviated).day())
    }

    static func weekday(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        date.formatted(style(locale: locale).weekday(.wide))
    }

    static func year(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        date.formatted(style(locale: locale).year())
    }

    static func month(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        date.formatted(style(locale: locale).month(.wide))
    }

    /// A time of day as the app's time pickers show it, in the locale's preferred hour cycle:
    /// 09:00 in Simplified Chinese, 上午9:00 in Traditional Chinese, 9:00 AM in English.
    static func time(hour: Int, minute: Int, locale: Locale = AppLocalization.locale) -> String {
        let date = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: hour, minute: minute)) ?? .now
        return date.formatted(style(locale: locale).hour().minute())
    }

    static var shortWeekdaySymbols: [String] {
        var calendar = calendar
        calendar.locale = AppLocalization.locale
        return AppLocalization.isEnglish ? calendar.shortStandaloneWeekdaySymbols
            : calendar.veryShortStandaloneWeekdaySymbols
    }

    /// The user's first day of the week (1 = Sunday), including the iOS
    /// Language & Region override, which the app locale carries over.
    static func firstWeekday(locale: Locale = AppLocalization.locale) -> Int {
        let days: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        return (days.firstIndex(of: locale.firstDayOfWeek) ?? 0) + 1
    }

    private static func style(locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let aStart = calendar.startOfDay(for: a)
        let bStart = calendar.startOfDay(for: b)
        return calendar.dateComponents([.day], from: aStart, to: bStart).day ?? 0
    }

    static func dayStarts(after date: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        let start = calendar.startOfDay(for: date)
        return (1...count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
