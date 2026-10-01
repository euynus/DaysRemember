import SwiftUI

struct DayList: View {
    let days: [Day]
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(days) { day in
                DayRow(day: day, onOpen: onOpen)
                    .dayContextMenu(day: day)
            }
        }
    }
}
