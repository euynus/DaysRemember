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
