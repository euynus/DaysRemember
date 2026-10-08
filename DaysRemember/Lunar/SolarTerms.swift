import Foundation

/// 24 节气 + traditional lunar holidays.
///
/// Solar terms are the instants when the Sun's apparent longitude reaches a multiple
/// of 15°, dated in Beijing time (UTC+8). The Sun's position uses the truncated VSOP87
/// Earth series from Meeus, *Astronomical Algorithms* (ch. 25, 32 and appendix III),
/// which agrees with published equinox and solstice times to about a minute. Only a
/// term within that minute of Beijing midnight could still land on the neighbouring day.
enum SolarTerms {
    /// In order of longitude, from 小寒 (285°) to 冬至 (270°) — the order within a Gregorian year.
    private static let names = [
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
        "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑",
        "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至",
    ]

    private static let beijing: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60) ?? .current
        return c
    }()

    static func name(for date: Date) -> String? {
        let c = CNDate.calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = c.year, let month = c.month, let day = c.day,
              let index = YearCache.shared.terms(in: year)[month * 100 + day] else { return nil }
        return String(localized: String.LocalizationValue(names[index]), bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    /// The Beijing-time instants of the year's 24 terms, 小寒 first.
    static func instants(in year: Int) -> [Date] {
        guard let january = beijing.date(from: DateComponents(year: year, month: 1, day: 6)) else { return [] }
        let estimate = julianDay(january)
        return (0..<24).map { index in
            let longitude = (285 + 15 * Double(index)).truncatingRemainder(dividingBy: 360)
            var jde = estimate + 15.2184 * Double(index)
            // Newton steps at the mean solar rate converge to well under a second.
            for _ in 0..<8 {
                var delta = (longitude - apparentLongitude(jde)).truncatingRemainder(dividingBy: 360)
                if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
                jde += delta * 365.2422 / 360
                if abs(delta) < 1e-7 { break }
            }
            let ut = jde - deltaT(year: Double(year) + Double(index) / 24) / 86400
            return Date(timeIntervalSince1970: (ut - 2440587.5) * 86400)
        }
    }

    private static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400 + 2440587.5
    }

    /// Apparent geocentric longitude of the Sun in degrees, referred to the true equinox of date.
    private static func apparentLongitude(_ jde: Double) -> Double {
        let tau = (jde - 2451545) / 365250
        let t = tau * 10
        let series = [VSOP87.l0, VSOP87.l1, VSOP87.l2, VSOP87.l3, VSOP87.l4, VSOP87.l5]
        var heliocentric = 0.0
        for (power, terms) in series.enumerated() {
            let sum = terms.reduce(0) { $0 + $1.a * cos($1.b + $1.c * tau) }
            heliocentric += sum * pow(tau, Double(power))
        }
        let radians = Double.pi / 180
        let node = (125.04452 - 1934.136261 * t) * radians
        let sunMean = (280.4665 + 36000.7698 * t) * radians
        let moonMean = (218.3165 + 481267.8813 * t) * radians
        let nutation = -17.20 * sin(node) - 1.32 * sin(2 * sunMean) - 0.23 * sin(2 * moonMean) + 0.21 * sin(2 * node)
        // Geocentric = heliocentric + 180°; then FK5, nutation and aberration (arcseconds).
        return heliocentric / 1e8 / radians + 180 + (-0.09033 + nutation - 20.4898) / 3600
    }

    /// TT − UT in seconds (Espenak & Meeus polynomials); worth a minute or two at most.
    private static func deltaT(year y: Double) -> Double {
        switch y {
        case ..<1920:
            let t = y - 1900
            return -2.79 + 1.494119 * t - 0.0598939 * t * t + 0.0061966 * t * t * t - 0.000197 * t * t * t * t
        case ..<1941:
            let t = y - 1920
            return 21.20 + 0.84493 * t - 0.076100 * t * t + 0.0020936 * t * t * t
        case ..<1961:
            let t = y - 1950
            return 29.07 + 0.407 * t - t * t / 233 + t * t * t / 2547
        case ..<1986:
            let t = y - 1975
            return 45.45 + 1.067 * t - t * t / 260 - t * t * t / 718
        case ..<2005:
            let t = y - 2000
            return 63.86 + 0.3345 * t - 0.060374 * t * t + 0.0017275 * t * t * t
                + 0.000651814 * t * t * t * t + 0.00002373599 * t * t * t * t * t
        case ..<2050:
            let t = y - 2000
            return 62.92 + 0.32217 * t + 0.005589 * t * t
        default:
            let u = (y - 1820) / 100
            return -20 + 32 * u * u - 0.5628 * (2150 - y)
        }
    }

    /// Calendar cells look terms up on every render, so each year is solved once.
    private final class YearCache: @unchecked Sendable {
        static let shared = YearCache()
        private let lock = NSLock()
        private var years: [Int: [Int: Int]] = [:]

        func terms(in year: Int) -> [Int: Int] {
            lock.lock(); defer { lock.unlock() }
            if let cached = years[year] { return cached }
            var days: [Int: Int] = [:]
            for (index, instant) in SolarTerms.instants(in: year).enumerated() {
                let c = SolarTerms.beijing.dateComponents([.month, .day], from: instant)
                if let month = c.month, let day = c.day { days[month * 100 + day] = index }
            }
            years[year] = days
            return days
        }
    }

    private static let holidays: [String: String] = [
        "1-1":"春节", "1-15":"元宵", "2-2":"龙抬头", "5-5":"端午",
        "7-7":"七夕", "7-15":"中元", "8-15":"中秋", "9-9":"重阳",
        "12-8":"腊八", "12-23":"小年",
    ]

    /// Traditional Chinese holiday by lunar date (春节, 元宵, 端午, 中秋, 除夕, …).
    /// Leap months repeat a month number but never its festivals.
    static func lunarHoliday(for date: Date) -> String? {
        let l = Lunar.solarToLunar(date)
        guard !l.isLeap else { return nil }
        // 除夕 is the last day of the twelfth month, which has either 29 or 30 days.
        let name = l.month == 12 && l.day == Lunar.dayCount(year: l.year, month: 12)
            ? "除夕" : holidays["\(l.month)-\(l.day)"]
        return name.map { String(localized: String.LocalizationValue($0), bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
    }
}
