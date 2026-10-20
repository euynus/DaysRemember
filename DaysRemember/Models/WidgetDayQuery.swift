import AppIntents
import Foundation

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
