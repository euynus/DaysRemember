import Foundation

enum AppLocalization {
    static let languageKey = "app.language.v1"

    static func preferredLanguage(defaults: UserDefaults = SharedStorage.defaults) -> AppLanguage {
        defaults.string(forKey: languageKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    static var bundle: Bundle { resolved().bundle }

    static func bundle(for language: AppLanguage, in sourceBundle: Bundle = .main) -> Bundle {
        guard language != .system,
              let path = sourceBundle.path(forResource: language.rawValue, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else { return sourceBundle }
        return localizedBundle
    }

    static var locale: Locale { resolved().locale }

    /// Every localized string asks for the bundle and locale, so they are built once per
    /// stored language and region rather than on each call.
    private static func resolved() -> (bundle: Bundle, locale: Locale) {
        let language = preferredLanguage()
        let regional = Locale.autoupdatingCurrent
        return Resolution.shared.value(for: language.rawValue + "|" + regional.identifier) {
            (bundle(for: language), locale(for: language, regionalLocale: regional))
        }
    }

    private final class Resolution: @unchecked Sendable {
        static let shared = Resolution()
        private let lock = NSLock()
        private var key = ""
        private var value: (bundle: Bundle, locale: Locale)?

        func value(for key: String, make: () -> (bundle: Bundle, locale: Locale)) -> (bundle: Bundle, locale: Locale) {
            lock.lock(); defer { lock.unlock() }
            if key == self.key, let value { return value }
            let made = make()
            self.key = key
            value = made
            return made
        }
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
