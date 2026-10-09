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
                    LabeledContent {
                        Text(verbatim: Self.version)
                    } label: {
                        Label("版本", systemImage: "info.circle")
                            .foregroundStyle(Theme.ink)
                    }
                    link("隐私政策", systemImage: "hand.raised", page: "privacy/", identifier: "settings.privacy")
                    link("帮助与反馈", systemImage: "questionmark.circle", page: "support/", identifier: "settings.support")
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

    /// A page of the product site (`docs/`), opened at the app language's section.
    private func link(_ title: LocalizedStringKey, systemImage: String, page: String,
                      identifier: String) -> some View {
        Link(destination: Self.siteURL(page)) {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .accessibilityIdentifier(identifier)
    }

    static let siteBase = "https://days.gooday.dev/"

    /// The privacy and support pages hold all three languages, anchored by localization.
    static func siteURL(_ page: String, locale: Locale = AppLocalization.locale) -> URL {
        let language = locale.language
        let anchor = language.languageCode?.identifier == "en" ? "en"
            : language.script?.identifier == "Hant" ? "zh-Hant" : "zh-Hans"
        return URL(string: siteBase + page + "#" + anchor)!
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
