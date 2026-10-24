import Foundation

/// A link an intent, a control or a Home Screen quick action asks the app to open. They can run
/// before any view exists, or in the widget extension, so the request waits in shared storage
/// until `RootTabView` takes it.
enum PendingLink {
    static let newDay = URL(string: "daysremember://new")!
    static let notification = Notification.Name("dev.gooday.days.pendingLink")
    private static let key = "pendingLink.v1"

    static func request(_ url: URL, defaults: UserDefaults = SharedStorage.defaults) {
        defaults.set(url.absoluteString, forKey: key)
        NotificationCenter.default.post(name: notification, object: nil)
    }

    /// The waiting link, removed as it is taken.
    static func take(defaults: UserDefaults = SharedStorage.defaults) -> URL? {
        guard let link = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return URL(string: link)
    }
}
