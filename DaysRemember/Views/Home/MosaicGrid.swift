import SwiftUI

/// The scrapbook feed grid — a 2-column layout of `DayPolaroid` cards (the
/// `grid-template-columns: 1fr 1fr; gap: 18` feed in `screens/Home.jsx`).
struct MosaicGrid: View {
    let days: [Day]
    var onOpen: (Day) -> Void = { _ in }

    private let columns = [
        GridItem(.flexible(), spacing: 18, alignment: .top),
        GridItem(.flexible(), spacing: 18, alignment: .top),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                DayPolaroid(day: day, idx: idx, onOpen: onOpen)
                    .dayContextMenu(day: day)
            }
        }
    }
}
