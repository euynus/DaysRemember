import SwiftUI

/// Links and build information shared by 我的 and the tests. The settings rows themselves
/// live in `MeView`.
enum SettingsView {
    static let siteBase = "https://days.gooday.dev/"

    /// The site's page in the app's language: Simplified Chinese at the root, the others under
    /// `zh-Hant/` and `en/`.
    static func siteURL(_ page: String, locale: Locale = AppLocalization.locale) -> URL {
        let language = locale.language
        let prefix = language.languageCode?.identifier == "en" ? "en/"
            : language.script?.identifier == "Hant" ? "zh-Hant/" : ""
        return URL(string: siteBase + prefix + page)!
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
