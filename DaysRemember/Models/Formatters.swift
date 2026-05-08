import Foundation

/// Chinese date formatters — match the prototype's `data.jsx` helpers.
enum CNDate {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }()

    /// "2026年4月23日"
    static func full(_ date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year!)年\(comps.month!)月\(comps.day!)日"
    }

    /// "4月23日"
    static func short(_ date: Date) -> String {
        let comps = calendar.dateComponents([.month, .day], from: date)
        return "\(comps.month!)月\(comps.day!)日"
    }

    /// "星期四"
    static func weekday(_ date: Date) -> String {
        let names = ["日","一","二","三","四","五","六"]
        let w = calendar.component(.weekday, from: date) - 1
        return "星期" + names[w]
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let aStart = calendar.startOfDay(for: a)
        let bStart = calendar.startOfDay(for: b)
        return calendar.dateComponents([.day], from: aStart, to: bStart).day ?? 0
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
