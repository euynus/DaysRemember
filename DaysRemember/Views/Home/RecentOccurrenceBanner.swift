import SwiftUI

/// A recurring day that just passed, kept on the feed for a week with a prompt to write it down.
struct RecentOccurrenceBanner: View {
    @Environment(DayStore.self) private var store
    @Environment(\.editDay) private var editDay
    let day: Day
    let occurrence: RecentOccurrence
    var onOpen: (Day) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let category = store.category(for: day)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            Button { onOpen(day) } label: {
                HStack(spacing: 10) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        CoverArt(day: day, photoCornerRadius: 12, maximumPixelSize: 192, decodesAsynchronously: true)
                            .frame(width: 48, height: 48)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(occurrence.daysAgo) 天前 · 第 \(occurrence.number) 周年")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.onPastel)
                        Text(verbatim: day.title)
                            .font(Theme.sans(15, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableTileStyle())
            Button { editDay(day) } label: {
                Text("写下这一天")
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(category.tintInk)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recentOccurrence.write")
        }
        .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 14 : 8)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(category.tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("recentOccurrence.\(day.id)")
    }
}
