import SwiftUI

/// A day in the 本月日子 list, on its category's pastel.
struct CalendarMonthRow: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    let year: Int
    /// 0-indexed.
    let month: Int
    let dayNumber: Int
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let metadata = subtitle(for: day, label: store.category(for: day).displayName)
        let date = CNDate.calendar.date(from: DateComponents(year: year, month: month + 1, day: dayNumber)) ?? today
        let category = store.category(for: day)
        return Button { onOpen(day) } label: {
            HStack(alignment: .center, spacing: 12) {
                if !dynamicTypeSize.isAccessibilitySize {
                    CoverArt(day: day, photoCornerRadius: 12, maximumPixelSize: 192, decodesAsynchronously: true)
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(CNDate.short(date))
                        .font(Theme.sans(12, weight: .heavy))
                        .foregroundStyle(category.tintInk)
                    Text(verbatim: day.title)
                        .font(Theme.sans(16, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(verbatim: metadata)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.onPastel)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(category.tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(CNDate.short(date))，\(day.title)，\(metadata)", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        .accessibilityHint("查看日子详情")
        .accessibilityInputLabels([day.title])
    }

    private func subtitle(for day: Day, label: String) -> String {
        var parts = [label]
        if day.recurring { parts.append(String(localized: "每年", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) }
        if day.lunar { parts.append(String(localized: "农历", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) }
        return parts.joined(separator: " · ")
    }
}
