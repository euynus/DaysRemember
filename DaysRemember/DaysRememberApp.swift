import SwiftUI
import UIKit

@main
struct DaysRememberApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = DayStore()
    @State private var settings = AppSettings()
    @State private var router = DeepLinkRouter()

    var body: some Scene {
        WindowGroup {
            RootGate()
                .environment(store)
                .environment(settings)
                .environment(router)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                // Artwork and exported cards use the same light appearance.
                .preferredColorScheme(.light)
                .tint(Theme.accent)
                .task {
                    store.settings = settings
                    NotificationManager.shared.configureDelegate(router: router)
                    var automated = false
                    #if DEBUG
                    automated = DebugLaunch.isAutomated || DebugLaunch.isUnitTesting
                    if ProcessInfo.processInfo.arguments.contains("--seed-sample-data") {
                        store.resetToSamples()
                    } else if ProcessInfo.processInfo.arguments.contains("--empty-library") {
                        try? store.restoreBackup(DayBackup(days: [], categories: CategoryDefinition.system, deletedDays: []))
                        settings.hasOnboarded = false
                    }
                    #endif
                    if !automated {
                        store.enableCloudSync()
                        settings.enableCloudSync {
                            store.rescheduleNotifications()
                        }
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    store.rescheduleNotifications()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.rescheduleNotifications() }
                }
        }
    }
}

private struct RootGate: View {
    @Environment(AppSettings.self) var settings
    @Environment(DayStore.self) var store
    @Environment(DeepLinkRouter.self) var router
    @State private var creatingFirstDay = false

    @ViewBuilder
    var body: some View {
        if store.loadError != nil {
            DataManagementView()
        } else {
            #if DEBUG
            if let override = DebugLaunch.screenOverride {
                override.makeView(store: store)
            } else if settings.hasOnboarded || (DebugLaunch.isAutomated && !DebugLaunch.showOnboarding) {
                RootTabView(startWithNewDay: creatingFirstDay)
            } else {
                onboarding
            }
            #else
            if settings.hasOnboarded {
                RootTabView(startWithNewDay: creatingFirstDay)
            } else {
                onboarding
            }
            #endif
        }
    }

    /// Drop any reminder/widget link queued before onboarding finished, so it doesn't
    /// fire a surprise navigation the moment RootTabView first mounts.
    private var onboarding: some View {
        OnboardingView(onFinish: {
            router.dayID = nil
            creatingFirstDay = store.days.isEmpty
            settings.hasOnboarded = true
        })
    }
}

#if DEBUG
/// `xcrun simctl launch ... --screen detail|add|share|onboarding [--day <id>]`
/// DEBUG-only — never compiled into the App Store / Release build.
@MainActor
enum DebugLaunch {
    enum Screen: String {
        case onboarding, detail, add, share, widgets

        @MainActor
        @ViewBuilder
        func makeView(store: DayStore) -> some View {
            switch self {
            case .onboarding:
                OnboardingView()
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

    /// True when launched with any debug arg or pinned-today env var — i.e. an
    /// automated screenshot session that can't dismiss system popups.
    static var isAutomated: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--screen") || args.contains("--tab") { return true }
        if args.contains("--empty-library") || args.contains("--seed-sample-data") { return true }
        if ProcessInfo.processInfo.environment["DR_PIN_TODAY"] != nil { return true }
        return false
    }

    static var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    static var showOnboarding: Bool { ProcessInfo.processInfo.arguments.contains("--show-onboarding") }

    static var screenOverride: Screen? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--screen"), i + 1 < args.count else { return nil }
        return Screen(rawValue: args[i + 1])
    }

    static func day(store: DayStore) -> Day {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--day"), i + 1 < args.count,
           let match = (store.days + SampleData.days).first(where: { $0.id == args[i + 1] }) {
            return match
        }
        return store.days.first ?? SampleData.days.first(where: { $0.id == "wedding" }) ?? SampleData.days[0]
    }

}
#endif
