import Foundation

struct CategoryDefinition: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var icon: String
    var colorToken: CategoryColorToken
    var isSystem: Bool

    // Persisted names are not rewritten when the app language changes.
    var displayName: String {
        guard isSystem, let category = DayCategory(rawValue: id) else { return name }
        return category.displayName
    }

    /// Older custom categories stored sticker names rather than SF Symbols.
    var symbolName: String {
        Self.symbolName(for: icon)
    }

    static func symbolName(for icon: String) -> String {
        switch icon {
        case "plane": return "airplane"
        case "cake": return "birthday.cake"
        case "cap": return "graduationcap"
        case "paw": return "pawprint"
        case "sun": return "sun.max"
        case "ring": return "circle.circle"
        default: return icon
        }
    }

    static let system: [CategoryDefinition] = DayCategory.allCases.map { category in
        CategoryDefinition(
            id: category.rawValue,
            name: category.label,
            icon: icon(for: category),
            colorToken: colorToken(for: category),
            isSystem: true
        )
    }

    private static func icon(for category: DayCategory) -> String {
        switch category {
        case .love: return "heart"
        case .family: return "house"
        case .travel: return "airplane"
        case .work: return "briefcase"
        case .life: return "sparkles"
        }
    }

    private static func colorToken(for category: DayCategory) -> CategoryColorToken {
        switch category {
        case .love: return .rose
        case .family: return .amber
        case .travel: return .dusty
        case .work: return .sage
        case .life: return .terracotta
        }
    }

    /// The colour of a day's category among `categories`, as `DayStore.category(for:)` resolves
    /// it: a system category keeps its own colour even when the list lacks it, and a category
    /// that hasn't arrived yet falls back to 生活.
    static func colorToken(for day: Day, in categories: [CategoryDefinition]) -> CategoryColorToken {
        (categories + system).first(where: { $0.id == day.categoryID })?.colorToken ?? .terracotta
    }
}
