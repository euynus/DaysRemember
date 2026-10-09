import XCTest
@testable import DaysRemember

/// BDD-style tests — each scenario reads as Given / When / Then so that the test
/// name + Xcode activity log together describe a user-facing behaviour.
///
/// We keep the existing XCTest infrastructure (no Quick/Nimble dependency) and
/// expose a tiny set of helpers via `XCTContext.runActivity`. The activities show
/// up in the test report as nested steps under each test, mirroring a Gherkin
/// scenario. Step descriptions are written in Chinese to match the app's domain
/// language; method names stay in English so the report is greppable.
final class BDDTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suite = "BDDTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    // MARK: - 添加 / 置顶日子

    @MainActor
    func test_addingADay_landsAtTopOfTheList() {
        let store = DayStore(defaults: defaults)

        given("一个空的日子列表") {
            store.days = []
            store.categories = CategoryDefinition.system
        }

        when("用户新增一个结婚纪念日") {
            store.add(Day(id: "wedding", title: "结婚纪念日",
                          date: dateAt(2019, 10, 12), recurring: true,
                          category: .love, photo: .wedding))
        }

        then("它出现在列表的最前面") {
            XCTAssertEqual(store.days.first?.id, "wedding")
            XCTAssertEqual(store.days.count, 1)
        }
    }

    @MainActor
    func test_pinningADay_movesItAheadOfCloserNonPinnedDays() {
        let store = DayStore(defaults: defaults)

        given("两个未置顶的日子，一近一远") {
            store.days = [
                Day(id: "near", title: "近的", date: dateAt(2026, 6, 1),
                    category: .life, photo: .home),
                Day(id: "far", title: "远的", date: dateAt(2027, 1, 1),
                    category: .life, photo: .home),
            ]
        }

        when("用户把那个远的置顶") {
            var far = store.days[1]
            far.pinned = true
            store.update(far)
        }

        then("置顶的日子排在最前面，即便它的倒数更长") {
            let sorted = store.sortedDays(store.days)
            XCTAssertEqual(sorted.first?.id, "far")
            XCTAssertTrue(sorted.first?.pinned == true)
        }
    }

    // MARK: - 分类筛选

    @MainActor
    func test_filteringByCategory_returnsOnlyMatchingDays() {
        let store = DayStore(defaults: defaults)

        given("分布在爱情 / 家人 / 旅行三个分类的日子") {
            store.days = [
                Day(id: "wed", title: "结婚纪念", date: dateAt(2019, 10, 12),
                    category: .love, photo: .wedding),
                Day(id: "mom", title: "妈妈生日", date: dateAt(1962, 6, 18),
                    category: .family, photo: .birthday),
                Day(id: "japan", title: "北海道", date: dateAt(2026, 7, 20),
                    category: .travel, photo: .japan),
            ]
        }

        var matched: [Day] = []
        when("按旅行分类筛选") {
            matched = store.days(in: DayCategory.travel.rawValue)
        }

        then("只返回北海道这一个日子") {
            XCTAssertEqual(matched.map(\.id), ["japan"])
        }
    }

    // MARK: - 自定义分类的增 / 改 / 删

    @MainActor
    func test_creatingCustomCategoryAndUsingIt_dayCarriesItsLabel() {
        let store = DayStore(defaults: defaults)
        var customID = ""

        given("初始状态：仅有 5 个系统分类") {
            store.days = []
            store.categories = CategoryDefinition.system
            XCTAssertEqual(store.categories.count, 5)
        }

        when("用户新建一个 朋友 分类，并加入一个聚会日子") {
            let custom = store.addCategory(name: "朋友", icon: "person.2",
                                            colorToken: .dusty)
            customID = custom.id
            store.add(Day(id: "hangout", title: "周末聚会",
                          date: dateAt(2026, 5, 30),
                          category: .life, photo: .home,
                          categoryID: custom.id, categoryLabel: custom.name))
        }

        then("分类里多了 朋友，新日子带着它的 id 与名字") {
            XCTAssertTrue(store.categories.contains(where: { $0.id == customID }))
            let day = store.days.first(where: { $0.id == "hangout" })
            XCTAssertEqual(day?.categoryID, customID)
            XCTAssertEqual(day?.categoryLabel, "朋友")
        }
    }

    @MainActor
    func test_renamingCustomCategory_existingDaysGetTheNewLabelAutomatically() {
        let store = DayStore(defaults: defaults)
        var customID = ""

        given("一个自定义分类 朋友 + 它下面的一条日子") {
            store.days = []
            store.categories = CategoryDefinition.system
            let custom = store.addCategory(name: "朋友", icon: "person.2",
                                            colorToken: .dusty)
            customID = custom.id
            store.add(Day(id: "hangout", title: "聚会", date: Date(),
                          category: .life, photo: .home,
                          categoryID: custom.id, categoryLabel: custom.name))
        }

        when("用户把分类改名为 老友") {
            var renamed = store.category(for: customID)
            renamed.name = "老友"
            store.updateCategory(renamed)
        }

        then("已有日子的 categoryLabel 自动跟着更新为 老友") {
            let day = store.days.first(where: { $0.id == "hangout" })
            XCTAssertEqual(day?.categoryLabel, "老友")
        }
    }

    @MainActor
    func test_deletingCustomCategory_migratesDaysToTheChosenTarget() {
        let store = DayStore(defaults: defaults)
        var customID = ""

        given("一个有两条日子的自定义分类 朋友") {
            store.days = []
            store.categories = CategoryDefinition.system
            let custom = store.addCategory(name: "朋友", icon: "person.2",
                                            colorToken: .dusty)
            customID = custom.id
            for id in ["a", "b"] {
                store.add(Day(id: id, title: id, date: Date(),
                              category: .life, photo: .home,
                              categoryID: custom.id, categoryLabel: custom.name))
            }
        }

        when("用户删除分类，并把日子迁移到 生活") {
            store.deleteCategory(id: customID, migrateTo: DayCategory.life.rawValue)
        }

        then("分类被移除，两条日子都改属于 生活") {
            XCTAssertFalse(store.categories.contains(where: { $0.id == customID }))
            for id in ["a", "b"] {
                let day = store.days.first(where: { $0.id == id })
                XCTAssertEqual(day?.categoryID, DayCategory.life.rawValue)
                XCTAssertEqual(day?.categoryLabel, DayCategory.life.label)
            }
        }
    }

    // MARK: - 倒数与重复

    func test_recurringGregorianDay_rollsForwardOnceAnniversaryHasPassed() {
        var info: DayInfo!

        when("今天是 2026-05-09，重复的 3 月 8 日已经过去") {
            let day = Day(id: "x", title: "纪念日",
                          date: dateAt(2020, 3, 8),
                          recurring: true, category: .life, photo: .home)
            info = DayInfo.compute(day, today: dateAt(2026, 5, 9))
        }

        then("下一次显示日期落在 2027-03-08 而不是 2026-03-08") {
            let cal = CNDate.calendar
            XCTAssertEqual(cal.component(.year, from: info.displayDate), 2027)
            XCTAssertEqual(cal.component(.month, from: info.displayDate), 3)
            XCTAssertEqual(cal.component(.day, from: info.displayDate), 8)
            XCTAssertFalse(info.isPast)
        }
    }

    func test_recurringLunarDay_walksToCurrentYearLunarAnniversary() {
        var info: DayInfo!

        when("今天是 2026-05-09，日子按农历八月十五重复") {
            // 2025-10-06 (solar) ↔ 2025-08-15 (lunar)
            let day = Day(id: "moon", title: "中秋",
                          date: dateAt(2025, 10, 6),
                          recurring: true, lunar: true,
                          category: .family, photo: .memorial)
            info = DayInfo.compute(day, today: dateAt(2026, 5, 9))
        }

        then("显示日期对应的农历日是 2026 年的八月十五") {
            let displayed = Lunar.solarToLunar(info.displayDate)
            XCTAssertEqual(displayed.month, 8)
            XCTAssertEqual(displayed.day, 15)
            XCTAssertEqual(displayed.year, 2026)
            XCTAssertFalse(info.isPast)
        }
    }

    // MARK: - 提醒触发时间

    func test_lateReminderFiresAtTheChosenTime() {
        var trigger: Date?

        when("提前 1 天的提醒设在深夜 23:15") {
            trigger = NotificationManager.triggerDate(
                displayDate: dateAt(2026, 7, 20),
                offset: 1,
                hour: 23, minute: 15,
                now: dateAt(2026, 7, 1),
                calendar: CNDate.calendar
            )
        }

        then("按设定在前一天 23:15 触发") {
            let cal = CNDate.calendar
            XCTAssertNotNil(trigger)
            XCTAssertEqual(cal.component(.day, from: trigger!), 19)
            XCTAssertEqual(cal.component(.hour, from: trigger!), 23)
            XCTAssertEqual(cal.component(.minute, from: trigger!), 15)
        }
    }

    // MARK: - 旧版本数据迁移

    func test_oldDayJSON_decodesWithSensibleDefaultsForNewFields() throws {
        var day: Day!

        when("解码一条 categoryID / coverFocus 都没有的旧 JSON") {
            let json = """
            {
                "id": "old", "title": "旧日子", "date": 0,
                "recurring": true, "lunar": false,
                "category": "travel", "categoryLabel": "旅行",
                "photo": "home", "note": "", "location": "", "pinned": false
            }
            """
            day = try? JSONDecoder().decode(Day.self, from: Data(json.utf8))
        }

        then("categoryID 回退到旧 enum 值，封面焦点居中") {
            XCTAssertNotNil(day)
            XCTAssertEqual(day.categoryID, DayCategory.travel.rawValue)
            XCTAssertEqual(day.coverFocusX, 0.5)
            XCTAssertEqual(day.coverFocusY, 0.5)
        }
    }

    // MARK: - Helpers

    private func dateAt(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return CNDate.calendar.date(from: c)!
    }
}

/// Reports each Given / When / Then step as a nested XCTContext activity so that
/// the test log reads like a Gherkin scenario in Xcode and on the command line.
private extension XCTestCase {
    func given(_ description: String, _ block: () throws -> Void) rethrows {
        try XCTContext.runActivity(named: "Given \(description)") { _ in try block() }
    }

    func when(_ description: String, _ block: () throws -> Void) rethrows {
        try XCTContext.runActivity(named: "When \(description)") { _ in try block() }
    }

    func then(_ description: String, _ block: () throws -> Void) rethrows {
        try XCTContext.runActivity(named: "Then \(description)") { _ in try block() }
    }
}
