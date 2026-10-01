import XCTest
@testable import DaysRemember

final class UIUXModelTests: XCTestCase {
    func testLegacyCategoryIconsKeepTheirMeaning() {
        let icons = ["plane": "airplane", "cake": "birthday.cake",
                     "cap": "graduationcap", "paw": "pawprint",
                     "sun": "sun.max", "ring": "circle.circle",
                     "heart": "heart", "person.2": "person.2"]
        for (stored, symbol) in icons {
            XCTAssertEqual(CategoryDefinition.symbolName(for: stored), symbol)
        }
    }

    override func setUp() {
        super.setUp()
        SharedStorage.defaults.removeObject(forKey: "days.v1")
        SharedStorage.defaults.removeObject(forKey: "categories.v1")
    }

    override func tearDown() {
        SharedStorage.defaults.removeObject(forKey: "days.v1")
        SharedStorage.defaults.removeObject(forKey: "categories.v1")
        super.tearDown()
    }

    func testOldDayJSONDefaultsCategoryIDAndCoverFocus() throws {
        let json = """
        [{
            "id": "old",
            "title": "旧日子",
            "date": 0,
            "recurring": true,
            "lunar": false,
            "category": "travel",
            "categoryLabel": "旅行",
            "photo": "home",
            "note": "",
            "location": "",
            "pinned": false
        }]
        """
        let days = try JSONDecoder().decode([Day].self, from: Data(json.utf8))

        XCTAssertEqual(days.first?.categoryID, DayCategory.travel.rawValue)
        XCTAssertEqual(days.first?.coverFocusX, 0.5)
        XCTAssertEqual(days.first?.coverFocusY, 0.5)
    }

    @MainActor
    func testDeletingCustomCategoryMigratesDays() {
        let store = DayStore()
        store.days = []
        let custom = store.addCategory(name: "朋友", icon: "person.2", colorToken: .dusty)
        store.add(Day(id: "friend", title: "朋友聚会", date: Date(),
                      category: .life, photo: .home,
                      categoryID: custom.id, categoryLabel: custom.name))

        store.deleteCategory(id: custom.id, migrateTo: DayCategory.work.rawValue)

        XCTAssertFalse(store.categories.contains(where: { $0.id == custom.id }))
        XCTAssertEqual(store.days.first?.categoryID, DayCategory.work.rawValue)
        XCTAssertEqual(store.days.first?.categoryLabel, DayCategory.work.label)
    }

    @MainActor
    func testSortedDaysOrdersByPinnedThenUpcomingThenDistance() {
        let store = DayStore()
        let today = CNDate.calendar.startOfDay(for: Today.date)
        func offset(_ days: Int) -> Date {
            CNDate.calendar.date(byAdding: .day, value: days, to: today)!
        }
        // Pinned but past — outranks every unpinned day regardless of distance.
        let pinnedPast = Day(id: "pinned-past", title: "pinned past",
                             date: offset(-400), category: .life, photo: .home,
                             pinned: true)
        // Far-future, unpinned — should sort behind close-future.
        let farFuture = Day(id: "far", title: "far",
                            date: offset(400), category: .life, photo: .home)
        // Close-future, unpinned — runner-up after pinned.
        let nearFuture = Day(id: "near", title: "near",
                             date: offset(5), category: .life, photo: .home)
        // Past, unpinned — sorts last.
        let past = Day(id: "past", title: "past",
                       date: offset(-5), category: .life, photo: .home)

        store.days = [past, farFuture, nearFuture, pinnedPast]
        let sorted = store.sortedDays(store.days)

        XCTAssertEqual(sorted.map(\.id), ["pinned-past", "near", "far", "past"])
    }

    func testNotificationTriggerUsesConfiguredTime() {
        let cal = CNDate.calendar
        let display = date(2026, 7, 20)
        let now = date(2026, 7, 1)

        let trigger = NotificationManager.triggerDate(displayDate: display, offset: 7,
                                                      hour: 16, minute: 30,
                                                      quietHours: false, now: now,
                                                      calendar: cal)

        XCTAssertEqual(cal.component(.day, from: trigger!), 13)
        XCTAssertEqual(cal.component(.hour, from: trigger!), 16)
        XCTAssertEqual(cal.component(.minute, from: trigger!), 30)
    }

    func testNotificationTriggerRespectsQuietHours() {
        let cal = CNDate.calendar
        let display = date(2026, 7, 20)
        let now = date(2026, 7, 1)

        let trigger = NotificationManager.triggerDate(displayDate: display, offset: 1,
                                                      hour: 23, minute: 15,
                                                      quietHours: true, now: now,
                                                      calendar: cal)

        XCTAssertEqual(cal.component(.day, from: trigger!), 19)
        XCTAssertEqual(cal.component(.hour, from: trigger!), 8)
        XCTAssertEqual(cal.component(.minute, from: trigger!), 15)
    }

    func testAppSettingsSnapshotCodableRoundTrip() throws {
        let json = """
        {
            "hasOnboarded": true,
            "notifPre7": false,
            "notifPre3": true,
            "notifPre1": true,
            "notifDay0": false,
            "memoryEnabled": true,
            "momentsEnabled": false,
            "quietHours": true,
            "notificationHour": 21,
            "notificationMinute": 45
        }
        """

        let snapshot = try JSONDecoder().decode(AppSettingsSnapshot.self, from: Data(json.utf8))
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(AppSettingsSnapshot.self, from: encoded)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.notificationHour, 21)
        XCTAssertEqual(decoded.notificationMinute, 45)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return CNDate.calendar.date(from: components)!
    }
}
