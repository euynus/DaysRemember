import UIKit

/// The Home Screen quick action that starts a new day. UIKit hands quick actions to the scene
/// delegate, which SwiftUI doesn't surface, so `AppDelegate` installs one that passes them on.
enum QuickActions {
    static let newDay = "com.shiguang.daysremember.newDay"

    /// Set at each launch and language change, so the title follows the app's language.
    @MainActor static func install() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(type: newDay,
                                      localizedTitle: String(localized: "新建日子", bundle: AppLocalization.bundle,
                                                             locale: AppLocalization.locale),
                                      localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: "calendar.badge.plus")),
        ]
    }

    @discardableResult
    static func perform(_ item: UIApplicationShortcutItem) -> Bool {
        guard item.type == newDay else { return false }
        PendingLink.request(PendingLink.newDay)
        return true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // A quick action that launched the app arrives here rather than at the scene delegate.
        if let item = options.shortcutItem { QuickActions.perform(item) }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        QuickActions.perform(shortcutItem)
    }
}
