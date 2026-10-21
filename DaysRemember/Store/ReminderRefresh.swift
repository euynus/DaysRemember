import BackgroundTasks
import Foundation

/// iOS keeps at most 64 pending reminders, the earliest in the planning window, so a library with
/// more than that runs out unless they're planned again. A daily background refresh does it
/// without waiting for the app to be opened.
enum ReminderRefresh {
    static let identifier = "com.shiguang.daysremember.reminders"

    /// Asks for the next refresh, about a day from now. iOS decides when, or whether, it runs.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date.now.addingTimeInterval(24 * 60 * 60)
        // Refused on the simulator and when Background App Refresh is off; opening the app plans them too.
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    static func run(store: DayStore, settings: AppSettings) async {
        schedule()
        guard store.loadError == nil else { return }
        await NotificationManager.shared.sync(days: store.days, settings: settings)
    }
}
