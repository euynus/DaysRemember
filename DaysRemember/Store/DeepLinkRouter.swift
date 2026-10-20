import Observation

/// Bridges a tapped reminder (or widget link) to SwiftUI navigation: `RootTabView`
/// observes `dayID`, opens that day's detail, and clears it.
@MainActor
@Observable
final class DeepLinkRouter {
    var dayID: String?
    /// Counts days opened from a link or reminder. Sheets that hold no draft close each time,
    /// so the day doesn't open out of sight beneath them.
    var linkOpenCount = 0
}
