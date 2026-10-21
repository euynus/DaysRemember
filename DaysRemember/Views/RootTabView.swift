import Accessibility
import StoreKit
import SwiftUI

struct RootTabView: View {
    @Environment(DayStore.self) private var store
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = Self.initialTab()
    @State private var homePath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var mePath = NavigationPath()
    @State private var newDay: NewDayRequest?
    @State private var cloud = CloudLibrarySync.shared
    /// A first day to start once iCloud's first download has brought nothing.
    @State private var firstDayAfterDownload = false
    /// The library's size when the new day's editor opened, to tell whether it added one.
    @State private var dayCountBeforeAdding = 0

    /// A new day's editor; `categoryID` starts it in that category.
    private struct NewDayRequest: Identifiable {
        let id = UUID()
        var categoryID: String?
    }

    init(startWithNewDay: Bool = false) {
        // On a new device the library may still be downloading; the editor would hide it arriving.
        let waits = startWithNewDay && CloudLibrarySync.shared.isFirstDownloadPending
        _newDay = State(initialValue: startWithNewDay && !waits ? NewDayRequest() : nil)
        _firstDayAfterDownload = State(initialValue: waits)
    }

    /// Allows `xcrun simctl launch ... --tab calendar` for screenshotting.
    private static func initialTab() -> AppTab {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--tab"), i + 1 < args.count,
           let t = AppTab(argument: args[i + 1]) { return t }
        return .home
    }

    var body: some View {
        content
            .environment(\.addDay, AddDayAction { startNewDay(categoryID: $0) })
            .dayEditorHost()
            .categoryEditorHost()
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
            .sheet(item: $newDay, onDismiss: askForReviewAfterAdding) {
                DayEditorView(categoryID: $0.categoryID).environment(store)
            }
            .onOpenURL { handleDeepLink($0) }
            // Intents, controls and quick actions leave their link to be taken here.
            .onReceive(NotificationCenter.default.publisher(for: PendingLink.notification).receive(on: RunLoop.main)) { _ in
                openPendingLink()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { openPendingLink() }
            }
            .onChange(of: cloud.isFirstDownloadPending) { _, pending in
                guard !pending, firstDayAfterDownload else { return }
                firstDayAfterDownload = false
                if store.days.isEmpty && newDay == nil { startNewDay() }
            }
            .onChange(of: router.dayID) { _, id in routePending(id) }
            // Also catch a tap that set the id before this view began observing
            // (cold launch from a notification).
            .task {
                routePending(router.dayID)
                openPendingLink()
            }
    }

    private func startNewDay(categoryID: String? = nil) {
        dayCountBeforeAdding = store.days.count
        newDay = NewDayRequest(categoryID: categoryID)
    }

    /// Once the editor has gone, a day just added is a good moment to ask for a rating, now and then.
    private func askForReviewAfterAdding() {
        #if DEBUG
        guard !DebugLaunch.isAutomated, !DebugLaunch.isUnitTesting else { return }
        #endif
        guard store.days.count > dayCountBeforeAdding,
              ReviewPrompt.takeTurn(dayCount: store.days.count) else { return }
        requestReview()
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

    /// A day's link opens its detail; the empty widget's link, or one to a day deleted since,
    /// shows 日子.
    private func handleDeepLink(_ url: URL) {
        switch DeepLink(url) {
        case .day(let id): if !openDay(id: id) { openHome() }
        case .newDay:
            openHome()
            if newDay == nil { startNewDay() }
        case .home: openHome()
        case nil: break
        }
    }

    private func openPendingLink() {
        if let url = PendingLink.take() { handleDeepLink(url) }
    }

    private func openHome() {
        router.linkOpenCount += 1
        tab = .home
        homePath = NavigationPath()
    }

    private func routePending(_ id: String?) {
        guard let id else { return }
        openDay(id: id)
        router.dayID = nil
    }

    /// Open a day's detail on the Home stack; false, changing nothing, if the id no longer exists.
    /// Shared by the widget URL and tapped-reminder routing. Editors keep their drafts on top;
    /// the detail opens beneath them.
    @discardableResult
    private func openDay(id: String) -> Bool {
        guard let day = store.days.first(where: { $0.id == id }) else { return false }
        openHome()
        homePath.append(DayRoute(id: day.id))
        return true
    }

    @ViewBuilder
    private var content: some View {
        TabView(selection: $tab) {
            Tab("日子", systemImage: "square.grid.2x2", value: AppTab.home) { homeStack }
            Tab("日历", systemImage: "calendar", value: AppTab.calendar) { calendarStack }
            Tab("我的", systemImage: "person.crop.circle", value: AppTab.me) { meStack }
        }
    }

    private var homeStack: some View {
        NavigationStack(path: $homePath) {
            HomeView(
                onOpen: { day in homePath.append(DayRoute(id: day.id)) },
                onAdd: { startNewDay() }
            )
            .toolbarVisibility(.hidden, for: .navigationBar)
            .dayDetailDestination()
        }
        .overlay(alignment: .bottom) { undoOverlay(on: .home) }
    }

    private var calendarStack: some View {
        NavigationStack(path: $calendarPath) {
            CalendarMonthView(onOpen: { day in calendarPath.append(DayRoute(id: day.id)) })
                .toolbarVisibility(.hidden, for: .navigationBar)
                .dayDetailDestination()
        }
        .overlay(alignment: .bottom) { undoOverlay(on: .calendar) }
    }

    private var meStack: some View {
        NavigationStack(path: $mePath) {
            MeView()
                .toolbarVisibility(.hidden, for: .navigationBar)
                .dayDetailDestination()
                .navigationDestination(for: CategoryRoute.self) { route in
                    switch route {
                    case .all:
                        CategoryDaysListView(title: String(localized: "全部日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale), categoryID: nil,
                                             onOpen: { mePath.append(DayRoute(id: $0.id)) })
                    case .category(let id):
                        CategoryDaysListView(title: store.category(for: id).displayName, categoryID: id,
                                             onOpen: { mePath.append(DayRoute(id: $0.id)) })
                    }
                }
                .navigationDestination(for: MeRoute.self) { route in
                    switch route {
                    case .reminders:
                        NotificationsView(showsHeader: false)
                            .navigationTitle("提醒")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbarVisibility(.visible, for: .navigationBar)
                    }
                }
        }
        .overlay(alignment: .bottom) { undoOverlay(on: .me) }
    }
}

private extension View {
    /// Shared `DayRoute` → `DetailView` push used by all three tab stacks. Pushed screens
    /// keep the system navigation bar: hiding it disables the interactive edge swipe.
    func dayDetailDestination() -> some View {
        navigationDestination(for: DayRoute.self) { route in
            DetailView(dayID: route.id)
                .toolbarVisibility(.visible, for: .navigationBar)
        }
    }
}
