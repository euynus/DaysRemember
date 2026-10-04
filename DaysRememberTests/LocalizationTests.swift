import XCTest
@testable import DaysRemember

@MainActor
final class LocalizationTests: XCTestCase {
    private let languages = ["zh-Hans", "zh-Hant", "en"]

    func testAppAndWidgetBundleEverySupportedLanguage() throws {
        let plugins = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let widget = try XCTUnwrap(Bundle(url: plugins.appendingPathComponent("DaysRememberWidget.appex")))
        for bundle in [Bundle.main, widget] {
            for language in languages {
                let localized = try localizedBundle(language, in: bundle)
                let name = localized.localizedString(forKey: "CFBundleDisplayName", value: nil, table: "InfoPlist")
                XCTAssertEqual(name, language == "en" ? "Days Remember" : language == "zh-Hant" ? "時光" : "时光")
                XCTAssertEqual(String(localized: "日历", bundle: localized),
                               language == "en" ? "Calendar" : language == "zh-Hant" ? "日曆" : "日历")
            }
        }
    }

    func testEnglishPluralRulesAndMultipleInterpolationArguments() throws {
        let bundle = try localizedBundle("en")
        let locale = Locale(identifier: "en_US")
        for count in [0, 1, 2, 23] {
            let expectedUnit = count == 1 ? "day" : "days"
            XCTAssertEqual(String(localized: "\(count)天后", bundle: bundle, locale: locale),
                           "in \(count) \(expectedUnit)")
            XCTAssertEqual(String(localized: "\(count)天前", bundle: bundle, locale: locale),
                           "\(count) \(expectedUnit) ago")
            let title = "100% My Day"
            XCTAssertEqual(String(localized: "「\(title)」还有 \(count) 天", bundle: bundle, locale: locale),
                           "“\(title)” is in \(count) \(expectedUnit).")
            XCTAssertEqual(String(localized: "countdown.daysLeftUnit", defaultValue: "\(count)天后",
                                  bundle: bundle, locale: locale), "\(expectedUnit) to go")
            XCTAssertEqual(String(localized: "countdown.daysAgoUnit", defaultValue: "\(count)天前",
                                  bundle: bundle, locale: locale), "\(expectedUnit) ago")
            let date = "April 23, 2026"
            XCTAssertEqual(String(localized: "\(date)，\(count) 个日子", bundle: bundle, locale: locale),
                           "\(date), \(count) \(count == 1 ? "event" : "events")")
            XCTAssertEqual(String(localized: "其中 \(count) 条日期提醒，最晚至 \(date)", bundle: bundle, locale: locale),
                           "\(count) dated \(count == 1 ? "reminder" : "reminders"), through \(date)")
        }
    }

    func testLocalizedDatesKeepShanghaiDayBoundaries() throws {
        let date = try XCTUnwrap(CNDate.calendar.date(from: DateComponents(year: 2026, month: 4, day: 23)))
        XCTAssertEqual(CNDate.full(date, locale: Locale(identifier: "en_US")), "April 23, 2026")
        XCTAssertEqual(CNDate.short(date, locale: Locale(identifier: "en_US")), "Apr 23")
        XCTAssertEqual(CNDate.weekday(date, locale: Locale(identifier: "en_US")), "Thursday")
        XCTAssertEqual(CNDate.full(date, locale: Locale(identifier: "zh_Hans_CN")), "2026年4月23日")
        XCTAssertEqual(CNDate.full(date, locale: Locale(identifier: "zh_Hant_TW")), "2026年4月23日")
        XCTAssertEqual(CNDate.calendar.timeZone.identifier, "Asia/Shanghai")
        XCTAssertEqual(CNDate.daysBetween(date, date.addingTimeInterval(86400)), 1)
    }

    func testAppLanguageRetainsTheUsersRegion() {
        let english = AppLocalization.locale(for: "en", regionalLocale: Locale(identifier: "zh_CN"))
        XCTAssertEqual(english.language.languageCode?.identifier, "en")
        XCTAssertEqual(english.region?.identifier, "CN")
        let traditional = AppLocalization.locale(for: "zh-Hant", regionalLocale: Locale(identifier: "en_GB"))
        XCTAssertEqual(traditional.language.script?.identifier, "Hant")
        XCTAssertEqual(traditional.region?.identifier, "GB")
    }

    func testDisplayingLocalizedCategoriesNeverRewritesStoredOrCustomNames() throws {
        let originalNames = ["爱情", "家人", "旅行", "工作", "生活"]
        XCTAssertEqual(CategoryDefinition.system.map(\.name), originalNames)
        let custom = CategoryDefinition(id: "custom.keep", name: "生活", icon: "tag", colorToken: .sage, isSystem: false)
        XCTAssertEqual(custom.displayName, "生活")
        let day = Day(id: "keep", title: "日历", date: Date(timeIntervalSince1970: 1_700_000_000),
                      category: .life, photo: .home, categoryID: custom.id,
                      note: "Days Remember / 時光 / 时光", location: "家人", categoryLabel: custom.name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(day)
        XCTAssertEqual(day.categoryDisplayName, "生活")
        _ = CategoryDefinition.system.map(\.displayName)
        XCTAssertEqual(try encoder.encode(day), before)
        XCTAssertEqual(try JSONDecoder().decode(Day.self, from: before), day)
    }

    func testCurrentLanguageLocalizesLunarLabelsAndSystemCategories() {
        let leap = Lunar.lunarToSolar(year: 2023, month: 2, day: 1, isLeap: true)
        let language = Bundle.main.preferredLocalizations.first
        if language == "en" {
            XCTAssertEqual(Lunar.fmt(leap), "Leap month 2, Day 1")
            XCTAssertEqual(Lunar.fmtFull(leap), "Lunar 2023 · Leap month 2, Day 1")
            XCTAssertEqual(DayCategory.love.displayName, "Love")
        } else if language == "zh-Hant" {
            XCTAssertEqual(Lunar.fmt(leap), "閏二月初一")
            XCTAssertEqual(Lunar.monthCN(12, isLeap: false), "臘月")
            XCTAssertEqual(DayCategory.love.displayName, "愛情")
        } else {
            XCTAssertEqual(language, "zh-Hans")
            XCTAssertEqual(Lunar.fmt(leap), "闰二月初一")
            XCTAssertEqual(DayCategory.love.displayName, "爱情")
        }
    }

    func testCurrentLanguageLocalizesNotificationPayloadWithoutChangingItsIdentity() throws {
        let settings = try JSONDecoder().decode(AppSettingsSnapshot.self, from: Data("""
        {"hasOnboarded":true,"notifPre7":false,"notifPre3":false,"notifPre1":false,"notifDay0":true,
         "memoryEnabled":false,"momentsEnabled":false,"quietHours":true,"notificationHour":9,"notificationMinute":0}
        """.utf8))
        let date = try XCTUnwrap(CNDate.calendar.date(from: DateComponents(year: 2026, month: 4, day: 23)))
        let day = Day(id: "stable-day-id", title: "My Day", date: date, category: .life, photo: .home,
                      reminderOffsets: [7], location: "Home")
        let plan = NotificationManager.plan(days: [day], settings: settings,
                                             now: date.addingTimeInterval(-14 * 86400))
        let reminder = try XCTUnwrap(plan.first)
        XCTAssertEqual(reminder.dayID, day.id)
        XCTAssertTrue(reminder.id.hasPrefix("dr.day.stable-day-id.pre.7."))
        XCTAssertEqual(reminder.request.content.userInfo["dayID"] as? String, day.id)
        if AppLocalization.isEnglish {
            XCTAssertEqual(reminder.title, "Days Remember")
            XCTAssertEqual(reminder.body, "“My Day” is in 7 days. · Home")
        } else if Bundle.main.preferredLocalizations.first == "zh-Hant" {
            XCTAssertEqual(reminder.title, "時光")
            XCTAssertEqual(reminder.body, "「My Day」還有 7 天 · Home")
        } else {
            XCTAssertEqual(reminder.title, "时光")
            XCTAssertEqual(reminder.body, "「My Day」还有 7 天 · Home")
        }
    }

    func testBackupErrorsAreAvailableInEveryLanguage() throws {
        let key = "无法读取此备份，原有数据未更改。"
        for language in languages {
            let text = String(localized: String.LocalizationValue(key), bundle: try localizedBundle(language))
            XCTAssertFalse(text.isEmpty)
            if language == "en" { XCTAssertEqual(text, "This backup could not be read. Your existing data has not changed.") }
            if language == "zh-Hant" { XCTAssertEqual(text, "無法讀取此備份，原有資料未變更。") }
        }
    }

    func testCurrentLanguageWidgetKeepsFullCountdownAndUserTitle() throws {
        let today = try XCTUnwrap(CNDate.calendar.date(from: DateComponents(year: 2026, month: 4, day: 23)))
        for offset in [-123456, -1, 1, 2, 123456] {
            let date = try XCTUnwrap(CNDate.calendar.date(byAdding: .day, value: offset, to: today))
            let day = Day(id: "localized-widget", title: "100% My Day", date: date, category: .life, photo: .home)
            let count = abs(offset).formatted(.number.locale(AppLocalization.locale))
            let expected: String
            if AppLocalization.isEnglish {
                let unit = abs(offset) == 1 ? "day" : "days"
                expected = offset < 0 ? "\(count) \(unit) ago" : "in \(count) \(unit)"
            } else {
                let future = Bundle.main.preferredLocalizations.first == "zh-Hant" ? "天後" : "天后"
                expected = count + (offset < 0 ? "天前" : future)
            }
            for style in [DayAccessoryWidget.Style.circular, .rectangular, .inline] {
                let widget = DayAccessoryWidget(day: day, style: style, today: today)
                XCTAssertTrue(widget.accessibilitySummary.hasPrefix(day.title))
                XCTAssertTrue(widget.accessibilitySummary.contains(expected), widget.accessibilitySummary)
                XCTAssertTrue(widget.accessibilitySummary.contains(CNDate.full(date)))
            }
        }
    }

    private func localizedBundle(_ language: String, in bundle: Bundle = .main) throws -> Bundle {
        let url = try XCTUnwrap(bundle.url(forResource: language, withExtension: "lproj"))
        return try XCTUnwrap(Bundle(url: url))
    }
}
