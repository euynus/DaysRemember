import AppIntents
import Foundation

struct WidgetDay: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("widget.day", defaultValue: "日子"))
    static let defaultQuery = WidgetDayQuery()

    var id: String
    var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    /// The widget gallery's example before any day exists. Its title is the app's own text, so it
    /// is translated like the card around it.
    static var gallerySample: Day {
        var day = SampleData.days[0]
        day.title = String(localized: "widget.sampleTitle", defaultValue: "结婚纪念日",
                           bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        return day
    }

    /// The days a list widget shows, in the feed's order: pinned days first, then those ahead,
    /// nearest first, then those behind, most recent first.
    static func list(in days: [Day], today: Date, limit: Int) -> [Day] {
        days.map { ($0, DayInfo.compute($0, today: today)) }
            .sorted { lhs, rhs in
                if lhs.0.pinned != rhs.0.pinned { return lhs.0.pinned }
                if lhs.1.isPast != rhs.1.isPast { return !lhs.1.isPast }
                return lhs.1.days < rhs.1.days
            }
            .prefix(limit)
            .map(\.0)
    }

    /// A selected day, or else the nearest upcoming day, of the pinned days when there are any.
    /// When nothing is ahead, the most recent past day ("已过去 N 天") keeps the widget useful
    /// instead of empty.
    static func resolve(in days: [Day], selectedID: String?, today: Date) -> Day? {
        if let selectedID { return days.first { $0.id == selectedID } }
        let pinned = days.filter(\.pinned)
        let candidates = (pinned.isEmpty ? days : pinned).map { ($0, DayInfo.compute($0, today: today)) }
        let upcoming = candidates.filter { !$0.1.isPast }
        return (upcoming.isEmpty ? candidates : upcoming).min { $0.1.days < $1.1.days }?.0
    }
}
