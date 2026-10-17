import SwiftUI

/// Links and build information shared by 我的 and the tests. The settings rows themselves
/// live in `MeView`.
enum SettingsView {
    static let siteBase = "https://days.gooday.dev/"

    /// The privacy and support pages hold all three languages, anchored by localization.
    static func siteURL(_ page: String, locale: Locale = AppLocalization.locale) -> URL {
        let language = locale.language
        let anchor = language.languageCode?.identifier == "en" ? "en"
            : language.script?.identifier == "Hant" ? "zh-Hant" : "zh-Hans"
        return URL(string: siteBase + page + "#" + anchor)!
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
