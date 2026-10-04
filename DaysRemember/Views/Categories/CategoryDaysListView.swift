import SwiftUI

struct CategoryDaysListView: View {
    @Environment(\.currentDay) private var today
    @Environment(\.dismiss) private var dismiss
    @Environment(DayStore.self) private var store
    let title: String
    let categoryID: String?
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let days = store.days(in: categoryID, today: today)
        VStack(spacing: 0) {
            NavHeader(title: title) { dismiss() }
            ScrollView {
                if days.isEmpty {
                    ContentUnavailableView("还没有日子", systemImage: "calendar")
                } else {
                    DayList(days: days, onOpen: onOpen)
                        .padding(22)
                }
            }
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
    }
}
