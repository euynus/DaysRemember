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
    @State private var tab: AppTab = Self.initialTab()
    @State private var homePath = NavigationPath()
    @State private var calendarPath = NavigationPath()
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                TabBar(current: tab, onSelect: { tab = $0 })
            }
            .ignoresSafeArea(.keyboard)
            .sheet(isPresented: $addingDay) { AddDayView() }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:
            NavigationStack(path: $homePath) {
                HomeView(
                    onOpen: { day in homePath.append(day) },
                    onAdd: { addingDay = true }
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Day.self) { day in
                    DetailView(day: day, onBack: { homePath.removeLast() })
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
                }
            }
        case .calendar:
            NavigationStack(path: $calendarPath) {
                CalendarMonthView(onOpen: { day in calendarPath.append(day) })
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Day.self) { day in
                        DetailView(day: day, onBack: { calendarPath.removeLast() })
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationBarBackButtonHidden(true)
                    }
            }
        case .categories:
            CategoriesView()
        case .notifications:
            NotificationsView()
        }
    }
}

struct TabBar: View {
    let current: AppTab
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { t in
                Button { onSelect(t) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: current == t ? t.iconNameFilled : t.iconName)
                            .font(.system(size: 20, weight: current == t ? .semibold : .regular))
                            .foregroundStyle(current == t ? Theme.ink : Theme.muted)
                        Text(t.label)
                            .font(Theme.sans(10, weight: .medium))
                            .foregroundStyle(current == t ? Theme.ink : Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .background(
            ZStack {
                Theme.card
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        )
    }
}
