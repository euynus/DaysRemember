import XCTest
@testable import DaysRemember

final class MissingDaysHoldTests: XCTestCase {
    private func day(_ id: String) -> Day {
        Day(id: id, title: id, date: Date(timeIntervalSince1970: 1_700_000_000), category: .life, photo: .home)
    }

    private func name(_ day: Day) -> String { CloudLibraryRecord.day(day).recordName }

    func testNothingMissingHoldsNothing() {
        XCTAssertNil(MissingDaysHold(missing: [], days: [day("a")], categories: []))
    }

    func testTheNoticeCountsOnlyDays() throws {
        let category = CategoryDefinition(id: "custom.c", name: "C", icon: "tag", colorToken: .sage, isSystem: false)
        let hold = try XCTUnwrap(MissingDaysHold(
            missing: [name(day("a")), name(day("b")), CloudLibraryRecord.category(category).recordName],
            days: [], categories: []))
        XCTAssertEqual(hold.dayCount, 2)
    }

    func testADayBackInTheLibraryLeavesTheHold() throws {
        let a = day("a"), b = day("b")
        let hold = try XCTUnwrap(MissingDaysHold(missing: [name(a), name(b)], days: [], categories: []))
        let next = try XCTUnwrap(hold.updating(days: [a, day("new")], categories: []) { _ in true })
        XCTAssertEqual(next.records, [name(b)])
        XCTAssertEqual(next.days.map(\.id), ["a", "new"], "Confirming sends the latest snapshot")
    }

    func testADayICloudNoLongerHoldsLeavesTheHold() throws {
        let a = day("a"), b = day("b")
        let hold = try XCTUnwrap(MissingDaysHold(missing: [name(a), name(b)], days: [], categories: []))
        let next = try XCTUnwrap(hold.updating(days: [], categories: []) { $0 != self.name(a) })
        XCTAssertEqual(next.records, [name(b)])
    }

    func testTheHoldEndsOnceNothingIsLeft() throws {
        let a = day("a")
        let hold = try XCTUnwrap(MissingDaysHold(missing: [name(a)], days: [], categories: []))
        XCTAssertNil(hold.updating(days: [a], categories: []) { _ in true },
                     "Nothing is held, so the library snapshot isn't kept either")
    }
}
