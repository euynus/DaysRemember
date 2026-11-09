import Foundation

/// The category editor's working copy. Nothing reaches the store until it is saved.
struct CategoryDraft: Equatable {
    /// A new category's icon and colour until the user picks others.
    static let newIcon = "tag"
    static let newColorToken = CategoryColorToken.terracotta

    /// The category as the editor opened it; nil for a new one.
    let original: CategoryDefinition?
    var name: String
    var icon: String
    var colorToken: CategoryColorToken

    init(editing category: CategoryDefinition?) {
        original = category
        name = category?.name ?? ""
        icon = category?.icon ?? Self.newIcon
        colorToken = category?.colorToken ?? Self.newColorToken
    }

    /// A category needs a name; spaces alone aren't one.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether closing the editor would lose anything.
    var hasChanges: Bool {
        name != (original?.name ?? "") || icon != (original?.icon ?? Self.newIcon)
            || colorToken != (original?.colorToken ?? Self.newColorToken)
    }

    /// The edited category for `DayStore.updateCategory`, which trims it; nil for a new category,
    /// which `DayStore.addCategory` makes from the draft's fields.
    var edited: CategoryDefinition? {
        guard var category = original else { return nil }
        category.name = name
        category.icon = icon
        category.colorToken = colorToken
        return category
    }
}
