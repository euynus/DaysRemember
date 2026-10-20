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

    var displayName: String {
        switch self {
        case .love: return String(localized: "爱情", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .family: return String(localized: "家人", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .travel: return String(localized: "旅行", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .work: return String(localized: "工作", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .life: return String(localized: "生活", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
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
