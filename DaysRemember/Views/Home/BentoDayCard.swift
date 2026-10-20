import SwiftUI

/// A pastel card in the two-column day grid: art in the corner, the count at the bottom.
struct BentoDayCard: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let info = DayInfo.compute(day, today: today)
        let category = store.category(for: day)
        Button { onOpen(day) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 8) {
                    if day.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(category.tintInk)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 0)
                    if !dynamicTypeSize.isAccessibilitySize {
                        CoverArt(day: day, photoCornerRadius: 14, maximumPixelSize: 256,
                                 decodesAsynchronously: true)
                            .frame(width: 64, height: 64)
                    }
                }
                Spacer(minLength: 8)
                if !info.isToday { CountLabel(info: info) }
                CountValue(info: info, size: 36)
                Text(verbatim: day.title)
                    .font(Theme.sans(15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)
                Text(DayCardText.meta(day, info: info, category: category))
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.onPastel)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .background(category.tint, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityLabel(DayCardText.accessibilityLabel(day, info: info))
        .accessibilityHint("长按可置顶、编辑或分享")
        .accessibilityIdentifier("dayRow.\(day.id)")
    }
}
