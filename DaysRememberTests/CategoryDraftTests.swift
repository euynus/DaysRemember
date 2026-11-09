import XCTest
@testable import DaysRemember

@MainActor
final class CategoryDraftTests: XCTestCase {
    private let friends = CategoryDefinition(id: "custom.friends", name: "朋友", icon: "heart",
                                             colorToken: .sage, isSystem: false)

    func testAnOpenedDraftHasNoChanges() {
        let editing = CategoryDraft(editing: friends)
        XCTAssertEqual(editing.original, friends)
        XCTAssertEqual(editing.name, "朋友")
        XCTAssertEqual(editing.icon, "heart")
        XCTAssertEqual(editing.colorToken, .sage)
        XCTAssertFalse(editing.hasChanges)
        XCTAssertTrue(editing.canSave)

        let new = CategoryDraft(editing: nil)
        XCTAssertNil(new.original)
        XCTAssertEqual(new.icon, CategoryDraft.newIcon)
        XCTAssertEqual(new.colorToken, CategoryDraft.newColorToken)
        XCTAssertFalse(new.hasChanges, "An untouched new category has nothing to lose")
        XCTAssertFalse(new.canSave, "A new category needs a name")
    }

    func testEveryEditedFieldIsAChange() {
        var renamed = CategoryDraft(editing: friends)
        renamed.name = "老朋友"
        XCTAssertTrue(renamed.hasChanges)

        var reiconed = CategoryDraft(editing: friends)
        reiconed.icon = "star"
        XCTAssertTrue(reiconed.hasChanges)

        var recoloured = CategoryDraft(editing: friends)
        recoloured.colorToken = .rose
        XCTAssertTrue(recoloured.hasChanges)

        var new = CategoryDraft(editing: nil)
        new.colorToken = .amber
        XCTAssertTrue(new.hasChanges, "A colour picked for a new category is a change too")

        var restored = CategoryDraft(editing: friends)
        restored.name = "老朋友"
        restored.name = "朋友"
        XCTAssertFalse(restored.hasChanges, "Changing a field back isn't a change")
    }

    func testABlankNameCannotBeSaved() {
        var draft = CategoryDraft(editing: friends)
        draft.name = "  \n"
        XCTAssertFalse(draft.canSave)
        XCTAssertTrue(draft.hasChanges, "Clearing the name still asks before it's discarded")
    }

    func testTheEditedCategoryKeepsItsIdentity() throws {
        var draft = CategoryDraft(editing: friends)
        draft.name = "老朋友"
        draft.icon = "star"
        draft.colorToken = .dusty
        let edited = try XCTUnwrap(draft.edited)
        XCTAssertEqual(edited.id, friends.id)
        XCTAssertFalse(edited.isSystem)
        XCTAssertEqual(edited.name, "老朋友")
        XCTAssertEqual(edited.icon, "star")
        XCTAssertEqual(edited.colorToken, .dusty)
        XCTAssertNil(CategoryDraft(editing: nil).edited, "A new category is added, not updated")
    }

    func testTheEditedCategoryRelabelsItsDaysWhenSaved() throws {
        let suite = "CategoryDraftTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DayStore(defaults: defaults)
        store.categories.append(friends)
        XCTAssertTrue(store.add(Day(id: "trip", title: "Trip", date: Today.date, category: .life,
                                    photo: .home, categoryID: friends.id, categoryLabel: friends.name)))

        var draft = CategoryDraft(editing: friends)
        draft.name = " 老朋友 "
        XCTAssertTrue(store.updateCategory(try XCTUnwrap(draft.edited)))
        XCTAssertEqual(store.category(for: friends.id).name, "老朋友")
        XCTAssertEqual(store.days.first?.categoryLabel, "老朋友")
    }
}
