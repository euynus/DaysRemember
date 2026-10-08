import SwiftUI

/// Raw identifiers remain stable so existing days keep decoding.
enum PhotoStyle: String, Codable, CaseIterable, Hashable {
    case systemDefault
    case wedding, baby, birthday, japan, study, memorial, work, pet, home, health
    case sketchLove, sketchFamily, sketchTravel, sketchWork, sketchLife
    case sketchMountain, sketchSea, sketchCafe, sketchGarden
    case mountains, cafe, garden, camping, homecoming, companionship, voyage

    /// One entry per illustration; legacy aliases keep their original artwork.
    static let pickerOptions: [PhotoStyle] = [
        .systemDefault, .birthday, .japan, .study, .home,
        .mountains, .cafe, .garden, .camping, .homecoming, .companionship, .voyage,
    ]

    /// The template a new day starts from in a system category. Custom categories keep
    /// whatever cover is current.
    static func defaultCover(forCategoryID id: String) -> PhotoStyle? {
        switch DayCategory(rawValue: id) {
        case .love: return .systemDefault
        case .family: return .birthday
        case .travel: return .japan
        case .work: return .study
        case .life: return .home
        case nil: return nil
        }
    }

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
        case .sketchCafe, .cafe: return String(localized: "午后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .mountains: return String(localized: "远山", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .garden: return String(localized: "花园", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .camping: return String(localized: "星野", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .homecoming: return String(localized: "归家", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .companionship: return String(localized: "相伴", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .voyage: return String(localized: "启程", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    var assetName: String {
        switch self {
        case .baby, .birthday, .sketchFamily: return "CoverCelebration"
        case .japan, .sketchTravel, .sketchMountain, .sketchSea: return "CoverCoast"
        case .study, .work, .sketchWork, .sketchCafe: return "CoverJournal"
        case .home, .pet, .sketchLife: return "CoverEveryday"
        case .mountains: return "CoverMountains"
        case .cafe: return "CoverCafe"
        case .garden: return "CoverGarden"
        case .camping: return "CoverCamping"
        case .homecoming: return "CoverHomecoming"
        case .companionship: return "CoverCompanionship"
        case .voyage: return "CoverVoyage"
        default: return "CoverFlowers"
        }
    }

    func background() -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
    }
}
