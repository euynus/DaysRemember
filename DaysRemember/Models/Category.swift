import SwiftUI

enum DayCategory: String, Codable, CaseIterable, Hashable {
    case love, family, travel, work, life

    var label: String {
        switch self {
        case .love: return "爱情"
        case .family: return "家人"
        case .travel: return "旅行"
        case .work: return "工作"
        case .life: return "生活"
        }
    }

    var color: Color {
        switch self {
        case .love: return Theme.rose
        case .family: return Theme.amber
        case .travel: return Theme.dusty
        case .work: return Theme.sage
        case .life: return Theme.terracotta
        }
    }

    var soft: Color {
        switch self {
        case .love: return Theme.roseSoft
        case .family: return Theme.amberSoft
        case .travel: return Theme.dustySoft
        case .work: return Theme.sageSoft
        case .life: return Theme.terracottaSoft
        }
    }
}

enum CategoryColorToken: String, Codable, CaseIterable, Hashable, Identifiable {
    case terracotta, rose, amber, dusty, sage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .terracotta: return "赤陶"
        case .rose: return "玫瑰"
        case .amber: return "琥珀"
        case .dusty: return "雾蓝"
        case .sage: return "鼠尾草"
        }
    }

    var color: Color {
        switch self {
        case .terracotta: return Theme.terracotta
        case .rose: return Theme.rose
        case .amber: return Theme.amber
        case .dusty: return Theme.dusty
        case .sage: return Theme.sage
        }
    }

    var soft: Color {
        switch self {
        case .terracotta: return Theme.terracottaSoft
        case .rose: return Theme.roseSoft
        case .amber: return Theme.amberSoft
        case .dusty: return Theme.dustySoft
        case .sage: return Theme.sageSoft
        }
    }
}

struct CategoryDefinition: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var icon: String
    var colorToken: CategoryColorToken
    var isSystem: Bool

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
}
