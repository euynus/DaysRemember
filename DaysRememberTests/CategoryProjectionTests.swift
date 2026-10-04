import XCTest
@testable import DaysRemember

@MainActor
final class CategoryProjectionTests: XCTestCase {
    func testGroupedDaysKeepCategoryCountsAndExistingRanking() throws {
        try withStore { store in
            let today = try date(2026, 4, 23)
            store.days = [
                day("travel-far", date: try date(2026, 5, 23), category: .travel),
                day("life-past", date: try date(2025, 4, 23), category: .life),
                day("travel-near", date: try date(2026, 4, 24), category: .travel),
                day("life-pinned", date: try date(2025, 1, 1), category: .life, pinned: true),
                day("life-near", date: try date(2026, 4, 24), category: .life),
                Day(id: "unresolved", title: "Unresolved", date: today, category: .life,
                    photo: .home, categoryID: "custom.pending", categoryLabel: "Pending")
            ]
            let grouped = store.daysByCategory(today: today)
            for id in Set(store.days.map(\.categoryID)) {
                XCTAssertEqual(grouped[id], store.days(in: id, today: today))
            }
            XCTAssertEqual(grouped["travel"]?.map(\.id), ["travel-near", "travel-far"])
            XCTAssertEqual(grouped["life"]?.map(\.id), ["life-pinned", "life-near", "life-past"])
            XCTAssertEqual(grouped["custom.pending"]?.count, 1)
            XCTAssertEqual(grouped.values.reduce(0) { $0 + $1.count }, store.days.count)
            XCTAssertNil(grouped["family"])
        }
    }

    func testGroupedCoverChangesAcrossMidnightAndAfterCategoryMove() throws {
        try withStore { store in
            let today = try date(2026, 4, 23)
            let tomorrow = try date(2026, 4, 24)
            let annual = Day(id: "annual", title: "Annual", date: try date(2020, 4, 23),
                             recurring: true, category: .life, photo: .home)
            var upcoming = day("upcoming", date: tomorrow, category: .life)
            store.days = [annual, upcoming]
            XCTAssertEqual(store.daysByCategory(today: today)["life"]?.first?.id, "annual")
            XCTAssertEqual(store.daysByCategory(today: tomorrow)["life"]?.first?.id, "upcoming")

            upcoming.categoryID = "travel"
            upcoming.category = .travel
            store.update(upcoming)
            let grouped = store.daysByCategory(today: tomorrow)
            XCTAssertEqual(grouped["life"]?.map(\.id), ["annual"])
            XCTAssertEqual(grouped["travel"]?.map(\.id), ["upcoming"])
        }
    }

    private func withStore(_ body: (DayStore) throws -> Void) throws {
        let name = "CategoryProjectionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(DayStore(defaults: defaults))
    }

    private func day(_ id: String, date: Date, category: DayCategory, pinned: Bool = false) -> Day {
        Day(id: id, title: id, date: date, category: category, photo: .home, pinned: pinned)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try XCTUnwrap(CNDate.calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }
}
