import SwiftUI

enum CategoryColorToken: String, Codable, CaseIterable, Hashable, Identifiable {
    case terracotta, rose, amber, dusty, sage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .terracotta: return String(localized: "赤陶", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .rose: return String(localized: "玫瑰", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .amber: return String(localized: "琥珀", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .dusty: return String(localized: "雾蓝", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .sage: return String(localized: "鼠尾草", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
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
