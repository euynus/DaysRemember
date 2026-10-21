import SwiftUI

/// The third tab: a summary of the library, the categories, reminders and app settings.
struct MeView: View {
    @Environment(DayStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.currentDay) private var today
    @Environment(DeepLinkRouter.self) private var router
    @AppStorage(AppLocalization.languageKey, store: SharedStorage.defaults)
    private var language = AppLanguage.system
    @State private var showingLanguage = false
    @State private var showingWidgets = false
    @State private var showingData = false
    @State private var importingBirthdays = false
    @State private var cloud = CloudLibrarySync.shared

    var body: some View {
        let infos = store.days.map { ($0, DayInfo.compute($0, today: today)) }
        let past = infos.filter { $0.1.isPast }
        let byCategory = store.daysByCategory(today: today)
        VStack(spacing: 0) {
            NavHeader(title: String(localized: "我的", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MeStats(total: infos.count, upcoming: infos.count - past.count, past: past.count)
                    if let oldest = past.max(by: { $0.1.days < $1.1.days }) {
                        Text("记得最久的是「\(oldest.0.title)」，已经 \(oldest.1.days) 天。")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.ink2)
                            .padding(.horizontal, 4)
                    }

                    sectionTitle(String(localized: "分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    MeCategoryGrid(byCategory: byCategory)

                    sectionTitle(String(localized: "提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    MeGroup {
                        NavigationLink(value: MeRoute.reminders) {
                            MeRowLabel(title: String(localized: "提醒设置", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                       systemImage: "bell", tint: Theme.noteYellow, ink: Theme.catLife,
                                       value: reminderSummary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("me.reminders")
                    }

                    sectionTitle(String(localized: "桌面与数据", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    MeGroup {
                        row(String(localized: "小组件", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                            systemImage: "rectangle.3.group", tint: Theme.noteGreen, ink: Theme.catWork,
                            identifier: "settings.widgets") { showingWidgets = true }
                        MeDivider()
                        row(String(localized: "导入通讯录生日", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                            systemImage: "gift", tint: Theme.notePink, ink: Theme.catLove,
                            identifier: "settings.contacts") { importingBirthdays = true }
                        MeDivider()
                        row(String(localized: "数据与同步", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                            systemImage: "icloud", tint: Theme.noteBlue, ink: Theme.catTravel,
                            value: cloud.attentionSummary, valueColor: Theme.danger,
                            identifier: "settings.data") { showingData = true }
                        MeDivider()
                        row(String(localized: "语言", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                            systemImage: "globe", tint: Theme.memory, ink: Theme.memoryInk,
                            value: language.displayName, identifier: "settings.language") { showingLanguage = true }
                    }

                    sectionTitle(String(localized: "关于", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    MeGroup {
                        MeRowLabel(title: String(localized: "版本", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                   systemImage: "info.circle", tint: Theme.bg2, ink: Theme.ink2,
                                   value: SettingsView.version, showsChevron: false)
                        MeDivider()
                        link(String(localized: "隐私政策", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                             systemImage: "hand.raised", page: "privacy/", identifier: "settings.privacy")
                        MeDivider()
                        link(String(localized: "帮助与反馈", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                             systemImage: "questionmark.circle", page: "support/", identifier: "settings.support")
                    }
                    Text("日子、照片和设置只保存在这台设备和你自己的 iCloud 中，不会上传给开发者。")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sheet(isPresented: $showingLanguage) { LanguageSettingsView() }
        .sheet(isPresented: $showingWidgets) { WidgetsPreviewView() }
        .sheet(isPresented: $showingData) { DataManagementView() }
        .sheet(isPresented: $importingBirthdays) { ContactBirthdaysView() }
        // A widget or reminder link opens its day on 日子; close the settings open here. A category
        // editor (categoryEditorHost) stays on top with its draft, and the day opens beneath it.
        .onChange(of: router.linkOpenCount) {
            showingLanguage = false
            showingWidgets = false
            showingData = false
            importingBirthdays = false
        }
    }

    private var reminderSummary: String {
        let time = NotificationManager.notificationTime(hour: settings.notificationHour,
                                                        minute: settings.notificationMinute)
        return String(localized: "每天 \(CNDate.time(hour: time.hour, minute: time.minute))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    // MARK: Rows

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Theme.sans(17, weight: .heavy, relativeTo: .headline))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ title: String, systemImage: String, tint: Color, ink: Color, value: String? = nil,
                     valueColor: Color = Theme.muted, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MeRowLabel(title: title, systemImage: systemImage, tint: tint, ink: ink, value: value, valueColor: valueColor)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    /// A page of the product site (`docs/`), opened at the app language's section.
    private func link(_ title: String, systemImage: String, page: String, identifier: String) -> some View {
        Link(destination: SettingsView.siteURL(page)) {
            MeRowLabel(title: title, systemImage: systemImage, tint: Theme.bg2, ink: Theme.ink2,
                       trailingSymbol: "arrow.up.right")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
