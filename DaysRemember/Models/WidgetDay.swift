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

    /// A selected day, or else the nearest upcoming day. When nothing is ahead, the most
    /// recent past day ("已过去 N 天") keeps the widget useful instead of empty.
    static func resolve(in days: [Day], selectedID: String?, today: Date) -> Day? {
        if let selectedID { return days.first { $0.id == selectedID } }
        let candidates = days.map { ($0, DayInfo.compute($0, today: today)) }
        let upcoming = candidates.filter { !$0.1.isPast }
        return (upcoming.isEmpty ? candidates : upcoming).min { $0.1.days < $1.1.days }?.0
    }
}

struct WidgetDayQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetDay] {
        let days = SharedStorage.loadLibrary().days
        // Preserve a deleted selection so it cannot turn into automatic selection.
        return identifiers.map { id in
            WidgetDay(id: id, title: days.first { $0.id == id }?.title ?? String(localized: "日子已删除", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        }
    }

    func suggestedEntities() async throws -> [WidgetDay] {
        SharedStorage.loadLibrary().days.map { WidgetDay(id: $0.id, title: $0.title) }
    }
}

struct SelectWidgetDay: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "选择日子"
    static let description = IntentDescription("不选择时，自动显示最近的日子。")

    @Parameter(title: LocalizedStringResource("widget.day", defaultValue: "日子"))
    var day: WidgetDay?
}
