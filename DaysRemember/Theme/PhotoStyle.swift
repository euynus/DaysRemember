import SwiftUI

/// Raw identifiers remain stable so existing days keep decoding.
enum PhotoStyle: String, Codable, CaseIterable, Hashable {
    case systemDefault
    case wedding, baby, birthday, japan, study, memorial, work, pet, home, health
    case sketchLove, sketchFamily, sketchTravel, sketchWork, sketchLife
    case sketchMountain, sketchSea, sketchCafe, sketchGarden

    var displayName: String {
        switch self {
        case .systemDefault: return String(localized: "花与光", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .wedding, .sketchLove: return String(localized: "花期", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .baby, .birthday, .sketchFamily: return String(localized: "小小庆祝", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .japan, .sketchTravel, .sketchSea: return String(localized: "海岸", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .study, .work, .sketchWork: return String(localized: "一页时光", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .memorial: return String(localized: "念念", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .pet, .home, .sketchLife: return String(localized: "日常", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .health, .sketchGarden: return String(localized: "向阳", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .sketchMountain: return String(localized: "远方", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .sketchCafe: return String(localized: "午后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    var assetName: String {
        switch self {
        case .baby, .birthday, .sketchFamily: return "CoverCelebration"
        case .japan, .sketchTravel, .sketchMountain, .sketchSea: return "CoverCoast"
        case .study, .work, .sketchWork, .sketchCafe: return "CoverJournal"
        case .home, .pet, .sketchLife: return "CoverEveryday"
        default: return "CoverFlowers"
        }
    }

    func background() -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
    }
}
