import UIKit

/// Applies this device's sync choice to everything that reaches iCloud: CloudKit for days and
/// categories, key-value storage for settings, and the pushes that tell CloudKit sync to fetch.
@MainActor
enum CloudSyncControl {
    /// At launch: syncs only once the user has chosen iCloud.
    static func resume(store: DayStore, settings: AppSettings) {
        guard settings.syncChoice == .iCloud, !isAutomated else { return }
        start(store: store, settings: settings)
    }

    static func choose(_ choice: SyncChoice, store: DayStore, settings: AppSettings) {
        settings.syncChoice = choice
        guard !isAutomated else { return }
        switch choice {
        case .iCloud:
            start(store: store, settings: settings)
        case .localOnly:
            store.disableCloudSync()
            settings.disableCloudSync()
            UIApplication.shared.unregisterForRemoteNotifications()
        }
    }

    /// Turns sync off here, then deletes the app's data from the user's iCloud: the CloudKit zone
    /// with every day, category and photo, and the settings and older copies in key-value storage.
    static func deleteCloudData(store: DayStore, settings: AppSettings) async throws {
        choose(.localOnly, store: store, settings: settings)
        try await CloudLibrarySync.shared.deleteCloudData()
        ICloudSyncStore.shared.removeAll()
    }

    private static func start(store: DayStore, settings: AppSettings) {
        store.enableCloudSync()
        settings.enableCloudSync {
            store.rescheduleNotifications()
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// UI tests, screenshots and unit tests never reach iCloud.
    private static var isAutomated: Bool {
        #if DEBUG
        DebugLaunch.isAutomated || DebugLaunch.isUnitTesting
        #else
        false
        #endif
    }
}
