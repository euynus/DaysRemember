import SwiftUI
import UIKit

/// Restores the interactive edge-swipe-back gesture on screens that hide the
/// navigation bar. Hiding the bar (`.toolbar(.hidden, for: .navigationBar)` +
/// `.navigationBarBackButtonHidden(true)`) disables `interactivePopGestureRecognizer`
/// by default, so a custom back button becomes the *only* way back — surprising on
/// iOS, where users expect to swipe from the left edge.
///
/// This finds the enclosing `UINavigationController` (NavigationStack is UIKit-backed)
/// and re-enables the gesture, gated on there being something to pop. Failure mode is
/// benign: if the controller can't be resolved, it simply no-ops.
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let nav = uiViewController.navigationController else { return }
            context.coordinator.nav = nav
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = context.coordinator
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var nav: UINavigationController?

        // Only let the swipe begin when a screen can actually be popped, so it never
        // fires (and stalls) on a stack root.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (nav?.viewControllers.count ?? 0) > 1
        }

        // Coexist with content gestures (e.g. a ScrollView) rather than blocking them.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

extension View {
    /// Re-enable left-edge swipe-back on a nav-bar-hidden screen. Attach to the
    /// screen's root; renders nothing.
    func enableSwipeBack() -> some View {
        background(SwipeBackEnabler().frame(width: 0, height: 0).accessibilityHidden(true))
    }
}
