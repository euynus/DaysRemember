import XCTest
import UIKit
@testable import DaysRemember

final class WidgetTests: XCTestCase {
    func testWidgetPhotosStayBelowArchivePixelLimit() throws {
        for limit in [512, 720] {
            for style in PhotoStyle.allCases {
                let image = try XCTUnwrap(UIImage(named: style.assetName))
                let thumbnail = try XCTUnwrap(PhotoTile.thumbnail(image, maximumPixelSize: CGFloat(limit))?.cgImage)
                XCTAssertLessThanOrEqual(max(thumbnail.width, thumbnail.height), limit)
                XCTAssertLessThanOrEqual(thumbnail.width * thumbnail.height, limit * limit)
            }
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 400), format: format)
            .image { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 800, height: 400)) }
        let thumbnail = try XCTUnwrap(PhotoTile.thumbnail(photo, maximumPixelSize: 720)?.cgImage)
        XCTAssertLessThanOrEqual(max(thumbnail.width, thumbnail.height), 720)
    }

    /// The widget paints a custom category's own colour, read from the shared App Group the
    /// store writes, not the 生活 colour the editor stores on such a day's `category`.
    @MainActor
    func testCustomCategoryColoursReachTheWidget() throws {
        let suite = "WidgetTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DayStore(defaults: defaults)
        let custom = store.addCategory(name: "雾", icon: "cloud", colorToken: .dusty)
        let day = Day(id: "custom", title: "雾", date: Date(), category: .life, photo: .home,
                      categoryID: custom.id, categoryLabel: custom.name)
        let shared = SharedStorage.loadCategories(defaults: defaults)

        XCTAssertEqual(CategoryDefinition.colorToken(for: day, in: shared), .dusty)
        XCTAssertEqual(CategoryDefinition.colorToken(for: day, in: shared), store.category(for: day).colorToken)
        // Before the definition arrives the day falls back to 生活, as in the app.
        XCTAssertEqual(CategoryDefinition.colorToken(for: day, in: []), store.category(for: "custom.pending").colorToken)
        let travel = Day(id: "travel", title: "旅", date: Date(), category: .travel, photo: .home)
        XCTAssertEqual(CategoryDefinition.colorToken(for: travel, in: []), .dusty)
        XCTAssertTrue(SharedStorage.loadCategories(defaults: UserDefaults(suiteName: "\(suite).empty")!).isEmpty)
    }

    func testAutomaticAndExplicitSelection() {
        let today = CNDate.calendar.date(from: DateComponents(year: 2026, month: 10, day: 2))!
        let past = Day(id: "past", title: "过去", date: today.addingTimeInterval(-86400),
                       category: .life, photo: .home)
        let far = Day(id: "far", title: "未来", date: today.addingTimeInterval(86400 * 500),
                      category: .life, photo: .home)
        let near = Day(id: "near", title: "今天", date: today, category: .life, photo: .home)
        XCTAssertEqual(WidgetDay.resolve(in: [past, far, near], selectedID: nil, today: today)?.id, "near")
        XCTAssertEqual(WidgetDay.resolve(in: [past, far], selectedID: nil, today: today)?.id, "far")
        XCTAssertEqual(WidgetDay.resolve(in: [past, near], selectedID: "past", today: today)?.id, "past")
        XCTAssertNil(WidgetDay.resolve(in: [near], selectedID: "deleted", today: today))
        // With nothing upcoming, the most recent past day is shown rather than an empty widget.
        XCTAssertEqual(WidgetDay.resolve(in: [past], selectedID: nil, today: today)?.id, "past")
        XCTAssertNil(WidgetDay.resolve(in: [], selectedID: nil, today: today))
    }

    func testDayStartsAcrossYearBoundary() {
        let now = CNDate.calendar.date(from: DateComponents(year: 2026, month: 12, day: 31,
                                                            hour: 23, minute: 59, second: 59))!
        let expected = (1...7).map {
            CNDate.calendar.date(from: DateComponents(year: 2027, month: 1, day: $0))!
        }
        XCTAssertEqual(CNDate.calendar.timeZone.identifier, "Asia/Shanghai")
        XCTAssertEqual(CNDate.dayStarts(after: now, count: 7), expected)
    }

    func testDayStartsAcrossLeapDay() {
        let now = CNDate.calendar.date(from: DateComponents(year: 2028, month: 2, day: 28,
                                                            hour: 12, minute: 30))!
        let leapDay = CNDate.calendar.date(from: DateComponents(year: 2028, month: 2, day: 29))!
        let march = CNDate.calendar.date(from: DateComponents(year: 2028, month: 3, day: 1))!
        XCTAssertEqual(CNDate.dayStarts(after: now, count: 2), [leapDay, march])
        XCTAssertEqual(CNDate.dayStarts(after: leapDay, count: 1), [march])
    }

    func testDayStartsWithNonPositiveCount() {
        let now = CNDate.calendar.date(from: DateComponents(year: 2026, month: 10, day: 2))!
        XCTAssertTrue(CNDate.dayStarts(after: now, count: 0).isEmpty)
        XCTAssertTrue(CNDate.dayStarts(after: now, count: -1).isEmpty)
    }

    func testAutomaticSelectionAdvancesAtMidnight() {
        let before = CNDate.calendar.date(from: DateComponents(year: 2026, month: 12, day: 31,
                                                               hour: 23, minute: 59, second: 59))!
        let next = CNDate.calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        let current = Day(id: "current", title: "今天", date: before, category: .life, photo: .home)
        let upcoming = Day(id: "upcoming", title: "明天", date: next, category: .life, photo: .home)
        let dates = [before] + CNDate.dayStarts(after: before, count: 2)
        let selections = dates.map {
            WidgetDay.resolve(in: [current, upcoming], selectedID: nil, today: $0)?.id
        }
        XCTAssertEqual(selections, ["current", "upcoming", "upcoming"])
    }

    func testExplicitSelectionsStayUnchangedAcrossMidnight() {
        let before = CNDate.calendar.date(from: DateComponents(year: 2026, month: 12, day: 31,
                                                               hour: 23, minute: 59, second: 59))!
        let pastDate = CNDate.calendar.date(from: DateComponents(year: 2026, month: 12, day: 30))!
        let next = CNDate.calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        let past = Day(id: "past", title: "过去", date: pastDate, category: .life, photo: .home)
        let upcoming = Day(id: "upcoming", title: "明天", date: next, category: .life, photo: .home)
        for date in [before] + CNDate.dayStarts(after: before, count: 7) {
            XCTAssertEqual(WidgetDay.resolve(in: [past, upcoming], selectedID: "past", today: date)?.id, "past")
            XCTAssertNil(WidgetDay.resolve(in: [past, upcoming], selectedID: "deleted", today: date))
        }
    }

    /// The widget gallery shows a sample before any day is added; its title is the app's own
    /// text, so it follows the language like the card's labels.
    func testGallerySampleIsInTheAppLanguage() {
        let defaults = SharedStorage.defaults
        let previous = defaults.object(forKey: AppLocalization.languageKey)
        defer { defaults.set(previous, forKey: AppLocalization.languageKey) }
        let expected = ["en": "Wedding Anniversary", "zh-Hant": "結婚紀念日", "zh-Hans": "结婚纪念日"]
        for (language, title) in expected {
            defaults.set(language, forKey: AppLocalization.languageKey)
            XCTAssertEqual(WidgetDay.gallerySample.title, title, language)
        }
    }

    @MainActor
    func testQueryReadsAppWritesAndRemovesDeletedDays() async throws {
        let original = SharedLibrarySnapshot(keys: ["days.v1", "days.v2", "deletedDays.v1"])
        defer { original.restore() }
        let store = DayStore()
        store.days = []
        let day = Day(id: "widget-test", title: "桌面日子", date: Date(), category: .life, photo: .home)
        store.add(day)
        var entities = try await WidgetDayQuery().entities(for: [day.id])
        XCTAssertEqual(entities.map(\.title), [day.title])
        var edited = day
        edited.title = "更新后的日子"
        store.update(edited)
        entities = try await WidgetDayQuery().entities(for: [day.id])
        XCTAssertEqual(entities.map(\.title), [edited.title])
        store.delete(day)
        entities = try await WidgetDayQuery().entities(for: [day.id])
        XCTAssertEqual(entities.map(\.id), [day.id])
        XCTAssertEqual(entities.map(\.title), ["日子已删除"])
        let suggestions = try await WidgetDayQuery().suggestedEntities()
        XCTAssertTrue(suggestions.isEmpty)
        XCTAssertNil(WidgetDay.resolve(in: SharedStorage.loadDays(), selectedID: entities.first?.id, today: Date()))
        XCTAssertTrue(SharedStorage.loadDays().isEmpty)
        SharedStorage.defaults.set(Data("invalid".utf8), forKey: "days.v2")
        XCTAssertTrue(SharedStorage.loadDays().isEmpty)
    }
}
