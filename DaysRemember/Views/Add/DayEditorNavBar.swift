import SwiftUI

/// 取消, the editor's title and 保存.
struct DayEditorNavBar: View {
    let isNew: Bool
    let canSave: Bool
    var onCancel: () -> Void = {}
    var onSave: () -> Void = {}

    var body: some View {
        HStack {
            Button(action: onCancel) {
                Text("取消")
                    .font(Theme.sans(16, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(PressScale())
            .accessibilityIdentifier("cancelDayButton")

            Spacer()
            Text(isNew ? String(localized: "新的日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "编辑日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                .font(Theme.sans(16, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer()

            PillButton(title: String(localized: "保存", bundle: AppLocalization.bundle, locale: AppLocalization.locale), style: .dark, height: 44, action: onSave)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .accessibilityIdentifier("saveDayButton")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
