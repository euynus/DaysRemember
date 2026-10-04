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

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60) ?? .current
        return c
    }()

    private static let base: Date = {
        var c = DateComponents()
        c.year = 1900; c.month = 1; c.day = 31
        c.calendar = calendar
        c.timeZone = calendar.timeZone
        return c.date!
    }()

    /// Convert Gregorian Date → LunarDate.
    static func solarToLunar(_ date: Date) -> LunarDate {
        let dayStart = calendar.startOfDay(for: date)
        var offset = Int((dayStart.timeIntervalSince1970 - base.timeIntervalSince1970) / 86400.0)
        // Dates before the table's first Spring Festival (1900-01-31) fall in lunar
        // year 1899, which the 1900–2100 table can't represent. Clamp to the first
        // lunar day so callers never get an out-of-range month/day — which would trap
        // the array-indexing formatters (CN_MONTH / CN_DAY_PREFIX / CN_NUM).
        if offset < 0 { return LunarDate(year: 1900, month: 1, day: 1, isLeap: false) }
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

    /// Convert lunar date → Gregorian.
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
        if isLeap && month == leap { offset += monthDays(year, month) }
        offset += day - 1
        return base.addingTimeInterval(TimeInterval(offset) * 86400)
    }

    // MARK: - Safe picker helpers

    /// Half-open range including every day of the final supported lunar year.
    static let supportedSolarDates: Range<Date> = base..<base.addingTimeInterval(
        TimeInterval(yearOffsets[LunarTable.info.count]) * 86400
    )

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
            : supportedSolarDates.upperBound.addingTimeInterval(-86400)
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
        if d == 10 { return "初十" }
        if d == 20 { return "二十" }
        if d == 30 { return "三十" }
        let t = d / 10
        let onesIndex = (d % 10 == 0 ? 10 : d % 10) - 1
        return CN_DAY_PREFIX[t] + CN_NUM[onesIndex]
    }

    static func monthCN(_ m: Int, isLeap: Bool) -> String {
        (isLeap ? "闰" : "") + CN_MONTH[m - 1] + "月"
    }

    static func ganZhi(_ y: Int) -> String {
        GAN[(y - 4 + 60) % 10] + ZHI[(y - 4 + 60) % 12]
    }

    static func zodiac(_ y: Int) -> String {
        ZODIAC[(y - 4 + 60) % 12]
    }

    /// "九月十四"
    static func fmt(_ date: Date) -> String {
        guard let l = supportedLunarDate(for: date) else { return "日期超出范围" }
        return monthCN(l.month, isLeap: l.isLeap) + dayCN(l.day)
    }

    /// "农历己亥猪年 · 九月十四"
    static func fmtFull(_ date: Date) -> String {
        guard let l = supportedLunarDate(for: date) else { return "农历日期超出范围" }
        return "农历\(ganZhi(l.year))\(zodiac(l.year))年 · \(monthCN(l.month, isLeap: l.isLeap))\(dayCN(l.day))"
    }
}
