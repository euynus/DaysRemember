import SwiftUI

struct CalendarEventRow: View {
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    var onOpen: (Day) -> Void

    var body: some View {
        let categoryName = store.category(for: day).displayName
        Button(action: { onOpen(day) }) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: day.title)
                        .font(Theme.sans(15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(verbatim: categoryName)
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize {
                    PhotoTile(day: day, flat: true, cornerRadius: 6, maximumPixelSize: 192,
                              decodesAsynchronously: true)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44, alignment: .leading)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.title)，\(categoryName)")
        .accessibilityHint("查看日子详情")
        .accessibilityInputLabels([day.title])
    }
}
