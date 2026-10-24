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
