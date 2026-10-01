import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case home, calendar, categories, notifications

    var label: String {
        switch self {
        case .home: return "日子"
        case .calendar: return "日历"
        case .categories: return "分类"
        case .notifications: return "提醒"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "square.grid.2x2"
        case .calendar: return "calendar"
        case .categories: return "tag"
        case .notifications: return "bell"
        }
    }

    /// `calendar` has no `.fill` variant, so we keep the same name and lean on weight for emphasis.
    var iconNameFilled: String {
        switch self {
        case .calendar: return "calendar"
        default: return iconName + ".fill"
        }
    }
}

struct RootTabView: View {
    @Environment(DayStore.self) private var store
    @Environment(DeepLinkRouter.self) private var router
    @State private var tab: AppTab = Self.initialTab()
    @State private var homePath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var categoryPath = NavigationPath()
    @State private var addingDay = false

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
            .sheet(isPresented: $addingDay) { AddDayView().environment(store) }
            .onOpenURL { handleDeepLink($0) }
            .onChange(of: router.dayID) { _, id in routePending(id) }
            // Also catch a tap that set the id before this view began observing
            // (cold launch from a notification).
            .task { routePending(router.dayID) }
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
        homePath.append(day)
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
                onOpen: { day in homePath.append(day) },
                onAdd: { addingDay = true }
            )
            .toolbar(.hidden, for: .navigationBar)
            .dayDetailDestination()
        }
    }

    private var calendarStack: some View {
        NavigationStack(path: $calendarPath) {
            CalendarMonthView(onOpen: { day in calendarPath.append(day) })
                .toolbar(.hidden, for: .navigationBar)
                .dayDetailDestination()
        }
    }

    private var categoriesStack: some View {
        NavigationStack(path: $categoryPath) {
            CategoriesView(onOpen: { day in categoryPath.append(day) })
                .toolbar(.hidden, for: .navigationBar)
                .dayDetailDestination()
        }
    }
}

private extension View {
    /// Shared `Day` → `DetailView` push used by all three tab stacks: hidden nav
    /// bar and a custom back button — one place to keep them identical.
    func dayDetailDestination() -> some View {
        navigationDestination(for: Day.self) { day in
            DetailView(day: day)
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
        }
    }
}
