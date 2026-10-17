import SwiftUI

/// A list of days as pastel cards, used by the category lists.
struct DayList: View {
    let days: [Day]
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        DayGrid(days: days, onOpen: onOpen)
    }
}
