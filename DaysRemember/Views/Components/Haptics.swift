import UIKit

/// Imperative one-shot haptics for actions that dismiss their view in the same
/// runloop (save, delete) — where SwiftUI's trigger-based `.sensoryFeedback`
/// wouldn't fire before the view goes away. In-view selection/impact feedback
/// (tabs, chips, toggles, pin) uses `.sensoryFeedback` directly at those views.
enum Haptics {
    /// Confirmation buzz for a completed action (save).
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Cautionary buzz for a destructive action (delete).
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
