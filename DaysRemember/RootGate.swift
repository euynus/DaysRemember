import SwiftUI

struct RootGate: View {
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
                tabs
            } else {
                onboarding
            }
            #else
            if settings.hasOnboarded {
                tabs
            } else {
                onboarding
            }
            #endif
        }
    }

    /// A device that synced before the choice existed is asked once, and doesn't sync until it answers.
    @ViewBuilder
    private var tabs: some View {
        #if DEBUG
        let asks = settings.syncChoice == nil && !DebugLaunch.isAutomated
        #else
        let asks = settings.syncChoice == nil
        #endif
        if asks {
            SyncChoiceView { CloudSyncControl.choose($0, store: store, settings: settings) }
        } else {
            RootTabView(startWithNewDay: creatingFirstDay)
        }
    }

    /// Drop any reminder/widget link queued before onboarding finished, so it doesn't
    /// fire a surprise navigation the moment RootTabView first mounts.
    private var onboarding: some View {
        OnboardingView(onFinish: { choice in
            router.dayID = nil
            // On a new device the library may still be on its way from iCloud; RootTabView waits,
            // so sync starts first.
            creatingFirstDay = store.days.isEmpty
            CloudSyncControl.choose(choice, store: store, settings: settings)
            settings.hasOnboarded = true
        })
    }
}
