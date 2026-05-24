import UIKit

/// Thin wrapper over UIKit's feedback generators for discrete, one-shot haptics.
///
/// Used imperatively at the call site (rather than SwiftUI's `.sensoryFeedback`)
/// so a haptic still fires when the triggering view is dismissed in the same
/// runloop — e.g. the success tap that saves a day and closes the editor.
enum Haptics {
    /// Light tap for a value change within a control (tabs, chips, toggles).
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Physical bump for a deliberate state flip (pin / unpin).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Confirmation buzz for a completed action (save).
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Cautionary buzz for a destructive action (delete).
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
