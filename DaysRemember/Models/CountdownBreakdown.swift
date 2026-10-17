import Foundation

/// The units the detail's countdown cycles through when tapped.
enum CountdownUnit: CaseIterable {
    case days, weeks, months, hours
}

/// A day count restated in another unit: whole weeks or months plus leftover days, or hours.
struct CountdownBreakdown: Equatable {
    let value: Int
    /// Leftover days after whole weeks or months; nil for days and hours.
    let remainderDays: Int?

    static func make(_ unit: CountdownUnit, between first: Date, and second: Date) -> CountdownBreakdown {
        let cal = CNDate.calendar
        let start = cal.startOfDay(for: min(first, second))
        let end = cal.startOfDay(for: max(first, second))
        let days = CNDate.daysBetween(start, end)
        switch unit {
        case .days:
            return CountdownBreakdown(value: days, remainderDays: nil)
        case .weeks:
            return CountdownBreakdown(value: days / 7, remainderDays: days % 7)
        case .months:
            let parts = cal.dateComponents([.month, .day], from: start, to: end)
            return CountdownBreakdown(value: parts.month ?? 0, remainderDays: parts.day ?? 0)
        case .hours:
            return CountdownBreakdown(value: days * 24, remainderDays: nil)
        }
    }
}
