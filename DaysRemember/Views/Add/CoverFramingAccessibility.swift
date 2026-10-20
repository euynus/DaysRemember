import SwiftUI

/// VoiceOver's version of the reframing drag: swipe up or down for the vertical position and use
/// the actions for the horizontal one. A template cover can't be reframed, so it isn't adjustable.
struct CoverFramingAccessibility: ViewModifier {
    let hasPhoto: Bool
    @Binding var x: Double
    @Binding var y: Double

    private func step(_ value: Double, by delta: Double) -> Double { min(1, max(0, value + delta)) }

    func body(content: Content) -> some View {
        let element = content
            .accessibilityElement()
            .accessibilityLabel("封面取景")
            .accessibilityIdentifier("coverFraming")
        if hasPhoto {
            element
                .accessibilityValue(DayEditorView.framingDescription(x: x, y: y))
                .accessibilityHint(String(localized: "上下轻扫调整照片的垂直位置，用操作调整水平位置", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: y = step(y, by: -0.1)
                    case .decrement: y = step(y, by: 0.1)
                    @unknown default: break
                    }
                }
                .accessibilityAction(named: Text(String(localized: "取景向左", bundle: AppLocalization.bundle, locale: AppLocalization.locale))) {
                    x = step(x, by: -0.1)
                }
                .accessibilityAction(named: Text(String(localized: "取景向右", bundle: AppLocalization.bundle, locale: AppLocalization.locale))) {
                    x = step(x, by: 0.1)
                }
        } else {
            element.accessibilityHint(String(localized: "封面预览", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        }
    }
}
