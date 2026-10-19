import SwiftUI

/// Pushed screens inside 我的.
enum MeRoute: Hashable {
    case reminders
}

/// A category's day list, or every day.
enum CategoryRoute: Hashable {
    case all, category(String)
}

/// The third tab: a summary of the library, the categories, reminders and app settings.
struct MeView: View {
    @Environment(DayStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.currentDay) private var today
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(DeepLinkRouter.self) private var router
    @AppStorage(AppLocalization.languageKey, store: SharedStorage.defaults)
    private var language = AppLanguage.system
    @Environment(\.editCategory) private var editCategory
    @State private var showingLanguage = false
    @State private var showingWidgets = false
    @State private var showingData = false

    var body: some View {
        let infos = store.days.map { ($0, DayInfo.compute($0, today: today)) }
        let past = infos.filter { $0.1.isPast }
        let byCategory = store.daysByCategory(today: today)
        VStack(spacing: 0) {
            NavHeader(title: String(localized: "我的", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    stats(total: infos.count, upcoming: infos.count - past.count, past: past.count)
                    if let oldest = past.max(by: { $0.1.days < $1.1.days }) {
                        Text("记得最久的是「\(oldest.0.title)」，已经 \(oldest.1.days.formatted()) 天。")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.ink2)
                            .padding(.horizontal, 4)
                    }

                    sectionTitle(String(localized: "分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    categoryGrid(byCategory)

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
                        row(String(localized: "数据与同步", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                            systemImage: "icloud", tint: Theme.noteBlue, ink: Theme.catTravel,
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sheet(isPresented: $showingLanguage) { LanguageSettingsView() }
        .sheet(isPresented: $showingWidgets) { WidgetsPreviewView() }
        .sheet(isPresented: $showingData) { DataManagementView() }
        // A widget or reminder link opens its day on 日子; close the settings open here. A category
        // editor (categoryEditorHost) stays on top with its draft, and the day opens beneath it.
        .onChange(of: router.linkOpenCount) {
            showingLanguage = false
            showingWidgets = false
            showingData = false
        }
    }

    private var reminderSummary: String {
        let time = NotificationManager.notificationTime(hour: settings.notificationHour,
                                                        minute: settings.notificationMinute)
        return String(localized: "每天 \(String(format: "%02d:%02d", time.hour, time.minute))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    // MARK: Stats

    private func stats(total: Int, upcoming: Int, past: Int) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            NavigationLink(value: CategoryRoute.all) {
                statCard(total, label: String(localized: "个日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                         tint: Theme.card)
            }
            .buttonStyle(PressableTileStyle())
            .accessibilityIdentifier("me.allDays")
            statCard(upcoming, label: String(localized: "home.face.upcoming", defaultValue: "将至", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                     tint: Theme.noteYellow)
            statCard(past, label: String(localized: "home.face.past", defaultValue: "已过", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                     tint: Theme.memory)
        }
    }

    private func statCard(_ value: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value.formatted())
                .numberFont(36)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.ink2)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .bottomLeading)
        .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Categories

    private func categoryGrid(_ byCategory: [String: [Day]]) -> some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(store.categories) { category in
                let days = byCategory[category.id] ?? []
                CategoryTile(category: category, coverDay: days.first, count: days.count) {
                    editCategory(category)
                }
            }
            Button { editCategory(nil) } label: {
                Label("新分类", systemImage: "plus")
                    .font(Theme.sans(14, weight: .bold))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(PressableTileStyle())
            .accessibilityLabel("新建分类")
            .accessibilityIdentifier("addCategoryButton")
        }
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
                     identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MeRowLabel(title: title, systemImage: systemImage, tint: tint, ink: ink, value: value)
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

/// A white rounded group of rows.
struct MeGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct MeDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.leading, 56)
    }
}

/// Icon tile, title, optional value and a chevron.
struct MeRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    let ink: Color
    var value: String? = nil
    var showsChevron = true
    var trailingSymbol = "chevron.right"

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink)
                .frame(width: 32, height: 32)
                .background(tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.sans(16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(verbatim: value)
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.trailing)
            }
            if showsChevron {
                Image(systemName: trailingSymbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}
