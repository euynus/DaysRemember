import Foundation

/// UserDefaults backing for data that is shared with the widget extension via App Group.
///
/// Falls back to `.standard` if the App Group entitlement isn't configured (e.g. while
/// running unit tests, or before code-signing has wired up the group capability) so the
/// app stays functional even without the widget — the widget just won't see fresh data.
enum SharedStorage {
    static let appGroupID = "group.com.shiguang.daysremember"

    static let defaults: UserDefaults = {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }()
}
