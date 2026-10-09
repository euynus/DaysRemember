import AppIntents
import Foundation

struct WidgetDay: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "日子"
    static var defaultQuery = WidgetDayQuery()

    var id: String
    var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

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
    static var title: LocalizedStringResource = "选择日子"
    static var description = IntentDescription("不选择时，自动显示最近的日子。")

    @Parameter(title: "日子")
    var day: WidgetDay?
}
