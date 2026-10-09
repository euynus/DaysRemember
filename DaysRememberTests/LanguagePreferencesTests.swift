import XCTest
@testable import DaysRemember

@MainActor
final class LanguagePreferencesTests: XCTestCase {
    func testLanguageIdentifiersAndAutonymsStayStable() {
        XCTAssertEqual(AppLocalization.languageKey, "app.language.v1")
        XCTAssertEqual(AppLanguage.allCases, [.system, .simplifiedChinese, .traditionalChinese, .english])
        XCTAssertEqual(AppLanguage.allCases.map(\.rawValue), ["system", "zh-Hans", "zh-Hant", "en"])
        XCTAssertEqual(AppLanguage.allCases.map(\.id), AppLanguage.allCases.map(\.rawValue))
        XCTAssertEqual(AppLanguage.simplifiedChinese.displayName, "简体中文")
        XCTAssertEqual(AppLanguage.traditionalChinese.displayName, "繁體中文")
        XCTAssertEqual(AppLanguage.english.displayName, "English")
    }

    func testAbsentPreferenceFallsBackToSystemWithoutWritingADefault() throws {
        try withDefaults { defaults in
            XCTAssertNil(defaults.object(forKey: AppLocalization.languageKey))
            XCTAssertEqual(AppLocalization.preferredLanguage(defaults: defaults), .system)
            XCTAssertNil(defaults.object(forKey: AppLocalization.languageKey))
        }
    }

    func testInvalidPreferencesFallBackToSystem() throws {
        try withDefaults { defaults in
            let invalidValues: [Any] = ["", "fr", "en_US", "zh_CN", "SYSTEM", 42, ["en"]]
            for value in invalidValues {
                defaults.set(value, forKey: AppLocalization.languageKey)
                XCTAssertEqual(AppLocalization.preferredLanguage(defaults: defaults), .system,
                               "Invalid preference: \(value)")
            }
        }
    }

    func testEverySupportedPreferenceIsReadFromTheInjectedDefaults() throws {
        try withDefaults { defaults in
            for language in AppLanguage.allCases {
                defaults.set(language.rawValue, forKey: AppLocalization.languageKey)
                XCTAssertEqual(AppLocalization.preferredLanguage(defaults: defaults), language)
            }
            defaults.removeObject(forKey: AppLocalization.languageKey)
            XCTAssertEqual(AppLocalization.preferredLanguage(defaults: defaults), .system)
        }
    }

    func testExplicitLanguagesRetainTheRegionalLocaleAndLegacyStringAPI() {
        let cases: [(AppLanguage, String, String, String?)] = [
            (.english, "zh_CN", "en", nil),
            (.simplifiedChinese, "en_GB", "zh", "Hans"),
            (.traditionalChinese, "en_US", "zh", "Hant")
        ]
        for (language, region, code, script) in cases {
            let regionalLocale = Locale(identifier: region)
            let locale = AppLocalization.locale(for: language, regionalLocale: regionalLocale)
            XCTAssertEqual(locale.language.languageCode?.identifier, code)
            if let script { XCTAssertEqual(locale.language.script?.identifier, script) }
            XCTAssertEqual(locale.region, regionalLocale.region)
            XCTAssertEqual(locale, AppLocalization.locale(for: language.rawValue, regionalLocale: regionalLocale))
        }
        let regionless = AppLocalization.locale(for: .traditionalChinese, regionalLocale: Locale(identifier: "en"))
        XCTAssertNil(regionless.region)
    }

    func testSiteLinksOpenTheSectionInTheAppLanguage() {
        let cases: [(AppLanguage, String, String)] = [
            (.simplifiedChinese, "en_US", "zh-Hans"),
            (.traditionalChinese, "zh_CN", "zh-Hant"),
            (.english, "zh_TW", "en")
        ]
        for (language, region, anchor) in cases {
            let locale = AppLocalization.locale(for: language, regionalLocale: Locale(identifier: region))
            XCTAssertEqual(SettingsView.siteURL("privacy/", locale: locale).absoluteString,
                           "https://days.gooday.dev/privacy/#\(anchor)")
        }
    }

    func testSystemUsesTheSuppliedBundlesLanguageAndMissingLocalizationFallsBack() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LanguagePreferencesTests-\(UUID().uuidString).bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("zh-Hant.lproj"),
                                               withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let info: [String: Any] = [
            "CFBundleIdentifier": "LanguagePreferencesTests.\(UUID().uuidString)",
            "CFBundlePackageType": "BNDL",
            "CFBundleDevelopmentRegion": "zh-Hant",
            "CFBundleLocalizations": ["zh-Hant"]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: directory.appendingPathComponent("Info.plist"))
        let source = try XCTUnwrap(Bundle(url: directory))
        XCTAssertEqual(source.preferredLocalizations.first, "zh-Hant")

        let locale = AppLocalization.locale(for: .system, regionalLocale: Locale(identifier: "en_GB"),
                                            bundle: source)
        XCTAssertEqual(locale.language.languageCode?.identifier, "zh")
        XCTAssertEqual(locale.language.script?.identifier, "Hant")
        XCTAssertEqual(locale.region?.identifier, "GB")
        XCTAssertEqual(AppLocalization.bundle(for: .system, in: source).bundleURL, source.bundleURL)
        XCTAssertEqual(AppLocalization.bundle(for: .english, in: source).bundleURL, source.bundleURL)
        XCTAssertEqual(AppLocalization.bundle(for: .system).bundleURL, Bundle.main.bundleURL)
    }

    func testSelectedBundlesResolveTranslationsAndPluralRules() throws {
        let cases: [(AppLanguage, String)] = [
            (.simplifiedChinese, "日历"), (.traditionalChinese, "日曆"), (.english, "Calendar")
        ]
        for (language, calendarTitle) in cases {
            let expectedURL = try XCTUnwrap(Bundle.main.url(forResource: language.rawValue, withExtension: "lproj"))
            let bundle = AppLocalization.bundle(for: language)
            let locale = AppLocalization.locale(for: language, regionalLocale: Locale(identifier: "en_US"))
            XCTAssertEqual(bundle.bundleURL, expectedURL)
            XCTAssertEqual(String(localized: "日历", bundle: bundle, locale: locale), calendarTitle)

            for count in [0, 1, 2, 23] {
                let expected: String
                let unit: String
                switch language {
                case .english:
                    expected = "in \(count) \(count == 1 ? "day" : "days")"
                    unit = count == 1 ? "day to go" : "days to go"
                case .traditionalChinese:
                    expected = "\(count)天後"
                    unit = "天後"
                default:
                    expected = "\(count)天后"
                    unit = "天后"
                }
                XCTAssertEqual(String(localized: "\(count)天后", bundle: bundle, locale: locale), expected)
                XCTAssertEqual(String(localized: "countdown.daysLeftUnit", defaultValue: "\(count)天后",
                                      bundle: bundle, locale: locale), unit)
            }
        }
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "LanguagePreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
