import Foundation

extension Day {
    /// The feed's order, which the list widget keeps too: pinned days first, then those ahead,
    /// nearest first, then those behind, most recent first.
    nonisolated static func feedOrder(_ days: [Day], today: Date) -> [Day] {
        // Each day's info once, not on every comparison: a recurring lunar day's can take a
        // multi-year walk, and a sort compares about N log N times.
        days.map { ($0, DayInfo.compute($0, today: today)) }
            .sorted { lhs, rhs in
                if lhs.0.pinned != rhs.0.pinned { return lhs.0.pinned }
                if lhs.1.isPast != rhs.1.isPast { return !lhs.1.isPast }
                return lhs.1.days < rhs.1.days
            }
            .map(\.0)
    }

    /// Puts the day in `category`: its id, the name it shows until the definition arrives
    /// elsewhere, and the system category older versions and the widget read.
    mutating func assign(_ category: CategoryDefinition) {
        categoryID = category.id
        categoryLabel = category.name
        self.category = DayCategory(rawValue: category.id) ?? .life
    }
}
