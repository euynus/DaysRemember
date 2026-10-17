import Foundation

/// Chinese lunar calendar — port of `lunar.jsx`. Coverage: 1900-01-31 → ~2100.
enum Lunar {
    private static let GAN = ["甲","乙","丙","丁","戊","己","庚","辛","壬","癸"]
    private static let ZHI = ["子","丑","寅","卯","辰","巳","午","未","申","酉","戌","亥"]
    private static let ZODIAC = ["鼠","牛","虎","兔","龙","蛇","马","羊","猴","鸡","狗","猪"]
    private static let CN_MONTH = ["正","二","三","四","五","六","七","八","九","十","冬","腊"]
    private static let CN_DAY_PREFIX = ["初","十","廿","卅"]
    private static let CN_NUM = ["一","二","三","四","五","六","七","八","九","十"]

    struct LunarDate: Equatable {
        var year: Int
        var month: Int
        var day: Int
        var isLeap: Bool
    }

    struct Month: Hashable {
        let number: Int
        let isLeap: Bool
    }

    static let supportedYears = 1900...(1900 + LunarTable.info.count - 1)

    private static func tableValue(_ y: Int) -> UInt32 {
        let idx = y - 1900
        guard idx >= 0 && idx < LunarTable.info.count else { return 0 }
        return LunarTable.info[idx]
    }

    private static func leapMonth(_ y: Int) -> Int { Int(tableValue(y) & 0xf) }
    private static func leapDays(_ y: Int) -> Int {
        leapMonth(y) > 0 ? ((tableValue(y) & 0x10000) != 0 ? 30 : 29) : 0
    }
    private static func monthDays(_ y: Int, _ m: Int) -> Int {
        (tableValue(y) & (UInt32(0x10000) >> m)) != 0 ? 30 : 29
    }
    private static func yearDays(_ y: Int) -> Int {
        var sum = 348
        var i: UInt32 = 0x8000
        while i > 0x8 {
            if (tableValue(y) & i) != 0 { sum += 1 }
            i >>= 1
        }
        return sum + leapDays(y)
    }

    // Immutable year boundaries are shared by calendar cells and anniversary lookups.
    private static let yearOffsets: [Int] = (1900..<(1900 + LunarTable.info.count))
        .reduce(into: [0]) { offsets, year in
            offsets.append(offsets.last! + yearDays(year))
        }

    /// The app's calendar. Its midnights aren't always UTC+8 midnights: Asia/Shanghai kept daylight
    /// saving in 1919, 1940–1949 and 1986–1991, and local mean time before 1901. So days are
    /// counted from calendar dates rather than from elapsed seconds.
    private static let calendar = CNDate.calendar

    /// 1900-01-31, 正月初一 of the table's first year, as a day number (see `dayNumber`).
    private static let baseDay = dayNumber(year: 1900, month: 1, day: 31)

    private static let base = solarDate(dayOffset: 0)

    /// Days since 1970-01-01 for a Gregorian date (Howard Hinnant's `days_from_civil`).
    private static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146097 + dayOfEra - 719468
    }

    /// The start of the day `offset` days after 1900-01-31 (the inverse, `civil_from_days`). It's
    /// found from noon, because some daylight-saving changes skipped midnight.
    private static func solarDate(dayOffset offset: Int) -> Date {
        let z = baseDay + offset + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let dayOfEra = z - era * 146097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return calendar.startOfDay(for: calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!)
    }

    /// Convert Gregorian Date → LunarDate.
    static func solarToLunar(_ date: Date) -> LunarDate {
        let solar = calendar.dateComponents([.year, .month, .day], from: date)
        var offset = dayNumber(year: solar.year!, month: solar.month!, day: solar.day!) - baseDay
        // Dates before the table's first Spring Festival (1900-01-31) fall in lunar
        // year 1899, which the 1900–2100 table can't represent. Clamp to the first
        // lunar day so callers never get an out-of-range month/day — which would trap
        // the array-indexing formatters (CN_MONTH / CN_DAY_PREFIX / CN_NUM).
        if offset < 0 { return LunarDate(year: 1900, month: 1, day: 1, isLeap: false) }
        // Likewise after the table's last day, which would otherwise run on into month 13.
        offset = min(offset, yearOffsets[LunarTable.info.count] - 1)
        let yearIndex = yearOffsets.lastIndex(where: { $0 <= offset })!
        let y = 1900 + yearIndex
        offset -= yearOffsets[yearIndex]
        var temp = 0

        let leap = leapMonth(y)
        var isLeap = false
        var m = 1
        while m < 13 && offset > 0 {
            if leap > 0 && m == leap + 1 && !isLeap {
                m -= 1
                isLeap = true
                temp = leapDays(y)
            } else {
                temp = monthDays(y, m)
            }
            if isLeap && m == leap + 1 { isLeap = false }
            offset -= temp
            m += 1
        }
        if offset == 0 && leap > 0 && m == leap + 1 {
            if isLeap { isLeap = false } else { isLeap = true; m -= 1 }
        }
        if offset < 0 { offset += temp; m -= 1 }
        return LunarDate(year: y, month: m, day: offset + 1, isLeap: isLeap)
    }

    /// Convert lunar date → Gregorian. A 三十 in a year whose month has 29 days falls on its last
    /// day, as 除夕 does, rather than on the next month's 初一.
    static func lunarToSolar(year: Int, month: Int, day: Int, isLeap: Bool = false) -> Date {
        var offset = 0
        if yearOffsets.indices.contains(year - 1900) {
            offset = yearOffsets[year - 1900]
        } else {
            for y in 1900..<year { offset += yearDays(y) }
        }
        let leap = leapMonth(year)
        for m in 1..<month { offset += monthDays(year, m) }
        if leap > 0 && month > leap { offset += leapDays(year) }
        let inLeapMonth = isLeap && month == leap
        if inLeapMonth { offset += monthDays(year, month) }
        offset += min(day, inLeapMonth ? leapDays(year) : monthDays(year, month)) - 1
        return solarDate(dayOffset: offset)
    }

    // MARK: - Safe picker helpers

    /// Half-open range including every day of the final supported lunar year.
    static let supportedSolarDates: Range<Date> = base..<solarDate(dayOffset: yearOffsets[LunarTable.info.count])

    static func months(in year: Int) -> [Month] {
        guard supportedYears.contains(year) else { return [] }
        return (1...12).flatMap { month in
            let regular = Month(number: month, isLeap: false)
            return leapMonth(year) == month
                ? [regular, Month(number: month, isLeap: true)] : [regular]
        }
    }

    static func dayCount(year: Int, month: Int, isLeap: Bool = false) -> Int? {
        guard supportedYears.contains(year), (1...12).contains(month) else { return nil }
        if isLeap {
            guard leapMonth(year) == month else { return nil }
            return leapDays(year)
        }
        return monthDays(year, month)
    }

    /// A missing leap month falls back to the same numbered regular month.
    static func clamped(_ lunar: LunarDate) -> LunarDate {
        let year = min(max(lunar.year, supportedYears.lowerBound), supportedYears.upperBound)
        let month = min(max(lunar.month, 1), 12)
        let isLeap = lunar.isLeap && leapMonth(year) == month
        let count = isLeap ? leapDays(year) : monthDays(year, month)
        return LunarDate(year: year, month: month, day: min(max(lunar.day, 1), count),
                         isLeap: isLeap)
    }

    /// Unlike the legacy conversion, rejects dates outside the table.
    static func supportedLunarDate(for date: Date) -> LunarDate? {
        guard supportedSolarDates.contains(date) else { return nil }
        return solarToLunar(date)
    }

    /// A display-only fallback; opening a picker must not replace its source date.
    static func pickerDate(for date: Date) -> LunarDate {
        if let lunar = supportedLunarDate(for: date) { return lunar }
        let boundary = date < supportedSolarDates.lowerBound
            ? supportedSolarDates.lowerBound
            : solarDate(dayOffset: yearOffsets[LunarTable.info.count] - 1)
        return solarToLunar(boundary)
    }

    /// Invalid components are rejected rather than normalized by the converter.
    static func solarDate(for lunar: LunarDate) -> Date? {
        guard let count = dayCount(year: lunar.year, month: lunar.month, isLeap: lunar.isLeap),
              (1...count).contains(lunar.day) else { return nil }
        return lunarToSolar(year: lunar.year, month: lunar.month, day: lunar.day,
                            isLeap: lunar.isLeap)
    }

    // MARK: - Formatting

    static func dayCN(_ d: Int) -> String {
        if AppLocalization.isEnglish { return String(localized: "第\(d)日", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        if d == 10 { return "初十" }
        if d == 20 { return "二十" }
        if d == 30 { return "三十" }
        let t = d / 10
        let onesIndex = (d % 10 == 0 ? 10 : d % 10) - 1
        return CN_DAY_PREFIX[t] + CN_NUM[onesIndex]
    }

    static func monthCN(_ m: Int, isLeap: Bool) -> String {
        if AppLocalization.isEnglish {
            return isLeap ? String(localized: "闰\(m)月", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "\(m)月", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        let month = String(localized: String.LocalizationValue(CN_MONTH[m - 1]), bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        return (isLeap ? String(localized: "闰", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : "") + month + String(localized: "月", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    static func ganZhi(_ y: Int) -> String {
        GAN[(y - 4 + 60) % 10] + ZHI[(y - 4 + 60) % 12]
    }

    static func zodiac(_ y: Int) -> String {
        String(localized: String.LocalizationValue(ZODIAC[(y - 4 + 60) % 12]), bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    /// "九月十四"
    static func fmt(_ date: Date) -> String {
        guard let l = supportedLunarDate(for: date) else { return String(localized: "日期超出范围", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        return monthCN(l.month, isLeap: l.isLeap) + (AppLocalization.isEnglish ? ", " : "") + dayCN(l.day)
    }

    /// "农历己亥猪年 · 九月十四"
    static func fmtFull(_ date: Date) -> String {
        guard let l = supportedLunarDate(for: date) else { return String(localized: "农历日期超出范围", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        if AppLocalization.isEnglish {
            return String(localized: "农历\(String(l.year))年 · \(fmt(date))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        return String(localized: "农历\(ganZhi(l.year))\(zodiac(l.year))年 · \(monthCN(l.month, isLeap: l.isLeap))\(dayCN(l.day))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }
}
