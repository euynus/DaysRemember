import SwiftUI

/// Picks the day's date, Gregorian or lunar, as a draft the editor takes on 完成.
struct DayEditorDatePickerSheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let solar: Bool
    @Binding var draftDate: Date
    var onCancel: () -> Void = {}
    var onConfirm: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onCancel() } label: {
                    Text("取消")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("cancelDayDatePicker")
                Spacer()
                Text(solar ? String(localized: "选择日期", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "选择农历日期", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(16, weight: .bold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dayDatePickerTitle")
                Spacer()
                Button(action: onConfirm) {
                    Text("完成")
                        .font(Theme.sans(15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("confirmDayDatePicker")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            if solar {
                DatePicker("选择日期", selection: $draftDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, AppLocalization.locale)
                    .environment(\.calendar, CNDate.calendar)
                    .environment(\.timeZone, CNDate.calendar.timeZone)
                    .tint(Theme.ink)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("daySolarDatePicker")
            } else {
                LunarDatePicker(selection: $draftDate)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .presentationDetents(dynamicTypeSize > .large ? [.large] : [.medium, .large])
    }
}
