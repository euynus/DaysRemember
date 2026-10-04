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
        XCTAssertNil(WidgetDay.resolve(in: [past], selectedID: nil, today: today))
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
        XCTAssertEqual(selections, ["current", "upcoming", nil])
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

    @MainActor
    func testQueryReadsAppWritesAndRemovesDeletedDays() async throws {
        let original = SharedStorage.defaults.data(forKey: "days.v1")
        defer { SharedStorage.defaults.set(original, forKey: "days.v1") }
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
        SharedStorage.defaults.set(Data("invalid".utf8), forKey: "days.v1")
        XCTAssertTrue(SharedStorage.loadDays().isEmpty)
    }
}
