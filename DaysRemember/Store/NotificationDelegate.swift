import Foundation
import UserNotifications

/// UNUserNotificationCenter delegate — routes a tapped reminder to its day, and lets
/// reminders surface as a banner while the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: DeepLinkRouter
    init(router: DeepLinkRouter) { self.router = router; super.init() }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        await NotificationManager.shared.refresh()
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["dayID"] as? String else { return }
        let router = router
        await MainActor.run { router.dayID = id }
    }
}
