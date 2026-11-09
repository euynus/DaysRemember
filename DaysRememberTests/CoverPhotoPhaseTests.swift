import PhotosUI
import SwiftUI
import XCTest
@testable import DaysRemember

final class CoverPhotoPhaseTests: XCTestCase {
    private let first = PhotosPickerItem(itemIdentifier: "first")
    private let second = PhotosPickerItem(itemIdentifier: "second")

    func testAPickedPhotoLoadsAndThenReachesTheDraft() {
        var phase = CoverPhotoPhase.idle
        phase.pick(first)
        XCTAssertTrue(phase.isLoading, "Saving waits for it")
        XCTAssertEqual(phase.item, first)
        XCTAssertTrue(phase.finish(first, succeeded: true))
        XCTAssertEqual(phase, .idle)
        XCTAssertNil(phase.item, "The picker's selection clears with it")
    }

    func testAPhotoThatCannotBeReadCanBePickedAgain() {
        var phase = CoverPhotoPhase.idle
        phase.pick(first)
        XCTAssertTrue(phase.finish(first, succeeded: false))
        XCTAssertEqual(phase, .failed)
        XCTAssertFalse(phase.isLoading, "Saving no longer waits")
        XCTAssertNil(phase.item)
        phase.pick(first)
        XCTAssertEqual(phase, .loading(first), "Picking the same photo again tries it again")
    }

    func testAnotherPhotoReplacesOneStillLoading() {
        var phase = CoverPhotoPhase.idle
        phase.pick(first)
        phase.pick(second)
        XCTAssertFalse(phase.finish(first, succeeded: true), "What the replaced photo read is dropped")
        XCTAssertFalse(phase.finish(first, succeeded: false), "and so is its failure")
        XCTAssertEqual(phase, .loading(second))
    }

    func testClearingTheSelectionStopsTheLoad() {
        var phase = CoverPhotoPhase.idle
        phase.pick(first)
        phase.pick(nil)
        XCTAssertEqual(phase, .idle)
        XCTAssertFalse(phase.finish(first, succeeded: true))

        var failed = CoverPhotoPhase.failed
        failed.pick(nil)
        XCTAssertEqual(failed, .failed, "An empty selection isn't a new photo, so the notice stays")
    }

    func testATemplateEndsALoadAndItsNotice() {
        // The editor sets the phase back to idle when a template is chosen.
        var phase = CoverPhotoPhase.loading(first)
        phase = .idle
        XCTAssertFalse(phase.finish(first, succeeded: false), "A late failure doesn't show")
        XCTAssertEqual(phase, .idle)
    }
}
