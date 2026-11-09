import XCTest
@testable import DaysRemember

final class DataManagementActivityTests: XCTestCase {
    private let backup = DayBackup(days: SampleData.days, categories: CategoryDefinition.system, deletedDays: [])

    func testAReadBackupWaitsForTheUsersConfirmation() throws {
        var activity = DataManagementActivity.idle
        XCTAssertTrue(activity.startReading())
        XCTAssertTrue(activity.isBusy, "The form shows the read in progress")
        try activity.finishReading(.success(backup))
        XCTAssertEqual(activity.pendingRestore?.days.count, SampleData.days.count)
        XCTAssertFalse(activity.isBusy)

        let confirmed = try XCTUnwrap(activity.confirmRestore())
        XCTAssertEqual(confirmed.days.count, SampleData.days.count)
        XCTAssertTrue(activity.isIdle)
        XCTAssertNil(activity.confirmRestore(), "A restore is confirmed once")
    }

    func testABackupThatCannotBeReadIsReported() {
        var activity = DataManagementActivity.idle
        XCTAssertTrue(activity.startReading())
        XCTAssertThrowsError(try activity.finishReading(.failure(DayBackup.BackupError.unreadable))) { error in
            XCTAssertEqual(error as? DayBackup.BackupError, .unreadable)
        }
        XCTAssertTrue(activity.isIdle)
        XCTAssertNil(activity.pendingRestore)
    }

    func testCancellingTheRestoreLeavesNothingPending() throws {
        var activity = DataManagementActivity.idle
        _ = activity.startReading()
        try activity.finishReading(.success(backup))
        activity.cancelRestore()
        XCTAssertTrue(activity.isIdle)
        XCTAssertNil(activity.confirmRestore())
    }

    func testOneLongOperationAtATime() {
        var reading = DataManagementActivity.idle
        XCTAssertTrue(reading.startReading())
        XCTAssertFalse(reading.startDeletingCloudData(), "iCloud data isn't deleted while a backup is read")
        XCTAssertFalse(reading.startExport(BackupDocument(data: Data()), filename: "备份"))
        XCTAssertFalse(reading.startReading())

        var deleting = DataManagementActivity.idle
        XCTAssertTrue(deleting.startDeletingCloudData())
        XCTAssertTrue(deleting.isBusy)
        XCTAssertFalse(deleting.startReading(), "No backup is read while iCloud data is deleted")
        deleting.finishDeletingCloudData()
        XCTAssertTrue(deleting.isIdle)
        XCTAssertTrue(deleting.startReading())
    }

    func testAnExportHoldsItsFileOnlyWhileTheExporterIsOpen() {
        var activity = DataManagementActivity.idle
        XCTAssertNil(activity.exportDocument)
        XCTAssertTrue(activity.startExport(BackupDocument(data: Data("备份".utf8)), filename: "时光备份-2026-11-09"))
        XCTAssertEqual(activity.exportDocument?.data, Data("备份".utf8))
        XCTAssertEqual(activity.exportFilename, "时光备份-2026-11-09")
        XCTAssertFalse(activity.isBusy, "The exporter covers the form while it is open")
        activity.finishExport()
        XCTAssertTrue(activity.isIdle)
        XCTAssertNil(activity.exportDocument)
    }

    func testResultsForAnotherStepChangeNothing() throws {
        var deleting = DataManagementActivity.idle
        _ = deleting.startDeletingCloudData()
        try deleting.finishReading(.success(backup))
        deleting.cancelRestore()
        deleting.finishExport()
        XCTAssertTrue(deleting.isBusy, "Only the deletion's own end ends it")

        var exporting = DataManagementActivity.idle
        _ = exporting.startExport(BackupDocument(data: Data()), filename: "备份")
        exporting.finishDeletingCloudData()
        XCTAssertNotNil(exporting.exportDocument)
    }
}
