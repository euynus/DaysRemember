import SwiftUI

@main
struct DaysRememberApp: App {
    @StateObject private var store = DayStore()
    @StateObject private var settings = AppSettings()

    init() {
        // Wire the store to settings so it can re-schedule notifications on day changes.
        // (Has to be in `body` for @StateObject access — this just sets the static link.)
    }

    var body: some Scene {
        WindowGroup {
            RootGate()
                .environmentObject(store)
                .environmentObject(settings)
                .task {
                    store.settings = settings
                    // Authorization is best-effort; user can still flip toggles either way.
                    _ = await NotificationManager.shared.requestAuthorization()
                    store.rescheduleNotifications()
                }
        }
    }
}

private struct RootGate: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: DayStore

    var body: some View {
        if let override = DebugLaunch.screenOverride {
            override.makeView(store: store)
        } else if settings.hasOnboarded {
            RootTabView()
        } else {
            OnboardingView(onFinish: { settings.hasOnboarded = true })
        }
    }
}

/// `xcrun simctl launch ... --screen detail|add|share|onboarding [--day <id>]`
@MainActor
enum DebugLaunch {
    enum Screen: String {
        case onboarding, detail, add, share, widgets

        @MainActor
        @ViewBuilder
        func makeView(store: DayStore) -> some View {
            switch self {
            case .onboarding:
                OnboardingView(initialPage: DebugLaunch.intArg("--page") ?? 0)
            case .detail:
                DetailView(day: DebugLaunch.day(store: store))
            case .add:
                AddDayView()
            case .share:
                ShareCardView(day: DebugLaunch.day(store: store))
            case .widgets:
                WidgetsPreviewView()
            }
        }
    }

    static var screenOverride: Screen? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--screen"), i + 1 < args.count else { return nil }
        return Screen(rawValue: args[i + 1])
    }

    static func day(store: DayStore) -> Day {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--day"), i + 1 < args.count,
           let match = store.days.first(where: { $0.id == args[i + 1] }) {
            return match
        }
        return store.days[0]
    }

    static func intArg(_ name: String) -> Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }
}
