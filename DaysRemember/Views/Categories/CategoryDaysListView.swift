import SwiftUI

struct CategoryDaysListView: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    let title: String
    let categoryID: String?
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let days = store.days(in: categoryID, today: today)
        ScrollView {
            if days.isEmpty {
                ContentUnavailableView("还没有日子", systemImage: "calendar")
            } else {
                DayList(days: days, onOpen: onOpen)
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
        .toolbar(.visible, for: .navigationBar)
    }
}
