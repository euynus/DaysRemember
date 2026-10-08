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

    static func day(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        date.formatted(style(locale: locale).day())
    }

    static var shortWeekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = AppLocalization.locale
        return AppLocalization.isEnglish ? formatter.shortStandaloneWeekdaySymbols
            : formatter.veryShortStandaloneWeekdaySymbols
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

/// Today reference — production uses `Date()`, but DEBUG can pin to the prototype's
/// 2026-04-23 so previews and screenshots line up with the design.
enum Today {
    static var date: Date {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["DR_PIN_TODAY"] {
            if raw == "1" {
                var c = DateComponents()
                c.year = 2026; c.month = 4; c.day = 23
                return CNDate.calendar.date(from: c) ?? Date()
            }
            // Accept "yyyy-MM-dd" so test runs can pin to arbitrary dates.
            let f = DateFormatter()
            f.calendar = CNDate.calendar
            f.timeZone = CNDate.calendar.timeZone
            f.dateFormat = "yyyy-MM-dd"
            if let d = f.date(from: raw) { return d }
        }
        #endif
        return Date()
    }
}
