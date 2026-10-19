import SwiftUI

/// Opens the category editor from 我的. Like a day's editor (`dayEditorHost`), it is presented from
/// the tab root: a sheet presented inside the tab is rebuilt when a link switches to 日子, losing
/// what was typed, while one here stays on top with its draft and the day opens beneath it.
struct EditCategoryAction {
    fileprivate var edit: (CategoryDefinition?) -> Void = { _ in }
    /// nil starts a new category.
    func callAsFunction(_ category: CategoryDefinition?) { edit(category) }
}

extension EnvironmentValues {
    @Entry var editCategory = EditCategoryAction()
}

private struct CategoryEditorRequest: Identifiable {
    let id = UUID()
    let category: CategoryDefinition?
}

private struct CategoryEditorHost: ViewModifier {
    @Environment(DayStore.self) private var store
    @State private var request: CategoryEditorRequest?

    func body(content: Content) -> some View {
        content
            .environment(\.editCategory, EditCategoryAction { request = CategoryEditorRequest(category: $0) })
            .sheet(item: $request) { CategoryEditorView(category: $0.category).environment(store) }
    }
}

extension View {
    /// Presents the category editors that `\.editCategory` asks for in this view's subtree.
    func categoryEditorHost() -> some View {
        modifier(CategoryEditorHost())
    }
}
