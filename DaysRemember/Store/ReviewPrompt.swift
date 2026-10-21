import Foundation

/// When to ask for an App Store rating: at most once per version, just after the user adds a day,
/// once the library has a few days and the app has been in use for a week.
enum ReviewPrompt {
    static let minimumDays = 5
    static let minimumUse: TimeInterval = 7 * 24 * 60 * 60
    private static let firstUseKey = "review.firstUse"
    private static let askedVersionKey = "review.askedVersion"

    static func shouldAsk(dayCount: Int, firstUse: Date, now: Date, askedVersion: String?, version: String) -> Bool {
        dayCount >= minimumDays && now.timeIntervalSince(firstUse) >= minimumUse && askedVersion != version
    }

    /// Records the first use, which the week of use counts from.
    static func noteUse(defaults: UserDefaults = .standard, now: Date = .now) {
        if defaults.object(forKey: firstUseKey) == nil { defaults.set(now, forKey: firstUseKey) }
    }

    /// Whether to ask now, recording that it was asked for this version when it is.
    static func takeTurn(dayCount: Int, defaults: UserDefaults = .standard, now: Date = .now,
                         version: String = marketingVersion) -> Bool {
        noteUse(defaults: defaults, now: now)
        guard let firstUse = defaults.object(forKey: firstUseKey) as? Date,
              shouldAsk(dayCount: dayCount, firstUse: firstUse, now: now,
                        askedVersion: defaults.string(forKey: askedVersionKey), version: version) else { return false }
        defaults.set(version, forKey: askedVersionKey)
        return true
    }

    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
