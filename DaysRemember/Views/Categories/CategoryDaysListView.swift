import SwiftUI

struct CategoryDaysListView: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let title: String
    let categoryID: String?
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let days = store.days(in: categoryID, today: today)
        ScrollView {
            if days.isEmpty {
                ContentUnavailableView("还没有日子", systemImage: "calendar")
            } else {
                DayGrid(days: days, onOpen: onOpen)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        // A visible system bar keeps the back button's edge swipe working.
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbarRole(.editor)
        .toolbarVisibility(.visible, for: .navigationBar)
        // A sync can delete the category while its list is open, as for a day's detail.
        .onChange(of: categoryID.map { id in store.categories.contains { $0.id == id } } ?? true) { _, exists in
            if !exists { dismiss() }
        }
    }
}
