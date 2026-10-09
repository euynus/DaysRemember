import SwiftUI

/// App-wide preferences and information, opened from the home header.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLocalization.languageKey, store: SharedStorage.defaults)
    private var language = AppLanguage.system
    @State private var showingLanguage = false
    @State private var showingWidgets = false
    @State private var showingData = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    row("语言", systemImage: "globe", value: language.displayName, identifier: "settings.language") {
                        showingLanguage = true
                    }
                    row("小组件", systemImage: "rectangle.3.group", identifier: "settings.widgets") {
                        showingWidgets = true
                    }
                    row("数据与同步", systemImage: "externaldrive", identifier: "settings.data") {
                        showingData = true
                    }
                }
                Section {
                    LabeledContent("版本", value: Self.version)
                } header: {
                    Text("关于")
                } footer: {
                    Text("日子、照片和设置只保存在这台设备和你自己的 iCloud 中，不会上传给开发者。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        .tint(Theme.accent)
        .sheet(isPresented: $showingLanguage) { LanguageSettingsView() }
        .sheet(isPresented: $showingWidgets) { WidgetsPreviewView() }
        .sheet(isPresented: $showingData) { DataManagementView() }
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, value: String? = nil,
                     identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                if let value {
                    Text(verbatim: value)
                        .foregroundStyle(Theme.muted)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .accessibilityIdentifier(identifier)
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
