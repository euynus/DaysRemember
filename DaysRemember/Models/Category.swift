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
