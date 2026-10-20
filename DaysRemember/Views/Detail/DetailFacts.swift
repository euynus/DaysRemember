import SwiftUI

/// Date, lunar date, repeat and reminder tiles.
struct DetailFacts: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    let info: DayInfo

    var body: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            fact(String(localized: "日期", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                 String(localized: "\(CNDate.short(info.displayDate)) \(CNDate.weekday(info.displayDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            fact(String(localized: "农历", bundle: AppLocalization.bundle, locale: AppLocalization.locale), Lunar.fmt(info.displayDate))
            fact(String(localized: "重复", bundle: AppLocalization.bundle, locale: AppLocalization.locale), repeatText(day))
            fact(String(localized: "提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale), reminderText(day))
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(Theme.sans(15, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func repeatText(_ day: Day) -> String {
        guard day.recurring else { return String(localized: "不重复", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        return day.lunar ? String(localized: "每年 · 按农历", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "每年", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    private func reminderText(_ day: Day) -> String {
        guard let offsets = day.reminderOffsets else {
            return String(localized: "跟随全局设置", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        let selected = Set(offsets)
        if selected.isEmpty { return String(localized: "不提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        if selected.count == 1, let offset = selected.first {
            return offset == 0 ? String(localized: "当天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : String(localized: "提前 \(offset) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        return String(localized: "自定义（\(selected.count)次）", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }
}
