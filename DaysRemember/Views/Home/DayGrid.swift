import SwiftUI

/// The two-column grid of day cards, one column at accessibility text sizes.
struct DayGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let days: [Day]
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(days) { day in
                BentoDayCard(day: day, onOpen: onOpen)
                    .dayContextMenu(day: day)
            }
        }
    }
}
