import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLocalization.languageKey, store: SharedStorage.defaults)
    private var language = AppLanguage.system
    @State private var selection = AppLanguage.system

    var body: some View {
        NavigationStack {
            Form {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        selection = option
                    } label: {
                        HStack(spacing: 12) {
                            Text(verbatim: option.displayName)
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                                .opacity(selection == option ? 1 : 0)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .accessibilityIdentifier("language.option.\(option.rawValue)")
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .accessibilityIdentifier("language.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        language = selection
                        dismiss()
                    }
                    .accessibilityIdentifier("language.done")
                }
            }
        }
        .tint(Theme.accent)
        .onAppear { selection = language }
    }
}
