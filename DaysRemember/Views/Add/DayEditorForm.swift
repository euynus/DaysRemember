import SwiftUI

/// Date, calendar, repeat, reminders and place.
struct DayEditorForm: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let selectedDate: Date
    @Binding var solar: Bool
    @Binding var recurring: Bool
    let reminderOffsets: [Int]?
    let reminderTime: DayReminderTime?
    @Binding var location: String
    var onPickDate: () -> Void = {}
    var onEditReminders: () -> Void = {}

    var body: some View {
        CardList {
            // 日期 → opens the date picker sheet.
            Button {
                onPickDate()
            } label: {
                HStack(spacing: 14) {
                    Text("日期").font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(CNDate.full(selectedDate))
                            .font(Theme.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        if !solar {
                            Text("农历 \(Lunar.fmt(selectedDate))")
                                .font(Theme.sans(12, weight: .medium))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(Theme.symbol(12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
                }
                .cardRow()
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale(scale: 0.99))
            .accessibilityIdentifier("dayDatePickerButton")

            RowDivider()
            row(label: String(localized: "日历", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) {
                SegPicker(title: String(localized: "日历", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                          options: [(true, String(localized: "公历", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
                                    (false, String(localized: "农历", bundle: AppLocalization.bundle, locale: AppLocalization.locale))], selection: $solar)
            }

            RowDivider()
            row(label: String(localized: "类型", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) {
                SegPicker(title: String(localized: "类型", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                          options: [(false, String(localized: "一次", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
                                    (true, String(localized: "每年", bundle: AppLocalization.bundle, locale: AppLocalization.locale))], selection: $recurring)
            }

            RowDivider()
            Button {
                onEditReminders()
            } label: {
                row(label: String(localized: "提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) {
                    HStack(spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(reminderSummary)
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.ink2)
                            if let reminderTime, reminderOffsets != [] {
                                Text(CNDate.time(hour: reminderTime.hour, minute: reminderTime.minute))
                                    .font(Theme.sans(12, weight: .medium))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(Theme.symbol(12, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale(scale: 0.99))
            .accessibilityIdentifier("dayReminderSettingsButton")

            RowDivider()
            HStack(spacing: 14) {
                Text("地点").font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                TextField("可选", text: $location)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tint(Theme.ink)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .accessibilityLabel("地点")
                    .accessibilityIdentifier("dayLocationField")
            }
            .cardRow()
        }
    }

    private func row<Content: View>(label: String,
                                    @ViewBuilder content: () -> Content) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 14))
        return layout {
            Text(label).font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            content()
        }
        .cardRow()
    }

    private var reminderSummary: String {
        guard let offsets = reminderOffsets else { return String(localized: "跟随全局设置", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        let selected = Set(offsets)
        if selected.isEmpty { return String(localized: "不提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        if selected.count == 1, let offset = selected.first {
            return offset == 0 ? String(localized: "当天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "提前 \(offset) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        return String(localized: "自定义（\(selected.count)次）", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }
}
