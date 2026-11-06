import SwiftUI

/// An editor sheet's bar: 取消, the editor's title and 保存.
struct EditorNavBar: View {
    let title: String
    let canSave: Bool
    let cancelIdentifier: String
    let saveIdentifier: String
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
            .accessibilityIdentifier(cancelIdentifier)

            Spacer()
            Text(title)
                .font(Theme.sans(16, weight: .bold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()

            PillButton(title: String(localized: "保存", bundle: AppLocalization.bundle, locale: AppLocalization.locale), style: .dark, height: 44, action: onSave)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .accessibilityIdentifier(saveIdentifier)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
