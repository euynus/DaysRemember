import Accessibility
import SwiftUI

enum AppTab: String, Hashable {
    case home, calendar, categories, notifications
}

/// Navigation value for a day's detail. Routing by ID keeps photo bytes out of the
/// path's hashing and lets the detail read the live record.
struct DayRoute: Hashable {
    let id: String
}

struct RootTabView: View {
    @Environment(DayStore.self) private var store
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab: AppTab = Self.initialTab()
    @State private var homePath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var categoryPath = NavigationPath()
    @State private var addingDay = false

    init(startWithNewDay: Bool = false) {
        _addingDay = State(initialValue: startWithNewDay)
    }

    /// Allows `xcrun simctl launch ... --tab calendar` for screenshotting.
    private static func initialTab() -> AppTab {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--tab"), i + 1 < args.count,
           let t = AppTab(rawValue: args[i + 1]) { return t }
        return .home
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tint(Theme.accent)
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error = store.saveError {
                    HStack(alignment: .top, spacing: 12) {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("关闭", systemImage: "xmark") { store.dismissSaveError() }
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Theme.bg)
                }
            }
            .sheet(isPresented: $addingDay) { AddDayView().environment(store) }
            .onOpenURL { handleDeepLink($0) }
            .onChange(of: router.dayID) { _, id in routePending(id) }
            // Also catch a tap that set the id before this view began observing
            // (cold launch from a notification).
            .task { routePending(router.dayID) }
    }

    /// Floats above the active tab's tab bar. An overlay rather than an inset, so screens
    /// never shift — and move a tap target — when it appears or times out.
    private func undoOverlay(on tab: AppTab) -> some View {
        ZStack {
            if self.tab == tab, let deleted = store.lastDeleted {
                undoBanner(deleted)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: store.lastDeleted?.id)
    }

    /// Undo for the latest deletion; it also stays recoverable in 最近删除.
    private func undoBanner(_ deleted: DeletedDay) -> some View {
        HStack(spacing: 12) {
            Label(String(localized: "已删除「\(deleted.day.title)」", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                  systemImage: "trash")
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("撤销") {
                Haptics.success()
                store.undoLastDeletion()
            }
            .fontWeight(.semibold)
            .foregroundStyle(Theme.accent)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("undoDelete")
        }
        .font(.footnote)
        .foregroundStyle(Theme.ink)
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairlineStrong, lineWidth: 1)
        }
        .shadow(color: Theme.ink.opacity(0.08), radius: 8, y: 2)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: deleted.id) {
            AccessibilityNotification.Announcement(
                String(localized: "已删除「\(deleted.day.title)」", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            ).post()
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            if store.lastDeleted?.id == deleted.id { store.dismissLastDeletion() }
        }
    }

    /// `daysremember://day/<id>` (tapped from the widget) opens that day's detail.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "daysremember" else { return }
        openDay(id: url.lastPathComponent)
    }

    private func routePending(_ id: String?) {
        guard let id else { return }
        openDay(id: id)
        router.dayID = nil
    }

    /// Open a day's detail on the Home stack. No-ops safely if the id no longer exists.
    /// Shared by the widget URL and tapped-reminder routing.
    private func openDay(id: String) {
        guard let day = store.days.first(where: { $0.id == id }) else { return }
        tab = .home
        homePath = NavigationPath()
        homePath.append(DayRoute(id: day.id))
    }

    @ViewBuilder
    private var content: some View {
        TabView(selection: $tab) {
            homeStack
                .tabItem { Label("日子", systemImage: "square.stack") }
                .tag(AppTab.home)
            calendarStack
                .tabItem { Label("日历", systemImage: "calendar") }
                .tag(AppTab.calendar)
            categoriesStack
                .tabItem { Label("分类", systemImage: "square.grid.2x2") }
                .tag(AppTab.categories)
            NotificationsView()
                .tabItem { Label("提醒", systemImage: "bell") }
                .tag(AppTab.notifications)
        }
    }

    private var homeStack: some View {
        NavigationStack(path: $homePath) {
            HomeView(
                onOpen: { day in homePath.append(DayRoute(id: day.id)) },
                onAdd: { addingDay = true }
            )
            .toolbar(.hidden, for: .navigationBar)
            .dayDetailDestination()
        }
        .overlay(alignment: .bottom) { undoOverlay(on: .home) }
    }

    private var calendarStack: some View {
        NavigationStack(path: $calendarPath) {
            CalendarMonthView(onOpen: { day in calendarPath.append(DayRoute(id: day.id)) })
                .toolbar(.hidden, for: .navigationBar)
                .dayDetailDestination()
        }
        .overlay(alignment: .bottom) { undoOverlay(on: .calendar) }
    }

    private var categoriesStack: some View {
        NavigationStack(path: $categoryPath) {
            CategoriesView()
                .toolbar(.hidden, for: .navigationBar)
                .dayDetailDestination()
                .navigationDestination(for: CategoryRoute.self) { route in
                    switch route {
                    case .all:
                        CategoryDaysListView(title: String(localized: "全部日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale), categoryID: nil,
                                             onOpen: { categoryPath.append(DayRoute(id: $0.id)) })
                    case .category(let id):
                        CategoryDaysListView(title: store.category(for: id).displayName, categoryID: id,
                                             onOpen: { categoryPath.append(DayRoute(id: $0.id)) })
                    }
                }
        }
        .overlay(alignment: .bottom) { undoOverlay(on: .categories) }
    }
}

private extension View {
    /// Shared `DayRoute` → `DetailView` push used by all three tab stacks. Pushed screens
    /// keep the system navigation bar: hiding it disables the interactive edge swipe.
    func dayDetailDestination() -> some View {
        navigationDestination(for: DayRoute.self) { route in
            DetailView(dayID: route.id)
                .toolbar(.visible, for: .navigationBar)
        }
    }
}
