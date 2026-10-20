import XCTest
@testable import DaysRemember

/// Times the work the main screens repeat on every update, over a heavy library: 300 days
/// (one-time, yearly and lunar yearly) with 60 photos. Each line reports the median and slowest
/// of several warm samples, so a regression shows up as a number rather than a feeling.
@MainActor
final class HotPathPerformanceTests: XCTestCase {
    private let today = CNDate.calendar.date(from: DateComponents(year: 2026, month: 4, day: 23))!
    private var store: DayStore!
    private var days: [Day] = []

    /// Each test builds the library on the main actor, where the store lives.
    private func prepare() throws {
        let suite = "HotPathPerformanceTests.\(UUID().uuidString)"
        // File-backed photos, as the app stores them.
        let directory = URL.temporaryDirectory.appending(path: suite, directoryHint: .isDirectory)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        store = DayStore(defaults: defaults, photoDirectory: directory)
        days = Self.library(count: 300, photos: 60)
        store.days = days
    }

    func testHomeFeedDerivation() throws {
        try prepare()
        benchmark("home_feed") {
            let sorted = store.sortedDays(store.days, today: today)
            var upcoming: [Day] = []
            var past: [Day] = []
            for day in sorted {
                if DayInfo.compute(day, today: today).isPast { past.append(day) } else { upcoming.append(day) }
            }
            let heroes = upcoming.map { ($0, DayInfo.compute($0, today: today).days) }
                .sorted { $0.1 < $1.1 }.prefix(5).map(\.0)
            let recent = store.days.compactMap { RecentOccurrence.of($0, today: today) }
            let milestones = past.compactMap { Milestone.next(after: $0.date, today: today) }
            return heroes.count + recent.count + milestones.count
        }
    }

    /// The parts of the home feed, to see which one costs what.
    func testHomeFeedParts() throws {
        try prepare()
        benchmark("home_feed_sort_split") {
            let sorted = store.sortedDays(store.days, today: today)
            return sorted.count { DayInfo.compute($0, today: today).isPast }
        }
        benchmark("home_feed_recent_occurrence") {
            store.days.compactMap { RecentOccurrence.of($0, today: today) }.count
        }
        let past = store.days.filter { DayInfo.compute($0, today: today).isPast }
        benchmark("home_feed_milestones") {
            past.compactMap { Milestone.next(after: $0.date, today: today) }.count
        }
    }

    func testSearchKeystroke() throws {
        try prepare()
        let sorted = store.sortedDays(store.days, today: today)
        benchmark("search_keystroke") {
            sorted.filter { day in
                [day.title, day.location, day.note, store.category(for: day).displayName]
                    .contains { $0.localizedStandardContains("京都") }
            }.count
        }
    }

    func testMeStatsDerivation() throws {
        try prepare()
        benchmark("me_stats") {
            let infos = store.days.map { ($0, DayInfo.compute($0, today: today)) }
            let past = infos.filter { $0.1.isPast }
            return past.count + store.daysByCategory(today: today).count
        }
    }

    func testCalendarEventsByDay() throws {
        try prepare()
        benchmark("calendar_events_by_day") {
            var map: [Int: [Day]] = [:]
            let cal = CNDate.calendar
            for day in store.days {
                for occurrence in DayInfo.occurrences(of: day, inGregorianYear: 2026)
                where cal.component(.month, from: occurrence) == 4 {
                    map[cal.component(.day, from: occurrence), default: []].append(day)
                }
            }
            return map.count
        }
    }

    /// What the 30 visible cells of a month compute for their labels on each update.
    func testCalendarMonthCells() throws {
        try prepare()
        benchmark("calendar_month_cells") {
            var total = 0
            for dayNumber in 1...30 {
                let date = CNDate.calendar.date(from: DateComponents(year: 2026, month: 4, day: dayNumber))!
                let marks = SolarTerms.marks(for: date)
                let lunar = Lunar.supportedLunarDate(for: date).map { l in
                    l.day == 1 ? Lunar.monthCN(l.month, isLeap: l.isLeap) : Lunar.dayCN(l.day)
                }
                let dateLabel = CNDate.full(date)
                let lunarLabel = String(localized: "\(dateLabel)，\(Lunar.fmt(date))",
                                        bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                let label = marks.reduce(lunarLabel) {
                    String(localized: "\($0)，\($1)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                }
                total += label.count + (lunar?.count ?? 0)
            }
            return total
        }
    }

    /// The cache lookup each visible photo tile makes on every update: 20 tiles, each keeping
    /// its photo's digest as `PhotoTile` does.
    func testPhotoTileCacheKeys() throws {
        try prepare()
        let photos = Array(days.compactMap(\.photoData).prefix(20))
        let memos = photos.map { _ in PhotoDigestMemo() }
        benchmark("photo_tile_cache_lookups") {
            zip(photos, memos).reduce(0) { total, tile in
                let digest = tile.1.digest(of: tile.0)
                return total + (PhotoDecodeCache.cached(digest: digest, maximumPixelSize: 256) == nil ? 1 : 0)
            }
        }
    }

    /// Runs after every edit that changes a day.
    func testNotificationPlanning() throws {
        try prepare()
        let settings = try JSONDecoder().decode(AppSettingsSnapshot.self, from: Data("""
        {"hasOnboarded":true,"notifPre7":true,"notifPre3":true,"notifPre1":false,"notifDay0":true,
         "memoryEnabled":true,"momentsEnabled":true,"quietHours":false,"notificationHour":9,"notificationMinute":0}
        """.utf8))
        benchmark("notification_plan") {
            NotificationManager.plan(days: store.days, settings: settings, now: today).count
        }
    }

    /// One pin toggle through `days.didSet`: normalization, the encoded write and the widget poke.
    func testStoreUpdate() throws {
        try prepare()
        var toggles = 0
        benchmark("store_update", samples: 9) {
            var edited = store.days[150]
            edited.pinned.toggle()
            toggles += 1
            return store.update(edited) ? 1 : 0
        }
        XCTAssertGreaterThan(toggles, 0)
    }

    // MARK: - Helpers

    private func benchmark(_ name: String, samples: Int = 15, _ body: () -> Int) {
        _ = body() // warm-up, as a screen's second update would be
        var times: [Double] = []
        var sink = 0
        for _ in 0..<samples {
            let clock = ContinuousClock()
            let start = clock.now
            sink &+= autoreleasepool(invoking: body)
            let elapsed = start.duration(to: clock.now).components
            times.append(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15)
        }
        times.sort()
        let median = times[times.count / 2]
        let slowest = times.last ?? 0
        let ms = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(3)).locale(Locale(identifier: "en_US_POSIX"))
        let summary = "HOTPATH \(name) median_ms=\(median.formatted(ms)) max_ms=\(slowest.formatted(ms)) "
            + "days=\(days.count) sink=\(sink)"
        print(summary)
        let attachment = XCTAttachment(string: summary)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func library(count: Int, photos: Int) -> [Day] {
        let cal = CNDate.calendar
        let categories: [DayCategory] = [.love, .family, .travel, .work, .life]
        let styles = PhotoStyle.pickerOptions
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { i in
            let date = cal.date(from: DateComponents(year: 1990 + i % 40, month: 1 + i % 12, day: 1 + i % 28))!
            let kind = i % 3
            let photo: Data? = i < photos
                ? Data((0..<400_000).map { _ in UInt8.random(in: 0...255, using: &generator) }) : nil
            return Day(id: "day-\(i)", title: "日子 \(i)", date: date,
                       recurring: kind != 0, lunar: kind == 2,
                       category: categories[i % categories.count], photo: styles[i % styles.count],
                       photoData: photo, note: i % 4 == 0 ? "一起去京都看红叶" : "",
                       location: i % 5 == 0 ? "京都" : "")
        }
    }
}
