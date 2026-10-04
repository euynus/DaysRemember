import Foundation

enum AppLocalization {
    static let languageKey = "app.language.v1"

    static func preferredLanguage(defaults: UserDefaults = SharedStorage.defaults) -> AppLanguage {
        defaults.string(forKey: languageKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    static var bundle: Bundle { bundle(for: preferredLanguage()) }

    static func bundle(for language: AppLanguage, in sourceBundle: Bundle = .main) -> Bundle {
        guard language != .system,
              let path = sourceBundle.path(forResource: language.rawValue, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else { return sourceBundle }
        return localizedBundle
    }

    static var locale: Locale {
        locale(for: preferredLanguage())
    }

    static func locale(for language: AppLanguage, regionalLocale: Locale = .autoupdatingCurrent,
                       bundle: Bundle = .main) -> Locale {
        let identifier = language == .system
            ? bundle.preferredLocalizations.first ?? "zh-Hans" : language.rawValue
        return locale(for: identifier, regionalLocale: regionalLocale)
    }

    static func locale(for language: String, regionalLocale: Locale) -> Locale {
        var components = Locale.Components(locale: regionalLocale)
        components.languageComponents = Locale.Language.Components(identifier: language)
        components.region = regionalLocale.region
        return Locale(components: components)
    }

    static var isEnglish: Bool { locale.language.languageCode?.identifier == "en" }
}
