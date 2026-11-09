import XCTest
@testable import DaysRemember

final class NewDayFlowTests: XCTestCase {
    func testOnboardingsFirstDayWaitsForTheFirstDownload() {
        var flow = NewDayFlow(firstDay: true, downloadPending: true)
        XCTAssertEqual(flow, .awaitingFirstDownload)
        XCTAssertNil(flow.request, "No editor hides the library arriving")
        flow.firstDownloadEnded(libraryIsEmpty: true)
        XCTAssertNotNil(flow.request, "Nothing came, so the first day's editor opens")
    }

    func testADownloadThatBringsTheLibraryOpensNothing() {
        var flow = NewDayFlow(firstDay: true, downloadPending: true)
        flow.firstDownloadEnded(libraryIsEmpty: false)
        XCTAssertEqual(flow, .idle)
    }

    func testWithoutADownloadTheFirstDayOpensAtOnce() {
        XCTAssertNotNil(NewDayFlow(firstDay: true, downloadPending: false).request)
        XCTAssertEqual(NewDayFlow(firstDay: false, downloadPending: true), .idle)
        XCTAssertEqual(NewDayFlow(firstDay: false, downloadPending: false), .idle)
    }

    func testAnEditorOpenedWhileWaitingEndsTheWait() {
        var flow = NewDayFlow(firstDay: true, downloadPending: true)
        flow.open()
        XCTAssertNotNil(flow.request)
        flow.editorDismissed { _ in false }
        XCTAssertFalse(flow.editorGone())
        flow.firstDownloadEnded(libraryIsEmpty: true)
        XCTAssertEqual(flow, .idle, "The editor the user closed doesn't open again by itself")
    }

    func testAnOpenEditorKeepsItsDraft() throws {
        var flow = NewDayFlow.idle
        flow.open(categoryID: DayCategory.love.rawValue)
        let request = try XCTUnwrap(flow.request)
        XCTAssertEqual(request.categoryID, DayCategory.love.rawValue)
        flow.open(date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(flow.request, request, "A link or another + doesn't replace the draft")
        flow.firstDownloadEnded(libraryIsEmpty: true)
        XCTAssertEqual(flow.request, request)
    }

    func testOnlyTheEditorsOwnDayCountsAsAdded() throws {
        var flow = NewDayFlow.idle
        flow.open()
        let cancelled = try XCTUnwrap(flow.request)
        // A sync brought another day while the editor was open, and the editor was cancelled.
        flow.editorDismissed { $0 == "synced" }
        XCTAssertEqual(flow, .closing(addedDay: false))
        XCTAssertNil(flow.request, "A dismissed editor isn't presented again")
        XCTAssertFalse(flow.editorGone())
        XCTAssertEqual(flow, .idle)

        flow.open()
        let saved = try XCTUnwrap(flow.request)
        XCTAssertNotEqual(saved.id, cancelled.id, "Each editor saves a day of its own")
        flow.editorDismissed { $0 == saved.id }
        XCTAssertTrue(flow.editorGone())
        XCTAssertEqual(flow, .idle)
        XCTAssertFalse(flow.editorGone(), "Once per editor")
    }

    func testAnEditorAskedForWhileTheLastOneLeavesStaysOpen() throws {
        var flow = NewDayFlow.idle
        flow.open()
        flow.editorDismissed { _ in true }
        flow.open(date: Date(timeIntervalSince1970: 0))
        let next = try XCTUnwrap(flow.request)
        XCTAssertFalse(flow.editorGone(), "The last editor's leaving doesn't close the next")
        XCTAssertEqual(flow.request, next)
    }
}
