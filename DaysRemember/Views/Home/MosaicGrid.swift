import SwiftUI

/// Asymmetric 2-column tile layout: index 0 → hero (2×2), 3/6 → wide (2×1), else square.
struct MosaicGrid: View {
    let days: [Day]
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        // We render rows manually so we can place the 2×2 hero correctly.
        let rows = layout()
        VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { i in
                rowView(rows[i])
            }
        }
    }

    private enum Cell { case hero(Day), wide(Day), sq(Day) }

    private func plan(for index: Int) -> String {
        if index == 0 { return "hero" }
        if index == 3 || index == 6 { return "wide" }
        return "sq"
    }

    /// Group days into rows that respect tile spans.
    private func layout() -> [[Cell]] {
        var rows: [[Cell]] = []
        var i = 0
        while i < days.count {
            switch plan(for: i) {
            case "hero":
                rows.append([.hero(days[i])])
                i += 1
            case "wide":
                rows.append([.wide(days[i])])
                i += 1
            default:
                let next = i + 1
                if next < days.count, plan(for: next) == "sq" {
                    rows.append([.sq(days[i]), .sq(days[next])])
                    i += 2
                } else {
                    rows.append([.sq(days[i])])
                    i += 1
                }
            }
        }
        return rows
    }

    @ViewBuilder
    private func rowView(_ row: [Cell]) -> some View {
        HStack(spacing: 10) {
            ForEach(row.indices, id: \.self) { j in
                cellView(row[j])
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .hero(let d):
            DayTile(day: d, size: .hero, action: { onOpen(d) })
                .frame(maxWidth: .infinity)
                .aspectRatio(1.35, contentMode: .fit)
        case .wide(let d):
            DayTile(day: d, size: .wide, action: { onOpen(d) })
                .frame(maxWidth: .infinity)
                .aspectRatio(2.2, contentMode: .fit)
        case .sq(let d):
            DayTile(day: d, size: .sq, action: { onOpen(d) })
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
    }
}
