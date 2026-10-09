import SwiftUI
import UIKit
import WidgetKit

@main
struct DaysRememberApp: App {
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var store = DebugLaunch.makeStore()
    #else
    @State private var store = DayStore()
    #endif
    @State private var settings = AppSettings()
    @State private var router = DeepLinkRouter()
    @State private var currentDay = CNDate.calendar.startOfDay(for: Today.date)
    @AppStorage(AppLocalization.languageKey, store: SharedStorage.defaults)
    private var language = AppLanguage.system

    var body: some Scene {
        WindowGroup {
            LocalizedRootView(language: language)
                .environment(store)
                .environment(settings)
                .environment(router)
                .environment(\.currentDay, currentDay)
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
                    if ProcessInfo.processInfo.arguments.contains("--seed-widget-photo") {
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = 1
                        let photoData = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400), format: format)
                            .image { context in
                                UIColor.systemYellow.setFill()
                                context.fill(CGRect(x: 0, y: 0, width: 600, height: 400))
                                UIColor.systemBlue.setFill()
                                context.fill(CGRect(x: 300, y: 0, width: 300, height: 400))
                            }.jpegData(compressionQuality: 0.8)
                        store.days = store.days.map { day in
                            var day = day
                            day.photoData = photoData
                            return day
                        }
                    }
                    if ProcessInfo.processInfo.arguments.contains("--seed-sync-conflicts"),
                       var local = store.days.first {
                        local.note = "Local note retained before sync"
                        store.update(local)
                        var remote = local
                        remote.note = "Remote note"
                        try? store.applyCloudUpdate(CloudLibraryUpdate(upsertedDays: [remote], recoveryDays: [local]))
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
                    if phase == .active {
                        refreshCurrentDay()
                        store.rescheduleNotifications()
                    }
                }
                .onChange(of: language) {
                    store.rescheduleNotifications()
                    WidgetCenter.shared.reloadTimelines(ofKind: "DaysRememberWidget")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    refreshCurrentDay()
                    store.rescheduleNotifications()
                }
                .task { await refreshAtMidnight() }
        }
    }

    private func refreshCurrentDay() {
        currentDay = CNDate.calendar.startOfDay(for: Today.date)
    }

    private func refreshAtMidnight() async {
        #if DEBUG
        if DebugLaunch.isAutomated,
           let delay = ProcessInfo.processInfo.environment["DR_ADVANCE_DAY_AFTER_SECONDS"].flatMap(Double.init),
           delay > 0, delay <= 60 {
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            currentDay = CNDate.dayStarts(after: currentDay, count: 1).first ?? currentDay
            return
        }
        #endif
        while !Task.isCancelled {
            let now = Date()
            let next = CNDate.dayStarts(after: now, count: 1).first ?? now.addingTimeInterval(21600)
            do { try await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow))) }
            catch { return }
            refreshCurrentDay()
            store.rescheduleNotifications()
        }
    }
}

private struct LocalizedRootView: View {
    let language: AppLanguage

    var body: some View {
        // Recreate localized view state without restarting storage/cloud setup.
        RootGate()
            .id(language)
            .environment(\.locale, AppLocalization.locale(for: language))
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
    static func makeStore() -> DayStore {
        if ProcessInfo.processInfo.arguments.contains("--ui-polish-fixture") {
            let name = "UIPolishUITests.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: name) else {
                preconditionFailure("Unable to create isolated UI test storage")
            }
            let store = DayStore(defaults: defaults)
            let category = CategoryDefinition(id: "ui-polish-custom", name: "Journeys and the people we meet along the way",
                                              icon: "camera", colorToken: .dusty, isSystem: false)
            store.categories = [category] + CategoryDefinition.system
            let calendar = CNDate.calendar
            let featured = Day(id: "ui-polish-featured", title: "和朋友去看海",
                               date: calendar.date(byAdding: .day, value: 10, to: Today.date)!,
                               category: .travel, photo: .japan)
            let long = Day(id: "ui-polish-long",
                           title: "Long-term memories from a summer journey together, with every little moment kept close to our hearts",
                           date: calendar.date(byAdding: .day, value: -12_000, to: Today.date)!,
                           category: .travel, photo: .japan, categoryID: category.id,
                           note: "Every day has a story worth remembering.", pinned: true, categoryLabel: category.name)
            store.days = [featured, long] + SampleData.days
            return store
        }
        guard ProcessInfo.processInfo.arguments.contains("--simulate-photo-save-failure") else {
            return DayStore()
        }
        // The failure fixture never reads or writes the real App Group library.
        let name = "EditorSaveUITests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("Unable to create isolated editor test storage")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let day = Day(id: "save-failure-fixture", title: "Save failure fixture", date: Today.date,
                      category: .life, photo: .systemDefault,
                      photoData: Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="))
        do {
            defaults.set(try JSONEncoder().encode([day]), forKey: SharedStorage.legacyDaysKey)
            try Data("blocked photo directory".utf8).write(to: directory)
        } catch {
            preconditionFailure("Unable to prepare editor save failure: \(error)")
        }
        return DayStore(defaults: defaults, photoDirectory: directory)
    }

    enum Screen: String {
        case onboarding, detail, add, share, widgets, settings

        @MainActor
        @ViewBuilder
        func makeView(store: DayStore) -> some View {
            switch self {
            case .onboarding:
                OnboardingView()
            case .detail:
                NavigationStack { DetailView(day: DebugLaunch.day(store: store)) }
            case .add:
                AddDayView()
            case .share:
                ShareCardView(day: DebugLaunch.day(store: store))
            case .widgets:
                WidgetsPreviewView()
            case .settings:
                SettingsView()
            }
        }
    }

    /// True when launched with any debug arg or pinned-today env var — i.e. an
    /// automated screenshot session that can't dismiss system popups.
    static var isAutomated: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--screen") || args.contains("--tab") { return true }
        if args.contains("--empty-library") || args.contains("--seed-sample-data")
            || args.contains("--seed-sync-conflicts") || args.contains("--simulate-photo-save-failure")
            || args.contains("--ui-polish-fixture") { return true }
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
