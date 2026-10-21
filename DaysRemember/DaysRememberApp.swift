import CloudKit
import SwiftUI
import TipKit
import UIKit
import WidgetKit

@main
struct DaysRememberApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var store = DebugLaunch.makeStore()
    #else
    @State private var store = DayStore()
    #endif
    @State private var settings = AppSettings()
    @State private var router: DeepLinkRouter
    @State private var currentDay = CNDate.calendar.startOfDay(for: Today.date)
    @AppStorage(AppLocalization.languageKey, store: SharedStorage.defaults)
    private var language = AppLanguage.system

    init() {
        let router = DeepLinkRouter()
        _router = State(initialValue: router)
        // Before launch finishes, as the system requires, so the tap on a reminder that launched
        // the app reaches the router.
        NotificationManager.shared.configureDelegate(router: router)
    }

    var body: some Scene {
        let store = store
        let settings = settings
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
                    var automated = false
                    #if DEBUG
                    automated = DebugLaunch.isAutomated || DebugLaunch.isUnitTesting
                    if ProcessInfo.processInfo.arguments.contains("--seed-sample-data") {
                        store.resetToSamples()
                        if ProcessInfo.processInfo.arguments.contains("--localized-samples") {
                            store.days = SampleTranslations.days(for: SampleTranslations.currentLocalization)
                        }
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
                    // Tips would cover what UI tests and screenshots tap and capture.
                    if automated { Tips.hideAllTipsForTesting() }
                    try? Tips.configure()
                    ReviewPrompt.noteUse()
                    QuickActions.install()
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
                        Task { await CloudLibrarySync.shared.resumeIfNeeded() }
                    } else if phase == .background {
                        ReminderRefresh.schedule()
                        // Siri learns the days' names for phrases like 「…还有几天」.
                        DaysShortcuts.updateAppShortcutParameters()
                    }
                }
                // Signing in to iCloud after launch, for one, starts sync without a relaunch.
                .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged).receive(on: RunLoop.main)) { _ in
                    Task { await CloudLibrarySync.shared.resumeIfNeeded() }
                }
                .onChange(of: language) {
                    QuickActions.install()
                    store.rescheduleNotifications()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                // Includes a change of time zone, which moves the day boundary widgets count from.
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    refreshCurrentDay()
                    store.rescheduleNotifications()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .task { await refreshAtMidnight() }
        }
        .backgroundTask(.appRefresh(ReminderRefresh.identifier)) {
            await ReminderRefresh.run(store: store, settings: settings)
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
            let now = Date.now
            let next = CNDate.localDayStarts(after: now, count: 1).first ?? now.addingTimeInterval(21600)
            do { try await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow))) }
            catch { return }
            refreshCurrentDay()
            store.rescheduleNotifications()
        }
    }
}
