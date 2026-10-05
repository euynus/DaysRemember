import XCTest
@testable import DaysRemember

@MainActor
final class EditorSaveTests: XCTestCase {
    func testMissingDayUpdateReturnsFalseWithoutMutation() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let existing = day("existing")
            store.add(existing)
            let before = try persisted(store)

            XCTAssertFalse(store.update(day("missing")))

            XCTAssertNil(store.loadError)
            XCTAssertEqual(store.days, [existing])
            XCTAssertEqual(store.categories, CategoryDefinition.system)
            XCTAssertTrue(store.deletedDays.isEmpty)
            XCTAssertEqual(try persisted(store), before)
        }
    }

    func testCloudDeletedDayUpdateDoesNotRecreateOrChangeDeletedCopy() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let original = day("deleted")
            let other = day("other")
            store.add(original)
            store.add(other)
            var draft = original
            draft.title = "Unsaved title"
            draft.note = "Unsaved note"
            try store.applyCloudUpdate(CloudLibraryUpdate(deletedDayIDs: [original.id]))
            let deleted = store.deletedDays
            XCTAssertEqual(deleted.map(\.day), [original])
            let before = try persisted(store)

            XCTAssertFalse(store.update(draft))

            XCTAssertNil(store.loadError)
            XCTAssertEqual(store.days, [other])
            XCTAssertEqual(store.deletedDays, deleted)
            XCTAssertEqual(try persisted(store), before)
            let reloaded = DayStore(defaults: defaults)
            XCTAssertEqual(reloaded.days, [other])
            XCTAssertEqual(reloaded.deletedDays, deleted)
        }
    }

    func testExistingDayUpdateReturnsTrueAndPersists() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let original = day("existing")
            store.add(original)
            var edited = original
            edited.title = "Saved title"
            edited.note = "Saved note"

            XCTAssertTrue(store.update(edited))

            XCTAssertNil(store.loadError)
            XCTAssertEqual(store.days, [edited])
            XCTAssertEqual(DayStore(defaults: defaults).days, [edited])
        }
    }

    func testFailedPhotoWriteReturnsFalseAndRollsBackUpdate() throws {
        try withDefaults { defaults in
            let blockedDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("EditorSaveTests.\(UUID().uuidString)")
            try Data("not a directory".utf8).write(to: blockedDirectory)
            defer { try? FileManager.default.removeItem(at: blockedDirectory) }
            let store = DayStore(defaults: defaults, photoDirectory: blockedDirectory)
            var original = day("existing")
            original.photoData = nil
            store.add(original)
            XCTAssertNil(store.loadError)
            let before = try XCTUnwrap(defaults.data(forKey: "days.v2"))
            var edited = original
            edited.title = "Must not persist"
            edited.photoData = Data([4, 5, 6])

            XCTAssertFalse(store.update(edited))

            XCTAssertNil(store.loadError, "A recoverable save failure must not replace the root editor")
            XCTAssertNotNil(store.saveError)
            XCTAssertEqual(store.days, [original])
            XCTAssertEqual(defaults.data(forKey: "days.v2"), before)

            try FileManager.default.removeItem(at: blockedDirectory)
            XCTAssertTrue(store.update(edited), "The same draft must be saveable after storage recovers")
            XCTAssertNil(store.saveError)
            XCTAssertEqual(store.days, [edited])
            XCTAssertEqual(DayStore(defaults: defaults, photoDirectory: blockedDirectory).days, [edited])
        }
    }

    func testUnchangedUnresolvedCategorySurvivesEditorSaveAndReload() throws {
        try withDefaults { defaults in
            let store = DayStore(defaults: defaults)
            let original = day("unresolved")
            store.add(original)
            var draft = original
            draft.title = "Edited title"
            let saved = try XCTUnwrap(DayEditorView.applyingCategory(
                to: draft, selectedCategory: nil, categories: store.categories))

            XCTAssertEqual(saved, draft)
            XCTAssertTrue(store.update(saved))

            let reloaded = DayStore(defaults: defaults)
            XCTAssertNil(reloaded.loadError)
            XCTAssertEqual(reloaded.days, [draft])
            XCTAssertEqual(reloaded.days.first?.categoryID, original.categoryID)
            XCTAssertEqual(reloaded.days.first?.categoryLabel, original.categoryLabel)
            XCTAssertEqual(reloaded.days.first?.category, .travel)
        }
    }

    func testFailedAdditionPreservesDeletedCopyAndCanBeRetried() throws {
        try withDefaults { defaults in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("EditorSaveTests.\(UUID().uuidString)")
            try Data("blocked photo directory".utf8).write(to: directory)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = DayStore(defaults: defaults, photoDirectory: directory)
            var original = day("deleted-before-retry")
            original.photoData = nil
            XCTAssertTrue(store.add(original))
            store.delete(original)
            let deleted = store.deletedDays
            var draft = original
            draft.title = "Restored draft"
            draft.photoData = Data([7, 8, 9])

            XCTAssertFalse(store.add(draft))
            XCTAssertNil(store.loadError)
            XCTAssertNotNil(store.saveError)
            XCTAssertTrue(store.days.isEmpty)
            XCTAssertEqual(store.deletedDays, deleted)

            try FileManager.default.removeItem(at: directory)
            XCTAssertTrue(store.add(draft))
            XCTAssertNil(store.saveError)
            XCTAssertEqual(store.days, [draft])
            XCTAssertTrue(store.deletedDays.isEmpty)
            let reloaded = DayStore(defaults: defaults, photoDirectory: directory)
            XCTAssertEqual(reloaded.days, [draft])
            XCTAssertTrue(reloaded.deletedDays.isEmpty)
        }
    }

    func testUnresolvedCategoryUsesDefinitionIfItArrivesBeforeSave() throws {
        let draft = day("unresolved")
        let resolved = CategoryDefinition(id: draft.categoryID, name: "Resolved category",
                                          icon: "tag", colorToken: .sage, isSystem: false)
        let saved = try XCTUnwrap(DayEditorView.applyingCategory(
            to: draft, selectedCategory: nil, categories: CategoryDefinition.system + [resolved]))
        var expected = draft
        expected.categoryLabel = resolved.name
        expected.category = .life
        XCTAssertEqual(saved, expected)
    }

    func testSelectedCategoryUsesLatestDefinitionWithoutChangingOtherFields() throws {
        let draft = day("edited")
        let selected = CategoryDefinition(id: "custom.selected", name: "Previous name",
                                          icon: "tag", colorToken: .sage, isSystem: false)
        var renamed = selected
        renamed.name = "Current name"
        let saved = try XCTUnwrap(DayEditorView.applyingCategory(
            to: draft, selectedCategory: selected, categories: CategoryDefinition.system + [renamed]))
        var expected = draft
        expected.categoryID = renamed.id
        expected.categoryLabel = renamed.name
        expected.category = .life
        XCTAssertEqual(saved, expected)
    }

    func testDeletedCategoryRejectsBothOriginalAndNewSelections() {
        let draft = day("edited")
        for id in [draft.categoryID, "custom.selected"] {
            let selected = CategoryDefinition(id: id, name: "Removed category",
                                              icon: "tag", colorToken: .sage, isSystem: false)
            XCTAssertNil(DayEditorView.applyingCategory(
                to: draft, selectedCategory: selected, categories: CategoryDefinition.system))
        }
    }

    func testSelectingSystemCategoryUpdatesLegacyCategory() throws {
        let draft = day("edited")
        let selected = try XCTUnwrap(CategoryDefinition.system.first { $0.id == DayCategory.work.rawValue })
        let saved = try XCTUnwrap(DayEditorView.applyingCategory(
            to: draft, selectedCategory: selected, categories: CategoryDefinition.system))
        var expected = draft
        expected.categoryID = selected.id
        expected.categoryLabel = selected.name
        expected.category = .work
        XCTAssertEqual(saved, expected)
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "EditorSaveTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    private func persisted(_ store: DayStore) throws -> [String: Data] {
        try JSONDecoder().decode([String: Data].self, from: store.exportOriginalData())
    }

    private func day(_ id: String) -> Day {
        Day(id: id, title: "Original title", date: Date(timeIntervalSince1970: 1_700_000_000),
            recurring: true, lunar: true, category: .travel, photo: .home, photoData: Data([1, 2, 3]),
            categoryID: "custom.unresolved", coverFocusX: 0.2, coverFocusY: 0.8,
            reminderOffsets: [7, 0], reminderTime: DayReminderTime(hour: 10, minute: 15),
            note: "Original note", location: "Original place", pinned: true,
            categoryLabel: "Unresolved category")
    }
}
