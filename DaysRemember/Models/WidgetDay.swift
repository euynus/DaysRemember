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
