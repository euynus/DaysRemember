import AppIntents
import Foundation

struct WidgetDay: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "日子"
    static var defaultQuery = WidgetDayQuery()

    var id: String
    var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    static func resolve(in days: [Day], selectedID: String?, today: Date) -> Day? {
        if let selectedID { return days.first { $0.id == selectedID } }
        return days.compactMap { day -> (Day, Int)? in
            let info = DayInfo.compute(day, today: today)
            return info.isPast ? nil : (day, info.days)
        }.min { $0.1 < $1.1 }?.0
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
