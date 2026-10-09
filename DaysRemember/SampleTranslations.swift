#if DEBUG
import Foundation

/// Translated copies of `SampleData` for App Store screenshots (`--localized-samples`).
/// The samples stand in for user content, which the app never translates, so regular
/// fixtures keep the original Chinese.
enum SampleTranslations {
    private struct Text {
        var title: String
        var note = ""
        var location = ""
        var categoryLabel = ""
    }

    static func days(for localization: String) -> [Day] {
        guard let table = tables[localization] else { return SampleData.days }
        return SampleData.days.map { day in
            guard let text = table[day.id] else { return day }
            var day = day
            day.title = text.title
            if !day.note.isEmpty { day.note = text.note }
            if !day.location.isEmpty { day.location = text.location }
            if !text.categoryLabel.isEmpty { day.categoryLabel = text.categoryLabel }
            return day
        }
    }

    /// The localization the app resolves to, e.g. `zh-Hant`.
    static var currentLocalization: String {
        let language = AppLocalization.preferredLanguage()
        return language == .system ? Bundle.main.preferredLocalizations.first ?? "zh-Hans" : language.rawValue
    }

    private static let tables: [String: [String: Text]] = [
        "zh-Hant": [
            "wedding": Text(title: "結婚紀念日", note: "那天下了一場小雨，你笑著說是天使撒花。", location: "杭州 · 西湖"),
            "baby": Text(title: "小年糕出生", note: "6斤3兩，凌晨3:47。", location: "上海 · 第一婦嬰"),
            "birthday": Text(title: "媽媽生日", note: "今年是 64 歲，要訂桂花糖藕。"),
            "midautumn": Text(title: "中秋團圓", note: "今年回家吃媽媽做的月餅。"),
            "japan": Text(title: "北海道旅行", note: "札幌→小樽→函館，記得提前訂民宿。", location: "日本 · 北海道"),
            "kaoyan": Text(title: "考研初試", note: "今天背了 80 個單字，還差 1200。", categoryLabel: "學業"),
            "firstmet": Text(title: "與他相遇", note: "圖書館三樓，靠窗的位置。"),
            "work": Text(title: "入職週年"),
            "dog": Text(title: "領養豆豆", note: "從流浪動物救助站帶回家的那天。"),
            "moved": Text(title: "搬進新家", location: "上海 · 徐匯"),
        ],
        "en": [
            "wedding": Text(title: "Wedding Anniversary",
                            note: "It drizzled that day, and you laughed that the angels were scattering petals.",
                            location: "West Lake, Hangzhou"),
            "baby": Text(title: "Little Niangao Arrives", note: "3.15 kg, at 3:47 in the morning.",
                         location: "Shanghai First Maternity Hospital"),
            "birthday": Text(title: "Mom's Birthday", note: "She turns 64 this year. Order the osmanthus lotus root."),
            "midautumn": Text(title: "Mid-Autumn Reunion", note: "Home this year for Mom's mooncakes."),
            "japan": Text(title: "Hokkaido Trip", note: "Sapporo → Otaru → Hakodate. Book the guesthouses early.",
                          location: "Hokkaido, Japan"),
            "kaoyan": Text(title: "Grad School Entrance Exam", note: "Learned 80 words today, 1,200 to go.",
                           categoryLabel: "Study"),
            "firstmet": Text(title: "The Day We Met", note: "Third floor of the library, the seat by the window."),
            "work": Text(title: "Work Anniversary"),
            "dog": Text(title: "Adopting Doudou", note: "The day we brought him home from the animal shelter."),
            "moved": Text(title: "Moving into Our New Home", location: "Xuhui, Shanghai"),
        ],
    ]
}
#endif
