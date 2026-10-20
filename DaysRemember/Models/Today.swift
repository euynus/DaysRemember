import Foundation

/// Today reference — production uses `Date.now`, but DEBUG can pin to the prototype's
/// 2026-04-23 so previews and screenshots line up with the design.
enum Today {
    static var date: Date {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["DR_PIN_TODAY"] {
            if raw == "1" {
                var c = DateComponents()
                c.year = 2026; c.month = 4; c.day = 23
                return CNDate.calendar.date(from: c) ?? Date.now
            }
            // Accept "yyyy-MM-dd" so test runs can pin to arbitrary dates.
            let f = DateFormatter()
            f.calendar = CNDate.calendar
            f.timeZone = CNDate.calendar.timeZone
            f.dateFormat = "yyyy-MM-dd"
            if let d = f.date(from: raw) { return d }
        }
        #endif
        return Date.now
    }
}
