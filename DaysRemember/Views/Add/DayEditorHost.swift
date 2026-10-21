import SwiftUI

/// Opens the editor for an existing day from a view that stays on screen. A sheet attached to a
/// feed row, the hero card or a pushed detail closes with that view, losing the draft, when the
/// day moves in the feed, a sync deletes it or a link opens another day; and a sheet on the hero
/// card follows the card to whichever day it shows next.
struct EditDayAction {
    fileprivate var edit: (Day) -> Void = { _ in }
    func callAsFunction(_ day: Day) { edit(day) }
}

extension EnvironmentValues {
    @Entry var editDay = EditDayAction()
    @Entry var addDay = AddDayAction()
}

/// Starts a new day, in a category when given, from the editor `RootTabView` presents: a sheet on a
/// pushed list would be rebuilt, losing its draft, when a link switches tabs.
struct AddDayAction {
    var add: (_ categoryID: String?) -> Void = { _ in }
    func callAsFunction(categoryID: String? = nil) { add(categoryID) }
}

private struct EditorRequest: Identifiable {
    let id = UUID()
    let day: Day
}

private struct DayEditorHost: ViewModifier {
    @Environment(DayStore.self) private var store
    @State private var request: EditorRequest?

    func body(content: Content) -> some View {
        content
            .environment(\.editDay, EditDayAction { request = EditorRequest(day: $0) })
            .sheet(item: $request) { DayEditorView(day: $0.day).environment(store) }
    }
}

extension View {
    /// Presents the editors that `\.editDay` asks for in this view's subtree.
    func dayEditorHost() -> some View {
        modifier(DayEditorHost())
    }
}
