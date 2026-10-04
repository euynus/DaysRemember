import Foundation

/// 24 节气 + traditional lunar holidays.
/// Note: Solar-term dates are simplified to fixed Gregorian days, matching the prototype's
/// `lunar.jsx` approximation. The real astronomical computation drifts by a day or two.
enum SolarTerms {
    private static let table: [(month: Int, day: Int, name: String)] = [
        (1,6,"小寒"),(1,20,"大寒"),(2,4,"立春"),(2,19,"雨水"),
        (3,6,"惊蛰"),(3,21,"春分"),(4,5,"清明"),(4,20,"谷雨"),
        (5,6,"立夏"),(5,21,"小满"),(6,6,"芒种"),(6,21,"夏至"),
        (7,7,"小暑"),(7,23,"大暑"),(8,8,"立秋"),(8,23,"处暑"),
        (9,8,"白露"),(9,23,"秋分"),(10,8,"寒露"),(10,24,"霜降"),
        (11,8,"立冬"),(11,22,"小雪"),(12,7,"大雪"),(12,22,"冬至"),
    ]

    static func name(for date: Date) -> String? {
        let cal = CNDate.calendar
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return table.first { $0.month == m && $0.day == d }.map {
            String(localized: String.LocalizationValue($0.name))
        }
    }

    /// Traditional Chinese holiday by lunar date (春节, 元宵, 端午, 中秋, …).
    static func lunarHoliday(for date: Date) -> String? {
        let l = Lunar.solarToLunar(date)
        let key = "\(l.month)-\(l.day)"
        let map: [String: String] = [
            "1-1":"春节", "1-15":"元宵", "2-2":"龙抬头", "5-5":"端午",
            "7-7":"七夕", "7-15":"中元", "8-15":"中秋", "9-9":"重阳",
            "12-8":"腊八", "12-23":"小年",
        ]
        return map[key].map { String(localized: String.LocalizationValue($0)) }
    }
}
