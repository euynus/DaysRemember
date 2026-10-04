import Foundation

enum AppLocalization {
    static var locale: Locale {
        locale(for: Bundle.main.preferredLocalizations.first ?? "zh-Hans", regionalLocale: .autoupdatingCurrent)
    }

    static func locale(for language: String, regionalLocale: Locale) -> Locale {
        var components = Locale.Components(locale: regionalLocale)
        components.languageComponents = Locale.Language.Components(identifier: language)
        components.region = regionalLocale.region
        return Locale(components: components)
    }

    static var isEnglish: Bool { locale.language.languageCode?.identifier == "en" }
}
