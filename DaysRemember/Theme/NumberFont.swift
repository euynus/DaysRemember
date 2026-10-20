import SwiftUI

/// Countdown numerals that scale like `.title` with the environment's Dynamic Type size,
/// so `.dynamicTypeSize(...)` caps apply to them as they do to text styles.
struct NumberFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let size: CGFloat
    var weight: Font.Weight = .heavy

    func body(content: Content) -> some View {
        content.font(Theme.number(size * Self.scale(for: dynamicTypeSize), weight: weight))
    }

    /// The title text style's growth relative to the default size.
    static func scale(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall: return 0.89
        case .small: return 0.93
        case .medium: return 0.96
        case .large: return 1
        case .xLarge: return 1.07
        case .xxLarge: return 1.14
        case .xxxLarge: return 1.21
        case .accessibility1: return 1.36
        case .accessibility2: return 1.54
        case .accessibility3: return 1.71
        case .accessibility4: return 1.89
        case .accessibility5: return 2.07
        @unknown default: return 1
        }
    }
}

extension View {
    func numberFont(_ size: CGFloat, weight: Font.Weight = .heavy) -> some View {
        modifier(NumberFont(size: size, weight: weight))
    }
}
