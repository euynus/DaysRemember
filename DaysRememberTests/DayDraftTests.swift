import XCTest
import UIKit
@testable import DaysRemember

@MainActor
final class DayDraftTests: XCTestCase {
    private let photoBytes = Data([1, 2, 3])

    private func stored() -> Day {
        Day(id: "stored", title: "结婚纪念日", date: date(2019, 10, 12), recurring: true,
            category: .love, photo: .wedding, photoData: photoBytes,
            coverFocusX: 0.2, coverFocusY: 0.8, reminderOffsets: [0, 3, 7],
            reminderTime: DayReminderTime(hour: 20, minute: 30), note: "那天下着小雨", location: "杭州",
            pinned: true)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        CNDate.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func category(_ id: DayCategory) -> CategoryDefinition {
        CategoryDefinition.system.first { $0.id == id.rawValue }!
    }

    // MARK: - Changes

    func testAnOpenedDraftHasNoChanges() {
        let editing = DayDraft(editing: stored(), date: Today.date)
        XCTAssertEqual(editing.original, stored())
        XCTAssertTrue(editing.coverChosen)
        XCTAssertFalse(editing.hasChanges)

        let new = DayDraft(editing: nil, date: date(2026, 4, 23))
        XCTAssertEqual(new.original.id, "")
        XCTAssertEqual(new.date, date(2026, 4, 23))
        XCTAssertFalse(new.coverChosen)
        XCTAssertFalse(new.hasChanges)
    }

    func testEveryEditedFieldIsAChange() {
        let work = category(.work)
        let edits: [(String, (inout DayDraft) -> Void)] = [
            ("title", { $0.title = "改过的名字" }),
            ("category", { $0.selectCategory(work) }),
            ("photo", { $0.photo = .japan }),
            ("photoData", { $0.photoData = nil }),
            ("recurring", { $0.recurring = false }),
            ("calendar", { $0.solar = false }),
            ("date", { $0.date = CNDate.calendar.date(byAdding: .day, value: 1, to: $0.date)! }),
            ("note", { $0.note = "" }),
            ("location", { $0.location = "上海" }),
            ("focusX", { $0.coverFocusX = 0.5 }),
            ("focusY", { $0.coverFocusY = 0.5 }),
            ("reminders", { $0.reminderOffsets = [1] }),
            ("reminderTime", { $0.reminderTime = nil }),
        ]
        for (name, edit) in edits {
            var draft = DayDraft(editing: stored(), date: Today.date)
            edit(&draft)
            XCTAssertTrue(draft.hasChanges, name)
        }
    }

    /// The date picker gives a day, so another time on the same day isn't a change.
    func testAnotherTimeOnTheSameDayIsNoChange() {
        var draft = DayDraft(editing: stored(), date: Today.date)
        draft.date = date(2019, 10, 12, hour: 15)
        XCTAssertFalse(draft.hasChanges)
    }

    func testSameRemindersInAnotherOrderAreNoChange() {
        var draft = DayDraft(editing: stored(), date: Today.date)
        draft.reminderOffsets = [7, 3, 0, 3]
        XCTAssertFalse(draft.hasChanges)
        draft.reminderOffsets = nil
        XCTAssertTrue(draft.hasChanges)
    }

    // MARK: - Cover

    func testANewDaysCoverFollowsItsCategoryUntilOneIsChosen() {
        var draft = DayDraft(editing: nil, date: Today.date)
        XCTAssertEqual(draft.photo, PhotoStyle.defaultCover(forCategoryID: DayCategory.life.rawValue))

        draft.selectCategory(category(.travel))
        XCTAssertEqual(draft.categoryID, DayCategory.travel.rawValue)
        XCTAssertEqual(draft.photo, PhotoStyle.defaultCover(forCategoryID: DayCategory.travel.rawValue))

        draft.selectTemplate(.memorial)
        draft.selectCategory(category(.work))
        XCTAssertEqual(draft.categoryID, DayCategory.work.rawValue)
        XCTAssertEqual(draft.photo, .memorial)
    }

    /// Tapping the template already shown still counts as choosing it.
    func testChoosingTheCurrentTemplateStopsTheCoverFollowing() {
        var draft = DayDraft(editing: nil, date: Today.date)
        let cover = draft.photo
        draft.selectTemplate(cover)
        XCTAssertTrue(draft.coverChosen)
        XCTAssertFalse(draft.hasChanges)

        draft.selectCategory(category(.travel))
        XCTAssertEqual(draft.photo, cover)
    }

    func testAnEditedDaysCoverStaysWhenItsCategoryChanges() {
        var draft = DayDraft(editing: stored(), date: Today.date)
        draft.photoData = nil
        draft.selectCategory(category(.travel))
        XCTAssertEqual(draft.photo, .wedding)
    }

    func testATemplateReplacesThePhotoAndItsFraming() {
        var draft = DayDraft(editing: stored(), date: Today.date)
        XCTAssertFalse(draft.isTemplateSelected(.wedding))

        draft.selectTemplate(.japan)
        XCTAssertEqual(draft.photo, .japan)
        XCTAssertNil(draft.photoData)
        XCTAssertEqual(draft.coverFocusX, 0.5)
        XCTAssertEqual(draft.coverFocusY, 0.5)
        XCTAssertTrue(draft.isTemplateSelected(.japan))
        XCTAssertFalse(draft.isTemplateSelected(.wedding))
    }

    func testAPhotoReplacesTheCoverAndItsFraming() {
        var draft = DayDraft(editing: nil, date: Today.date)
        draft.coverFocusX = 0.1
        draft.usePhoto(photoBytes)
        XCTAssertEqual(draft.photoData, photoBytes)
        XCTAssertTrue(draft.coverChosen)
        XCTAssertEqual(draft.coverFocusX, 0.5)
        XCTAssertEqual(draft.coverFocusY, 0.5)
        XCTAssertFalse(draft.isTemplateSelected(draft.photo))
    }

    // MARK: - Save

    func testTheSavedDayHasTrimmedTextAndTheOriginalCategory() throws {
        var draft = DayDraft(editing: stored(), date: Today.date)
        draft.title = "  第七年  "
        draft.note = "\n小雨 "
        draft.location = " 杭州西湖 "
        draft.solar = false
        draft.selectCategory(category(.family))

        let day = try XCTUnwrap(draft.day(id: "stored", pinned: true))
        XCTAssertEqual(day.title, "第七年")
        XCTAssertEqual(day.note, "小雨")
        XCTAssertEqual(day.location, "杭州西湖")
        XCTAssertTrue(day.lunar)
        XCTAssertTrue(day.pinned)
        XCTAssertEqual(day.photoData, photoBytes)
        XCTAssertEqual(day.reminderOffsets, [0, 3, 7])
        // The selection is applied by applyingCategory, against the categories at save time.
        XCTAssertEqual(day.categoryID, stored().categoryID)
        let saved = try XCTUnwrap(DayDraft.applyingCategory(to: day, selectedCategory: draft.selectedCategory,
                                                            categories: CategoryDefinition.system))
        XCTAssertEqual(saved.categoryID, DayCategory.family.rawValue)
        XCTAssertEqual(saved.category, .family)
    }

    func testABlankTitleSavesNothing() {
        var draft = DayDraft(editing: nil, date: Today.date)
        draft.title = " \n "
        XCTAssertNil(draft.day(id: "new", pinned: false))
        XCTAssertFalse(draft.canSave(isLoadingPhoto: false))
        draft.title = "新的一天"
        XCTAssertTrue(draft.canSave(isLoadingPhoto: false))
        XCTAssertFalse(draft.canSave(isLoadingPhoto: true))
    }

    // MARK: - Photo import

    func testAPickedPhotoBecomesABoundedJPEG() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let png = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 3200, height: 1600), format: format)
            .image { context in
                UIColor.systemTeal.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 3200, height: 1600))
            }.pngData())

        let cover = try await CoverPhotoImport.cover(from: png)
        let image = try XCTUnwrap(UIImage(data: cover))
        XCTAssertEqual(cover.prefix(2), Data([0xFF, 0xD8]), "a JPEG")
        XCTAssertEqual(max(image.size.width * image.scale, image.size.height * image.scale), 1600)
    }

    func testAPhotoThatCannotBeReadFails() async {
        for data in [nil, Data("not an image".utf8)] {
            do {
                _ = try await CoverPhotoImport.cover(from: data)
                XCTFail("expected a failure for \(String(describing: data))")
            } catch let error as CocoaError {
                XCTAssertEqual(error.code, .fileReadCorruptFile)
            } catch {
                XCTFail("unexpected \(error)")
            }
        }
    }

    /// Choosing another photo or a template cancels the import before it compresses anything.
    func testACancelledImportStops() async {
        // Bytes that would otherwise fail as a corrupt file, so only cancellation explains a CancellationError.
        let task = Task { @MainActor in
            try await CoverPhotoImport.cover(from: Data("not an image".utf8))
        }
        task.cancel()
        let result = await task.result
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
    }
}
