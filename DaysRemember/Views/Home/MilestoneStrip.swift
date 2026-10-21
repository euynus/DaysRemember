import SwiftUI

/// A sideways row of the next round numbers past days reach.
struct MilestoneStrip: View {
    @Environment(DayStore.self) private var store
    let items: [(Day, Milestone)]
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0.id) { day, milestone in
                    Button { onOpen(day) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                if milestone.daysUntil == 0 {
                                    Text("今天")
                                        .numberFont(26)
                                        .foregroundStyle(store.category(for: day).tintInk)
                                } else {
                                    Text(milestone.daysUntil, format: .number)
                                        .numberFont(26)
                                        .foregroundStyle(store.category(for: day).tintInk)
                                    Text(String(localized: "countdown.daysLeftUnit", defaultValue: "\(milestone.daysUntil)天后",
                                                bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                                        .font(Theme.sans(12))
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            Text(verbatim: "\(day.title) \(milestone.title)")
                                .font(Theme.sans(13, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(width: 160, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(PressableTileStyle())
                    .dayContextMenu(day: day)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}
