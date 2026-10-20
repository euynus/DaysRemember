import Foundation

extension CloudLibraryRecord {
    var kindName: String {
        switch self {
        case .day: return String(localized: "record.day", defaultValue: "日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .category: return String(localized: "record.category", defaultValue: "分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }
}
